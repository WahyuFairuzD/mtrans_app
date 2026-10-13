import 'package:flutter/material.dart';

enum InspectionResult {
  bersih('bersih', 'Bersih', Icons.check_circle, Colors.green),
  cukup('cukup', 'Cukup', Icons.remove_circle, Colors.orange),
  kurang('kurang', 'Kurang', Icons.cancel, Colors.red);

  final String apiValue;
  final String label;
  final IconData icon;
  final Color color;

  const InspectionResult(this.apiValue, this.label, this.icon, this.color);
}