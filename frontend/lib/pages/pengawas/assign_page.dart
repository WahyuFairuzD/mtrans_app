import 'package:flutter/material.dart';
import '../../models/assignment.dart';
import '../../models/bus_wash.dart';
import '../../services/api_exception.dart';
import '../../services/job_service.dart';
import '../../services/pegawai_service.dart';
import '../../theme/app_theme.dart';

class AssignPage extends StatefulWidget {
  final BusWash bus;

  const AssignPage({super.key, required this.bus});

  @override
  State<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<AssignPage> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _instructions = TextEditingController();

  List<PegawaiItem> _pegawai = [];
  final Set<String> _selected = {};

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _isReassign => widget.bus.status == WashStatus.menungguDikerjakan;

  bool get _valid => _selected.isNotEmpty && !_saving;

  List<PegawaiItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _pegawai;
    return _pegawai
        .where((p) => p.fullName.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final Future<JobAssignment?> assignmentFuture = _isReassign
          ? JobService.instance.fetchAssignment(widget.bus.id)
          : Future<JobAssignment?>.value(null);

      final (list, assignment) = await (
        PegawaiService.instance.fetchPegawai(),
        assignmentFuture,
      ).wait;

      if (!mounted) return;

      final validIds = list.map((p) => p.id).toSet();

      setState(() {
        _pegawai = list;
        if (assignment != null) {
          _selected
            ..clear()
            ..addAll(assignment.pegawaiIds.where(validIds.contains));
          _instructions.text = assignment.instructions;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Gagal memuat data. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String id, bool checked) {
    setState(() {
      if (checked) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (!_valid) return;

    setState(() => _saving = true);

    try {
      final bus = await JobService.instance.assignJob(
        jobId: widget.bus.id,
        pegawaiIds: _selected.toList(),
        instructions: _instructions.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop<BusWash>(context, bus);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isReassign ? 'Ganti Petugas' : 'Tugaskan Petugas';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bus = widget.bus;
    final shown = _filtered;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.plateNumber,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          bus.brand,
                          if (bus.serviceName != null) bus.serviceName!,
                        ].join(' • '),
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
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pilih Petugas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${_selected.length} dipilih',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: _decoration('Cari nama petugas').copyWith(
              prefixIcon: const Icon(Icons.search),
            ),
          ),

          const SizedBox(height: 8),

          if (_pegawai.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada akun Petugas yang aktif.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Petugas tidak ditemukan.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: shown
                    .map(
                      (p) => CheckboxListTile(
                        value: _selected.contains(p.id),
                        onChanged: _saving
                            ? null
                            : (v) => _toggle(p.id, v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          p.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          const SizedBox(height: 20),

          TextField(
            controller: _instructions,
            maxLines: 3,
            maxLength: 255,
            decoration: _decoration('Instruksi pekerjaan (opsional)')
                .copyWith(alignLabelWithHint: true),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valid ? _save : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isReassign ? 'Simpan Perubahan' : 'Simpan Penugasan',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}