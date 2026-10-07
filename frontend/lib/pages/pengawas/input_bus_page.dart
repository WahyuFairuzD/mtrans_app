import 'package:flutter/material.dart';
import '../../models/bus_wash.dart';
import '../../models/master_data.dart';
import '../../services/api_exception.dart';
import '../../services/job_service.dart';
import '../../services/master_service.dart';
import '../../theme/app_theme.dart';

class InputBusPage extends StatefulWidget {
  const InputBusPage({super.key});

  @override
  State<InputBusPage> createState() => _InputBusPageState();
}

class _InputBusPageState extends State<InputBusPage> {
  final TextEditingController _note = TextEditingController();

  List<BusUnit> _units = [];
  List<LocationItem> _locations = [];
  List<ServiceTypeItem> _services = [];

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  String? _unitId;
  String? _locationId;
  String? _serviceId;

  bool get _valid =>
      _unitId != null &&
      _locationId != null &&
      _serviceId != null &&
      !_saving;

  BusUnit? get _selectedUnit {
    for (final unit in _units) {
      if (unit.id == _unitId) return unit;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final (units, locations, services) = await (
        MasterService.instance.fetchUnits(),
        MasterService.instance.fetchLocations(),
        MasterService.instance.fetchServiceTypes(),
      ).wait;

      if (!mounted) return;

      setState(() {
        _units = units;
        _locations = locations;
        _services = services;
        if (locations.length == 1) _locationId = locations.first.id;
        if (services.length == 1) _serviceId = services.first.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Gagal memuat data. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addUnit() async {
    final unit = await showModalBottomSheet<BusUnit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NewUnitSheet(),
    );

    if (unit == null || !mounted) return;

    setState(() {
      _units = [..._units, unit]
        ..sort((a, b) => a.plateNumber.compareTo(b.plateNumber));
      _unitId = unit.id;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (!_valid) return;

    setState(() => _saving = true);

    try {
      final note = _note.text.trim();

      final bus = await JobService.instance.createJob(
        unitId: _unitId!,
        locationId: _locationId!,
        serviceTypeId: _serviceId!,
        initialNote: note.isEmpty ? null : note,
      );

      if (!mounted) return;
      Navigator.pop<BusWash>(context, bus);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Input Bus Datang')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Input Bus Datang')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final unit = _selectedUnit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Bus Datang'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          DropdownButtonFormField<String>(
            key: ValueKey('unit-$_unitId'),
            value: _unitId,
            isExpanded: true,
            decoration: _decoration('Nomor Polisi'),
            items: _units
                .map(
                  (u) => DropdownMenuItem<String>(
                    value: u.id,
                    child: Text(u.plateNumber),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _unitId = value),
          ),

          const SizedBox(height: 4),

          Row(
            children: [
              Expanded(
                child: Text(
                  unit != null
                      ? 'Merek: ${unit.brand ?? '-'}'
                      : (_units.isEmpty
                          ? 'Belum ada unit. Tambahkan dulu.'
                          : ''),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addUnit,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Unit baru'),
              ),
            ],
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('loc-$_locationId'),
            value: _locationId,
            isExpanded: true,
            decoration: _decoration('Lokasi'),
            items: _locations
                .map(
                  (l) => DropdownMenuItem<String>(
                    value: l.id,
                    child: Text(l.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _locationId = value),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            key: ValueKey('svc-$_serviceId'),
            value: _serviceId,
            isExpanded: true,
            decoration: _decoration('Jenis Layanan'),
            items: _services
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(s.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _serviceId = value),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 500,
            decoration: _decoration('Catatan kondisi awal (opsional)')
                .copyWith(alignLabelWithHint: true),
          ),

          const SizedBox(height: 12),

          const Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Waktu masuk dicatat otomatis saat disimpan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valid ? _save : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewUnitSheet extends StatefulWidget {
  const _NewUnitSheet();

  @override
  State<_NewUnitSheet> createState() => _NewUnitSheetState();
}

class _NewUnitSheetState extends State<_NewUnitSheet> {
  final TextEditingController _plate = TextEditingController();
  final TextEditingController _brand = TextEditingController();

  bool _saving = false;
  String? _error;

  bool get _valid =>
      _plate.text.trim().length >= 3 &&
      _brand.text.trim().isNotEmpty &&
      !_saving;

  @override
  void dispose() {
    _plate.dispose();
    _brand.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final unit = await MasterService.instance.createUnit(
        plateNumber: _plate.text.trim(),
        brand: _brand.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop<BusUnit>(context, unit);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unit Baru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                maxLength: 15,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nomor Polisi',
                  hintText: 'N 1234 AB',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _brand,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Merek Bus',
                  hintText: 'Contoh: Hino',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _valid ? _submit : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Unit'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}