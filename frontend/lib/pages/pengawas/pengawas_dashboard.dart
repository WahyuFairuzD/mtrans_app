import 'package:flutter/material.dart';
import '../../models/bus_wash.dart';
import '../../services/api_exception.dart';
import '../../services/app_data.dart';
import '../../services/review_service.dart';
import '../../utils/dialogs.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/load_notice.dart';
import '../../widgets/stat_card.dart';
import '../attendance/attendance_page.dart';
import '../stock/stock_page.dart';
import 'assign_page.dart';
import 'input_bus_page.dart';
import 'inspection_page.dart';

class PengawasDashboard extends StatefulWidget {
  const PengawasDashboard({super.key});

  @override
  State<PengawasDashboard> createState() => _PengawasDashboardState();
}

class _PengawasDashboardState extends State<PengawasDashboard> {
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

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _addBus() async {
    final result = await Navigator.push<BusWash>(
      context,
      MaterialPageRoute(builder: (_) => const InputBusPage()),
    );

    if (result == null || !mounted) return;

    _appData.addBus(result);
  }

  Future<void> _assign(BusWash bus) async {
    final result = await Navigator.push<BusWash>(
      context,
      MaterialPageRoute(builder: (_) => AssignPage(bus: bus)),
    );

    if (result == null || !mounted) return;

    _appData.addBus(result);
    showSnack(context, 'Penugasan berhasil disimpan.');
  }

  Future<void> _inspect(BusWash bus) async {
    final result = await Navigator.push<BusWash>(
      context,
      MaterialPageRoute(builder: (_) => InspectionPage(bus: bus)),
    );

    if (result == null || !mounted) return;

    _appData.addBus(result);
    showSnack(context, 'Hasil pemeriksaan tersimpan. Bus siap dicatat keluar.');
  }

  Future<void> _recordExit(BusWash bus) async {
    if (_busy) return;

    final confirmed = await confirmDialog(
      context,
      title: 'Catat ${bus.plateNumber} keluar?',
      message: 'Waktu keluar dicatat sekarang dan pekerjaan masuk ke rekap.',
      confirmLabel: 'Catat Keluar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);

    BusWash? updated;

    try {
      updated = await ReviewService.instance.recordExit(bus.id);
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

    if (updated == null || !mounted) return;

    _appData.addBus(updated);
    showSnack(context, 'Unit keluar dicatat.');
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
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    return ListenableBuilder(
      listenable: _appData,
      builder: (context, _) {
        final toAssign = _by(WashStatus.terdaftar);
        final waiting = _by(WashStatus.menungguDikerjakan);
        final working = _by(WashStatus.dalamPengerjaan);
        final toInspect = _by(WashStatus.menungguPemeriksaan);
        final toExit = _by(WashStatus.selesai);

        final isEmpty =
            _appData.loaded &&
            _appData.error == null &&
            _appData.operational.isEmpty;

        return DashboardScaffold(
          greeting: 'Halo, Pengawas',
          subtitle: 'Kelola bus masuk, penugasan, dan pemeriksaan.',
          onRefresh: _appData.refresh,
          bottomPadding: 96,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addBus,
            icon: const Icon(Icons.add),
            label: const Text('Input Bus Datang'),
          ),
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
                  number: '${waiting.length + working.length}',
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
            const SizedBox(height: 14),
            EntryCard(
              title: 'Absensi',
              subtitle: 'Catat absen masuk dan pulang',
              icon: Icons.fact_check_outlined,
              onTap: () => _open(const AttendancePage()),
            ),
            const SizedBox(height: 12),
            EntryCard(
              title: 'Kelola Stok',
              subtitle: 'Lihat persediaan dan catat perubahan',
              icon: Icons.inventory_2_outlined,
              iconColor: Colors.blue,
              onTap: () => _open(const StockPage()),
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
              _assign,
            ),
            ..._section(
              'Menunggu Dikerjakan',
              waiting,
              'Ganti Petugas',
              _assign,
            ),
            ..._section('Sedang Dikerjakan', working),
            ..._section(
              'Menunggu Pemeriksaan',
              toInspect,
              'Periksa Hasil',
              _inspect,
            ),
            ..._section('Siap Keluar', toExit, 'Catat Bus Keluar', _recordExit),
            const SizedBox(height: 24),
            const HistoryButton(),
          ],
        );
      },
    );
  }
}
