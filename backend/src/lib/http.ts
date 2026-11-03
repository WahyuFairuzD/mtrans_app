import type { AppError } from './errors'
import { uuidPattern } from './validate'

export function requireUuid(
  value: string | undefined,
  onInvalid: () => AppError,
): string {
  if (!value || !uuidPattern.test(value)) throw onInvalid()
  return value
}
