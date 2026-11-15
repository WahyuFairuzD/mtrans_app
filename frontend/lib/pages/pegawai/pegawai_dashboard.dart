import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/master_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/attendance_history_view.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../../widgets/entry_card.dart';
import '../attendance/attendance_page.dart';

/// Beranda Petugas: data diri, absen, dan riwayat absen sendiri.
/// Petugas tidak lagi punya alur pekerjaan bus (dipegang Pengawas).
class PegawaiDashboard extends StatefulWidget {
  const PegawaiDashboard({super.key});

  @override
  State<PegawaiDashboard> createState() => _PegawaiDashboardState();
}

class _PegawaiDashboardState extends State<PegawaiDashboard> {
  List<Branch> _branches = [];
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await MasterService.instance.fetchBranches();
      if (!mounted) return;
      setState(() => _branches = branches);
    } catch (_) {
      // Nama cabang hanya tampilan; tanpa itu cukup ditampilkan "-".
    }
  }

  Future<void> _refresh() async {
    setState(() => _reloadToken++);
    await _loadBranches();
  }

  Future<void> _openAttendance() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AttendancePage()),
    );
    if (!mounted) return;
    setState(() => _reloadToken++);
  }

  String? get _branchName {
    final id = AuthService.instance.attendanceBranchId;
    if (id == null) return null;
    for (final branch in _branches) {
      if (branch.id == id) return branch.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.user;
        if (user == null) return const SizedBox.shrink();

        final fullName = user.fullName.trim();
        final firstName = fullName.isEmpty ? 'Petugas' : fullName.split(' ').first;

        return DashboardScaffold(
          greeting: 'Halo, $firstName',
          subtitle: 'Catat absen dan lihat riwayat kehadiranmu.',
          onRefresh: _refresh,
          children: [
            _ProfileCard(
              name: fullName.isEmpty ? '-' : fullName,
              email: user.email,
              phone: user.phone,
              role: user.role.label,
              branch: _branchName,
            ),
            const SizedBox(height: 14),
            EntryCard(
              title: 'Absensi',
              subtitle: 'Catat absen masuk dan pulang',
              icon: Icons.fact_check_outlined,
              onTap: _openAttendance,
            ),
            const SizedBox(height: 22),
            const Text(
              'Riwayat Absensi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            AttendanceHistoryView(
              reloadToken: _reloadToken,
              loader: (from, to) =>
                  AttendanceService.instance.fetchMyRange(from: from, to: to),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.branch,
  });

  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? branch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Diri',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _InfoLine(icon: Icons.person_outline, label: 'Nama', value: name),
          _InfoLine(icon: Icons.email_outlined, label: 'Email', value: email),
          _InfoLine(icon: Icons.phone_outlined, label: 'No. HP', value: phone),
          _InfoLine(icon: Icons.badge_outlined, label: 'Peran', value: role),
          _InfoLine(
            icon: Icons.location_on_outlined,
            label: 'Cabang',
            value: branch,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = (value == null || value!.trim().isEmpty) ? '-' : value!.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
