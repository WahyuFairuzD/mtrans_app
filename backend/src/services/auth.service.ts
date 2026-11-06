import type { Session } from '@supabase/supabase-js'
import { AppError, forbidden } from '../lib/errors'
import { adminClient, anonClient, getProfile } from '../lib/supabase'
import type { AuthUser, Bindings, Profile } from '../types'

export type RegisterInput = {
  full_name: string
  email: string
  password: string
  phone?: string
}

const isEmailRateLimited = (error: { status?: number; code?: string } | null) =>
  error?.status === 429 || error?.code === 'over_email_send_rate_limit'

function toAuthUser(profile: Profile, email: string): AuthUser {
  return {
    id: profile.id,
    email,
    full_name: profile.full_name,
    phone: profile.phone,
    role: profile.role,
    branch_id: profile.branch_id,
  }
}

function sessionPayload(session: Session, user: AuthUser) {
  return {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    token_type: 'bearer',
    expires_in: session.expires_in,
    expires_at: session.expires_at ?? null,
    user,
  }
}

/** Akun yang profilnya hilang atau nonaktif tidak boleh memegang sesi. */
async function revokeAndDeny(
  env: Bindings,
  session: Session,
  message: string,
): Promise<never> {
  await adminClient(env).auth.admin.signOut(session.access_token, 'local')
  throw forbidden(message)
}

export async function registerUser(env: Bindings, body: RegisterInput) {
  const { data, error } = await anonClient(env).auth.signUp({
    email: body.email,
    password: body.password,
    options: {
      data: {
        full_name: body.full_name,
        ...(body.phone ? { phone: body.phone } : {}),
      },
    },
  })

  if (error) {
    if (
      error.code === 'email_exists' ||
      error.code === 'user_already_exists' ||
      /already|registered/i.test(error.message)
    ) {
      throw new AppError(409, 'EMAIL_TAKEN', 'Email sudah terdaftar.')
    }

    if (isEmailRateLimited(error)) {
      throw new AppError(429, 'RATE_LIMITED', 'Terlalu banyak permintaan. Coba lagi sebentar.')
    }

    if (error.code === 'weak_password') {
      throw new AppError(
        400,
        'VALIDATION_ERROR',
        'Password terlalu lemah. Gunakan kombinasi yang lebih kuat.',
      )
    }

    console.error('signUp gagal:', error)
    if ((error.status ?? 500) < 500) {
      throw new AppError(
        400,
        'REGISTER_FAILED',
        'Pendaftaran ditolak. Periksa kembali email dan password kamu.',
      )
    }
    throw new AppError(500, 'INTERNAL_ERROR', 'Gagal membuat akun. Coba lagi nanti.')
  }

  if (data.user && (data.user.identities?.length ?? 0) === 0) {
    throw new AppError(409, 'EMAIL_TAKEN', 'Email sudah terdaftar.')
  }

  if (data.session) {
    console.error(
      'Supabase mengembalikan sesi saat signUp. Aktifkan "Confirm email" di Authentication > Providers > Email.',
    )
    throw new AppError(
      500,
      'INTERNAL_ERROR',
      'Verifikasi email belum dikonfigurasi di server.',
    )
  }

  return {
    message: 'Kode verifikasi sudah dikirim ke email kamu.',
    email: body.email,
  }
}

export async function verifyOtp(env: Bindings, email: string, code: string) {
  const { data, error } = await anonClient(env).auth.verifyOtp({
    email,
    token: code,
    type: 'signup',
  })

  if (error || !data.session || !data.user) {
    if (error?.status === 429) {
      throw new AppError(429, 'RATE_LIMITED', 'Terlalu banyak percobaan. Coba lagi sebentar.')
    }
    throw new AppError(400, 'INVALID_OTP', 'Kode salah atau sudah kedaluwarsa.')
  }

  const profile = await getProfile(adminClient(env), data.user.id)

  if (!profile) {
    console.error(
      'Profil tidak terbentuk setelah verifikasi. Pastikan 002_otp_register.sql sudah dijalankan.',
    )
    throw new AppError(
      500,
      'INTERNAL_ERROR',
      'Akun terverifikasi tetapi profil belum siap. Hubungi admin.',
    )
  }
  if (!profile.is_active) {
    return revokeAndDeny(env, data.session, 'Akun kamu sudah dinonaktifkan.')
  }

  return sessionPayload(data.session, toAuthUser(profile, data.user.email ?? email))
}

export async function resendOtp(env: Bindings, email: string) {
  const { error } = await anonClient(env).auth.resend({ type: 'signup', email })

  if (isEmailRateLimited(error)) {
    throw new AppError(429, 'RATE_LIMITED', 'Tunggu sebentar sebelum meminta kode lagi.')
  }
  if (error) console.error('resend gagal:', error)

  // Selalu sukses supaya tidak membocorkan email mana yang terdaftar.
  return {
    message: 'Jika email terdaftar dan belum diverifikasi, kode baru sudah dikirim.',
  }
}

export async function login(env: Bindings, email: string, password: string) {
  const { data, error } = await anonClient(env).auth.signInWithPassword({
    email,
    password,
  })

  if (error || !data.session || !data.user) {
    if (error?.code === 'email_not_confirmed') {
      throw new AppError(
        403,
        'EMAIL_NOT_VERIFIED',
        'Email kamu belum diverifikasi. Masukkan kode OTP yang dikirim ke email.',
      )
    }
    if (error?.status === 429) {
      throw new AppError(429, 'RATE_LIMITED', 'Terlalu banyak percobaan. Coba lagi sebentar.')
    }
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Email atau password salah.')
  }

  const profile = await getProfile(adminClient(env), data.user.id)
  if (!profile || !profile.is_active) {
    return revokeAndDeny(env, data.session, 'Akun tidak aktif atau profil tidak ditemukan.')
  }

  return sessionPayload(data.session, toAuthUser(profile, data.user.email ?? email))
}

export async function refreshSession(env: Bindings, refreshToken: string) {
  const { data, error } = await anonClient(env).auth.refreshSession({
    refresh_token: refreshToken,
  })

  if (error || !data.session || !data.user) {
    throw new AppError(401, 'UNAUTHORIZED', 'Sesi sudah berakhir, silakan login lagi.')
  }

  const profile = await getProfile(adminClient(env), data.user.id)
  if (!profile || !profile.is_active) {
    return revokeAndDeny(env, data.session, 'Akun tidak aktif atau profil tidak ditemukan.')
  }

  return sessionPayload(data.session, toAuthUser(profile, data.user.email ?? ''))
}

export async function logout(env: Bindings, token: string) {
  await adminClient(env).auth.admin.signOut(token, 'local')
  return { message: 'Berhasil logout.' }
}
