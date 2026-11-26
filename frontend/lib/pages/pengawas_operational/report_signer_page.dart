import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../models/operational_report.dart';
import '../../services/api_exception.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../widgets/error_state.dart';
import '../../widgets/signature_pad.dart';

/// Nama & tanda tangan yang tercetak di laporan inspeksi. Disimpan per akun,
/// jadi export berikutnya tidak perlu menggambar ulang.
class ReportSignerPage extends StatefulWidget {
  const ReportSignerPage({super.key});

  @override
  State<ReportSignerPage> createState() => _ReportSignerPageState();
}

class _ReportSignerPageState extends State<ReportSignerPage> {
  final TextEditingController _qcName = TextEditingController();
  final TextEditingController _operationalName = TextEditingController();
  final SignatureController _qcSignature = SignaturePad.newController();
  final SignatureController _operationalSignature = SignaturePad.newController();

  Uint8List? _savedQc;
  Uint8List? _savedOperational;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qcName.dispose();
    _operationalName.dispose();
    _qcSignature.dispose();
    _operationalSignature.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final signer = await ReportService.instance.fetchSigner();
      if (!mounted) return;

      setState(() {
        _qcName.text = signer?.qcName ?? '';
        _operationalName.text = signer?.operationalName ?? '';
        _savedQc = _decode(signer?.qcSignature);
        _savedOperational = _decode(signer?.operationalSignature);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Gagal memuat data. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Uint8List? _decode(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  bool get _valid =>
      !_saving &&
      _qcName.text.trim().length >= 2 &&
      _operationalName.text.trim().length >= 2;

  /// Goresan baru dipakai bila ada; kalau tidak, pakai tanda tangan tersimpan.
  Future<String?> _signatureOf(
    SignatureController controller,
    Uint8List? saved,
  ) async {
    if (controller.isNotEmpty) {
      final bytes = await controller.toPngBytes();
      if (bytes != null && bytes.isNotEmpty) return base64Encode(bytes);
    }
    return saved == null ? null : base64Encode(saved);
  }

  Future<void> _save() async {
    if (!_valid) return;

    setState(() => _saving = true);

    try {
      final qc = await _signatureOf(_qcSignature, _savedQc);
      final operational = await _signatureOf(
        _operationalSignature,
        _savedOperational,
      );

      final saved = await ReportService.instance.saveSigner(
        ReportSigner(
          qcName: _qcName.text.trim(),
          qcSignature: qc,
          operationalName: _operationalName.text.trim(),
          operationalSignature: operational,
        ),
      );

      if (!mounted) return;
      _qcSignature.clear();
      _operationalSignature.clear();
      setState(() {
        _savedQc = _decode(saved.qcSignature);
        _savedOperational = _decode(saved.operationalSignature);
      });
      showSnack(context, 'Nama & tanda tangan tersimpan.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nama & Tanda Tangan')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return ErrorState(message: _loadError!, onRetry: _load);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Dibuat Oleh — PIC QC Cuci Bus',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _qcName,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          onChanged: (_) => setState(() {}),
          decoration: filledInputDecoration('Nama PIC QC'),
        ),
        const SizedBox(height: 8),
        SignaturePad(controller: _qcSignature),
        if (_savedQc != null) ...[
          const SizedBox(height: 4),
          _savedSignature('Tanda tangan tersimpan (PIC QC)', _savedQc!),
        ],
        const SizedBox(height: 24),
        const Text(
          'Diperiksa Oleh — PIC Operasional Mtrans',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _operationalName,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          onChanged: (_) => setState(() {}),
          decoration: filledInputDecoration('Nama PIC Operasional'),
        ),
        const SizedBox(height: 8),
        SignaturePad(controller: _operationalSignature),
        if (_savedOperational != null) ...[
          const SizedBox(height: 4),
          _savedSignature(
            'Tanda tangan tersimpan (PIC Operasional)',
            _savedOperational!,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _valid ? _save : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Goresan baru akan menggantikan tanda tangan tersimpan. "Hapus" hanya membersihkan goresan yang sedang digambar.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _savedSignature(String label, Uint8List bytes) {
    return Row(
      children: [
        Container(
          height: 56,
          width: 120,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
