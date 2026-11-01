import 'package:flutter/material.dart';

import '../../models/stock.dart';
import '../../services/api_exception.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import 'stock_page_support.dart';
import 'stock_components.dart';
import 'stock_sheets.dart';

// 2. HALAMAN UTAMA

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final StockService _service = StockService.instance;
  final TextEditingController _searchController = TextEditingController();

  int _tab = 0;
  String _selectedCategory = stockCategoryOperational;
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

  /// Tampilkan hanya dua kategori operasional yang dipilih pengguna.
  List<String> get _categories => [
    stockCategoryOperational,
    stockCategoryEquipment,
  ];

  String get _effectiveCategory => _categories.contains(_selectedCategory)
      ? _selectedCategory
      : stockCategoryOperational;

  List<StockItem> get _visibleItems {
    final query = _searchText.toLowerCase();
    final selected = _effectiveCategory;
    return _items.where((item) {
      final categoryMatch = selected == stockCategoryOperational
          ? isOperationalStockCategory(item.category)
          : !isOperationalStockCategory(item.category);
      final nameMatch = item.name.toLowerCase().contains(query);
      return categoryMatch && nameMatch;
    }).toList();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final now = stockNowWib();
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

    if (amount < 1 || amount > maxStockAmount) {
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
          showDragHandle: true,
          backgroundColor: Colors.white,
          shape: stockSheetShape,
          builder: (_) => StockAdjustmentSheet(item: item),
        );
    if (result == null || !mounted) return;

    await _adjustStock(
      item,
      amount: result.amount,
      isAdd: result.isAdd,
      message: result.message,
    );
  }

  Future<void> _openAddItem(String category) async {
    final result = await showModalBottomSheet<StockChange>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: stockSheetShape,
      builder: (_) => AddStockItemSheet(category: category),
    );
    if (result == null || !mounted) return;

    final next = [..._items, result.item];
    next.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    setState(() {
      _items = next;
      if (result.movement != null) {
        _changesToday += 1;
        _movementsLoaded = false;
      }
    });

    _showMessage('Barang ${result.item.name} berhasil ditambahkan.');
  }

  // ===================== TAMPILAN =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stok')),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openAddItem(_effectiveCategory),
              backgroundColor: stockRed,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Barang'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              if (_busy)
                const LinearProgressIndicator(minHeight: 2, color: stockRed),
              _buildSummaryRow(),
              _buildTabSwitcher(),
              const SizedBox(height: 8),
              Expanded(
                child: _tab == 0 ? _buildStockTab() : _buildHistoryTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _buildSummaryCard(
            'Total barang',
            '${_items.length}',
            Icons.inventory_2_outlined,
            Colors.blue,
          ),
          const SizedBox(width: 12),
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
        padding: const EdgeInsets.all(14),
        decoration: stockCardDecoration(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
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
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero,
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textSecondary,
          selectedBackgroundColor: stockRed,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
        return StockErrorState(message: _itemsError!, onRetry: _loadItems);
      }
      return const Center(child: CircularProgressIndicator(color: stockRed));
    }

    final notFound = _visibleItems.isEmpty && _searchText.isNotEmpty;
    return Column(
      children: [
        _buildSearchField(),
        _buildCategoryChips(),
        Expanded(
          child: RefreshIndicator(
            color: stockRed,
            onRefresh: _loadItems,
            child: notFound
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 280,
                        child: StockEmptyState(hasAnyItem: _items.isNotEmpty),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: _buildSections(),
                  ),
          ),
        ),
      ],
    );
  }

  /// Tampilkan satu seksi sesuai kategori yang sedang dipilih.
  List<Widget> _buildSections() {
    final selected = _effectiveCategory;
    final searching = _searchText.isNotEmpty;
    final visible = _visibleItems;

    Widget card(StockItem item) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StockItemCard(item: item, onTap: () => _openItemDetails(item)),
    );

    List<Widget> section(String category) {
      final isOperational = category == stockCategoryOperational;
      final items = visible
          .where(
            (item) => isOperational
                ? isOperationalStockCategory(item.category)
                : !isOperationalStockCategory(item.category),
          )
          .toList();
      if (items.isEmpty && searching) return [];

      return [
        StockSectionHeader(title: category, count: items.length),
        if (items.isEmpty) const StockEmptySection() else ...items.map(card),
      ];
    }

    return section(selected);
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: stockFieldDecoration(
          hint: 'Cari barang',
          prefix: const Icon(
            Icons.search,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ),
        onChanged: (value) => setState(() => _searchText = value.trim()),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final selected = _effectiveCategory;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _categories.map((name) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: stockRedChip(
              label: name,
              selected: selected == name,
              onTap: () => setState(() => _selectedCategory = name),
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
          const LinearProgressIndicator(minHeight: 2, color: stockRed),
        _buildDateFilter(),
        Expanded(child: _buildHistoryBody()),
      ],
    );
  }

  Widget _buildDateFilter() {
    final range = _range;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    range == null
                        ? 'Semua tanggal'
                        : '${stockFormatDate(range.start)} – ${stockFormatDate(range.end)}',
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
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Menampilkan perubahan terbaru. Pakai filter tanggal untuk riwayat yang lebih lama.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryBody() {
    if (!_movementsLoaded) {
      if (_movementsError != null) {
        return StockErrorState(
          message: _movementsError!,
          onRetry: () => _loadMovements(),
        );
      }
      return const Center(child: CircularProgressIndicator(color: stockRed));
    }

    return RefreshIndicator(
      color: stockRed,
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
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _movements.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: stockRed,
                ),
              )
            : TextButton(
                onPressed: () => _loadMovements(append: true),
                style: TextButton.styleFrom(foregroundColor: stockRed),
                child: const Text('Muat lebih banyak'),
              ),
      ),
    );
  }

  Widget _buildHistoryTile(StockMovement movement) {
    final color = movement.isAddition ? Colors.green : Colors.deepOrange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: stockCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              movement.isAddition ? Icons.add : Icons.remove,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.item,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stok ${movement.quantityBefore} → ${movement.quantityAfter} ${movement.unit}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (movement.message.isNotEmpty) movement.message,
                    movement.person,
                    stockFormatDateTime(movement.time),
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${movement.isAddition ? '+' : ''}${movement.amount}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// 3. TAMPILAN KOSONG DAN ERROR
