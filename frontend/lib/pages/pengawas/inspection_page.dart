import 'package:flutter/material.dart';
import '../../models/bus_wash.dart';
import '../../models/inspection.dart';
import '../../services/api_exception.dart';
import '../../services/review_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/job_media.dart';

class InspectionPage extends StatefulWidget {
  final BusWash bus;

  const InspectionPage({super.key, required this.bus});

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  final TextEditingController _notes = TextEditingController();

  InspectionResult? _result;
  bool _saving = false;

  bool get _valid => _result != null && !_saving;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null || _saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Simpan hasil pemeriksaan?'),
        content: Text(
          'Hasil: ${result.label}. Status pekerjaan berubah menjadi Selesai dan hasil tidak bisa diubah lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    try {
      final bus = await ReviewService.instance.submitInspection(
        jobId: widget.bus.id,
        result: result,
        notes: _notes.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Periksa Hasil')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeader(),

            JobProofSection(jobId: widget.bus.id),

            const SizedBox(height: 24),
            const Text(
              'Hasil Pemeriksaan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...InspectionResult.values.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ResultOption(
                  option: option,
                  selected: _result == option,
                  onTap: _saving ? null : () => setState(() => _result = option),
                ),
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _notes,
              maxLines: 3,
              maxLength: 500,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Catatan pemeriksaan (opsional)',
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
                      : const Text('Simpan Pemeriksaan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bus = widget.bus;

    final subtitle = [
      bus.brand,
      if (bus.serviceName != null) bus.serviceName!,
    ].join(' • ');

    final lines = <String>[
      if (bus.employees.isNotEmpty)
        'Petugas: ${bus.employees.map((e) => e.name).join(', ')}',
      if (bus.startTime != null || bus.endTime != null)
        'Mulai ${bus.startTime ?? '-'} • Selesai ${bus.endTime ?? '-'}',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_bus, color: Colors.white),
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
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                for (final line in lines) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultOption extends StatelessWidget {
  final InspectionResult option;
  final bool selected;
  final VoidCallback? onTap;

  const _ResultOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? option.color.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? option.color : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(option.icon, color: option.color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check, color: option.color),
            ],
          ),
        ),
      ),
    );
  }
}