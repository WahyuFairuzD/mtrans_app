import 'package:dio/dio.dart';
import '../models/master_data.dart';
import 'api_client.dart';
import 'api_exception.dart';

class MasterService {
  MasterService._();
  static final MasterService instance = MasterService._();
  Dio get _dio => ApiClient.dio;

  List<Map<String, dynamic>> _list(Response<dynamic> res) {
    final body = res.data as Map<String, dynamic>;
    return (body['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<BusUnit>> fetchUnits() async {
    try {
      final res = await _dio.get('/units', queryParameters: {'limit': 200});
      return _list(res).map(BusUnit.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BusUnit> createUnit({
    required String plateNumber,
    required String brand,
  }) async {
    try {
      final res = await _dio.post(
        '/units',
        data: {'plate_number': plateNumber, 'brand': brand},
      );
      final body = res.data as Map<String, dynamic>;
      return BusUnit.fromJson(body['unit'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<LocationItem>> fetchLocations() async {
    try {
      final res = await _dio.get('/locations');
      return _list(res).map(LocationItem.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<ServiceTypeItem>> fetchServiceTypes() async {
    try {
      final res = await _dio.get('/service-types');
      return _list(res).map(ServiceTypeItem.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}