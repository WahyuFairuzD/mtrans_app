import 'package:flutter/material.dart';
import '../../models/bus_wash.dart';
import '../../services/api_exception.dart';
import '../../services/app_data.dart';
import '../../services/work_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/load_notice.dart';
import '../../widgets/stat_card.dart';
import '../attendance/attendance_page.dart';
import 'work_page.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _appData.refresh();
    });
  }

  List<BusWash> _by(WashStatus status) =>
      _appData.operational.where((bus) => bus.status == status).toList();

  Future<void> _start(BusWash bus) async {
    if (_busy) return;

    final confirmed = await confirmDialog(
      context,
      title: 'Mulai cuci ${bus.plateNumber}?',
      message: 'Waktu mulai akan dicatat sekarang.',
      confirmLabel: 'Mulai Cuci',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);

    BusWash? started;

    try {
      started = await WorkService.instance.startJob(bus.id);
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, e.message);
        if (e.statusCode == 409) _appData.refresh();
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Terjadi kesalahan. Coba lagi.');
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
      MaterialPageRoute(builder: (_) => WorkPage(bus: bus)),
    );

    if (result == null || !mounted) return;

    _appData.addBus(result);
    showSnack(context, 'Pekerjaan selesai dan menunggu pemeriksaan Pengawas.');
  }

  Widget _taskCard(
    BusWash bus, {
    required String label,
    required IconData icon,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _TaskCard(
        bus: bus,
        actionLabel: label,
        actionIcon: icon,
        onAction: _busy ? null : onAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appData,
      builder: (context, _) {
        final waitingBuses = _by(WashStatus.menungguDikerjakan);
        final workingBuses = _by(WashStatus.dalamPengerjaan);
        final inspectionBuses = _by(WashStatus.menungguPemeriksaan);

        final showEmpty =
            waitingBuses.isEmpty &&
            workingBuses.isEmpty &&
            inspectionBuses.isEmpty &&
            _appData.loaded &&
            _appData.error == null;

        return DashboardScaffold(
          greeting: 'Halo, Petugas',
          subtitle: 'Kelola tugas pencucian bus kamu hari ini.',
          onRefresh: _appData.refresh,
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
            EntryCard(
              title: 'Absensi',
              subtitle: 'Catat absen masuk dan pulang',
              icon: Icons.fact_check_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendancePage()),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Tugas Saya',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LoadNotice(
              loading: _appData.loading,
              loaded: _appData.loaded,
              error: _appData.error,
              onRetry: _appData.refresh,
            ),
            if (showEmpty) const _EmptyTasks(),
            ...waitingBuses.map(
              (bus) => _taskCard(
                bus,
                label: 'Mulai Cuci',
                icon: Icons.play_arrow,
                onAction: () => _start(bus),
              ),
            ),
            ...workingBuses.map(
              (bus) => _taskCard(
                bus,
                label: 'Lanjutkan Pekerjaan',
                icon: Icons.assignment_outlined,
                onAction: () => _openWork(bus),
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
        );
      },
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(Icons.task_alt, size: 42, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            'Tidak ada tugas saat ini.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Tugas yang diberikan kepada kamu akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
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
