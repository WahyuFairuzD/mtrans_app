import { Hono } from 'hono'
import { tooLarge } from '../lib/errors'
import { requireUuid } from '../lib/http'
import { adminClient } from '../lib/supabase'
import {
  intQuery,
  optionalBranchId,
  optionalPositiveInt,
  requiredBranchId,
  requiredIsoDate,
  ValidationError,
} from '../lib/validate'
import { requireAuth, requireRole } from '../middleware/auth'
import {
  createInvoice,
  getInvoice,
  getInvoiceSignature,
  invoiceNotFound,
  listInvoices,
  markInvoicePaid,
  previewInvoice,
  voidInvoice,
} from '../services/invoices.service'
import type { AppEnv } from '../types'

const invoices = new Hono<AppEnv>()

invoices.use('*', requireAuth)
invoices.use('*', requireRole('owner'))

const MAX_SIGNATURE_BYTES = 512 * 1024
const MAX_INVOICE_NUMBER = 999_999
const STATUSES = ['terbit', 'lunas', 'batal']

function isPng(bytes: ArrayBuffer): boolean {
  if (bytes.byteLength < 8) return false
  const head = new Uint8Array(bytes, 0, 4)
  return head[0] === 0x89 && head[1] === 0x50 && head[2] === 0x4e && head[3] === 0x47
}

// Pratinjau isi invoice sebelum dibuat. Tidak menyimpan apa pun.
invoices.get('/preview', async (c) => {
  const preview = await previewInvoice(
    adminClient(c.env),
    requiredBranchId(c.req.query('branch_id')),
    requiredIsoDate(c.req.query('from'), 'Tanggal awal'),
    requiredIsoDate(c.req.query('to'), 'Tanggal akhir'),
  )
  return c.json(preview)
})

invoices.get('/', async (c) => {
  const status = c.req.query('status')
  if (status && !STATUSES.includes(status)) {
    throw new ValidationError('Status harus terbit, lunas, atau batal.')
  }
  const limit = intQuery(c.req.query('limit'), 'Limit', 50, 1, 100)
  const offset = intQuery(c.req.query('offset'), 'Offset', 0, 0, 1_000_000)

  const data = await listInvoices(adminClient(c.env), {
    branchId: optionalBranchId(c.req.query('branch_id')),
    status: status || undefined,
    limit,
    offset,
  })
  return c.json({ data, limit, offset })
})

// Multipart: field teks + file PNG tanda tangan (field "signature").
invoices.post('/', async (c) => {
  const declaredLength = Number(c.req.header('content-length') ?? 0)
  if (declaredLength > MAX_SIGNATURE_BYTES + 64 * 1024) {
    throw tooLarge('Ukuran tanda tangan maksimal 500 KB.')
  }

  const form = await c.req.parseBody()

  const file = form['signature']
  if (!(file instanceof File) || file.size === 0) {
    throw new ValidationError('Tanda tangan wajib diisi.')
  }
  if (file.size > MAX_SIGNATURE_BYTES) {
    throw tooLarge('Ukuran tanda tangan maksimal 500 KB.')
  }
  const signature = await file.arrayBuffer()
  if (!isPng(signature)) {
    throw new ValidationError('Tanda tangan harus berupa gambar PNG.')
  }

  const result = await createInvoice(adminClient(c.env), c.env.PHOTOS, c.get('user'), {
    branchId: requiredBranchId(form['branch_id']),
    periodStart: requiredIsoDate(form['period_start'], 'Tanggal awal periode'),
    periodEnd: requiredIsoDate(form['period_end'], 'Tanggal akhir periode'),
    invoiceDate: requiredIsoDate(form['invoice_date'], 'Tanggal invoice'),
    dueDate: requiredIsoDate(form['due_date'], 'Jatuh tempo'),
    number: optionalPositiveInt(form['number'], 'Nomor invoice', MAX_INVOICE_NUMBER),
    signature,
  })

  return c.json(
    {
      message: 'Invoice berhasil dibuat.',
      invoice: result.invoice,
      skipped_count: result.skipped_count,
    },
    201,
  )
})

invoices.get('/:id', async (c) => {
  const id = requireUuid(c.req.param('id'), invoiceNotFound)
  return c.json({ invoice: await getInvoice(adminClient(c.env), id) })
})

invoices.get('/:id/signature', async (c) => {
  const id = requireUuid(c.req.param('id'), invoiceNotFound)
  const object = await getInvoiceSignature(adminClient(c.env), c.env.PHOTOS, id)

  const headers = new Headers()
  object.writeHttpMetadata(headers)
  headers.set('etag', object.httpEtag)
  headers.set('Cache-Control', 'private, max-age=86400')
  headers.set('X-Content-Type-Options', 'nosniff')

  return new Response(object.body, { headers })
})

invoices.post('/:id/void', async (c) => {
  const id = requireUuid(c.req.param('id'), invoiceNotFound)
  const invoice = await voidInvoice(adminClient(c.env), c.get('user'), id)
  return c.json({ message: 'Invoice dibatalkan.', invoice })
})

invoices.post('/:id/paid', async (c) => {
  const id = requireUuid(c.req.param('id'), invoiceNotFound)
  const invoice = await markInvoicePaid(adminClient(c.env), id)
  return c.json({ message: 'Invoice ditandai lunas.', invoice })
})

export default invoices
