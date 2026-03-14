import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/secure_file_service.dart';
import '../services/upload_service.dart';
import '../screen/profile/pdf_viewer_screen.dart';

class PdfOpenHelper {
  static Future<void> downloadAndOpen(
    BuildContext context, {
    required String url,
    required String title,
    required bool isPrivate,
    ValueChanged<double>? onProgress,
    bool showDialogProgress = false,
  }) async {
    final normalized = UploadService.normalizeUrl(url);

    if (kIsWeb) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: normalized,
            title: title,
            isPrivate: isPrivate,
          ),
        ),
      );
      return;
    }

    if (isPrivate) {
      final cached = await SecureFileService.instance.hasCached(normalized);
      if (!context.mounted) return;
      if (cached) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              url: normalized,
              title: title,
              isPrivate: isPrivate,
            ),
          ),
        );
        return;
      }
    }

    double progress = 0;
    var dialogActive = false;
    bool report(double value) {
      final clamped = value.clamp(0, 1).toDouble();
      if (clamped < progress) return false; // keep progress monotonic on retry
      onProgress?.call(clamped);
      progress = clamped;
      return true;
    }

    StateSetter? dialogSetState;

    if (showDialogProgress) {
      if (!context.mounted) return;
      dialogActive = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            dialogSetState = setState;
            final pct = (progress * 100).round();
            return AlertDialog(
              title: const Text("İndiriliyor"),
              content: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text("%$pct"),
                ],
              ),
            );
          },
        ),
      ).whenComplete(() {
        dialogActive = false;
        dialogSetState = null;
      });
    }

    try {
      report(0);
      await SecureFileService.instance.getPdfBytes(
        url: normalized,
        isPrivate: isPrivate,
        onProgress: (p) {
          final updated = report(p);
          if (updated && dialogActive) {
            dialogSetState?.call(() {});
          }
        },
      );
      report(1);
      if (showDialogProgress && context.mounted) {
        dialogActive = false;
        dialogSetState = null;
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: normalized,
            title: title,
            isPrivate: isPrivate,
          ),
        ),
      );
    } catch (e) {
      if (showDialogProgress && context.mounted) {
        dialogActive = false;
        dialogSetState = null;
        Navigator.of(context, rootNavigator: true).pop();
      }
      rethrow;
    }
  }
}
