import { Hono } from 'hono'
import { requireAuth, requireRole } from '../middleware/auth'
import { apiError } from '../lib/response'
import { adminClient } from '../lib/supabase'
import {
  intQuery,
  isoDateTime,
  optionalUuid,
  readJson,
  requiredUuid,
  safeLike,
  text,
  uuidPattern,
  ValidationError,
} from '../lib/validate'
import type { AppEnv } from '../types'

const jobs = new Hono<AppEnv>()

jobs.use('*', requireAuth)

const JOB_STATUSES = [
  'terdaftar',
  'menunggu_dikerjakan',
  'dalam_pengerjaan',
  'menunggu_pemeriksaan',
  'selesai',
  'unit_keluar',
]

type Db = ReturnType<typeof adminClient>

async function assignedJobIds(db: Db, pegawaiId: string): Promise<string[]> {
  const { data, error } = await db
    .from('job_assignees')
    .select('job_id')
    .eq('pegawai_id', pegawaiId)
  if (error) throw error
  return (data ?? []).map((r: { job_id: string }) => r.job_id)
}

jobs.post('/', requireRole('pengawas'), async (c) => {
  const raw = await readJson(c)
  const unitId = requiredUuid(raw.unit_id, 'Unit')
  const locationId = requiredUuid(raw.location_id, 'Lokasi')
  const serviceTypeId = requiredUuid(raw.service_type_id, 'Jenis layanan')
  const enteredAt = isoDateTime(raw.entered_at, 'waktu masuk')
  const notes = text(raw.initial_condition_notes, 'Catatan kondisi awal', {
    max: 500,
  })

  if (enteredAt && Date.parse(enteredAt) > Date.now() + 5 * 60 * 1000) {
    throw new ValidationError('Waktu masuk tidak boleh di masa depan.')
  }

  const user = c.get('user')
  const db = adminClient(c.env)

  const [unitRes, locRes, svcRes, activeRes] = await Promise.all([
    db.from('units').select('id, is_active').eq('id', unitId).maybeSingle(),
    db.from('locations').select('id, is_active').eq('id', locationId).maybeSingle(),
    db.from('service_types').select('id, is_active').eq('id', serviceTypeId).maybeSingle(),
    db
      .from('wash_jobs')
      .select('id, job_code')
      .eq('unit_id', unitId)
      .neq('status', 'unit_keluar')
      .limit(1)
      .maybeSingle(),
  ])

  const failed = unitRes.error ?? locRes.error ?? svcRes.error ?? activeRes.error
  if (failed) {
    console.error(failed)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal memvalidasi data.'), 500)
  }
  if (!unitRes.data?.is_active) {
    throw new ValidationError('Unit tidak ditemukan atau nonaktif.')
  }
  if (!locRes.data?.is_active) {
    throw new ValidationError('Lokasi tidak ditemukan atau nonaktif.')
  }
  if (!svcRes.data?.is_active) {
    throw new ValidationError('Jenis layanan tidak ditemukan atau nonaktif.')
  }
  if (activeRes.data) {
    return c.json(
      apiError(
        'ACTIVE_JOB_EXISTS',
        `Unit ini masih punya pekerjaan aktif (${activeRes.data.job_code}).`,
      ),
      409,
    )
  }

  const { data: row, error } = await db
    .from('wash_jobs')
    .insert({
      unit_id: unitId,
      location_id: locationId,
      service_type_id: serviceTypeId,
      ...(enteredAt ? { entered_at: enteredAt } : {}),
      initial_condition_notes: notes ?? null,
      created_by: user.id,
    })
    .select()
    .single()

  if (error) {
    if (error.code === 'P0001') {
      return c.json(apiError('CONFLICT', error.message), 409)
    }
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal menyimpan data bus.'), 500)
  }

  const { data: detail } = await db
    .from('v_job_detail')
    .select('*')
    .eq('id', row.id)
    .maybeSingle()

  return c.json({ message: 'Bus berhasil dicatat.', job: detail ?? row }, 201)
})

jobs.get('/', async (c) => {
  const statusParam = c.req.query('status')
  const statuses = statusParam
    ? statusParam.split(',').map((s) => s.trim()).filter(Boolean)
    : []
  if (statuses.some((s) => !JOB_STATUSES.includes(s))) {
    throw new ValidationError('Status tidak valid.')
  }
  const locationId = optionalUuid(c.req.query('location_id'), 'Lokasi')
  const serviceTypeId = optionalUuid(c.req.query('service_type_id'), 'Jenis layanan')
  const pegawaiId = optionalUuid(c.req.query('pegawai_id'), 'Petugas')
  const from = isoDateTime(c.req.query('from'), 'tanggal awal')
  const to = isoDateTime(c.req.query('to'), 'tanggal akhir')
  const q = c.req.query('q')?.trim()
  const limit = intQuery(c.req.query('limit'), 'Limit', 50, 1, 100)
  const offset = intQuery(c.req.query('offset'), 'Offset', 0, 0, 1_000_000)

  const user = c.get('user')
  const db = adminClient(c.env)

  let req = db
    .from('v_job_detail')
    .select('*')
    .order('entered_at', { ascending: false })
    .range(offset, offset + limit - 1)

  const scopePegawaiId = user.role === 'pegawai' ? user.id : pegawaiId
  if (scopePegawaiId) {
    let ids: string[]
    try {
      ids = await assignedJobIds(db, scopePegawaiId)
    } catch (err) {
      console.error(err)
      return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil data tugas.'), 500)
    }
    if (ids.length === 0) return c.json({ data: [], limit, offset })
    req = req.in('id', ids)
  }

  if (statuses.length) req = req.in('status', statuses)
  if (locationId) req = req.eq('location_id', locationId)
  if (serviceTypeId) req = req.eq('service_type_id', serviceTypeId)
  if (from) req = req.gte('entered_at', from)
  if (to) req = req.lte('entered_at', to)
  if (q) req = req.ilike('plate_number', `%${safeLike(q)}%`)

  const { data, error } = await req
  if (error) {
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil data pekerjaan.'), 500)
  }
  return c.json({ data, limit, offset })
})

jobs.get('/:id', async (c) => {
  const id = c.req.param('id')
  const notFound = () =>
    c.json(apiError('NOT_FOUND', 'Pekerjaan tidak ditemukan.'), 404)
  if (!uuidPattern.test(id)) return notFound()

  const user = c.get('user')
  const db = adminClient(c.env)

  if (user.role === 'pegawai') {
    const { data: link } = await db
      .from('job_assignees')
      .select('job_id')
      .eq('job_id', id)
      .eq('pegawai_id', user.id)
      .maybeSingle()
    if (!link) return notFound()
  }

  const { data, error } = await db
    .from('v_job_detail')
    .select('*')
    .eq('id', id)
    .maybeSingle()

  if (error) {
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil detail pekerjaan.'), 500)
  }
  if (!data) return notFound()
  return c.json({ job: data })
})

export default jobs