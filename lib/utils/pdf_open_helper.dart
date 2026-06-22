import 'package:flutter/material.dart';

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

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: normalized,
          title: title,
          isPrivate: isPrivate,
          titleFontSize: titleFontSize,
        ),
      ),
    );
  }
}
