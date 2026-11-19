import 'package:flutter/material.dart';
import '../pages/settings/settings_page.dart';

/// Ikon gerigi di header dashboard. Membuka halaman Setting
/// (profil, lokasi dan harga untuk Owner, logout).
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      tooltip: 'Setting',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      ),
      icon: const Icon(Icons.settings_outlined, color: Colors.white),
    );
  }
}
