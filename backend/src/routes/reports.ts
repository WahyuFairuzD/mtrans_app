import { Hono } from 'hono'
import { requireUuid } from '../lib/http'
import { adminClient } from '../lib/supabase'
import {
  intQuery,
  isoDateTime,
  optionalBranchId,
  readJson,
  requiredIsoDate,
  requiredText,
  text,
  ValidationError,
} from '../lib/validate'
import { requireAuth, requireRole } from '../middleware/auth'
import { jobNotFound } from '../services/jobs.service'
import {
  getReport,
  getSigner,
  listReportableBuses,
  type ReportInput,
  saveReport,
  saveSigner,
  signatureValue,
} from '../services/reports.service'
import type { AppEnv } from '../types'

// Laporan inspeksi: konfirmasi kondisi after oleh Pengawas Operational.
const reports = new Hono<AppEnv>()

reports.use('*', requireAuth, requireRole('owner', 'pengawas_operational'))

function parseReport(raw: Record<string, unknown>): ReportInput {
  return {
    report_date: requiredIsoDate(raw.report_date, 'Tanggal inspeksi'),
    shift: requiredText(raw.shift, 'Shift operasional', { max: 60 }),
    pool_name: requiredText(raw.pool_name, 'Lokasi pool', { max: 100 }),
    team_name: requiredText(raw.team_name, 'Tim cuci', { max: 120 }),
    bus_label: requiredText(raw.bus_label, 'Nama/jenis bus/nopol', { max: 120 }),
    after_notes: requiredText(raw.after_notes, 'Kondisi after', { min: 3, max: 1000 }),
    findings: text(raw.findings, 'Temuan hasil inspeksi', { max: 1000 }) ?? '',
    constraints: text(raw.constraints, 'Kendala lapangan', { max: 1000 }) ?? '',
    final_status: requiredText(raw.final_status, 'Ket. final', { max: 60 }),
  }
}

// Daftar bus yang sudah diperiksa Pengawas, siap dikonfirmasi kondisi after-nya.
reports.get('/buses', async (c) => {
  const limit = intQuery(c.req.query('limit'), 'Limit', 50, 1, 100)
  const offset = intQuery(c.req.query('offset'), 'Offset', 0, 0, 1_000_000)

  const data = await listReportableBuses(
    adminClient(c.env),
    {
      q: c.req.query('q')?.trim() || undefined,
      branchId: optionalBranchId(c.req.query('branch_id')),
      from: isoDateTime(c.req.query('from'), 'tanggal awal'),
      to: isoDateTime(c.req.query('to'), 'tanggal akhir'),
    },
    limit,
    offset,
  )
  return c.json({ data, limit, offset })
})

// Nama & tanda tangan yang dipakai di PDF. Disimpan per akun.
reports.get('/signer', async (c) => {
  return c.json({ data: await getSigner(adminClient(c.env), c.get('user')) })
})

reports.put('/signer', async (c) => {
  const raw = await readJson(c)

  const data = await saveSigner(adminClient(c.env), c.get('user'), {
    qc_name: requiredText(raw.qc_name, 'Nama PIC QC', { min: 2, max: 60 }),
    qc_signature: signatureValue(raw.qc_signature, 'Tanda tangan PIC QC'),
    operational_name: requiredText(raw.operational_name, 'Nama PIC Operasional', {
      min: 2,
      max: 60,
    }),
    operational_signature: signatureValue(
      raw.operational_signature,
      'Tanda tangan PIC Operasional',
    ),
  })
  return c.json({ message: 'Data penanda tangan tersimpan.', data })
})

reports.get('/:jobId', async (c) => {
  const jobId = requireUuid(c.req.param('jobId'), jobNotFound)
  return c.json(await getReport(adminClient(c.env), jobId))
})

reports.put('/:jobId', async (c) => {
  const jobId = requireUuid(c.req.param('jobId'), jobNotFound)
  const report = await saveReport(
    adminClient(c.env),
    c.get('user'),
    jobId,
    parseReport(await readJson(c)),
  )
  return c.json({ message: 'Laporan inspeksi tersimpan.', report })
})

export default reports
