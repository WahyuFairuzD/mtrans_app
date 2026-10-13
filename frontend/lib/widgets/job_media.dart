import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/work.dart';
import '../services/api_exception.dart';
import '../services/work_service.dart';
import '../theme/app_theme.dart';

class JobProofSection extends StatefulWidget {
  final String jobId;

  const JobProofSection({super.key, required this.jobId});

  @override
  State<JobProofSection> createState() => _JobProofSectionState();
}

class _JobProofSectionState extends State<JobProofSection> {
  List<ChecklistItem> _items = [];
  List<JobPhoto> _photos = [];
  final Map<String, Future<Uint8List>> _futures = {};

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
      final results = await Future.wait<Object>([
        WorkService.instance.fetchChecklist(widget.jobId),
        WorkService.instance.fetchPhotos(widget.jobId),
      ]);

      if (!mounted) return;

      setState(() {
        _items = results[0] as List<ChecklistItem>;
        _photos = results[1] as List<JobPhoto>;
        _futures.clear();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gagal memuat checklist dan foto.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _photoFuture(String photoId) {
    return _futures.putIfAbsent(
      photoId,
      () => WorkService.instance.fetchPhotoBytes(widget.jobId, photoId),
    );
  }

  void _openViewer(JobPhoto photo) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerPage(future: _photoFuture(photo.id)),
      ),
    );
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
            TextButton(
              onPressed: _load,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final doneCount = _items.where((i) => i.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title('Checklist (${_items.isEmpty ? 0 : doneCount}/${_items.length})'),
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
        _Title('Foto sesudah cuci (${_photos.length})'),
        if (_photos.isEmpty)
          const Text(
            'Belum ada foto.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: _photos.map(_tile).toList(),
          ),
      ],
    );
  }

  Widget _tile(JobPhoto photo) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FutureBuilder<Uint8List>(
        future: _photoFuture(photo.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return InkWell(
              onTap: () => setState(() => _futures.remove(photo.id)),
              child: Container(
                color: AppColors.background,
                child: const Center(
                  child: Icon(Icons.refresh, color: Colors.grey),
                ),
              ),
            );
          }

          final bytes = snapshot.data;

          if (bytes == null) {
            return Container(
              color: AppColors.background,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          if (bytes.isEmpty) {
            return Container(
              color: AppColors.background,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            );
          }

          return InkWell(
            onTap: () => _openViewer(photo),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              cacheWidth: 400,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.background,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

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

class PhotoViewerPage extends StatelessWidget {
  final Future<Uint8List> future;

  const PhotoViewerPage({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<Uint8List>(
        future: future,
        builder: (context, snapshot) {
          final bytes = snapshot.data;

          if (snapshot.hasError || (bytes != null && bytes.isEmpty)) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            );
          }
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(child: Image.memory(bytes)),
          );
        },
      ),
    );
  }
}