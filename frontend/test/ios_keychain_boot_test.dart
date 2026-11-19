import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtrans_wash/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final keychain = <String, String>{};

  setUp(() {
    keychain
      ..clear()
      ..['access_token'] = 'token-lama';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map).cast<String, Object?>();
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return keychain[key];
            case 'write':
              keychain[key!] = args['value'] as String;
              return null;
            case 'delete':
              keychain.remove(key);
              return null;
            case 'deleteAll':
              keychain.clear();
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS instalasi baru menghapus token sisa dari keychain', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await AuthService.instance.restoreSession();

    expect(keychain, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('secure_storage_install_marker'), isTrue);
  });

  test('iOS instalasi lama mempertahankan sesi', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'secure_storage_install_marker': true,
    });

    await AuthService.instance.restoreSession();

    expect(keychain['access_token'], 'token-lama');
  });

  test('Android tidak pernah menghapus sesi saat restore', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await AuthService.instance.restoreSession();

    expect(keychain['access_token'], 'token-lama');
  });
}
