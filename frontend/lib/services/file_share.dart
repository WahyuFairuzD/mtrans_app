import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class FileShare {
  FileShare._();

  static const pdfMime = 'application/pdf';
  static const xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static Future<void> shareBytes(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  }
}
