import { Hono } from 'hono'
import { adminClient } from '../lib/supabase'
import { apiError } from '../lib/response'
import { intQuery, readJson, ValidationError } from '../lib/validate'
import { requireAuth, requireRole } from '../middleware/auth'
import type { AppEnv } from '../types'

const attendance = new Hono<AppEnv>()
attendance.use('*', requireAuth)

const PHOTO_BUCKET = 'attendance-photos'
const MAX_PHOTO_BYTES = 1024 * 1024
const WIB_OFFSET_MS = 7 * 60 * 60 * 1000
const COLUMNS = `id, user_id, branch_id, type, attended_at, work_date, latitude, longitude, accuracy_m, photo_path,
  profiles!attendance_user_id_fkey(full_name, role), branches!attendance_branch_id_fkey(name)`

function todayWib(): string {
  return new Date(Date.now() + WIB_OFFSET_MS).toISOString().slice(0, 10)
}

function validCoordinates(raw: Record<string, unknown>) {
  const latitude = raw.latitude
  const longitude = raw.longitude
  const accuracy = raw.accuracy_m

  if (typeof latitude !== 'number' || !Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new ValidationError('Koordinat latitude tidak valid.')
  }
  if (typeof longitude !== 'number' || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new ValidationError('Koordinat longitude tidak valid.')
  }
  if (accuracy !== undefined && accuracy !== null &&
      (typeof accuracy !== 'number' || !Number.isFinite(accuracy) || accuracy < 0)) {
    throw new ValidationError('Akurasi GPS tidak valid.')
  }
  return { latitude, longitude, accuracy_m: (accuracy as number | null | undefined) ?? null }
}

function withPhotoUrl(db: ReturnType<typeof adminClient>, row: any) {
  return db.storage.from(PHOTO_BUCKET).createSignedUrl(row.photo_path, 60 * 60)
    .then(({ data, error }) => {
      if (error || !data?.signedUrl) throw error ?? new Error('URL foto tidak tersedia.')
      const profile = row.profiles ?? {}
      const branch = row.branches ?? {}
      const { photo_path: _photoPath, profiles: _profiles, branches: _branches, ...rest } = row
      return {
        ...rest,
        full_name: profile.full_name ?? '',
        role: profile.role ?? '',
        branch_name: branch.name ?? '',
        photo_url: data.signedUrl,
      }
    })
}

attendance.get('/me/today', requireRole('pegawai', 'pengawas'), async (c) => {
  const db = adminClient(c.env)
  const user = c.get('user')
  const { data, error } = await db
    .from('attendance')
    .select(COLUMNS)
    .eq('user_id', user.id)
    .eq('work_date', todayWib())
    .order('attended_at', { ascending: true })

  if (error) {
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil absensi hari ini.'), 500)
  }

  try {
    return c.json({ data: await Promise.all((data ?? []).map((row) => withPhotoUrl(db, row))) })
  } catch (err) {
    console.error(err)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal memuat foto absensi.'), 500)
  }
})

attendance.get('/today', requireRole('owner'), async (c) => {
  const branchId = intQuery(c.req.query('branch_id'), 'Cabang', 0, 0, 32767)
  const db = adminClient(c.env)
  let query = db
    .from('attendance')
    .select(COLUMNS)
    .eq('work_date', todayWib())
    .order('attended_at', { ascending: true })
  if (branchId > 0) query = query.eq('branch_id', branchId)

  const { data, error } = await query
  if (error) {
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil absensi hari ini.'), 500)
  }

  try {
    return c.json({ data: await Promise.all((data ?? []).map((row) => withPhotoUrl(db, row))) })
  } catch (err) {
    console.error(err)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal memuat foto absensi.'), 500)
  }
})

attendance.post('/', requireRole('pegawai', 'pengawas'), async (c) => {
  const user = c.get('user')
  const contentLength = Number(c.req.header('content-length') ?? 0)
  if (contentLength > MAX_PHOTO_BYTES + 64 * 1024) {
    return c.json(apiError('PAYLOAD_TOO_LARGE', 'Ukuran foto maksimal 1 MB.'), 413)
  }

  const form = await c.req.parseBody()
  const type = form['type']
  if (type !== 'masuk' && type !== 'pulang') {
    throw new ValidationError('Jenis absensi harus masuk atau pulang.')
  }
  const file = form['photo']
  if (!(file instanceof File) || file.size === 0) {
    throw new ValidationError('Foto absensi wajib diunggah.')
  }
  if (file.size > MAX_PHOTO_BYTES) {
    return c.json(apiError('PAYLOAD_TOO_LARGE', 'Ukuran foto maksimal 1 MB.'), 413)
  }
  if (file.type !== 'image/jpeg') {
    throw new ValidationError('Foto absensi harus berformat JPEG.')
  }

  const latitude = Number(form['latitude'])
  const longitude = Number(form['longitude'])
  const accuracyRaw = form['accuracy_m']
  const coordinates = validCoordinates({
    latitude,
    longitude,
    ...(accuracyRaw === undefined ? {} : { accuracy_m: Number(accuracyRaw) }),
  })
  const db = adminClient(c.env)

  let branchId: number
  if (user.role === 'pengawas') {
    if (!user.branch_id) {
      return c.json(apiError('BRANCH_NOT_ASSIGNED', 'Cabang akun Pengawas belum ditetapkan.'), 409)
    }
    branchId = user.branch_id
  } else {
    const rawBranch = form['branch_id']
    branchId = typeof rawBranch === 'string' ? Number(rawBranch) : Number.NaN
    if (!Number.isInteger(branchId) || branchId < 1 || branchId > 32767) {
      throw new ValidationError('Cabang wajib dipilih.')
    }
  }

  const { data: branch, error: branchError } = await db
    .from('branches').select('id').eq('id', branchId).maybeSingle()
  if (branchError) {
    console.error(branchError)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal memvalidasi cabang.'), 500)
  }
  if (!branch) throw new ValidationError('Cabang tidak ditemukan.')

  const workDate = todayWib()
  const objectPath = `${user.id}/${workDate}/${type}-${crypto.randomUUID()}.jpg`
  const upload = await db.storage.from(PHOTO_BUCKET).upload(
    objectPath,
    await file.arrayBuffer(),
    { contentType: 'image/jpeg', upsert: false },
  )
  if (upload.error) {
    console.error(upload.error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal mengunggah foto absensi.'), 500)
  }

  const { data: row, error } = await db.from('attendance').insert({
    user_id: user.id,
    branch_id: branchId,
    type,
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    accuracy_m: coordinates.accuracy_m,
    photo_path: objectPath,
  }).select(COLUMNS).single()

  if (error) {
    try {
      await db.storage.from(PHOTO_BUCKET).remove([objectPath])
    } catch (cleanupError) {
      console.error('Gagal membersihkan foto absensi:', cleanupError)
    }
    if (error.code === '23505') {
      return c.json(apiError('ATTENDANCE_EXISTS', `Absen ${type} hari ini sudah tercatat.`), 409)
    }
    if (error.code === 'P0001') {
      return c.json(apiError('ATTENDANCE_CONFLICT', error.message), 409)
    }
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal menyimpan absensi.'), 500)
  }

  try {
    return c.json({ message: `Absen ${type} berhasil dicatat.`, attendance: await withPhotoUrl(db, row) }, 201)
  } catch (err) {
    console.error(err)
    return c.json(apiError('INTERNAL_ERROR', 'Absensi tersimpan, tetapi foto gagal dimuat.'), 500)
  }
})

export default attendance
