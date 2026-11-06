import { requireBranch } from '../lib/access'
import { AppError, conflict, internal, notFound } from '../lib/errors'
import type { Db } from '../lib/supabase'
import { todayWib } from '../lib/time'
import { ValidationError } from '../lib/validate'
import type { AuthUser } from '../types'

export type AttendanceType = 'masuk' | 'pulang'

export type AttendanceInput = {
  type: AttendanceType
  /** Wajib untuk Petugas. Pengawas selalu memakai cabang akunnya. */
  branchId?: number
  latitude: number
  longitude: number
  accuracyM: number | null
  photo: ArrayBuffer
}

type AttendanceRow = {
  id: string
  user_id: string
  branch_id: number
  type: AttendanceType
  attended_at: string
  work_date: string
  latitude: number
  longitude: number
  accuracy_m: number | null
  photo_path: string
  profiles: { full_name: string; role: string } | null
  branches: { name: string } | null
}

const COLUMNS = `id, user_id, branch_id, type, attended_at, work_date, latitude, longitude, accuracy_m, photo_path,
  profiles!attendance_user_id_fkey(full_name, role), branches!attendance_branch_id_fkey(name)`

/** photo_path (key R2) tidak dikirim ke klien. Foto diambil lewat GET /attendance/:id/photo. */
function toDto(row: AttendanceRow) {
  const { photo_path: _photoPath, profiles, branches, ...rest } = row
  return {
    ...rest,
    full_name: profiles?.full_name ?? '',
    role: profiles?.role ?? '',
    branch_name: branches?.name ?? '',
    photo_url: `/attendance/${row.id}/photo`,
  }
}

export async function listMine(db: Db, userId: string) {
  const { data, error } = await db
    .from('attendance')
    .select(COLUMNS)
    .eq('user_id', userId)
    .eq('work_date', todayWib())
    .order('attended_at', { ascending: true })

  if (error) throw internal(error, 'Gagal mengambil absensi hari ini.')
  return ((data ?? []) as unknown as AttendanceRow[]).map(toDto)
}

/** Absensi semua pegawai pada satu tanggal kerja (WIB), opsional per cabang. */
export async function listForDate(db: Db, date: string, branchId?: number) {
  let query = db
    .from('attendance')
    .select(COLUMNS)
    .eq('work_date', date)
    .order('attended_at', { ascending: true })
  if (branchId !== undefined) query = query.eq('branch_id', branchId)

  const { data, error } = await query
  if (error) throw internal(error, 'Gagal mengambil absensi hari ini.')
  return ((data ?? []) as unknown as AttendanceRow[]).map(toDto)
}

async function removeQuietly(bucket: R2Bucket, key: string) {
  try {
    await bucket.delete(key)
  } catch (cleanupError) {
    console.error('Gagal membersihkan foto absensi:', cleanupError)
  }
}

export async function submitAttendance(
  db: Db,
  bucket: R2Bucket,
  user: AuthUser,
  input: AttendanceInput,
) {
  const branchId = requireBranch(user, input.branchId)

  const { data: branch, error: branchError } = await db
    .from('branches')
    .select('id')
    .eq('id', branchId)
    .maybeSingle()
  if (branchError) throw internal(branchError, 'Gagal memvalidasi cabang.')
  if (!branch) throw new ValidationError('Cabang tidak ditemukan.')

  const key = `attendance/${user.id}/${todayWib()}/${input.type}-${crypto.randomUUID()}.jpg`

  try {
    await bucket.put(key, input.photo, {
      httpMetadata: { contentType: 'image/jpeg' },
    })
  } catch (uploadError) {
    throw internal(uploadError, 'Gagal mengunggah foto absensi.')
  }

  const { data: row, error } = await db
    .from('attendance')
    .insert({
      user_id: user.id,
      branch_id: branchId,
      type: input.type,
      latitude: input.latitude,
      longitude: input.longitude,
      accuracy_m: input.accuracyM,
      photo_path: key,
    })
    .select(COLUMNS)
    .single()

  if (error) {
    await removeQuietly(bucket, key)
    if (error.code === '23505') {
      throw conflict(`Absen ${input.type} hari ini sudah tercatat.`, 'ATTENDANCE_EXISTS')
    }
    if (error.code === 'P0001') {
      throw conflict(error.message, 'ATTENDANCE_CONFLICT')
    }
    throw internal(error, 'Gagal menyimpan absensi.')
  }

  return toDto(row as unknown as AttendanceRow)
}

/**
 * Ambil objek foto dari R2. Hanya pemilik absensi dan Owner yang boleh melihat.
 * Akses yang ditolak dibalas "tidak ditemukan" supaya keberadaan data tidak bocor.
 */
export async function getAttendancePhoto(
  db: Db,
  bucket: R2Bucket,
  user: AuthUser,
  id: string,
) {
  const { data, error } = await db
    .from('attendance')
    .select('user_id, photo_path')
    .eq('id', id)
    .maybeSingle()

  if (error) throw internal(error, 'Gagal mengambil foto absensi.')
  if (!data) throw notFound('Absensi tidak ditemukan.')
  if (user.role !== 'owner' && data.user_id !== user.id) {
    throw notFound('Absensi tidak ditemukan.')
  }

  const object = await bucket.get(data.photo_path as string)
  // Foto di R2 dihapus otomatis setelah 28 hari (aturan lifecycle bucket).
  if (!object) {
    throw new AppError(
      410,
      'PHOTO_EXPIRED',
      'Foto sudah dihapus karena lebih dari 28 hari.',
    )
  }
  return object
}
