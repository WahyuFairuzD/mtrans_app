import 'package:dio/dio.dart';
import '../models/bus_wash.dart';
import '../models/history_filter.dart';
import '../models/recap.dart';
import 'api_client.dart';
import 'api_exception.dart';

class HistoryService {
  HistoryService._();

  static final HistoryService instance = HistoryService._();

  Dio get _dio => ApiClient.dio;

  Future<List<BusWash>> fetchPage(
    HistoryFilter filter, {
    required int limit,
    required int offset,
  }) async {
    try {
      final res = await _dio.get(
        '/jobs',
        queryParameters: filter.toQuery(limit: limit, offset: offset),
      );
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(BusWash.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Recap> fetchRecap(HistoryFilter filter) async {
    try {
      final res = await _dio.get(
        '/jobs/recap',
        queryParameters: filter.toQuery(),
      );
      final body = res.data as Map<String, dynamic>;
      return Recap.fromJson(body['recap'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}