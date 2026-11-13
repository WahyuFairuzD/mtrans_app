/**
 * Titik kantor tiap cabang untuk validasi jarak absensi.
 * Koordinat diambil dari pin Google Maps kantor masing-masing.
 * Kantor tidak berpindah, jadi sengaja di-hardcode (ubah di sini lalu deploy ulang).
 */

/** Jarak maksimal (meter) dari titik kantor agar absen diterima. */
export const ATTENDANCE_MAX_DISTANCE_M = 100

export type BranchOffice = {
  branch_id: number
  name: string
  latitude: number
  longitude: number
}

export const BRANCH_OFFICES: readonly BranchOffice[] = [
  { branch_id: 1, name: 'Suhat', latitude: -7.9459335, longitude: 112.6181617 },
  { branch_id: 2, name: 'Panjen', latitude: -8.1218184, longitude: 112.5545461 },
  { branch_id: 3, name: 'Arjosari', latitude: -7.9303816, longitude: 112.6517062 },
]

export function findBranchOffice(branchId: number): BranchOffice | undefined {
  return BRANCH_OFFICES.find((office) => office.branch_id === branchId)
}

const EARTH_RADIUS_M = 6_371_000
const toRad = (deg: number) => (deg * Math.PI) / 180

/** Jarak dua titik (meter) dengan rumus Haversine. */
export function distanceMeters(
  aLat: number,
  aLng: number,
  bLat: number,
  bLng: number,
): number {
  const dLat = toRad(bLat - aLat)
  const dLng = toRad(bLng - aLng)
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)))
}

/** Jarak titik ke kantor cabang, atau null bila titik kantor cabang belum diatur. */
export function distanceToOffice(
  branchId: number,
  latitude: number,
  longitude: number,
): number | null {
  const office = findBranchOffice(branchId)
  if (!office) return null
  return distanceMeters(latitude, longitude, office.latitude, office.longitude)
}

export function formatDistance(meters: number): string {
  return meters < 1000
    ? `${Math.round(meters)} m`
    : `${(meters / 1000).toFixed(1)} km`
}
