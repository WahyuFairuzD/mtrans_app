import { Hono } from 'hono'
import { notFound, tooLarge } from '../lib/errors'
import { requireUuid } from '../lib/http'
import { adminClient } from '../lib/supabase'
import {
  formNumber,
  optionalBranchId,
  optionalFormNumber,
  requiredBranchId,
  ValidationError,
} from '../lib/validate'
import { requireAuth, requireRole } from '../middleware/auth'
import {
  getAttendancePhoto,
  listMine,
  listToday,
  submitAttendance,
  type AttendanceType,
} from '../services/attendance.service'
import type { AppEnv } from '../types'

const attendance = new Hono<AppEnv>()
attendance.use('*', requireAuth)

const MAX_PHOTO_BYTES = 1024 * 1024
const PHOTO_TOO_LARGE = 'Ukuran foto maksimal 1 MB.'

function isJpeg(bytes: ArrayBuffer): boolean {
  if (bytes.byteLength < 3) return false
  const head = new Uint8Array(bytes, 0, 3)
  return head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff
}

attendance.get('/me/today', requireRole('pegawai', 'pengawas'), async (c) => {
  const data = await listMine(adminClient(c.env), c.get('user').id)
  return c.json({ data })
})

attendance.get('/today', requireRole('owner'), async (c) => {
  const branchId = optionalBranchId(c.req.query('branch_id'))
  const data = await listToday(adminClient(c.env), branchId)
  return c.json({ data })
})

attendance.post('/', requireRole('pegawai', 'pengawas'), async (c) => {
  const user = c.get('user')

  const declaredLength = Number(c.req.header('content-length') ?? 0)
  if (declaredLength > MAX_PHOTO_BYTES + 64 * 1024) throw tooLarge(PHOTO_TOO_LARGE)

  const form = await c.req.parseBody()

  const type = form['type']
  if (type !== 'masuk' && type !== 'pulang') {
    throw new ValidationError('Jenis absensi harus masuk atau pulang.')
  }

  const file = form['photo']
  if (!(file instanceof File) || file.size === 0) {
    throw new ValidationError('Foto absensi wajib diunggah.')
  }
  if (file.size > MAX_PHOTO_BYTES) throw tooLarge(PHOTO_TOO_LARGE)
  if (file.type !== 'image/jpeg') {
    throw new ValidationError('Foto absensi harus berformat JPEG.')
  }

  const latitude = formNumber(form['latitude'], 'Koordinat latitude')
  const longitude = formNumber(form['longitude'], 'Koordinat longitude')
  if (latitude < -90 || latitude > 90) {
    throw new ValidationError('Koordinat latitude tidak valid.')
  }
  if (longitude < -180 || longitude > 180) {
    throw new ValidationError('Koordinat longitude tidak valid.')
  }
  const accuracyM = optionalFormNumber(form['accuracy_m'], 'Akurasi GPS')
  if (accuracyM !== null && accuracyM < 0) {
    throw new ValidationError('Akurasi GPS tidak valid.')
  }

  const photo = await file.arrayBuffer()
  if (!isJpeg(photo)) {
    throw new ValidationError('Foto absensi harus berformat JPEG.')
  }

  const branchId =
    user.role === 'pengawas' ? undefined : requiredBranchId(form['branch_id'])

  const record = await submitAttendance(adminClient(c.env), c.env.PHOTOS, user, {
    type: type as AttendanceType,
    branchId,
    latitude,
    longitude,
    accuracyM,
    photo,
  })

  return c.json(
    { message: `Absen ${type} berhasil dicatat.`, attendance: record },
    201,
  )
})

attendance.get('/:id/photo', async (c) => {
  const id = requireUuid(c.req.param('id'), () =>
    notFound('Absensi tidak ditemukan.'),
  )
  const object = await getAttendancePhoto(
    adminClient(c.env),
    c.env.PHOTOS,
    c.get('user'),
    id,
  )

  const headers = new Headers()
  object.writeHttpMetadata(headers)
  headers.set('etag', object.httpEtag)
  headers.set('Cache-Control', 'private, max-age=3600')
  headers.set('X-Content-Type-Options', 'nosniff')

  return new Response(object.body, { headers })
})

export default attendance
