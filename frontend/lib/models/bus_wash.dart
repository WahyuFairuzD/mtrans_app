import 'package:flutter/material.dart';

/// Status operasional bus.
enum WashStatus {
  terdaftar('Terdaftar', Colors.blueGrey),
  menungguDikerjakan('Menunggu Dikerjakan', Colors.grey),
  dalamPengerjaan('Dalam Pengerjaan', Colors.orange),
  menungguPemeriksaan('Menunggu Pemeriksaan', Colors.purple),
  selesai('Selesai', Colors.green),
  unitKeluar('Unit Keluar', Colors.blue);

  final String label;
  final Color color;

  const WashStatus(this.label, this.color);
}

/// Data pegawai.
class Employee {
  final String name;
  final String role;

  const Employee({
    required this.name,
    required this.role,
  });
}

/// Data operasional pencucian bus.
class BusWash {
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
  final List<String> checklist;

  final String? initialNote;
  final String? inspectionNote;

  /// URL/path foto sesudah cuci.
  final String? photo;

  const BusWash({
    required this.plateNumber,
    required this.brand,
    required this.status,
    required this.date,
    this.entryTime,
    this.startTime,
    this.endTime,
    this.inspectionTime,
    this.exitTime,
    this.employees = const [],
    this.checklist = const [],
    this.initialNote,
    this.inspectionNote,
    this.photo,
  });

  BusWash copyWith({
    WashStatus? status,
    String? startTime,
    String? endTime,
    String? inspectionTime,
    String? exitTime,
    List<Employee>? employees,
    List<String>? checklist,
    String? inspectionNote,
    String? photo,
  }) {
    return BusWash(
      plateNumber: plateNumber,
      brand: brand,
      status: status ?? this.status,
      date: date,
      entryTime: entryTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      inspectionTime: inspectionTime ?? this.inspectionTime,
      exitTime: exitTime ?? this.exitTime,
      employees: employees ?? this.employees,
      checklist: checklist ?? this.checklist,
      initialNote: initialNote,
      inspectionNote: inspectionNote ?? this.inspectionNote,
      photo: photo ?? this.photo,
    );
  }
}

/// Mengambil waktu sekarang dalam format HH:mm.
String nowText() {
  final t = TimeOfDay.now();

  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}