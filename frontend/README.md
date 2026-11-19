# mtrans_wash (Flutter)

Aplikasi operasional cuci bus Mtrans.

## Menjalankan di Android

```bash
flutter pub get
flutter run
```

## Menjalankan di iOS

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run
```

- Buka `ios/Runner.xcworkspace` di Xcode untuk mengatur Team signing.
- Minimum iOS: 15.0.
- Izin yang diminta: kamera (foto absensi), lokasi saat aplikasi dipakai
  (titik absensi), mikrofon (dipakai modul kamera, aplikasi tidak merekam audio).

```bash
dart run flutter_launcher_icons
```