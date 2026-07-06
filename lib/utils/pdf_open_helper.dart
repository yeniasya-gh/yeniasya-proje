import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/secure_file_service.dart';
import '../services/upload_service.dart';
import '../screen/profile/pdf_viewer_screen.dart';

class PdfOpenHelper {
  static Future<void> downloadAndOpen(
    BuildContext context, {
    required String url,
    required String title,
    required bool isPrivate,
    double? titleFontSize,
  }) async {
    final normalized = UploadService.normalizeUrl(url);
    Uint8List? initialBytes;
    try {
      initialBytes = kIsWeb
          ? null
          : await SecureFileService.instance.getPdfBytes(
              url: normalized,
              isPrivate: isPrivate,
            );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("PDF açılamadı: $e")));
      return;
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: normalized,
          title: title,
          isPrivate: isPrivate,
          initialBytes: initialBytes,
          titleFontSize: titleFontSize,
        ),
      ),
    );
  }
}
