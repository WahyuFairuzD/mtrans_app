import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stock.dart';
import '../services/api_exception.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';

const int _maxAmount = 1000000;

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDate(DateTime t) => '${_two(t.day)}/${_two(t.month)}/${t.year}';

String _formatDateTime(DateTime t) =>
    '${_formatDate(t)}  ${_two(t.hour)}:${_two(t.minute)}';

DateTime _nowWib() => DateTime.now().toUtc().add(const Duration(hours: 7));

// 2. HALAMAN UTAMA

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  static const _all = 'Semua';

  final StockService _service = StockService.instance;
  final TextEditingController _searchController = TextEditingController();

  int _tab = 0;
  String _selectedCategory = _all;
  String _searchText = '';

  // Daftar stok
  List<StockItem> _items = [];
  int _changesToday = 0;
  bool _itemsLoading = false;
  bool _itemsLoaded = false;
  String? _itemsError;

  // Riwayat
  List<StockMovement> _movements = [];
  bool _movementsLoading = false;
  bool _movementsLoaded = false;
  bool _hasMore = false;
  String? _movementsError;
  DateTimeRange? _range;
  int _movementsGen = 0;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final names = _items.map((item) => item.category).toSet().toList()..sort();
    return [_all, ...names];
  }

  List<StockItem> get _visibleItems {
    final query = _searchText.toLowerCase();
    return _items.where((item) {
      final categoryMatch =
          _selectedCategory == _all || item.category == _selectedCategory;
      final nameMatch = item.name.toLowerCase().contains(query);
      return categoryMatch && nameMatch;
    }).toList();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Muat data

  Future<void> _loadItems() async {
    if (_itemsLoading) return;

    setState(() {
      _itemsLoading = true;
      _itemsError = null;
    });

    try {
      final result = await _service.fetchItems();
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _changesToday = result.changesToday;
        _itemsLoaded = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _itemsError = e.message);
      if (_itemsLoaded) _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Terjadi kesalahan saat memuat stok. Coba lagi.';
      setState(() => _itemsError = message);
      if (_itemsLoaded) _showMessage(message);
    } finally {
      if (mounted) setState(() => _itemsLoading = false);
    }
  }

  Future<void> _loadMovements({bool append = false}) async {
    if (append && _movementsLoading) return;

    final gen = ++_movementsGen;
    setState(() {
      _movementsLoading = true;
      _movementsError = null;
    });

    try {
      final offset = append ? _movements.length : 0;
      final list = await _service.fetchMovements(
        from: _range?.start,
        to: _range?.end,
        offset: offset,
      );
      if (!mounted || gen != _movementsGen) return;
      setState(() {
        _movements = append ? [..._movements, ...list] : list;
        _hasMore = list.length >= stockPageSize;
        _movementsLoaded = true;
      });
    } on ApiException catch (e) {
      if (!mounted || gen != _movementsGen) return;
      setState(() => _movementsError = e.message);
      if (_movementsLoaded) _showMessage(e.message);
    } catch (_) {
      if (!mounted || gen != _movementsGen) return;
      const message = 'Terjadi kesalahan saat memuat riwayat. Coba lagi.';
      setState(() => _movementsError = message);
      if (_movementsLoaded) _showMessage(message);
    } finally {
      if (mounted && gen == _movementsGen) {
        setState(() => _movementsLoading = false);
      }
    }
  }

  Future<void> _pickRange() async {
    final now = _nowWib();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'Pilih rentang tanggal',
    );
    if (picked == null || !mounted) return;

    setState(() => _range = picked);
    await _loadMovements();
  }

  Future<void> _clearRange() async {
    setState(() => _range = null);
    await _loadMovements();
  }

  // Aksi

  Future<void> _adjustStock(
    StockItem item, {
    required int amount,
    required bool isAdd,
    required String message,
  }) async {
    if (_busy) return;

    if (amount < 1 || amount > _maxAmount) {
      _showMessage('Masukkan jumlah antara 1 dan 1.000.000.');
      return;
    }
    if (!isAdd && amount > item.quantity) {
      _showMessage('Jumlah pengurangan melebihi stok yang tersedia.');
      return;
    }

    setState(() => _busy = true);

    try {
      final result = await _service.adjust(
        itemId: item.id,
        amount: amount,
        isAdd: isAdd,
        message: message,
      );
      if (!mounted) return;

      setState(() {
        _items = _items
            .map((i) => i.id == result.item.id ? result.item : i)
            .toList();
        _changesToday += 1;
        _movementsLoaded = false;
      });

      _showMessage(
        'Stok ${item.name} berhasil ${isAdd ? 'ditambahkan' : 'dikurangi'}.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
      // Stok di layar bisa sudah usang (mis. diubah orang lain): muat ulang.
      if (e.statusCode == 409 || e.statusCode == 404) _loadItems();
    } catch (_) {
      if (mounted) _showMessage('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openItemDetails(StockItem item) async {
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

  Future<void> _openAddItem() async {
    final result = await showModalBottomSheet<StockChange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _AddItemSheet(items: _items),
    );
    if (result == null || !mounted) return;

    final next = [..._items, result.item];
    next.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    setState(() {
      _items = next;
      if (result.movement != null) {
        _changesToday += 1;
        _movementsLoaded = false;
      }
    });

    _showMessage('Barang ${result.item.name} berhasil ditambahkan.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stok')),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _openAddItem,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Barang'),
            )
          : null,
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
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
        onSelectionChanged: (value) {
          setState(() => _tab = value.first);
          if (_tab == 1 && !_movementsLoaded && !_movementsLoading) {
            _loadMovements();
          }
        },
      ),
    );
  }

  // Tab 1: Daftar stok

  Widget _buildStockTab() {
    if (!_itemsLoaded) {
      if (_itemsError != null) {
        return _ErrorState(message: _itemsError!, onRetry: _loadItems);
      }
      return const Center(child: CircularProgressIndicator());
    }

    final items = _visibleItems;
    return Column(
      children: [
        _buildSearchField(),
        _buildCategoryChips(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadItems,
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 280,
                        child: _EmptyStockState(hasAnyItem: _items.isNotEmpty),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _StockItemCard(
                      item: items[index],
                      onTap: () => _openItemDetails(items[index]),
                    ),
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
        controller: _searchController,
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
    return Column(
      children: [
        if (_movementsLoading && _movementsLoaded)
          const LinearProgressIndicator(minHeight: 2),
        _buildDateFilter(),
        Expanded(child: _buildHistoryBody()),
      ],
    );
  }

  Widget _buildDateFilter() {
    final range = _range;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    range == null
                        ? 'Semua tanggal'
                        : '${_formatDate(range.start)} – ${_formatDate(range.end)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (range != null)
                IconButton(
                  tooltip: 'Hapus filter',
                  onPressed: _clearRange,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (range == null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Menampilkan perubahan terbaru. Pakai filter tanggal untuk riwayat yang lebih lama.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryBody() {
    if (!_movementsLoaded) {
      if (_movementsError != null) {
        return _ErrorState(
          message: _movementsError!,
          onRetry: () => _loadMovements(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadMovements(),
      child: _movements.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 240,
                  child: Center(
                    child: Text(
                      _range == null
                          ? 'Belum ada perubahan stok.'
                          : 'Tidak ada perubahan stok pada rentang tanggal ini.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _movements.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= _movements.length) return _buildLoadMore();
                return _buildHistoryTile(_movements[index]);
              },
            ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: _movementsLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () => _loadMovements(append: true),
                child: const Text('Muat lebih banyak'),
              ),
      ),
    );
  }

  Widget _buildHistoryTile(StockMovement movement) {
    final color = movement.isAddition ? Colors.green : Colors.deepOrange;

    return ListTile(
      isThreeLine: true,
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stok ${movement.quantityBefore} → ${movement.quantityAfter} ${movement.unit}',
          ),
          Text(
            [
              if (movement.message.isNotEmpty) movement.message,
              movement.person,
              _formatDateTime(movement.time),
            ].join(' · '),
          ),
        ],
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

// 3. TAMPILAN KOSONG DAN ERROR

class _EmptyStockState extends StatelessWidget {
  const _EmptyStockState({required this.hasAnyItem});

  final bool hasAnyItem;

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
            Text(
              hasAnyItem ? 'Barang tidak ditemukan' : 'Belum ada data stok',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              hasAnyItem
                  ? 'Coba ubah kata kunci atau kategori.'
                  : 'Tekan "Tambah Barang" untuk menambahkan barang pertama.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 44, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. DETAIL BARANG DAN ALUR PERUBAHAN STOK

class _StockItemCard extends StatelessWidget {
  const _StockItemCard({required this.item, required this.onTap});

  final StockItem item;
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

  final StockItem item;

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
            _ConfirmRow(label: 'Tanggal', value: _formatDate(_nowWib())),
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
                  'Tanggal: ${_formatDate(_nowWib())}',
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

  final StockItem item;
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
          maxLength: 255,
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

// 5. TAMBAH BARANG BARU

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({required this.items});

  /// Barang yang sudah ada, dipakai untuk saran kategori dan satuan.
  final List<StockItem> items;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitController = TextEditingController();
  final _initialController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  List<String> _distinct(String Function(StockItem) pick) {
    return widget.items.map(pick).toSet().toList()..sort();
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final unit = _unitController.text.trim();
    final initialText = _initialController.text.trim();
    final initial = initialText.isEmpty ? 0 : int.tryParse(initialText);

    String? error;
    if (name.length < 2) {
      error = 'Nama barang minimal 2 karakter.';
    } else if (category.isEmpty) {
      error = 'Kategori wajib diisi.';
    } else if (unit.isEmpty) {
      error = 'Satuan wajib diisi.';
    } else if (initial == null || initial < 0 || initial > _maxAmount) {
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
        category: category,
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

  Widget _suggestions(List<String> values, TextEditingController controller) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        children: values
            .map(
              (v) => ActionChip(
                label: Text(v),
                onPressed: _saving
                    ? null
                    : () => setState(() => controller.text = v),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
          const Text(
            'Tambah barang baru',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            enabled: !_saving,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nama barang',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryController,
            enabled: !_saving,
            maxLength: 50,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              hintText: 'Contoh: Sabun, Alat, Kimia',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          _suggestions(_distinct((i) => i.category), _categoryController),
          const SizedBox(height: 12),
          TextField(
            controller: _unitController,
            enabled: !_saving,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Satuan',
              hintText: 'Contoh: liter, pcs, kg',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          _suggestions(_distinct((i) => i.unit), _unitController),
          const SizedBox(height: 12),
          TextField(
            controller: _initialController,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Stok awal (opsional)',
              helperText: 'Jika diisi, tercatat di riwayat sebagai "Stok awal".',
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
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan barang'),
            ),
          ),
        ],
      ),
    );
  }
}