import 'package:flutter/material.dart';
import '../../models/bus_wash.dart';
import '../../models/work.dart';
import '../../services/api_exception.dart';
import '../../services/job_service.dart';
import '../../services/work_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../widgets/bus_header_card.dart';
import '../../widgets/error_state.dart';

class WorkPage extends StatefulWidget {
  final BusWash bus;

  const WorkPage({super.key, required this.bus});

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  List<ChecklistItem> _items = [];
  String _instructions = '';

  final Set<String> _savingItems = {};

  bool _loading = true;
  String? _loadError;

  bool _finishing = false;

  int get _requiredLeft =>
      _items.where((i) => i.isRequired && !i.isDone).length;

  int get _doneCount => _items.where((i) => i.isDone).length;

  bool get _canFinish =>
      _requiredLeft == 0 && _savingItems.isEmpty && !_finishing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final jobId = widget.bus.id;

      final (items, assignment) = await (
        WorkService.instance.fetchChecklist(jobId),
        JobService.instance.fetchAssignment(jobId),
      ).wait;

      if (!mounted) return;

      setState(() {
        _items = items;
        _instructions = assignment.instructions;
        _loadError = null;
      });
    } on ApiException catch (e) {
      _handleLoadError(e.message, silent);
    } catch (_) {
      _handleLoadError('Gagal memuat data. Coba lagi.', silent);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _handleLoadError(String message, bool silent) {
    if (!mounted) return;
    if (silent) {
      showSnack(context, message);
    } else {
      setState(() => _loadError = message);
    }
  }

  void _replaceItem(ChecklistItem item) {
    _items = _items.map((i) => i.id == item.id ? item : i).toList();
  }

  Future<void> _toggle(ChecklistItem item, bool value) async {
    if (_savingItems.contains(item.id) || _finishing) return;

    setState(() {
      _savingItems.add(item.id);
      _replaceItem(item.copyWith(isDone: value));
    });

    try {
      final updated = await WorkService.instance.setChecklistItem(
        jobId: widget.bus.id,
        itemId: item.id,
        isDone: value,
      );
      if (!mounted) return;
      setState(() => _replaceItem(updated));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _replaceItem(item));
      showSnack(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _replaceItem(item));
      showSnack(context, 'Gagal menyimpan checklist. Coba lagi.');
    } finally {
      if (mounted) setState(() => _savingItems.remove(item.id));
    }
  }

  Future<void> _finish() async {
    if (!_canFinish) return;

    final ok = await confirmDialog(
      context,
      title: 'Selesaikan pekerjaan?',
      message:
          'Setelah ini checklist tidak bisa diubah, dan pekerjaan masuk ke pemeriksaan Pengawas.',
      confirmLabel: 'Selesai Cuci',
    );
    if (!ok || !mounted) return;

    setState(() => _finishing = true);

    try {
      final bus = await WorkService.instance.finishJob(widget.bus.id);
      if (!mounted) return;
      Navigator.pop<BusWash>(context, bus);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.bus.plateNumber;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorState(message: _loadError!, onRetry: _load),
      );
    }

    return PopScope(
      canPop: !_finishing,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: RefreshIndicator(
          onRefresh: () => _load(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              BusHeaderCard(bus: widget.bus),
              if (_instructions.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildInstructions(),
              ],
              const SizedBox(height: 24),
              _buildChecklist(),
              const SizedBox(height: 24),
              _buildFinish(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.brand),
              SizedBox(width: 8),
              Text(
                'Instruksi pekerjaan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_instructions.trim()),
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Checklist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '$_doneCount/${_items.length}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          const Text(
            'Tidak ada checklist untuk pekerjaan ini.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _items
                  .map(
                    (item) => CheckboxListTile(
                      value: item.isDone,
                      onChanged: (_savingItems.contains(item.id) || _finishing)
                          ? null
                          : (v) => _toggle(item, v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(item.label),
                      subtitle: item.isRequired ? null : const Text('Opsional'),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFinish() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _canFinish ? _finish : null,
            icon: _finishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_finishing ? 'Menyimpan...' : 'Selesai Cuci'),
            ),
          ),
        ),
        if (_requiredLeft > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Untuk menyelesaikan: centang $_requiredLeft checklist wajib.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
