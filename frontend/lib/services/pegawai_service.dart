import 'package:dio/dio.dart';
import '../models/assignment.dart';
import 'api_client.dart';
import 'api_exception.dart';

class PegawaiService {
  PegawaiService._();

  static final PegawaiService instance = PegawaiService._();

  Dio get _dio => ApiClient.dio;

  Future<List<PegawaiItem>> fetchPegawai() async {
    try {
      final res = await _dio.get('/pegawai');
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(PegawaiItem.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}