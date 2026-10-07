class BusUnit {
  final String id;
  final String plateNumber;
  final String? brand;

  const BusUnit({
    required this.id,
    required this.plateNumber,
    this.brand,
  });

  factory BusUnit.fromJson(Map<String, dynamic> j) {
    return BusUnit(
      id: j['id'] as String,
      plateNumber: j['plate_number'] as String,
      brand: j['brand'] as String?,
    );
  }
}

class LocationItem {
  final String id;
  final String name;

  const LocationItem({required this.id, required this.name});

  factory LocationItem.fromJson(Map<String, dynamic> j) {
    return LocationItem(
      id: j['id'] as String,
      name: j['name'] as String,
    );
  }
}

class ServiceTypeItem {
  final String id;
  final String name;

  const ServiceTypeItem({required this.id, required this.name});

  factory ServiceTypeItem.fromJson(Map<String, dynamic> j) {
    return ServiceTypeItem(
      id: j['id'] as String,
      name: j['name'] as String,
    );
  }
}