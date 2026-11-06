import type { AppError } from './errors'
import { uuidPattern } from './validate'

/** Ambil parameter path bertipe UUID. UUID tidak valid dianggap "tidak ditemukan". */
export function requireUuid(
  value: string | undefined,
  onInvalid: () => AppError,
): string {
  if (!value || !uuidPattern.test(value)) throw onInvalid()
  return value
}
