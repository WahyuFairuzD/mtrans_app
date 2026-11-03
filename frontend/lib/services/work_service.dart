import 'package:dio/dio.dart';
import '../models/bus_wash.dart';
import '../models/work.dart';
import 'api_client.dart';
import 'api_exception.dart';

class WorkService {
  WorkService._();

  static final WorkService instance = WorkService._();

  Dio get _dio => ApiClient.dio;

  Future<BusWash> startJob(String jobId) => _transition(jobId, 'start');

  Future<BusWash> finishJob(String jobId) => _transition(jobId, 'finish');

  Future<BusWash> _transition(String jobId, String action) async {
    try {
      final res = await _dio.post('/jobs/$jobId/$action');
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
}
