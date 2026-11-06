export const WIB_OFFSET_MS = 7 * 60 * 60 * 1000
const DAY_MS = 24 * 60 * 60 * 1000

/** Tanggal hari ini di WIB, format YYYY-MM-DD. */
export function todayWib(): string {
  return new Date(Date.now() + WIB_OFFSET_MS).toISOString().slice(0, 10)
}

/** Batas awal (inklusif) dan akhir (eksklusif) hari ini di WIB, dalam ISO UTC. */
export function todayRangeWib(): { from: string; to: string } {
  const wibNow = new Date(Date.now() + WIB_OFFSET_MS)
  const startUtc =
    Date.UTC(wibNow.getUTCFullYear(), wibNow.getUTCMonth(), wibNow.getUTCDate()) -
    WIB_OFFSET_MS
  return {
    from: new Date(startUtc).toISOString(),
    to: new Date(startUtc + DAY_MS).toISOString(),
  }
}

/** Tanggal WIB (YYYY-MM-DD) dari waktu ISO. */
export function wibDateOf(iso: string): string {
  return new Date(Date.parse(iso) + WIB_OFFSET_MS).toISOString().slice(0, 10)
}

/** Jam WIB (HH:mm) dari waktu ISO. */
export function wibClockOf(iso: string): string {
  return new Date(Date.parse(iso) + WIB_OFFSET_MS).toISOString().slice(11, 16)
}
