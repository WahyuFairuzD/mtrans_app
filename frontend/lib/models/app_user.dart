enum UserRole {
  owner,
  pengawas,
  pengawasOperational,
  pegawai;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.apiValue == value,
      orElse: () => UserRole.pegawai,
    );
  }

  /// Nilai yang dikirim ke API (snake_case, sama dengan nama enum di database).
  String get apiValue => switch (this) {
    UserRole.owner => 'owner',
    UserRole.pengawas => 'pengawas',
    UserRole.pengawasOperational => 'pengawas_operational',
    UserRole.pegawai => 'pegawai',
  };

  String get label {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.pengawas:
        return 'Pengawas';
      case UserRole.pengawasOperational:
        return 'Pengawas Operational';
      case UserRole.pegawai:
        return 'Petugas Cuci';
    }
  }
}

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole role;
  final int? branchId;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.branchId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      branchId: (json['branch_id'] as num?)?.toInt(),
    );
  }
}
