import { Hono } from 'hono'
import { requireUuid } from '../lib/http'
import { adminClient } from '../lib/supabase'
import {
  intQuery,
  intValue,
  isoDateTime,
  optionalBranchId,
  optionalUuid,
  readJson,
  requiredText,
  text,
  ValidationError,
} from '../lib/validate'
import { requireAuth, requireRole } from '../middleware/auth'
import {
  adjustItem,
  createItem,
  itemNotFound,
  listItems,
  listMovements,
} from '../services/stock.service'
import type { AppEnv } from '../types'

const stock = new Hono<AppEnv>()

stock.use('*', requireAuth)
stock.use('*', requireRole('owner', 'pengawas'))

const MAX_AMOUNT = 1_000_000

const clean = (s: string) => s.replace(/\s+/g, ' ')

stock.get('/items', async (c) => {
  const branchId = optionalBranchId(c.req.query('branch_id'))
  const result = await listItems(adminClient(c.env), c.get('user'), branchId)
  return c.json(result)
})

stock.post('/items', async (c) => {
  const raw = await readJson(c)

  const result = await createItem(adminClient(c.env), c.get('user'), {
    branchId: optionalBranchId(raw.branch_id),
    name: clean(requiredText(raw.name, 'Nama barang', { min: 2, max: 100 })),
    category: clean(requiredText(raw.category, 'Kategori', { max: 50 })),
    unit: clean(requiredText(raw.unit, 'Satuan', { max: 20 })),
    initial: intValue(raw.initial_quantity, 'Stok awal', { min: 0, max: MAX_AMOUNT }) ?? 0,
  })

  return c.json(
    {
      message: 'Barang berhasil ditambahkan.',
      item: result.item,
      movement: result.movement,
    },
    201,
  )
})

stock.post('/items/:id/adjust', async (c) => {
  const id = requireUuid(c.req.param('id'), itemNotFound)
  const raw = await readJson(c)

  const action = raw.action
  if (action !== 'add' && action !== 'subtract') {
    throw new ValidationError('Aksi harus add atau subtract.')
  }
  const amount = intValue(raw.amount, 'Jumlah', { min: 1, max: MAX_AMOUNT })
  if (amount === undefined || amount === null) {
    throw new ValidationError('Jumlah wajib diisi.')
  }
  const message = text(raw.message, 'Pesan', { max: 255 }) ?? null

  const result = await adjustItem(
    adminClient(c.env),
    c.get('user'),
    id,
    action,
    amount,
    message,
  )

  return c.json({
    message:
      action === 'add' ? 'Stok berhasil ditambahkan.' : 'Stok berhasil dikurangi.',
    item: result.item,
    movement: result.movement,
  })
})

stock.get('/movements', async (c) => {
  const limit = intQuery(c.req.query('limit'), 'Limit', 100, 1, 100)
  const offset = intQuery(c.req.query('offset'), 'Offset', 0, 0, 1_000_000)
  const from = isoDateTime(c.req.query('from'), 'tanggal awal')
  const to = isoDateTime(c.req.query('to'), 'tanggal akhir')

  if (from && to && Date.parse(from) > Date.parse(to)) {
    throw new ValidationError('Tanggal awal tidak boleh setelah tanggal akhir.')
  }

  const data = await listMovements(adminClient(c.env), c.get('user'), {
    limit,
    offset,
    from,
    to,
    itemId: optionalUuid(c.req.query('item_id'), 'Barang'),
    branchId: optionalBranchId(c.req.query('branch_id')),
  })
  return c.json({ data, limit, offset })
})

export default stock
