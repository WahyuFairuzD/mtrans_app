import 'package:flutter/material.dart';
import '../models/branch.dart';
import '../theme/app_theme.dart';

class BranchFilterChips extends StatelessWidget {
  const BranchFilterChips({
    super.key,
    required this.branches,
    required this.selectedId,
    required this.onSelected,
    this.showAll = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Branch> branches;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final bool showAll;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      children: [
        if (showAll) _chip('Semua', null),
        ...branches.map((branch) => _chip(branch.name, branch.id)),
      ],
    ),
  );

  Widget _chip(String label, int? id) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selectedId == id,
      showCheckmark: false,
      selectedColor: AppColors.brand,
      labelStyle: TextStyle(
        color: selectedId == id ? Colors.white : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onSelected(id),
    ),
  );
}
