import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../config/invoice_config.dart';
import '../models/invoice.dart';
import '../utils/invoice_format.dart';

const _blue = PdfColor.fromInt(0xFF1F3F9E);
const _headerGray = PdfColor.fromInt(0xFFC8C8C8);

class InvoicePdf {
  InvoicePdf._();

  static Future<Uint8List> build(
    Invoice invoice, {
    required Uint8List logo,
    Uint8List? signature,
  }) async {
    final doc = pw.Document(
      title: 'Invoice ${invoiceNumberLabel(invoice.number)}',
      author: InvoiceConfig.companyName,
      creator: InvoiceConfig.companyName,
    );

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 36),
      theme: pw.ThemeData.withFont(
        base: pw.Font.times(),
        bold: pw.Font.timesBold(),
        italic: pw.Font.timesItalic(),
        boldItalic: pw.Font.timesBoldItalic(),
      ),
    );

    final logoImage = pw.MemoryImage(logo);
    final signatureImage = signature == null ? null : pw.MemoryImage(signature);
    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        maxPages: 500,
        header: (_) => _letterhead(logoImage),
        build: (_) => [
          ..._titleBlock(invoice),
          pw.SizedBox(height: 10),
          _linesTable(invoice),
          pw.SizedBox(height: 18),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ..._paymentBlock(),
              pw.SizedBox(height: 10),
              pw.Text(InvoiceConfig.closingText, style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 8),
              _signatureBlock(invoice, signatureImage),
            ],
          ),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (_) => _letterhead(logoImage),
        build: (_) => [
          pw.Text('LAMPIRAN:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _summaryTable(invoice),
          pw.SizedBox(height: 8),
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 10),
              children: [
                const pw.TextSpan(text: 'Total : '),
                pw.TextSpan(
                  text:
                      '${formatRupiah(invoice.totalAmount)} (${terbilangRupiah(invoice.totalAmount)})',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 28),
          _signatureBlock(invoice, signatureImage, withThanks: false),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _letterhead(pw.ImageProvider logo) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 78,
            height: 58,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  InvoiceConfig.companyName,
                  style: pw.TextStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                    color: _blue,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  InvoiceConfig.companyAddress,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10, color: _blue),
                ),
                pw.Text(
                  InvoiceConfig.companyContact,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10, color: _blue),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 78),
        ],
      ),
    );
  }

  static List<pw.Widget> _titleBlock(Invoice invoice) {
    const small = pw.TextStyle(fontSize: 10);
    final bold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);

    pw.Widget meta(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 62, child: pw.Text(label, style: small)),
          pw.Text(': $value', style: small),
        ],
      ),
    );

    return [
      pw.Center(
        child: pw.Text(
          'INVOICE',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Center(
        child: pw.Text(
          '(Periode ${formatLongDate(invoice.periodStart)} - ${formatLongDate(invoice.periodEnd)})',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      pw.SizedBox(height: 14),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(InvoiceConfig.companyName, style: bold),
                pw.SizedBox(height: 2),
                pw.Text(InvoiceConfig.issuerAddress, style: small),
              ],
            ),
          ),
          pw.SizedBox(
            width: 215,
            child: pw.Column(
              children: [
                meta('Nomor', invoiceNumberLabel(invoice.number)),
                meta('Tanggal', formatLongDate(invoice.invoiceDate)),
                meta('Jatuh Tempo', formatLongDate(invoice.dueDate)),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.RichText(
        text: pw.TextSpan(
          style: small,
          children: [
            const pw.TextSpan(text: 'Kepada Yth. '),
            pw.TextSpan(text: InvoiceConfig.customerName, style: bold),
          ],
        ),
      ),
      pw.Text(InvoiceConfig.customerAddress, style: small),
      pw.SizedBox(height: 12),
      pw.Text(
        'Pengerjaan ${InvoiceConfig.serviceText} wilayah ${invoice.branchName}, '
        '${InvoiceConfig.city} pada tanggal ${formatLongDate(invoice.periodStart)} '
        'sampai dengan tanggal ${formatLongDate(invoice.periodEnd)}, '
        'dengan rincian sebagai berikut:',
        style: small,
      ),
    ];
  }

  static pw.Widget _cell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
    bool bold = false,
    double fontSize = 9.5,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.6, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _linesTable(Invoice invoice) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerGray),
        children: [
          _cell('Tanggal', bold: true, fontSize: 10),
          _cell('No', bold: true, fontSize: 10),
          _cell('Nama Armada', bold: true, fontSize: 10),
          _cell('Nomor Polisi', bold: true, fontSize: 10),
          _cell('Total', bold: true, fontSize: 10),
          _cell('Waktu', bold: true, fontSize: 10),
        ],
      ),
    ];

    DateTime? lastDate;
    for (var i = 0; i < invoice.lines.length; i++) {
      final line = invoice.lines[i];
      final newDay = lastDate == null || lastDate != line.exitDate;
      lastDate = line.exitDate;

      rows.add(
        pw.TableRow(
          children: [
            _cell(newDay ? formatLongDate(line.exitDate) : '', bold: true),
            _cell('${i + 1}'),
            _cell(line.unitName),
            _cell(line.plateNumber),
            _cell(formatRupiah(line.price)),
            _cell(line.exitTime),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        children: [
          _cell(''),
          _cell(''),
          _cell(''),
          _cell(''),
          _cell(formatRupiah(invoice.totalAmount), bold: true),
          _cell(''),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(102),
        1: pw.FixedColumnWidth(26),
        2: pw.FlexColumnWidth(2.1),
        3: pw.FlexColumnWidth(1.7),
        4: pw.FlexColumnWidth(1.5),
        5: pw.FlexColumnWidth(1.1),
      },
      children: rows,
    );
  }

  static List<pw.Widget> _paymentBlock() {
    const style = pw.TextStyle(fontSize: 9);

    pw.Widget row(String label, String value) => pw.Row(
      children: [
        pw.SizedBox(width: 82, child: pw.Text(label, style: style)),
        pw.Text(': $value', style: style),
      ],
    );

    return [
      pw.Text('Pembayaran dapat dilakukan melalui:', style: style),
      pw.SizedBox(height: 6),
      row('Nama Bank', InvoiceConfig.bankName),
      row('Nomor Rekening', InvoiceConfig.bankAccount),
      row('Atas Nama', InvoiceConfig.bankHolder),
    ];
  }

  static pw.Widget _signatureBlock(
    Invoice invoice,
    pw.ImageProvider? signature, {
    bool withThanks = true,
  }) {
    final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 200,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (withThanks)
              pw.Text(InvoiceConfig.thanksText, style: const pw.TextStyle(fontSize: 9)),
            pw.Text(InvoiceConfig.companyName, style: bold),
            pw.SizedBox(
              height: 66,
              child: signature == null
                  ? pw.SizedBox()
                  : pw.Image(signature, fit: pw.BoxFit.contain),
            ),
            pw.Text(invoice.signerName, style: bold),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summaryTable(Invoice invoice) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerGray),
        children: [
          _cell('NO', bold: true, fontSize: 10),
          _cell('KETERANGAN', bold: true, fontSize: 10),
          _cell('UNIT', bold: true, fontSize: 10),
          _cell('HARGA', bold: true, fontSize: 10),
          _cell('TOTAL', bold: true, fontSize: 10),
        ],
      ),
    ];

    for (var i = 0; i < invoice.summary.length; i++) {
      final row = invoice.summary[i];
      rows.add(
        pw.TableRow(
          children: [
            _cell('${i + 1}', fontSize: 10),
            _cell(row.vehicleType.invoiceLabel, fontSize: 10),
            _cell('${row.units}', fontSize: 10),
            _cell(formatRupiah(row.price), fontSize: 10),
            _cell(formatRupiah(row.total), fontSize: 10),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        children: [
          _cell(''),
          _cell(''),
          _cell(''),
          _cell(''),
          _cell(formatRupiah(invoice.totalAmount), bold: true, fontSize: 10),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(34),
        1: pw.FlexColumnWidth(3),
        2: pw.FixedColumnWidth(50),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.7),
      },
      children: rows,
    );
  }
}
