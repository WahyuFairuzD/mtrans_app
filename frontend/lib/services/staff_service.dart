import 'package:dio/dio.dart';
import '../models/app_user.dart';
import '../models/staff_account.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Kelola akun Pengawas dan Petugas Cuci (khusus Owner).
class StaffService {
  StaffService._();
  static final StaffService instance = StaffService._();
  Dio get _dio => ApiClient.dio;

  Future<List<StaffAccount>> fetchStaff({String? query}) async {
    try {
      final q = query?.trim() ?? '';
      final res = await _dio.get(
        '/users',
        queryParameters: {if (q.isNotEmpty) 'q': q},
      );
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(StaffAccount.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<StaffAccount> createStaff({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    required int? branchId,
  }) async {
    try {
      final res = await _dio.post(
        '/users',
        data: {
          'full_name': fullName,
          'email': email,
          'password': password,
          'phone': phone.isEmpty ? null : phone,
          'role': role.apiValue,
          'branch_id': branchId,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return StaffAccount.fromJson(body['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<StaffAccount> updateStaff(
    String id, {
    required String fullName,
    required String phone,
    required UserRole role,
    required int? branchId,
    required bool isActive,
  }) async {
    try {
      final res = await _dio.patch(
        '/users/$id',
        data: {
          'full_name': fullName,
          'phone': phone.isEmpty ? null : phone,
          'role': role.apiValue,
          'branch_id': branchId,
          'is_active': isActive,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return StaffAccount.fromJson(body['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
