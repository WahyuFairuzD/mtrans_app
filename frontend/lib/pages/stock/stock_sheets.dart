import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/stock.dart';
import '../../services/api_exception.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import 'stock_page_support.dart';

class StockAdjustmentSheet extends StatefulWidget {
  const StockAdjustmentSheet({super.key, required this.item});

  final StockItem item;

  @override
  State<StockAdjustmentSheet> createState() => _StockAdjustmentSheetState();
}

class _StockAdjustmentSheetState extends State<StockAdjustmentSheet> {
  Future<void> _chooseAction(bool isAdd) async {
    final input = await showModalBottomSheet<({int amount, String message})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: stockSheetShape,
      builder: (_) => StockAmountSheet(item: widget.item, isAdd: isAdd),
    );
    if (input == null || !mounted) return;

    final item = widget.item;
    if (!isAdd && input.amount > item.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah pengurangan melebihi stok yang tersedia.'),
        ),
      );
      return;
    }

    final newQuantity = item.quantity + (isAdd ? input.amount : -input.amount);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Yakin dengan perubahan ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: 'Barang', value: item.name),
            _ConfirmRow(
              label: 'Aksi',
              value: isAdd ? 'Tambah stok' : 'Kurangi stok',
            ),
            _ConfirmRow(
              label: 'Perubahan',
              value: '${isAdd ? '+' : '−'}${input.amount} ${item.unit}',
            ),
            _ConfirmRow(
              label: 'Stok sekarang',
              value: '${item.quantity} ${item.unit}',
            ),
            _ConfirmRow(
              label: 'Setelah perubahan',
              value: '$newQuantity ${item.unit}',
            ),
            _ConfirmRow(
              label: 'Tanggal',
              value: stockFormatDate(stockNowWib()),
            ),
            if (input.message.isNotEmpty)
              _ConfirmRow(label: 'Pesan', value: input.message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: stockRed),
            child: const Text('Ya, simpan'),
          ),
        ],
      ),
    );
    if (sure == true && mounted) {
      Navigator.pop(context, (
        amount: input.amount,
        isAdd: isAdd,
        message: input.message,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final category = isOperationalStockCategory(item.category)
        ? stockCategoryOperational
        : stockCategoryEquipment;
    final color = stockCategoryColor(category);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: stockCategoryImageIcon(category, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      item.category,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stok saat ini',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} ${item.unit}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tanggal: ${stockFormatDate(stockNowWib())}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pilih perubahan stok',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _chooseAction(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: stockRed,
                    side: const BorderSide(color: stockRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.remove),
                  label: const Text('Kurangi'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _chooseAction(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: stockRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StockAmountSheet extends StatefulWidget {
  const StockAmountSheet({super.key, required this.item, required this.isAdd});

  final StockItem item;
  final bool isAdd;

  @override
  State<StockAmountSheet> createState() => _StockAmountSheetState();
}

class _StockAmountSheetState extends State<StockAmountSheet> {
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _continue() {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount < 1 || amount > maxStockAmount) {
      setState(() => _error = 'Masukkan jumlah antara 1 dan $maxStockAmount.');
      return;
    }
    Navigator.pop(context, (
      amount: amount,
      message: _messageController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isAdd
              ? 'Tambah ${widget.item.name}'
              : 'Kurangi ${widget.item.name}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: stockFieldDecoration(
            label: 'Jumlah (${widget.item.unit})',
            hint: 'Ketik jumlah, mis. 1',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageController,
          maxLines: 2,
          maxLength: 255,
          decoration: stockFieldDecoration(
            label: 'Pesan (opsional)',
            hint: 'Contoh: stok baru datang',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _continue,
            style: FilledButton.styleFrom(
              backgroundColor: stockRed,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Konfirmasi'),
          ),
        ),
      ],
    ),
  );
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

// 5. TAMBAH BARANG BARU

class AddStockItemSheet extends StatefulWidget {
  const AddStockItemSheet({super.key, required this.category});

  /// Ditentukan oleh tombol "Tambah" yang ditekan di daftar stok.
  final String category;

  @override
  State<AddStockItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddStockItemSheet> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _initialController = TextEditingController();

  bool _saving = false;
  String? _error;

  bool get _isOperationalHarian => widget.category == stockCategoryOperational;

  // Pintasan satuan menyesuaikan jenis barang (tetap boleh diketik sendiri).
  List<String> get _unitPresets => _isOperationalHarian
      ? const ['liter', 'botol', 'kg', 'pack', 'pcs']
      : const ['pcs', 'buah', 'unit', 'set'];

  String get _nameHint => _isOperationalHarian
      ? 'Contoh: Sabun cair, Pewangi'
      : 'Contoh: Sikat roda, Lap microfiber';

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();
    final initialText = _initialController.text.trim();
    final initial = initialText.isEmpty ? 0 : int.tryParse(initialText);

    String? error;
    if (name.length < 2) {
      error = 'Nama barang minimal 2 karakter.';
    } else if (unit.isEmpty) {
      error = 'Satuan wajib diisi.';
    } else if (RegExp(r'^\d+$').hasMatch(unit)) {
      error = 'Satuan tidak boleh hanya angka.';
    } else if (initial == null || initial < 0 || initial > maxStockAmount) {
      error = 'Stok awal harus antara 0 dan 1.000.000.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await StockService.instance.createItem(
        name: name,
        category: widget.category,
        unit: unit,
        initialQuantity: initial ?? 0,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Terjadi kesalahan. Coba lagi.';
      });
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final color = stockCategoryColor(widget.category);
    final caption = stockCategoryCaption(widget.category);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Judul: jelas sedang menambah apa ----------
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: stockCategoryImageIcon(
                  widget.category,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tambah ${widget.category}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (caption != null)
                      Text(
                        caption,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---------- Nama ----------
          _label('Nama barang'),
          TextField(
            controller: _nameController,
            enabled: !_saving,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            decoration: stockFieldDecoration(hint: _nameHint),
          ),
          const SizedBox(height: 18),

          // ---------- Satuan ----------
          _label('Satuan'),
          TextField(
            controller: _unitController,
            enabled: !_saving,
            maxLength: 20,
            onChanged: (_) => setState(() {}),
            decoration: stockFieldDecoration(hint: 'Contoh: pcs, liter, kg'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final unit in _unitPresets)
                stockRedChip(
                  label: unit,
                  selected: _unitController.text.trim().toLowerCase() == unit,
                  onTap: _saving
                      ? null
                      : () => setState(() => _unitController.text = unit),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // ---------- Stok awal ----------
          _label('Stok awal (opsional)'),
          TextField(
            controller: _initialController,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: stockFieldDecoration(
              hint: '0',
              helper: 'Jika diisi, tercatat di riwayat sebagai "Stok awal".',
            ),
          ),

          // ---------- Pesan error ----------
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ---------- Simpan ----------
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: stockRed,
                disabledBackgroundColor: stockRed.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Simpan barang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
