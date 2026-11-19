import 'package:flutter/material.dart';

enum VehicleType {
  bus('bus', 'Bus', 'Cuci Bus', Icons.directions_bus),
  medium(
    'medium',
    'Mobil Medium/Elf',
    'Kendaraan Umum (Medium)',
    Icons.airport_shuttle,
  ),
  kecil(
    'kecil',
    'Mobil Kecil',
    'Kendaraan Umum (Kecil)',
    Icons.directions_car,
  );

  const VehicleType(this.apiValue, this.label, this.invoiceLabel, this.icon);

  final String apiValue;

  final String label;
  final String invoiceLabel;
  final IconData icon;

  static VehicleType fromApi(String? value) => VehicleType.values.firstWhere(
    (type) => type.apiValue == value,
    orElse: () => VehicleType.bus,
  );
}

typedef PriceList = Map<VehicleType, int>;
