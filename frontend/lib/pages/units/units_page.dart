import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/master_data.dart';
import '../../services/api_exception.dart';
import '../../services/master_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../widgets/error_state.dart';
import '../../widgets/unit_form_sheet.dart';

/// Kelola Unit (Owner dan Pengawas): cari, ubah jenis kendaraan, nama armada,
/// plat, dan status aktif.
class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  List<BusUnit> _units = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final gen = ++_generation;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final units = await MasterService.instance.fetchUnits(
        query: _search.text,
        includeInactive: true,
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _units = units;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() => _error = 'Gagal memuat unit. Coba lagi.');
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _openForm([BusUnit? unit]) async {
    final saved = await showUnitFormSheet(context, unit: unit);
    if (saved == null || !mounted) return;

    showSnack(
      context,
      unit == null ? 'Unit berhasil ditambahkan.' : 'Unit berhasil diperbarui.',
    );
    await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Unit')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Unit Baru'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: filledInputDecoration('Cari nama armada atau plat')
                  .copyWith(
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _units.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(40),
              children: [
                Text(
                  _search.text.trim().isEmpty
                      ? 'Belum ada unit. Tekan "Unit Baru" untuk menambah.'
                      : 'Unit tidak ditemukan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              itemCount: _units.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _UnitTile(
                unit: _units[i],
                onTap: () => _openForm(_units[i]),
              ),
            ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.unit, required this.onTap});

  final BusUnit unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = !unit.isActive;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF2FF),
                child: Icon(
                  unit.vehicleType.icon,
                  color: inactive ? Colors.grey : AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.armadaName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: inactive ? AppColors.textSecondary : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${unit.plateNumber} · ${unit.vehicleType.label}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (inactive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Nonaktif',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
