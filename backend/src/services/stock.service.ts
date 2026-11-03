import { branchOf, requireBranch, scopeBranch } from '../lib/access'
import { conflict, internal, notFound } from '../lib/errors'
import type { Db } from '../lib/supabase'
import { todayRangeWib } from '../lib/time'
import type { AuthUser } from '../types'

const MAX_ITEMS = 1000

const ITEM_COLUMNS = 'id, branch_id, name, category, unit, quantity, created_at, updated_at'
const MOVEMENT_COLUMNS =
  'id, item_id, item_name, unit, branch_id, branch_name, amount, quantity_before, quantity_after, message, created_by_name, created_at'

type StockResult = { item_id: string; movement_id: number | null }

const itemNotFound = () => notFound('Barang tidak ditemukan.')

async function loadResult(db: Db, result: StockResult, failMessage: string) {
  const itemRes = await db
    .from('stock_items')
    .select(ITEM_COLUMNS)
    .eq('id', result.item_id)
    .single()
  if (itemRes.error) throw internal(itemRes.error, failMessage)

  let movement = null
  if (result.movement_id !== null && result.movement_id !== undefined) {
    const moveRes = await db
      .from('v_stock_movements')
      .select(MOVEMENT_COLUMNS)
      .eq('id', result.movement_id)
      .single()
    if (moveRes.error) throw internal(moveRes.error, failMessage)
    movement = moveRes.data
  }

  return { item: itemRes.data, movement }
}

export async function listItems(db: Db, user: AuthUser, requestedBranch?: number) {
  const branchId = scopeBranch(user, requestedBranch)
  const today = todayRangeWib()

  let itemsQuery = db
    .from('stock_items')
    .select(ITEM_COLUMNS)
    .order('name', { ascending: true })
    .limit(MAX_ITEMS)

  let todayQuery = db
    .from('v_stock_movements')
    .select('id', { count: 'exact', head: true })
    .gte('created_at', today.from)
    .lt('created_at', today.to)

  if (branchId !== undefined) {
    itemsQuery = itemsQuery.eq('branch_id', branchId)
    todayQuery = todayQuery.eq('branch_id', branchId)
  }

  const [itemsRes, todayRes] = await Promise.all([itemsQuery, todayQuery])

  const failed = itemsRes.error ?? todayRes.error
  if (failed) throw internal(failed, 'Gagal mengambil data stok.')

  const data = itemsRes.data ?? []
  return {
    data,
    summary: { item_count: data.length, changes_today: todayRes.count ?? 0 },
  }
}

export type CreateItemInput = {
  branchId?: number
  name: string
  category: string
  unit: string
  initial: number
}

export async function createItem(db: Db, user: AuthUser, input: CreateItemInput) {
  const branchId = requireBranch(user, input.branchId)

  const { data, error } = await db.rpc('stock_create_item', {
    p_branch_id: branchId,
    p_name: input.name,
    p_category: input.category,
    p_unit: input.unit,
    p_initial: input.initial,
    p_user: user.id,
  })

  if (error) {
    if (error.code === '23505') {
      throw conflict('Barang dengan nama tersebut sudah terdaftar di cabang ini.', 'ITEM_EXISTS')
    }
    if (error.code === 'P0001') throw conflict(error.message)
    throw internal(error, 'Gagal menyimpan barang.')
  }

  return loadResult(
    db,
    data as StockResult,
    'Barang tersimpan, tetapi gagal memuat data terbaru.',
  )
}

export async function adjustItem(
  db: Db,
  user: AuthUser,
  itemId: string,
  action: 'add' | 'subtract',
  amount: number,
  message: string | null,
) {
  const { data: item, error: itemError } = await db
    .from('stock_items')
    .select('id, branch_id')
    .eq('id', itemId)
    .maybeSingle()
  if (itemError) throw internal(itemError, 'Gagal menyimpan perubahan stok.')
  if (!item) throw itemNotFound()
  if (user.role === 'pengawas' && item.branch_id !== branchOf(user)) {
    throw itemNotFound()
  }

  const { data, error } = await db.rpc('stock_adjust', {
    p_item_id: itemId,
    p_amount: action === 'add' ? amount : -amount,
    p_message: message,
    p_user: user.id,
  })

  if (error) {
    if (error.code === 'P0002') throw itemNotFound()
    if (error.code === 'P0001') throw conflict(error.message)
    throw internal(error, 'Gagal menyimpan perubahan stok.')
  }

  return loadResult(
    db,
    data as StockResult,
    'Perubahan tersimpan, tetapi gagal memuat data terbaru.',
  )
}

export type MovementFilters = {
  limit: number
  offset: number
  from?: string
  to?: string
  itemId?: string
  branchId?: number
}

export async function listMovements(db: Db, user: AuthUser, f: MovementFilters) {
  const branchId = scopeBranch(user, f.branchId)

  let req = db
    .from('v_stock_movements')
    .select(MOVEMENT_COLUMNS)
    .order('created_at', { ascending: false })
    .order('id', { ascending: false })
    .range(f.offset, f.offset + f.limit - 1)

  if (branchId !== undefined) req = req.eq('branch_id', branchId)
  if (f.from) req = req.gte('created_at', f.from)
  if (f.to) req = req.lte('created_at', f.to)
  if (f.itemId) req = req.eq('item_id', f.itemId)

  const { data, error } = await req
  if (error) throw internal(error, 'Gagal mengambil riwayat stok.')
  return data ?? []
}

export { itemNotFound }
