import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { Bindings, Profile } from '../types'

export type Db = SupabaseClient

const options = {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false,
  },
}

export const adminClient = (env: Bindings): Db =>
  createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, options)

export const anonClient = (env: Bindings): Db =>
  createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, options)

export async function getProfile(
  admin: Db,
  userId: string,
): Promise<Profile | null> {
  const { data, error } = await admin
    .from('profiles')
    .select('id, full_name, phone, role, is_active, branch_id')
    .eq('id', userId)
    .maybeSingle()

  if (error) throw new Error(`Gagal membaca profil: ${error.message}`)
  return (data as Profile | null) ?? null
}
