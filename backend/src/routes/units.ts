import { Hono } from 'hono'
import { requireAuth, requireRole } from '../middleware/auth'
import { apiError } from '../lib/response'
import { adminClient } from '../lib/supabase'
import {
  boolValue,
  compact,
  intQuery,
  intValue,
  readJson,
  requiredText,
  safeLike,
  text,
  uuidPattern,
  ValidationError,
  type JsonObject,
} from '../lib/validate'
import type { AppEnv } from '../types'

const units = new Hono<AppEnv>()

units.use('*', requireAuth)

const plateTaken = () =>
  apiError('PLATE_TAKEN', 'Nomor polisi sudah terdaftar.')

const normalizePlate = (v: unknown) =>
  requiredText(v, 'Nomor polisi', { min: 3, max: 15 })
    .replace(/\s+/g, ' ')
    .toUpperCase()

function parseUnitFields(raw: JsonObject, isCreate: boolean) {
  return compact({
    plate_number:
      isCreate || raw.plate_number !== undefined
        ? normalizePlate(raw.plate_number)
        : undefined,
    unit_name: text(raw.unit_name, 'Nama unit', { max: 100 }),
    brand: text(raw.brand, 'Merek', { max: 100 }),
    bus_type: text(raw.bus_type, 'Tipe bus', { max: 100 }),
    capacity: intValue(raw.capacity, 'Kapasitas', { min: 1, max: 200 }),
    notes: text(raw.notes, 'Catatan', { max: 500 }),
  })
}

units.get('/', requireRole('owner', 'pengawas'), async (c) => {
  const q = c.req.query('q')?.trim()
  const active = c.req.query('active') ?? 'true'
  if (!['true', 'false', 'all'].includes(active)) {
    throw new ValidationError('Parameter active harus true, false, atau all.')
  }
  const limit = intQuery(c.req.query('limit'), 'Limit', 100, 1, 200)
  const offset = intQuery(c.req.query('offset'), 'Offset', 0, 0, 1_000_000)

  let req = adminClient(c.env)
    .from('units')
    .select('*')
    .order('plate_number', { ascending: true })
    .range(offset, offset + limit - 1)

  if (active !== 'all') req = req.eq('is_active', active === 'true')
  if (q) req = req.ilike('plate_number', `%${safeLike(q)}%`)

  const { data, error } = await req
  if (error) {
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil data unit.'), 500)
  }
  return c.json({ data, limit, offset })
})

units.post('/', requireRole('pengawas'), async (c) => {
  const fields = parseUnitFields(await readJson(c), true)
  const db = adminClient(c.env)

  const { data: exist, error: existError } = await db
    .from('units')
    .select('id')
    .ilike('plate_number', fields.plate_number as string)
    .maybeSingle()
  if (existError) {
    console.error(existError)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal menyimpan unit.'), 500)
  }
  if (exist) return c.json(plateTaken(), 409)

  const { data, error } = await db.from('units').insert(fields).select().single()
  if (error) {
    if (error.code === '23505') return c.json(plateTaken(), 409)
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal menyimpan unit.'), 500)
  }
  return c.json({ message: 'Unit berhasil ditambahkan.', unit: data }, 201)
})

units.patch('/:id', requireRole('pengawas'), async (c) => {
  const id = c.req.param('id')
  const notFound = () => c.json(apiError('NOT_FOUND', 'Unit tidak ditemukan.'), 404)
  if (!uuidPattern.test(id)) return notFound()

  const raw = await readJson(c)
  const patch = compact({
    ...parseUnitFields(raw, false),
    is_active: boolValue(raw.is_active, 'is_active'),
  })
  if (Object.keys(patch).length === 0) {
    throw new ValidationError('Tidak ada data yang diubah.')
  }

  const db = adminClient(c.env)

  if (typeof patch.plate_number === 'string') {
    const { data: dup } = await db
      .from('units')
      .select('id')
      .ilike('plate_number', patch.plate_number)
      .neq('id', id)
      .maybeSingle()
    if (dup) return c.json(plateTaken(), 409)
  }

  const { data, error } = await db
    .from('units')
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq('id', id)
    .select()
    .maybeSingle()

  if (error) {
    if (error.code === '23505') return c.json(plateTaken(), 409)
    console.error(error)
    return c.json(apiError('INTERNAL_ERROR', 'Gagal mengubah unit.'), 500)
  }
  if (!data) return notFound()
  return c.json({ message: 'Unit berhasil diperbarui.', unit: data })
})

export default units