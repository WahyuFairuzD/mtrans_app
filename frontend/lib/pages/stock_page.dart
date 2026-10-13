import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

// HALAMAN STOK
// Melihat daftar barang, menambah/mengurangi stok, dan melihat riwayat.

// 1. MODEL DATA


class _StockItem {
  _StockItem({
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
  });

  final String name;
  final String category;
  final String unit;
  int quantity;
}

/// Satu catatan perubahan stok (untuk tab Riwayat).
class _Movement {
  _Movement({
    required this.item,
    required this.amount,
    required this.person,
    required this.time,
    required this.message,
  });

  final String item;
  final int amount;
  final String person;
  final DateTime time;
  final String message;

  bool get isAddition => amount > 0;
}

// 2. SUMBER DATA (tunggguuuintegrasi backend)

// TODO backend: isi daftar ini dari Supabase.
final List<_StockItem> _items = <_StockItem>[];

// TODO backend: isi riwayat ini dari Supabase.
final List<_Movement> _movements = <_Movement>[];

// 3. FUNGSI BANTU

/// Batas jumlah sekali input.
const int _maxAmount = 1000000;

String _currentUserName() => AuthService.instance.user?.fullName ?? 'Pengguna';

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDate(DateTime t) => '${_two(t.day)}/${_two(t.month)}/${t.year}';

String _formatDateTime(DateTime t) =>
    '${_formatDate(t)}  ${_two(t.hour)}:${_two(t.minute)}';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// 4. HALAMAN UTAMA

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  static const _all = 'Semua';

  int _tab = 0; // 0 = Daftar stok, 1 = Riwayat
  String _selectedCategory = _all;
  String _searchText = '';

  List<String> get _categories {
    final names = _items.map((item) => item.category).toSet().toList()..sort();
    return [_all, ...names];
  }

  List<_StockItem> get _visibleItems {
    final query = _searchText.toLowerCase();
    return _items.where((item) {
      final categoryMatch =
          _selectedCategory == _all || item.category == _selectedCategory;
      final nameMatch = item.name.toLowerCase().contains(query);
      return categoryMatch && nameMatch;
    }).toList();
  }

  int get _changesToday {
    final now = DateTime.now();
    return _movements.where((m) => _isSameDay(m.time, now)).length;
  }

  Future<void> _adjustStock(
    _StockItem item, {
    required int amount,
    required bool isAdd,
    required String message,
  }) async {
    if (amount < 1 || amount > _maxAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan jumlah antara 1 dan 1.000.000.'),
        ),
      );
      return;
    }
    if (!isAdd && amount > item.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah pengurangan melebihi stok yang tersedia.'),
        ),
      );
      return;
    }

    final change = isAdd ? amount : -amount;

    // TODO backend: kirim perubahan ke API; sementara stok diperbarui di memori.
    setState(() {
      item.quantity += change;
      _movements.insert(
        0,
        _Movement(
          item: item.name,
          amount: change,
          person: _currentUserName(),
          time: DateTime.now(),
          message: message,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Stok ${item.name} berhasil ${isAdd ? 'ditambahkan' : 'dikurangi'}.',
        ),
      ),
    );
  }

  Future<void> _openItemDetails(_StockItem item) async {
    final result =
        await showModalBottomSheet<({int amount, bool isAdd, String message})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (_) => _StockAdjustmentSheet(item: item),
        );
    if (result == null || !mounted) return;

    await _adjustStock(
      item,
      amount: result.amount,
      isAdd: result.isAdd,
      message: result.message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stok')),
      body: Column(
        children: [
          _buildSummaryRow(),
          _buildTabSwitcher(),
          const SizedBox(height: 8),
          Expanded(child: _tab == 0 ? _buildStockTab() : _buildHistoryTab()),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _buildSummaryCard(
            'Jenis barang',
            '${_items.length}',
            Icons.inventory_2_outlined,
            Colors.blue,
          ),
          const SizedBox(width: 10),
          _buildSummaryCard(
            'Perubahan hari ini',
            '$_changesToday',
            Icons.history,
            Colors.deepOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('Daftar stok'),
            icon: Icon(Icons.inventory_outlined),
          ),
          ButtonSegment(
            value: 1,
            label: Text('Riwayat'),
            icon: Icon(Icons.history),
          ),
        ],
        selected: {_tab},
        onSelectionChanged: (value) => setState(() => _tab = value.first),
      ),
    );
  }

  // Tab 1: Daftar stok

  Widget _buildStockTab() {
    final items = _visibleItems;
    return Column(
      children: [
        _buildSearchField(),
        _buildCategoryChips(),
        Expanded(
          child: items.isEmpty
              ? const _EmptyStockState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _StockItemCard(
                    item: items[index],
                    onTap: () => _openItemDetails(items[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Cari barang',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _searchText = value.trim()),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = _categories;
    final selected = categories.contains(_selectedCategory)
        ? _selectedCategory
        : _all;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: categories.map((name) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: ChoiceChip(
              label: Text(name),
              selected: selected == name,
              onSelected: (_) => setState(() => _selectedCategory = name),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Tab 2: Riwayat

  Widget _buildHistoryTab() {
    if (_movements.isEmpty) {
      return const Center(child: Text('Belum ada perubahan stok.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _movements.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildHistoryTile(_movements[index]),
    );
  }

  Widget _buildHistoryTile(_Movement movement) {
    final color = movement.isAddition ? Colors.green : Colors.deepOrange;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(
          movement.isAddition ? Icons.add : Icons.remove,
          color: color,
        ),
      ),
      title: Text(
        movement.item,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (movement.message.isNotEmpty) movement.message,
          movement.person,
          _formatDateTime(movement.time),
        ].join(' · '),
      ),
      trailing: Text(
        '${movement.isAddition ? '+' : ''}${movement.amount}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// 5. TAMPILAN KOSONG

class _EmptyStockState extends StatelessWidget {
  const _EmptyStockState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data stok',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Daftar stok akan muncul setelah backend terhubung.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// 6. DETAIL BARANG DAN ALUR PERUBAHAN STOK

class _StockItemCard extends StatelessWidget {
  const _StockItemCard({required this.item, required this.onTap});

  final _StockItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.withValues(alpha: .12),
              child: const Icon(Icons.inventory_2_outlined, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item.category,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ketuk untuk melihat detail',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${item.quantity} ${item.unit}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    ),
  );
}

class _StockAdjustmentSheet extends StatefulWidget {
  const _StockAdjustmentSheet({required this.item});

  final _StockItem item;

  @override
  State<_StockAdjustmentSheet> createState() => _StockAdjustmentSheetState();
}

class _StockAdjustmentSheetState extends State<_StockAdjustmentSheet> {
  Future<void> _chooseAction(bool isAdd) async {
    final input = await showModalBottomSheet<({int amount, String message})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _StockAmountSheet(item: widget.item, isAdd: isAdd),
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
            _ConfirmRow(label: 'Tanggal', value: _formatDate(DateTime.now())),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            item.category,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tanggal: ${_formatDate(DateTime.now())}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                  icon: const Icon(Icons.remove),
                  label: const Text('Kurangi'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _chooseAction(true),
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

class _StockAmountSheet extends StatefulWidget {
  const _StockAmountSheet({required this.item, required this.isAdd});

  final _StockItem item;
  final bool isAdd;

  @override
  State<_StockAmountSheet> createState() => _StockAmountSheetState();
}

class _StockAmountSheetState extends State<_StockAmountSheet> {
  final _amountController = TextEditingController(text: '1');
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
    if (amount == null || amount < 1 || amount > _maxAmount) {
      setState(() => _error = 'Masukkan jumlah antara 1 dan $_maxAmount.');
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
      20,
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
          decoration: InputDecoration(
            labelText: 'Jumlah (${widget.item.unit})',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Pesan (opsional)',
            hintText: 'Contoh: stok baru datang',
            border: OutlineInputBorder(),
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
