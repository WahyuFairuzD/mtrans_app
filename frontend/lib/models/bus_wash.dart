import 'package:flutter/material.dart';
import '../utils/wib.dart';

enum WashStatus {
  terdaftar('terdaftar', 'Terdaftar', Colors.blueGrey),
  menungguDikerjakan('menunggu_dikerjakan', 'Menunggu Dikerjakan', Colors.grey),
  dalamPengerjaan('dalam_pengerjaan', 'Dalam Pengerjaan', Colors.orange),
  menungguPemeriksaan('menunggu_pemeriksaan', 'Menunggu Pemeriksaan', Colors.purple),
  selesai('selesai', 'Selesai', Colors.green),
  unitKeluar('unit_keluar', 'Unit Keluar', Colors.blue);

  final String apiValue;
  final String label;
  final Color color;

  const WashStatus(this.apiValue, this.label, this.color);

  static WashStatus fromApi(String? value) {
    return WashStatus.values.firstWhere(
      (s) => s.apiValue == value,
      orElse: () => WashStatus.terdaftar,
    );
  }
}

class Employee {
  final String name;
  final String role;
  const Employee({required this.name, required this.role});
}

class BusWash {
  final String id;
  final String? jobCode;
  final String? unitId;
  final int? branchId;
  final String? branchName;
  final String? serviceName;
  final String plateNumber;
  final String brand;
  final WashStatus status;
  final String date;
  final String? entryTime;
  final String? startTime;
  final String? endTime;
  final String? inspectionTime;
  final String? exitTime;
  final List<Employee> employees;
  final String? initialNote;
  final String? inspectionNote;

  const BusWash({
    required this.id,
    required this.plateNumber,
    required this.brand,
    required this.status,
    required this.date,
    this.jobCode,
    this.unitId,
    this.branchId,
    this.branchName,
    this.serviceName,
    this.entryTime,
    this.startTime,
    this.endTime,
    this.inspectionTime,
    this.exitTime,
    this.employees = const [],
    this.initialNote,
    this.inspectionNote,
  });

  factory BusWash.fromJson(Map<String, dynamic> j) {
    final entered = _parse(j['entered_at']);
    final brandRaw = (j['brand'] as String?)?.trim();
    final names =
        (j['pegawai_names'] as String?)
            ?.split(', ')
            .map((n) => n.trim())
            .where((n) => n.isNotEmpty)
            .toList() ??
        <String>[];

    return BusWash(
      id: j['id'] as String,
      jobCode: j['job_code'] as String?,
      unitId: j['unit_id'] as String?,
      branchId: (j['branch_id'] as num?)?.toInt(),
      branchName: j['branch_name'] as String?,
      serviceName: j['service_name'] as String?,
      plateNumber: (j['plate_number'] as String?) ?? '-',
      brand: (brandRaw == null || brandRaw.isEmpty) ? '-' : brandRaw,
      status: WashStatus.fromApi(j['status'] as String?),
      date: entered == null ? '' : wibDateLabel(entered),
      entryTime: _time(j['entered_at']),
      startTime: _time(j['started_at']),
      endTime: _time(j['finished_at']),
      inspectionTime: _time(j['inspected_at']),
      exitTime: _time(j['exited_at']),
      employees: names
          .map((n) => Employee(name: n, role: 'Petugas Cuci'))
          .toList(),
      initialNote: j['initial_condition_notes'] as String?,
      inspectionNote: _inspectionText(j),
    );
  }
}

DateTime? _parse(dynamic v) => v is String ? DateTime.tryParse(v) : null;

String? _time(dynamic v) {
  final d = _parse(v);
  return d == null ? null : wibTime(d);
}

String? _inspectionText(Map<String, dynamic> j) {
  final result = j['inspection_result'] as String?;
  if (result == null) return null;

  final label = switch (result) {
    'bersih' => 'Bersih',
    'cukup' => 'Cukup',
    'kurang' => 'Kurang',
    _ => result,
  };

  final notes = (j['inspection_notes'] as String?)?.trim();

  return (notes == null || notes.isEmpty)
      ? 'Hasil: $label'
      : 'Hasil: $label. $notes';
}
