import { Hono } from 'hono'
import { adminClient } from '../lib/supabase'
import { intValue, readJson, ValidationError } from '../lib/validate'
import { VEHICLE_LABELS, VEHICLE_TYPES } from '../lib/vehicle'
import { requireAuth, requireRole } from '../middleware/auth'
import { getPrices, updatePrices, type Prices } from '../services/prices.service'
import type { AppEnv } from '../types'

const prices = new Hono<AppEnv>()

prices.use('*', requireAuth)
prices.use('*', requireRole('owner'))

const MAX_PRICE = 10_000_000

prices.get('/', async (c) => {
  return c.json({ data: await getPrices(adminClient(c.env)) })
})

prices.put('/', async (c) => {
  const raw = await readJson(c)

  const next = {} as Prices
  for (const type of VEHICLE_TYPES) {
    const label = `Harga ${VEHICLE_LABELS[type]}`
    const value = intValue(raw[type], label, { min: 0, max: MAX_PRICE })
    if (value === undefined || value === null) {
      throw new ValidationError(`${label} wajib diisi.`)
    }
    next[type] = value
  }

  const data = await updatePrices(adminClient(c.env), c.get('user'), next)
  return c.json({ message: 'Harga berhasil disimpan.', data })
})

export default prices
