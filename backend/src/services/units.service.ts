import { conflict, internal, notFound } from '../lib/errors'
import type { Db } from '../lib/supabase'
import { safeLike } from '../lib/validate'

export type UnitFields = Record<string, unknown>

/** Isi plat untuk kendaraan yang tidak punya plat. Boleh dipakai banyak unit. */
export const PLATE_PLACEHOLDER = 'KOSONG'

const plateTaken = () =>
  conflict('Nomor polisi sudah terdaftar.', 'PLATE_TAKEN')

export const unitNotFound = () => notFound('Unit tidak ditemukan.')

export type UnitListQuery = {
  q?: string
  active: 'true' | 'false' | 'all'
  limit: number
  offset: number
}

export async function listUnits(db: Db, query: UnitListQuery) {
  let req = db
    .from('units')
    .select('*')
    .order('plate_number', { ascending: true })
    .order('brand', { ascending: true })
    .range(query.offset, query.offset + query.limit - 1)

  if (query.active !== 'all') req = req.eq('is_active', query.active === 'true')
  if (query.q) {
    // Cari berdasarkan plat atau nama armada. PostgREST memakai * sebagai wildcard di filter or.
    const like = `*${safeLike(query.q)}*`
    req = req.or(`plate_number.ilike.${like},brand.ilike.${like}`)
  }

  const { data, error } = await req
  if (error) throw internal(error, 'Gagal mengambil data unit.')
  return data ?? []
}

export async function createUnit(db: Db, fields: UnitFields) {
  const plate = fields.plate_number as string

  if (plate !== PLATE_PLACEHOLDER) {
    const { data: exist, error: existError } = await db
      .from('units')
      .select('id')
      .ilike('plate_number', plate)
      .maybeSingle()
    if (existError) throw internal(existError, 'Gagal menyimpan unit.')
    if (exist) throw plateTaken()
  }

  const { data, error } = await db.from('units').insert(fields).select().single()
  if (error) {
    if (error.code === '23505') throw plateTaken()
    throw internal(error, 'Gagal menyimpan unit.')
  }
  return data
}

export async function updateUnit(db: Db, id: string, patch: UnitFields) {
  if (typeof patch.plate_number === 'string' && patch.plate_number !== PLATE_PLACEHOLDER) {
    const { data: dup } = await db
      .from('units')
      .select('id')
      .ilike('plate_number', patch.plate_number)
      .neq('id', id)
      .maybeSingle()
    if (dup) throw plateTaken()
  }

  const { data, error } = await db
    .from('units')
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq('id', id)
    .select()
    .maybeSingle()

  if (error) {
    if (error.code === '23505') throw plateTaken()
    throw internal(error, 'Gagal mengubah unit.')
  }
  if (!data) throw unitNotFound()
  return data
}
