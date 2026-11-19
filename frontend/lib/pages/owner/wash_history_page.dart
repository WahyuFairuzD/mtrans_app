import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/bus_wash.dart';
import '../../models/history_filter.dart';
import '../../services/auth_service.dart';
import '../../services/location_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/history_filter_sheet.dart';
import '../../widgets/paged_bus_list.dart';
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

  /// Owner: tunggu pilihan lokasi (Setting) termuat dulu supaya daftar tidak dimuat dua kali.
  bool _ready = false;

  UserRole? get _role => AuthService.instance.user?.role;
  bool get _isPegawai => _role == UserRole.pegawai;
  bool get _isOwner => _role == UserRole.owner;

  @override
  void initState() {
    super.initState();
    if (_isOwner) {
      LocationSettings.instance
          .ensureLoaded()
          .catchError((_) {})
          .whenComplete(() {
            if (mounted) setState(() => _ready = true);
          });
    } else {
      _ready = true;
    }
  }

  /// Owner: cabang mengikuti Setting > Lokasi. Peran lain: dikunci server.
  HistoryFilter get _effectiveFilter =>
      _isOwner ? _filter.withBranch(LocationSettings.instance.branchId) : _filter;

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
        builder: (_) =>
            UnitHistoryPage(unitId: unitId, plateNumber: bus.plateNumber),
      ),
    );
  }

  Widget _buildSearchBar() {
    OutlineInputBorder border() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );

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
                border: border(),
                enabledBorder: border(),
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
    final appBar = AppBar(title: const Text('Riwayat Pencucian'));

    if (!_ready) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: PagedBusList(
              filter: _effectiveFilter,
              onUnitHistory: _isPegawai ? null : _openUnit,
              showBranch: _isOwner,
            ),
          ),
        ],
      ),
    );
  }
}
