class ChecklistItem {
  final String id;
  final String label;
  final bool isRequired;
  final bool isDone;
  final int sortOrder;

  const ChecklistItem({
    required this.id,
    required this.label,
    required this.isRequired,
    required this.isDone,
    required this.sortOrder,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> j) {
    return ChecklistItem(
      id: j['id'] as String,
      label: (j['label'] as String?) ?? '-',
      isRequired: (j['is_required'] as bool?) ?? true,
      isDone: (j['is_done'] as bool?) ?? false,
      sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  ChecklistItem copyWith({bool? isDone}) {
    return ChecklistItem(
      id: id,
      label: label,
      isRequired: isRequired,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder,
    );
  }
}
