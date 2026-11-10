import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/branch.dart';
import '../../services/auth_service.dart';
import '../../services/location_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import 'price_settings_page.dart';

/// Setting: profil dan keluar untuk semua peran. Lokasi dan Harga khusus Owner.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loggingOut = false;

  AppUser? get _user => AuthService.instance.user;
  bool get _isOwner => _user?.role == UserRole.owner;

  @override
  void initState() {
    super.initState();
    if (_isOwner) {
      LocationSettings.instance.ensureLoaded().catchError((_) {});
    }
  }

  Future<void> _chooseLocation() async {
    final settings = LocationSettings.instance;
    try {
      await settings.ensureLoaded();
    } catch (_) {
      if (mounted) showSnack(context, 'Gagal memuat daftar lokasi. Coba lagi.');
      return;
    }
    if (!mounted) return;

    final choice = await showModalBottomSheet<({int? id})>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _LocationSheet(
        branches: settings.branches,
        selectedId: settings.branchId,
      ),
    );
    if (choice == null) return;
    await settings.select(choice.id);
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirmed = await confirmDialog(
      context,
      title: 'Keluar dari akun?',
      message: 'Kamu perlu login lagi untuk memakai aplikasi.',
      confirmLabel: 'Keluar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _loggingOut = true);
    await AuthService.instance.logout();
    if (!mounted) return;
    // AuthGate otomatis menampilkan halaman login; tutup halaman ini.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(title: const Text('Setting')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (user != null) _ProfileCard(user: user),
          if (_isOwner) ...[
            const SizedBox(height: 24),
            const Text(
              'Pengaturan Owner',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListenableBuilder(
              listenable: LocationSettings.instance,
              builder: (context, _) => _SettingTile(
                icon: Icons.location_on_outlined,
                title: 'Lokasi',
                subtitle: LocationSettings.instance.loaded
                    ? LocationSettings.instance.label
                    : 'Ketuk untuk memilih',
                onTap: _chooseLocation,
              ),
            ),
            const SizedBox(height: 10),
            _SettingTile(
              icon: Icons.payments_outlined,
              title: 'Harga',
              subtitle: 'Harga cuci per jenis kendaraan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PriceSettingsPage()),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loggingOut ? null : _logout,
              icon: _loggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.logout),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_loggingOut ? 'Keluar...' : 'Keluar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final name = user.fullName.trim().isEmpty ? '-' : user.fullName.trim();
    final initial = name == '-' ? '?' : name[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.brand.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF2FF),
                child: Icon(icon, color: AppColors.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSheet extends StatelessWidget {
  const _LocationSheet({required this.branches, required this.selectedId});

  final List<Branch> branches;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, int? id) {
      final selected = id == selectedId;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          id == null ? Icons.public : Icons.location_on_outlined,
          color: selected ? AppColors.brand : AppColors.textSecondary,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.brand)
            : null,
        onTap: () => Navigator.pop<({int? id})>(context, (id: id)),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Lokasi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Operasional, riwayat, stok, absensi, dan invoice hanya menampilkan lokasi ini.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            option('Semua Lokasi', null),
            for (final branch in branches) option(branch.name, branch.id),
          ],
        ),
      ),
    );
  }
}
