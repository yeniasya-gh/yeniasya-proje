import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:typed_data';

const String _bridgeName = '__yaRenderPdfCover';

Future<Uint8List?> renderPdfCoverWithPdfJs(Uint8List pdfBytes) async {
  _ensureBridgeInstalled();

  final completer = Completer<String>();
  js.context.callMethod(_bridgeName, [
    pdfBytes,
    js.allowInterop((String dataUrl) {
      if (!completer.isCompleted) completer.complete(dataUrl);
    }),
    js.allowInterop((Object error) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(error.toString()));
      }
    }),
  ]);

  final dataUrl = await completer.future;
  if (dataUrl.isEmpty) return null;
  return UriData.parse(dataUrl).contentAsBytes();
}

void _ensureBridgeInstalled() {
  if (js.context.hasProperty(_bridgeName)) return;

  final script = html.ScriptElement()
    ..type = 'text/javascript'
    ..text = r'''
(function () {
  var PDFJS_BASE = 'https://cdn.yeniasyadijital.com/pdfjs-legacy';
  var PDFJS_SCRIPT = PDFJS_BASE + '/build/pdf.js';
  var PDFJS_WORKER = PDFJS_BASE + '/build/pdf.worker.js';
  var PDFJS_LOAD_PROMISE = null;

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var existing = document.querySelector('script[src="' + src + '"]');
      if (existing) {
        if (window.pdfjsLib) {
          resolve();
          return;
        }
        existing.addEventListener('load', resolve, { once: true });
        existing.addEventListener('error', reject, { once: true });
        return;
      }

      var script = document.createElement('script');
      script.src = src;
      script.defer = true;
      script.onload = resolve;
      script.onerror = function () {
        reject(new Error('PDF.js script yuklenemedi: ' + src));
      };
      document.head.appendChild(script);
    });
  }

  function ensurePdfJs() {
    if (window.pdfjsLib) return Promise.resolve(window.pdfjsLib);
    PDFJS_LOAD_PROMISE = PDFJS_LOAD_PROMISE || loadScript(PDFJS_SCRIPT);
    return PDFJS_LOAD_PROMISE.then(function () {
      if (!window.pdfjsLib) throw new Error('PDF.js global bulunamadi.');
      return window.pdfjsLib;
    });
  }

  window.__yaRenderPdfCover = function (bytes, onSuccess, onError) {
    ensurePdfJs()
      .then(function (pdfjsLib) {
        pdfjsLib.GlobalWorkerOptions.workerSrc = PDFJS_WORKER;
        return pdfjsLib.getDocument({
          data: bytes,
          cMapUrl: PDFJS_BASE + '/cmaps/',
          cMapPacked: true
        }).promise;
      })
      .then(function (doc) {
        return doc.getPage(1).then(function (page) {
          var originalViewport = page.getViewport({ scale: 1 });
          var maxWidth = 1200;
          var scale = originalViewport.width > maxWidth
            ? maxWidth / originalViewport.width
            : 1;
          var viewport = page.getViewport({ scale: scale });
          var canvas = document.createElement('canvas');
          canvas.width = Math.ceil(viewport.width);
          canvas.height = Math.ceil(viewport.height);
          var context = canvas.getContext('2d', { alpha: false });
          if (!context) throw new Error('Canvas context olusturulamadi.');

          return page.render({
            canvasContext: context,
            viewport: viewport
          }).promise.then(function () {
            var dataUrl = canvas.toDataURL('image/png');
            try { page.cleanup(); } catch (_) {}
            return doc.destroy().catch(function () {}).then(function () {
              onSuccess(dataUrl);
            });
          });
        });
      })
      .catch(function (error) {
        onError(error && (error.stack || error.message) ? (error.stack || error.message) : String(error));
      });
  };
})();
''';
  html.document.head?.append(script);
}
