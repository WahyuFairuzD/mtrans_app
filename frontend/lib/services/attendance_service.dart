import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/attendance.dart';
import '../utils/invoice_format.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class AttendanceService {
  AttendanceService._() {
    AuthService.instance.addListener(() {
      if (AuthService.instance.user == null) _photoCache.clear();
    });
  }
  static final AttendanceService instance = AttendanceService._();

  Dio get _dio => ApiClient.dio;

  final Map<String, Future<Uint8List>> _photoCache = {};

  Future<List<AttendanceRecord>> fetchMyToday() async {
    try {
      final response = await _dio.get('/attendance/me/today');
      return _records(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<AttendanceRecord>> fetchOwnerDay({
    required DateTime date,
    int? branchId,
  }) async {
    try {
      final response = await _dio.get(
        '/attendance/day',
        queryParameters: {
          'date': isoDate(date),
          if (branchId != null) 'branch_id': branchId,
        },
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

  Future<Uint8List> photoBytes(String attendanceId) =>
      _photoCache.putIfAbsent(attendanceId, () => _loadPhoto(attendanceId));

  Future<Uint8List> _loadPhoto(String attendanceId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/attendance/$attendanceId/photo',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const <int>[]);
    } on DioException catch (error) {
      _photoCache.remove(attendanceId);
      throw ApiException.fromDio(error);
    }
  }

  List<AttendanceRecord> _records(Map<String, dynamic> body) =>
      (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(AttendanceRecord.fromJson)
          .toList();
}
