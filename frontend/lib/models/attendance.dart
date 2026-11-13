import 'dart:math' as math;

/// Batas jarak absen dari kantor cabang (meter). Nilai resmi dan penegakannya
/// ada di backend (lib/offices.ts); konstanta ini hanya untuk label tampilan.
const kAttendanceMaxDistanceM = 100.0;

enum AttendanceType {
  masuk('masuk', 'Absen Masuk'),
  pulang('pulang', 'Absen Pulang');

  const AttendanceType(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

String attendanceRoleLabel(String role) =>
    role == 'pengawas' ? 'Pengawas' : 'Petugas Cuci';

class AttendancePerson {
  const AttendancePerson({
    required this.id,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String fullName;
  final String role;

  factory AttendancePerson.fromJson(Map<String, dynamic> json) {
    return AttendancePerson(
      id: json['id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
    );
  }
}

/// Titik kantor satu cabang (dari GET /attendance/offices).
class BranchOffice {
  const BranchOffice({
    required this.branchId,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final int branchId;
  final String name;
  final double latitude;
  final double longitude;

  factory BranchOffice.fromJson(Map<String, dynamic> json) {
    return BranchOffice(
      branchId: (json['branch_id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class AttendanceOffices {
  const AttendanceOffices({required this.maxDistanceM, required this.offices});

  final double maxDistanceM;
  final List<BranchOffice> offices;

  factory AttendanceOffices.fromJson(Map<String, dynamic> json) {
    return AttendanceOffices(
      maxDistanceM:
          (json['max_distance_m'] as num?)?.toDouble() ?? kAttendanceMaxDistanceM,
      offices: (json['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(BranchOffice.fromJson)
          .toList(),
    );
  }

  BranchOffice? officeOf(int branchId) {
    for (final office in offices) {
      if (office.branchId == branchId) return office;
    }
    return null;
  }
}

/// Jarak dua titik (meter) dengan rumus Haversine. Sama dengan rumus di backend.
double distanceBetweenMeters(
  double aLat,
  double aLng,
  double bLat,
  double bLng,
) {
  const earthRadiusM = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(bLat - aLat);
  final dLng = rad(bLng - aLng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(aLat)) *
          math.cos(rad(bLat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
}

String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

String outOfRangeMessage({
  required String officeName,
  required double distanceM,
  required double maxM,
}) =>
    'Kamu berada sekitar ${formatDistance(distanceM)} dari kantor $officeName. '
    'Absen dan foto harus dilakukan di kantor (maksimal ${maxM.round()} m).';

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.branchId,
    required this.type,
    required this.attendedAt,
    required this.workDate,
    required this.latitude,
    required this.longitude,
    required this.fullName,
    required this.role,
    required this.branchName,
    this.accuracyM,
    this.distanceM,
  });

  final String id;
  final String userId;
  final int branchId;
  final AttendanceType type;

  /// Selalu UTC. Tampilkan dengan wibTime() dari utils/wib.dart.
  final DateTime attendedAt;
  final String workDate;
  final double latitude;
  final double longitude;
  final double? accuracyM;

  /// Jarak titik absen ke kantor cabang (meter), dihitung backend. Null bila
  /// titik kantor cabang belum diatur.
  final double? distanceM;
  final String fullName;
  final String role;
  final String branchName;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;
    final type = AttendanceType.values.firstWhere(
      (value) => value.apiValue == rawType,
      orElse: () => AttendanceType.masuk,
    );
    return AttendanceRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      branchId: (json['branch_id'] as num).toInt(),
      type: type,
      attendedAt: DateTime.parse(json['attended_at'] as String).toUtc(),
      workDate: json['work_date'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      distanceM: (json['distance_m'] as num?)?.toDouble(),
      fullName: (json['full_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      branchName: (json['branch_name'] as String?) ?? '',
    );
  }
}
