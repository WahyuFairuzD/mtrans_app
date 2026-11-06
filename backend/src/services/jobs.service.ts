import { branchOf, scopeBranch } from '../lib/access'
import { dbError } from '../lib/db'
import { conflict, internal, notFound } from '../lib/errors'
import type { Db } from '../lib/supabase'
import { safeLike, ValidationError } from '../lib/validate'
import type { AuthUser } from '../types'

export const JOB_STATUSES = [
  'terdaftar',
  'menunggu_dikerjakan',
  'dalam_pengerjaan',
  'menunggu_pemeriksaan',
  'selesai',
  'unit_keluar',
]

export type JobFilters = {
  statuses: string[]
  branchId?: number
  serviceTypeId?: string
  pegawaiId?: string
  unitId?: string
  from?: string
  to?: string
  q?: string
}

export const jobNotFound = () => notFound('Pekerjaan tidak ditemukan.')

type AccessibleJob = { id: string; status: string; branch_id: number }

/**
 * Ambil pekerjaan sesuai hak akses peran:
 * - Petugas: hanya yang ditugaskan kepadanya
 * - Pengawas: hanya di cabangnya
 * - Owner: semua
 * Akses yang ditolak dibalas "tidak ditemukan".
 */
export async function findAccessibleJob(
  db: Db,
  jobId: string,
  user: AuthUser,
): Promise<AccessibleJob> {
  const { data, error } = await db
    .from('wash_jobs')
    .select('id, status, branch_id')
    .eq('id', jobId)
    .maybeSingle()
  if (error) throw internal(error, 'Gagal mengambil pekerjaan.')
  if (!data) throw jobNotFound()

  if (user.role === 'pengawas' && data.branch_id !== branchOf(user)) {
    throw jobNotFound()
  }

  if (user.role === 'pegawai') {
    const { data: link, error: linkError } = await db
      .from('job_assignees')
      .select('job_id')
      .eq('job_id', jobId)
      .eq('pegawai_id', user.id)
      .maybeSingle()
    if (linkError) throw internal(linkError, 'Gagal mengambil pekerjaan.')
    if (!link) throw jobNotFound()
  }

  return data as AccessibleJob
}

export async function loadJobDetail(
  db: Db,
  jobId: string,
  failMessage = 'Perubahan tersimpan, tetapi gagal memuat data terbaru.',
) {
  const { data, error } = await db
    .from('v_job_detail')
    .select('*')
    .eq('id', jobId)
    .maybeSingle()
  if (error || !data) throw internal(error ?? 'v_job_detail kosong', failMessage)
  return data
}

export type CreateJobInput = {
  unitId: string
  serviceTypeId: string
  enteredAt?: string
  notes: string | null
}

export async function createJob(db: Db, user: AuthUser, input: CreateJobInput) {
  const branchId = branchOf(user)

  const [unitRes, svcRes, activeRes] = await Promise.all([
    db.from('units').select('id, is_active').eq('id', input.unitId).maybeSingle(),
    db
      .from('service_types')
      .select('id, is_active')
      .eq('id', input.serviceTypeId)
      .maybeSingle(),
    db
      .from('wash_jobs')
      .select('id, job_code')
      .eq('unit_id', input.unitId)
      .neq('status', 'unit_keluar')
      .limit(1)
      .maybeSingle(),
  ])

  const failed = unitRes.error ?? svcRes.error ?? activeRes.error
  if (failed) throw internal(failed, 'Gagal memvalidasi data.')
  if (!unitRes.data?.is_active) {
    throw new ValidationError('Unit tidak ditemukan atau nonaktif.')
  }
  if (!svcRes.data?.is_active) {
    throw new ValidationError('Jenis layanan tidak ditemukan atau nonaktif.')
  }
  if (activeRes.data) {
    throw conflict(
      `Unit ini masih punya pekerjaan aktif (${activeRes.data.job_code}).`,
      'ACTIVE_JOB_EXISTS',
    )
  }

  const { data: row, error } = await db
    .from('wash_jobs')
    .insert({
      unit_id: input.unitId,
      branch_id: branchId,
      service_type_id: input.serviceTypeId,
      ...(input.enteredAt ? { entered_at: input.enteredAt } : {}),
      initial_condition_notes: input.notes,
      created_by: user.id,
    })
    .select()
    .single()
  if (error) throw dbError(error, 'Gagal menyimpan data bus.')

  const { data: detail } = await db
    .from('v_job_detail')
    .select('*')
    .eq('id', row.id)
    .maybeSingle()

  return detail ?? row
}

export async function listJobs(
  db: Db,
  user: AuthUser,
  f: JobFilters,
  limit: number,
  offset: number,
) {
  let req = db
    .from('v_job_detail')
    .select('*')
    .order('entered_at', { ascending: false })
    .order('id', { ascending: false })
    .range(offset, offset + limit - 1)

  if (user.role === 'pegawai') {
    // Petugas selalu dibatasi ke tugas miliknya, apa pun parameter yang dikirim.
    req = req.contains('pegawai_ids', [user.id])
  } else {
    const branchId = scopeBranch(user, f.branchId)
    if (branchId !== undefined) req = req.eq('branch_id', branchId)
    if (f.pegawaiId) req = req.contains('pegawai_ids', [f.pegawaiId])
  }

  if (f.statuses.length) req = req.in('status', f.statuses)
  if (f.serviceTypeId) req = req.eq('service_type_id', f.serviceTypeId)
  if (f.unitId) req = req.eq('unit_id', f.unitId)
  if (f.from) req = req.gte('entered_at', f.from)
  if (f.to) req = req.lte('entered_at', f.to)
  if (f.q) req = req.ilike('plate_number', `%${safeLike(f.q)}%`)

  const { data, error } = await req
  if (error) throw internal(error, 'Gagal mengambil data pekerjaan.')
  return data ?? []
}

export async function jobRecap(db: Db, user: AuthUser, f: JobFilters) {
  const plate = f.q ? safeLike(f.q) : ''

  const { data, error } = await db.rpc('job_recap', {
    p_from: f.from ?? null,
    p_to: f.to ?? null,
    p_branch_id: scopeBranch(user, f.branchId) ?? null,
    p_service_type_id: f.serviceTypeId ?? null,
    p_pegawai_id: f.pegawaiId ?? null,
    p_unit_id: f.unitId ?? null,
    p_plate: plate || null,
    p_statuses: f.statuses.length ? f.statuses : null,
  })
  if (error) throw internal(error, 'Gagal mengambil rekap.')
  return data
}

export async function getJob(db: Db, user: AuthUser, id: string) {
  await findAccessibleJob(db, id, user)
  const job = await loadJobDetail(db, id, 'Gagal mengambil detail pekerjaan.')
  return { job, pegawai_ids: (job.pegawai_ids as string[] | null) ?? [] }
}

export type AssignInput = {
  pegawaiIds: string[]
  /** null = pertahankan instruksi lama. '' = hapus instruksi. */
  instructions: string | null
}

export async function assignJob(
  db: Db,
  user: AuthUser,
  id: string,
  input: AssignInput,
) {
  const job = await findAccessibleJob(db, id, user)

  const { data: valid, error: pegawaiError } = await db
    .from('profiles')
    .select('id')
    .eq('role', 'pegawai')
    .eq('is_active', true)
    .in('id', input.pegawaiIds)
  if (pegawaiError) throw internal(pegawaiError, 'Gagal memvalidasi data.')
  if ((valid ?? []).length !== input.pegawaiIds.length) {
    throw new ValidationError('Terdapat petugas yang tidak valid atau tidak aktif.')
  }

  if (!['terdaftar', 'menunggu_dikerjakan'].includes(job.status)) {
    throw conflict('Penugasan tidak dapat diubah setelah pengerjaan dimulai.')
  }

  const { error } = await db.rpc('assign_job', {
    p_job_id: id,
    p_pegawai_ids: input.pegawaiIds,
    p_team_id: null,
    p_instructions: input.instructions,
    p_assigned_by: user.id,
  })
  if (error) throw dbError(error, 'Gagal menyimpan penugasan.')

  return loadJobDetail(
    db,
    id,
    'Penugasan tersimpan, tetapi gagal memuat data terbaru.',
  )
}
