import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/bus_wash.dart';
import '../../models/work.dart';
import '../../services/api_exception.dart';
import '../../services/job_service.dart';
import '../../services/work_service.dart';
import '../../theme/app_theme.dart';

const double _maxSide = 1920;
const int _quality = 85;
const int _maxPhotoBytes = 10 * 1024 * 1024;

class WorkPage extends StatefulWidget {
  final BusWash bus;

  const WorkPage({super.key, required this.bus});

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  final ImagePicker _picker = ImagePicker();

  List<ChecklistItem> _items = [];
  List<JobPhoto> _photos = [];
  String _instructions = '';

  final Map<String, Future<Uint8List>> _photoFutures = {};
  final Set<String> _savingItems = {};
  final Set<String> _deletingPhotos = {};

  bool _loading = true;
  String? _loadError;

  bool _uploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;

  bool _finishing = false;

  int get _requiredLeft =>
      _items.where((i) => i.isRequired && !i.isDone).length;

  int get _doneCount => _items.where((i) => i.isDone).length;

  bool get _busy => _uploading || _finishing;

  bool get _canFinish =>
      _requiredLeft == 0 &&
      _photos.isNotEmpty &&
      _savingItems.isEmpty &&
      _deletingPhotos.isEmpty &&
      !_busy;

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

      final results = await Future.wait<Object?>([
        WorkService.instance.fetchChecklist(jobId),
        WorkService.instance.fetchPhotos(jobId),
        JobService.instance.fetchAssignment(jobId),
      ]);

      if (!mounted) return;

      final items = results[0] as List<ChecklistItem>;
      final photos = results[1] as List<JobPhoto>;
      final assignment = results[2] as dynamic;

      setState(() {
        _items = items;
        _photos = photos;
        _instructions = (assignment.instructions as String?) ?? '';
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (silent) {
        _showError(e.message);
      } else {
        setState(() => _loadError = e.message);
      }
    } catch (_) {
      if (!mounted) return;
      const message = 'Gagal memuat data. Coba lagi.';
      if (silent) {
        _showError(message);
      } else {
        setState(() => _loadError = message);
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _replaceItem(ChecklistItem item) {
    _items = _items.map((i) => i.id == item.id ? item : i).toList();
  }

  Future<void> _toggle(ChecklistItem item, bool value) async {
    if (_savingItems.contains(item.id) || _busy) return;

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
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _replaceItem(item));
      _showError('Gagal menyimpan checklist. Coba lagi.');
    } finally {
      if (mounted) setState(() => _savingItems.remove(item.id));
    }
  }

  Future<Uint8List> _photoFuture(String photoId) {
    return _photoFutures.putIfAbsent(
      photoId,
      () => WorkService.instance.fetchPhotoBytes(widget.bus.id, photoId),
    );
  }

  Future<void> _pickFromCamera() async {
    if (_busy) return;

    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (file == null) return;
      await _uploadAll([file]);
    } catch (_) {
      if (mounted) _showError('Tidak bisa membuka kamera. Periksa izin kamera.');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;

    try {
      final files = await _picker.pickMultiImage(
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (files.isEmpty) return;
      await _uploadAll(files);
    } catch (_) {
      if (mounted) _showError('Tidak bisa membuka galeri. Periksa izin penyimpanan.');
    }
  }

  Future<void> _uploadAll(List<XFile> files) async {
    if (!mounted) return;

    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadTotal = files.length;
    });

    var failed = 0;
    String? firstError;

    for (final file in files) {
      if (!mounted) return;

      try {
        final size = await file.length();
        if (size > _maxPhotoBytes) {
          failed++;
          firstError ??= 'Ukuran foto maksimal 10 MB.';
          continue;
        }

        final photo = await WorkService.instance.uploadPhoto(
          jobId: widget.bus.id,
          path: file.path,
        );
        final bytes = await file.readAsBytes();

        if (!mounted) return;
        setState(() {
          _photos = [..._photos, photo];
          _photoFutures[photo.id] = Future.value(bytes);
        });
      } on ApiException catch (e) {
        failed++;
        firstError ??= e.message;
        if (e.statusCode == 409) break;
      } catch (_) {
        failed++;
        firstError ??= 'Gagal mengunggah foto.';
      } finally {
        if (mounted) setState(() => _uploadDone++);
      }
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    if (failed > 0) {
      final reason = firstError ?? 'Gagal mengunggah foto.';
      _showError(files.length == 1 ? reason : '$failed foto gagal diunggah. $reason');
    }
  }

  Future<void> _deletePhoto(JobPhoto photo) async {
    if (_busy || _deletingPhotos.contains(photo.id)) return;

    final ok = await _confirm(
      title: 'Hapus foto ini?',
      message: 'Foto akan dihapus permanen.',
      confirmLabel: 'Hapus',
    );
    if (!ok || !mounted) return;

    setState(() => _deletingPhotos.add(photo.id));

    try {
      await WorkService.instance.deletePhoto(widget.bus.id, photo.id);
      if (!mounted) return;
      setState(() {
        _photos = _photos.where((p) => p.id != photo.id).toList();
        _photoFutures.remove(photo.id);
      });
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Gagal menghapus foto. Coba lagi.');
    } finally {
      if (mounted) setState(() => _deletingPhotos.remove(photo.id));
    }
  }

  void _openViewer(JobPhoto photo) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewerPage(future: _photoFuture(photo.id)),
      ),
    );
  }

  Future<void> _finish() async {
    if (!_canFinish) return;

    final ok = await _confirm(
      title: 'Selesaikan pekerjaan?',
      message:
          'Setelah ini checklist dan foto tidak bisa diubah, dan pekerjaan masuk ke pemeriksaan Pengawas.',
      confirmLabel: 'Selesai Cuci',
    );
    if (!ok || !mounted) return;

    setState(() => _finishing = true);

    try {
      final bus = await WorkService.instance.finishJob(widget.bus.id);
      if (!mounted) return;
      Navigator.pop<BusWash>(context, bus);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Terjadi kesalahan. Coba lagi.');
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

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: RefreshIndicator(
          onRefresh: () => _load(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              if (_instructions.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildInstructions(),
              ],
              const SizedBox(height: 24),
              _buildChecklist(),
              const SizedBox(height: 24),
              _buildPhotos(),
              const SizedBox(height: 24),
              _buildFinish(),
            ],
          ),
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

    return Container(
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
              ],
            ),
          ),
        ],
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
                      onChanged: (_savingItems.contains(item.id) || _busy)
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

  Widget _buildPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Foto Hasil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${_photos.length} foto',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _pickFromCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Kamera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeri'),
              ),
            ),
          ],
        ),
        if (_uploading) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _uploadTotal == 0 ? null : _uploadDone / _uploadTotal,
          ),
          const SizedBox(height: 6),
          Text(
            'Mengunggah $_uploadDone/$_uploadTotal...',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_photos.isEmpty)
          const Text(
            'Belum ada foto. Minimal 1 foto wajib diunggah.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: _photos.map(_photoTile).toList(),
          ),
      ],
    );
  }

  Widget _photoTile(JobPhoto photo) {
    final deleting = _deletingPhotos.contains(photo.id);

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<Uint8List>(
            future: _photoFuture(photo.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return InkWell(
                  onTap: () => setState(() => _photoFutures.remove(photo.id)),
                  child: Container(
                    color: AppColors.background,
                    child: const Center(
                      child: Icon(Icons.refresh, color: Colors.grey),
                    ),
                  ),
                );
              }

              final bytes = snapshot.data;
              if (bytes == null || bytes.isEmpty) {
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
        ),
        if (deleting)
          Container(
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: _busy ? null : () => _deletePhoto(photo),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFinish() {
    final missing = <String>[
      if (_requiredLeft > 0) 'centang $_requiredLeft checklist wajib',
      if (_photos.isEmpty) 'unggah minimal 1 foto',
    ];

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
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Untuk menyelesaikan: ${missing.join(' dan ')}.',
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

class _PhotoViewerPage extends StatelessWidget {
  final Future<Uint8List> future;

  const _PhotoViewerPage({required this.future});

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
              child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
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