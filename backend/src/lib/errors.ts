import type { ContentfulStatusCode } from 'hono/utils/http-status'

export class AppError extends Error {
  readonly status: ContentfulStatusCode
  readonly code: string

  constructor(status: ContentfulStatusCode, code: string, message: string) {
    super(message)
    this.status = status
    this.code = code
  }
}

export const notFound = (message: string) =>
  new AppError(404, 'NOT_FOUND', message)

export const conflict = (message: string, code = 'CONFLICT') =>
  new AppError(409, code, message)

export const forbidden = (message: string) =>
  new AppError(403, 'FORBIDDEN', message)

export const tooLarge = (message: string) =>
  new AppError(413, 'PAYLOAD_TOO_LARGE', message)

export function internal(cause: unknown, message: string): AppError {
  console.error(cause)
  return new AppError(500, 'INTERNAL_ERROR', message)
}
