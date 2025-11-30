import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../services/upload_service.dart';
import '../../services/error/error_manager.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool isPrivate;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.isPrivate = true,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _bytes = await _fetchPdfBytes();
    } catch (e) {
      _error = ErrorManager.parseGraphQLError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_bytes == null && _error == null) {
          _error = "PDF yüklenemedi, lütfen tekrar deneyin.";
        }
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : (_bytes == null
                  ? _errorView()
                  : SfPdfViewer.memory(
                      _bytes!,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                    )),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 8),
          Text(_error ?? "PDF yüklenemedi"),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            child: const Text("Tekrar dene"),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _fetchPdfBytes() async {
    final normalized = UploadService.normalizeUrl(widget.url);

    if (!widget.isPrivate) {
      final resp = await http.get(Uri.parse(normalized)).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
        throw Exception("PDF alınamadı (${resp.statusCode})");
      }
      return resp.bodyBytes;
    }

    final uri = Uri.parse("${UploadService.normalizeUrl("/private/view")}");
    debugPrint("PDF view request -> $uri");
    final payload = {"path": normalized.replaceFirst(RegExp(r'^https?://[^/]+'), "")};
    debugPrint("PDF path -> ${payload["path"]}");

    final resp = await http
        .post(
          uri,
          headers: {
            "content-type": "application/json",
            "x-api-key": UploadService.privateAuthToken,
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    debugPrint("PDF view status: ${resp.statusCode}");
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      final bodyPreview = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
      throw Exception("Görünüm linki alınamadı (${resp.statusCode}): $bodyPreview");
    }

    return resp.bodyBytes;
  }
}
