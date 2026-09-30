import 'package:flutter/foundation.dart';

import '../models/bus_wash.dart';

class AppData extends ChangeNotifier {
  AppData._();

  static final AppData instance = AppData._();

  // MASTER DATA BUS

  final List<String> masterUnits = [
    'N 3456 MN',
    'N 9012 EF',
    'N 1234 AB',
    'N 7777 QR',
    'N 5678 CD',
    'N 1111 ST',
  ];

  final List<String> masterBrands = [
    'Hino',
    'Mercedes-Benz',
    'Scania',
    'Isuzu',
    'Volvo',
  ];

  // CHECKLIST

  final List<String> checklistItems = [
    'Bodi luar',
    'Kaca',
    'Interior',
    'Lantai',
  ];

  // MASTER PEGAWAI

  final List<Employee> employees = [
    Employee(
      name: 'Roby',
      role: 'Petugas Cuci',
    ),
    Employee(
      name: 'Andi Wijaya',
      role: 'Petugas Cuci',
    ),
    Employee(
      name: 'Budi Santoso',
      role: 'Petugas Cuci',
    ),
    Employee(
      name: 'Rudi Hartono',
      role: 'Petugas Cuci',
    ),
    Employee(
      name: 'Joko Susilo',
      role: 'Petugas Cuci',
    ),
  ];

  // PEGAWAI YANG SEDANG LOGIN / TESTING

  String currentPetugas = 'Roby';

  // DATA BUS

  final List<BusWash> _buses = [];

  List<BusWash> get buses {
    return List.unmodifiable(_buses);
  }

  // TAMBAH BUS

  void addBus(BusWash bus) {
    _buses.add(bus);

    notifyListeners();
  }

  // UPDATE BUS

  void updateBus(
    BusWash oldBus,
    BusWash newBus,
  ) {
    final index = _buses.indexOf(oldBus);

    if (index == -1) {
      return;
    }

    _buses[index] = newBus;

    notifyListeners();
  }

  // HAPUS BUS

  void removeBus(BusWash bus) {
    _buses.remove(bus);

    notifyListeners();
  }

  // RESET DATA

  void resetData() {
    _buses.clear();

    notifyListeners();
  }
}