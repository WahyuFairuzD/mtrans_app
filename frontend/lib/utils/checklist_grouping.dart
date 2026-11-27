import '../config/inspection_report_config.dart';
import '../models/work.dart';

/// Checklist dikelompokkan per bagian armada (Eksterior, Interior, Lainnya).
/// Urutan bagian tetap; urutan item mengikuti [ChecklistItem.sortOrder].
Map<InspectionSection, List<ChecklistItem>> groupChecklist(
  List<ChecklistItem> items,
) {
  final groups = <InspectionSection, List<ChecklistItem>>{};
  for (final item in items) {
    groups
        .putIfAbsent(InspectionReportConfig.sectionOf(item.label), () => [])
        .add(item);
  }

  return {
    for (final section in InspectionSection.values)
      if (groups[section] != null) section: groups[section]!,
  };
}
