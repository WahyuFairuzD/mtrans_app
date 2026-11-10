import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../config/invoice_config.dart';
import '../../models/invoice.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_service.dart';
import '../../services/location_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../utils/invoice_format.dart';
import '../../utils/wib.dart';
import '../../widgets/error_state.dart';
import '../../widgets/signature_pad.dart';
import 'invoice_detail_page.dart';

class InvoiceCreatePage extends StatefulWidget {
  const InvoiceCreatePage({super.key});

  @override
  State<InvoiceCreatePage> createState() => _InvoiceCreatePageState();
}

class _InvoiceCreatePageState extends State<InvoiceCreatePage> {
  final TextEditingController _number = TextEditingController();
  final SignatureController _signature = SignaturePad.newController();

  int? _branchId;
  late DateTimeRange _period;
  late DateTime _invoiceDate;
  late DateTime _dueDate;
  late DateTime _today;

  bool _ready = false;
  String? _bootError;

  InvoicePreview? _preview;
  bool _loadingPreview = false;
  String? _previewError;
  bool _creating = false;

  @override
  void initState() {
    super.initState();

    final now = toWib(DateTime.now());
    _today = DateTime(now.year, now.month, now.day);
    _period = _defaultPeriod(_today);
    _applyInvoiceDates();

    _signature.addListener(_onSignatureChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _signature.removeListener(_onSignatureChanged);
    _signature.dispose();
    _number.dispose();
    super.dispose();
  }

  /// Siklus tagihan 24 s/d 23 yang terakhir selesai.
  static DateTimeRange _defaultPeriod(DateTime today) {
    final end = today.day >= 24
        ? DateTime(today.year, today.month, 23)
        : DateTime(today.year, today.month - 1, 23);
    final start = DateTime(end.year, end.month - 1, 24);
    return DateTimeRange(start: start, end: end);
  }

  /// Tanggal invoice = sehari setelah akhir periode, jatuh tempo +7 hari.
  void _applyInvoiceDates() {
    _invoiceDate = DateTime(_period.end.year, _period.end.month, _period.end.day + 1);
    _dueDate = DateTime(
      _invoiceDate.year,
      _invoiceDate.month,
      _invoiceDate.day + InvoiceConfig.defaultDueDays,
    );
  }

  Future<void> _bootstrap() async {
    setState(() => _bootError = null);
    try {
      await LocationSettings.instance.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _branchId = LocationSettings.instance.branchId;
        _ready = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _bootError = e.message);
    } catch (_) {
      if (mounted) setState(() => _bootError = 'Gagal memuat daftar lokasi. Coba lagi.');
    }
  }

  void _onSignatureChanged() {
    if (mounted) setState(() {});
  }

  void _invalidatePreview() {
    _preview = null;
    _previewError = null;
  }

  // ------------------------------------------------------------------ input

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: _today,
      initialDateRange: _period,
      helpText: 'Pilih periode invoice',
      saveText: 'Pilih',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _period = picked;
      _applyInvoiceDates();
      _invalidatePreview();
    });
  }

  Future<void> _pickInvoiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(_today.year + 1, _today.month, _today.day),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _invoiceDate = picked;
      if (_dueDate.isBefore(picked)) _dueDate = picked;
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: _invoiceDate,
      lastDate: DateTime(_today.year + 2, _today.month, _today.day),
    );
    if (picked == null || !mounted) return;

    setState(() => _dueDate = picked);
  }

  // --------------------------------------------------------------- pratinjau

  Future<void> _loadPreview() async {
    final branchId = _branchId;
    if (branchId == null || _loadingPreview) return;

    setState(() {
      _loadingPreview = true;
      _previewError = null;
      _preview = null;
    });

    try {
      final preview = await InvoiceService.instance.preview(
        branchId: branchId,
        from: _period.start,
        to: _period.end,
      );
      if (mounted) setState(() => _preview = preview);
    } on ApiException catch (e) {
      if (mounted) setState(() => _previewError = e.message);
    } catch (_) {
      if (mounted) setState(() => _previewError = 'Gagal memuat pratinjau. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  // ------------------------------------------------------------------- buat

  bool get _numberValid {
    final text = _number.text.trim();
    if (text.isEmpty) return true;
    final value = int.tryParse(text);
    return value != null && value > 0;
  }

  bool get _canCreate {
    final preview = _preview;
    return preview != null &&
        preview.lines.isNotEmpty &&
        _signature.isNotEmpty &&
        _numberValid &&
        !_creating;
  }

  Future<void> _create() async {
    final preview = _preview;
    final branchId = _branchId;
    if (!_canCreate || preview == null || branchId == null) return;

    final confirmed = await confirmDialog(
      context,
      title: 'Buat invoice?',
      message:
          '${preview.lines.length} pekerjaan senilai ${formatRupiah(preview.total)} akan ditagih dan tidak bisa ditagih lagi di invoice lain.',
      confirmLabel: 'Buat Invoice',
    );
    if (!confirmed || !mounted) return;

    setState(() => _creating = true);

    try {
      final png = await _signature.toPngBytes();
      if (png == null || png.isEmpty) {
        if (mounted) showSnack(context, 'Tanda tangan belum terbaca. Coba gambar ulang.');
        return;
      }

      final result = await InvoiceService.instance.create(
        branchId: branchId,
        periodStart: _period.start,
        periodEnd: _period.end,
        invoiceDate: _invoiceDate,
        dueDate: _dueDate,
        number: int.tryParse(_number.text.trim()),
        signaturePng: png,
      );
      if (!mounted) return;

      final label = invoiceNumberLabel(result.invoice.number);
      final message = result.skippedCount > 0
          ? 'Invoice $label dibuat. ${result.skippedCount} pekerjaan dilewati karena sudah ditagih.'
          : 'Invoice $label berhasil dibuat.';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(
            invoiceId: result.invoice.id,
            initial: result.invoice,
            message: message,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  // ----------------------------------------------------------------- tampilan

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Invoice')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_bootError != null) {
      return ErrorState(message: _bootError!, onRetry: _bootstrap);
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());

    final preview = _preview;
    final hasLines = preview != null && preview.lines.isNotEmpty;
    final signer = (AuthService.instance.user?.fullName ?? '').trim().toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('Cabang'),
        _branchField(),
        const SizedBox(height: 20),
        _sectionTitle('Periode'),
        _DateField(
          icon: Icons.date_range,
          label: 'Tanggal keluar unit',
          value: '${formatLongDate(_period.start)} - ${formatLongDate(_period.end)}',
          onTap: _pickPeriod,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateField(
                icon: Icons.event,
                label: 'Tanggal invoice',
                value: formatLongDate(_invoiceDate),
                onTap: _pickInvoiceDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateField(
                icon: Icons.event_available,
                label: 'Jatuh tempo',
                value: formatLongDate(_dueDate),
                onTap: _pickDueDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _number,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: filledInputDecoration('Nomor invoice (opsional)').copyWith(
            helperText: 'Kosongkan untuk nomor berikutnya otomatis.',
            errorText: _numberValid ? null : 'Nomor harus berupa angka.',
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: (_branchId == null || _loadingPreview) ? null : _loadPreview,
          icon: _loadingPreview
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fact_check_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Lihat Pratinjau'),
          ),
        ),
        if (_previewError != null) ...[
          const SizedBox(height: 12),
          Text(_previewError!, style: TextStyle(color: Colors.red.shade700)),
        ],
        if (preview != null) ...[
          const SizedBox(height: 16),
          _PreviewCard(preview: preview),
        ],
        if (hasLines) ...[
          const SizedBox(height: 24),
          _sectionTitle('Tanda tangan'),
          SignaturePad(controller: _signature),
          if (signer.isNotEmpty)
            Text(
              'Penanda tangan: $signer',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _canCreate ? _create : null,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.receipt_long_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_creating ? 'Membuat...' : 'Buat Invoice'),
            ),
          ),
          if (_signature.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Gambar tanda tangan dulu untuk membuat invoice.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );

  /// Mengikuti Setting > Lokasi. Bila "Semua Lokasi", cabang dipilih di sini
  /// karena satu invoice hanya untuk satu cabang.
  Widget _branchField() {
    final settings = LocationSettings.instance;

    if (settings.branchId != null) {
      return _DateField(
        icon: Icons.location_on_outlined,
        label: 'Lokasi (dari Setting)',
        value: settings.label,
        onTap: null,
      );
    }

    return DropdownButtonFormField<int>(
      key: ValueKey('branch-$_branchId'),
      initialValue: _branchId,
      isExpanded: true,
      decoration: filledInputDecoration('Pilih cabang'),
      items: settings.branches
          .map((b) => DropdownMenuItem<int>(value: b.id, child: Text(b.name)))
          .toList(),
      onChanged: (value) => setState(() {
        _branchId = value;
        _invalidatePreview();
      }),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final InvoicePreview preview;

  @override
  Widget build(BuildContext context) {
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
          const Text('Pratinjau', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (preview.lines.isEmpty)
            const Text(
              'Tidak ada pekerjaan yang bisa ditagih pada periode ini.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            for (final row in preview.summary)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${row.vehicleType.invoiceLabel} · ${row.units} unit × ${formatRupiah(row.price)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      formatRupiah(row.total),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total (${preview.lines.length} pekerjaan)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  formatRupiah(preview.total),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
          if (preview.skippedCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${preview.skippedCount} pekerjaan di periode ini sudah masuk invoice lain dan dilewati.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ],
        ],
      ),
    );
  }
}
