import { dbError } from '../lib/db'
import { conflict, internal, notFound } from '../lib/errors'
import type { Db } from '../lib/supabase'
import { ValidationError } from '../lib/validate'
import type { AuthUser } from '../types'
import { jobNotFound, loadJobDetail } from './jobs.service'

/** Pekerjaan yang sudah diperiksa Pengawas dan siap dikonfirmasi kondisi after-nya. */
export const REPORTABLE_STATUSES = ['selesai', 'unit_keluar']

export const reportNotFound = () => notFound('Laporan inspeksi tidak ditemukan.')

const REPORT_COLUMNS =
  'job_id, report_date, shift, pool_name, team_name, bus_label, after_notes, ' +
  'findings, constraints, final_status, created_at, updated_at'

const SIGNER_COLUMNS =
  'qc_name, qc_signature, operational_name, operational_signature, updated_at'

const BUS_COLUMNS =
  'id, job_code, plate_number, brand, bus_type, branch_id, branch_name, ' +
  'service_name, status, entered_at, started_at, finished_at, inspected_at, ' +
  'inspection_result, inspection_notes, inspector_name, initial_condition_notes, ' +
  'pegawai_names'

export type ReportInput = {
  report_date: string
  shift: string
  pool_name: string
  team_name: string
  bus_label: string
  after_notes: string
  findings: string
  constraints: string
  final_status: string
}

export type SignerInput = {
  qc_name: string
  qc_signature: string | null
  operational_name: string
  operational_signature: string | null
}

export type ReportRow = ReportInput & { job_id: string }

type BusRow = Record<string, unknown> & { id: string }

export type ReportFilters = {
  q?: string
  branchId?: number
  from?: string
  to?: string
}

async function requireInspectedJob(db: Db, jobId: string) {
  const { data, error } = await db
    .from('v_job_detail')
    .select('id, inspection_result')
    .eq('id', jobId)
    .maybeSingle()
  if (error) throw internal(error, 'Gagal mengambil pekerjaan.')
  if (!data) throw jobNotFound()
  if (!data.inspection_result) {
    throw conflict('Pekerjaan ini belum diperiksa Pengawas.')
  }
}

/** Daftar pekerjaan yang sudah diperiksa Pengawas, beserta status laporannya. */
export async function listReportableBuses(
  db: Db,
  f: ReportFilters,
  limit: number,
  offset: number,
) {
  let req = db
    .from('v_job_detail')
    .select(BUS_COLUMNS)
    .in('status', REPORTABLE_STATUSES)
    .order('inspected_at', { ascending: false })
    .order('id', { ascending: false })
    .range(offset, offset + limit - 1)

  if (f.branchId !== undefined) req = req.eq('branch_id', f.branchId)
  if (f.from) req = req.gte('inspected_at', f.from)
  if (f.to) req = req.lte('inspected_at', f.to)
  if (f.q) req = req.ilike('plate_number', `%${f.q.replace(/[%_,()\\]/g, '')}%`)

  const { data, error } = await req
  if (error) throw internal(error, 'Gagal mengambil daftar pekerjaan.')

  const rows = (data ?? []) as unknown as BusRow[]
  if (rows.length === 0) return []

  const { data: reports, error: reportError } = await db
    .from('job_operational_reports')
    .select('job_id, final_status, updated_at')
    .in(
      'job_id',
      rows.map((row) => row.id),
    )
  if (reportError) throw internal(reportError, 'Gagal mengambil status laporan.')

  const byJob = new Map<string, unknown>(
    (reports ?? []).map((r) => [r.job_id as string, r]),
  )

  return rows.map((row) => ({
    ...row,
    report: byJob.get(row.id) ?? null,
  }))
}

/** Detail satu pekerjaan + laporan tersimpan (bila ada). */
export async function getReport(db: Db, jobId: string) {
  const job = await loadJobDetail(db, jobId, 'Gagal mengambil pekerjaan.')

  const { data, error } = await db
    .from('job_operational_reports')
    .select(REPORT_COLUMNS)
    .eq('job_id', jobId)
    .maybeSingle()
  if (error) throw internal(error, 'Gagal mengambil laporan.')

  return { job, report: (data as ReportRow | null) ?? null }
}

/** Simpan laporan baru atau perbarui laporan yang sudah ada. */
export async function saveReport(
  db: Db,
  user: AuthUser,
  jobId: string,
  input: ReportInput,
) {
  await requireInspectedJob(db, jobId)

  const { data: existing, error: findError } = await db
    .from('job_operational_reports')
    .select('job_id')
    .eq('job_id', jobId)
    .maybeSingle()
  if (findError) throw internal(findError, 'Gagal memeriksa laporan.')

  const patch = { ...input, updated_by: user.id }
  const { data, error } = existing
    ? await db
        .from('job_operational_reports')
        .update(patch)
        .eq('job_id', jobId)
        .select(REPORT_COLUMNS)
        .maybeSingle()
    : await db
        .from('job_operational_reports')
        .insert({ job_id: jobId, ...patch, created_by: user.id })
        .select(REPORT_COLUMNS)
        .maybeSingle()

  if (error) throw dbError(error, 'Gagal menyimpan laporan inspeksi.')
  if (!data) throw reportNotFound()
  return data as unknown as ReportRow
}

export async function getSigner(db: Db, user: AuthUser) {
  const { data, error } = await db
    .from('report_signers')
    .select(SIGNER_COLUMNS)
    .eq('profile_id', user.id)
    .maybeSingle()
  if (error) throw internal(error, 'Gagal mengambil data penanda tangan.')
  return data
}

export async function saveSigner(db: Db, user: AuthUser, input: SignerInput) {
  const { data, error } = await db
    .from('report_signers')
    .upsert({ profile_id: user.id, ...input }, { onConflict: 'profile_id' })
    .select(SIGNER_COLUMNS)
    .single()
  if (error) throw dbError(error, 'Gagal menyimpan data penanda tangan.')
  return data
}

/** Tanda tangan hanya boleh PNG base64 dari aplikasi, bukan URL. */
export function signatureValue(v: unknown, label: string): string | null {
  if (v === undefined || v === null || v === '') return null
  if (typeof v !== 'string') throw new ValidationError(`${label} tidak valid.`)
  const s = v.trim()
  if (s === '') return null
  if (!/^[A-Za-z0-9+/=]+$/.test(s)) {
    throw new ValidationError(`${label} tidak valid.`)
  }
  if (s.length > 700_000) {
    throw new ValidationError(`${label} terlalu besar.`)
  }
  return s
}
