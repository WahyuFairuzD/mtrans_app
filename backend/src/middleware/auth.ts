import { createMiddleware } from 'hono/factory'
import { apiError } from '../lib/response'
import { adminClient, getProfile } from '../lib/supabase'
import type { AppEnv, Role } from '../types'

export const requireAuth = createMiddleware<AppEnv>(async (c, next) => {
  const header = c.req.header('Authorization') ?? ''
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : ''

  if (!token) {
    return c.json(apiError('UNAUTHORIZED', 'Token tidak ditemukan.'), 401)
  }

  const admin = adminClient(c.env)
  const { data, error } = await admin.auth.getUser(token)

  if (error || !data.user) {
    return c.json(
      apiError('UNAUTHORIZED', 'Sesi tidak valid atau sudah berakhir.'),
      401,
    )
  }

  const profile = await getProfile(admin, data.user.id)

  if (!profile) {
    return c.json(apiError('FORBIDDEN', 'Profil pengguna tidak ditemukan.'), 403)
  }
  if (!profile.is_active) {
    return c.json(apiError('FORBIDDEN', 'Akun kamu sudah dinonaktifkan.'), 403)
  }

  c.set('token', token)
  c.set('user', {
    id: profile.id,
    email: data.user.email ?? '',
    full_name: profile.full_name,
    phone: profile.phone,
    role: profile.role,
  })

  await next()
})

export const requireRole = (...roles: Role[]) =>
  createMiddleware<AppEnv>(async (c, next) => {
    const user = c.get('user')

    if (!roles.includes(user.role)) {
      return c.json(
        apiError('FORBIDDEN', 'Kamu tidak punya akses ke fitur ini.'),
        403,
      )
    }

    await next()
  })
