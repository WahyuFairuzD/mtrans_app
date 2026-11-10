enum AttendanceType {
  masuk('masuk', 'Absen Masuk'),
  pulang('pulang', 'Absen Pulang');

  const AttendanceType(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

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
      fullName: (json['full_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      branchName: (json['branch_name'] as String?) ?? '',
    );
  }
}
