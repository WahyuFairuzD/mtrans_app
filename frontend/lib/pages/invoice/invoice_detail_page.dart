import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/invoice_config.dart';
import '../../models/invoice.dart';
import '../../services/api_exception.dart';
import '../../services/file_share.dart';
import '../../services/invoice_excel.dart';
import '../../services/invoice_pdf.dart';
import '../../services/invoice_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../utils/invoice_format.dart';
import '../../widgets/error_state.dart';
import '../../widgets/invoice_status_chip.dart';

/// Detail satu invoice: ringkasan, bagikan PDF atau Excel, tandai lunas, batalkan.
class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({
    super.key,
    required this.invoiceId,
    this.initial,
    this.message,
  });

  final String invoiceId;

  /// Invoice yang baru dibuat (sudah lengkap), supaya tidak perlu memuat ulang.
  final Invoice? initial;

  /// Pesan yang ditampilkan sekali saat halaman terbuka.
  final String? message;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Invoice? _invoice;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.initial;
    _loading = widget.initial == null;
    if (widget.initial == null) _load();

    final message = widget.message;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSnack(context, message);
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final invoice = await InvoiceService.instance.fetchDetail(widget.invoiceId);
      if (mounted) setState(() => _invoice = invoice);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat invoice. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Menjalankan [task] sambil mengunci tombol. Kegagalan jadi pesan singkat.
  Future<void> _run(Future<void> Function() task, String failMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, failMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List?> _signature(Invoice invoice) async {
    if (!invoice.hasSignature) return null;
    try {
      return await InvoiceService.instance.signatureBytes(invoice.id);
    } catch (_) {
      return null; // PDF tetap dibuat tanpa gambar tanda tangan
    }
  }

  Future<void> _sharePdf(BuildContext buttonContext, Invoice invoice) {
    return _run(() async {
      final logo = (await rootBundle.load(InvoiceConfig.logoAsset)).buffer.asUint8List();
      final signature = await _signature(invoice);
      final bytes = await InvoicePdf.build(invoice, logo: logo, signature: signature);

      if (!buttonContext.mounted) return;
      await FileShare.shareBytes(
        buttonContext,
        bytes: bytes,
        fileName: invoiceFileName(invoice, 'pdf'),
        mimeType: FileShare.pdfMime,
        subject: 'Invoice ${invoiceNumberLabel(invoice.number)}',
      );
    }, 'Gagal membuat PDF. Coba lagi.');
  }

  Future<void> _shareExcel(BuildContext buttonContext, Invoice invoice) {
    return _run(() async {
      final bytes = InvoiceExcel.build(invoice);

      if (!buttonContext.mounted) return;
      await FileShare.shareBytes(
        buttonContext,
        bytes: bytes,
        fileName: invoiceFileName(invoice, 'xlsx'),
        mimeType: FileShare.xlsxMime,
        subject: 'Invoice ${invoiceNumberLabel(invoice.number)}',
      );
    }, 'Gagal membuat Excel. Coba lagi.');
  }

  Future<void> _markPaid(Invoice invoice) async {
    final ok = await confirmDialog(
      context,
      title: 'Tandai lunas?',
      message: 'Invoice ${invoiceNumberLabel(invoice.number)} ditandai sudah dibayar.',
      confirmLabel: 'Tandai Lunas',
    );
    if (!ok || !mounted) return;

    await _run(() async {
      final updated = await InvoiceService.instance.markPaid(invoice.id);
      if (mounted) setState(() => _invoice = updated);
    }, 'Gagal menandai lunas. Coba lagi.');
  }

  Future<void> _void(Invoice invoice) async {
    final ok = await confirmDialog(
      context,
      title: 'Batalkan invoice?',
      message:
          'Nomor ${invoiceNumberLabel(invoice.number)} tidak dipakai lagi, dan ${invoice.lines.length} pekerjaan di dalamnya bisa ditagih di invoice lain.',
      confirmLabel: 'Batalkan Invoice',
    );
    if (!ok || !mounted) return;

    await _run(() async {
      final updated = await InvoiceService.instance.voidInvoice(invoice.id);
      if (mounted) setState(() => _invoice = updated);
    }, 'Gagal membatalkan invoice. Coba lagi.');
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          invoice == null
              ? 'Invoice'
              : 'INV ${invoiceNumberLabel(invoice.number)}',
        ),
      ),
      body: _body(invoice),
    );
  }

  Widget _body(Invoice? invoice) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (invoice == null) {
      return ErrorState(message: _error ?? 'Invoice tidak ditemukan.', onRetry: _load);
    }

    final cancelled = invoice.status == InvoiceStatus.batal;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _HeaderCard(invoice: invoice),
        if (cancelled) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Invoice ini dibatalkan. Pekerjaannya bisa ditagih di invoice lain.',
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Lampiran',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        for (final row in invoice.summary) _SummaryTile(row: row),
        const SizedBox(height: 4),
        Text(
          '${invoice.lines.length} pekerjaan · Penanda tangan: ${invoice.signerName}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (buttonContext) => FilledButton.icon(
                  onPressed: (_busy || cancelled)
                      ? null
                      : () => _sharePdf(buttonContext, invoice),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Bagikan PDF'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                  onPressed: (_busy || cancelled)
                      ? null
                      : () => _shareExcel(buttonContext, invoice),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Bagikan Excel'),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 3),
        ],
        if (invoice.status == InvoiceStatus.terbit) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _markPaid(invoice),
            icon: const Icon(Icons.check_circle_outline),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Tandai Lunas'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy ? null : () => _void(invoice),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Batalkan Invoice'),
          ),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.branchName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              InvoiceStatusChip(status: invoice.status),
            ],
          ),
          const SizedBox(height: 12),
          row('Periode', '${formatLongDate(invoice.periodStart)} - ${formatLongDate(invoice.periodEnd)}'),
          row('Tanggal', formatLongDate(invoice.invoiceDate)),
          row('Jatuh tempo', formatLongDate(invoice.dueDate)),
          const Divider(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Total', style: TextStyle(color: AppColors.textSecondary)),
              ),
              Text(
                formatRupiah(invoice.totalAmount),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.row});

  final InvoiceSummaryRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(row.vehicleType.icon, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.vehicleType.invoiceLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${row.units} unit × ${formatRupiah(row.price)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(row.total),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
