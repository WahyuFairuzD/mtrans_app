import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/attendance.dart';
import '../models/branch.dart';
import 'api_client.dart';
import 'api_exception.dart';

class AttendanceService {
  AttendanceService._();
  static final AttendanceService instance = AttendanceService._();

  Dio get _dio => ApiClient.dio;

  Future<List<Branch>> fetchBranches() async {
    try {
      final response = await _dio.get('/branches');
      final body = response.data as Map<String, dynamic>;
      return (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(Branch.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<AttendanceRecord>> fetchMyToday() async {
    try {
      final response = await _dio.get('/attendance/me/today');
      return _records(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<AttendanceRecord>> fetchOwnerToday({int? branchId}) async {
    try {
      final response = await _dio.get(
        '/attendance/today',
        queryParameters: branchId == null ? null : {'branch_id': branchId},
      );
      return _records(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AttendanceRecord> submit({
    required AttendanceType type,
    required int branchId,
    required double latitude,
    required double longitude,
    required double accuracyM,
    required Uint8List photo,
  }) async {
    try {
      final form = FormData.fromMap({
        'type': type.apiValue,
        'branch_id': branchId.toString(),
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'accuracy_m': accuracyM.toString(),
        'photo': MultipartFile.fromBytes(
          photo,
          filename: 'attendance.jpg',
          contentType: DioMediaType.parse('image/jpeg'),
        ),
      });
      final response = await _dio.post(
        '/attendance',
        data: form,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 1),
        ),
      );
      final body = response.data as Map<String, dynamic>;
      return AttendanceRecord.fromJson(
        body['attendance'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  List<AttendanceRecord> _records(Map<String, dynamic> body) =>
      (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(AttendanceRecord.fromJson)
          .toList();
}
