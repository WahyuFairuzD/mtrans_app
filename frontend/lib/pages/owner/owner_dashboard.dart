import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../models/bus_wash.dart';
import '../../services/app_data.dart';
import '../../services/master_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/wib.dart';
import '../../widgets/branch_filter_chips.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/load_notice.dart';
import '../../widgets/stat_card.dart';
import '../attendance/owner_attendance_page.dart';
import '../stock/stock_page.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final AppData _appData = AppData.instance;

  List<Branch> _branches = [];
  int? _branchId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([_appData.refresh(), _loadBranches()]);
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await MasterService.instance.fetchBranches();
      if (mounted) setState(() => _branches = branches);
    } catch (_) {
    }
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appData,
      builder: (context, _) {
        final buses = _appData.operational
            .where((bus) => _branchId == null || bus.branchId == _branchId)
            .toList();

        String count(WashStatus status) =>
            '${buses.where((bus) => bus.status == status).length}';

        final enteredToday = buses.where((bus) => bus.date == kToday).length;

        return DashboardScaffold(
          greeting: 'Halo, Owner',
          subtitle: 'Pantau Operasional Cuci Bus Hari Ini',
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
              title: 'Absensi Hari Ini',
              subtitle: 'Pantau absensi semua cabang',
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
            const SizedBox(height: 28),
            const Text(
              'Operasional Hari Ini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_branches.isNotEmpty) ...[
              const SizedBox(height: 8),
              BranchFilterChips(
                branches: _branches,
                selectedId: _branchId,
                onSelected: (id) => setState(() => _branchId = id),
                padding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 12),
            LoadNotice(
              loading: _appData.loading,
              loaded: _appData.loaded,
              error: _appData.error,
              onRetry: _appData.refresh,
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
                  child: BusCard(bus: bus, showBranch: _branchId == null),
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
