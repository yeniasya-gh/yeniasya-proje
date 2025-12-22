// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';

Widget buildPdfWebFrame(String url) {
  final viewType = "pdf-iframe-${DateTime.now().millisecondsSinceEpoch}-${url.hashCode}";

  // Register iframe factory
  ui.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final iframe = IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'cross-origin-isolated; fullscreen'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('sandbox', 'allow-same-origin allow-scripts allow-forms allow-popups');
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
