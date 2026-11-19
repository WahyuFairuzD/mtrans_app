import { Hono } from 'hono'
import { adminClient } from '../lib/supabase'
import { requireAuth, requireRole } from '../middleware/auth'
import {
  listBranches,
  listPegawai,
  listServiceTypes,
} from '../services/lookups.service'
import type { AppEnv } from '../types'

const lookups = new Hono<AppEnv>()

// Publik: dipakai Petugas memilih cabang tepat setelah login.
lookups.get('/branches', async (c) => {
  return c.json({ data: await listBranches(adminClient(c.env)) })
})

lookups.get(
  '/service-types',
  requireAuth,
  requireRole('owner', 'pengawas'),
  async (c) => {
    return c.json({ data: await listServiceTypes(adminClient(c.env)) })
  },
)

lookups.get(
  '/pegawai',
  requireAuth,
  requireRole('owner', 'pengawas'),
  async (c) => {
    return c.json({ data: await listPegawai(adminClient(c.env)) })
  },
)

export default lookups
