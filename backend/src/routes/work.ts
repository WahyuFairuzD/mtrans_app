import { Hono } from 'hono'
import { requireUuid } from '../lib/http'
import { adminClient } from '../lib/supabase'
import { boolValue, readJson, text, ValidationError } from '../lib/validate'
import { requireRole } from '../middleware/auth'
import {
  checklistNotFound,
  finishJob,
  INSPECTION_RESULTS,
  jobNotFound,
  listChecklist,
  recordExit,
  setChecklistItem,
  startJob,
  submitInspection,
} from '../services/work.service'
import type { AppEnv } from '../types'

const work = new Hono<AppEnv>()

work.post('/:id/start', requireRole('pegawai'), async (c) => {
  const id = requireUuid(c.req.param('id'), jobNotFound)
  const job = await startJob(adminClient(c.env), c.get('user'), id)
  return c.json({ message: 'Pekerjaan dimulai.', job })
})

work.post('/:id/finish', requireRole('pegawai'), async (c) => {
  const id = requireUuid(c.req.param('id'), jobNotFound)
  const job = await finishJob(adminClient(c.env), c.get('user'), id)
  return c.json({ message: 'Pekerjaan selesai dan menunggu pemeriksaan.', job })
})

work.post('/:id/inspection', requireRole('pengawas'), async (c) => {
  const id = requireUuid(c.req.param('id'), jobNotFound)
  const raw = await readJson(c)

  const result = raw.result
  if (typeof result !== 'string' || !INSPECTION_RESULTS.includes(result)) {
    throw new ValidationError('Hasil pemeriksaan tidak valid.')
  }
  const notes = text(raw.notes, 'Catatan pemeriksaan', { max: 500 }) ?? null

  const job = await submitInspection(adminClient(c.env), c.get('user'), id, {
    result,
    notes,
  })
  return c.json({ message: 'Hasil pemeriksaan tersimpan.', job })
})

work.post('/:id/exit', requireRole('pengawas'), async (c) => {
  const id = requireUuid(c.req.param('id'), jobNotFound)
  const job = await recordExit(adminClient(c.env), c.get('user'), id)
  return c.json({ message: 'Unit keluar dicatat.', job })
})

work.get('/:id/checklist', async (c) => {
  const id = requireUuid(c.req.param('id'), jobNotFound)
  const data = await listChecklist(adminClient(c.env), c.get('user'), id)
  return c.json({ data })
})

work.patch('/:id/checklist/:itemId', requireRole('pegawai'), async (c) => {
  const id = requireUuid(c.req.param('id'), jobNotFound)
  const itemId = requireUuid(c.req.param('itemId'), checklistNotFound)

  const raw = await readJson(c)
  const isDone = boolValue(raw.is_done, 'is_done')
  if (isDone === undefined) {
    throw new ValidationError('Status centang wajib diisi.')
  }

  const item = await setChecklistItem(
    adminClient(c.env),
    c.get('user'),
    id,
    itemId,
    isDone,
  )
  return c.json({ item })
})

export default work
