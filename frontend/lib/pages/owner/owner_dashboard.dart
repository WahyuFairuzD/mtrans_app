import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bus_wash.dart';
import '../../services/app_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/stat_card.dart';

// Ganti sesuai punyamu.
const _logoAsset = 'assets/images/kpbputih.png'; // logo putih
const _headerRed = Color(0xFFB1121A);

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = AppData.instance;
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // ikon status bar putih di atas merah
      child: Scaffold(
        // AppBar dihapus, diganti header merah di dalam body
        body: AnimatedBuilder(
          animation: appData,
          builder: (context, _) {
            final buses = appData.buses;

            String count(List<WashStatus> statuses) {
              return '${buses.where((bus) => statuses.contains(bus.status)).length}';
            }

            return SingleChildScrollView(
              child: Stack(
                children: [
                  // ===== HEADER MERAH =====
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: top + 190,
                    child: Container(
                      color: _headerRed,
                      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 0),
                      child: Stack(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Image.asset(
                                _logoAsset,
                                height: 120,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                          const Positioned(
                            left: 0,
                            bottom: 50,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, Owner',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Pantau Operasional Cuci Bus Hari Ini',
                                  style: TextStyle(
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
                  ),

                  // ===== ISI (grid menimpa tepi header) =====
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, top + 150, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // STATISTIK (tidak diubah)
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
                              number: count([WashStatus.dalamPengerjaan]),
                              title: 'Dikerjakan',
                              icon: Icons.autorenew,
                              color: Colors.orange,
                            ),
                            StatCard(
                              number: count([WashStatus.menungguPemeriksaan]),
                              title: 'Perlu Diperiksa',
                              icon: Icons.fact_check_outlined,
                              color: Colors.purple,
                            ),
                            StatCard(
                              number: count([WashStatus.selesai]),
                              title: 'Selesai',
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            StatCard(
                              number: count([WashStatus.unitKeluar]),
                              title: 'Unit Keluar',
                              icon: Icons.exit_to_app,
                              color: Colors.blue,
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // OPERASIONAL (tidak diubah)
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
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
