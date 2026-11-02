import 'package:flutter/material.dart';

import '../../models/attendance.dart';
import '../../models/branch.dart';
import '../../services/api_exception.dart';
import '../../services/attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/attendance_widgets.dart';
import '../../widgets/branch_filter_chips.dart';

class OwnerAttendancePage extends StatefulWidget {
  const OwnerAttendancePage({super.key});
  @override
  State<OwnerAttendancePage> createState() => _OwnerAttendancePageState();
}

class _OwnerAttendancePageState extends State<OwnerAttendancePage> {
  final _service = AttendanceService.instance;
  List<Branch> _branches = [];
  List<AttendanceRecord> _records = [];
  int? _selectedBranch;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchBranches(),
        _service.fetchOwnerToday(branchId: _selectedBranch),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = results[0] as List<Branch>;
        _records = results[1] as List<AttendanceRecord>;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat absensi hari ini.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectBranch(int? id) {
    setState(() => _selectedBranch = id);
    _load();
  }

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
        title: const Text('Absensi Hari Ini'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: Column(
        children: [
          BranchFilterChips(
            branches: _branches,
            selectedId: _selectedBranch,
            onSelected: _selectBranch,
          ),
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
                              'Belum ada catatan absensi hari ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ...grouped.map(
                            (entry) =>
                                _EmployeeAttendanceCard(records: entry.value),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
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

  String _time(AttendanceRecord? record) {
    if (record == null) return 'Belum pulang';
    final time = record.wibTime;
    return '${_two(time.hour)}:${_two(time.minute)}';
  }

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

String _two(int value) => value.toString().padLeft(2, '0');
