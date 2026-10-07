import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const ApiException(this.message, {this.statusCode, this.code});

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;

    if (data is Map && data['error'] is Map) {
      final error = data['error'] as Map;
      final message = error['message'];

      if (message is String && message.isNotEmpty) {
        return ApiException(
          message,
          statusCode: e.response?.statusCode,
          code: error['code'] as String?,
        );
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const ApiException(
          'Tidak bisa terhubung ke server. Periksa koneksi internet kamu.',
        );
      default:
        return ApiException(
          'Terjadi kesalahan. Coba lagi.',
          statusCode: e.response?.statusCode,
        );
    }
  }

  @override
  String toString() => message;
}