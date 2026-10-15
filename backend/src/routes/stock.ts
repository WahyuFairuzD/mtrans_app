import { Hono } from 'hono'
import type { SupabaseClient } from '@supabase/supabase-js'
import { requireAuth, requireRole } from '../middleware/auth'
import { apiError } from '../lib/response'
import { adminClient } from '../lib/supabase'
import {
  intQuery,
  intValue,
  isoDateTime,
  optionalUuid,
  readJson,
  requiredText,
  text,
  uuidPattern,
  ValidationError,
} from '../lib/validate'
import type { AppEnv } from '../types'

const stock = new Hono<AppEnv>()

stock.use('*', requireAuth)
stock.use('*', requireRole('owner', 'pengawas'))

const MAX_AMOUNT = 1_000_000
const MAX_ITEMS = 1000
const WIB_OFFSET_MS = 7 * 60 * 60 * 1000

const ITEM_COLUMNS = 'id, name, category, unit, quantity, created_at, updated_at'
const MOVEMENT_COLUMNS =
  'id, item_id, item_name, unit, amount, quantity_before, quantity_after, message, created_by_name, created_at'

type StockResult = { item_id: string; movement_id: number | null }

const clean = (s: string) => s.replace(/\s+/g, ' ')
function todayRangeWib() {
  const wibNow = new Date(Date.now() + WIB_OFFSET_MS)
  const startUtc =
    Date.UTC(wibNow.getUTCFullYear(), wibNow.getUTCMonth(), wibNow.getUTCDate()) -
    WIB_OFFSET_MS
  return {
    from: new Date(startUtc).toISOString(),
    to: new Date(startUtc + 24 * 60 * 60 * 1000).toISOString(),
  }
}

async function loadResult(db: SupabaseClient, result: StockResult) {
  const itemRes = await db
    .from('stock_items')
    .select(ITEM_COLUMNS)
    .eq('id', result.item_id)
    .single()
  if (itemRes.error) {
    console.error(itemRes.error)
    return null
  }

  let movement = null
  if (result.movement_id !== null && result.movement_id !== undefined) {
    const moveRes = await db
      .from('v_stock_movements')
      .select(MOVEMENT_COLUMNS)
      .eq('id', result.movement_id)
      .single()
    if (moveRes.error) {
      console.error(moveRes.error)
      return null
    }
    movement = moveRes.data
  }

  return { item: itemRes.data, movement }
}

stock.get('/items', async (c) => {
  const db = adminClient(c.env)
  const today = todayRangeWib()

  const [itemsRes, todayRes] = await Promise.all([
    db
      .from('stock_items')
      .select(ITEM_COLUMNS)
      .order('name', { ascending: true })
      .limit(MAX_ITEMS),
    db
      .from('stock_movements')
      .select('id', { count: 'exact', head: true })
      .gte('created_at', today.from)
      .lt('created_at', today.to),
  ])

  const failed = itemsRes.error ?? todayRes.error
  if (failed) {
    console.error(failed)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil data stok.'), 500)
  }

  const data = itemsRes.data ?? []
  return c.json({
    data,
    summary: {
      item_count: data.length,
      changes_today: todayRes.count ?? 0,
    },
  })
})

stock.post('/items', async (c) => {
  const raw = await readJson(c)
  const name = clean(requiredText(raw.name, 'Nama barang', { min: 2, max: 100 }))
  const category = clean(requiredText(raw.category, 'Kategori', { max: 50 }))
  const unit = clean(requiredText(raw.unit, 'Satuan', { max: 20 }))
  const initial =
    intValue(raw.initial_quantity, 'Stok awal', { min: 0, max: MAX_AMOUNT }) ?? 0

  const user = c.get('user')
  const db = adminClient(c.env)

  const { data, error } = await db.rpc('stock_create_item', {
    p_name: name,
    p_category: category,
    p_unit: unit,
    p_initial: initial,
    p_user: user.id,
  })

  if (error) {
    if (error.code === '23505') {
      return c.json(
        apiError('ITEM_EXISTS', 'Barang dengan nama tersebut sudah terdaftar.'),
        409,
      )
    }
    if (error.code === 'P0001') {
      return c.json(apiError('CONFLICT', error.message), 409)
    }
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal menyimpan barang.'), 500)
  }

  const loaded = await loadResult(db, data as StockResult)
  if (!loaded) {
    return c.json(
      apiError('INTERNAL_ERROR', 'Barang tersimpan, tetapi gagal memuat data terbaru.'),
      500,
    )
  }

  return c.json(
    { message: 'Barang berhasil ditambahkan.', item: loaded.item, movement: loaded.movement },
    201,
  )
})

stock.post('/items/:id/adjust', async (c) => {
  const id = c.req.param('id')
  const notFound = () =>
    c.json(apiError('NOT_FOUND', 'Barang tidak ditemukan.'), 404)
  if (!uuidPattern.test(id)) return notFound()

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

  const user = c.get('user')
  const db = adminClient(c.env)

  const { data, error } = await db.rpc('stock_adjust', {
    p_item_id: id,
    p_amount: action === 'add' ? amount : -amount,
    p_message: message,
    p_user: user.id,
  })

  if (error) {
    if (error.code === 'P0002') return notFound()
    if (error.code === 'P0001') {
      return c.json(apiError('CONFLICT', error.message), 409)
    }
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal menyimpan perubahan stok.'), 500)
  }

  const loaded = await loadResult(db, data as StockResult)
  if (!loaded) {
    return c.json(
      apiError('INTERNAL_ERROR', 'Perubahan tersimpan, tetapi gagal memuat data terbaru.'),
      500,
    )
  }

  return c.json({
    message:
      action === 'add' ? 'Stok berhasil ditambahkan.' : 'Stok berhasil dikurangi.',
    item: loaded.item,
    movement: loaded.movement,
  })
})

stock.get('/movements', async (c) => {
  const limit = intQuery(c.req.query('limit'), 'Limit', 100, 1, 100)
  const offset = intQuery(c.req.query('offset'), 'Offset', 0, 0, 1_000_000)
  const from = isoDateTime(c.req.query('from'), 'tanggal awal')
  const to = isoDateTime(c.req.query('to'), 'tanggal akhir')
  const itemId = optionalUuid(c.req.query('item_id'), 'Barang')

  if (from && to && Date.parse(from) > Date.parse(to)) {
    throw new ValidationError('Tanggal awal tidak boleh setelah tanggal akhir.')
  }

  let req = adminClient(c.env)
    .from('v_stock_movements')
    .select(MOVEMENT_COLUMNS)
    .order('created_at', { ascending: false })
    .order('id', { ascending: false })
    .range(offset, offset + limit - 1)

  if (from) req = req.gte('created_at', from)
  if (to) req = req.lte('created_at', to)
  if (itemId) req = req.eq('item_id', itemId)

  const { data, error } = await req
  if (error) {
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil riwayat stok.'), 500)
  }
  return c.json({ data, limit, offset })
})

export default stock