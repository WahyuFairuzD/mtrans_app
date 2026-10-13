import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/bus_wash.dart';
import '../models/work.dart';
import 'api_client.dart';
import 'api_exception.dart';

class WorkService {
  WorkService._();

  static final WorkService instance = WorkService._();

  Dio get _dio => ApiClient.dio;

  Future<BusWash> startJob(String jobId) async {
    try {
      final res = await _dio.post('/jobs/$jobId/start');
      final body = res.data as Map<String, dynamic>;
      return BusWash.fromJson(body['job'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BusWash> finishJob(String jobId) async {
    try {
      final res = await _dio.post('/jobs/$jobId/finish');
      final body = res.data as Map<String, dynamic>;
      return BusWash.fromJson(body['job'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<ChecklistItem>> fetchChecklist(String jobId) async {
    try {
      final res = await _dio.get('/jobs/$jobId/checklist');
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(ChecklistItem.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ChecklistItem> setChecklistItem({
    required String jobId,
    required String itemId,
    required bool isDone,
  }) async {
    try {
      final res = await _dio.patch(
        '/jobs/$jobId/checklist/$itemId',
        data: {'is_done': isDone},
      );
      final body = res.data as Map<String, dynamic>;
      return ChecklistItem.fromJson(body['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<JobPhoto>> fetchPhotos(String jobId) async {
    try {
      final res = await _dio.get('/jobs/$jobId/photos');
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(JobPhoto.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<JobPhoto> uploadPhoto({
    required String jobId,
    required String path,
  }) async {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    for (var attempt = 0;; attempt++) {
      try {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            path,
            filename: fileName,
            contentType: DioMediaType.parse(_mimeFor(path)),
          ),
        });

        final res = await _dio.post(
          '/jobs/$jobId/photos',
          data: form,
          options: Options(
            contentType: Headers.multipartFormDataContentType,
            sendTimeout: const Duration(minutes: 2),
            receiveTimeout: const Duration(minutes: 1),
          ),
        );

        final body = res.data as Map<String, dynamic>;
        return JobPhoto.fromJson(body['photo'] as Map<String, dynamic>);
      } on DioException catch (e) {
        final tokenRetry = attempt == 0 && e.error is StateError;
        if (!tokenRetry) throw ApiException.fromDio(e);
      }
    }
  }

  Future<Uint8List> fetchPhotoBytes(String jobId, String photoId) async {
    try {
      final res = await _dio.get<List<int>>(
        '/jobs/$jobId/photos/$photoId/file',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const <int>[]);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deletePhoto(String jobId, String photoId) async {
    try {
      await _dio.delete('/jobs/$jobId/photos/$photoId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  String _mimeFor(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}