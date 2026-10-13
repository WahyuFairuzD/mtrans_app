import { Hono, type Context } from 'hono'
import { requireRole } from '../middleware/auth'
import { apiError } from '../lib/response'
import { adminClient } from '../lib/supabase'
import {
  boolValue,
  readJson,
  uuidPattern,
  ValidationError,
} from '../lib/validate'
import type { AppEnv, AuthUser } from '../types'

// requireAuth dipasang oleh jobs.ts, karena route ini di-mount di sana.
const work = new Hono<AppEnv>()

const MAX_PHOTO_BYTES = 10 * 1024 * 1024

const PHOTO_EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
}

type Db = ReturnType<typeof adminClient>

const jobNotFound = (c: Context<AppEnv>) =>
  c.json(apiError('NOT_FOUND', 'Pekerjaan tidak ditemukan.'), 404)

const itemNotFound = (c: Context<AppEnv>) =>
  c.json(apiError('NOT_FOUND', 'Item checklist tidak ditemukan.'), 404)

const photoNotFound = (c: Context<AppEnv>) =>
  c.json(apiError('NOT_FOUND', 'Foto tidak ditemukan.'), 404)

const conflict = (c: Context<AppEnv>, message: string) =>
  c.json(apiError('CONFLICT', message), 409)

const serverError = (c: Context<AppEnv>, err: unknown, message: string) => {
  console.error(err)
  return c.json(apiError('INTERNAL_ERROR', message), 500)
}

// Pekerjaan yang boleh diakses user: pengawas/owner semua, pegawai hanya yang ditugaskan.
async function findAccessibleJob(
  db: Db,
  jobId: string,
  user: AuthUser,
): Promise<{ id: string; status: string } | null> {
  const { data, error } = await db
    .from('wash_jobs')
    .select('id, status')
    .eq('id', jobId)
    .maybeSingle()
  if (error) throw error
  if (!data) return null

  if (user.role === 'pegawai') {
    const { data: link, error: linkError } = await db
      .from('job_assignees')
      .select('job_id')
      .eq('job_id', jobId)
      .eq('pegawai_id', user.id)
      .maybeSingle()
    if (linkError) throw linkError
    if (!link) return null
  }

  return data as { id: string; status: string }
}

async function runTransition(
  c: Context<AppEnv>,
  db: Db,
  jobId: string,
  from: string,
  to: string,
  userId: string,
  successMessage: string,
): Promise<Response> {
  const { data, error } = await db
    .from('wash_jobs')
    .update({ status: to, updated_by: userId })
    .eq('id', jobId)
    .eq('status', from)
    .select('id')
    .maybeSingle()

  if (error) {
    if (error.code === 'P0001') return conflict(c, error.message)
    return serverError(c, error, 'Gagal mengubah status pekerjaan.')
  }
  if (!data) {
    return conflict(c, 'Status pekerjaan sudah berubah. Muat ulang data.')
  }

  const { data: detail, error: detailError } = await db
    .from('v_job_detail')
    .select('*')
    .eq('id', jobId)
    .maybeSingle()

  if (detailError || !detail) {
    return serverError(
      c,
      detailError,
      'Status tersimpan, tetapi gagal memuat data terbaru.',
    )
  }

  return c.json({ message: successMessage, job: detail })
}

// ---------- Mulai & Selesai ----------

work.post('/:id/start', requireRole('pegawai'), async (c) => {
  const id = c.req.param('id')
  if (!uuidPattern.test(id)) return jobNotFound(c)

  const user = c.get('user')
  const db = adminClient(c.env)

  const job = await findAccessibleJob(db, id, user)
  if (!job) return jobNotFound(c)

  if (job.status !== 'menunggu_dikerjakan') {
    return conflict(
      c,
      'Pekerjaan hanya bisa dimulai saat status Menunggu Dikerjakan.',
    )
  }

  return runTransition(
    c,
    db,
    id,
    'menunggu_dikerjakan',
    'dalam_pengerjaan',
    user.id,
    'Pekerjaan dimulai.',
  )
})

work.post('/:id/finish', requireRole('pegawai'), async (c) => {
  const id = c.req.param('id')
  if (!uuidPattern.test(id)) return jobNotFound(c)

  const user = c.get('user')
  const db = adminClient(c.env)

  const job = await findAccessibleJob(db, id, user)
  if (!job) return jobNotFound(c)

  if (job.status !== 'dalam_pengerjaan') {
    return conflict(
      c,
      'Pekerjaan hanya bisa diselesaikan saat status Dalam Pengerjaan.',
    )
  }

  // Aturan "minimal 1 foto" dan "checklist wajib lengkap" dijaga trigger di database.
  return runTransition(
    c,
    db,
    id,
    'dalam_pengerjaan',
    'menunggu_pemeriksaan',
    user.id,
    'Pekerjaan selesai dan menunggu pemeriksaan.',
  )
})

// ---------- Checklist ----------

const CHECKLIST_COLUMNS = 'id, label, is_required, sort_order, is_done, checked_at'

work.get('/:id/checklist', async (c) => {
  const id = c.req.param('id')
  if (!uuidPattern.test(id)) return jobNotFound(c)

  const db = adminClient(c.env)
  const job = await findAccessibleJob(db, id, c.get('user'))
  if (!job) return jobNotFound(c)

  const { data, error } = await db
    .from('job_checklist_items')
    .select(CHECKLIST_COLUMNS)
    .eq('job_id', id)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true })

  if (error) return serverError(c, error, 'Gagal mengambil checklist.')
  return c.json({ data })
})

work.patch('/:id/checklist/:itemId', requireRole('pegawai'), async (c) => {
  const id = c.req.param('id')
  const itemId = c.req.param('itemId')
  if (!uuidPattern.test(id)) return jobNotFound(c)
  if (!uuidPattern.test(itemId)) return itemNotFound(c)

  const raw = await readJson(c)
  const isDone = boolValue(raw.is_done, 'is_done')
  if (isDone === undefined) {
    throw new ValidationError('Status centang wajib diisi.')
  }

  const user = c.get('user')
  const db = adminClient(c.env)

  const job = await findAccessibleJob(db, id, user)
  if (!job) return jobNotFound(c)

  if (job.status !== 'dalam_pengerjaan') {
    return conflict(
      c,
      'Checklist hanya bisa diubah saat status Dalam Pengerjaan.',
    )
  }

  const { data, error } = await db
    .from('job_checklist_items')
    .update({
      is_done: isDone,
      checked_by: isDone ? user.id : null,
      checked_at: isDone ? new Date().toISOString() : null,
    })
    .eq('id', itemId)
    .eq('job_id', id)
    .select(CHECKLIST_COLUMNS)
    .maybeSingle()

  if (error) {
    if (error.code === 'P0001') return conflict(c, error.message)
    return serverError(c, error, 'Gagal menyimpan checklist.')
  }
  if (!data) return itemNotFound(c)

  return c.json({ item: data })
})

// ---------- Foto ----------

work.post('/:id/photos', requireRole('pegawai'), async (c) => {
  const id = c.req.param('id')
  if (!uuidPattern.test(id)) return jobNotFound(c)

  const declaredLength = Number(c.req.header('content-length') ?? 0)
  if (declaredLength > MAX_PHOTO_BYTES + 1024 * 1024) {
    return c.json(
      apiError('PAYLOAD_TOO_LARGE', 'Ukuran foto maksimal 10 MB.'),
      413,
    )
  }

  const user = c.get('user')
  const db = adminClient(c.env)

  const job = await findAccessibleJob(db, id, user)
  if (!job) return jobNotFound(c)

  if (job.status !== 'dalam_pengerjaan') {
    return conflict(c, 'Foto hanya bisa diunggah saat status Dalam Pengerjaan.')
  }

  const body = await c.req.parseBody()
  const file = body['file']

  if (!(file instanceof File)) {
    throw new ValidationError('File foto wajib diunggah.')
  }
  if (file.size === 0) {
    throw new ValidationError('File foto kosong.')
  }
  if (file.size > MAX_PHOTO_BYTES) {
    return c.json(
      apiError('PAYLOAD_TOO_LARGE', 'Ukuran foto maksimal 10 MB.'),
      413,
    )
  }

  const ext = PHOTO_EXT[file.type]
  if (!ext) {
    throw new ValidationError('Format foto harus JPG, PNG, atau WebP.')
  }

  const key = `${id}/${crypto.randomUUID()}.${ext}`

  await c.env.PHOTOS.put(key, file.stream(), {
    httpMetadata: { contentType: file.type },
  })

  const { data: photo, error } = await db
    .from('job_photos')
    .insert({ job_id: id, storage_path: key, uploaded_by: user.id })
    .select('id, created_at')
    .single()

  if (error) {
    try {
      await c.env.PHOTOS.delete(key)
    } catch (cleanupError) {
      console.error('Gagal membersihkan file R2:', cleanupError)
    }
    if (error.code === 'P0001') return conflict(c, error.message)
    return serverError(c, error, 'Gagal menyimpan foto.')
  }

  return c.json({ message: 'Foto berhasil diunggah.', photo }, 201)
})

work.get('/:id/photos', async (c) => {
  const id = c.req.param('id')
  if (!uuidPattern.test(id)) return jobNotFound(c)

  const db = adminClient(c.env)
  const job = await findAccessibleJob(db, id, c.get('user'))
  if (!job) return jobNotFound(c)

  const { data, error } = await db
    .from('job_photos')
    .select('id, created_at')
    .eq('job_id', id)
    .order('created_at', { ascending: true })

  if (error) return serverError(c, error, 'Gagal mengambil daftar foto.')
  return c.json({ data })
})

work.get('/:id/photos/:photoId/file', async (c) => {
  const id = c.req.param('id')
  const photoId = c.req.param('photoId')
  if (!uuidPattern.test(id)) return jobNotFound(c)
  if (!uuidPattern.test(photoId)) return photoNotFound(c)

  const db = adminClient(c.env)
  const job = await findAccessibleJob(db, id, c.get('user'))
  if (!job) return jobNotFound(c)

  const { data: photo, error } = await db
    .from('job_photos')
    .select('storage_path')
    .eq('id', photoId)
    .eq('job_id', id)
    .maybeSingle()

  if (error) return serverError(c, error, 'Gagal mengambil foto.')
  if (!photo) return photoNotFound(c)

  const object = await c.env.PHOTOS.get(photo.storage_path)
  if (!object) {
    return c.json(apiError('NOT_FOUND', 'File foto tidak ditemukan.'), 404)
  }

  const headers = new Headers()
  object.writeHttpMetadata(headers)
  headers.set('etag', object.httpEtag)
  headers.set('Cache-Control', 'private, max-age=3600')
  headers.set('X-Content-Type-Options', 'nosniff')

  return new Response(object.body, { headers })
})

work.delete('/:id/photos/:photoId', requireRole('pegawai'), async (c) => {
  const id = c.req.param('id')
  const photoId = c.req.param('photoId')
  if (!uuidPattern.test(id)) return jobNotFound(c)
  if (!uuidPattern.test(photoId)) return photoNotFound(c)

  const user = c.get('user')
  const db = adminClient(c.env)

  const job = await findAccessibleJob(db, id, user)
  if (!job) return jobNotFound(c)

  if (job.status !== 'dalam_pengerjaan') {
    return conflict(c, 'Foto hanya bisa dihapus saat status Dalam Pengerjaan.')
  }

  const { data: photo, error } = await db
    .from('job_photos')
    .select('id, storage_path')
    .eq('id', photoId)
    .eq('job_id', id)
    .maybeSingle()

  if (error) return serverError(c, error, 'Gagal mengambil foto.')
  if (!photo) return photoNotFound(c)

  // Hapus baris database dulu; kalau gagal, file R2 tetap aman dan tidak ada baris yatim.
  const { error: deleteError } = await db
    .from('job_photos')
    .delete()
    .eq('id', photoId)
    .eq('job_id', id)

  if (deleteError) {
    if (deleteError.code === 'P0001') return conflict(c, deleteError.message)
    return serverError(c, deleteError, 'Gagal menghapus foto.')
  }

  try {
    await c.env.PHOTOS.delete(photo.storage_path)
  } catch (r2Error) {
    console.error('Baris foto terhapus, tetapi file R2 gagal dihapus:', r2Error)
  }

  return c.json({ message: 'Foto berhasil dihapus.' })
})

export default work