import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { HTTPException } from 'hono/http-exception'
import { AppError } from './lib/errors'
import { apiError } from './lib/response'
import { ValidationError } from './lib/validate'
import attendance from './routes/attendance'
import auth from './routes/auth'
import invoices from './routes/invoices'
import jobs from './routes/jobs'
import lookups from './routes/lookups'
import prices from './routes/prices'
import stock from './routes/stock'
import units from './routes/units'
import type { AppEnv } from './types'

const app = new Hono<AppEnv>()

app.use(
  '*',
  cors({
    origin: '*',
    allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Authorization', 'Content-Type'],
    maxAge: 86400,
  }),
)

app.get('/', (c) => c.json({ name: 'mtrans-api', status: 'ok' }))

app.route('/auth', auth)
app.route('/attendance', attendance)
app.route('/units', units)
app.route('/jobs', jobs)
app.route('/stock', stock)
app.route('/prices', prices)
app.route('/invoices', invoices)
app.route('/', lookups)

app.notFound((c) => c.json(apiError('NOT_FOUND', 'Endpoint tidak ditemukan.'), 404))

// Semua kegagalan dari route dan service berakhir di sini.
app.onError((err, c) => {
  if (err instanceof AppError) {
    return c.json(apiError(err.code, err.message), err.status)
  }
  if (err instanceof ValidationError) {
    return c.json(apiError('VALIDATION_ERROR', err.message), 400)
  }
  if (err instanceof HTTPException) {
    return c.json(apiError('BAD_REQUEST', err.message), err.status)
  }
  console.error(err)
  return c.json(apiError('INTERNAL_ERROR', 'Terjadi kesalahan pada server.'), 500)
})

export default app
