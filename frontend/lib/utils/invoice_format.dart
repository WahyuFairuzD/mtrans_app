import '../models/invoice.dart';

const _monthNames = [
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
];

/// "24 September 2026"
String formatLongDate(DateTime d) =>
    '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

/// "2026-09-24" (format tanggal untuk API).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// "Rp 32.820.000"
String formatRupiah(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}Rp $buffer';
}

/// Nomor invoice 3 digit: 43 -> "043".
String invoiceNumberLabel(int number) => number.toString().padLeft(3, '0');

const _ones = [
  '',
  'satu',
  'dua',
  'tiga',
  'empat',
  'lima',
  'enam',
  'tujuh',
  'delapan',
  'sembilan',
  'sepuluh',
  'sebelas',
];

String _join(String head, String tail) => tail.isEmpty ? head : '$head $tail';

String _say(int n) {
  if (n < 12) return _ones[n];
  if (n < 20) return '${_ones[n - 10]} belas';
  if (n < 100) return _join('${_ones[n ~/ 10]} puluh', _say(n % 10));
  if (n < 200) return _join('seratus', _say(n - 100));
  if (n < 1000) return _join('${_ones[n ~/ 100]} ratus', _say(n % 100));
  if (n < 2000) return _join('seribu', _say(n - 1000));
  if (n < 1000000) return _join('${_say(n ~/ 1000)} ribu', _say(n % 1000));
  if (n < 1000000000) {
    return _join('${_say(n ~/ 1000000)} juta', _say(n % 1000000));
  }
  if (n < 1000000000000) {
    return _join('${_say(n ~/ 1000000000)} miliar', _say(n % 1000000000));
  }
  throw RangeError('Angka terlalu besar untuk terbilang: $n');
}

/// 32820000 -> "tiga puluh dua juta delapan ratus dua puluh ribu rupiah"
String terbilangRupiah(int n) => n == 0 ? 'nol rupiah' : '${_say(n)} rupiah';

/// Nama berkas tanpa karakter yang dilarang di nama file.
String _safeName(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');

/// Contoh: "INV 043 CV KPB - 24 Agustus 2026 - 23 September 2026 CB MTRANS ARJOSARI.pdf"
String invoiceFileName(Invoice invoice, String extension) => _safeName(
  'INV ${invoiceNumberLabel(invoice.number)} CV KPB - '
  '${formatLongDate(invoice.periodStart)} - ${formatLongDate(invoice.periodEnd)} '
  'CB MTRANS ${invoice.branchName.toUpperCase()}.$extension',
);
