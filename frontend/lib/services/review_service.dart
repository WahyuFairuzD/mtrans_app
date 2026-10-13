import 'package:dio/dio.dart';
import '../models/bus_wash.dart';
import '../models/inspection.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  Dio get _dio => ApiClient.dio;

  Future<BusWash> submitInspection({
    required String jobId,
    required InspectionResult result,
    String? notes,
  }) async {
    try {
      final res = await _dio.post(
        '/jobs/$jobId/inspection',
        data: {
          'result': result.apiValue,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return BusWash.fromJson(body['job'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BusWash> recordExit(String jobId) async {
    try {
      final res = await _dio.post('/jobs/$jobId/exit');
      final body = res.data as Map<String, dynamic>;
      return BusWash.fromJson(body['job'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}