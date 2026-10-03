export type Role = 'owner' | 'pengawas' | 'pegawai'

export type Bindings = {
  SUPABASE_URL: string
  SUPABASE_ANON_KEY: string
  SUPABASE_SERVICE_ROLE_KEY: string
  PHOTOS: R2Bucket
}

export type Profile = {
  id: string
  full_name: string
  phone: string | null
  role: Role
  is_active: boolean
}

export type AuthUser = {
  id: string
  email: string
  full_name: string
  phone: string | null
  role: Role
}

export type Variables = {
  user: AuthUser
  token: string
}

export type AppEnv = {
  Bindings: Bindings
  Variables: Variables
}
