import 'app_user.dart';

/// Akun Pengawas atau Petugas Cuci yang dikelola Owner.
class StaffAccount {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole role;
  final int? branchId;
  final bool isActive;

  const StaffAccount({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.phone,
    this.branchId,
  });

  factory StaffAccount.fromJson(Map<String, dynamic> j) {
    return StaffAccount(
      id: j['id'] as String,
      email: (j['email'] as String?) ?? '',
      fullName: (j['full_name'] as String?) ?? '',
      phone: j['phone'] as String?,
      role: UserRole.fromString(j['role'] as String?),
      branchId: (j['branch_id'] as num?)?.toInt(),
      isActive: (j['is_active'] as bool?) ?? true,
    );
  }
}
