import { ValidationError } from './validate'

export const VEHICLE_TYPES = ['bus', 'medium', 'kecil'] as const

export type VehicleType = (typeof VEHICLE_TYPES)[number]

export const VEHICLE_LABELS: Record<VehicleType, string> = {
  bus: 'Bus',
  medium: 'Mobil Medium/Elf',
  kecil: 'Mobil Kecil',
}

export function isVehicleType(v: unknown): v is VehicleType {
  return typeof v === 'string' && (VEHICLE_TYPES as readonly string[]).includes(v)
}

/** undefined dibiarkan lolos (artinya tidak diubah). Nilai lain harus valid. */
export function parseVehicleType(v: unknown): VehicleType | undefined {
  if (v === undefined) return undefined
  if (!isVehicleType(v)) {
    throw new ValidationError('Jenis kendaraan harus bus, medium, atau kecil.')
  }
  return v
}
