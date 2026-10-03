import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../owner/owner_dashboard.dart';
import '../pegawai/pegawai_dashboard.dart';
import '../pengawas/pengawas_dashboard.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final auth = AuthService.instance;

        if (!auth.initialized) {
          return const _SplashPage();
        }

        final user = auth.user;

        if (user == null) {
          return const LoginPage();
        }

        switch (user.role) {
          case UserRole.owner:
            return const OwnerDashboard();
          case UserRole.pengawas:
            return const PengawasDashboard();
          case UserRole.pegawai:
            return const PegawaiDashboard();
        }
      },
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MTRANS',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
