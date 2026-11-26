import '../utils/wib.dart';

/// Pekerjaan yang sudah diperiksa Pengawas dan menunggu konfirmasi kondisi
/// after oleh Pengawas Operational.
class ReportableBus {
  final String id;
  final String? jobCode;
  final String plateNumber;
  final String? brand;
  final String? busType;
  final int? branchId;
  final String? branchName;
  final String? serviceName;
  final String status;
  final DateTime? enteredAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? inspectedAt;
  final String? inspectionResult;
  final String? inspectionNotes;
  final String? inspectorName;
  final String? initialNote;
  final List<String> pegawaiNames;

  /// Terisi bila laporan sudah pernah disimpan.
  final String? reportFinalStatus;
  final DateTime? reportUpdatedAt;

  const ReportableBus({
    required this.id,
    required this.plateNumber,
    required this.status,
    this.jobCode,
    this.brand,
    this.busType,
    this.branchId,
    this.branchName,
    this.serviceName,
    this.enteredAt,
    this.startedAt,
    this.finishedAt,
    this.inspectedAt,
    this.inspectionResult,
    this.inspectionNotes,
    this.inspectorName,
    this.initialNote,
    this.pegawaiNames = const [],
    this.reportFinalStatus,
    this.reportUpdatedAt,
  });

  bool get hasReport => reportFinalStatus != null;

  String get inspectionLabel => switch (inspectionResult) {
    'bersih' => 'Bersih',
    'cukup' => 'Cukup',
    'kurang' => 'Kurang',
    final other => other ?? '-',
  };

  String get brandLabel {
    final value = brand?.trim() ?? '';
    return value.isEmpty ? '-' : value;
  }

  String get dateLabel {
    final at = inspectedAt ?? finishedAt ?? enteredAt;
    return at == null ? '-' : wibDateLabel(at);
  }

  /// "GREGORY /Single Decker/N 7204 UJ" — jenis bus dilewati bila kosong.
  String get busLabel {
    final type = busType?.trim() ?? '';
    return type.isEmpty
        ? '$brandLabel /$plateNumber'
        : '$brandLabel /$type/$plateNumber';
  }

  /// "Tim A (4 Personel)" — nama pelaksana yang tercatat pada pekerjaan.
  String get teamLabel {
    if (pegawaiNames.isEmpty) return '-';
    return '${pegawaiNames.join(', ')} (${pegawaiNames.length} Personel)';
  }

  factory ReportableBus.fromJson(Map<String, dynamic> j) {
    final names =
        (j['pegawai_names'] as String?)
            ?.split(', ')
            .map((n) => n.trim())
            .where((n) => n.isNotEmpty)
            .toList() ??
        <String>[];
    final report = j['report'] as Map<String, dynamic>?;

    return ReportableBus(
      id: j['id'] as String,
      jobCode: j['job_code'] as String?,
      plateNumber: (j['plate_number'] as String?) ?? '-',
      brand: j['brand'] as String?,
      busType: j['bus_type'] as String?,
      branchId: (j['branch_id'] as num?)?.toInt(),
      branchName: j['branch_name'] as String?,
      serviceName: j['service_name'] as String?,
      status: (j['status'] as String?) ?? '',
      enteredAt: _parse(j['entered_at']),
      startedAt: _parse(j['started_at']),
      finishedAt: _parse(j['finished_at']),
      inspectedAt: _parse(j['inspected_at']),
      inspectionResult: j['inspection_result'] as String?,
      inspectionNotes: j['inspection_notes'] as String?,
      inspectorName: j['inspector_name'] as String?,
      initialNote: j['initial_condition_notes'] as String?,
      pegawaiNames: names,
      reportFinalStatus: report?['final_status'] as String?,
      reportUpdatedAt: _parse(report?['updated_at']),
    );
  }
}

/// Isi laporan yang diketik Pengawas Operational untuk satu pekerjaan.
class OperationalReport {
  final String reportDate;
  final String shift;
  final String poolName;
  final String teamName;
  final String busLabel;
  final String afterNotes;
  final String findings;
  final String constraints;
  final String finalStatus;

  const OperationalReport({
    required this.reportDate,
    required this.shift,
    required this.poolName,
    required this.teamName,
    required this.busLabel,
    required this.afterNotes,
    this.findings = '',
    this.constraints = '',
    this.finalStatus = 'DONE',
  });

  Map<String, dynamic> toJson() => {
    'report_date': reportDate,
    'shift': shift,
    'pool_name': poolName,
    'team_name': teamName,
    'bus_label': busLabel,
    'after_notes': afterNotes,
    'findings': findings,
    'constraints': constraints,
    'final_status': finalStatus,
  };

  factory OperationalReport.fromJson(Map<String, dynamic> j) {
    return OperationalReport(
      reportDate: (j['report_date'] as String?) ?? '',
      shift: (j['shift'] as String?) ?? '',
      poolName: (j['pool_name'] as String?) ?? '',
      teamName: (j['team_name'] as String?) ?? '',
      busLabel: (j['bus_label'] as String?) ?? '',
      afterNotes: (j['after_notes'] as String?) ?? '',
      findings: (j['findings'] as String?) ?? '',
      constraints: (j['constraints'] as String?) ?? '',
      finalStatus: (j['final_status'] as String?) ?? 'DONE',
    );
  }
}

/// Nama & tanda tangan yang tercetak di laporan (disimpan per akun).
class ReportSigner {
  final String qcName;
  final String? qcSignature;
  final String operationalName;
  final String? operationalSignature;

  const ReportSigner({
    this.qcName = '',
    this.qcSignature,
    this.operationalName = '',
    this.operationalSignature,
  });

  bool get isComplete =>
      qcName.trim().isNotEmpty && operationalName.trim().isNotEmpty;

  factory ReportSigner.fromJson(Map<String, dynamic> j) {
    return ReportSigner(
      qcName: (j['qc_name'] as String?) ?? '',
      qcSignature: j['qc_signature'] as String?,
      operationalName: (j['operational_name'] as String?) ?? '',
      operationalSignature: j['operational_signature'] as String?,
    );
  }
}

DateTime? _parse(dynamic v) => v is String ? DateTime.tryParse(v) : null;
