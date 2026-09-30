import 'package:flutter/material.dart';

import '../../models/bus_wash.dart';
import '../../services/app_data.dart';
import '../../theme/app_theme.dart';

class InputBusPage extends StatefulWidget {
  const InputBusPage({super.key});

  @override
  State<InputBusPage> createState() => _InputBusPageState();
}

class _InputBusPageState extends State<InputBusPage> {
  final AppData _appData = AppData.instance;

  final TextEditingController _note = TextEditingController();

  String? _plate;
  String? _brand;

  bool get _valid {
    return _plate != null && _brand != null;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_valid) return;

    final bus = BusWash(
      plateNumber: _plate!,
      brand: _brand!,
      status: WashStatus.terdaftar,
      date: 'Hari ini',
      entryTime: nowText(),
      initialNote: _note.text.trim().isEmpty
          ? null
          : _note.text.trim(),
    );

    Navigator.pop(context, bus);
  }

  Widget _dropdown({
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Bus Datang'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // NOMOR POLISI

          _dropdown(
            label: 'Nomor Polisi',
            items: _appData.masterUnits,
            onChanged: (value) {
              setState(() {
                _plate = value;
              });
            },
          ),

          const SizedBox(height: 16),

          // MEREK BUS

          _dropdown(
            label: 'Merek Bus',
            items: _appData.masterBrands,
            onChanged: (value) {
              setState(() {
                _brand = value;
              });
            },
          ),

          const SizedBox(height: 16),

          // CATATAN

          TextField(
            controller: _note,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Catatan kondisi awal (opsional)',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // INFO WAKTU

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

          // SIMPAN

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valid ? _save : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Simpan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}