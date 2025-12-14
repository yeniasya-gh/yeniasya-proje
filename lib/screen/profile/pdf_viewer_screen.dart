import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../services/upload_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/secure_file_service.dart';

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
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();
  double _zoom = 1.0;
  final Set<int> _bookmarks = {};
  final Map<int, String> _notes = {};

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
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: "Bu sayfayı işaretle",
            onPressed: _loading ? null : _addBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: "Etiket/Not ekle",
            onPressed: _loading ? null : _addNoteDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : (_bytes == null
                  ? _errorView()
                  : Column(
                      children: [
                        _toolbar(),
                        Expanded(
                          child: SfPdfViewer.memory(
                            _bytes!,
                            key: _pdfKey,
                            controller: _controller,
                            canShowScrollHead: true,
                            canShowScrollStatus: true,
                            pageLayoutMode: PdfPageLayoutMode.single,
                            enableDoubleTapZooming: true,
                          ),
                        ),
                        _bookmarksBar(),
                      ],
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
    return SecureFileService.instance.getPdfBytes(
      url: normalized,
      isPrivate: widget.isPrivate,
    );
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
                  onDeleted: () => setState(() => _bookmarks.remove(p)),
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
      return;
    }
    setState(() => _notes[page] = saved);
    if (!_bookmarks.contains(page)) {
      setState(() => _bookmarks.add(page));
    }
  }
}
