class ApiConfig {
  ApiConfig._();

  /// Ganti lewat --dart-define saat run/build, contoh:
  /// flutter run --dart-define=API_BASE_URL=https://mtrans-api.xxx.workers.dev
  ///
  /// Default 10.0.2.2 = alamat localhost dari Android Emulator
  /// (wrangler dev jalan di port 8787).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8787',
  );
}
