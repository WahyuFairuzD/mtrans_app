import { dbError } from '../lib/db'
import { conflict, notFound } from '../lib/errors'
import type { Db } from '../lib/supabase'
import type { AuthUser } from '../types'
import { findAccessibleJob, jobNotFound, loadJobDetail } from './jobs.service'

export const INSPECTION_RESULTS = ['bersih', 'cukup', 'kurang']

const CHECKLIST_COLUMNS = 'id, label, is_required, sort_order, is_done, checked_at'

const checklistNotFound = () => notFound('Item checklist tidak ditemukan.')

// 'menunggu_dikerjakan' hanya untuk data lama dari alur penugasan yang sudah dihapus.
const START_FROM = ['terdaftar', 'menunggu_dikerjakan']

type Transition = { from: string; to: string; wrongState: string }

async function transition(db: Db, user: AuthUser, id: string, t: Transition) {
  const job = await findAccessibleJob(db, id, user)
  if (job.status !== t.from) throw conflict(t.wrongState)

  const { data, error } = await db
    .from('wash_jobs')
    .update({ status: t.to, updated_by: user.id })
    .eq('id', id)
    .eq('status', t.from)
    .select('id')
    .maybeSingle()

  if (error) throw dbError(error, 'Gagal mengubah status pekerjaan.')
  if (!data) throw conflict('Status pekerjaan sudah berubah. Muat ulang data.')

  return loadJobDetail(db, id)
}

/**
 * Pengawas memulai pekerjaan. Checklist disalin oleh trigger database saat
 * status menjadi dalam_pengerjaan. Pengawas dicatat sebagai pelaksana
 * (job_assignees) supaya namanya tampil di kartu dan riwayat.
 */
export async function startJob(db: Db, user: AuthUser, id: string) {
  const job = await findAccessibleJob(db, id, user)
  if (!START_FROM.includes(job.status)) {
    throw conflict('Pekerjaan hanya bisa dimulai saat status Terdaftar.')
  }

  const { data, error } = await db
    .from('wash_jobs')
    .update({ status: 'dalam_pengerjaan', updated_by: user.id })
    .eq('id', id)
    .in('status', START_FROM)
    .select('id')
    .maybeSingle()

  if (error) throw dbError(error, 'Gagal mengubah status pekerjaan.')
  if (!data) throw conflict('Status pekerjaan sudah berubah. Muat ulang data.')

  const { error: assigneeError } = await db
    .from('job_assignees')
    .upsert(
      { job_id: id, pegawai_id: user.id },
      { onConflict: 'job_id,pegawai_id', ignoreDuplicates: true },
    )
  if (assigneeError) {
    throw dbError(assigneeError, 'Pekerjaan dimulai, tetapi gagal mencatat pelaksana.')
  }

  return loadJobDetail(db, id)
}

export const finishJob = (db: Db, user: AuthUser, id: string) =>
  transition(db, user, id, {
    from: 'dalam_pengerjaan',
    to: 'menunggu_pemeriksaan',
    wrongState: 'Pekerjaan hanya bisa diselesaikan saat status Dalam Pengerjaan.',
  })

export const recordExit = (db: Db, user: AuthUser, id: string) =>
  transition(db, user, id, {
    from: 'selesai',
    to: 'unit_keluar',
    wrongState: 'Unit hanya bisa dicatat keluar setelah pekerjaan Selesai.',
  })

export async function submitInspection(
  db: Db,
  user: AuthUser,
  id: string,
  input: { result: string; notes: string | null },
) {
  const job = await findAccessibleJob(db, id, user)
  if (job.status !== 'menunggu_pemeriksaan') {
    throw conflict('Pemeriksaan hanya bisa dilakukan saat status Menunggu Pemeriksaan.')
  }

  const { error } = await db.from('inspections').insert({
    job_id: id,
    inspector_id: user.id,
    result: input.result,
    notes: input.notes,
  })

  if (error) {
    if (error.code === '23505') throw conflict('Pekerjaan ini sudah diperiksa.')
    throw dbError(error, 'Gagal menyimpan hasil pemeriksaan.')
  }

  return loadJobDetail(db, id)
}

export async function listChecklist(db: Db, user: AuthUser, jobId: string) {
  await findAccessibleJob(db, jobId, user)

  const { data, error } = await db
    .from('job_checklist_items')
    .select(CHECKLIST_COLUMNS)
    .eq('job_id', jobId)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true })

  if (error) throw dbError(error, 'Gagal mengambil checklist.')
  return data ?? []
}

export async function setChecklistItem(
  db: Db,
  user: AuthUser,
  jobId: string,
  itemId: string,
  isDone: boolean,
) {
  const job = await findAccessibleJob(db, jobId, user)
  if (job.status !== 'dalam_pengerjaan') {
    throw conflict('Checklist hanya bisa diubah saat status Dalam Pengerjaan.')
  }

  const { data, error } = await db
    .from('job_checklist_items')
    .update({
      is_done: isDone,
      checked_by: isDone ? user.id : null,
      checked_at: isDone ? new Date().toISOString() : null,
    })
    .eq('id', itemId)
    .eq('job_id', jobId)
    .select(CHECKLIST_COLUMNS)
    .maybeSingle()

  if (error) throw dbError(error, 'Gagal menyimpan checklist.')
  if (!data) throw checklistNotFound()
  return data
}

export { checklistNotFound, jobNotFound }
