import 'package:flutter/material.dart';
import '../models/bus_wash.dart';
import '../models/history_filter.dart';
import '../services/api_exception.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'bus_card.dart';

/// Daftar bus yang dimuat bertahap dari server sesuai filter.
class PagedBusList extends StatefulWidget {
  final HistoryFilter filter;

  /// Kalau diisi, tiap kartu punya tombol "Riwayat unit ini".
  final void Function(BusWash bus)? onUnitHistory;

  const PagedBusList({
    super.key,
    required this.filter,
    this.onUnitHistory,
  });

  @override
  State<PagedBusList> createState() => _PagedBusListState();
}

class _PagedBusListState extends State<PagedBusList>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 30;

  final ScrollController _scroll = ScrollController();

  List<BusWash> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _moreError;

  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void didUpdateWidget(covariant PagedBusList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.signature != widget.filter.signature) {
      _loadFirst();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadFirst({bool silent = false}) async {
    final gen = ++_generation;

    if (!silent) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _moreError = null;
        _items = [];
        _hasMore = true;
      });
    }

    try {
      final page = await HistoryService.instance.fetchPage(
        widget.filter,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted || gen != _generation) return;

      setState(() {
        _items = page;
        _hasMore = page.length == _pageSize;
        _error = null;
        _moreError = null;
      });
    } on ApiException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() => _error = 'Gagal memuat riwayat. Coba lagi.');
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _error != null) return;

    final gen = _generation;

    setState(() {
      _loadingMore = true;
      _moreError = null;
    });

    try {
      final page = await HistoryService.instance.fetchPage(
        widget.filter,
        limit: _pageSize,
        offset: _items.length,
      );
      if (!mounted || gen != _generation) return;

      final known = _items.map((b) => b.id).toSet();

      setState(() {
        _items = [..._items, ...page.where((b) => !known.contains(b.id))];
        _hasMore = page.length == _pageSize;
      });
    } on ApiException catch (e) {
      if (mounted && gen == _generation) setState(() => _moreError = e.message);
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() => _moreError = 'Gagal memuat data berikutnya.');
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadFirst,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = widget.filter.isActive ||
        widget.filter.query.trim().isNotEmpty ||
        widget.filter.unitId != null;

    return RefreshIndicator(
      onRefresh: () => _loadFirst(silent: true),
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(40),
              children: [
                Text(
                  filtered
                      ? 'Tidak ada data yang cocok dengan filter.'
                      : 'Belum ada riwayat pencucian.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: _items.length + 1,
              itemBuilder: (context, i) {
                if (i == _items.length) return _footer();

                final bus = _items[i];
                final onUnit = widget.onUnitHistory;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      BusCard(bus: bus, showDate: true),
                      if (onUnit != null && bus.unitId != null)
                        TextButton.icon(
                          onPressed: () => onUnit(bus),
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('Riwayat unit ini'),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _footer() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              _moreError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: _loadMore,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Semua data sudah ditampilkan.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return const SizedBox(height: 16);
  }
}