import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../models/branch.dart';
import '../../services/api_exception.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/device_location.dart';
import '../../theme/app_theme.dart';
import '../../widgets/attendance_widgets.dart';
import '../../widgets/branch_badge.dart';
import '../../widgets/branch_selection_sheet.dart';
import 'capture_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _service = AttendanceService.instance;
  List<AttendanceRecord> _records = [];
  List<Branch> _branches = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  AppUser? get _user => AuthService.instance.user;
  int? get _branchId => _user?.role == UserRole.pengawas
      ? _user?.branchId
      : AuthService.instance.attendanceBranchId;
  Branch? get _branch {
    final id = _branchId;
    for (final branch in _branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }

  AttendanceRecord? _find(AttendanceType type) {
    for (final record in _records) {
      if (record.type == type) return record;
    }
    return null;
  }

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
        _service.fetchMyToday(),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = results[0] as List<Branch>;
        _records = results[1] as List<AttendanceRecord>;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat absensi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectBranch() async {
    try {
      final id = await selectAttendanceBranch(context);
      if (id == null || !mounted) return;
      await AuthService.instance.setAttendanceBranchId(id);
      await _load();
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _submit(AttendanceType type) async {
    if (_busy) return;
    final branchId = _branchId;
    if (branchId == null) {
      if (_user?.role == UserRole.pegawai) {
        await _selectBranch();
      } else {
        _showMessage(
          'Cabang akun Pengawas belum ditetapkan. Hubungi administrator.',
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final position = await DeviceLocation.instance.currentPosition();
      if (!mounted) return;
      final photo = await Navigator.of(
        context,
      ).push<Uint8List>(MaterialPageRoute(builder: (_) => const CapturePage()));
      if (photo == null || !mounted) return;
      final record = await _service.submit(
        type: type,
        branchId: branchId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        photo: photo,
      );
      if (!mounted) return;
      setState(() {
        _records = [..._records, record]
          ..sort((a, b) => a.attendedAt.compareTo(b.attendedAt));
      });
      _showMessage('Absen ${type.apiValue} berhasil dicatat.');
    } on DeviceLocationException catch (error) {
      if (mounted) _showMessage(error.message);
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
        if (error.statusCode == 409) _load();
      }
    } catch (_) {
      if (mounted) _showMessage('Absensi gagal disimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final branch = _branch;
    final checkIn = _find(AttendanceType.masuk);
    final checkOut = _find(AttendanceType.pulang);
    return Scaffold(
      appBar: AppBar(title: const Text('Absensi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    _ErrorBox(message: _error!, onRetry: _load),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _user?.fullName ?? 'Pengguna',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (branch != null) BranchBadge(name: branch.name),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_user?.role == UserRole.pegawai && branch == null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Pilih cabang absensi'),
                        subtitle: const Text(
                          'Cabang dibutuhkan untuk mencatat kehadiran.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _selectBranch,
                      ),
                    )
                  else if (_user?.role == UserRole.pengawas && branch == null)
                    const _ErrorBox(
                      message:
                          'Cabang akun Pengawas belum ditetapkan. Hubungi administrator.',
                    ),
                  _AttendanceStatusCard(
                    type: AttendanceType.masuk,
                    record: checkIn,
                    enabled: checkIn == null && branch != null && !_busy,
                    busy: _busy && checkIn == null,
                    onTap: () => _submit(AttendanceType.masuk),
                  ),
                  const SizedBox(height: 12),
                  _AttendanceStatusCard(
                    type: AttendanceType.pulang,
                    record: checkOut,
                    enabled:
                        checkIn != null &&
                        checkOut == null &&
                        branch != null &&
                        !_busy,
                    busy: _busy && checkIn != null && checkOut == null,
                    onTap: () => _submit(AttendanceType.pulang),
                    waitingForCheckIn: checkIn == null,
                  ),
                  if (checkIn != null && checkOut == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Kamu sudah absen masuk dan belum absen pulang.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Catatan Hari Ini',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (_records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Text(
                        'Belum ada absensi hari ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ..._records.map(
                      (record) => AttendanceRecordTile(record: record),
                    ),
                ],
              ),
            ),
    );
  }
}

class _AttendanceStatusCard extends StatelessWidget {
  const _AttendanceStatusCard({
    required this.type,
    required this.record,
    required this.enabled,
    required this.busy,
    required this.onTap,
    this.waitingForCheckIn = false,
  });
  final AttendanceType type;
  final AttendanceRecord? record;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;
  final bool waitingForCheckIn;

  @override
  Widget build(BuildContext context) {
    final time = record?.wibTime;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == AttendanceType.masuk ? Icons.login : Icons.logout,
                  color: record != null ? Colors.green : AppColors.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (time != null)
                  Text(
                    '${_two(time.hour)}:${_two(time.minute)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
            if (record != null)
              AttendanceRecordTile(record: record!)
            else ...[
              const SizedBox(height: 8),
              Text(
                waitingForCheckIn ? 'Absen masuk dulu.' : 'Belum absen.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: enabled ? onTap : null,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(busy ? 'Memproses...' : type.label),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD9191F),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.red.shade50,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: Colors.red.shade800)),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
        ],
      ),
    ),
  );
}

String _two(int value) => value.toString().padLeft(2, '0');
