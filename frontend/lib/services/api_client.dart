import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiClient {
  ApiClient._();

  static final Dio dio = _build();

  static Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = AuthService.instance.accessToken;

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final auth = AuthService.instance;
          final request = error.requestOptions;
          final alreadyRetried = request.extra['retried'] == true;

          if (error.response?.statusCode == 401 &&
              !alreadyRetried &&
              auth.isLoggedIn) {
            final refreshed = await auth.refreshTokens();

            if (refreshed) {
              request.extra['retried'] = true;
              request.headers['Authorization'] =
                  'Bearer ${auth.accessToken}';

              try {
                final response = await dio.fetch(request);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
          }

          handler.next(error);
        },
      ),
    );

    return dio;
  }
}