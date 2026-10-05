import { zValidator } from '@hono/zod-validator'
import type { Session } from '@supabase/supabase-js'
import { Hono } from 'hono'
import { z } from 'zod'
import { apiError } from '../lib/response'
import { adminClient, anonClient, getProfile } from '../lib/supabase'
import { requireAuth } from '../middleware/auth'
import type { AppEnv, AuthUser, Profile } from '../types'

const auth = new Hono<AppEnv>()

const emailField = z
  .string({ required_error: 'Email wajib diisi.' })
  .trim()
  .toLowerCase()
  .email('Format email tidak valid.')

const registerSchema = z.object({
  full_name: z
    .string({ required_error: 'Nama lengkap wajib diisi.' })
    .trim()
    .min(2, 'Nama lengkap minimal 2 karakter.')
    .max(100, 'Nama lengkap maksimal 100 karakter.'),
  email: emailField,
  password: z
    .string({ required_error: 'Password wajib diisi.' })
    .min(8, 'Password minimal 8 karakter.')
    .max(72, 'Password maksimal 72 karakter.'),
  phone: z
    .string()
    .trim()
    .min(8, 'Nomor HP minimal 8 digit.')
    .max(20, 'Nomor HP maksimal 20 karakter.')
    .optional(),
})

const loginSchema = z.object({
  email: emailField,
  password: z
    .string({ required_error: 'Password wajib diisi.' })
    .min(1, 'Password wajib diisi.'),
})

const verifySchema = z.object({
  email: emailField,
  code: z
    .string({ required_error: 'Kode verifikasi wajib diisi.' })
    .trim()
    .regex(/^\d{6,10}$/, 'Kode verifikasi harus berupa angka.'),
})

const resendSchema = z.object({ email: emailField })

const refreshSchema = z.object({
  refresh_token: z
    .string({ required_error: 'refresh_token wajib diisi.' })
    .min(1, 'refresh_token wajib diisi.'),
})

const validate = <T extends z.ZodTypeAny>(schema: T) =>
  zValidator('json', schema, (result, c) => {
    if (!result.success) {
      const message = result.error.issues[0]?.message ?? 'Data tidak valid.'
      return c.json(apiError('VALIDATION_ERROR', message), 400)
    }
  })

function toAuthUser(profile: Profile, email: string): AuthUser {
  return {
    id: profile.id,
    email,
    full_name: profile.full_name,
    phone: profile.phone,
    role: profile.role,
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

const isEmailRateLimited = (error: { status?: number; code?: string } | null) =>
  error?.status === 429 || error?.code === 'over_email_send_rate_limit'

auth.post('/register', validate(registerSchema), async (c) => {
  const body = c.req.valid('json')

  const { data, error } = await anonClient(c.env).auth.signUp({
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
      return c.json(apiError('EMAIL_TAKEN', 'Email sudah terdaftar.'), 409)
    }

    if (isEmailRateLimited(error)) {
      return c.json(
        apiError('RATE_LIMITED', 'Terlalu banyak permintaan. Coba lagi sebentar.'),
        429,
      )
    }

    if (error.code === 'weak_password') {
      return c.json(
        apiError('VALIDATION_ERROR', 'Password terlalu lemah. Gunakan kombinasi yang lebih kuat.'),
        400,
      )
    }

    console.error('signUp gagal:', error)
    const clientError = (error.status ?? 500) < 500
    return c.json(
      apiError(
        clientError ? 'REGISTER_FAILED' : 'INTERNAL_ERROR',
        clientError
          ? 'Pendaftaran ditolak. Periksa kembali email dan password kamu.'
          : 'Gagal membuat akun. Coba lagi nanti.',
      ),
      clientError ? 400 : 500,
    )
  }
  if (data.user && (data.user.identities?.length ?? 0) === 0) {
    return c.json(apiError('EMAIL_TAKEN', 'Email sudah terdaftar.'), 409)
  }

  if (data.session) {
    console.error(
      'Supabase mengembalikan sesi saat signUp. Aktifkan "Confirm email" di Authentication > Providers > Email.',
    )
    return c.json(
      apiError('INTERNAL_ERROR', 'Verifikasi email belum dikonfigurasi di server.'),
      500,
    )
  }

  return c.json(
    {
      message: 'Kode verifikasi sudah dikirim ke email kamu.',
      email: body.email,
    },
    201,
  )
})

auth.post('/verify', validate(verifySchema), async (c) => {
  const { email, code } = c.req.valid('json')

  const { data, error } = await anonClient(c.env).auth.verifyOtp({
    email,
    token: code,
    type: 'signup',
  })

  if (error || !data.session || !data.user) {
    if (error?.status === 429) {
      return c.json(
        apiError('RATE_LIMITED', 'Terlalu banyak percobaan. Coba lagi sebentar.'),
        429,
      )
    }
    return c.json(apiError('INVALID_OTP', 'Kode salah atau sudah kedaluwarsa.'), 400)
  }

  const admin = adminClient(c.env)
  const profile = await getProfile(admin, data.user.id)

  if (!profile) {
    console.error(
      'Profil tidak terbentuk setelah verifikasi. Pastikan 002_otp_register.sql sudah dijalankan.',
    )
    return c.json(
      apiError('INTERNAL_ERROR', 'Akun terverifikasi tetapi profil belum siap. Hubungi admin.'),
      500,
    )
  }

  if (!profile.is_active) {
    await admin.auth.admin.signOut(data.session.access_token, 'local')
    return c.json(apiError('FORBIDDEN', 'Akun kamu sudah dinonaktifkan.'), 403)
  }

  return c.json(
    sessionPayload(data.session, toAuthUser(profile, data.user.email ?? email)),
  )
})

auth.post('/resend', validate(resendSchema), async (c) => {
  const { email } = c.req.valid('json')

  const { error } = await anonClient(c.env).auth.resend({
    type: 'signup',
    email,
  })

  if (isEmailRateLimited(error)) {
    return c.json(
      apiError('RATE_LIMITED', 'Tunggu sebentar sebelum meminta kode lagi.'),
      429,
    )
  }

  if (error) console.error('resend gagal:', error)

  return c.json({
    message: 'Jika email terdaftar dan belum diverifikasi, kode baru sudah dikirim.',
  })
})

auth.post('/login', validate(loginSchema), async (c) => {
  const { email, password } = c.req.valid('json')

  const { data, error } = await anonClient(c.env).auth.signInWithPassword({
    email,
    password,
  })

  if (error || !data.session || !data.user) {
    if (error?.code === 'email_not_confirmed') {
      return c.json(
        apiError(
          'EMAIL_NOT_VERIFIED',
          'Email kamu belum diverifikasi. Masukkan kode OTP yang dikirim ke email.',
        ),
        403,
      )
    }
    if (error?.status === 429) {
      return c.json(
        apiError('RATE_LIMITED', 'Terlalu banyak percobaan. Coba lagi sebentar.'),
        429,
      )
    }
    return c.json(apiError('INVALID_CREDENTIALS', 'Email atau password salah.'), 401)
  }

  const admin = adminClient(c.env)
  const profile = await getProfile(admin, data.user.id)

  if (!profile || !profile.is_active) {
    await admin.auth.admin.signOut(data.session.access_token, 'local')
    return c.json(
      apiError('FORBIDDEN', 'Akun tidak aktif atau profil tidak ditemukan.'),
      403,
    )
  }

  return c.json(
    sessionPayload(data.session, toAuthUser(profile, data.user.email ?? email)),
  )
})

auth.post('/refresh', validate(refreshSchema), async (c) => {
  const { refresh_token } = c.req.valid('json')

  const { data, error } = await anonClient(c.env).auth.refreshSession({
    refresh_token,
  })

  if (error || !data.session || !data.user) {
    return c.json(
      apiError('UNAUTHORIZED', 'Sesi sudah berakhir, silakan login lagi.'),
      401,
    )
  }

  const admin = adminClient(c.env)
  const profile = await getProfile(admin, data.user.id)

  if (!profile || !profile.is_active) {
    await admin.auth.admin.signOut(data.session.access_token, 'local')
    return c.json(
      apiError('FORBIDDEN', 'Akun tidak aktif atau profil tidak ditemukan.'),
      403,
    )
  }

  return c.json(
    sessionPayload(data.session, toAuthUser(profile, data.user.email ?? '')),
  )
})

auth.get('/me', requireAuth, (c) => {
  return c.json({ user: c.get('user') })
})

auth.post('/logout', requireAuth, async (c) => {
  await adminClient(c.env).auth.admin.signOut(c.get('token'), 'local')
  return c.json({ message: 'Berhasil logout.' })
})

export default auth
