import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../services/api_exception.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../utils/wib.dart';

/// Foto absensi dari R2. Diunduh lewat API (butuh token) lalu di-cache di memori.
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

class AttendanceRecordTile extends StatelessWidget {
  const AttendanceRecordTile({super.key, required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final label = record.type == AttendanceType.masuk ? 'Masuk' : 'Pulang';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AttendancePhotoThumb(record: record, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · ${wibTime(record.attendedAt)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  record.branchName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (record.accuracyM != null)
                  Text(
                    'Akurasi ±${record.accuracyM!.round()} m',
                    style: const TextStyle(
                      fontSize: 11,
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
                    Text(
                      '${wibTime(record.attendedAt)} · ${record.branchName}',
                    ),
                    Text(
                      '${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)}',
                    ),
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
