import 'dart:async';

import 'package:flutter/material.dart';

import 'pages/auth/auth_gate.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(AuthService.instance.restoreSession());

  runApp(const MtransApp());
}

class MtransApp extends StatelessWidget {
  const MtransApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mtrans',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
