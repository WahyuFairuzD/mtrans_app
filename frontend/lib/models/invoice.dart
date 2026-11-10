import 'package:flutter/material.dart';
import 'vehicle_type.dart';

enum InvoiceStatus {
  terbit('terbit', 'Terbit', Colors.orange),
  lunas('lunas', 'Lunas', Colors.green),
  batal('batal', 'Batal', Colors.red);

  const InvoiceStatus(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static InvoiceStatus fromApi(String? value) => InvoiceStatus.values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => InvoiceStatus.terbit,
  );
}

/// Tanggal kalender dari "YYYY-MM-DD" (tanpa zona waktu).
DateTime _day(String value) => DateTime.parse(value.substring(0, 10));

/// Satu baris rincian invoice: satu pekerjaan yang unitnya sudah keluar.
class InvoiceLine {
  const InvoiceLine({
    required this.jobId,
    required this.exitDate,
    required this.exitTime,
    required this.unitName,
    required this.plateNumber,
    required this.vehicleType,
    required this.price,
  });

  final String jobId;

  /// Tanggal keluar (WIB).
  final DateTime exitDate;

  /// Jam keluar (WIB), format HH:mm.
  final String exitTime;
  final String unitName;
  final String plateNumber;
  final VehicleType vehicleType;
  final int price;

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
    jobId: j['job_id'] as String,
    exitDate: _day(j['exit_date'] as String),
    exitTime: j['exit_time'] as String,
    unitName: j['unit_name'] as String,
    plateNumber: j['plate_number'] as String,
    vehicleType: VehicleType.fromApi(j['vehicle_type'] as String?),
    price: (j['price'] as num).toInt(),
  );
}

/// Satu baris Lampiran: jumlah unit dan total per jenis kendaraan.
class InvoiceSummaryRow {
  const InvoiceSummaryRow({
    required this.vehicleType,
    required this.units,
    required this.price,
    required this.total,
  });

  final VehicleType vehicleType;
  final int units;
  final int price;
  final int total;

  factory InvoiceSummaryRow.fromJson(Map<String, dynamic> j) =>
      InvoiceSummaryRow(
        vehicleType: VehicleType.fromApi(j['vehicle_type'] as String?),
        units: (j['units'] as num).toInt(),
        price: (j['price'] as num).toInt(),
        total: (j['total'] as num).toInt(),
      );
}

List<InvoiceLine> _lines(dynamic raw) => raw is List
    ? raw.cast<Map<String, dynamic>>().map(InvoiceLine.fromJson).toList()
    : const [];

List<InvoiceSummaryRow> _summary(dynamic raw) => raw is List
    ? raw.cast<Map<String, dynamic>>().map(InvoiceSummaryRow.fromJson).toList()
    : const [];

/// Pratinjau isi invoice sebelum dibuat (belum tersimpan).
class InvoicePreview {
  const InvoicePreview({
    required this.lines,
    required this.skippedCount,
    required this.summary,
    required this.total,
  });

  final List<InvoiceLine> lines;

  /// Pekerjaan di periode ini yang sudah masuk invoice lain (dilewati).
  final int skippedCount;
  final List<InvoiceSummaryRow> summary;
  final int total;

  factory InvoicePreview.fromJson(Map<String, dynamic> j) => InvoicePreview(
    lines: _lines(j['lines']),
    skippedCount: (j['skipped_count'] as num?)?.toInt() ?? 0,
    summary: _summary(j['summary']),
    total: (j['total'] as num).toInt(),
  );
}

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.branchId,
    required this.branchName,
    required this.periodStart,
    required this.periodEnd,
    required this.invoiceDate,
    required this.dueDate,
    required this.status,
    required this.totalAmount,
    required this.signerName,
    required this.hasSignature,
    this.lines = const [],
    this.summary = const [],
  });

  final String id;
  final int number;
  final int branchId;
  final String branchName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final InvoiceStatus status;
  final int totalAmount;
  final String signerName;
  final bool hasSignature;

  /// Hanya terisi pada detail (bukan daftar riwayat).
  final List<InvoiceLine> lines;
  final List<InvoiceSummaryRow> summary;

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    id: j['id'] as String,
    number: (j['number'] as num).toInt(),
    branchId: (j['branch_id'] as num).toInt(),
    branchName: (j['branch_name'] as String?) ?? '',
    periodStart: _day(j['period_start'] as String),
    periodEnd: _day(j['period_end'] as String),
    invoiceDate: _day(j['invoice_date'] as String),
    dueDate: _day(j['due_date'] as String),
    status: InvoiceStatus.fromApi(j['status'] as String?),
    totalAmount: (j['total_amount'] as num).toInt(),
    signerName: (j['signer_name'] as String?) ?? '',
    hasSignature: j['signature_url'] != null,
    lines: _lines(j['items']),
    summary: _summary(j['summary']),
  );
}
