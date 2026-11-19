import { internal } from '../lib/errors'
import type { Db } from '../lib/supabase'
import { VEHICLE_TYPES, type VehicleType } from '../lib/vehicle'
import type { AuthUser } from '../types'

export type Prices = Record<VehicleType, number>

export async function getPrices(db: Db): Promise<Prices> {
  const { data, error } = await db
    .from('vehicle_prices')
    .select('vehicle_type, price')
  if (error) throw internal(error, 'Gagal mengambil daftar harga.')

  const prices = {} as Prices
  for (const row of (data ?? []) as { vehicle_type: VehicleType; price: number }[]) {
    prices[row.vehicle_type] = row.price
  }
  for (const type of VEHICLE_TYPES) {
    if (typeof prices[type] !== 'number') {
      throw internal(`harga ${type} belum ada`, 'Daftar harga belum lengkap. Hubungi administrator.')
    }
  }
  return prices
}

/**
 * Harga baru hanya berlaku untuk invoice berikutnya: isi invoice yang sudah
 * dibuat dibekukan bersama harganya.
 */
export async function updatePrices(db: Db, user: AuthUser, prices: Prices) {
  const now = new Date().toISOString()
  const rows = VEHICLE_TYPES.map((type) => ({
    vehicle_type: type,
    price: prices[type],
    updated_by: user.id,
    updated_at: now,
  }))

  const { error } = await db
    .from('vehicle_prices')
    .upsert(rows, { onConflict: 'vehicle_type' })
  if (error) throw internal(error, 'Gagal menyimpan harga.')

  return getPrices(db)
}
