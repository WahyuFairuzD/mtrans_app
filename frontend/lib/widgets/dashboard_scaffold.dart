import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'settings_button.dart';

const _logoAsset = 'assets/images/kpbputih.png';

/// Kerangka dashboard semua peran: header merah (profil, logo, sapaan),
/// tarik-untuk-muat-ulang, dan isi yang bisa digulir.
class DashboardScaffold extends StatelessWidget {
  const DashboardScaffold({
    super.key,
    required this.greeting,
    required this.subtitle,
    required this.onRefresh,
    required this.children,
    this.bottomPadding = 28,
    this.floatingActionButton,
  });

  final String greeting;
  final String subtitle;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final double bottomPadding;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        floatingActionButton: floatingActionButton,
        body: RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: top + 190,
                  child: _Header(
                    top: top,
                    greeting: greeting,
                    subtitle: subtitle,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 150, 20, bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.top,
    required this.greeting,
    required this.subtitle,
  });

  final double top;
  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brand,
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 0),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsButton(),
              const Spacer(),
              Image.asset(_logoAsset, height: 120, fit: BoxFit.contain),
            ],
          ),
          Positioned(
            left: 0,
            bottom: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
