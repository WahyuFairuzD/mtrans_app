import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../config/inspection_report_config.dart';
import '../../models/bus_wash.dart';
import '../../models/operational_report.dart';
import '../../services/api_exception.dart';
import '../../services/file_share.dart';
import '../../services/report_pdf.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../utils/wib.dart';
import '../../widgets/bus_header_card.dart';
import '../../widgets/error_state.dart';
import 'report_signer_page.dart';

/// Konfirmasi kondisi after satu armada lalu export laporan inspeksi (PDF).
class OperationalReportPage extends StatefulWidget {
  const OperationalReportPage({super.key, required this.bus});

  final ReportableBus bus;

  @override
  State<OperationalReportPage> createState() => _OperationalReportPageState();
}

class _OperationalReportPageState extends State<OperationalReportPage> {
  final TextEditingController _shift = TextEditingController();
  final TextEditingController _pool = TextEditingController();
  final TextEditingController _team = TextEditingController();
  final TextEditingController _busLabel = TextEditingController();
  final TextEditingController _after = TextEditingController();
  final TextEditingController _findings = TextEditingController();
  final TextEditingController _constraints = TextEditingController();
  final TextEditingController _finalStatus = TextEditingController();

  DateTime _reportDate = DateTime.now();

  ReportSigner _signer = const ReportSigner();
  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;
  String? _loadError;

  bool get _busy => _saving || _exporting;

  bool get _valid =>
      _after.text.trim().length >= 3 &&
      _shift.text.trim().isNotEmpty &&
      _pool.text.trim().isNotEmpty &&
      _team.text.trim().isNotEmpty &&
      _busLabel.text.trim().isNotEmpty &&
      _finalStatus.text.trim().isNotEmpty &&
      !_busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _shift.dispose();
    _pool.dispose();
    _team.dispose();
    _busLabel.dispose();
    _after.dispose();
    _findings.dispose();
    _constraints.dispose();
    _finalStatus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final (report, signer) = await (
        ReportService.instance.fetchReport(widget.bus.id),
        ReportService.instance.fetchSigner(),
      ).wait;

      if (!mounted) return;

      final bus = widget.bus;
      final inspectedAt = bus.inspectedAt;

      setState(() {
        _signer = signer ?? const ReportSigner();
        _reportDate = inspectedAt == null
            ? toWib(DateTime.now())
            : toWib(inspectedAt);
        _shift.text = report?.shift ?? _defaultShift(_reportDate.hour);
        _pool.text =
            report?.poolName ??
            'MTrans Pool ${bus.branchName ?? '-'}';
        _team.text = report?.teamName ?? bus.teamLabel;
        _busLabel.text = report?.busLabel ?? bus.busLabel;
        _after.text = report?.afterNotes ?? '';
        _findings.text = report?.findings ?? '';
        _constraints.text = report?.constraints ?? '';
        _finalStatus.text = report?.finalStatus ?? 'DONE';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Gagal memuat laporan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _defaultShift(int hour) {
    if (hour >= 8 && hour < 16) return 'Shift 1 (08.00-16.00)';
    if (hour >= 16) return 'Shift 2 (16.00-24.00)';
    return 'Shift 3 (00.00-08.00)';
  }

  String get _isoReportDate =>
      '${_reportDate.year.toString().padLeft(4, '0')}-'
      '${_reportDate.month.toString().padLeft(2, '0')}-'
      '${_reportDate.day.toString().padLeft(2, '0')}';

  OperationalReport _collect() => OperationalReport(
    reportDate: _isoReportDate,
    shift: _shift.text.trim(),
    poolName: _pool.text.trim(),
    teamName: _team.text.trim(),
    busLabel: _busLabel.text.trim(),
    afterNotes: _after.text.trim(),
    findings: _findings.text.trim(),
    constraints: _constraints.text.trim(),
    finalStatus: _finalStatus.text.trim(),
  );

  Future<bool> _save() async {
    if (!_valid) return false;

    setState(() => _saving = true);

    try {
      await ReportService.instance.saveReport(widget.bus.id, _collect());
      if (!mounted) return false;
      showSnack(context, 'Laporan inspeksi tersimpan.');
      return true;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
      return false;
    } catch (_) {
      if (mounted) showSnack(context, 'Terjadi kesalahan. Coba lagi.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndStay() async {
    final saved = await _save();
    if (saved && mounted) Navigator.pop(context, true);
  }

  /// Export menyimpan dulu, lalu membuat PDF dari data yang baru disimpan.
  Future<void> _export() async {
    if (!_valid) return;

    if (!_signer.isComplete) {
      final ok = await confirmDialog(
        context,
        title: 'Nama penanda tangan belum diisi',
        message:
            'Laporan memuat nama PIC QC dan PIC Operasional. Lengkapi dulu di halaman Nama & Tanda Tangan.',
        confirmLabel: 'Atur Sekarang',
      );
      if (!ok || !mounted) return;

      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const ReportSignerPage()),
      );
      if (!mounted) return;

      final signer = await ReportService.instance.fetchSigner();
      if (!mounted) return;
      setState(() => _signer = signer ?? const ReportSigner());
      if (!_signer.isComplete) return;
    }

    setState(() => _exporting = true);

    try {
      final report = await ReportService.instance.saveReport(
        widget.bus.id,
        _collect(),
      );
      final logo = await rootBundle.load(InspectionReportConfig.logoAsset);
      final bytes = await InspectionReportPdf.build(
        bus: widget.bus,
        report: report,
        signer: _signer,
        logo: logo.buffer.asUint8List(),
      );

      if (!mounted) return;
      await FileShare.shareBytes(
        context,
        bytes: Uint8List.fromList(bytes),
        fileName: _fileName(),
        mimeType: FileShare.pdfMime,
        subject: 'Laporan Inspeksi ${widget.bus.plateNumber}',
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, 'Gagal membuat PDF. Coba lagi.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _fileName() {
    final plate = widget.bus.plateNumber.replaceAll(RegExp(r'\s+'), '-');
    return 'Laporan-Inspeksi-$plate-$_isoReportDate.pdf';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2024),
      lastDate: toWib(DateTime.now()).add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() => _reportDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Laporan Inspeksi')),
        body: _body(bus),
      ),
    );
  }

  Widget _body(ReportableBus bus) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return ErrorState(message: _loadError!, onRetry: _load);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BusHeaderCard(
          bus: BusWash(
            id: bus.id,
            plateNumber: bus.plateNumber,
            brand: bus.brandLabel,
            status: WashStatus.fromApi(bus.status),
            date: bus.dateLabel,
            branchName: bus.branchName,
            serviceName: bus.serviceName,
          ),
          extraLines: [
            'Pemeriksaan Pengawas: ${bus.inspectionLabel}',
            if (bus.inspectorName != null) 'Diperiksa: ${bus.inspectorName}',
          ],
        ),
        const SizedBox(height: 20),
        _beforeCard(bus),
        const SizedBox(height: 20),
        _sectionTitle('Data laporan'),
        const SizedBox(height: 10),
        _dateField(),
        const SizedBox(height: 12),
        _field(_shift, 'Shift operasional'),
        const SizedBox(height: 12),
        _field(_pool, 'Lokasi pool'),
        const SizedBox(height: 12),
        _field(_team, 'Tim cuci / washers'),
        const SizedBox(height: 12),
        _field(_busLabel, 'Nama / jenis bus / nopol'),
        const SizedBox(height: 20),
        _sectionTitle('Konfirmasi after'),
        const SizedBox(height: 10),
        TextField(
          controller: _after,
          enabled: !_busy,
          maxLines: 5,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
          decoration: filledInputDecoration(
            'Kondisi after (wajib)',
            multiline: true,
          ).copyWith(
            hintText: 'Contoh: Bersih tidak ada sampah di cabin penumpang',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _findings,
          enabled: !_busy,
          maxLines: 3,
          maxLength: 1000,
          decoration: filledInputDecoration(
            'Temuan hasil inspeksi (opsional)',
            multiline: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _constraints,
          enabled: !_busy,
          maxLines: 3,
          maxLength: 1000,
          decoration: filledInputDecoration(
            'Kendala lapangan (opsional)',
            multiline: true,
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Keterangan final'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['DONE', 'PERBAIKAN', 'GAGAL (REWASH)'].map((value) {
            return ChoiceChip(
              label: Text(value),
              selected: _finalStatus.text == value,
              onSelected: _busy
                  ? null
                  : (_) => setState(() => _finalStatus.text = value),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _finalStatus,
          enabled: !_busy,
          maxLength: 60,
          onChanged: (_) => setState(() {}),
          decoration: filledInputDecoration('Ket. final'),
        ),
        const SizedBox(height: 20),
        _signerCard(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _valid ? _export : null,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_exporting ? 'Menyiapkan PDF...' : 'Export PDF'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _valid ? _saveAndStay : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_saving ? 'Menyimpan...' : 'Simpan Saja'),
            ),
          ),
        ),
        if (!_valid && !_busy) ...[
          const SizedBox(height: 8),
          const Text(
            'Isi kondisi after untuk menyimpan atau export laporan.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _beforeCard(ReportableBus bus) {
    final note = bus.initialNote?.trim();
    final inspection = [
      bus.inspectionLabel,
      if (bus.inspectionNotes != null && bus.inspectionNotes!.trim().isNotEmpty)
        bus.inspectionNotes!.trim(),
    ].join(' — ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kondisi before (dari Pengawas)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            (note == null || note.isEmpty) ? '-' : note,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            'Hasil pemeriksaan: $inspection',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _signerCard() {
    return Container(
      width: double.infinity,
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
              const Expanded(
                child: Text(
                  'Penanda tangan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _openSigner,
                child: const Text('Atur'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _signer.isComplete
                ? 'PIC QC: ${_signer.qcName} • PIC Operasional: ${_signer.operationalName}'
                : 'Nama PIC QC dan PIC Operasional belum diatur.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _openSigner() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ReportSignerPage()),
    );
    if (!mounted) return;

    final signer = await ReportService.instance.fetchSigner();
    if (!mounted) return;
    setState(() => _signer = signer ?? const ReportSigner());
  }

  Widget _dateField() {
    return InkWell(
      onTap: _busy ? null : _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: filledInputDecoration('Tanggal inspeksi'),
        child: Row(
          children: [
            Expanded(child: Text(_longDate(_reportDate))),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      maxLength: 120,
      onChanged: (_) => setState(() {}),
      decoration: filledInputDecoration(label).copyWith(counterText: ''),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );
}

String _longDate(DateTime d) =>
    '${d.day} ${_monthName(d.month)} ${d.year}';

String _monthName(int month) => const [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
][month - 1];
