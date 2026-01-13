import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SliderWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const SliderWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<SliderWebViewScreen> createState() => _SliderWebViewScreenState();
}

class _SliderWebViewScreenState extends State<SliderWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    if (!kIsWeb) {
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint("WebView start: $url");
            _setLoading(true);
            _setError(null);
          },
          onPageFinished: (url) {
            debugPrint("WebView finish: $url");
            _setLoading(false);
          },
          onWebResourceError: (error) {
            debugPrint("WebView error: ${error.errorCode} ${error.description}");
            _setLoading(false);
            _setError("${error.errorCode} ${error.description}");
          },
        ),
      );
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => _loading = value);
  }

  void _setError(String? value) {
    if (mounted) setState(() => _error = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: kIsWeb
                  ? Center(child: Text(widget.title))
                  : WebViewWidget(controller: _controller),
            ),
          ),
          if (_error != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white, size: 36),
                        const SizedBox(height: 12),
                        const Text(
                          "Sayfa yüklenemedi",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.url,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _controller.loadRequest(Uri.parse(widget.url)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                          ),
                          child: const Text("Tekrar Dene"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
