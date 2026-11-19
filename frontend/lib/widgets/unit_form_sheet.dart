import 'package:flutter/material.dart';
import '../models/master_data.dart';
import '../models/vehicle_type.dart';
import '../services/api_exception.dart';
import '../services/master_service.dart';
import '../theme/app_theme.dart';

/// Form unit (bus atau mobil). [unit] null = unit baru, terisi = ubah unit.
/// Mengembalikan unit hasil simpan, atau null bila ditutup.
Future<BusUnit?> showUnitFormSheet(BuildContext context, {BusUnit? unit}) {
  return showModalBottomSheet<BusUnit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _UnitFormSheet(unit: unit),
  );
}

class _UnitFormSheet extends StatefulWidget {
  const _UnitFormSheet({this.unit});

  final BusUnit? unit;

  @override
  State<_UnitFormSheet> createState() => _UnitFormSheetState();
}

class _UnitFormSheetState extends State<_UnitFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _plate;

  late VehicleType _type;
  late bool _noPlate;
  late bool _active;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.unit != null;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_noPlate || _plate.text.trim().length >= 3) &&
      !_saving;

  @override
  void initState() {
    super.initState();
    final unit = widget.unit;
    _name = TextEditingController(text: unit?.brand ?? '');
    _noPlate = unit != null && !unit.hasPlate;
    _plate = TextEditingController(text: _noPlate ? '' : (unit?.plateNumber ?? ''));
    _type = unit?.vehicleType ?? VehicleType.bus;
    _active = unit?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final plate = _noPlate ? kNoPlate : _plate.text.trim();
      final master = MasterService.instance;

      final saved = _isEdit
          ? await master.updateUnit(
              widget.unit!.id,
              plateNumber: plate,
              armadaName: _name.text.trim(),
              vehicleType: _type,
              isActive: _active,
            )
          : await master.createUnit(
              plateNumber: plate,
              armadaName: _name.text.trim(),
              vehicleType: _type,
            );

      if (!mounted) return;
      Navigator.pop<BusUnit>(context, saved);
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
              Text(
                _isEdit ? 'Ubah Unit' : 'Unit Baru',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                onChanged: (_) => setState(() {}),
                decoration: filledInputDecoration('Nama Armada').copyWith(
                  hintText: 'Contoh: Flavia',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _plate,
                enabled: !_saving && !_noPlate,
                textCapitalization: TextCapitalization.characters,
                maxLength: 15,
                onChanged: (_) => setState(() {}),
                decoration: filledInputDecoration('Nomor Polisi').copyWith(
                  hintText: _noPlate ? kNoPlate : 'N 1234 AB',
                  counterText: '',
                ),
              ),
              CheckboxListTile(
                value: _noPlate,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _noPlate = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Kendaraan tidak punya plat'),
                subtitle: const Text('Ditulis "KOSONG" di invoice.'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Jenis kendaraan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: VehicleType.values.map((type) {
                  return ChoiceChip(
                    avatar: Icon(type.icon, size: 18),
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: _saving ? null : (_) => setState(() => _type = type),
                  );
                }).toList(),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _active,
                  onChanged: _saving ? null : (v) => setState(() => _active = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Unit aktif'),
                  subtitle: const Text(
                    'Unit nonaktif tidak muncul saat input bus datang.',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
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
                        : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Unit'),
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
