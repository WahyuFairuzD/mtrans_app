import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../theme/app_theme.dart';

/// Kotak untuk menggambar tanda tangan dengan jari atau stylus.
/// Controller dimiliki pemanggil (dibuat dan di-dispose di sana).
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller, this.height = 170});

  final SignatureController controller;
  final double height;

  /// Controller dengan goresan hitam dan latar transparan (PNG siap ditempel di PDF).
  static SignatureController newController() => SignatureController(
    penStrokeWidth: 2.6,
    penColor: Colors.black,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Signature(
              controller: controller,
              height: height,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: controller.clear,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Hapus'),
          ),
        ),
      ],
    );
  }
}
