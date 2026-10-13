import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/bus_wash.dart';
import '../../models/history_filter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/history_filter_sheet.dart';
import '../../widgets/paged_bus_list.dart';
import '../../widgets/recap_view.dart';
import 'unit_history_page.dart';

class WashHistoryPage extends StatefulWidget {
  const WashHistoryPage({super.key});

  @override
  State<WashHistoryPage> createState() => _WashHistoryPageState();
}

class _WashHistoryPageState extends State<WashHistoryPage> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  HistoryFilter _filter = const HistoryFilter();

  bool get _isPegawai => AuthService.instance.user?.role == UserRole.pegawai;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _filter = _filter.withQuery(value.trim()));
    });
  }

  Future<void> _openFilter() async {
    final result = await showHistoryFilterSheet(
      context,
      current: _filter,
      canFilterMaster: !_isPegawai,
    );

    if (result == null || !mounted) return;

    setState(() => _filter = result);
  }

  void _openUnit(BusWash bus) {
    final unitId = bus.unitId;
    if (unitId == null) return;

    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => UnitHistoryPage(
          unitId: unitId,
          plateNumber: bus.plateNumber,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Cari nomor polisi',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: IconButton(
                tooltip: 'Filter',
                onPressed: _openFilter,
                icon: Badge(
                  isLabelVisible: _filter.isActive,
                  smallSize: 8,
                  child: const Icon(Icons.tune),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = PagedBusList(
      filter: _filter,
      onUnitHistory: _isPegawai ? null : _openUnit,
    );

    if (_isPegawai) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Pencucian')),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: list),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat Pencucian'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Riwayat'),
              Tab(text: 'Rekap'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                children: [
                  list,
                  RecapView(filter: _filter),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}