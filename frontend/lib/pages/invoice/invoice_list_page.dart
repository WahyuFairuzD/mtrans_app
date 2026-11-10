import 'package:flutter/material.dart';
import '../../models/invoice.dart';
import '../../services/api_exception.dart';
import '../../services/invoice_service.dart';
import '../../services/location_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/invoice_format.dart';
import '../../widgets/error_state.dart';
import '../../widgets/invoice_status_chip.dart';
import 'invoice_create_page.dart';
import 'invoice_detail_page.dart';

/// Riwayat invoice (Owner). Mengikuti pilihan lokasi di Setting.
class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  static const _pageSize = 50;

  final ScrollController _scroll = ScrollController();

  List<Invoice> _items = [];
  InvoiceStatus? _status;
  bool _ready = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _generation = 0;

  int? get _branchId => LocationSettings.instance.branchId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await LocationSettings.instance.ensureLoaded();
    } catch (_) {
      // Tanpa daftar lokasi, riwayat semua cabang tetap bisa dilihat.
    }
    if (!mounted) return;
    setState(() => _ready = true);
    await _load();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load({bool silent = false}) async {
    final gen = ++_generation;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final page = await InvoiceService.instance.fetchList(
        branchId: _branchId,
        status: _status,
        limit: _pageSize,
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items = page;
        _hasMore = page.length == _pageSize;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() => _error = 'Gagal memuat invoice. Coba lagi.');
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _error != null) return;

    final gen = _generation;
    setState(() => _loadingMore = true);

    try {
      final page = await InvoiceService.instance.fetchList(
        branchId: _branchId,
        status: _status,
        offset: _items.length,
        limit: _pageSize,
      );
      if (!mounted || gen != _generation) return;
      final known = _items.map((i) => i.id).toSet();
      setState(() {
        _items = [..._items, ...page.where((i) => !known.contains(i.id))];
        _hasMore = page.length == _pageSize;
      });
    } catch (_) {
      // Gagal memuat halaman berikutnya: biarkan daftar yang sudah ada.
    } finally {
      if (mounted && gen == _generation) setState(() => _loadingMore = false);
    }
  }

  void _setStatus(InvoiceStatus? status) {
    if (status == _status) return;
    setState(() => _status = status);
    _load();
  }

  Future<void> _create() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const InvoiceCreatePage()),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _open(Invoice invoice) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailPage(invoiceId: invoice.id),
      ),
    );
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Buat Invoice'),
      ),
      body: Column(
        children: [
          if (_ready)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    LocationSettings.instance.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          _buildStatusChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildStatusChips() {
    Widget chip(String label, InvoiceStatus? status) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _status == status,
        onSelected: (_) => _setStatus(status),
      ),
    );

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          chip('Semua', null),
          for (final status in InvoiceStatus.values) chip(status.label, status),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_ready || _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(40),
              children: const [
                Text(
                  'Belum ada invoice. Tekan "Buat Invoice" untuk membuat yang pertama.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            )
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  );
                }
                return _InvoiceTile(
                  invoice: _items[i],
                  onTap: () => _open(_items[i]),
                );
              },
            ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice, required this.onTap});

  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = invoice.status == InvoiceStatus.batal;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'INV ${invoiceNumberLabel(invoice.number)} · ${invoice.branchName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InvoiceStatusChip(status: invoice.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${formatLongDate(invoice.periodStart)} - ${formatLongDate(invoice.periodEnd)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatRupiah(invoice.totalAmount),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  decoration: cancelled ? TextDecoration.lineThrough : null,
                  color: cancelled ? AppColors.textSecondary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
