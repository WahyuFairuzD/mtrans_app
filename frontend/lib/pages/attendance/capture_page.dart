import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

const _maxPhotoBytes = 1024 * 1024;

Uint8List _compressJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('Foto tidak dapat dibaca.');
  final oriented = img.bakeOrientation(decoded);
  for (final width in [1280, 1024, 860, 720, 600]) {
    final resized = oriented.width > width
        ? img.copyResize(oriented, width: width)
        : oriented;
    for (final quality in [85, 75, 65, 55, 45]) {
      final result = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality),
      );
      if (result.lengthInBytes <= _maxPhotoBytes) return result;
    }
  }
  throw StateError('Ukuran foto masih melebihi 1 MB. Coba ambil ulang.');
}

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  CameraController? _controller;
  Uint8List? _captured;
  bool _initializing = true;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Kamera tidak ditemukan.');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _error = null;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = switch (error.code) {
          'CameraAccessDenied' =>
            'Izin kamera ditolak. Izinkan akses kamera untuk absensi.',
          'CameraAccessDeniedWithoutPrompt' =>
            'Izin kamera diblokir. Aktifkan izin kamera di pengaturan.',
          _ => 'Kamera tidak dapat dibuka. ${error.description ?? ''}'.trim(),
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Kamera tidak tersedia di perangkat ini.';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return;
    }
    setState(() => _processing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final compressed = await compute(_compressJpeg, bytes);
      if (!mounted) return;
      setState(() {
        _captured = compressed;
        _processing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto. Coba lagi.')),
      );
    }
  }

  void _retake() => setState(() => _captured = null);

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final captured = _captured;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Foto Absensi'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _initializing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : captured != null
                    ? Image.memory(captured, fit: BoxFit.contain)
                    : _controller == null
                    ? const SizedBox.shrink()
                    : CameraPreview(_controller!),
              ),
            ),
            if (captured != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _processing ? null : _retake,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Ulangi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _processing
                            ? null
                            : () => Navigator.pop(context, captured),
                        icon: const Icon(Icons.check),
                        label: const Text('Gunakan Foto'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD9191F),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: FloatingActionButton(
                    onPressed: _initializing || _error != null || _processing
                        ? null
                        : _capture,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFD9191F),
                    child: _processing
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.camera_alt, size: 30),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
