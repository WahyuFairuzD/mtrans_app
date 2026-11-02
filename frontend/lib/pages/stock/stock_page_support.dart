import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

const int maxStockAmount = 1000000;
const stockRed = Color(0xFFD9191F);

// Dua segmen barang. Mau ganti nama? Cukup ubah dua teks ini.
const stockCategoryOperational = 'Operasional Harian';
const stockCategoryEquipment = 'Gudang';

/// Menyatukan nilai kategori lama dan kategori baru untuk kebutuhan filter.
bool isOperationalStockCategory(String category) {
  final normalized = category.trim().toLowerCase();
  return {stockCategoryOperational.toLowerCase()}.contains(normalized);
}

String stockCategoryIconAsset(String category) =>
    isOperationalStockCategory(category)
    ? 'assets/images/stock_operational.png'
    : 'assets/images/stock_warehouse.png';

Widget stockCategoryImageIcon(
  String category, {
  required double size,
  Color? color,
}) => Image.asset(
  stockCategoryIconAsset(category),
  width: size,
  height: size,
  fit: BoxFit.contain,
  color: color,
  colorBlendMode: color == null ? null : BlendMode.srcIn,
);

Color stockCategoryColor(String category) => switch (category) {
  stockCategoryOperational => Colors.blue,
  stockCategoryEquipment => Colors.deepOrange,
  _ => Colors.blueGrey,
};

String? stockCategoryCaption(String category) => switch (category) {
  stockCategoryOperational => 'Bahan habis pakai',
  stockCategoryEquipment => 'Alat kerja dan alat cuci',
  _ => null,
};

String stockTwo(int n) => n.toString().padLeft(2, '0');

String stockFormatDate(DateTime t) =>
    '${stockTwo(t.day)}/${stockTwo(t.month)}/${t.year}';

String stockFormatDateTime(DateTime t) =>
    '${stockFormatDate(t)}  ${stockTwo(t.hour)}:${stockTwo(t.minute)}';

DateTime stockNowWib() => DateTime.now().toUtc().add(const Duration(hours: 7));

// ===================== GAYA BERSAMA =====================
BoxDecoration stockCardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.border),
);

InputDecoration stockFieldDecoration({
  String? hint,
  String? label,
  String? helper,
  Widget? prefix,
}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c),
  );

  return InputDecoration(
    hintText: hint,
    labelText: label,
    helperText: helper,
    counterText: '',
    prefixIcon: prefix,
    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(stockRed),
    errorBorder: border(Colors.red),
    focusedErrorBorder: border(stockRed),
  );
}

Widget stockRedChip({
  required String label,
  required bool selected,
  required VoidCallback? onTap,
}) {
  return ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: onTap == null ? null : (_) => onTap(),
    selectedColor: stockRed,
    backgroundColor: Colors.white,
    labelStyle: TextStyle(
      color: selected ? Colors.white : Colors.black87,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
    side: BorderSide(color: selected ? stockRed : AppColors.border),
    shape: const StadiumBorder(),
  );
}

const stockSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
);
