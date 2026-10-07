import { Hono } from 'hono'
import { requireAuth, requireRole } from '../middleware/auth'
import { apiError } from '../lib/response'
import { adminClient } from '../lib/supabase'
import type { AppEnv } from '../types'

const lookups = new Hono<AppEnv>()

lookups.get(
  '/locations',
  requireAuth,
  requireRole('owner', 'pengawas'),
  async (c) => {
    const { data, error } = await adminClient(c.env)
      .from('locations')
      .select('id, name, address')
      .eq('is_active', true)
      .order('name')
    if (error) {
      console.error(error)
      return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil data lokasi.'), 500)
    }
    return c.json({ data })
  },
)

lookups.get(
  '/service-types',
  requireAuth,
  requireRole('owner', 'pengawas'),
  async (c) => {
    const { data, error } = await adminClient(c.env)
      .from('service_types')
      .select('id, name, description')
      .eq('is_active', true)
      .order('name')
    if (error) {
      console.error(error)
      return c.json(apiError('INTERNAL_ERROR', 'Gagal mengambil jenis layanan.'), 500)
    }
    return c.json({ data })
  },
)

export default lookups