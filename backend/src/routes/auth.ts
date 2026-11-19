import { zValidator } from '@hono/zod-validator'
import { Hono } from 'hono'
import { z } from 'zod'
import { apiError } from '../lib/response'
import { requireAuth } from '../middleware/auth'
import {
  login,
  logout,
  refreshSession,
  registerUser,
  resendOtp,
  verifyOtp,
} from '../services/auth.service'
import type { AppEnv } from '../types'

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

auth.post('/register', validate(registerSchema), async (c) => {
  const result = await registerUser(c.env, c.req.valid('json'))
  return c.json(result, 201)
})

auth.post('/verify', validate(verifySchema), async (c) => {
  const { email, code } = c.req.valid('json')
  return c.json(await verifyOtp(c.env, email, code))
})

auth.post('/resend', validate(resendSchema), async (c) => {
  const { email } = c.req.valid('json')
  return c.json(await resendOtp(c.env, email))
})

auth.post('/login', validate(loginSchema), async (c) => {
  const { email, password } = c.req.valid('json')
  return c.json(await login(c.env, email, password))
})

auth.post('/refresh', validate(refreshSchema), async (c) => {
  const { refresh_token } = c.req.valid('json')
  return c.json(await refreshSession(c.env, refresh_token))
})

auth.get('/me', requireAuth, (c) => c.json({ user: c.get('user') }))

auth.post('/logout', requireAuth, async (c) => {
  return c.json(await logout(c.env, c.get('token')))
})

export default auth
