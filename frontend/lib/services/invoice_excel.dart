import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../config/invoice_config.dart';
import '../models/invoice.dart';
import '../utils/invoice_format.dart';

class InvoiceExcel {
  InvoiceExcel._();

  static final _rupiahFormat = NumFormat.custom(formatCode: '"Rp" #,##0');
  static final _border = Border(borderStyle: BorderStyle.Thin);

  static Uint8List build(Invoice invoice) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Invoice');

    _buildInvoiceSheet(excel['Invoice'], invoice);
    _buildAttachmentSheet(excel['Lampiran'], invoice);

    final bytes = excel.encode();
    if (bytes == null) throw StateError('Gagal membuat berkas Excel.');
    return Uint8List.fromList(bytes);
  }

  static CellStyle _style({
    bool bold = false,
    int? size,
    HorizontalAlign align = HorizontalAlign.Left,
    ExcelColor? background,
    bool bordered = false,
    bool wrap = false,
    NumFormat? format,
  }) {
    return CellStyle(
      bold: bold,
      fontSize: size,
      horizontalAlign: align,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: background ?? ExcelColor.none,
      textWrapping: wrap ? TextWrapping.WrapText : null,
      leftBorder: bordered ? _border : null,
      rightBorder: bordered ? _border : null,
      topBorder: bordered ? _border : null,
      bottomBorder: bordered ? _border : null,
      numberFormat: format ?? NumFormat.standard_0,
    );
  }

  static CellIndex _at(int column, int row) =>
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row);

  static void _text(
    Sheet sheet,
    int column,
    int row,
    String value, [
    CellStyle? style,
  ]) {
    sheet.updateCell(_at(column, row), TextCellValue(value), cellStyle: style);
  }

  static void _number(
    Sheet sheet,
    int column,
    int row,
    int value, [
    CellStyle? style,
  ]) {
    sheet.updateCell(_at(column, row), IntCellValue(value), cellStyle: style);
  }

  static void _formula(
    Sheet sheet,
    int column,
    int row,
    String formula, [
    CellStyle? style,
  ]) {
    sheet.updateCell(
      _at(column, row),
      FormulaCellValue(formula),
      cellStyle: style,
    );
  }

  static void _merged(
    Sheet sheet,
    int fromColumn,
    int toColumn,
    int row,
    String value,
    CellStyle style,
  ) {
    sheet.merge(
      _at(fromColumn, row),
      _at(toColumn, row),
      customValue: TextCellValue(value),
    );
    sheet.updateCell(_at(fromColumn, row), TextCellValue(value), cellStyle: style);
  }

  static int _letterhead(Sheet sheet, int lastColumn) {
    final center = HorizontalAlign.Center;
    _merged(
      sheet,
      0,
      lastColumn,
      0,
      InvoiceConfig.companyName,
      _style(bold: true, size: 15, align: center),
    );
    _merged(
      sheet,
      0,
      lastColumn,
      1,
      InvoiceConfig.companyAddress,
      _style(align: center),
    );
    _merged(
      sheet,
      0,
      lastColumn,
      2,
      InvoiceConfig.companyContact,
      _style(align: center),
    );
    return 4;
  }

  static ExcelColor get _headerColor => ExcelColor.fromHexString('FFC8C8C8');

  static void _buildInvoiceSheet(Sheet sheet, Invoice invoice) {
    const widths = [24.0, 6.0, 28.0, 18.0, 18.0, 10.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }

    var row = _letterhead(sheet, 5);

    final center = HorizontalAlign.Center;
    _merged(sheet, 0, 5, row, 'INVOICE', _style(bold: true, size: 13, align: center));
    row++;
    _merged(
      sheet,
      0,
      5,
      row,
      '(Periode ${formatLongDate(invoice.periodStart)} - ${formatLongDate(invoice.periodEnd)})',
      _style(align: center),
    );
    row += 2;

    void meta(String label, String value, {bool bold = false}) {
      _text(sheet, 0, row, label);
      _text(sheet, 2, row, value, _style(bold: bold));
      row++;
    }

    meta('Nomor', invoiceNumberLabel(invoice.number));
    meta('Tanggal', formatLongDate(invoice.invoiceDate));
    meta('Jatuh Tempo', formatLongDate(invoice.dueDate));
    meta('Kepada Yth.', InvoiceConfig.customerName, bold: true);
    meta('', InvoiceConfig.customerAddress);
    row++;

    _merged(
      sheet,
      0,
      5,
      row,
      'Pengerjaan ${InvoiceConfig.serviceText} wilayah ${invoice.branchName}, '
      '${InvoiceConfig.city} pada tanggal ${formatLongDate(invoice.periodStart)} '
      'sampai dengan tanggal ${formatLongDate(invoice.periodEnd)}, '
      'dengan rincian sebagai berikut:',
      _style(wrap: true),
    );
    sheet.setRowHeight(row, 32);
    row += 2;

    final header = _style(
      bold: true,
      align: center,
      background: _headerColor,
      bordered: true,
    );
    const titles = ['Tanggal', 'No', 'Nama Armada', 'Nomor Polisi', 'Total', 'Waktu'];
    for (var c = 0; c < titles.length; c++) {
      _text(sheet, c, row, titles[c], header);
    }
    row++;

    final firstLineRow = row;
    final cell = _style(align: center, bordered: true);
    final dateCell = _style(bold: true, align: HorizontalAlign.Left, bordered: true);
    final moneyCell = _style(
      align: HorizontalAlign.Right,
      bordered: true,
      format: _rupiahFormat,
    );

    DateTime? lastDate;
    for (var i = 0; i < invoice.lines.length; i++) {
      final line = invoice.lines[i];
      final newDay = lastDate == null || lastDate != line.exitDate;
      lastDate = line.exitDate;

      _text(sheet, 0, row, newDay ? formatLongDate(line.exitDate) : '', dateCell);
      _number(sheet, 1, row, i + 1, cell);
      _text(sheet, 2, row, line.unitName, cell);
      _text(sheet, 3, row, line.plateNumber, cell);
      _number(sheet, 4, row, line.price, moneyCell);
      _text(sheet, 5, row, line.exitTime, cell);
      row++;
    }

    final lastLineRow = row - 1;
    final bold = _style(bold: true, align: HorizontalAlign.Right, bordered: true, format: _rupiahFormat);
    for (var c = 0; c < 6; c++) {
      if (c == 4) continue;
      _text(sheet, c, row, '', cell);
    }
    _text(sheet, 3, row, 'TOTAL', _style(bold: true, align: center, bordered: true));
    if (invoice.lines.isEmpty) {
      _number(sheet, 4, row, 0, bold);
    } else {
      _formula(sheet, 4, row, 'SUM(E${firstLineRow + 1}:E${lastLineRow + 1})', bold);
    }
    row += 2;
    _text(sheet, 0, row++, 'Pembayaran dapat dilakukan melalui:');
    _text(sheet, 0, row, 'Nama Bank');
    _text(sheet, 2, row++, ': ${InvoiceConfig.bankName}');
    _text(sheet, 0, row, 'Nomor Rekening');
    _text(sheet, 2, row++, ': ${InvoiceConfig.bankAccount}');
    _text(sheet, 0, row, 'Atas Nama');
    _text(sheet, 2, row++, ': ${InvoiceConfig.bankHolder}');
    row++;
    _text(sheet, 0, row++, InvoiceConfig.closingText);
    row++;
    _text(sheet, 3, row++, InvoiceConfig.thanksText);
    _text(sheet, 3, row++, InvoiceConfig.companyName, _style(bold: true));
    row += 3;
    _text(sheet, 3, row, invoice.signerName, _style(bold: true));
  }

  static void _buildAttachmentSheet(Sheet sheet, Invoice invoice) {
    const widths = [6.0, 34.0, 10.0, 18.0, 20.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }

    var row = _letterhead(sheet, 4);
    _text(sheet, 0, row, 'LAMPIRAN:', _style(bold: true));
    row += 2;

    final header = _style(
      bold: true,
      align: HorizontalAlign.Center,
      background: _headerColor,
      bordered: true,
    );
    const titles = ['NO', 'KETERANGAN', 'UNIT', 'HARGA', 'TOTAL'];
    for (var c = 0; c < titles.length; c++) {
      _text(sheet, c, row, titles[c], header);
    }
    row++;

    final cell = _style(align: HorizontalAlign.Center, bordered: true);
    final money = _style(
      align: HorizontalAlign.Right,
      bordered: true,
      format: _rupiahFormat,
    );

    final firstRow = row;
    for (var i = 0; i < invoice.summary.length; i++) {
      final item = invoice.summary[i];
      _number(sheet, 0, row, i + 1, cell);
      _text(sheet, 1, row, item.vehicleType.invoiceLabel, cell);
      _number(sheet, 2, row, item.units, cell);
      _number(sheet, 3, row, item.price, money);
      _formula(sheet, 4, row, 'C${row + 1}*D${row + 1}', money);
      row++;
    }

    final lastRow = row - 1;
    final bold = _style(bold: true, align: HorizontalAlign.Right, bordered: true, format: _rupiahFormat);
    for (var c = 0; c < 4; c++) {
      _text(sheet, c, row, '', cell);
    }
    if (invoice.summary.isEmpty) {
      _number(sheet, 4, row, 0, bold);
    } else {
      _formula(sheet, 4, row, 'SUM(E${firstRow + 1}:E${lastRow + 1})', bold);
    }
    row += 2;

    _merged(
      sheet,
      0,
      4,
      row,
      'Total : ${formatRupiah(invoice.totalAmount)} (${terbilangRupiah(invoice.totalAmount)})',
      _style(bold: true),
    );
    row += 3;

    _text(sheet, 3, row++, InvoiceConfig.companyName, _style(bold: true));
    row += 3;
    _text(sheet, 3, row, invoice.signerName, _style(bold: true));
  }
}
