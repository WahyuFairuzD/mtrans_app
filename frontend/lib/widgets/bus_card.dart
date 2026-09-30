import 'package:flutter/material.dart';
import '../models/bus_wash.dart';
import '../theme/app_theme.dart';

bool _hasPhotos(BusWash bus) =>
    bus.status.index >= WashStatus.menungguPemeriksaan.index;


// KARTU BUS

class BusCard extends StatelessWidget {
  final BusWash bus;
  final bool showDate;

  /// Opsional: tombol aksi di bawah kartu (dipakai Pengawas).
  final String? actionLabel;
  final VoidCallback? onAction;

  const BusCard({
    super.key,
    required this.bus,
    this.showDate = false,
    this.actionLabel,
    this.onAction,
  });

  String get _subtitle {
    final base = bus.brand;
    return showDate ? '${bus.date} • $base' : base;
  }

  @override
  Widget build(BuildContext context) {
    final photos = _hasPhotos(bus);
    final hint = photos
        ? 'Lihat foto & checklist'
        : (bus.employees.isNotEmpty
            ? bus.employees.map((e) => e.name).join(', ')
            : null);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showBusDetail(context, bus),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          _subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatusChip(status: bus.status),
                        if (hint != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                photos
                                    ? Icons.photo_outlined
                                    : Icons.person_outline,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  hint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final WashStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: status.color,
        ),
      ),
    );
  }
}


// BAGIAN YANG DIPAKAI ULANG (detail + pemeriksaan)

class ChecklistList extends StatelessWidget {
  final List<String> items;

  const ChecklistList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'Belum ada checklist.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    return Column(
      children: items
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(e),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class WashPhoto extends StatelessWidget {
  final BusWash bus;

  const WashPhoto({super.key, required this.bus});

  Widget _uploaded() => Container(
        color: const Color(0xFFE6F4E7),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(height: 4),
              Text(
                'Terunggah',
                style: TextStyle(fontSize: 11, color: Colors.green),
              ),
            ],
          ),
        ),
      );

  Widget _placeholder() => Container(
        color: AppColors.background,
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final url = bus.photo;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url == null
            ? _placeholder()
            : (url.startsWith('http')
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _uploaded()),
      ),
    );
  }
}


// DETAIL (bottom sheet)

void showBusDetail(BuildContext context, BusWash bus) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DetailSheet(bus: bus),
  );
}

class _DetailSheet extends StatelessWidget {
  final BusWash bus;

  const _DetailSheet({required this.bus});

  @override
  Widget build(BuildContext context) {
    final note = bus.initialNote;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    bus.plateNumber,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(status: bus.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${bus.brand} • ${bus.date}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (bus.entryTime != null)
              _InfoRow(Icons.login, 'Masuk', bus.entryTime!),
            if (bus.startTime != null)
              _InfoRow(Icons.play_arrow_outlined, 'Mulai', bus.startTime!),
            if (bus.endTime != null)
              _InfoRow(Icons.check, 'Selesai cuci', bus.endTime!),
            if (bus.inspectionTime != null)
              _InfoRow(
                Icons.fact_check_outlined,
                'Diperiksa',
                bus.inspectionTime!,
              ),
            if (bus.exitTime != null)
              _InfoRow(Icons.logout, 'Keluar', bus.exitTime!),
            if (note != null && note.isNotEmpty) ...[
              const _SectionTitle('Catatan kondisi awal'),
              Text(note),
            ],
            if (bus.employees.isNotEmpty) ...[
              const _SectionTitle('Petugas'),
              ...bus.employees.map((e) => _EmployeeTile(employee: e)),
            ],
            if (bus.checklist.isNotEmpty) ...[
              const _SectionTitle('Checklist'),
              ChecklistList(items: bus.checklist),
            ],
            if (_hasPhotos(bus)) ...[
              const _SectionTitle('Foto sesudah cuci'),
              WashPhoto(bus: bus),
            ],
            if (bus.inspectionNote != null) ...[
              const _SectionTitle('Hasil pemeriksaan'),
              Text(bus.inspectionNote!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final Employee employee;

  const _EmployeeTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.background,
            child: Text(
              employee.name[0],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                employee.role,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}