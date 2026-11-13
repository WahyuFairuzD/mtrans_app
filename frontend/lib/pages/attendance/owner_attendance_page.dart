import 'package:flutter/material.dart';

import '../../models/attendance.dart';
import '../../services/api_exception.dart';
import '../../services/attendance_service.dart';
import '../../services/location_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/invoice_format.dart';
import '../../utils/wib.dart';
import '../../widgets/attendance_widgets.dart';
import 'attendance_person_page.dart';

typedef _Entry = ({AttendancePerson person, List<AttendanceRecord> records});

class _PersonPick {
  const _PersonPick(this.person);
  final AttendancePerson? person;
}

class OwnerAttendancePage extends StatefulWidget {
  const OwnerAttendancePage({super.key});
  @override
  State<OwnerAttendancePage> createState() => _OwnerAttendancePageState();
}

class _OwnerAttendancePageState extends State<OwnerAttendancePage> {
  static const _photoRetentionDays = 28;

  final _service = AttendanceService.instance;
  List<AttendanceRecord> _records = [];
  List<AttendancePerson> _people = [];
  AttendancePerson? _person;
  late DateTime _today;
  late DateTime _date;
  bool _ready = false;
  bool _loading = true;
  bool _peopleLoading = false;
  String? _error;
  String? _peopleError;

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
    await Future.wait([_load(), _loadPeople()]);
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

  Future<void> _loadPeople() async {
    setState(() {
      _peopleLoading = true;
      _peopleError = null;
    });
    try {
      final people = await _service.fetchPeople(
        branchId: LocationSettings.instance.branchId,
      );
      if (!mounted) return;
      setState(() => _people = people);
    } on ApiException catch (error) {
      if (mounted) setState(() => _peopleError = error.message);
    } catch (_) {
      if (mounted) setState(() => _peopleError = 'Gagal memuat daftar pegawai.');
    } finally {
      if (mounted) setState(() => _peopleLoading = false);
    }
  }

  Future<void> _refreshAll() => Future.wait([_load(), _loadPeople()]);

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

  Future<void> _pickPerson() async {
    final result = await showModalBottomSheet<_PersonPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _PersonPickerSheet(people: _people, selectedId: _person?.id),
    );
    if (result == null || !mounted) return;
    setState(() => _person = result.person);
  }

  void _openPerson(AttendancePerson person) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => AttendancePersonPage(person: person)),
    );
  }

  bool get _isToday => _date == _today;

  bool get _photosExpired =>
      _today.difference(_date).inDays > _photoRetentionDays;

  List<_Entry> get _entries {
    final selected = _person;
    if (selected != null) {
      return [
        (
          person: selected,
          records: _records.where((r) => r.userId == selected.id).toList(),
        ),
      ];
    }

    final grouped = <String, List<AttendanceRecord>>{};
    for (final record in _records) {
      grouped.putIfAbsent(record.userId, () => []).add(record);
    }
    final entries = grouped.values.map<_Entry>((records) {
      final first = records.first;
      return (
        person: AttendancePerson(
          id: first.userId,
          fullName: first.fullName,
          role: first.role,
        ),
        records: records,
      );
    }).toList();
    entries.sort((a, b) => a.person.fullName.compareTo(b.person.fullName));
    return entries;
  }

  int _countType(AttendanceType type) => _records
      .where((record) => record.type == type)
      .map((record) => record.userId)
      .toSet()
      .length;

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi'),
        actions: [
          IconButton(
            onPressed: _ready ? _refreshAll : null,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      _buildDateBar(),
                      const SizedBox(height: 10),
                      _buildPersonBar(),
                    ],
                  ),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                Expanded(
                  child: _loading && _records.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _refreshAll,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              if (_photosExpired) _buildExpiredNote(),
                              if (_person == null) ...[
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
                                const SizedBox(height: 16),
                              ],
                              if (entries.isEmpty)
                                const _EmptyState()
                              else
                                ...entries.map(
                                  (entry) => _EmployeeAttendanceCard(
                                    person: entry.person,
                                    records: entry.records,
                                    onTap: () => _openPerson(entry.person),
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
    return Column(
      children: [
        Row(
          children: [
            AttendanceNavButton(
              icon: Icons.chevron_left,
              tooltip: 'Hari sebelumnya',
              onPressed: () =>
                  _goTo(DateTime(_date.year, _date.month, _date.day - 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AttendanceFilterPill(
                icon: Icons.calendar_month_outlined,
                caption: _isToday ? 'Hari ini' : null,
                label: formatLongDate(_date),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: 10),
            AttendanceNavButton(
              icon: Icons.chevron_right,
              tooltip: 'Hari berikutnya',
              onPressed: _isToday
                  ? null
                  : () =>
                        _goTo(DateTime(_date.year, _date.month, _date.day + 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
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
      ],
    );
  }

  Widget _buildPersonBar() {
    final person = _person;

    String label;
    VoidCallback? onTap = _pickPerson;
    if (_peopleLoading) {
      label = 'Memuat daftar pegawai...';
      onTap = null;
    } else if (_peopleError != null) {
      label = 'Gagal memuat. Ketuk untuk coba lagi';
      onTap = _loadPeople;
    } else {
      label = person?.fullName ?? 'Semua pegawai';
    }

    return AttendanceFilterPill(
      icon: Icons.person_search_outlined,
      label: label,
      active: person != null,
      onTap: onTap,
      onClear: person != null ? () => setState(() => _person = null) : null,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Foto absensi lebih dari $_photoRetentionDays hari sudah dihapus otomatis. Catatan jam dan lokasi tetap tersimpan.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 48),
    child: Column(
      children: [
        Icon(Icons.event_busy_outlined, size: 40, color: Colors.grey),
        SizedBox(height: 12),
        Text(
          'Belum ada catatan absensi pada tanggal ini.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _PersonPickerSheet extends StatefulWidget {
  const _PersonPickerSheet({required this.people, required this.selectedId});

  final List<AttendancePerson> people;
  final String? selectedId;

  @override
  State<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends State<_PersonPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final people = query.isEmpty
        ? widget.people
        : widget.people
              .where((p) => p.fullName.toLowerCase().contains(query))
              .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pilih pegawai',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: filledInputDecoration('Cari nama').copyWith(
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    if (query.isEmpty)
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.groups_outlined),
                        ),
                        title: const Text('Semua pegawai'),
                        trailing: widget.selectedId == null
                            ? const Icon(Icons.check, color: AppColors.brand)
                            : null,
                        onTap: () =>
                            Navigator.pop(context, const _PersonPick(null)),
                      ),
                    for (final person in people)
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(person.fullName),
                        subtitle: Text(attendanceRoleLabel(person.role)),
                        trailing: widget.selectedId == person.id
                            ? const Icon(Icons.check, color: AppColors.brand)
                            : null,
                        onTap: () =>
                            Navigator.pop(context, _PersonPick(person)),
                      ),
                    if (people.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Tidak ada pegawai yang cocok.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        AttendanceIconBox(icon: icon),
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

class _EmployeeAttendanceCard extends StatelessWidget {
  const _EmployeeAttendanceCard({
    required this.person,
    required this.records,
    required this.onTap,
  });
  final AttendancePerson person;
  final List<AttendanceRecord> records;
  final VoidCallback onTap;

  AttendanceRecord? _byType(AttendanceType type) {
    for (final record in records) {
      if (record.type == type) return record;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final checkIn = _byType(AttendanceType.masuk);
    final checkOut = _byType(AttendanceType.pulang);
    final role = attendanceRoleLabel(person.role);
    final subtitle = records.isEmpty ? role : '$role · ${records.first.branchName}';
    final initial = person.fullName.trim().isEmpty
        ? '?'
        : person.fullName.trim()[0].toUpperCase();

    final (statusLabel, statusColor) = checkIn == null
        ? ('Belum masuk', Colors.orange.shade800)
        : checkOut == null
        ? ('Belum pulang', Colors.blue.shade700)
        : ('Lengkap', Colors.green.shade700);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
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
                    const SizedBox(width: 8),
                    AttendanceChip(label: statusLabel, color: statusColor),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TimeBlock(
                        type: AttendanceType.masuk,
                        record: checkIn,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TimeBlock(
                        type: AttendanceType.pulang,
                        record: checkOut,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.type, required this.record});
  final AttendanceType type;
  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final isIn = type == AttendanceType.masuk;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                child: Icon(
                  isIn ? Icons.login : Icons.logout,
                  size: 14,
                  color: r != null
                      ? Colors.green.shade700
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isIn ? 'Masuk' : 'Pulang',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (r != null)
            Text(
              wibTime(r.attendedAt),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            )
          else
            Text(
              isIn ? 'Belum masuk' : 'Belum pulang',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
          if (r != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                AttendancePhotoThumb(record: r, size: 48),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AttendanceDistanceChip(
                      distanceM: r.distanceM,
                      compact: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
