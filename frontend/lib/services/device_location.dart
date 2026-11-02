import 'dart:async';

import 'package:geolocator/geolocator.dart';

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DeviceLocation {
  DeviceLocation._();
  static final instance = DeviceLocation._();

  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(
        'GPS mati. Aktifkan layanan lokasi lalu coba lagi.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
        'Izin lokasi ditolak. Izinkan akses lokasi untuk melakukan absensi.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        'Izin lokasi diblokir. Aktifkan izin lokasi di pengaturan perangkat.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on LocationServiceDisabledException {
      throw const DeviceLocationException(
        'GPS mati. Aktifkan layanan lokasi lalu coba lagi.',
      );
    } on PermissionDeniedException {
      throw const DeviceLocationException(
        'Izin lokasi ditolak. Izinkan akses lokasi untuk melakukan absensi.',
      );
    } on TimeoutException {
      throw const DeviceLocationException(
        'Lokasi tidak ditemukan dalam 15 detik. Coba lagi di area terbuka.',
      );
    }
  }
}
