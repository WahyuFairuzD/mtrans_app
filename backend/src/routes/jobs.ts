import { Hono, type Context } from 'hono'
import { requireUuid } from '../lib/http'
import { adminClient } from '../lib/supabase'
import {
  intQuery,
  isoDateTime,
  optionalBranchId,
  optionalUuid,
  readJson,
  requiredUuid,
  text,
  ValidationError,
} from '../lib/validate'
import { requireAuth, requireRole } from '../middleware/auth'
import {
  assignJob,
  createJob,
  getJob,
  JOB_STATUSES,
  jobNotFound,
  jobRecap,
  listJobs,
  type JobFilters,
} from '../services/jobs.service'
import type { AppEnv } from '../types'
import work from './work'

const jobs = new Hono<AppEnv>()

jobs.use('*', requireAuth)

const MAX_ASSIGNEES = 20

function parseFilters(c: Context<AppEnv>): JobFilters {
  const statusParam = c.req.query('status')
  const statuses = statusParam
    ? statusParam.split(',').map((s) => s.trim()).filter(Boolean)
    : []
  if (statuses.some((s) => !JOB_STATUSES.includes(s))) {
    throw new ValidationError('Status tidak valid.')
  }

  return {
    statuses,
    branchId: optionalBranchId(c.req.query('branch_id')),
    serviceTypeId: optionalUuid(c.req.query('service_type_id'), 'Jenis layanan'),
    pegawaiId: optionalUuid(c.req.query('pegawai_id'), 'Petugas'),
    unitId: optionalUuid(c.req.query('unit_id'), 'Unit'),
    from: isoDateTime(c.req.query('from'), 'tanggal awal'),
    to: isoDateTime(c.req.query('to'), 'tanggal akhir'),
    q: c.req.query('q')?.trim() || undefined,
  }
}

function uuidList(v: unknown, label: string, min: number, max: number): string[] {
  if (!Array.isArray(v)) {
    throw new ValidationError(`${label} wajib dipilih.`)
  }
  const ids = [...new Set(v.map((x) => requiredUuid(x, label)))]
  if (ids.length < min) {
    throw new ValidationError(`Pilih minimal ${min} petugas.`)
  }
  if (ids.length > max) {
    throw new ValidationError(`Maksimal ${max} petugas per pekerjaan.`)
  }
  return ids
}

jobs.post('/', requireRole('pengawas'), async (c) => {
  const raw = await readJson(c)

  const enteredAt = isoDateTime(raw.entered_at, 'waktu masuk')
  if (enteredAt && Date.parse(enteredAt) > Date.now() + 5 * 60 * 1000) {
    throw new ValidationError('Waktu masuk tidak boleh di masa depan.')
  }

  const job = await createJob(adminClient(c.env), c.get('user'), {
    unitId: requiredUuid(raw.unit_id, 'Unit'),
    serviceTypeId: requiredUuid(raw.service_type_id, 'Jenis layanan'),
    enteredAt,
    notes: text(raw.initial_condition_notes, 'Catatan kondisi awal', { max: 500 }) ?? null,
  })

  return c.json({ message: 'Bus berhasil dicatat.', job }, 201)
})

jobs.get('/', async (c) => {
  const filters = parseFilters(c)
  const limit = intQuery(c.req.query('limit'), 'Limit', 50, 1, 100)
  const offset = intQuery(c.req.query('offset'), 'Offset', 0, 0, 1_000_000)

  const data = await listJobs(adminClient(c.env), c.get('user'), filters, limit, offset)
  return c.json({ data, limit, offset })
})

jobs.get('/recap', requireRole('owner', 'pengawas'), async (c) => {
  const recap = await jobRecap(adminClient(c.env), c.get('user'), parseFilters(c))
  return c.json({ recap })
})

jobs.get('/:id', async (c) => {
  const id = requireUuid(c.req.param('id'), jobNotFound)
  return c.json(await getJob(adminClient(c.env), c.get('user'), id))
})

jobs.post('/:id/assign', requireRole('pengawas'), async (c) => {
  const id = requireUuid(c.req.param('id'), jobNotFound)
  const raw = await readJson(c)

  const pegawaiIds = uuidList(raw.pegawai_ids, 'Petugas', 1, MAX_ASSIGNEES)

  const instructions =
    raw.instructions === undefined
      ? null
      : (text(raw.instructions, 'Instruksi', { max: 255 }) ?? '')

  const job = await assignJob(adminClient(c.env), c.get('user'), id, {
    pegawaiIds,
    instructions,
  })
  return c.json({ message: 'Penugasan berhasil disimpan.', job })
})

jobs.route('/', work)

export default jobs
