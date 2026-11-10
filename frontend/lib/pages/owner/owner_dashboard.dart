import 'package:flutter/material.dart';
import '../../models/bus_wash.dart';
import '../../services/app_data.dart';
import '../../services/location_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/wib.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/load_notice.dart';
import '../../widgets/stat_card.dart';
import '../attendance/owner_attendance_page.dart';
import '../invoice/invoice_list_page.dart';
import '../stock/stock_page.dart';
import '../units/units_page.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final AppData _appData = AppData.instance;
  final LocationSettings _location = LocationSettings.instance;

  /// Cabang yang terakhir dipakai memuat data (null = semua cabang).
  int? _appliedBranch;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    _location.addListener(_onLocationChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await _location.ensureLoaded();
    } catch (_) {
      // Tanpa daftar lokasi, dashboard tetap dicoba dimuat (semua cabang).
    }
    // Bila ensureLoaded sukses, listener sudah memuat data; jangan dobel.
    if (mounted) await _applyLocation();
  }

  void _onLocationChanged() {
    if (_location.loaded) _applyLocation();
  }

  /// Muat ulang operasional bila pilihan lokasi berubah (mis. dari Setting).
  Future<void> _applyLocation() async {
    final branch = _location.branchId;
    if (_hasApplied && branch == _appliedBranch) return;

    _hasApplied = true;
    _appliedBranch = branch;
    await _appData.setBranchFilter(branch);
  }

  Future<void> _refresh() async {
    try {
      await _location.ensureLoaded();
    } catch (_) {
      // lihat _bootstrap
    }
    await _appData.refresh(force: true);
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_appData, _location]),
      builder: (context, _) {
        final buses = _appData.operational;

        String count(WashStatus status) =>
            '${buses.where((bus) => bus.status == status).length}';

        final enteredToday = buses.where((bus) => bus.date == kToday).length;

        return DashboardScaffold(
          greeting: 'Halo, Owner',
          subtitle: _location.loaded
              ? 'Operasional hari ini · ${_location.label}'
              : 'Pantau Operasional Cuci Bus Hari Ini',
          onRefresh: _refresh,
          children: [
            StatGrid(
              items: [
                StatCard(
                  number: '$enteredToday',
                  title: 'Bus Masuk',
                  icon: Icons.directions_bus,
                  color: Colors.blue,
                ),
                StatCard(
                  number: count(WashStatus.dalamPengerjaan),
                  title: 'Dikerjakan',
                  icon: Icons.autorenew,
                  color: Colors.orange,
                ),
                StatCard(
                  number: count(WashStatus.menungguPemeriksaan),
                  title: 'Perlu Diperiksa',
                  icon: Icons.fact_check_outlined,
                  color: Colors.purple,
                ),
                StatCard(
                  number: count(WashStatus.selesai),
                  title: 'Selesai',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                StatCard(
                  number: count(WashStatus.unitKeluar),
                  title: 'Unit Keluar',
                  icon: Icons.exit_to_app,
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 14),
            EntryCard(
              title: 'Absensi',
              subtitle: 'Pantau absensi pegawai per tanggal',
              icon: Icons.fact_check_outlined,
              onTap: () => _open(const OwnerAttendancePage()),
            ),
            const SizedBox(height: 12),
            EntryCard(
              title: 'Kelola Stok',
              subtitle: 'Lihat persediaan dan catat perubahan',
              icon: Icons.inventory_2_outlined,
              iconColor: Colors.blue,
              onTap: () => _open(const StockPage()),
            ),
            const SizedBox(height: 12),
            EntryCard(
              title: 'Invoice',
              subtitle: 'Buat dan lihat riwayat tagihan',
              icon: Icons.receipt_long_outlined,
              iconColor: Colors.green,
              onTap: () => _open(const InvoiceListPage()),
            ),
            const SizedBox(height: 12),
            EntryCard(
              title: 'Kelola Unit',
              subtitle: 'Jenis kendaraan, nama armada, dan plat',
              icon: Icons.directions_bus_outlined,
              iconColor: Colors.orange,
              onTap: () => _open(const UnitsPage()),
            ),
            const SizedBox(height: 28),
            const Text(
              'Operasional Hari Ini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LoadNotice(
              loading: _appData.loading,
              loaded: _appData.loaded,
              error: _appData.error,
              onRetry: _refresh,
            ),
            if (buses.isEmpty && _appData.loaded && _appData.error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    'Belum ada data bus hari ini.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...buses.map(
                (bus) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BusCard(bus: bus, showBranch: _location.isAll),
                ),
              ),
            const SizedBox(height: 10),
            const HistoryButton(),
          ],
        );
      },
    );
  }
}
