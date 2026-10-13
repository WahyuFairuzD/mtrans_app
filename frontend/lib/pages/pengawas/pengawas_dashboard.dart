import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bus_wash.dart';
import '../../services/api_exception.dart';
import '../../services/app_data.dart';
import '../../services/review_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/load_notice.dart';
import '../../widgets/profile_button.dart';
import '../../widgets/stat_card.dart';
import 'assign_page.dart';
import 'input_bus_page.dart';
import 'inspection_page.dart';

const _logoAsset = 'assets/images/kpbputih.png';

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  Future<void> _assign(BusWash bus) async {
    final result = await Navigator.push<BusWash>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignPage(bus: bus),
      ),
    );

    if (result == null || !mounted) return;

    _appData.addBus(result);

    _showMessage('Penugasan berhasil disimpan.');
  }

  Future<void> _inspect(BusWash bus) async {
    final result = await Navigator.push<BusWash>(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionPage(bus: bus),
      ),
    );

    if (result == null || !mounted) return;

    _appData.addBus(result);

    _showMessage('Hasil pemeriksaan tersimpan. Bus siap dicatat keluar.');
  }

  Future<void> _recordExit(BusWash bus) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Catat ${bus.plateNumber} keluar?'),
        content: const Text(
          'Waktu keluar dicatat sekarang dan pekerjaan masuk ke rekap.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Catat Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    BusWash? updated;

    try {
      updated = await ReviewService.instance.recordExit(bus.id);
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message);
        if (e.statusCode == 409) _appData.refresh();
      }
    } catch (_) {
      if (mounted) _showMessage('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (updated == null || !mounted) return;

    _appData.addBus(updated);

    _showMessage('Unit keluar dicatat.');
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
    final waiting = _by([WashStatus.menungguDikerjakan]);
    final working = _by([WashStatus.dalamPengerjaan]);
    final runningCount = waiting.length + working.length;

    final toInspect = _by([WashStatus.menungguPemeriksaan]);

    final toExit = _by([WashStatus.selesai]);

    final isEmpty = _appData.loaded &&
        _appData.error == null &&
        _appData.operational.isEmpty;

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

                Padding(
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
                            number: '$runningCount',
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

                      ..._section(
                        'Siap Keluar',
                        toExit,
                        'Catat Bus Keluar',
                        _recordExit,
                      ),

                      const SizedBox(height: 24),

                      const HistoryButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addBus,
          icon: const Icon(Icons.add),
          label: const Text('Input Bus Datang'),
        ),
      ),
    );
  }
}