import 'package:flutter/material.dart';
import '../models/bus_wash.dart';
import '../theme/app_theme.dart';

/// Kotak hitam berisi ikon bus.
class BusIconBadge extends StatelessWidget {
  const BusIconBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.directions_bus, color: Colors.white),
    );
  }
}

/// Kartu ringkas bus (plat, merek, layanan) di bagian atas halaman kerja,
/// penugasan, dan pemeriksaan.
class BusHeaderCard extends StatelessWidget {
  const BusHeaderCard({super.key, required this.bus, this.extraLines = const []});

  final BusWash bus;
  final List<String> extraLines;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      bus.brand,
      if (bus.serviceName != null) bus.serviceName!,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BusIconBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bus.plateNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                for (final line in extraLines) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
