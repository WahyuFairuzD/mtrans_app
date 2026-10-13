import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../models/bus_wash.dart';
import '../models/history_filter.dart';
import '../models/master_data.dart';
import '../services/api_exception.dart';
import '../services/master_service.dart';
import '../services/pegawai_service.dart';
import '../theme/app_theme.dart';
import '../utils/wib.dart';

/// Mengembalikan filter baru, atau null kalau ditutup tanpa menerapkan.
Future<HistoryFilter?> showHistoryFilterSheet(
  BuildContext context, {
  required HistoryFilter current,
  required bool canFilterMaster,
}) {
  return showModalBottomSheet<HistoryFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FilterSheet(
      current: current,
      canFilterMaster: canFilterMaster,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  final HistoryFilter current;
  final bool canFilterMaster;

  const _FilterSheet({required this.current, required this.canFilterMaster});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DatePreset _preset;
  DateTime? _from;
  DateTime? _to;
  late Set<WashStatus> _statuses;
  String? _locationId;
  String? _serviceId;
  String? _pegawaiId;

  List<LocationItem> _locations = [];
  List<ServiceTypeItem> _services = [];
  List<PegawaiItem> _pegawai = [];

  bool _loadingLookups = false;
  String? _lookupError;

  @override
  void initState() {
    super.initState();

    final c = widget.current;
    _preset = c.preset;
    _from = c.customFrom;
    _to = c.customTo;
    _statuses = {...c.statuses};
    _locationId = c.locationId;
    _serviceId = c.serviceTypeId;
    _pegawaiId = c.pegawaiId;

    if (widget.canFilterMaster) _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final results = await Future.wait<Object>([
        MasterService.instance.fetchLocations(),
        MasterService.instance.fetchServiceTypes(),
        PegawaiService.instance.fetchPegawai(),
      ]);

      if (!mounted) return;

      setState(() {
        _locations = results[0] as List<LocationItem>;
        _services = results[1] as List<ServiceTypeItem>;
        _pegawai = results[2] as List<PegawaiItem>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _lookupError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _lookupError = 'Gagal memuat daftar filter.');
      }
    } finally {
      if (mounted) setState(() => _loadingLookups = false);
    }
  }

  Future<void> _pickRange() async {
    final now = toWib(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);

    final initial = (_from != null && _to != null)
        ? DateTimeRange(start: _from!, end: _to!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: today,
      initialDateRange: initial,
      helpText: 'Pilih rentang tanggal',
      saveText: 'Pilih',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _preset = DatePreset.custom;
      _from = picked.start;
      _to = picked.end;
    });
  }

  void _reset() {
    setState(() {
      _preset = DatePreset.all;
      _from = null;
      _to = null;
      _statuses = {};
      _locationId = null;
      _serviceId = null;
      _pegawaiId = null;
    });
  }

  void _apply() {
    final c = widget.current;

    Navigator.pop(
      context,
      HistoryFilter(
        preset: _preset,
        customFrom: _preset == DatePreset.custom ? _from : null,
        customTo: _preset == DatePreset.custom ? _to : null,
        statuses: _statuses,
        locationId: _locationId,
        serviceTypeId: _serviceId,
        pegawaiId: _pegawaiId,
        unitId: c.unitId,
        query: c.query,
      ),
    );
  }

  String _presetLabel(DatePreset p) {
    if (p == DatePreset.custom &&
        _preset == DatePreset.custom &&
        _from != null &&
        _to != null) {
      return '${formatDay(_from!)} - ${formatDay(_to!)}';
    }
    return p.label;
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Semua')),
          ...items,
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationValue =
        _locations.any((l) => l.id == _locationId) ? _locationId : null;
    final serviceValue =
        _services.any((s) => s.id == _serviceId) ? _serviceId : null;
    final pegawaiValue =
        _pegawai.any((p) => p.id == _pegawaiId) ? _pegawaiId : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),

            _title('Tanggal masuk'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DatePreset.values.map((p) {
                return ChoiceChip(
                  label: Text(_presetLabel(p)),
                  selected: _preset == p,
                  onSelected: (_) {
                    if (p == DatePreset.custom) {
                      _pickRange();
                    } else {
                      setState(() => _preset = p);
                    }
                  },
                );
              }).toList(),
            ),

            _title('Status'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WashStatus.values.map((s) {
                return FilterChip(
                  label: Text(s.label),
                  selected: _statuses.contains(s),
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        _statuses.add(s);
                      } else {
                        _statuses.remove(s);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            if (widget.canFilterMaster) ...[
              const SizedBox(height: 16),
              if (_loadingLookups)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else if (_lookupError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lookupError!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadLookups,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                )
              else ...[
                _dropdown(
                  label: 'Lokasi',
                  value: locationValue,
                  items: _locations
                      .map(
                        (l) => DropdownMenuItem<String?>(
                          value: l.id,
                          child: Text(l.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _locationId = v),
                ),
                _dropdown(
                  label: 'Jenis layanan',
                  value: serviceValue,
                  items: _services
                      .map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _serviceId = v),
                ),
                _dropdown(
                  label: 'Petugas',
                  value: pegawaiValue,
                  items: _pegawai
                      .map(
                        (p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _pegawaiId = v),
                ),
              ],
            ],

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _apply,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Terapkan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}