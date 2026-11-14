import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'settings_button.dart';

const _logoAsset = 'assets/images/kpbputih.png';
const _redDark = Color(0xFF9E1022);

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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, _redDark],
        ),
      ),
      child: Stack(
        children: [
          // Garis gelombang dekoratif
          Positioned.fill(child: CustomPaint(painter: _WavePainter())),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 0),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SettingsButton(),
                    const Spacer(),
                    // Logo tanpa lingkaran, diberi garis aksen
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Image.asset(
                          _logoAsset,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 72,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 40,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
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

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 5; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.10 + i * 0.03);

      final baseY = size.height * (0.40 + i * 0.07);
      final amp = 12.0 + i * 3;

      final path = Path()..moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 4) {
        final y =
            baseY + math.sin((x / size.width) * 2 * math.pi + i * 0.7) * amp;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}