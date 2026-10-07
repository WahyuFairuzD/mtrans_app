import type { Context } from 'hono'
import { HTTPException } from 'hono/http-exception'
import type { AppEnv } from '../types'

export const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const isoWithZone = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$/

export class ValidationError extends Error {}

export type JsonObject = Record<string, unknown>

export async function readJson(c: Context<AppEnv>): Promise<JsonObject> {
  let raw: unknown
  try {
    raw = await c.req.json()
  } catch {
    throw new HTTPException(400, { message: 'Format JSON tidak valid.' })
  }
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new HTTPException(400, { message: 'Body harus berupa objek JSON.' })
  }
  return raw as JsonObject
}

type TextOpts = { min?: number; max: number }

export function text(
  v: unknown,
  label: string,
  opts: TextOpts,
): string | null | undefined {
  if (v === undefined) return undefined
  if (v === null) return null
  if (typeof v !== 'string') {
    throw new ValidationError(`${label} harus berupa teks.`)
  }
  const s = v.trim()
  if (s === '') return null
  if (opts.min !== undefined && s.length < opts.min) {
    throw new ValidationError(`${label} minimal ${opts.min} karakter.`)
  }
  if (s.length > opts.max) {
    throw new ValidationError(`${label} maksimal ${opts.max} karakter.`)
  }
  return s
}

export function requiredText(v: unknown, label: string, opts: TextOpts): string {
  const s = text(v, label, opts)
  if (s === undefined || s === null) {
    throw new ValidationError(`${label} wajib diisi.`)
  }
  return s
}

export function requiredUuid(v: unknown, label: string): string {
  if (v === undefined || v === null || v === '') {
    throw new ValidationError(`${label} wajib diisi.`)
  }
  if (typeof v !== 'string' || !uuidPattern.test(v)) {
    throw new ValidationError(`${label} tidak valid.`)
  }
  return v
}

export function optionalUuid(v: unknown, label: string): string | undefined {
  if (v === undefined || v === null || v === '') return undefined
  return requiredUuid(v, label)
}

export function intValue(
  v: unknown,
  label: string,
  opts: { min?: number; max?: number } = {},
): number | null | undefined {
  if (v === undefined) return undefined
  if (v === null) return null
  if (typeof v !== 'number' || !Number.isInteger(v)) {
    throw new ValidationError(`${label} harus berupa bilangan bulat.`)
  }
  if (opts.min !== undefined && v < opts.min) {
    throw new ValidationError(`${label} minimal ${opts.min}.`)
  }
  if (opts.max !== undefined && v > opts.max) {
    throw new ValidationError(`${label} maksimal ${opts.max}.`)
  }
  return v
}

export function intQuery(
  v: string | undefined,
  label: string,
  def: number,
  min: number,
  max: number,
): number {
  if (v === undefined || v === '') return def
  const n = Number(v)
  if (!Number.isInteger(n) || n < min || n > max) {
    throw new ValidationError(`${label} harus berupa angka ${min}-${max}.`)
  }
  return n
}

export function boolValue(v: unknown, label: string): boolean | undefined {
  if (v === undefined) return undefined
  if (typeof v !== 'boolean') {
    throw new ValidationError(`${label} harus berupa true atau false.`)
  }
  return v
}

export function isoDateTime(v: unknown, label: string): string | undefined {
  if (v === undefined || v === null || v === '') return undefined
  if (typeof v !== 'string' || !isoWithZone.test(v) || Number.isNaN(Date.parse(v))) {
    throw new ValidationError(`Format ${label} tidak valid.`)
  }
  return v
}

export function compact<T extends Record<string, unknown>>(o: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(o).filter(([, value]) => value !== undefined),
  ) as Partial<T>
}

export function safeLike(q: string): string {
  return q.replace(/[%_,()\\]/g, '')
}