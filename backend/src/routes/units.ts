import { Hono } from 'hono'
import { requireUuid } from '../lib/http'
import { adminClient } from '../lib/supabase'
import {
  boolValue,
  compact,
  intQuery,
  intValue,
  readJson,
  requiredText,
  text,
  ValidationError,
  type JsonObject,
} from '../lib/validate'
import { requireAuth, requireRole } from '../middleware/auth'
import {
  createUnit,
  listUnits,
  unitNotFound,
  updateUnit,
} from '../services/units.service'
import type { AppEnv } from '../types'

const units = new Hono<AppEnv>()

units.use('*', requireAuth)

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
  const active = c.req.query('active') ?? 'true'
  if (active !== 'true' && active !== 'false' && active !== 'all') {
    throw new ValidationError('Parameter active harus true, false, atau all.')
  }
  const limit = intQuery(c.req.query('limit'), 'Limit', 100, 1, 200)
  const offset = intQuery(c.req.query('offset'), 'Offset', 0, 0, 1_000_000)

  const data = await listUnits(adminClient(c.env), {
    q: c.req.query('q')?.trim() || undefined,
    active,
    limit,
    offset,
  })
  return c.json({ data, limit, offset })
})

units.post('/', requireRole('pengawas'), async (c) => {
  const fields = parseUnitFields(await readJson(c), true)
  const unit = await createUnit(adminClient(c.env), fields)
  return c.json({ message: 'Unit berhasil ditambahkan.', unit }, 201)
})

units.patch('/:id', requireRole('pengawas'), async (c) => {
  const id = requireUuid(c.req.param('id'), unitNotFound)

  const raw = await readJson(c)
  const patch = compact({
    ...parseUnitFields(raw, false),
    is_active: boolValue(raw.is_active, 'is_active'),
  })
  if (Object.keys(patch).length === 0) {
    throw new ValidationError('Tidak ada data yang diubah.')
  }

  const unit = await updateUnit(adminClient(c.env), id, patch)
  return c.json({ message: 'Unit berhasil diperbarui.', unit })
})

export default units
