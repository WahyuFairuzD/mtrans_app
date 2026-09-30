import 'package:flutter/material.dart';

import '../../models/bus_wash.dart';
import '../../services/app_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/stat_card.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = AppData.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MTRANS'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: appData,
        builder: (context, _) {
          final buses = appData.buses;

          String count(List<WashStatus> statuses) {
            return '${buses.where((bus) => statuses.contains(bus.status)).length}';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Halo, Owner 👋',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pantau operasional Mtrans hari ini.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // STATISTIK
                StatGrid(
                  items: [
                    StatCard(
                      number: '${buses.length}',
                      title: 'Bus Masuk',
                      icon: Icons.directions_bus,
                      color: Colors.blue,
                    ),
                    StatCard(
                      number: count([
                        WashStatus.terdaftar,
                        WashStatus.menungguDikerjakan,
                      ]),
                      title: 'Menunggu',
                      icon: Icons.access_time,
                      color: Colors.grey,
                    ),
                    StatCard(
                      number: count([
                        WashStatus.dalamPengerjaan,
                      ]),
                      title: 'Dikerjakan',
                      icon: Icons.autorenew,
                      color: Colors.orange,
                    ),
                    StatCard(
                      number: count([
                        WashStatus.menungguPemeriksaan,
                      ]),
                      title: 'Perlu Diperiksa',
                      icon: Icons.fact_check_outlined,
                      color: Colors.purple,
                    ),
                    StatCard(
                      number: count([
                        WashStatus.selesai,
                      ]),
                      title: 'Selesai',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    StatCard(
                      number: count([
                        WashStatus.unitKeluar,
                      ]),
                      title: 'Unit Keluar',
                      icon: Icons.exit_to_app,
                      color: Colors.blue,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // OPERASIONAL
                const Text(
                  'Operasional Hari Ini',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (buses.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'Belum ada data bus hari ini.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...buses.map(
                    (bus) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BusCard(bus: bus),
                    ),
                  ),

                const SizedBox(height: 10),

                const HistoryButton(),
              ],
            ),
          );
        },
      ),
    );
  }
}