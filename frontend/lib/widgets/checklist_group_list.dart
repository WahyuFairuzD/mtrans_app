import 'package:flutter/material.dart';

import '../config/inspection_report_config.dart';
import '../models/work.dart';
import '../theme/app_theme.dart';
import '../utils/checklist_grouping.dart';

/// Checklist satu pekerjaan, dikelompokkan per bagian armada (Eksterior,
/// Interior) mengikuti laporan inspeksi cuci bus.
///
/// [onToggle] null = hanya baca. Item lama di luar daftar bagian armada
/// dikelompokkan pada bagian "Lainnya" tanpa judul.
class ChecklistGroupList extends StatelessWidget {
  const ChecklistGroupList({
    super.key,
    required this.items,
    this.onToggle,
    this.canToggle,
    this.card = true,
  });

  final List<ChecklistItem> items;
  final void Function(ChecklistItem item, bool value)? onToggle;
  final bool Function(ChecklistItem item)? canToggle;

  /// true: dibungkus kartu putih (halaman pengerjaan), false: daftar polos.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final groups = groupChecklist(items);
    final readOnly = onToggle == null;

    final rows = <Widget>[
      for (final group in groups.entries) ...[
        if (group.key != InspectionSection.other)
          _header(group.key, group.value, showCount: !readOnly),
        if (readOnly)
          ...group.value.map(_readOnlyRow)
        else
          ...group.value.map(
            (item) => CheckboxListTile(
              value: item.isDone,
              onChanged: (canToggle?.call(item) ?? true)
                  ? (v) => onToggle!(item, v ?? false)
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(item.label),
              subtitle: item.isRequired ? null : const Text('Opsional'),
            ),
          ),
      ],
    ];

    if (!card) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: rows),
    );
  }

  Widget _header(
    InspectionSection section,
    List<ChecklistItem> items, {
    required bool showCount,
  }) {
    final done = items.where((i) => i.isDone).length;

    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              section.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (showCount)
            Text(
              '$done/${items.length}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _readOnlyRow(ChecklistItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: item.isDone ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.isRequired ? item.label : '${item.label} (opsional)',
            ),
          ),
        ],
      ),
    );
  }
}
