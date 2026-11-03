import type { PostgrestError } from '@supabase/supabase-js'
import { conflict, internal, type AppError } from './errors'

export function dbError(error: PostgrestError, fallback: string): AppError {
  if (error.code === 'P0001') return conflict(error.message)
  return internal(error, fallback)
}
