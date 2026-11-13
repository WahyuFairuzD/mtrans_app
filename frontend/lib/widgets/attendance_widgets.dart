import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../services/api_exception.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../utils/wib.dart';

// ------------------------------------------------------------------ foto

class AttendancePhotoImage extends StatelessWidget {
  const AttendancePhotoImage({
    super.key,
    required this.attendanceId,
    this.fit = BoxFit.cover,
  });

  final String attendanceId;
  final BoxFit fit;

  Widget _expired() => Container(
    color: AppColors.background,
    padding: const EdgeInsets.all(4),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hide_image_outlined, size: 18, color: Colors.grey),
          SizedBox(height: 2),
          Text(
            'Dihapus',
            style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );

  Widget _placeholder({bool loading = false}) => Container(
    color: AppColors.background,
    child: Center(
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.broken_image_outlined, color: Colors.grey),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: AttendanceService.instance.photoBytes(attendanceId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Foto di R2 dihapus otomatis setelah 28 hari.
          final error = snapshot.error;
          if (error is ApiException && error.code == 'PHOTO_EXPIRED') {
            return _expired();
          }
          return _placeholder();
        }

        final bytes = snapshot.data;
        if (bytes == null) return _placeholder(loading: true);
        if (bytes.isEmpty) return _placeholder();

        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _placeholder(),
        );
      },
    );
  }
}

class AttendancePhotoThumb extends StatelessWidget {
  const AttendancePhotoThumb({super.key, required this.record, this.size = 58});
  final AttendanceRecord record;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AttendancePhotoViewer(record: record)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: AttendancePhotoImage(attendanceId: record.id),
      ),
    ),
  );
}

// ------------------------------------------------------- komponen dasar UI

/// Ikon di dalam kotak berwarna dengan ukuran tetap, supaya ikon selalu
/// berada di tengah segmennya.
class AttendanceIconBox extends StatelessWidget {
  const AttendanceIconBox({
    super.key,
    required this.icon,
    this.color = AppColors.brand,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, size: size * 0.5, color: color),
  );
}

/// Baris kecil: ikon di kotak lebar tetap + teks satu baris.
class AttendanceInfoRow extends StatelessWidget {
  const AttendanceInfoRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 16,
        child: Icon(icon, size: 14, color: AppColors.textSecondary),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    ],
  );
}

class AttendanceChip extends StatelessWidget {
  const AttendanceChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Badge jarak absen ke kantor. Hijau bila dalam batas, oranye bila di luar
/// batas (hanya mungkin untuk data lama sebelum validasi jarak diterapkan).
class AttendanceDistanceChip extends StatelessWidget {
  const AttendanceDistanceChip({
    super.key,
    required this.distanceM,
    this.compact = false,
  });

  final double? distanceM;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final distance = distanceM;
    if (distance == null) return const SizedBox.shrink();
    final within = distance <= kAttendanceMaxDistanceM;
    final text = formatDistance(distance);
    return AttendanceChip(
      icon: within ? Icons.check_circle_outline : Icons.warning_amber_rounded,
      label: compact ? text : '$text dari kantor',
      color: within ? Colors.green.shade700 : Colors.orange.shade800,
    );
  }
}

class AttendanceAccuracyChip extends StatelessWidget {
  const AttendanceAccuracyChip({super.key, required this.accuracyM});
  final double? accuracyM;

  @override
  Widget build(BuildContext context) {
    final accuracy = accuracyM;
    if (accuracy == null) return const SizedBox.shrink();
    return AttendanceChip(
      icon: Icons.gps_fixed,
      label: 'Akurasi ±${accuracy.round()} m',
      color: AppColors.textSecondary,
    );
  }
}

/// Tombol bundar bergaris untuk navigasi (hari sebelumnya/berikutnya).
class AttendanceNavButton extends StatelessWidget {
  const AttendanceNavButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      disabledBackgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      fixedSize: const Size(44, 44),
      padding: EdgeInsets.zero,
    ),
  );
}

/// Pil pemilih (tanggal / nama pegawai). Semua ikon, termasuk tombol hapus,
/// berada di dalam pil dengan padding yang konsisten.
class AttendanceFilterPill extends StatelessWidget {
  const AttendanceFilterPill({
    super.key,
    required this.icon,
    required this.label,
    this.caption,
    this.onTap,
    this.onClear,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final accent = active ? AppColors.brand : AppColors.textSecondary;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: StadiumBorder(
        side: BorderSide(color: active ? AppColors.brand : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (caption != null)
                        Text(
                          caption!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    onPressed: onClear,
                    tooltip: 'Tampilkan semua pegawai',
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                  )
                else if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- dialog jarak

Future<void> showAttendanceOutOfRangeDialog(
  BuildContext context, {
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    icon: const Icon(Icons.location_off_outlined, size: 32, color: AppColors.brand),
    title: const Text('Di luar jangkauan kantor'),
    content: Text(message),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(dialogContext),
        style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
        child: const Text('Mengerti'),
      ),
    ],
  ),
);

// ------------------------------------------------------------ kartu record

class AttendanceRecordTile extends StatelessWidget {
  const AttendanceRecordTile({super.key, required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final isIn = record.type == AttendanceType.masuk;
    final label = isIn ? 'Masuk' : 'Pulang';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AttendancePhotoThumb(record: record, size: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isIn ? Icons.login : Icons.logout,
                      size: 16,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$label · ${wibTime(record.attendedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (record.branchName.isNotEmpty) ...[
                  AttendanceInfoRow(
                    icon: Icons.business_outlined,
                    text: record.branchName,
                  ),
                  const SizedBox(height: 3),
                ],
                AttendanceInfoRow(
                  icon: Icons.location_on_outlined,
                  text:
                      '${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)}',
                ),
                if (record.distanceM != null || record.accuracyM != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AttendanceDistanceChip(distanceM: record.distanceM),
                      AttendanceAccuracyChip(accuracyM: record.accuracyM),
                    ],
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

class AttendancePhotoViewer extends StatelessWidget {
  const AttendancePhotoViewer({super.key, required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(record.type.label),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  // Ukuran tetap supaya placeholder (muat/gagal/dihapus) tidak
                  // meminta ruang tak terbatas di dalam InteractiveViewer.
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: AttendancePhotoImage(
                      attendanceId: record.id,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${wibTime(record.attendedAt)} · ${record.branchName}',
                    ),
                    Text(
                      '${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)}',
                    ),
                    if (record.distanceM != null || record.accuracyM != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          AttendanceDistanceChip(distanceM: record.distanceM),
                          AttendanceAccuracyChip(accuracyM: record.accuracyM),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
