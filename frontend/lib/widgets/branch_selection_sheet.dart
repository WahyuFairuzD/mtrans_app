import 'package:flutter/material.dart';

import '../models/branch.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/master_service.dart';
import '../theme/app_theme.dart';

/// Lembar pilihan cabang. Mengembalikan id cabang, atau null bila ditutup.
Future<int?> pickBranch(
  BuildContext context, {
  required String title,
  required String subtitle,
}) async {
  List<Branch> branches;
  try {
    branches = await MasterService.instance.fetchBranches();
  } on ApiException catch (error) {
    throw AuthException(error.message);
  }
  if (!context.mounted) return null;
  if (branches.isEmpty) {
    throw const AuthException(
      'Daftar cabang belum tersedia. Hubungi administrator.',
    );
  }

  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ...branches.map(
              (branch) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(branch.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, branch.id),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pilihan cabang untuk absensi Petugas.
Future<int?> selectAttendanceBranch(BuildContext context) => pickBranch(
  context,
  title: 'Pilih Cabang Absensi',
  subtitle: 'Cabang ini digunakan untuk absen masuk dan pulang hari ini.',
);
