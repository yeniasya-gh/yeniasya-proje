import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../services/auth/auth_token_store.dart';
import '../../services/error/error_manager.dart';
import '../../services/logging_service.dart';
import '../../services/secure_file_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/pdf_web_frame_stub.dart'
    if (dart.library.html) '../../widgets/pdf_web_frame_web.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool isPrivate;
  final Uint8List? initialBytes;
  final double? titleFontSize;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.isPrivate = true,
    this.initialBytes,
    this.titleFontSize,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  static const double _defaultZoomLevel = 0.5;
  static const double _minZoomLevel = _defaultZoomLevel;
  static const double _maxZoomLevel = 5.0;

  Uint8List? _bytes;
  String? _webViewerUrl;
  bool _loading = true;
  String? _error;
  double _zoom = _defaultZoomLevel;
  int? _lastSavedPage;
  bool _sidebarOpen = true;
  _PdfSidebarTab _sidebarTab = _PdfSidebarTab.bookmarks;
  _PendingNoteDraft? _pendingNoteDraft;

  final LoggingService _logger = LoggingService();
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();
  final TextEditingController _pageJumpController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _bookmarks = {};
  final List<_PdfStickyNoteEntry> _noteEntries = [];
  final Map<String, StickyNoteAnnotation> _noteAnnotations = {};

  PdfTextSearchResult? _searchResult;
  bool _consumedInitialBytes = false;

  @override
  void initState() {
    super.initState();
    _pageJumpController.text = "1";
    _load();
  }

  @override
  void dispose() {
    _searchResult?.removeListener(_handleSearchResultChanged);
    _pageJumpController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _currentPage {
    if (_controller.pageNumber > 0) return _controller.pageNumber;
    if (_lastSavedPage != null && _lastSavedPage! > 0) return _lastSavedPage!;
    return 1;
  }

  int get _totalPages => _controller.pageCount;

  List<int> get _sortedBookmarks {
    final items = _bookmarks.toList()..sort();
    return items;
  }

  List<_PdfStickyNoteEntry> get _sortedNotes {
    final items = List<_PdfStickyNoteEntry>.from(_noteEntries);
    items.sort((a, b) {
      final pageCompare = a.pageNumber.compareTo(b.pageNumber);
      if (pageCompare != 0) return pageCompare;
      return a.id.compareTo(b.id);
    });
    return items;
  }

  bool get _hasInlineSidebar {
    if (!kIsWeb || !mounted) return false;
    return MediaQuery.of(context).size.width >= 1180;
  }

  bool get _canGoPrevious => _currentPage > 1;

  bool get _canGoNext => _totalPages > 0 && _currentPage < _totalPages;

  bool get _hasSearchResult => _searchResult?.hasResult ?? false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _webViewerUrl = null;
    });
    try {
      await _loadPersistedState();
      if (!kIsWeb || widget.isPrivate) {
        _webViewerUrl = await SecureFileService.instance.getPdfViewerUrl(
          url: widget.url,
          isPrivate: widget.isPrivate,
        );
        return;
      }
      final seededBytes = widget.initialBytes;
      if (!_consumedInitialBytes &&
          seededBytes != null &&
          seededBytes.isNotEmpty) {
        _bytes = seededBytes;
        _consumedInitialBytes = true;
      } else {
        _bytes = await _fetchPdfBytes();
      }
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
        if (_bytes == null && _webViewerUrl == null && _error == null) {
          _error = "PDF yüklenemedi, lütfen tekrar deneyin.";
        }
      }
    }
  }

  Future<Uint8List> _fetchPdfBytes() async {
    final normalized = UploadService.normalizeUrl(widget.url);
    if (kIsWeb && widget.isPrivate) {
      return SecureFileService.instance.getPdfBytes(
        url: normalized,
        isPrivate: widget.isPrivate,
      );
    }

    if (kIsWeb) {
      final headers = {
        if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
          "Authorization": "Bearer ${AuthTokenStore.token}",
      };
      final resp = await http
          .get(Uri.parse(normalized), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
      return SecureFileService.instance.getPdfBytes(
        url: normalized,
        isPrivate: widget.isPrivate,
      );
    }

    return SecureFileService.instance.getPdfBytes(
      url: normalized,
      isPrivate: widget.isPrivate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    return Scaffold(
      backgroundColor: isWeb ? const Color(0xFFF4F6F8) : null,
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.titleFontSize == null
              ? null
              : TextStyle(fontSize: widget.titleFontSize),
        ),
        actions: _webAppBarActions(),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _errorView()
            : isWeb
            ? _buildWebLayout(context)
            : _buildMobileLayout(),
      ),
    );
  }

  List<Widget> _webAppBarActions() {
    return [
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: "Yenile",
        onPressed: _loading ? null : _load,
      ),
    ];
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
          ElevatedButton(onPressed: _load, child: const Text("Tekrar dene")),
        ],
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    if (_webViewerUrl != null) {
      return buildPdfWebFrame(_webViewerUrl!);
    }

    final inlineSidebar = _hasInlineSidebar;
    return Row(
      children: [
        if (inlineSidebar && _sidebarOpen)
          SizedBox(width: 312, child: _buildSidebarSurface()),
        Expanded(
          child: Column(
            children: [
              _buildControlBar(isWeb: true),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: _buildViewerSurface(isWeb: true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_webViewerUrl != null) {
      return _MobilePdfWebViewer(url: _webViewerUrl!, title: widget.title);
    }

    return Column(
      children: [
        _buildControlBar(isWeb: false),
        Expanded(child: _buildViewerSurface(isWeb: false)),
        _bookmarksBar(),
      ],
    );
  }

  Widget _buildViewerSurface({required bool isWeb}) {
    final viewer = _buildViewer();
    if (!isWeb) return viewer;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E8EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: viewer),
    );
  }

  Widget _buildViewer() {
    if (_bytes == null) return _errorView();
    final isWeb = kIsWeb;
    final isMobile = !kIsWeb;

    return SfPdfViewer.memory(
      _bytes!,
      key: _pdfKey,
      controller: _controller,
      canShowScrollHead: !kIsWeb,
      canShowScrollStatus: !kIsWeb,
      enableTextSelection: isWeb,
      canShowPaginationDialog: false,
      maxZoomLevel: _maxZoomLevel,
      pageLayoutMode: PdfPageLayoutMode.continuous,
      scrollDirection: PdfScrollDirection.vertical,
      interactionMode: isMobile
          ? PdfInteractionMode.pan
          : PdfInteractionMode.selection,
      enableDoubleTapZooming: true,
      onTap: _handleViewerTap,
      onZoomLevelChanged: (details) {
        if (!mounted) return;
        setState(() => _zoom = details.newZoomLevel);
      },
      onDocumentLoadFailed: (details) async {
        final errorText = details.error;
        if (mounted) {
          setState(
            () => _error = errorText.isNotEmpty ? errorText : "PDF yüklenemedi",
          );
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
        if (!mounted) return;
        setState(() {
          _syncPageJumpField(details.newPageNumber);
        });
        _persistState(page: details.newPageNumber);
      },
      onDocumentLoaded: (details) {
        if (!mounted) return;
        final totalPages = details.document.pages.count;
        final targetPage = _clampPage(_lastSavedPage ?? 1, totalPages);
        final initialZoom = _zoom.clamp(_minZoomLevel, _maxZoomLevel);
        setState(() {
          _zoom = initialZoom;
          _syncPageJumpField(targetPage);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _controller.zoomLevel = initialZoom;
          if (targetPage > 1) {
            _controller.jumpToPage(targetPage);
          }
          _restoreStickyNotesToViewer();
          if (_searchController.text.trim().isNotEmpty) {
            _runSearch();
          }
        });
      },
      onAnnotationEdited: _handleAnnotationEdited,
      onAnnotationRemoved: _handleAnnotationRemoved,
    );
  }

  Widget _buildControlBar({required bool isWeb}) {
    final page = _currentPage;
    final totalPages = _totalPages;
    final noteCount = _noteEntries.length;
    final progress = totalPages > 0 ? ((page / totalPages) * 100).round() : 0;
    final summaryWidgets = <Widget>[
      _infoChip(
        icon: Icons.auto_stories_rounded,
        label: "Sayfa $page / ${totalPages > 0 ? totalPages : "-"}",
      ),
      _infoChip(icon: Icons.insights_outlined, label: "%$progress okundu"),
      _infoChip(
        icon: Icons.bookmarks_outlined,
        label: "${_bookmarks.length} ayraç",
      ),
      _infoChip(icon: Icons.sticky_note_2_outlined, label: "$noteCount not"),
      if (_hasSearchResult)
        _infoChip(
          icon: Icons.find_in_page_outlined,
          label:
              "${_searchResult!.currentInstanceIndex}/${_searchResult!.totalInstanceCount} eşleşme",
        ),
      if (_pendingNoteDraft != null)
        ActionChip(
          avatar: const Icon(Icons.touch_app_outlined, size: 18),
          label: const Text(
            "Notu bırakmak için sayfa üzerinde bir noktaya tıklayın",
          ),
          onPressed: _cancelPendingNotePlacement,
        ),
    ];

    return Material(
      color: Colors.white,
      elevation: isWeb ? 0 : 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isWeb ? const Color(0xFFE4E8EE) : const Color(0xFFE0E0E0),
            ),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _withHorizontalSpacing([
              _toolbarGroup(
                children: [
                  _toolbarIconButton(
                    icon: Icons.first_page,
                    tooltip: "İlk sayfa",
                    onPressed: totalPages > 0 ? () => _jumpToPage(1) : null,
                  ),
                  _toolbarIconButton(
                    icon: Icons.chevron_left,
                    tooltip: "Önceki sayfa",
                    onPressed: _canGoPrevious
                        ? () => _controller.previousPage()
                        : null,
                  ),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _pageJumpController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _jumpToTypedPage(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "/ ${totalPages > 0 ? totalPages : "-"}",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _toolbarIconButton(
                    icon: Icons.chevron_right,
                    tooltip: "Sonraki sayfa",
                    onPressed: _canGoNext ? () => _controller.nextPage() : null,
                  ),
                  _toolbarIconButton(
                    icon: Icons.last_page,
                    tooltip: "Son sayfa",
                    onPressed: totalPages > 0
                        ? () => _jumpToPage(totalPages)
                        : null,
                  ),
                ],
              ),
              _toolbarGroup(
                children: [
                  _toolbarIconButton(
                    icon: Icons.remove,
                    tooltip: "Uzaklaştır",
                    onPressed: () => _setZoom(_zoom - 0.2),
                  ),
                  SizedBox(
                    width: isWeb ? 150 : 120,
                    child: Slider(
                      min: _minZoomLevel,
                      max: _maxZoomLevel,
                      divisions: 20,
                      value: _zoom.clamp(_minZoomLevel, _maxZoomLevel),
                      label: "${(_zoom * 100).round()}%",
                      onChanged: _setZoom,
                    ),
                  ),
                  _toolbarIconButton(
                    icon: Icons.add,
                    tooltip: "Yakınlaştır",
                    onPressed: () => _setZoom(_zoom + 0.2),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => _setZoom(_defaultZoomLevel),
                    child: Text("${(_zoom * 100).round()}%"),
                  ),
                ],
              ),
              _toolbarGroup(
                children: [
                  TextButton.icon(
                    onPressed: _toggleCurrentBookmark,
                    icon: Icon(
                      _bookmarks.contains(page)
                          ? Icons.bookmark
                          : Icons.bookmark_add_outlined,
                    ),
                    label: const Text("Ayraç"),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: _pendingNoteDraft == null
                        ? _startNotePlacement
                        : _cancelPendingNotePlacement,
                    icon: Icon(
                      _pendingNoteDraft == null
                          ? Icons.sticky_note_2_outlined
                          : Icons.close,
                    ),
                    label: Text(
                      _pendingNoteDraft == null ? "Not Bırak" : "İptal",
                    ),
                  ),
                  if (isWeb) ...[
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () => _openToolsPanel(context),
                      icon: const Icon(Icons.search),
                      label: const Text("Araçlar"),
                    ),
                  ],
                ],
              ),
              ...summaryWidgets,
            ]),
          ),
        ),
      ),
    );
  }

  Widget _toolbarGroup({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _toolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }

  Widget _infoChip({required IconData icon, required String label}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF526071)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _withHorizontalSpacing(List<Widget> children, {double gap = 8}) {
    if (children.isEmpty) return const [];
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(SizedBox(width: gap));
      }
      items.add(children[i]);
    }
    return items;
  }

  Widget _buildSidebarSurface() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE4E8EE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "PDF Araçları",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_hasInlineSidebar)
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: "Paneli daralt",
                    onPressed: () => setState(() => _sidebarOpen = false),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _sidebarTabChip(
                  label: "Ayraçlar",
                  tab: _PdfSidebarTab.bookmarks,
                ),
                const SizedBox(width: 8),
                _sidebarTabChip(label: "Notlar", tab: _PdfSidebarTab.notes),
                const SizedBox(width: 8),
                _sidebarTabChip(label: "Arama", tab: _PdfSidebarTab.search),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _buildSidebarTabBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarTabChip({required String label, required _PdfSidebarTab tab}) {
    final selected = _sidebarTab == tab;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: selected,
        onSelected: (_) => setState(() => _sidebarTab = tab),
      ),
    );
  }

  Widget _buildSidebarTabBody() {
    if (_sidebarTab == _PdfSidebarTab.notes) {
      return _buildNotesPanel();
    }
    if (_sidebarTab == _PdfSidebarTab.search) {
      return _buildSearchPanel();
    }
    return _buildBookmarksPanel();
  }

  Widget _buildBookmarksPanel() {
    final bookmarks = _sortedBookmarks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.tonalIcon(
          onPressed: _toggleCurrentBookmark,
          icon: Icon(
            _bookmarks.contains(_currentPage)
                ? Icons.bookmark_remove_outlined
                : Icons.bookmark_add_outlined,
          ),
          label: Text(
            _bookmarks.contains(_currentPage)
                ? "Mevcut Sayfayı Çıkar"
                : "Mevcut Sayfayı Kaydet",
          ),
        ),
        const SizedBox(height: 12),
        if (bookmarks.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                "Henüz ayraç yok.\nOkurken önemli sayfaları kaydedebilirsin.",
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: bookmarks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final page = bookmarks[index];
                final summary = _pageNoteSummary(page);
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.bookmark)),
                    title: Text("Sayfa $page"),
                    subtitle: summary == null ? null : Text(summary),
                    onTap: () => _jumpToPage(page),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: "Sil",
                      onPressed: () => _removeBookmark(page),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNotesPanel() {
    final notes = _sortedNotes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _startNotePlacement,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text("Sayfaya Not Bırak"),
              ),
            ),
            if (_pendingNoteDraft != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: "İptal",
                onPressed: _cancelPendingNotePlacement,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_pendingNoteDraft != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD977)),
            ),
            child: Text(
              "Not hazır. Yerleştirmek için PDF üzerinde uygun noktaya tıkla.",
            ),
          ),
        if (_pendingNoteDraft != null) const SizedBox(height: 12),
        if (notes.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                "Henüz not yok.\nBir not bırakıp PDF üzerinde işaretleyebilirsin.",
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final note = notes[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(_stickyNoteIconData(note.icon), size: 18),
                    ),
                    title: Text("Sayfa ${note.pageNumber}"),
                    subtitle: Text(
                      note.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _focusNote(note),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == "edit") {
                          _editNote(note);
                        } else if (value == "delete") {
                          _removeNote(note);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: "edit", child: Text("Düzenle")),
                        PopupMenuItem(value: "delete", child: Text("Sil")),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchPanel() {
    final result = _searchResult;
    final searchText = _searchController.text.trim();
    String statusText = "Kelime veya ifade ara";
    if (searchText.isNotEmpty && result != null) {
      if (result.hasResult) {
        statusText =
            "${result.currentInstanceIndex}/${result.totalInstanceCount} eşleşme bulundu";
      } else if (result.isSearchCompleted || kIsWeb) {
        statusText = "Sonuç bulunamadı";
      } else {
        statusText = "Aranıyor...";
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: "PDF içinde ara",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchText.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  ),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _runSearch(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _runSearch,
                icon: const Icon(Icons.search),
                label: const Text("Ara"),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.navigate_before),
              tooltip: "Önceki sonuç",
              onPressed: _hasSearchResult
                  ? () => _searchResult?.previousInstance()
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.navigate_next),
              tooltip: "Sonraki sonuç",
              onPressed: _hasSearchResult
                  ? () => _searchResult?.nextInstance()
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E8EF)),
          ),
          child: Text(statusText),
        ),
      ],
    );
  }

  Widget _bookmarksBar() {
    if (_bookmarks.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: _sortedBookmarks
            .map(
              (page) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: InputChip(
                  avatar: const Icon(Icons.bookmark, size: 16),
                  label: Text("Sayfa $page"),
                  onPressed: () => _jumpToPage(page),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeBookmark(page),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _openToolsPanel(BuildContext context) async {
    if (_hasInlineSidebar) {
      setState(() => _sidebarOpen = !_sidebarOpen);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: _buildSidebarSurface(),
        ),
      ),
    );
  }

  void _toggleCurrentBookmark() {
    final page = _currentPage;
    if (page <= 0 || _totalPages <= 0) return;
    final added = !_bookmarks.contains(page);
    setState(() {
      if (added) {
        _bookmarks.add(page);
      } else {
        _bookmarks.remove(page);
      }
    });
    _persistState();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? "Sayfa $page ayraca eklendi"
              : "Sayfa $page ayraçtan çıkarıldı",
        ),
      ),
    );
  }

  void _removeBookmark(int page) {
    setState(() => _bookmarks.remove(page));
    _persistState();
  }

  void _jumpToTypedPage() {
    final typedPage = int.tryParse(_pageJumpController.text.trim());
    if (typedPage == null || _totalPages <= 0) {
      _syncPageJumpField();
      return;
    }
    final target = _clampPage(typedPage, _totalPages);
    _jumpToPage(target);
  }

  void _jumpToPage(int page) {
    if (_totalPages <= 0) return;
    final target = _clampPage(page, _totalPages);
    _controller.jumpToPage(target);
    _syncPageJumpField(target);
  }

  int _clampPage(int page, int maxPage) {
    if (page < 1) return 1;
    if (page > maxPage) return maxPage;
    return page;
  }

  void _syncPageJumpField([int? page]) {
    final current = page ?? _currentPage;
    final text = current.toString();
    if (_pageJumpController.text == text) return;
    _pageJumpController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _setZoom(double value) {
    final nextZoom = value.clamp(_minZoomLevel, _maxZoomLevel);
    setState(() => _zoom = nextZoom);
    _controller.zoomLevel = nextZoom;
  }

  void _bindSearchResult(PdfTextSearchResult result) {
    if (identical(_searchResult, result)) return;
    _searchResult?.removeListener(_handleSearchResultChanged);
    _searchResult = result;
    _searchResult?.addListener(_handleSearchResultChanged);
  }

  void _handleSearchResultChanged() {
    if (mounted) setState(() {});
  }

  void _runSearch() {
    if (!kIsWeb) {
      return;
    }
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    final result = _controller.searchText(query);
    _bindSearchResult(result);
    setState(() {
      _sidebarTab = _PdfSidebarTab.search;
      _sidebarOpen = true;
    });
  }

  void _clearSearch() {
    _searchResult?.clear();
    _searchController.clear();
    setState(() {});
  }

  Future<void> _startNotePlacement() async {
    final draft = await _showNoteComposer();
    if (!mounted || draft == null) return;
    setState(() {
      _pendingNoteDraft = draft;
      _sidebarTab = _PdfSidebarTab.notes;
      _sidebarOpen = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Notu bırakmak istediğin noktaya PDF üzerinde tıkla."),
      ),
    );
  }

  void _cancelPendingNotePlacement() {
    if (_pendingNoteDraft == null) return;
    setState(() => _pendingNoteDraft = null);
  }

  Future<_PendingNoteDraft?> _showNoteComposer({
    _PdfStickyNoteEntry? existing,
  }) async {
    final controller = TextEditingController(text: existing?.text ?? "");
    PdfStickyNoteIcon selectedIcon =
        existing?.icon ?? PdfStickyNoteIcon.comment;
    final result = await showDialog<_PendingNoteDraft>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text(existing == null ? "Not Hazırla" : "Notu Düzenle"),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: "Not",
                      hintText: "Bu sayfa için kısa bir not yaz",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PdfStickyNoteIcon>(
                    initialValue: selectedIcon,
                    decoration: const InputDecoration(
                      labelText: "İkon",
                      border: OutlineInputBorder(),
                    ),
                    items: PdfStickyNoteIcon.values
                        .map(
                          (icon) => DropdownMenuItem(
                            value: icon,
                            child: Text(_stickyNoteIconLabel(icon)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => selectedIcon = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal"),
              ),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(
                    context,
                    _PendingNoteDraft(text: text, icon: selectedIcon),
                  );
                },
                child: Text(existing == null ? "Hazırla" : "Kaydet"),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result;
  }

  void _handleViewerTap(PdfGestureDetails details) {
    final draft = _pendingNoteDraft;
    if (draft == null) return;
    if (details.pageNumber <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notu sayfa üzerinde bir yere bırak.")),
      );
      return;
    }

    final entry = _PdfStickyNoteEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pageNumber: details.pageNumber,
      text: draft.text,
      offsetX: details.pagePosition.dx,
      offsetY: details.pagePosition.dy,
      icon: draft.icon,
    );

    setState(() {
      _pendingNoteDraft = null;
      _sidebarTab = _PdfSidebarTab.notes;
    });
    _upsertNoteEntry(entry, addToViewer: true);
  }

  void _restoreStickyNotesToViewer() {
    for (final annotation in _noteAnnotations.values.toList()) {
      _controller.removeAnnotation(annotation);
    }
    _noteAnnotations.clear();
    for (final entry in _noteEntries) {
      final annotation = _annotationFromEntry(entry);
      _noteAnnotations[entry.id] = annotation;
      _controller.addAnnotation(annotation);
    }
  }

  StickyNoteAnnotation _annotationFromEntry(_PdfStickyNoteEntry entry) {
    final annotation =
        StickyNoteAnnotation(
            pageNumber: entry.pageNumber,
            text: entry.text,
            position: Offset(entry.offsetX, entry.offsetY),
            icon: entry.icon,
          )
          ..name = entry.id
          ..author = "Yeni Asya"
          ..subject = "reader-note"
          ..color = const Color(0xFFFFC44D)
          ..opacity = 1;
    return annotation;
  }

  void _upsertNoteEntry(
    _PdfStickyNoteEntry entry, {
    required bool addToViewer,
  }) {
    final existingIndex = _noteEntries.indexWhere(
      (item) => item.id == entry.id,
    );
    final existingAnnotation = _noteAnnotations.remove(entry.id);
    if (existingAnnotation != null) {
      _controller.removeAnnotation(existingAnnotation);
    }

    setState(() {
      if (existingIndex >= 0) {
        _noteEntries[existingIndex] = entry;
      } else {
        _noteEntries.add(entry);
      }
      _bookmarks.add(entry.pageNumber);
    });

    if (addToViewer) {
      final annotation = _annotationFromEntry(entry);
      _noteAnnotations[entry.id] = annotation;
      _controller.addAnnotation(annotation);
    }

    _persistState();
  }

  void _handleAnnotationEdited(Annotation annotation) {
    if (annotation is! StickyNoteAnnotation) return;
    final id = annotation.name;
    if (id == null || id.isEmpty) return;
    final index = _noteEntries.indexWhere((item) => item.id == id);
    if (index < 0) return;

    final updated = _noteEntries[index].copyWith(
      pageNumber: annotation.pageNumber,
      text: annotation.text,
      offsetX: annotation.position.dx,
      offsetY: annotation.position.dy,
      icon: annotation.icon,
    );

    setState(() {
      _noteEntries[index] = updated;
      _bookmarks.add(updated.pageNumber);
      _noteAnnotations[id] = annotation;
    });
    _persistState();
  }

  void _handleAnnotationRemoved(Annotation annotation) {
    if (annotation is! StickyNoteAnnotation) return;
    final id = annotation.name;
    if (id == null || id.isEmpty) return;

    setState(() {
      _noteEntries.removeWhere((item) => item.id == id);
      _noteAnnotations.remove(id);
    });
    _persistState();
  }

  Future<void> _editNote(_PdfStickyNoteEntry entry) async {
    final draft = await _showNoteComposer(existing: entry);
    if (!mounted || draft == null) return;
    final updated = entry.copyWith(text: draft.text, icon: draft.icon);
    _upsertNoteEntry(updated, addToViewer: true);
  }

  void _removeNote(_PdfStickyNoteEntry entry) {
    final annotation = _noteAnnotations.remove(entry.id);
    if (annotation != null) {
      _controller.removeAnnotation(annotation);
    }
    setState(() => _noteEntries.removeWhere((item) => item.id == entry.id));
    _persistState();
  }

  void _focusNote(_PdfStickyNoteEntry entry) {
    _jumpToPage(entry.pageNumber);
    final annotation = _noteAnnotations[entry.id];
    if (annotation == null) return;
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _controller.selectAnnotation(annotation);
    });
  }

  String? _pageNoteSummary(int page) {
    final pageNotes = _noteEntries
        .where((item) => item.pageNumber == page)
        .toList();
    if (pageNotes.isEmpty) return null;
    if (pageNotes.length == 1) return pageNotes.first.text;
    return "${pageNotes.length} not";
  }

  String get _storageKey {
    final parsed = Uri.tryParse(widget.url);
    final name = parsed?.pathSegments.isNotEmpty == true
        ? parsed!.pathSegments.last
        : widget.url;
    return "pdf_state::$name";
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedBookmarks = (data["bookmarks"] as List?)
          ?.map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toSet();
      final savedPage = int.tryParse(data["page"]?.toString() ?? "");
      final savedNotes = _decodeNotes(data["notes"]);
      setState(() {
        _bookmarks
          ..clear()
          ..addAll(savedBookmarks ?? {});
        _noteEntries
          ..clear()
          ..addAll(savedNotes);
        _lastSavedPage = savedPage;
        _syncPageJumpField(savedPage ?? 1);
      });
    } catch (_) {
      // ignore invalid state
    }
  }

  List<_PdfStickyNoteEntry> _decodeNotes(Object? rawNotes) {
    final items = <_PdfStickyNoteEntry>[];
    if (rawNotes is List) {
      for (final entry in rawNotes) {
        if (entry is! Map) continue;
        items.add(
          _PdfStickyNoteEntry.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
      return items;
    }

    if (rawNotes is Map) {
      final legacyNotes = Map<String, dynamic>.from(rawNotes);
      legacyNotes.forEach((key, value) {
        final page = int.tryParse(key);
        final text = value?.toString().trim() ?? "";
        if (page == null || page <= 0 || text.isEmpty) return;
        items.add(
          _PdfStickyNoteEntry(
            id: "legacy-$page",
            pageNumber: page,
            text: text,
            offsetX: 24,
            offsetY: 24,
            icon: PdfStickyNoteIcon.note,
          ),
        );
      });
    }
    return items;
  }

  Future<void> _persistState({int? page}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      "page": page ?? _currentPage,
      "bookmarks": _sortedBookmarks,
      "notes": _sortedNotes.map((item) => item.toJson()).toList(),
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  String _stickyNoteIconLabel(PdfStickyNoteIcon icon) {
    switch (icon) {
      case PdfStickyNoteIcon.comment:
        return "Yorum";
      case PdfStickyNoteIcon.key:
        return "Anahtar";
      case PdfStickyNoteIcon.note:
        return "Not";
      case PdfStickyNoteIcon.help:
        return "Yardım";
      case PdfStickyNoteIcon.newParagraph:
        return "Yeni Paragraf";
      case PdfStickyNoteIcon.paragraph:
        return "Paragraf";
      case PdfStickyNoteIcon.insert:
        return "Ekle";
    }
  }

  IconData _stickyNoteIconData(PdfStickyNoteIcon icon) {
    switch (icon) {
      case PdfStickyNoteIcon.comment:
        return Icons.mode_comment_outlined;
      case PdfStickyNoteIcon.key:
        return Icons.key_outlined;
      case PdfStickyNoteIcon.note:
        return Icons.sticky_note_2_outlined;
      case PdfStickyNoteIcon.help:
        return Icons.help_outline;
      case PdfStickyNoteIcon.newParagraph:
        return Icons.notes_outlined;
      case PdfStickyNoteIcon.paragraph:
        return Icons.subject_outlined;
      case PdfStickyNoteIcon.insert:
        return Icons.add_box_outlined;
    }
  }
}

class _MobilePdfWebViewer extends StatefulWidget {
  const _MobilePdfWebViewer({required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<_MobilePdfWebViewer> createState() => _MobilePdfWebViewerState();
}

class _MobilePdfWebViewerState extends State<_MobilePdfWebViewer> {
  static final Set<Factory<OneSequenceGestureRecognizer>>
  _webViewGestureRecognizers = {
    Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  static const String _pdfJsMobileViewportBridge = '''
(() => {
  if (window.__yeniasyaPdfMobileViewportInstalled) return;
  window.__yeniasyaPdfMobileViewportInstalled = true;

  const MIN_VISUAL_SCALE = 0.05;
  const MAX_VISUAL_SCALE = 20;
  const loosenPdfJsScaleLimits = () => {
    const app = window.PDFViewerApplication;
    const options = window.PDFViewerApplicationOptions;
    try {
      if (options?.set) {
        options.set('minScale', MIN_VISUAL_SCALE);
        options.set('maxScale', MAX_VISUAL_SCALE);
      }
    } catch (_) {}
    try {
      if (app?.pdfViewer) {
        app.pdfViewer.minScale = MIN_VISUAL_SCALE;
        app.pdfViewer.maxScale = MAX_VISUAL_SCALE;
      }
      if (app?.pdfViewer?._uiUtils) {
        app.pdfViewer._uiUtils.MIN_SCALE = MIN_VISUAL_SCALE;
        app.pdfViewer._uiUtils.MAX_SCALE = MAX_VISUAL_SCALE;
      }
    } catch (_) {}
    try {
      window.PDFViewerApplicationConstants =
        window.PDFViewerApplicationConstants || {};
      window.PDFViewerApplicationConstants.MIN_SCALE = MIN_VISUAL_SCALE;
      window.PDFViewerApplicationConstants.MAX_SCALE = MAX_VISUAL_SCALE;
    } catch (_) {}
  };
  const setTouchPolicy = () => {
    let viewport = document.querySelector('meta[name="viewport"]');
    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.name = 'viewport';
      document.head.appendChild(viewport);
    }
    viewport.setAttribute(
      'content',
      'width=device-width, initial-scale=1, minimum-scale=0.05, maximum-scale=20, user-scalable=yes, viewport-fit=cover'
    );
    document.documentElement.style.webkitTextSizeAdjust = '100%';
    document.documentElement.style.touchAction = 'auto';
    document.body.style.touchAction = 'auto';
    ['viewerContainer', 'viewer', 'outerContainer'].forEach((id) => {
      const element = document.getElementById(id);
      if (element) element.style.touchAction = 'auto';
    });
    loosenPdfJsScaleLimits();
  };

  setTouchPolicy();
  setTimeout(setTouchPolicy, 500);
  setTimeout(setTouchPolicy, 1500);
  setTimeout(setTouchPolicy, 3000);
  document.addEventListener('webviewerloaded', setTouchPolicy, {
    capture: true,
  });
  document.addEventListener('pagesinit', setTouchPolicy, {
    capture: true,
  });
  document.addEventListener('scalechanging', loosenPdfJsScaleLimits, {
    capture: true,
  });
})();
''';

  InAppWebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _installPdfJsMobileViewportBridge() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.evaluateJavascript(source: _pdfJsMobileViewportBridge);
    } catch (_) {
      // The viewer can navigate during reload; the next page finish retries setup.
    }
  }

  void _schedulePdfJsMobileViewportBridgeInstall() {
    unawaited(_installPdfJsMobileViewportBridge());
    for (final delay in const [
      Duration(milliseconds: 250),
      Duration(milliseconds: 750),
      Duration(milliseconds: 1500),
      Duration(milliseconds: 3000),
    ]) {
      unawaited(Future<void>.delayed(delay, _installPdfJsMobileViewportBridge));
    }
  }

  @override
  void didUpdateWidget(covariant _MobilePdfWebViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              javaScriptCanOpenWindowsAutomatically: false,
              domStorageEnabled: true,
              databaseEnabled: true,
              cacheEnabled: true,
              supportZoom: true,
              builtInZoomControls: false,
              displayZoomControls: false,
              useWideViewPort: true,
              loadWithOverviewMode: false,
              enableViewportScale: true,
              ignoresViewportScaleLimits: true,
              minimumZoomScale: 0.05,
              maximumZoomScale: 20,
              disallowOverScroll: false,
              disableHorizontalScroll: false,
              disableVerticalScroll: false,
              transparentBackground: false,
              allowsInlineMediaPlayback: true,
              mediaPlaybackRequiresUserGesture: false,
            ),
            gestureRecognizers: _webViewGestureRecognizers,
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            onLoadStart: (_, __) {
              if (!mounted) return;
              setState(() {
                _loading = true;
                _error = null;
              });
            },
            onLoadStop: (_, __) {
              if (!mounted) return;
              setState(() => _loading = false);
              _schedulePdfJsMobileViewportBridgeInstall();
            },
            onReceivedError: (_, request, error) {
              if (!mounted || request.isForMainFrame != true) return;
              setState(() {
                _loading = false;
                _error = error.description;
              });
            },
          ),
        ),
        if (_error != null)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "PDF görüntüleyici açılmadı",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _controller?.loadUrl(
                            urlRequest: URLRequest(url: WebUri(widget.url)),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Tekrar dene"),
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
              color: Color(0x22000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

enum _PdfSidebarTab { bookmarks, notes, search }

class _PendingNoteDraft {
  const _PendingNoteDraft({required this.text, required this.icon});

  final String text;
  final PdfStickyNoteIcon icon;
}

class _PdfStickyNoteEntry {
  const _PdfStickyNoteEntry({
    required this.id,
    required this.pageNumber,
    required this.text,
    required this.offsetX,
    required this.offsetY,
    required this.icon,
  });

  final String id;
  final int pageNumber;
  final String text;
  final double offsetX;
  final double offsetY;
  final PdfStickyNoteIcon icon;

  _PdfStickyNoteEntry copyWith({
    String? id,
    int? pageNumber,
    String? text,
    double? offsetX,
    double? offsetY,
    PdfStickyNoteIcon? icon,
  }) {
    return _PdfStickyNoteEntry(
      id: id ?? this.id,
      pageNumber: pageNumber ?? this.pageNumber,
      text: text ?? this.text,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "pageNumber": pageNumber,
      "text": text,
      "offsetX": offsetX,
      "offsetY": offsetY,
      "icon": icon.name,
    };
  }

  factory _PdfStickyNoteEntry.fromJson(Map<String, dynamic> json) {
    final iconName = json["icon"]?.toString() ?? PdfStickyNoteIcon.comment.name;
    final icon = PdfStickyNoteIcon.values.firstWhere(
      (value) => value.name == iconName,
      orElse: () => PdfStickyNoteIcon.comment,
    );
    return _PdfStickyNoteEntry(
      id:
          json["id"]?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      pageNumber: int.tryParse(json["pageNumber"]?.toString() ?? "") ?? 1,
      text: json["text"]?.toString() ?? "",
      offsetX: double.tryParse(json["offsetX"]?.toString() ?? "") ?? 24,
      offsetY: double.tryParse(json["offsetY"]?.toString() ?? "") ?? 24,
      icon: icon,
    );
  }
}
