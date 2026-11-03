import type { AuthUser } from '../types'
import { conflict } from './errors'
import { ValidationError } from './validate'

export function branchOf(user: AuthUser): number {
  if (user.branch_id === null) {
    throw conflict(
      'Cabang akun Pengawas belum ditetapkan. Hubungi administrator.',
      'BRANCH_NOT_ASSIGNED',
    )
  }
  return user.branch_id
}

export function scopeBranch(user: AuthUser, requested?: number): number | undefined {
  if (user.role === 'pengawas') return branchOf(user)
  return requested
}

export function requireBranch(user: AuthUser, requested?: number): number {
  if (user.role === 'pengawas') return branchOf(user)
  if (requested === undefined) throw new ValidationError('Cabang wajib dipilih.')
  return requested
}
