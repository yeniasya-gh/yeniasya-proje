import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../services/upload_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/logging_service.dart';
import '../../services/secure_file_service.dart';
import '../../widgets/pdf_web_frame_stub.dart'
    if (dart.library.html) '../../widgets/pdf_web_frame_web.dart' as pdf_web_frame;
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
  String? _webPdfUrl;
  bool _loading = true;
  String? _error;
  final LoggingService _logger = LoggingService();
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();
  double _zoom = 1.0;
  final Set<int> _bookmarks = {};
  final Map<int, String> _notes = {};
  bool _testBusy = false;
  int? _lastSavedPage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Geçici test: web'de PDF fetch sorununu debug etmek için
  Future<void> testPdfFetch() async {
    const pdfPath = "/private/dergi/1764576570252-07_Temmuz_2025_Bizim_Aile_compressed.pdf";
    final targetPath = Uri.parse(UploadService.normalizeUrl(pdfPath)).path;
    final tokenUri = Uri.parse(UploadService.normalizeUrl("/private/view-token"));
    setState(() => _testBusy = true);
    try {
      final tokenResp = await http
          .post(
            tokenUri,
            headers: {
              "content-type": "application/json",
              "accept": "application/json",
              "x-api-key": UploadService.privateAuthToken,
            },
            body: jsonEncode({"path": targetPath}),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint("🧪 Token status: ${tokenResp.statusCode}");
      debugPrint("🧪 Token body: ${tokenResp.body}");
      if (tokenResp.statusCode == 200) {
        final tokenData = jsonDecode(tokenResp.body);
        final pdfUrl = tokenData["url"] ?? tokenData["viewUrl"] ?? tokenData["path"];
        final token = tokenData["token"]?.toString();
        debugPrint("🧪 Token PDF URL: $pdfUrl");
        debugPrint("🧪 Token value: $token");
        final viewSecure = (pdfUrl != null && pdfUrl.toString().isNotEmpty)
            ? UploadService.normalizeUrl(pdfUrl.toString())
            : Uri.parse(UploadService.normalizeUrl("/private/view-secure"))
                .replace(queryParameters: {"token": token ?? ""}).toString();
        if (viewSecure.isNotEmpty) {
          final pdfResp = await http
              .get(
                Uri.parse(viewSecure.toString()),
                headers: {"accept": "application/pdf"},
              )
              .timeout(const Duration(seconds: 10));
          debugPrint("🧪 PDF fetch status: ${pdfResp.statusCode}");
          debugPrint("🧪 Content-Type: ${pdfResp.headers["content-type"]}");
          debugPrint("🧪 Body length: ${pdfResp.bodyBytes.length}");
        }
      }
    } catch (e) {
      debugPrint("🧪 PDF fetch error: $e");
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _webPdfUrl = null;
    });
    try {
      await _loadPersistedState();
      if (kIsWeb) {
        final target = widget.isPrivate
            ? await SecureFileService.instance.getWebViewSecureUrl(url: widget.url)
            : UploadService.normalizeUrl(widget.url);
        _webPdfUrl = target;
        _bytes = null;
        return;
      }

      _bytes = await _fetchPdfBytes();
    } catch (e, s) {
      _error = ErrorManager.parseGraphQLError(e.toString());
      await _logger.logError(
        service: "PdfViewerScreen",
        operation: "load",
        message: _error ?? e.toString(),
        stackTrace: s.toString(),
        payload: {
          "url": widget.url,
          "normalizedUrl": UploadService.normalizeUrl(widget.url),
          "isPrivate": widget.isPrivate,
          "platform": defaultTargetPlatform.toString(),
          "web": kIsWeb,
        },
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_bytes == null && _error == null && !(kIsWeb && _webPdfUrl != null)) {
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
    final isWeb = kIsWeb;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          if (!isWeb)
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: "Bu sayfayı işaretle",
              onPressed: _loading ? null : _addBookmark,
            ),
          if (!isWeb)
            IconButton(
              icon: const Icon(Icons.note_add_outlined),
              tooltip: "Etiket/Not ekle",
              onPressed: _loading ? null : _addNoteDialog,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : Column(
                    children: [
                      if (!isWeb) _toolbar(),
                      Expanded(child: _buildViewer()),
                      if (!isWeb) _bookmarksBar(),
                    ],
                  ),
      ),
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
    // Web'de özel dosyalar için yeni /private/view-file endpoint'ini kullan
    if (kIsWeb && widget.isPrivate) {
      return SecureFileService.instance.getPdfBytes(url: normalized, isPrivate: widget.isPrivate);
    }

    if (kIsWeb) {
      final resp = await http.get(Uri.parse(normalized)).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
      return SecureFileService.instance.getPdfBytes(url: normalized, isPrivate: widget.isPrivate);
    }

    return SecureFileService.instance.getPdfBytes(
      url: normalized,
      isPrivate: widget.isPrivate,
    );
  }

  Widget _buildViewer() {
    if (kIsWeb) {
      if (_webPdfUrl == null || _webPdfUrl!.isEmpty) {
        return _errorView();
      }
      return pdf_web_frame.buildPdfWebFrame(_webPdfUrl!);
    }

    if (_bytes == null) return _errorView();

    return SfPdfViewer.memory(
      _bytes!,
      key: _pdfKey,
      controller: _controller,
      onDocumentLoadFailed: (details) async {
        final errorText = details.error;
        if (mounted) {
          setState(() => _error = errorText.isNotEmpty ? errorText : "PDF yüklenemedi");
        }
        await _logger.logError(
          service: "PdfViewerScreen",
          operation: "documentLoadFailed",
          message: errorText,
          payload: {
            "url": widget.url,
            "normalizedUrl": UploadService.normalizeUrl(widget.url),
            "isPrivate": widget.isPrivate,
            "platform": defaultTargetPlatform.toString(),
            "web": kIsWeb,
            "description": details.description,
          },
        );
      },
      onPageChanged: (details) {
        setState(() {});
        _persistState(page: details.newPageNumber);
      },
      onDocumentLoaded: (_) {
        setState(() {});
        if (_lastSavedPage != null && _lastSavedPage! > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _controller.jumpToPage(_lastSavedPage!);
            }
          });
        }
      },
      canShowScrollHead: true,
      canShowScrollStatus: true,
      pageLayoutMode: PdfPageLayoutMode.single,
      enableDoubleTapZooming: true,
    );
  }

  Future<void> _openPdfExternal(String url) async {
    final normalized = UploadService.normalizeUrl(url);
    final uri = Uri.parse(normalized);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("🧪 PDF external launch failed");
    }
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: "Önceki sayfa",
            onPressed: () {
              if (_controller.pageNumber > 1) {
                _controller.previousPage();
              }
            },
          ),
          Text("${_controller.pageNumber}/${_controller.pageCount}"),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: "Sonraki sayfa",
            onPressed: () {
              if (_controller.pageNumber < _controller.pageCount) {
                _controller.nextPage();
              }
            },
          ),
          const SizedBox(width: 12),
          const Text("Yakınlaştır"),
          Expanded(
            child: Slider(
              min: 1.0,
              max: 3.0,
              divisions: 10,
              value: _zoom,
              label: "${_zoom.toStringAsFixed(1)}x",
              onChanged: (v) {
                setState(() => _zoom = v);
                _controller.zoomLevel = v;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: "Ayraçlar",
            onPressed: _bookmarks.isEmpty ? null : _openBookmarksSheet,
          ),
        ],
      ),
    );
  }

  void _addBookmark() {
    final page = _controller.pageNumber;
    setState(() => _bookmarks.add(page));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sayfa $page ayraca eklendi")));
    _persistState();
  }

  void _openBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(12),
        children: _bookmarks.map((p) {
          return ListTile(
            leading: const Icon(Icons.bookmark),
            title: Text("Sayfa $p"),
            subtitle: _notes[p]?.isNotEmpty == true ? Text(_notes[p]!) : null,
            onTap: () {
              Navigator.pop(context);
              _controller.jumpToPage(p);
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() => _bookmarks.remove(p));
                _persistState();
                Navigator.pop(context);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bookmarksBar() {
    if (_bookmarks.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: _bookmarks
            .map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: InputChip(
                  avatar: const Icon(Icons.bookmark, size: 16),
                  label: Text("Sayfa $p"),
                  onPressed: () => _controller.jumpToPage(p),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() => _bookmarks.remove(p));
                    _persistState();
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _addNoteDialog() async {
    final page = _controller.pageNumber;
    final ctrl = TextEditingController(text: _notes[page] ?? "");
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Sayfa $page için not"),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Etiket / not girin",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text("Kaydet")),
        ],
      ),
    );
    if (saved == null) return;
    if (saved.isEmpty) {
      setState(() => _notes.remove(page));
      _persistState();
      return;
    }
    setState(() => _notes[page] = saved);
    if (!_bookmarks.contains(page)) {
      setState(() => _bookmarks.add(page));
    }
    _persistState();
  }

  String get _storageKey {
    final parsed = Uri.tryParse(widget.url);
    final name = parsed?.pathSegments.isNotEmpty == true ? parsed!.pathSegments.last : widget.url;
    return "pdf_state::$name";
  }

  Future<void> _loadPersistedState() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedBookmarks = (data["bookmarks"] as List?)
          ?.map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toSet();
      final savedNotesRaw = data["notes"] as Map<String, dynamic>?;
      final savedNotes = <int, String>{};
      savedNotesRaw?.forEach((k, v) {
        final key = int.tryParse(k.toString());
        if (key != null && v != null) savedNotes[key] = v.toString();
      });
      final savedPage = int.tryParse(data["page"]?.toString() ?? "");
      setState(() {
        _bookmarks
          ..clear()
          ..addAll(savedBookmarks ?? {});
        _notes
          ..clear()
          ..addAll(savedNotes);
        _lastSavedPage = savedPage;
      });
    } catch (_) {
      // ignore invalid state
    }
  }

  Future<void> _persistState({int? page}) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final data = {
      "page": page ?? _controller.pageNumber,
      "bookmarks": _bookmarks.toList(),
      "notes": _notes.map((k, v) => MapEntry(k.toString(), v)),
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }
}
