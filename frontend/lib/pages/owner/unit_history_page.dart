import 'package:flutter/material.dart';
import '../../models/history_filter.dart';
import '../../widgets/paged_bus_list.dart';

/// Semua pekerjaan dari satu unit (FR-10.5).
class UnitHistoryPage extends StatelessWidget {
  final String unitId;
  final String plateNumber;

  const UnitHistoryPage({
    super.key,
    required this.unitId,
    required this.plateNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Riwayat $plateNumber')),
      body: PagedBusList(filter: HistoryFilter(unitId: unitId)),
    );
  }
}