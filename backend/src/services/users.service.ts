import { AppError, conflict, internal, notFound } from '../lib/errors'
import type { Db } from '../lib/supabase'
import type { Role } from '../types'

/** Peran yang boleh dibuat dan dikelola Owner dari aplikasi. */
export type StaffRole = Exclude<Role, 'owner'>

export type StaffInput = {
  full_name: string
  email: string
  password: string
  phone: string | null
  role: StaffRole
  branch_id: number
}

export type StaffPatch = Partial<{
  full_name: string
  phone: string | null
  role: StaffRole
  branch_id: number
  is_active: boolean
}>

export type StaffListQuery = {
  q?: string
  role?: StaffRole
}

type ProfileRow = {
  id: string
  full_name: string
  phone: string | null
  role: StaffRole
  is_active: boolean
  branch_id: number | null
  created_at: string
}

const PROFILE_COLUMNS = 'id, full_name, phone, role, is_active, branch_id, created_at'

export const staffNotFound = () => notFound('Akun tidak ditemukan.')

/** Peta id -> email dari Supabase Auth. Jumlah karyawan kecil, cukup satu halaman besar. */
async function emailMap(db: Db): Promise<Map<string, string>> {
  const map = new Map<string, string>()
  for (let page = 1; ; page++) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 1000 })
    if (error) throw internal(error, 'Gagal mengambil daftar akun.')
    for (const user of data.users) map.set(user.id, user.email ?? '')
    if (data.users.length < 1000) return map
  }
}

async function emailOf(db: Db, id: string): Promise<string> {
  const { data, error } = await db.auth.admin.getUserById(id)
  if (error) throw internal(error, 'Gagal mengambil data akun.')
  return data.user?.email ?? ''
}

export async function listStaff(db: Db, query: StaffListQuery) {
  const req = db
    .from('profiles')
    .select(PROFILE_COLUMNS)
    .in('role', query.role ? [query.role] : ['pengawas', 'pegawai'])
    .order('is_active', { ascending: false })
    .order('full_name', { ascending: true })

  const [{ data, error }, emails] = await Promise.all([req, emailMap(db)])
  if (error) throw internal(error, 'Gagal mengambil daftar akun.')

  const rows = ((data ?? []) as ProfileRow[]).map((row) => ({
    ...row,
    email: emails.get(row.id) ?? '',
  }))

  const q = query.q?.toLowerCase()
  if (!q) return rows
  return rows.filter(
    (row) =>
      row.full_name.toLowerCase().includes(q) ||
      row.email.toLowerCase().includes(q) ||
      (row.phone ?? '').includes(q),
  )
}

async function ensureBranchExists(db: Db, branchId: number) {
  const { data, error } = await db
    .from('branches')
    .select('id')
    .eq('id', branchId)
    .maybeSingle()
  if (error) throw internal(error, 'Gagal memeriksa cabang.')
  if (!data) throw new AppError(400, 'VALIDATION_ERROR', 'Cabang tidak ditemukan.')
}

/**
 * Akun dibuat langsung terverifikasi (tanpa OTP) karena Owner yang mendaftarkan.
 * Profil di-upsert supaya hasilnya sama baik trigger auth.users membuat profil atau tidak.
 */
export async function createStaff(db: Db, input: StaffInput) {
  await ensureBranchExists(db, input.branch_id)

  const { data, error } = await db.auth.admin.createUser({
    email: input.email,
    password: input.password,
    email_confirm: true,
    user_metadata: {
      full_name: input.full_name,
      ...(input.phone ? { phone: input.phone } : {}),
    },
  })

  if (error || !data.user) {
    if (
      error?.code === 'email_exists' ||
      error?.code === 'user_already_exists' ||
      /already|registered/i.test(error?.message ?? '')
    ) {
      throw conflict('Email sudah terdaftar.', 'EMAIL_TAKEN')
    }
    if (error?.code === 'weak_password') {
      throw new AppError(
        400,
        'VALIDATION_ERROR',
        'Password terlalu lemah. Gunakan kombinasi yang lebih kuat.',
      )
    }
    throw internal(error, 'Gagal membuat akun. Coba lagi nanti.')
  }

  const userId = data.user.id
  const { data: profile, error: profileError } = await db
    .from('profiles')
    .upsert({
      id: userId,
      full_name: input.full_name,
      phone: input.phone,
      role: input.role,
      branch_id: input.branch_id,
      is_active: true,
      updated_at: new Date().toISOString(),
    })
    .select(PROFILE_COLUMNS)
    .single()

  if (profileError || !profile) {
    // Jangan tinggalkan akun login tanpa profil yang benar.
    const { error: cleanupError } = await db.auth.admin.deleteUser(userId)
    if (cleanupError) console.error('Gagal menghapus akun setelah profil gagal:', cleanupError)
    throw internal(profileError, 'Gagal menyimpan profil akun. Coba lagi nanti.')
  }

  return { ...(profile as ProfileRow), email: data.user.email ?? input.email }
}

export async function updateStaff(db: Db, id: string, patch: StaffPatch) {
  const { data: current, error: currentError } = await db
    .from('profiles')
    .select('role')
    .eq('id', id)
    .maybeSingle()
  if (currentError) throw internal(currentError, 'Gagal mengubah akun.')
  // Akun Owner tidak dikelola dari sini.
  if (!current || current.role === 'owner') throw staffNotFound()

  if (patch.branch_id !== undefined) await ensureBranchExists(db, patch.branch_id)

  const { data, error } = await db
    .from('profiles')
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq('id', id)
    .select(PROFILE_COLUMNS)
    .maybeSingle()

  if (error) throw internal(error, 'Gagal mengubah akun.')
  if (!data) throw staffNotFound()

  return { ...(data as ProfileRow), email: await emailOf(db, id) }
}
