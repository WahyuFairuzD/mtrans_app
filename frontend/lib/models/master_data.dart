import 'vehicle_type.dart';

/// Plat untuk kendaraan yang tidak punya plat.
const kNoPlate = 'KOSONG';

class BusUnit {
  final String id;
  final String plateNumber;

  /// Kolom "brand" di server dipakai sebagai Nama Armada.
  final String? brand;
  final VehicleType vehicleType;
  final bool isActive;

  const BusUnit({
    required this.id,
    required this.plateNumber,
    this.brand,
    this.vehicleType = VehicleType.bus,
    this.isActive = true,
  });

  String get armadaName {
    final name = brand?.trim() ?? '';
    return name.isEmpty ? '-' : name;
  }

  bool get hasPlate => plateNumber.trim().toUpperCase() != kNoPlate;

  /// Contoh: "Flavia · N 7351 UF". Plat KOSONG dobel dibedakan lewat nama.
  String get displayLabel => '$armadaName · $plateNumber';

  factory BusUnit.fromJson(Map<String, dynamic> j) {
    return BusUnit(
      id: j['id'] as String,
      plateNumber: j['plate_number'] as String,
      brand: j['brand'] as String?,
      vehicleType: VehicleType.fromApi(j['vehicle_type'] as String?),
      isActive: (j['is_active'] as bool?) ?? true,
    );
  }
}

class ServiceTypeItem {
  final String id;
  final String name;

  const ServiceTypeItem({required this.id, required this.name});

  factory ServiceTypeItem.fromJson(Map<String, dynamic> j) {
    return ServiceTypeItem(id: j['id'] as String, name: j['name'] as String);
  }
}
