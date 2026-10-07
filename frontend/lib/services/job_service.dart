import 'package:dio/dio.dart';
import '../models/bus_wash.dart';
import 'api_client.dart';
import 'api_exception.dart';

class JobService {
  JobService._();

  static final JobService instance = JobService._();

  Dio get _dio => ApiClient.dio;
  Future<List<BusWash>> fetchJobs({int limit = 100}) async {
    try {
      final res = await _dio.get('/jobs', queryParameters: {'limit': limit});
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(BusWash.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BusWash> createJob({
    required String unitId,
    required String locationId,
    required String serviceTypeId,
    String? initialNote,
  }) async {
    try {
      final res = await _dio.post(
        '/jobs',
        data: {
          'unit_id': unitId,
          'location_id': locationId,
          'service_type_id': serviceTypeId,
          if (initialNote != null && initialNote.isNotEmpty)
            'initial_condition_notes': initialNote,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return BusWash.fromJson(body['job'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}