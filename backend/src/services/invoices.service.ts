import { dbError } from '../lib/db'
import { conflict, internal, notFound } from '../lib/errors'
import type { Db } from '../lib/supabase'
import { wibClockOf, wibDateOf } from '../lib/time'
import { ValidationError } from '../lib/validate'
import { VEHICLE_TYPES, type VehicleType } from '../lib/vehicle'
import type { AuthUser } from '../types'

const MAX_PERIOD_DAYS = 400
const DAY_MS = 24 * 60 * 60 * 1000

export const invoiceNotFound = () => notFound('Invoice tidak ditemukan.')

type CandidateRow = {
  job_id: string
  exited_at: string
  unit_name: string
  plate_number: string
  vehicle_type: VehicleType
  price: number
  already_invoiced: boolean
}

type ItemRow = Omit<CandidateRow, 'already_invoiced'> & { line_no: number }

function toLine(row: Omit<CandidateRow, 'already_invoiced'>) {
  return {
    job_id: row.job_id,
    exited_at: row.exited_at,
    exit_date: wibDateOf(row.exited_at),
    exit_time: wibClockOf(row.exited_at),
    unit_name: row.unit_name,
    plate_number: row.plate_number,
    vehicle_type: row.vehicle_type,
    price: row.price,
  }
}

/** Ringkasan untuk Lampiran: hanya jenis kendaraan yang ada di periode itu. */
function summarize(lines: { vehicle_type: VehicleType; price: number }[]) {
  const summary: { vehicle_type: VehicleType; units: number; price: number; total: number }[] = []
  for (const type of VEHICLE_TYPES) {
    const ofType = lines.filter((l) => l.vehicle_type === type)
    if (ofType.length === 0) continue
    const total = ofType.reduce((sum, l) => sum + l.price, 0)
    summary.push({ vehicle_type: type, units: ofType.length, price: ofType[0].price, total })
  }
  return summary
}

function assertPeriod(from: string, to: string) {
  const days = (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / DAY_MS
  if (days < 0) {
    throw new ValidationError('Tanggal awal tidak boleh setelah tanggal akhir.')
  }
  if (days > MAX_PERIOD_DAYS) {
    throw new ValidationError(`Periode maksimal ${MAX_PERIOD_DAYS} hari.`)
  }
}

/** Pratinjau isi invoice tanpa menyimpan apa pun. */
export async function previewInvoice(db: Db, branchId: number, from: string, to: string) {
  assertPeriod(from, to)

  const { data, error } = await db.rpc('invoice_candidates', {
    p_branch_id: branchId,
    p_from: from,
    p_to: to,
  })
  if (error) throw internal(error, 'Gagal mengambil data invoice.')

  const rows = (data ?? []) as CandidateRow[]
  const billable = rows.filter((r) => !r.already_invoiced)
  const lines = billable.map(toLine)

  return {
    branch_id: branchId,
    period_start: from,
    period_end: to,
    lines,
    skipped_count: rows.length - billable.length,
    summary: summarize(lines),
    total: lines.reduce((sum, l) => sum + l.price, 0),
  }
}

const LIST_COLUMNS =
  'id, number, branch_id, period_start, period_end, invoice_date, due_date, status, total_amount, signer_name, created_at, voided_at, branches(name)'

type InvoiceRow = {
  id: string
  signature_key?: string | null
  branches: { name: string } | null
  [key: string]: unknown
}

function toInvoiceDto(row: InvoiceRow) {
  const { branches, signature_key: signatureKey, ...rest } = row
  return {
    ...rest,
    branch_name: branches?.name ?? '',
    ...(signatureKey !== undefined
      ? { signature_url: signatureKey ? `/invoices/${row.id}/signature` : null }
      : {}),
  }
}

export type InvoiceListQuery = {
  branchId?: number
  status?: string
  limit: number
  offset: number
}

export async function listInvoices(db: Db, q: InvoiceListQuery) {
  let req = db
    .from('invoices')
    .select(LIST_COLUMNS)
    .order('number', { ascending: false })
    .range(q.offset, q.offset + q.limit - 1)

  if (q.branchId !== undefined) req = req.eq('branch_id', q.branchId)
  if (q.status) req = req.eq('status', q.status)

  const { data, error } = await req
  if (error) throw internal(error, 'Gagal mengambil daftar invoice.')
  return ((data ?? []) as unknown as InvoiceRow[]).map(toInvoiceDto)
}

export async function getInvoice(db: Db, id: string) {
  const { data, error } = await db
    .from('invoices')
    .select(`${LIST_COLUMNS}, signature_key`)
    .eq('id', id)
    .maybeSingle()
  if (error) throw internal(error, 'Gagal mengambil invoice.')
  if (!data) throw invoiceNotFound()

  const itemsRes = await db
    .from('invoice_items')
    .select('line_no, job_id, exited_at, unit_name, plate_number, vehicle_type, price')
    .eq('invoice_id', id)
    .order('line_no', { ascending: true })
  if (itemsRes.error) throw internal(itemsRes.error, 'Gagal mengambil isi invoice.')

  const items = ((itemsRes.data ?? []) as ItemRow[]).map((row) => ({
    line_no: row.line_no,
    ...toLine(row),
  }))

  return {
    ...toInvoiceDto(data as unknown as InvoiceRow),
    items,
    summary: summarize(items),
  }
}

export type CreateInvoiceInput = {
  branchId: number
  periodStart: string
  periodEnd: string
  invoiceDate: string
  dueDate: string
  /** Kosong = nomor berikutnya otomatis. */
  number?: number
  signature: ArrayBuffer
}

async function removeQuietly(bucket: R2Bucket, key: string) {
  try {
    await bucket.delete(key)
  } catch (cleanupError) {
    console.error('Gagal membersihkan tanda tangan invoice:', cleanupError)
  }
}

export async function createInvoice(
  db: Db,
  bucket: R2Bucket,
  user: AuthUser,
  input: CreateInvoiceInput,
) {
  assertPeriod(input.periodStart, input.periodEnd)
  if (input.dueDate < input.invoiceDate) {
    throw new ValidationError('Jatuh tempo tidak boleh sebelum tanggal invoice.')
  }

  const key = `invoices/signatures/${crypto.randomUUID()}.png`
  try {
    await bucket.put(key, input.signature, {
      httpMetadata: { contentType: 'image/png' },
    })
  } catch (uploadError) {
    throw internal(uploadError, 'Gagal menyimpan tanda tangan.')
  }

  const { data, error } = await db.rpc('create_invoice', {
    p_branch_id: input.branchId,
    p_period_start: input.periodStart,
    p_period_end: input.periodEnd,
    p_invoice_date: input.invoiceDate,
    p_due_date: input.dueDate,
    p_number: input.number ?? null,
    // Nama penanda tangan selalu dari akun yang sedang login.
    p_signer_name: user.full_name.trim().toUpperCase(),
    p_signature_key: key,
    p_user: user.id,
  })

  if (error) {
    await removeQuietly(bucket, key)
    if (error.code === '23505') throw conflict('Nomor invoice sudah dipakai.')
    throw dbError(error, 'Gagal membuat invoice.')
  }

  const result = data as { invoice_id: string; number: number; skipped_count: number }
  const invoice = await getInvoice(db, result.invoice_id)
  return { invoice, skipped_count: result.skipped_count }
}

export async function voidInvoice(db: Db, user: AuthUser, id: string) {
  const { error } = await db.rpc('void_invoice', {
    p_invoice_id: id,
    p_user: user.id,
  })
  if (error) {
    if (error.code === 'P0002') throw invoiceNotFound()
    throw dbError(error, 'Gagal membatalkan invoice.')
  }
  return getInvoice(db, id)
}

export async function getInvoiceSignature(db: Db, bucket: R2Bucket, id: string) {
  const { data, error } = await db
    .from('invoices')
    .select('signature_key')
    .eq('id', id)
    .maybeSingle()
  if (error) throw internal(error, 'Gagal mengambil tanda tangan.')
  if (!data) throw invoiceNotFound()
  if (!data.signature_key) throw notFound('Tanda tangan tidak tersedia.')

  const object = await bucket.get(data.signature_key as string)
  if (!object) throw notFound('File tanda tangan tidak ditemukan.')
  return object
}
