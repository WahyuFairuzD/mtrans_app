import { internal } from '../lib/errors'
import type { Db } from '../lib/supabase'

export async function listBranches(db: Db) {
  const { data, error } = await db.from('branches').select('id, name').order('name')
  if (error) throw internal(error, 'Gagal mengambil daftar cabang.')
  return data ?? []
}

export async function listServiceTypes(db: Db) {
  const { data, error } = await db
    .from('service_types')
    .select('id, name, description')
    .eq('is_active', true)
    .order('name')
  if (error) throw internal(error, 'Gagal mengambil jenis layanan.')
  return data ?? []
}

export async function listPegawai(db: Db) {
  const { data, error } = await db
    .from('profiles')
    .select('id, full_name')
    .eq('role', 'pegawai')
    .eq('is_active', true)
    .order('full_name')
  if (error) throw internal(error, 'Gagal mengambil daftar petugas.')
  return data ?? []
}
