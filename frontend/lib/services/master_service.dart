import 'package:dio/dio.dart';
import '../models/branch.dart';
import '../models/master_data.dart';
import '../models/vehicle_type.dart';
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

  Future<List<Branch>> fetchBranches() async {
    try {
      final res = await _dio.get('/branches');
      return _list(res).map(Branch.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<BusUnit>> fetchUnits({
    String? query,
    bool includeInactive = false,
  }) async {
    try {
      final q = query?.trim() ?? '';
      final res = await _dio.get(
        '/units',
        queryParameters: {
          'limit': 200,
          'active': includeInactive ? 'all' : 'true',
          if (q.isNotEmpty) 'q': q,
        },
      );
      return _list(res).map(BusUnit.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BusUnit> createUnit({
    required String plateNumber,
    required String armadaName,
    required VehicleType vehicleType,
  }) async {
    try {
      final res = await _dio.post(
        '/units',
        data: {
          'plate_number': plateNumber.trim().isEmpty ? kNoPlate : plateNumber,
          'brand': armadaName,
          'vehicle_type': vehicleType.apiValue,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return BusUnit.fromJson(body['unit'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BusUnit> updateUnit(
    String id, {
    required String plateNumber,
    required String armadaName,
    required VehicleType vehicleType,
    required bool isActive,
  }) async {
    try {
      final res = await _dio.patch(
        '/units/$id',
        data: {
          'plate_number': plateNumber.trim().isEmpty ? kNoPlate : plateNumber,
          'brand': armadaName,
          'vehicle_type': vehicleType.apiValue,
          'is_active': isActive,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return BusUnit.fromJson(body['unit'] as Map<String, dynamic>);
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
