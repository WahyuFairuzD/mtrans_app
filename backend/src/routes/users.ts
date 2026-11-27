import { Hono } from 'hono'
import { requireUuid } from '../lib/http'
import { adminClient } from '../lib/supabase'
import {
  boolValue,
  compact,
  optionalBranchId,
  readJson,
  requiredBranchId,
  requiredText,
  text,
  ValidationError,
} from '../lib/validate'
import { requireAuth, requireRole } from '../middleware/auth'
import {
  createStaff,
  listStaff,
  staffNotFound,
  updateStaff,
  type StaffRole,
} from '../services/users.service'
import type { AppEnv } from '../types'

// Kelola akun Pengawas dan Petugas Cuci. Khusus Owner.
const users = new Hono<AppEnv>()

users.use('*', requireAuth, requireRole('owner'))

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const STAFF_ROLES: StaffRole[] = ['pengawas', 'pengawas_operational', 'pegawai']

function parseRole(v: unknown): StaffRole {
  if (typeof v === 'string' && (STAFF_ROLES as string[]).includes(v)) {
    return v as StaffRole
  }
  throw new ValidationError('Peran harus Pengawas, Pengawas Operational, atau Petugas Cuci.')
}

/**
 * Cabang wajib untuk Pengawas dan Petugas Cuci. Pengawas Operational bekerja
 * lintas cabang, jadi cabangnya boleh kosong.
 */
function staffBranch(role: StaffRole, v: unknown): number | null {
  if (role === 'pengawas_operational') return optionalBranchId(v) ?? null
  return requiredBranchId(v)
}

users.get('/', async (c) => {
  const role = c.req.query('role')
  const data = await listStaff(adminClient(c.env), {
    q: c.req.query('q')?.trim() || undefined,
    role: role ? parseRole(role) : undefined,
  })
  return c.json({ data })
})

users.post('/', async (c) => {
  const raw = await readJson(c)

  const email = requiredText(raw.email, 'Email', { max: 254 }).toLowerCase()
  if (!emailPattern.test(email)) throw new ValidationError('Format email tidak valid.')

  if (typeof raw.password !== 'string' || raw.password === '') {
    throw new ValidationError('Password wajib diisi.')
  }
  if (raw.password.length < 8) throw new ValidationError('Password minimal 8 karakter.')
  if (raw.password.length > 72) throw new ValidationError('Password maksimal 72 karakter.')

  const role = parseRole(raw.role)

  const user = await createStaff(adminClient(c.env), {
    full_name: requiredText(raw.full_name, 'Nama lengkap', { min: 2, max: 100 }),
    email,
    password: raw.password,
    phone: text(raw.phone, 'Nomor HP', { min: 8, max: 20 }) ?? null,
    role,
    branch_id: staffBranch(role, raw.branch_id),
  })
  return c.json({ message: 'Akun berhasil dibuat.', user }, 201)
})

users.patch('/:id', async (c) => {
  const id = requireUuid(c.req.param('id'), staffNotFound)
  const raw = await readJson(c)

  // branch_id: null berarti mengosongkan (hanya sah untuk Pengawas Operational).
  const branchProvided = raw.branch_id !== undefined
  const branchId =
    !branchProvided
      ? undefined
      : raw.branch_id === null || raw.branch_id === ''
        ? null
        : requiredBranchId(raw.branch_id)

  const patch = compact({
    full_name:
      raw.full_name === undefined
        ? undefined
        : requiredText(raw.full_name, 'Nama lengkap', { min: 2, max: 100 }),
    phone: text(raw.phone, 'Nomor HP', { min: 8, max: 20 }),
    role: raw.role === undefined ? undefined : parseRole(raw.role),
    branch_id: branchId,
    is_active: boolValue(raw.is_active, 'is_active'),
  })
  if (Object.keys(patch).length === 0) {
    throw new ValidationError('Tidak ada data yang diubah.')
  }

  const user = await updateStaff(adminClient(c.env), id, patch)
  return c.json({ message: 'Akun berhasil diperbarui.', user })
})

export default users
