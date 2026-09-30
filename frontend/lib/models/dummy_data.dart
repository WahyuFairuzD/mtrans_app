import 'bus_wash.dart';

// -mastercarddumyyy
const masterUnits = [
  'N 3456 MN',
  'N 9012 EF',
  'N 1234 AB',
  'N 7777 QR',
  'N 5678 CD',
  'N 1111 ST',
];
const masterBrands = ['Hino', 'Mercedes-Benz', 'Scania', 'Isuzu', 'Volvo'];

const petugasList = [
  Employee(name: 'Budi Santoso', role: 'Petugas Cuci'),
  Employee(name: 'Andi Wijaya', role: 'Petugas Cuci'),
  Employee(name: 'Rudi Hartono', role: 'Petugas Cuci'),
  Employee(name: 'Joko Susilo', role: 'Petugas Cuci'),
];

const checklistItems = ['Bodi luar', 'Kaca', 'Interior', 'Lantai'];

/// SEMENTARA: petugas yang sedang "login" (pengganti data dari backend).
const currentPetugas = 'Andi Wijaya';

// op hari ini
const todayBuses = [
  BusWash(
    plateNumber: 'N 3456 MN',
    brand: 'Hino',
    status: WashStatus.terdaftar,
    date: 'Hari ini',
    entryTime: '06:40',
    initialNote: 'Kaca belakang berdebu tebal',
  ),
  BusWash(
    plateNumber: 'N 9012 EF',
    brand: 'Mercedes-Benz',
    status: WashStatus.menungguDikerjakan,
    date: 'Hari ini',
    entryTime: '07:05',
    employees: [Employee(name: 'Andi Wijaya', role: 'Petugas Cuci')],
  ),
  BusWash(
    plateNumber: 'N 1234 AB',
    brand: 'Scania',
    status: WashStatus.dalamPengerjaan,
    date: 'Hari ini',
    entryTime: '06:50',
    startTime: '08:15',
    employees: [
      Employee(name: 'Budi Santoso', role: 'Petugas Cuci'),
      Employee(name: 'Andi Wijaya', role: 'Petugas Cuci'),
    ],
  ),
  BusWash(
    plateNumber: 'N 7777 QR',
    brand: 'Hino',
    status: WashStatus.menungguPemeriksaan,
    date: 'Hari ini',
    entryTime: '06:00',
    startTime: '06:30',
    endTime: '07:20',
    employees: [Employee(name: 'Rudi Hartono', role: 'Petugas Cuci')],
    checklist: checklistItems,
  ),
  BusWash(
    plateNumber: 'N 5678 CD',
    brand: 'Isuzu',
    status: WashStatus.selesai,
    date: 'Hari ini',
    entryTime: '05:50',
    startTime: '06:10',
    endTime: '06:55',
    inspectionTime: '07:10',
    employees: [Employee(name: 'Rudi Hartono', role: 'Petugas Cuci')],
    checklist: checklistItems,
    inspectionNote: 'Bersih, tidak ada catatan.',
  ),
  BusWash(
    plateNumber: 'N 1111 ST',
    brand: 'Mercedes-Benz',
    status: WashStatus.unitKeluar,
    date: 'Hari ini',
    entryTime: '05:30',
    startTime: '05:45',
    endTime: '06:20',
    inspectionTime: '06:30',
    exitTime: '07:40',
    employees: [Employee(name: 'Andi Wijaya', role: 'Petugas Cuci')],
    checklist: checklistItems,
    inspectionNote: 'Sesuai standar.',
  ),
];

// ---------------- Riwayat hari sebelumnya ----------------
const historyBuses = [
  BusWash(
    plateNumber: 'N 4321 GH',
    brand: 'Scania',
    status: WashStatus.unitKeluar,
    date: 'Kemarin',
    entryTime: '08:40',
    startTime: '09:00',
    endTime: '10:10',
    inspectionTime: '10:20',
    exitTime: '11:00',
    employees: [
      Employee(name: 'Budi Santoso', role: 'Petugas Cuci'),
      Employee(name: 'Andi Wijaya', role: 'Petugas Cuci'),
    ],
    checklist: checklistItems,
    inspectionNote: 'Bersih.',
  ),
  BusWash(
    plateNumber: 'N 8765 IJ',
    brand: 'Hino',
    status: WashStatus.unitKeluar,
    date: 'Kemarin',
    entryTime: '13:15',
    startTime: '13:30',
    endTime: '14:15',
    inspectionTime: '14:25',
    exitTime: '15:00',
    employees: [Employee(name: 'Rudi Hartono', role: 'Petugas Cuci')],
    checklist: checklistItems,
    inspectionNote: 'Sesuai standar.',
  ),
  BusWash(
    plateNumber: 'N 2468 KL',
    brand: 'Isuzu',
    status: WashStatus.unitKeluar,
    date: '2 hari lalu',
    entryTime: '09:45',
    startTime: '10:00',
    endTime: '10:50',
    inspectionTime: '11:00',
    exitTime: '11:30',
    employees: [Employee(name: 'Joko Susilo', role: 'Petugas Cuci')],
    checklist: checklistItems,
    inspectionNote: 'Bersih.',
  ),
];