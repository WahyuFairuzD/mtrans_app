import 'package:flutter/material.dart';

import '../../models/attendance.dart';
import '../../services/api_exception.dart';
import '../../services/attendance_service.dart';
import '../../services/location_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/invoice_format.dart';
import '../../utils/wib.dart';
import '../../widgets/attendance_widgets.dart';

class OwnerAttendancePage extends StatefulWidget {
  const OwnerAttendancePage({super.key});
  @override
  State<OwnerAttendancePage> createState() => _OwnerAttendancePageState();
}

class _OwnerAttendancePageState extends State<OwnerAttendancePage> {
  /// Foto absensi dihapus otomatis dari penyimpanan setelah 28 hari.
  static const _photoRetentionDays = 28;

  final _service = AttendanceService.instance;
  List<AttendanceRecord> _records = [];
  late DateTime _today;
  late DateTime _date;
  bool _ready = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = toWib(DateTime.now());
    _today = DateTime(now.year, now.month, now.day);
    _date = _today;
    _bootstrap();
  }

  /// Cabang mengikuti Setting > Lokasi (satu cabang atau semua).
  Future<void> _bootstrap() async {
    try {
      await LocationSettings.instance.ensureLoaded();
    } catch (_) {
      // Tanpa daftar lokasi, tampilkan semua cabang.
    }
    if (!mounted) return;
    setState(() => _ready = true);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _service.fetchOwnerDay(
        date: _date,
        branchId: LocationSettings.instance.branchId,
      );
      if (!mounted) return;
      setState(() => _records = records);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat absensi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goTo(DateTime date) {
    if (date.isAfter(_today)) return;
    setState(() => _date = date);
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2025),
      lastDate: _today,
      helpText: 'Pilih tanggal absensi',
    );
    if (picked != null && mounted) {
      _goTo(DateTime(picked.year, picked.month, picked.day));
    }
  }

  bool get _isToday => _date == _today;

  bool get _photosExpired =>
      _today.difference(_date).inDays > _photoRetentionDays;

  Map<String, List<AttendanceRecord>> get _grouped {
    final grouped = <String, List<AttendanceRecord>>{};
    for (final record in _records) {
      grouped.putIfAbsent(record.userId, () => []).add(record);
    }
    return grouped;
  }

  int _countType(AttendanceType type) => _records
      .where((record) => record.type == type)
      .map((record) => record.userId)
      .toSet()
      .length;

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped.entries.toList()
      ..sort(
        (a, b) => a.value.first.fullName.compareTo(b.value.first.fullName),
      );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi'),
        actions: [
          IconButton(
            onPressed: _ready ? _load : null,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDateBar(),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                Expanded(
                  child: _loading && _records.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (_photosExpired) _buildExpiredNote(),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SummaryCard(
                                      label: 'Sudah Masuk',
                                      value: _countType(AttendanceType.masuk),
                                      icon: Icons.login,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SummaryCard(
                                      label: 'Sudah Pulang',
                                      value: _countType(AttendanceType.pulang),
                                      icon: Icons.logout,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (grouped.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 36),
                                  child: Text(
                                    'Belum ada catatan absensi pada tanggal ini.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              else
                                ...grouped.map(
                                  (entry) => _EmployeeAttendanceCard(
                                    records: entry.value,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Hari sebelumnya',
                onPressed: () => _goTo(
                  DateTime(_date.year, _date.month, _date.day - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    _isToday
                        ? 'Hari ini · ${formatLongDate(_date)}'
                        : formatLongDate(_date),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Hari berikutnya',
                onPressed: _isToday
                    ? null
                    : () => _goTo(
                        DateTime(_date.year, _date.month, _date.day + 1),
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  LocationSettings.instance.label,
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

  Widget _buildExpiredNote() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Foto absensi lebih dari $_photoRetentionDays hari sudah dihapus otomatis. Catatan jam dan lokasi tetap tersimpan.',
        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.brand),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
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

class _EmployeeAttendanceCard extends StatelessWidget {
  const _EmployeeAttendanceCard({required this.records});
  final List<AttendanceRecord> records;

  AttendanceRecord? _byType(AttendanceType type) {
    for (final record in records) {
      if (record.type == type) return record;
    }
    return null;
  }

  String _time(AttendanceRecord? record) =>
      record == null ? 'Belum pulang' : wibTime(record.attendedAt);

  @override
  Widget build(BuildContext context) {
    final checkIn = _byType(AttendanceType.masuk);
    final checkOut = _byType(AttendanceType.pulang);
    final first = records.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${first.role == 'pengawas' ? 'Pengawas' : 'Petugas Cuci'} · ${first.branchName}',
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
            const SizedBox(height: 12),
            _OwnerTimeRow(label: 'Masuk', value: _time(checkIn)),
            const SizedBox(height: 6),
            _OwnerTimeRow(label: 'Pulang', value: _time(checkOut)),
            if (checkIn != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PhotoColumn(label: 'Foto Masuk', record: checkIn),
                  ),
                  if (checkOut != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PhotoColumn(
                        label: 'Foto Pulang',
                        record: checkOut,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoColumn extends StatelessWidget {
  const _PhotoColumn({required this.label, required this.record});
  final String label;
  final AttendanceRecord record;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 6),
      AttendancePhotoThumb(record: record, size: 72),
      const SizedBox(height: 4),
      Text(
        '${record.latitude.toStringAsFixed(5)}, ${record.longitude.toStringAsFixed(5)}',
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    ],
  );
}

class _OwnerTimeRow extends StatelessWidget {
  const _OwnerTimeRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 74,
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: value == 'Belum pulang'
              ? Colors.orange.shade800
              : Colors.black87,
        ),
      ),
    ],
  );
}
