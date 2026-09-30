import 'package:flutter/material.dart';
import 'pages/owner/owner_dashboard.dart';
import 'pages/pegawai/pegawai_dashboard.dart';
import 'pages/pengawas/pengawas_dashboard.dart';
import 'theme/app_theme.dart';

void main() => runApp(const MtransApp());

class MtransApp extends StatelessWidget {
  const MtransApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mtrans',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const RolePickerPage(),
    );
  }
}

/// SEMENTARA: pengganti login, untuk pindah antar dashboard saat development.
/// Nanti diganti halaman Login + pengecekan role dari backend.
class RolePickerPage extends StatelessWidget {
  const RolePickerPage({super.key});

  Widget _roleButton(
    BuildContext context,
    String label,
    IconData icon,
    Widget page,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'MTRANS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih role (mode development)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  _roleButton(
                    context,
                    'Owner',
                    Icons.admin_panel_settings_outlined,
                    const OwnerDashboard(),
                  ),
                  _roleButton(
                    context,
                    'Pengawas',
                    Icons.supervisor_account_outlined,
                    const PengawasDashboard(),
                  ),
                  _roleButton(
                    context,
                    'Petugas Cuci',
                    Icons.local_car_wash_outlined,
                    const PegawaiDashboard(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}