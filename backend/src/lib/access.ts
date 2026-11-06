import type { AuthUser } from '../types'
import { conflict } from './errors'
import { ValidationError } from './validate'

/** Cabang tetap milik akun (dipakai Pengawas). Gagal bila belum ditetapkan. */
export function branchOf(user: AuthUser): number {
  if (user.branch_id === null) {
    throw conflict(
      'Cabang akun Pengawas belum ditetapkan. Hubungi administrator.',
      'BRANCH_NOT_ASSIGNED',
    )
  }
  return user.branch_id
}

/**
 * Lingkup cabang untuk membaca data.
 * Pengawas dikunci ke cabangnya. Owner bebas: undefined berarti semua cabang.
 */
export function scopeBranch(user: AuthUser, requested?: number): number | undefined {
  if (user.role === 'pengawas') return branchOf(user)
  return requested
}

/**
 * Cabang untuk menulis data.
 * Pengawas memakai cabang akunnya. Peran lain wajib menyebut cabang.
 */
export function requireBranch(user: AuthUser, requested?: number): number {
  if (user.role === 'pengawas') return branchOf(user)
  if (requested === undefined) throw new ValidationError('Cabang wajib dipilih.')
  return requested
}
