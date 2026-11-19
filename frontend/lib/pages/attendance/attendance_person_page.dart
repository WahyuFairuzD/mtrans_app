import 'package:flutter/material.dart';

import '../../models/attendance.dart';
import '../../services/api_exception.dart';
import '../../services/attendance_service.dart';
import '../../services/location_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/invoice_format.dart';
import '../../utils/wib.dart';
import '../../widgets/attendance_widgets.dart';
import '../../widgets/error_state.dart';

enum _DayStatus { none, partial, complete }

class AttendancePersonPage extends StatefulWidget {
  const AttendancePersonPage({super.key, required this.person});

  final AttendancePerson person;

  @override
  State<AttendancePersonPage> createState() => _AttendancePersonPageState();
}

class _AttendancePersonPageState extends State<AttendancePersonPage> {
  static const _photoRetentionDays = 28;
  static const _monthRowHeight = 16.0;
  static const _weekdayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _monthShort = [
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

  late DateTime _today;
  late DateTime _start;
  Map<String, List<AttendanceRecord>> _byDate = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = toWib(DateTime.now());
    _today = DateTime(now.year, now.month, now.day);
    // 3 bulan kalender: bulan ini dan 2 bulan sebelumnya.
    _start = DateTime(_today.year, _today.month - 2, 1);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await AttendanceService.instance.fetchUserRange(
        userId: widget.person.id,
        from: _start,
        to: _today,
        branchId: LocationSettings.instance.branchId,
      );
      final byDate = <String, List<AttendanceRecord>>{};
      for (final record in records) {
        byDate.putIfAbsent(record.workDate, () => []).add(record);
      }
      if (!mounted) return;
      setState(() => _byDate = byDate);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat riwayat absensi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------------------ data

  _DayStatus _statusOf(String key) {
    final records = _byDate[key];
    if (records == null || records.isEmpty) return _DayStatus.none;
    final hasIn = records.any((r) => r.type == AttendanceType.masuk);
    final hasOut = records.any((r) => r.type == AttendanceType.pulang);
    return hasIn && hasOut ? _DayStatus.complete : _DayStatus.partial;
  }

  Color _colorOf(_DayStatus status) {
    switch (status) {
      case _DayStatus.complete:
        return Colors.green.shade600;
      case _DayStatus.partial:
        return Colors.orange.shade400;
      case _DayStatus.none:
        return Colors.grey.shade300;
    }
  }

  Color _chipColorOf(_DayStatus status) {
    switch (status) {
      case _DayStatus.complete:
        return Colors.green.shade700;
      case _DayStatus.partial:
        return Colors.orange.shade800;
      case _DayStatus.none:
        return AppColors.textSecondary;
    }
  }

  String _labelOf(_DayStatus status) {
    switch (status) {
      case _DayStatus.complete:
        return 'Lengkap (masuk dan pulang)';
      case _DayStatus.partial:
        return 'Belum lengkap';
      case _DayStatus.none:
        return 'Tidak ada absen';
    }
  }

  static int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  ({int complete, int partial}) _counts() {
    var complete = 0;
    var partial = 0;
    final total = _daysBetween(_start, _today);
    for (var i = 0; i <= total; i++) {
      final day = DateTime(_start.year, _start.month, _start.day + i);
      switch (_statusOf(isoDate(day))) {
        case _DayStatus.complete:
          complete++;
        case _DayStatus.partial:
          partial++;
        case _DayStatus.none:
          break;
      }
    }
    return (complete: complete, partial: partial);
  }

  // ---------------------------------------------------------------- detail

  void _openDay(DateTime day) {
    final records = [...(_byDate[isoDate(day)] ?? const <AttendanceRecord>[])]
      ..sort((a, b) => a.attendedAt.compareTo(b.attendedAt));
    final status = _statusOf(isoDate(day));
    final expired = _today.difference(day).inDays > _photoRetentionDays;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  formatLongDate(day),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AttendanceChip(
                    label: _labelOf(status),
                    color: _chipColorOf(status),
                    icon: status == _DayStatus.complete
                        ? Icons.check_circle_outline
                        : status == _DayStatus.partial
                        ? Icons.timelapse
                        : Icons.event_busy_outlined,
                  ),
                ),
                if (records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Tidak ada catatan absensi pada tanggal ini.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else ...[
                  if (expired)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.orange.shade900,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Foto absensi lebih dari $_photoRetentionDays hari sudah dihapus otomatis. Catatan jam dan lokasi tetap tersimpan.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final record in records)
                    AttendanceRecordTile(record: record),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ grid

  Widget _buildGrid() {
    final gridStart = DateTime(
      _start.year,
      _start.month,
      _start.day - (_start.weekday - 1),
    );
    final weeks = ((_daysBetween(gridStart, _today) + 1) / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        const labelWidth = 30.0;
        const gap = 3.0;
        final slot = ((constraints.maxWidth - labelWidth) / weeks)
            .clamp(14.0, 30.0)
            .toDouble();
        final cell = slot - gap;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: _monthRowHeight),
                  for (var d = 0; d < 7; d++)
                    SizedBox(
                      height: slot,
                      child: (d == 0 || d == 2 || d == 4)
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _weekdayLabels[d],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            for (var w = 0; w < weeks; w++)
              _weekColumn(gridStart, w, slot, cell),
          ],
        );
      },
    );
  }

  Widget _weekColumn(DateTime gridStart, int week, double slot, double cell) {
    final monday = DateTime(
      gridStart.year,
      gridStart.month,
      gridStart.day + week * 7,
    );

    // Label bulan muncul di minggu yang memuat tanggal 1.
    String? monthLabel;
    for (var d = 0; d < 7; d++) {
      final day = DateTime(monday.year, monday.month, monday.day + d);
      if (day.day == 1 && !day.isBefore(_start) && !day.isAfter(_today)) {
        monthLabel = _monthShort[day.month - 1];
        break;
      }
    }

    return SizedBox(
      width: slot,
      child: Column(
        children: [
          SizedBox(
            height: _monthRowHeight,
            child: monthLabel == null
                ? null
                : OverflowBox(
                    maxWidth: 40,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      monthLabel,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
          ),
          for (var d = 0; d < 7; d++)
            _dayCell(
              DateTime(monday.year, monday.month, monday.day + d),
              slot,
              cell,
            ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, double slot, double cell) {
    if (day.isBefore(_start) || day.isAfter(_today)) {
      return SizedBox(width: slot, height: slot);
    }

    final status = _statusOf(isoDate(day));
    final isToday = day == _today;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDay(day),
      child: SizedBox(
        width: slot,
        height: slot,
        child: Center(
          child: Container(
            width: cell,
            height: cell,
            decoration: BoxDecoration(
              color: _colorOf(status),
              borderRadius: BorderRadius.circular(4),
              border: isToday
                  ? Border.all(color: Colors.black87, width: 1.5)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- tampilan

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.person.fullName)),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final counts = _counts();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AttendanceChip(
                icon: Icons.badge_outlined,
                label: attendanceRoleLabel(widget.person.role),
                color: AppColors.brand,
              ),
              AttendanceChip(
                icon: Icons.location_on_outlined,
                label: LocationSettings.instance.label,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.check_circle_outline,
                  color: Colors.green.shade700,
                  value: counts.complete,
                  label: 'Hari lengkap',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.timelapse,
                  color: Colors.orange.shade800,
                  value: counts.partial,
                  label: 'Belum lengkap',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '3 bulan terakhir',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildGrid(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _legendItem(_colorOf(_DayStatus.none), 'Tidak ada absen'),
                    _legendItem(_colorOf(_DayStatus.partial), 'Belum lengkap'),
                    _legendItem(_colorOf(_DayStatus.complete), 'Lengkap'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 16,
                child: Icon(
                  Icons.touch_app_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ketuk kotak tanggal untuk melihat jam, lokasi, jarak dari kantor, dan foto absensi. '
                  'Foto yang lebih dari $_photoRetentionDays hari sudah dihapus otomatis.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        AttendanceIconBox(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
