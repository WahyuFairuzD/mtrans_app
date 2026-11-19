import type { PostgrestError } from '@supabase/supabase-js'
import { conflict, internal, type AppError } from './errors'

/**
 * Ubah error Postgres jadi AppError.
 * P0001 = `raise exception` dari trigger/fungsi SQL (aturan bisnis), jadi 409.
 * Kode lain (mis. 23505) ditangani pemanggil sebelum memanggil fungsi ini.
 */
export function dbError(error: PostgrestError, fallback: string): AppError {
  if (error.code === 'P0001') return conflict(error.message)
  return internal(error, fallback)
}
