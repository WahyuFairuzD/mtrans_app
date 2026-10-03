import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/app_user.dart';

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  const AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  AppUser? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _initialized = false;
  Completer<bool>? _refreshing;

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _user != null;
  bool get initialized => _initialized;

  Future<void> restoreSession() async {
    try {
      _accessToken = await _storage.read(key: _accessKey);
      _refreshToken = await _storage.read(key: _refreshKey);

      if (_refreshToken != null) {
        await refreshTokens();
      }
    } catch (_) {
      await _clear();
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      await _applySession(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      await _dio.post(
        '/auth/register',
        data: {
          'full_name': fullName,
          'email': email,
          'password': password,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
    } on DioException catch (e) {
      throw _toException(e);
    }

    await login(email: email, password: password);
  }

  Future<void> logout() async {
    final token = _accessToken;

    if (token != null) {
      try {
        await _dio.post(
          '/auth/logout',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
      } catch (_) {
      }
    }

    await _clear();
  }

  Future<bool> refreshTokens() async {
    final pending = _refreshing;
    if (pending != null) return pending.future;

    final completer = Completer<bool>();
    _refreshing = completer;

    try {
      final refreshToken = _refreshToken;

      if (refreshToken == null) {
        completer.complete(false);
        return false;
      }

      final res = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      await _applySession(res.data as Map<String, dynamic>);
      completer.complete(true);
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await _clear();
      }

      completer.complete(false);
      return false;
    } catch (_) {
      completer.complete(false);
      return false;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);

    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);

    _accessToken = access;
    _refreshToken = refresh;
    _user = user;

    notifyListeners();
  }

  Future<void> _clear() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;

    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {}

    notifyListeners();
  }

  AuthException _toException(DioException e) {
    final data = e.response?.data;

    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) {
        return AuthException(message, statusCode: e.response?.statusCode);
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const AuthException(
          'Tidak bisa terhubung ke server. Periksa koneksi internet kamu.',
        );
      default:
        return AuthException(
          'Terjadi kesalahan. Coba lagi.',
          statusCode: e.response?.statusCode,
        );
    }
  }
}