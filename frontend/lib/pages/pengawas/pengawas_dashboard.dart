import 'package:flutter/material.dart';
import '../../models/bus_wash.dart';
import '../../services/app_data.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/load_notice.dart';
import '../../widgets/stat_card.dart';
import 'input_bus_page.dart';

const _logoAsset = 'assets/images/kpbputih.png';
const _headerRed = Color(0xFFB1121A);

class PengawasDashboard extends StatefulWidget {
  const PengawasDashboard({super.key});

  @override
  State<PengawasDashboard> createState() => _PengawasDashboardState();
}

class _PengawasDashboardState extends State<PengawasDashboard> {
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

  Future<void> _addBus() async {
    final result = await Navigator.push<BusWash>(
      context,
      MaterialPageRoute(
        builder: (_) => const InputBusPage(),
      ),
    );

    if (result == null || !mounted) return;

    _appData.addBus(result);
  }

  List<Widget> _section(
    String title,
    List<BusWash> items, [
    String? actionLabel,
    void Function(BusWash)? onAction,
  ]) {
    if (items.isEmpty) return [];

    return [
      const SizedBox(height: 24),
      Text(
        '$title (${items.length})',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      ...items.map(
        (bus) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BusCard(
            bus: bus,
            actionLabel: actionLabel,
            onAction: onAction == null ? null : () => onAction(bus),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    final toAssign = _by([WashStatus.terdaftar]);

    final running = _by([
      WashStatus.menungguDikerjakan,
      WashStatus.dalamPengerjaan,
    ]);

    final toInspect = _by([WashStatus.menungguPemeriksaan]);

    final toExit = _by([WashStatus.selesai]);

    final isEmpty = _appData.loaded &&
        _appData.error == null &&
        _appData.operational.isEmpty;

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
                          'Halo, Pengawas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kelola bus masuk, penugasan, dan pemeriksaan.',
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, top + 150, 20, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatGrid(
                      items: [
                        StatCard(
                          number: '${toAssign.length}',
                          title: 'Perlu Ditugaskan',
                          icon: Icons.assignment_ind_outlined,
                          color: Colors.blueGrey,
                        ),
                        StatCard(
                          number: '${running.length}',
                          title: 'Berjalan',
                          icon: Icons.autorenew,
                          color: Colors.orange,
                        ),
                        StatCard(
                          number: '${toInspect.length}',
                          title: 'Perlu Diperiksa',
                          icon: Icons.fact_check_outlined,
                          color: Colors.purple,
                        ),
                        StatCard(
                          number: '${toExit.length}',
                          title: 'Siap Keluar',
                          icon: Icons.exit_to_app,
                          color: Colors.green,
                        ),
                      ],
                    ),

                    LoadNotice(
                      loading: _appData.loading,
                      loaded: _appData.loaded,
                      error: _appData.error,
                      onRetry: _appData.refresh,
                    ),

                    if (isEmpty) ...[
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'Belum ada bus. Tekan "Input Bus Datang" untuk mencatat bus yang datang.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],

                    ..._section(
                      'Perlu Ditugaskan',
                      toAssign,
                      'Tugaskan Petugas',
                      (_) => _soon('Penugasan'),
                    ),

                    ..._section('Sedang Berjalan', running),

                    ..._section(
                      'Menunggu Pemeriksaan',
                      toInspect,
                      'Periksa Hasil',
                      (_) => _soon('Pemeriksaan'),
                    ),

                    ..._section(
                      'Siap Keluar',
                      toExit,
                      'Catat Bus Keluar',
                      (_) => _soon('Pencatatan bus keluar'),
                    ),

                    const SizedBox(height: 24),

                    const HistoryButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBus,
        icon: const Icon(Icons.add),
        label: const Text('Input Bus Datang'),
      ),
    );
  }
}