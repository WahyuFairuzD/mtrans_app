import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { HTTPException } from 'hono/http-exception'
import { apiError } from './lib/response'
import { ValidationError } from './lib/validate'
import auth from './routes/auth'
import jobs from './routes/jobs'
import lookups from './routes/lookups'
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
app.route('/units', units)
app.route('/jobs', jobs)
app.route('/', lookups)

app.notFound((c) => c.json(apiError('NOT_FOUND', 'Endpoint tidak ditemukan.'), 404))

app.onError((err, c) => {
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