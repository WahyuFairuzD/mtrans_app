import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/inspection_report_config.dart';
import '../models/operational_report.dart';
import '../utils/wib.dart';

const _black = PdfColor.fromInt(0xFF000000);
const _headerGray = PdfColor.fromInt(0xFFC8C8C8);
const _badgeColors = [
  PdfColor.fromInt(0xFF3FA535),
  PdfColor.fromInt(0xFFF2D024),
  PdfColor.fromInt(0xFFD93025),
];

/// Laporan inspeksi cuci bus per armada (satu PDF untuk satu pekerjaan).
class InspectionReportPdf {
  InspectionReportPdf._();

  static Future<Uint8List> build({
    required ReportableBus bus,
    required OperationalReport report,
    required ReportSigner signer,
    required Uint8List logo,
  }) async {
    final doc = pw.Document(
      title: 'Laporan Inspeksi ${bus.plateNumber}',
      author: InspectionReportConfig.operationalRole,
    );

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(38, 30, 38, 34),
    );

    final logoImage = pw.MemoryImage(logo);
    final qcSignature = _signature(signer.qcSignature);
    final operationalSignature = _signature(signer.operationalSignature);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        maxPages: 20,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Text(
            '${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (_) => [
          _letterhead(logoImage),
          pw.SizedBox(height: 10),
          _identityTable(bus, report, signer),
          pw.SizedBox(height: 16),
          _sectionTitle('1.', 'PARAMETER DAN STATUS INSPEKSI'),
          pw.SizedBox(height: 8),
          pw.Text(
            'Penilaian status kebersihan armada didasarkan pada parameter baku berikut:',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _parameterTable(),
          pw.SizedBox(height: 16),
          _sectionTitle('2.', 'TABEL RINCIAN INSPEKSI PER ARMADA'),
          pw.SizedBox(height: 8),
          _detailTable(bus, report),
          pw.SizedBox(height: 18),
          pw.Inseparable(child: _findingTables(bus, report)),
          pw.SizedBox(height: 26),
          pw.Inseparable(
            child: _signatureBlock(
              qcSignature: qcSignature,
              qcName: signer.qcName,
              operationalSignature: operationalSignature,
              operationalName: signer.operationalName,
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.ImageProvider? _signature(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    try {
      return pw.MemoryImage(base64Decode(base64));
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _letterhead(pw.ImageProvider logo) {
    return pw.Table(
      border: pw.TableBorder.all(color: _black, width: 0.8),
      columnWidths: const {
        0: pw.FixedColumnWidth(148),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: pw.Image(logo, height: 58, fit: pw.BoxFit.contain),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              alignment: pw.Alignment.center,
              child: pw.Text(
                InspectionReportConfig.title,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _identityTable(
    ReportableBus bus,
    OperationalReport report,
    ReportSigner signer,
  ) {
    pw.Widget label(String text) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      color: _headerGray,
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
    );

    pw.Widget value(String text) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9.5)),
    );

    final date = DateTime.tryParse(report.reportDate);
    final dateText = date == null
        ? report.reportDate
        : '${date.day} ${_monthName(date.month)} ${date.year}';

    return pw.Table(
      border: pw.TableBorder.all(color: _black, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(96),
        1: pw.FlexColumnWidth(2),
        2: pw.FixedColumnWidth(88),
        3: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          children: [
            label('Tanggal Inspeksi'),
            value(dateText),
            label('Shift Operasional'),
            value(report.shift),
          ],
        ),
        pw.TableRow(
          children: [
            label('Lokasi Pool'),
            value(report.poolName),
            label('PIC QC'),
            value(signer.qcName.isEmpty ? bus.inspectorName ?? '-' : signer.qcName),
          ],
        ),
        pw.TableRow(
          children: [
            label('Nama/Jenis Bus/Nopol'),
            value(report.busLabel),
            label('Tim Cuci / Washers'),
            value(report.teamName),
          ],
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String number, String title) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 22,
          child: pw.Text(
            number,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _parameterTable() {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerGray),
        children: [
          _cell('Keterangan', bold: true),
          _cell('Kondisi\nKebersihan', bold: true),
          _cell('Parameter Penilaian Eksterior &\nInterior', bold: true),
          _cell('Tindakan Lanjutan', bold: true),
        ],
      ),
    ];

    for (var i = 0; i < InspectionReportConfig.parameters.length; i++) {
      final p = InspectionReportConfig.parameters[i];
      final color = _badgeColors[i % _badgeColors.length];

      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  color: color,
                  child: pw.Text(
                    p.badge,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: i == 1 ? _black : PdfColors.white,
                    ),
                  ),
                ),
              ),
            ),
            _cell(p.condition),
            _cell(p.parameter),
            _cell(p.action),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _black, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(84),
        1: pw.FixedColumnWidth(76),
        2: pw.FlexColumnWidth(2.4),
        3: pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  static pw.Widget _detailTable(ReportableBus bus, OperationalReport report) {
    pw.Widget header(String text) => pw.Container(
      color: _headerGray,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      ),
    );

    pw.Widget plain(String text) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      alignment: pw.Alignment.topLeft,
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );

    final exterior = InspectionReportConfig.exteriorParts;
    final interior = InspectionReportConfig.interiorParts;
    final rows = exterior.length > interior.length ? exterior.length : interior.length;

    final parts = pw.Table(
      border: pw.TableBorder.all(color: _black, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerGray),
          children: [
            header('Bagian\nEksterior'),
            header('Bagian\nInterior'),
          ],
        ),
        for (var i = 0; i < rows; i++)
          pw.TableRow(
            children: [
              plain(i < exterior.length ? exterior[i] : ''),
              plain(i < interior.length ? interior[i] : ''),
            ],
          ),
      ],
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _black, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(22),
        1: pw.FixedColumnWidth(64),
        2: pw.FlexColumnWidth(2.6),
        3: pw.FlexColumnWidth(1.7),
        4: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerGray),
          children: [
            header('No'),
            header('Waktu\npengerjaan\ncuci'),
            header('Bagian\nEksterior / Interior'),
            header('Kendala Lapangan'),
            header('Ket.\nfinal'),
          ],
        ),
        pw.TableRow(
          children: [
            plain('1'),
            plain(_washTime(bus)),
            pw.Padding(padding: const pw.EdgeInsets.all(2), child: parts),
            plain(report.constraints),
            plain(report.finalStatus),
          ],
        ),
      ],
    );
  }

  static pw.Widget _findingTables(ReportableBus bus, OperationalReport report) {
    pw.Widget label(String text) => pw.Container(
      color: _headerGray,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      alignment: pw.Alignment.topLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
    );

    pw.Widget content(pw.Widget child) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: child,
    );

    final before = _bulletText(bus.initialNote);
    final after = _bulletText(report.afterNotes);

    return pw.Table(
      border: pw.TableBorder.all(color: _black, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(112),
        1: pw.FlexColumnWidth(4),
      },
      children: [
        pw.TableRow(
          children: [
            label('Temuan Hasil Inspeksi'),
            content(_bullets(report.findings)),
          ],
        ),
        pw.TableRow(
          children: [
            label('Kondisi Before & After'),
            content(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Before :',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 3),
                  before,
                  pw.SizedBox(height: 8),
                  pw.Container(height: 0.6, color: _black),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'After :',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 3),
                  after,
                ],
              ),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            label(InspectionReportConfig.noteLabel),
            content(
              pw.Text(
                InspectionReportConfig.noteText,
                style: const pw.TextStyle(fontSize: 9.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _signatureBlock({
    required pw.ImageProvider? qcSignature,
    required String qcName,
    required pw.ImageProvider? operationalSignature,
    required String operationalName,
  }) {
    pw.Widget column({
      required String heading,
      required String role,
      required pw.ImageProvider? signature,
      required String name,
    }) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(heading, style: const pw.TextStyle(fontSize: 9.5)),
            pw.SizedBox(height: 2),
            pw.Text(
              role,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(
              height: 62,
              child: signature == null
                  ? pw.SizedBox()
                  : pw.Image(signature, fit: pw.BoxFit.contain),
            ),
            pw.Text(
              name.trim().isEmpty ? '( )' : '(${name.trim().toUpperCase()})',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        column(
          heading: InspectionReportConfig.createdBy,
          role: InspectionReportConfig.qcRole,
          signature: qcSignature,
          name: qcName,
        ),
        pw.SizedBox(width: 8),
        column(
          heading: InspectionReportConfig.inspectedBy,
          role: InspectionReportConfig.operationalRole,
          signature: operationalSignature,
          name: operationalName,
        ),
        pw.SizedBox(width: 8),
        column(
          heading: InspectionReportConfig.knownBy,
          role: InspectionReportConfig.scmRole,
          signature: null,
          name: '',
        ),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      alignment: pw.Alignment.topCenter,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _bullets(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return pw.Text('-', style: const pw.TextStyle(fontSize: 9.5));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          pw.Bullet(
            text: line.startsWith('-') ? line.substring(1).trim() : line,
            style: const pw.TextStyle(fontSize: 9.5),
            bulletMargin: const pw.EdgeInsets.only(
              top: 3,
              left: 2,
              right: 6,
            ),
            bulletSize: 2.4,
            margin: const pw.EdgeInsets.only(bottom: 2),
          ),
      ],
    );
  }

  static pw.Widget _bulletText(String? text) => _bullets(text ?? '');

  /// "09.00 - 09.45" (WIB). Tanpa jam selesai cukup jam mulai.
  static String _washTime(ReportableBus bus) {
    final start = bus.startedAt;
    final finish = bus.finishedAt;
    if (start == null) return finish == null ? '-' : wibTime(finish);
    final from = wibTime(start);
    if (finish == null) return from;
    return '$from - ${wibTime(finish)}';
  }

  static String _monthName(int month) => const [
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
}
