import 'package:flutter/material.dart';

import '../../services/app_data.dart';
import '../../widgets/bus_card.dart';

class WashHistoryPage extends StatelessWidget {
  const WashHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = AppData.instance;

    final historyBuses = appData.buses
        .where(
          (bus) => bus.date != 'Hari ini',
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pencucian'),
      ),
      body: historyBuses.isEmpty
          ? const Center(
              child: Text(
                'Belum ada riwayat pencucian.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: historyBuses.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: 10),
              itemBuilder: (_, i) {
                return BusCard(
                  bus: historyBuses[i],
                  showDate: true,
                );
              },
            ),
    );
  }
}