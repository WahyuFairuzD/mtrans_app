import 'package:flutter/material.dart';

import '../../models/bus_wash.dart';
import '../../services/app_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/load_notice.dart';
import '../../widgets/stat_card.dart';

const _logoAsset = 'assets/images/kpbputih.png';
const _headerRed = Color(0xFFB1121A);

class PegawaiDashboard extends StatefulWidget {
  const PegawaiDashboard({super.key});

  @override
  State<PegawaiDashboard> createState() => _PegawaiDashboardState();
}

class _PegawaiDashboardState extends State<PegawaiDashboard> {
  final AppData _appData = AppData.instance;

  @override
  void initState() {
    super.initState();

    _appData.addListener(_onDataChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _appData.refresh();
    });
  }

  @override
  void dispose() {
    _appData.removeListener(_onDataChanged);

    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;

    setState(() {});
  }

  List<BusWash> _by(List<WashStatus> statuses) {
    return _appData.operational
        .where((bus) => statuses.contains(bus.status))
        .toList();
  }

  void _soon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature belum tersedia.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    final waitingBuses = _by([WashStatus.menungguDikerjakan]);
    final workingBuses = _by([WashStatus.dalamPengerjaan]);
    final inspectionBuses = _by([WashStatus.menungguPemeriksaan]);

    final noTasks = waitingBuses.isEmpty &&
        workingBuses.isEmpty &&
        inspectionBuses.isEmpty;

    final showEmpty =
        noTasks && _appData.loaded && _appData.error == null;

    return Scaffold(
      body: Stack(
        children: [
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
                          'Halo, Petugas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kelola tugas pencucian bus kamu hari ini.',
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

          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _appData.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, top + 150, 20, 96),
                children: [
                  StatGrid(
                    items: [
                      StatCard(
                        number: '${waitingBuses.length}',
                        title: 'Menunggu',
                        icon: Icons.access_time,
                        color: Colors.grey,
                      ),
                      StatCard(
                        number: '${workingBuses.length}',
                        title: 'Dikerjakan',
                        icon: Icons.autorenew,
                        color: Colors.orange,
                      ),
                      StatCard(
                        number: '${inspectionBuses.length}',
                        title: 'Pemeriksaan',
                        icon: Icons.fact_check_outlined,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Tugas Saya',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  LoadNotice(
                    loading: _appData.loading,
                    loaded: _appData.loaded,
                    error: _appData.error,
                    onRetry: _appData.refresh,
                  ),

                  if (showEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 42,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Tidak ada tugas saat ini.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tugas yang diberikan kepada kamu akan muncul di sini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  ...waitingBuses.map(
                    (bus) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TaskCard(
                        bus: bus,
                        actionLabel: 'Mulai Cuci',
                        actionIcon: Icons.play_arrow,
                        onAction: () => _soon('Mulai Cuci'),
                      ),
                    ),
                  ),

                  ...workingBuses.map(
                    (bus) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TaskCard(
                        bus: bus,
                        actionLabel: 'Selesai Cuci',
                        actionIcon: Icons.check,
                        onAction: () => _soon('Selesai Cuci'),
                      ),
                    ),
                  ),

                  ...inspectionBuses.map(
                    (bus) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BusCard(bus: bus),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final BusWash bus;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _TaskCard({
    required this.bus,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BusCard(bus: bus),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}