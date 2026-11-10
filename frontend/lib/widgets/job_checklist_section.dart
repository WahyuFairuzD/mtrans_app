import 'package:flutter/material.dart';
import '../models/work.dart';
import '../services/api_exception.dart';
import '../services/work_service.dart';
import '../theme/app_theme.dart';

/// Daftar checklist hasil kerja satu pekerjaan (hanya baca).
class JobChecklistSection extends StatefulWidget {
  final String jobId;

  const JobChecklistSection({super.key, required this.jobId});

  @override
  State<JobChecklistSection> createState() => _JobChecklistSectionState();
}

class _JobChecklistSectionState extends State<JobChecklistSection> {
  List<ChecklistItem> _items = [];
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
      final items = await WorkService.instance.fetchChecklist(widget.jobId);
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat checklist.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    final doneCount = _items.where((i) => i.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: Text(
            'Checklist ($doneCount/${_items.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        if (_items.isEmpty)
          const Text(
            'Belum ada checklist.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ..._items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.isDone
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: item.isDone ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.isRequired ? item.label : '${item.label} (opsional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
