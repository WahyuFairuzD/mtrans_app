import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bus_wash.dart';
import '../../services/api_exception.dart';
import '../../services/app_data.dart';
import '../../services/work_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/load_notice.dart';
import '../../widgets/profile_button.dart';
import '../../widgets/stat_card.dart';
import 'work_page.dart';

const _logoAsset = 'assets/images/kpbputih.png';

class PegawaiDashboard extends StatefulWidget {
  const PegawaiDashboard({super.key});

  @override
  State<PegawaiDashboard> createState() => _PegawaiDashboardState();
}

class _PegawaiDashboardState extends State<PegawaiDashboard> {
  final AppData _appData = AppData.instance;

  bool _busy = false;

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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _start(BusWash bus) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Mulai cuci ${bus.plateNumber}?'),
        content: const Text('Waktu mulai akan dicatat sekarang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mulai Cuci'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    BusWash? started;

    try {
      started = await WorkService.instance.startJob(bus.id);
    } on ApiException catch (e) {
      if (mounted) {
        _showError(e.message);
        if (e.statusCode == 409) _appData.refresh();
      }
    } catch (_) {
      if (mounted) _showError('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (started == null || !mounted) return;

    _appData.addBus(started);
    await _openWork(started);
  }

  Future<void> _openWork(BusWash bus) async {
    final result = await Navigator.push<BusWash>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkPage(bus: bus),
      ),
    );

    if (result == null || !mounted) return;

    _appData.addBus(result);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pekerjaan selesai dan menunggu pemeriksaan Pengawas.'),
      ),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _appData.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: top + 190,
                  child: Container(
                    color: AppColors.brand,
                    padding: EdgeInsets.fromLTRB(20, top + 12, 20, 0),
                    child: Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ProfileButton(),
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

                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 150, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          width: double.infinity,
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
                            onAction: _busy ? null : () => _start(bus),
                          ),
                        ),
                      ),

                      ...workingBuses.map(
                        (bus) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TaskCard(
                            bus: bus,
                            actionLabel: 'Lanjutkan Pekerjaan',
                            actionIcon: Icons.assignment_outlined,
                            onAction: _busy ? null : () => _openWork(bus),
                          ),
                        ),
                      ),

                      ...inspectionBuses.map(
                        (bus) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BusCard(bus: bus),
                        ),
                      ),

                      const SizedBox(height: 14),

                      const HistoryButton(),
                    ],
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

class _TaskCard extends StatelessWidget {
  final BusWash bus;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

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