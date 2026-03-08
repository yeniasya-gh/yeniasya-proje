// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';

String createPdfObjectUrl(Uint8List bytes) {
  final blob = Blob([bytes], 'application/pdf');
  return Url.createObjectUrlFromBlob(blob);
}

void revokePdfObjectUrl(String? url) {
  if (url == null || url.isEmpty || !url.startsWith('blob:')) return;
  Url.revokeObjectUrl(url);
}

Widget buildPdfWebFrame(String url) {
  final viewType =
      "pdf-iframe-${DateTime.now().millisecondsSinceEpoch}-${url.hashCode}";

  ui.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final normalized = url.trim().toLowerCase();

    if (normalized.startsWith('blob:') || normalized.endsWith('.pdf')) {
      final embed = EmbedElement()
        ..src = url
        ..type = 'application/pdf'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return embed;
    }

    final iframe = IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'cross-origin-isolated; fullscreen'
      ..setAttribute('allowfullscreen', 'true');
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
