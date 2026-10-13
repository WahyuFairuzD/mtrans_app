import '../utils/wib.dart';
import 'bus_wash.dart';

enum DatePreset {
  all('Semua'),
  today('Hari ini'),
  last7('7 hari'),
  last30('30 hari'),
  custom('Pilih tanggal');

  final String label;

  const DatePreset(this.label);
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String formatDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

// Batas hari dalam WIB (UTC+7), dikirim ke server sebagai waktu UTC.
DateTime _dayStartUtc(DateTime wibDay) =>
    DateTime.utc(wibDay.year, wibDay.month, wibDay.day)
        .subtract(const Duration(hours: 7));

DateTime _dayEndUtc(DateTime wibDay) =>
    DateTime.utc(wibDay.year, wibDay.month, wibDay.day + 1)
        .subtract(const Duration(hours: 7, milliseconds: 1));

class HistoryFilter {
  final DatePreset preset;
  final DateTime? customFrom;
  final DateTime? customTo;
  final Set<WashStatus> statuses;
  final String? locationId;
  final String? serviceTypeId;
  final String? pegawaiId;
  final String? unitId;
  final String query;

  const HistoryFilter({
    this.preset = DatePreset.all,
    this.customFrom,
    this.customTo,
    this.statuses = const {},
    this.locationId,
    this.serviceTypeId,
    this.pegawaiId,
    this.unitId,
    this.query = '',
  });

  HistoryFilter withQuery(String value) {
    return HistoryFilter(
      preset: preset,
      customFrom: customFrom,
      customTo: customTo,
      statuses: statuses,
      locationId: locationId,
      serviceTypeId: serviceTypeId,
      pegawaiId: pegawaiId,
      unitId: unitId,
      query: value,
    );
  }

  /// Filter di panel (tanpa kolom pencarian dan unit) sedang dipakai.
  bool get isActive =>
      preset != DatePreset.all ||
      statuses.isNotEmpty ||
      locationId != null ||
      serviceTypeId != null ||
      pegawaiId != null;

  ({DateTime? from, DateTime? to}) get _range {
    final today = toWib(DateTime.now());

    switch (preset) {
      case DatePreset.all:
        return (from: null, to: null);
      case DatePreset.today:
        return (from: _dayStartUtc(today), to: _dayEndUtc(today));
      case DatePreset.last7:
        return (
          from: _dayStartUtc(today.subtract(const Duration(days: 6))),
          to: _dayEndUtc(today),
        );
      case DatePreset.last30:
        return (
          from: _dayStartUtc(today.subtract(const Duration(days: 29))),
          to: _dayEndUtc(today),
        );
      case DatePreset.custom:
        final from = customFrom;
        final to = customTo;
        return (
          from: from == null ? null : _dayStartUtc(from),
          to: to == null ? null : _dayEndUtc(to),
        );
    }
  }

  Map<String, dynamic> toQuery({int? limit, int? offset}) {
    final range = _range;
    final q = query.trim();
    final statusList = statuses.map((s) => s.apiValue).toList()..sort();

    return {
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
      if (statusList.isNotEmpty) 'status': statusList.join(','),
      if (locationId != null) 'location_id': locationId,
      if (serviceTypeId != null) 'service_type_id': serviceTypeId,
      if (pegawaiId != null) 'pegawai_id': pegawaiId,
      if (unitId != null) 'unit_id': unitId,
      if (range.from != null) 'from': range.from!.toIso8601String(),
      if (range.to != null) 'to': range.to!.toIso8601String(),
      if (q.isNotEmpty) 'q': q,
    };
  }

  String get signature => toQuery().toString();
}