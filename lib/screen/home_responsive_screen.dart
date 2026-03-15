import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/access_provider.dart';
import '/screen/footer/faq_page.dart';
import '/screen/footer/yeni_asya_footer.dart';
import '/services/auth/auth_provider.dart';
import '/services/auth/auth_api_service.dart';
import '/screen/login/login_screen.dart';
import '/screen/profile/profile_screen.dart';
import '/utils/route_guard.dart';
import '/screen/cart/cart_screen.dart';
import '/screen/order/order_detail_screen.dart';
import '../services/admin/admin_magazine_service.dart';
import '../services/admin/admin_book_service.dart';
import '../services/ek_service.dart';
import '../services/cart/cart_provider.dart';
import '../models/cart_item.dart';
import '../services/order_service.dart';
import '../services/user_content_access_service.dart';
import '../services/revenuecat_service.dart';
import '../services/app_feature_flags_service.dart';
import '../services/upload_service.dart';
import '../services/home_bootstrap_service.dart';
import '../services/newspaper_subscription_type_service.dart';
import '../services/logging_service.dart';
import '../screen/profile/pdf_viewer_screen.dart';
import '../utils/cart_feedback.dart';
import '../utils/price_utils.dart';
import '../utils/pdf_open_helper.dart';
import 'search/search_screen.dart';
import 'product/product_detail_screen.dart';
import '../utils/safe_image.dart';
import '../utils/ek_normalizer.dart';
import 'attachment/ek_detail_screen.dart';
import 'slider/slider_detail_screen.dart';
import 'slider/slider_webview_screen.dart';
import 'contact/contact_form.dart';
import 'login/email_verification_screen.dart';
import 'login/password_reset_screen.dart';
import 'checkout/payment_web_return_screen.dart';
import 'splash/splash_screen.dart';

enum HomeSection { home, magazines, books, newspapers, attachments }

class _HomeLoadBundle {
  final List<Map<String, dynamic>> sliders;
  final List<Map<String, dynamic>> magazines;
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> newspapers;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> homeBookEntries;
  final List<Map<String, dynamic>> homeMagazineEntries;
  final Map<String, String> failedSources;

  const _HomeLoadBundle({
    required this.sliders,
    required this.magazines,
    required this.books,
    required this.newspapers,
    required this.attachments,
    required this.homeBookEntries,
    required this.homeMagazineEntries,
    required this.failedSources,
  });
}

class HomeResponsiveScreen extends StatefulWidget {
  final Uri? initialUri;

  const HomeResponsiveScreen({super.key, this.initialUri});

  @override
  State<HomeResponsiveScreen> createState() => _HomeResponsiveScreenState();
}

class _HomeResponsiveScreenState extends State<HomeResponsiveScreen> {
  HomeSection _section = HomeSection.home;

  final AdminMagazineService _magService = AdminMagazineService();
  final AdminBookService _bookService = AdminBookService();
  final EkService _ekService = EkService();
  final AuthApiService _authApi = AuthApiService();
  final OrderService _orderService = OrderService();
  final UserContentAccessService _accessService = UserContentAccessService();
  final HomeBootstrapService _homeBootstrapService = HomeBootstrapService();
  final NewspaperSubscriptionTypeService _newspaperTypePriceService =
      NewspaperSubscriptionTypeService();
  final AppFeatureFlagsService _appFeatureFlagsService =
      AppFeatureFlagsService();
  final LoggingService _loggingService = LoggingService();

  final PageController _sliderController = PageController();
  Timer? _sliderTimer;
  Timer? _libraryWarmupTimer;
  int _sliderIndex = 0;

  List<Map<String, dynamic>> sliders = [];
  List<Map<String, dynamic>> magazines = [];
  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> newspapers = [];
  List<Map<String, dynamic>> attachments = [];
  List<Map<String, dynamic>> homeBookEntries = [];
  List<Map<String, dynamic>> homeMagazineEntries = [];
  bool loading = true;
  int _mobileNavIndex = 0;
  bool libraryLoading = false;
  List<Map<String, dynamic>> libraryOrders = [];
  bool libraryAccessLoading = false;
  List<Map<String, dynamic>> libraryAccess = [];
  bool _loadingAccessSheet = false;
  bool _loadingLibraryMagazineIssues = false;
  bool _libraryMagazineIssuesSheetOpen = false;
  bool _deepLinkHandled = false;
  bool _standaloneRouteHandled = false;
  bool _hideMagazines = false;
  bool _hideNewspapers = false;
  bool _homeLoadFailed = false;
  AuthProvider? _authListener;
  DateTime? _newsSelectedDate;

  int _showcaseItemLimit(bool isWeb) => isWeb ? 10 : 6;

  DateTime get _newspaperPickerInitialDate =>
      _normalizeDate(_newsSelectedDate ?? DateTime.now());

  String get _newspaperSelectedDateLabel => _newsSelectedDate == null
      ? "Tarih Seç"
      : _formatDateShort(_newsSelectedDate!);

  void _setNewspaperSelectedDate(DateTime? date) {
    final normalized = date == null ? null : _normalizeDate(date);
    if (!mounted) {
      _newsSelectedDate = normalized;
      return;
    }
    setState(() => _newsSelectedDate = normalized);
  }

  void _openSectionFromFooter(String label) {
    final section = switch (label) {
      "E-Dergiler" => HomeSection.magazines,
      "E-Kitaplar" => HomeSection.books,
      "E-Gazete" => HomeSection.newspapers,
      "E-Ekler" => HomeSection.attachments,
      _ => null,
    };
    if (section == null) return;
    if (section == HomeSection.magazines && _hideMagazines) return;
    if (section == HomeSection.newspapers && _hideNewspapers) return;
    setState(() => _section = section);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadData());
      _authListener = context.read<AuthProvider>();
      _authListener?.addListener(_onAuthChange);
      _loadAccessIfNeeded();
      _scheduleDeferredLibraryWarmup();
    });
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => loading = true);
    }

    final visibilityFuture = _loadVisibilitySafely();
    unawaited(_applyVisibilityWhenReady(visibilityFuture));
    final cachedBootstrap = await _homeBootstrapService.readCachedPayload();

    if (showLoading && cachedBootstrap != null && mounted) {
      _applyHomeData(
        slidersData: cachedBootstrap.sliders,
        magazinesData: cachedBootstrap.magazines,
        booksData: cachedBootstrap.books,
        newspapersData: cachedBootstrap.newspapers,
        attachmentsData: cachedBootstrap.attachments,
        homeBooksData: cachedBootstrap.homeBookEntries,
        homeMagazinesData: cachedBootstrap.homeMagazineEntries,
        visibility: _currentVisibilitySnapshot(),
        homeLoadFailed: false,
      );
      _startSliderAuto();
      unawaited(_handleInitialDeepLink());
      setState(() => loading = false);
    }

    try {
      final bootstrap = await _homeBootstrapService.fetch();
      if (!mounted) return;
      _applyHomeData(
        slidersData: bootstrap.sliders,
        magazinesData: bootstrap.magazines,
        booksData: bootstrap.books,
        newspapersData: bootstrap.newspapers,
        attachmentsData: bootstrap.attachments,
        homeBooksData: bootstrap.homeBookEntries,
        homeMagazinesData: bootstrap.homeMagazineEntries,
        visibility: _currentVisibilitySnapshot(),
        homeLoadFailed: false,
      );
      _startSliderAuto();
      await _handleInitialDeepLink();
    } catch (bootstrapError, bootstrapStack) {
      debugPrint("Home bootstrap error: $bootstrapError");
      _logHomeLoadFailure(
        operation: "loadData.bootstrap",
        error: bootstrapError,
        stackTrace: bootstrapStack,
      );

      final fallback = await _loadLegacyHomeData();
      if (!mounted) return;

      final resolvedSliders = _selectResolvedSectionData(
        fresh: fallback.sliders,
        current: sliders,
        failedSources: fallback.failedSources,
        key: "sliders",
      );
      final resolvedMagazines = _selectResolvedSectionData(
        fresh: fallback.magazines,
        current: magazines,
        failedSources: fallback.failedSources,
        key: "magazines",
      );
      final resolvedBooks = _selectResolvedSectionData(
        fresh: fallback.books,
        current: books,
        failedSources: fallback.failedSources,
        key: "books",
      );
      final resolvedNewspapers = _selectResolvedSectionData(
        fresh: fallback.newspapers,
        current: newspapers,
        failedSources: fallback.failedSources,
        key: "newspapers",
      );
      final resolvedAttachments = _selectResolvedSectionData(
        fresh: fallback.attachments,
        current: attachments,
        failedSources: fallback.failedSources,
        key: "attachments",
      );
      final resolvedHomeBooks = _selectResolvedSectionData(
        fresh: fallback.homeBookEntries,
        current: homeBookEntries,
        failedSources: fallback.failedSources,
        key: "homeBookEntries",
      );
      final resolvedHomeMagazines = _selectResolvedSectionData(
        fresh: fallback.homeMagazineEntries,
        current: homeMagazineEntries,
        failedSources: fallback.failedSources,
        key: "homeMagazineEntries",
      );

      final hasAnyContent = _hasAnyHomeContent(
        slidersData: resolvedSliders,
        magazinesData: resolvedMagazines,
        booksData: resolvedBooks,
        newspapersData: resolvedNewspapers,
        attachmentsData: resolvedAttachments,
        homeBooksData: resolvedHomeBooks,
        homeMagazinesData: resolvedHomeMagazines,
        hideMagazines: _hideMagazines,
        hideNewspapers: _hideNewspapers,
      );

      _applyHomeData(
        slidersData: resolvedSliders,
        magazinesData: resolvedMagazines,
        booksData: resolvedBooks,
        newspapersData: resolvedNewspapers,
        attachmentsData: resolvedAttachments,
        homeBooksData: resolvedHomeBooks,
        homeMagazinesData: resolvedHomeMagazines,
        visibility: _currentVisibilitySnapshot(),
        homeLoadFailed: fallback.failedSources.isNotEmpty && !hasAnyContent,
      );

      if (hasAnyContent) {
        unawaited(
          _homeBootstrapService.cachePayload(
            HomeBootstrapPayload(
              sliders: resolvedSliders,
              magazines: resolvedMagazines,
              books: resolvedBooks,
              newspapers: resolvedNewspapers,
              attachments: resolvedAttachments,
              homeBookEntries: resolvedHomeBooks,
              homeMagazineEntries: resolvedHomeMagazines,
            ),
          ),
        );
      }

      if (fallback.failedSources.isNotEmpty) {
        _logHomeLoadFailure(
          operation: "loadData.fallback",
          error: Exception("HOME_FALLBACK_PARTIAL_FAILURE"),
          payload: {
            "failedSources": fallback.failedSources,
            "hasAnyContent": hasAnyContent,
          },
        );
      }

      _startSliderAuto();
      await _handleInitialDeepLink();
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<AppFeatureVisibility> _loadVisibilitySafely() async {
    try {
      return await _appFeatureFlagsService.getVisibilityForCurrentApp();
    } catch (error, stackTrace) {
      debugPrint("App feature flags load error: $error");
      _logHomeLoadFailure(
        operation: "loadData.featureFlags",
        error: error,
        stackTrace: stackTrace,
      );
      return const AppFeatureVisibility();
    }
  }

  AppFeatureVisibility _currentVisibilitySnapshot() {
    return AppFeatureVisibility(
      hideMagazines: _hideMagazines,
      hideNewspapers: _hideNewspapers,
    );
  }

  Future<void> _applyVisibilityWhenReady(
    Future<AppFeatureVisibility> visibilityFuture,
  ) async {
    final visibility = await visibilityFuture;
    if (!mounted) return;
    setState(() {
      _hideMagazines = visibility.hideMagazines;
      _hideNewspapers = visibility.hideNewspapers;
      if ((_hideMagazines && _section == HomeSection.magazines) ||
          (_hideNewspapers && _section == HomeSection.newspapers)) {
        _section = HomeSection.home;
      }
    });
  }

  Future<_HomeLoadBundle> _loadLegacyHomeData() async {
    final failedSources = <String, String>{};

    Future<List<Map<String, dynamic>>> guardedList(
      String key,
      Future<List<Map<String, dynamic>>> Function() loader,
    ) async {
      try {
        return await loader();
      } catch (error, stackTrace) {
        debugPrint("Legacy home load error [$key]: $error");
        failedSources[key] = error.toString();
        _logHomeLoadFailure(
          operation: "loadData.legacy.$key",
          error: error,
          stackTrace: stackTrace,
        );
        return const <Map<String, dynamic>>[];
      }
    }

    final results = await Future.wait([
      guardedList("magazines", _homeBootstrapService.fetchMagazines),
      guardedList("books", _homeBootstrapService.fetchBooks),
      guardedList("newspapers", _homeBootstrapService.fetchNewspapers),
      guardedList("attachments", _homeBootstrapService.fetchAttachments),
      guardedList("sliders", _homeBootstrapService.fetchSliders),
      guardedList(
        "homeBookEntries",
        _homeBootstrapService.fetchHomeBookEntries,
      ),
      guardedList(
        "homeMagazineEntries",
        _homeBootstrapService.fetchHomeMagazineEntries,
      ),
    ]);

    return _HomeLoadBundle(
      magazines: results[0],
      books: results[1],
      newspapers: results[2],
      attachments: results[3],
      sliders: results[4],
      homeBookEntries: results[5],
      homeMagazineEntries: results[6],
      failedSources: failedSources,
    );
  }

  void _applyHomeData({
    required List<Map<String, dynamic>> slidersData,
    required List<Map<String, dynamic>> magazinesData,
    required List<Map<String, dynamic>> booksData,
    required List<Map<String, dynamic>> newspapersData,
    required List<Map<String, dynamic>> attachmentsData,
    required List<Map<String, dynamic>> homeBooksData,
    required List<Map<String, dynamic>> homeMagazinesData,
    required AppFeatureVisibility visibility,
    required bool homeLoadFailed,
  }) {
    if (!mounted) return;
    setState(() {
      sliders = slidersData;
      _sliderIndex = 0;
      magazines = magazinesData;
      books = booksData;
      newspapers = newspapersData;
      attachments = attachmentsData;
      homeBookEntries = homeBooksData;
      homeMagazineEntries = homeMagazinesData;
      _hideMagazines = visibility.hideMagazines;
      _hideNewspapers = visibility.hideNewspapers;
      _homeLoadFailed = homeLoadFailed;
      if ((_hideMagazines && _section == HomeSection.magazines) ||
          (_hideNewspapers && _section == HomeSection.newspapers)) {
        _section = HomeSection.home;
      }
    });
  }

  List<Map<String, dynamic>> _selectResolvedSectionData({
    required String key,
    required List<Map<String, dynamic>> fresh,
    required List<Map<String, dynamic>> current,
    required Map<String, String> failedSources,
  }) {
    if (failedSources.containsKey(key) && current.isNotEmpty) {
      return current;
    }
    return fresh;
  }

  bool _hasAnyHomeContent({
    required List<Map<String, dynamic>> slidersData,
    required List<Map<String, dynamic>> magazinesData,
    required List<Map<String, dynamic>> booksData,
    required List<Map<String, dynamic>> newspapersData,
    required List<Map<String, dynamic>> attachmentsData,
    required List<Map<String, dynamic>> homeBooksData,
    required List<Map<String, dynamic>> homeMagazinesData,
    required bool hideMagazines,
    required bool hideNewspapers,
  }) {
    final hasNewspaperShowcase = !hideNewspapers && newspapersData.isNotEmpty;
    final hasMagazineShowcase = !hideMagazines
        ? _buildHomeShowcaseList(
            baseItems: magazinesData,
            selectedEntries: homeMagazinesData,
            maxItems: 10,
            idKey: "id",
            selectedIdKey: "product_id",
          ).isNotEmpty
        : false;
    final hasBookShowcase = _buildHomeShowcaseList(
      baseItems: booksData,
      selectedEntries: homeBooksData,
      maxItems: 10,
      idKey: "id",
      selectedIdKey: "product_id",
    ).isNotEmpty;

    return slidersData.isNotEmpty ||
        hasNewspaperShowcase ||
        hasMagazineShowcase ||
        hasBookShowcase ||
        attachmentsData.isNotEmpty;
  }

  void _logHomeLoadFailure({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? payload,
  }) {
    unawaited(
      _loggingService.logError(
        service: "HomeResponsiveScreen",
        operation: operation,
        message: error.toString(),
        stackTrace: stackTrace?.toString(),
        payload: payload,
      ),
    );
  }

  Future<void> _refreshHome() async {
    await _loadData(showLoading: false);
    await _loadLibraryOrders();
    await _loadLibraryAccess();
    _loadAccessIfNeeded();
  }

  void _startSliderAuto() {
    _sliderTimer?.cancel();
    if (sliders.isEmpty) {
      _sliderIndex = 0;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _sliderController.hasClients) {
        _sliderController.jumpToPage(_sliderIndex);
      }
    });
    if (sliders.length <= 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sliderController.hasClients) return;
      _sliderTimer?.cancel();
      _sliderTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted || !_sliderController.hasClients) return;
        final nextIndex = (_sliderIndex + 1) % sliders.length;
        _sliderController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  Future<void> _loadLibraryOrders() async {
    setState(() => libraryLoading = true);
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) {
        if (mounted) {
          setState(() => libraryOrders = []);
        }
        return;
      }
      final orders = await _orderService.getOrdersWithItems(userId);
      if (mounted) {
        setState(() => libraryOrders = orders);
      }
    } catch (e) {
      debugPrint("Library load error: $e");
    } finally {
      if (mounted) {
        setState(() => libraryLoading = false);
      }
    }
  }

  void _onAuthChange() {
    final auth = _authListener;
    if (auth == null) return;
    if (auth.isLoggedIn) {
      _loadData();
      _loadAccessIfNeeded();
      if (_mobileNavIndex == 2) {
        _loadLibraryOrders();
        _loadLibraryAccess();
      } else {
        _scheduleDeferredLibraryWarmup();
      }
    } else {
      _resetAfterLogout();
    }
  }

  void _resetAfterLogout() {
    if (!mounted) return;
    setState(() {
      loading = true;
      _section = HomeSection.home;
      _mobileNavIndex = 0;
      libraryOrders = [];
      libraryAccess = [];
    });
    _loadData();
  }

  Future<void> _loadLibraryAccess() async {
    setState(() => libraryAccessLoading = true);
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        final entries = await _accessService.getAll(userId: userId);
        if (mounted) setState(() => libraryAccess = entries);
      } else {
        if (mounted) setState(() => libraryAccess = []);
      }
    } catch (e) {
      debugPrint("Library access load error: $e");
    }
    if (mounted) setState(() => libraryAccessLoading = false);
  }

  void _scheduleDeferredLibraryWarmup() {
    _libraryWarmupTimer?.cancel();
    _libraryWarmupTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _mobileNavIndex == 2) return;
      unawaited(_loadLibraryOrders());
      unawaited(_loadLibraryAccess());
    });
  }

  Future<void> _handleInitialDeepLink() async {
    if (_deepLinkHandled || widget.initialUri == null) return;
    final uri = widget.initialUri!;
    final type = uri.queryParameters["type"];
    final id = int.tryParse(uri.queryParameters["id"] ?? "");
    if (type == null || id == null) return;

    ProductDetail? detail;
    switch (type) {
      case "book":
        final data = books.firstWhere((b) => b["id"] == id, orElse: () => {});
        if (data.isNotEmpty) detail = _mapBookDetail(data);
        break;
      case "magazine":
        if (_hideMagazines) break;
        final data = magazines.firstWhere(
          (m) => m["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) detail = _mapMagazineDetail(data);
        break;
      case "magazine_issue":
        break;
      case "newspaper_subscription":
        if (_hideNewspapers) break;
        final data = newspapers.firstWhere(
          (n) => n["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) detail = _mapNewspaperDetail(data);
        break;
      case "ek":
        final data = attachments.firstWhere(
          (n) => n["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) {
          _deepLinkHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _openEkDetail(data);
          });
        }
        return;
    }

    if (detail != null) {
      _deepLinkHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openProductDetail(detail!);
      });
    }
  }

  Future<void> _loadAccessIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id;
      if (userId == null) return;
      await context.read<AccessProvider>().load(userId);
    });
  }

  @override
  void dispose() {
    _authListener?.removeListener(_onAuthChange);
    _sliderTimer?.cancel();
    _libraryWarmupTimer?.cancel();
    _sliderController.dispose();
    super.dispose();
  }

  double _parsePrice(dynamic value, {double fallback = 0}) {
    return double.tryParse(value?.toString() ?? "") ?? fallback;
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _formatIsoDateOnly(DateTime date) {
    final normalized = _normalizeDate(date);
    return "${normalized.year.toString().padLeft(4, "0")}-"
        "${normalized.month.toString().padLeft(2, "0")}-"
        "${normalized.day.toString().padLeft(2, "0")}";
  }

  String _resolveArchivedNewspaperUrl(
    Map<String, dynamic> viewInfo, {
    required DateTime fallbackDate,
  }) {
    final rawUrl = viewInfo["url"]?.toString().trim() ?? "";
    final source = viewInfo["source"]?.toString().trim().toLowerCase() ?? "";
    if (source != "legacy" || rawUrl.isNotEmpty) return rawUrl;

    final responseDate = viewInfo["date"]?.toString().trim() ?? "";
    final fileNameMatch = RegExp(
      r"(\d{4}-\d{2}-\d{2})\.pdf",
      caseSensitive: false,
    ).firstMatch(rawUrl);
    final isoDate = RegExp(r"^\d{4}-\d{2}-\d{2}$").hasMatch(responseDate)
        ? responseDate
        : fileNameMatch?.group(1) ?? _formatIsoDateOnly(fallbackDate);

    return "/newspaper/legacy-file?date=$isoDate";
  }

  Future<void> _openArchivedNewspaperForDate(
    BuildContext context,
    DateTime date,
  ) async {
    final normalized = _normalizeDate(date);
    final dateLabel =
        "${normalized.day.toString().padLeft(2, "0")}.${normalized.month.toString().padLeft(2, "0")}.${normalized.year}";
    try {
      final viewInfo = await _authApi.getNewspaperViewInfo(date: normalized);
      final source = viewInfo["source"]?.toString().trim().toLowerCase() ?? "";
      final pdfUrl = _resolveArchivedNewspaperUrl(
        viewInfo,
        fallbackDate: normalized,
      );
      final isPrivate = source == "legacy"
          ? false
          : viewInfo["isPrivate"] == true;
      if (pdfUrl.isEmpty) {
        throw Exception("E-gazete bağlantısı alınamadı.");
      }
      if (!context.mounted) return;
      await PdfOpenHelper.downloadAndOpen(
        context,
        url: pdfUrl,
        title: "E-Gazete $dateLabel",
        isPrivate: isPrivate,
      );
    } catch (e) {
      if (!context.mounted) return;
      final message = e.toString().replaceFirst("Exception: ", "").trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isNotEmpty ? message : "E-gazete bağlantısı alınamadı.",
          ),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _filteredNewspapers() {
    final selectedDate = _newsSelectedDate;
    if (selectedDate == null) return newspapers;

    final target = _normalizeDate(selectedDate);
    return newspapers
        .where((n) {
          final raw = n["publish_date"]?.toString();
          if (raw == null) return false;
          final parsed = DateTime.tryParse(raw);
          if (parsed == null) return false;
          return _normalizeDate(parsed) == target;
        })
        .toList(growable: false);
  }

  bool _shouldHydrateProductDetail(ProductDetail detail) =>
      detail.metadata?["hydrateOnOpen"] == true;

  ProductDetail _mergeHydratedProductDetail(
    ProductDetail current,
    ProductDetail hydrated,
  ) {
    return ProductDetail(
      id: hydrated.id,
      title: hydrated.title,
      subtitle: hydrated.subtitle,
      description: hydrated.description,
      imageUrl: hydrated.imageUrl,
      price: hydrated.price,
      type: hydrated.type,
      actionLabel: hydrated.actionLabel,
      metadata: {
        ...(current.metadata ?? const <String, dynamic>{}),
        ...(hydrated.metadata ?? const <String, dynamic>{}),
        "hydrateOnOpen": false,
      },
      forceAccess: current.forceAccess || hydrated.forceAccess,
    );
  }

  Future<ProductDetail> _hydrateProductDetailIfNeeded(
    ProductDetail detail,
  ) async {
    if (!_shouldHydrateProductDetail(detail)) return detail;
    final productId = _toInt(detail.metadata?["productId"]);
    if (productId == null) return detail;

    try {
      switch (detail.type) {
        case CartItemType.book:
          final book = await _bookService.getBookById(productId);
          if (book == null || book.isEmpty) return detail;
          return _mergeHydratedProductDetail(detail, _mapBookDetail(book));
        case CartItemType.magazine:
          final magazine = await _magService.getMagazineById(productId);
          if (magazine == null || magazine.isEmpty) return detail;
          return _mergeHydratedProductDetail(
            detail,
            _mapMagazineDetail(magazine),
          );
        case CartItemType.newspaperSubscription:
        case CartItemType.magazineIssue:
        case CartItemType.supplement:
          return detail;
      }
    } catch (error) {
      debugPrint("Product detail hydrate error: $error");
      return detail;
    }
  }

  Future<Map<String, dynamic>> _hydrateEkIfNeeded(
    Map<String, dynamic> ek,
  ) async {
    if (ek["created_at"] != null) return ek;
    final ekId = _toInt(ek["id"]);
    if (ekId == null) return ek;

    try {
      final fullEk = await _ekService.getEk(ekId);
      if (fullEk != null && fullEk.isNotEmpty) {
        return fullEk;
      }
    } catch (error) {
      debugPrint("Ek detail hydrate error: $error");
    }

    return ek;
  }

  void _openProductDetail(ProductDetail detail) async {
    final resolvedDetail = await _hydrateProductDetailIfNeeded(detail);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(detail: resolvedDetail),
      ),
    );
  }

  void _openEkDetail(Map<String, dynamic> ek) async {
    final resolvedEk = await _hydrateEkIfNeeded(ek);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EkDetailScreen(ek: normalizeEk(resolvedEk)),
      ),
    );
  }

  void _openPdfDirect(
    String url, {
    required String title,
    required bool isPublic,
  }) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("PDF bulunamadı")));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: UploadService.normalizeUrl(url),
          title: title,
          // Ücretsiz ekler de private modda açılacak
          isPrivate: true,
        ),
      ),
    );
  }

  Uri? _parseSliderUri(String link) {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return Uri.tryParse(trimmed);
    }
    if (trimmed.startsWith("?")) {
      return Uri.tryParse("https://local/$trimmed");
    }
    if (trimmed.contains("type=") &&
        trimmed.contains("id=") &&
        !trimmed.contains("://")) {
      return Uri.tryParse("https://local/?$trimmed");
    }
    return Uri.tryParse(trimmed);
  }

  Future<void> _handleSliderLink(Map<String, dynamic> slide) async {
    final link = (slide["link_url"] ?? "").toString().trim();
    if (link.isEmpty) return;
    final uri = _parseSliderUri(link);
    if (uri != null) {
      final type = uri.queryParameters["type"];
      final id = int.tryParse(uri.queryParameters["id"] ?? "");
      if (type != null && id != null) {
        final opened = _openSliderTarget(type, id);
        if (opened) return;
      }
    }
    if (uri == null || !(uri.scheme == "http" || uri.scheme == "https")) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Link açılamadı.")));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SliderWebViewScreen(
          url: uri.toString(),
          title: (slide["title"] ?? "Duyuru").toString(),
        ),
      ),
    );
  }

  void _handleSliderTap(Map<String, dynamic> slide) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SliderDetailScreen(
          slide: slide,
          onOpenLink: () => _handleSliderLink(slide),
        ),
      ),
    );
  }

  bool _openSliderTarget(String type, int id) {
    switch (type) {
      case "book":
        final data = books.firstWhere((b) => b["id"] == id, orElse: () => {});
        if (data.isNotEmpty) {
          _openProductDetail(_mapBookDetail(data));
          return true;
        }
        return false;
      case "magazine":
        if (_hideMagazines) return false;
        final data = magazines.firstWhere(
          (m) => m["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) {
          _openProductDetail(_mapMagazineDetail(data));
          return true;
        }
        return false;
      case "newspaper_subscription":
      case "newspaper":
        if (_hideNewspapers) return false;
        final data = newspapers.firstWhere(
          (n) => n["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) {
          _openProductDetail(_mapNewspaperDetail(data));
          return true;
        }
        return false;
      case "ek":
        final data = attachments.firstWhere(
          (e) => e["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) {
          _openEkDetail(data);
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  void _openSearch({String initialQuery = ""}) {
    Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          books: books,
          magazines: magazines,
          newspapers: newspapers,
          attachments: attachments,
          initialQuery: initialQuery,
          showMagazines: !_hideMagazines,
          showNewspapers: !_hideNewspapers,
        ),
        fullscreenDialog: true,
      ),
    ).then((result) {
      if (result == null) return;
      final item = result["item"] as Map<String, dynamic>?;
      final type = result["type"] as String?;
      if (item == null || type == null) return;

      if (type == "book") {
        _openProductDetail(_mapBookDetail(item));
      } else if (type == "magazine") {
        if (_hideMagazines) return;
        _openProductDetail(_mapMagazineDetail(item));
      } else if (type == "ek") {
        _openEkDetail(item);
      } else {
        if (_hideNewspapers) return;
        _openProductDetail(_mapNewspaperDetail(item));
      }
    });
  }

  Future<void> _openNewspaperPaywall(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (!auth.isLoggedIn || user == null) {
      showLoginRequirementDialog(
        context,
        message:
            "E-gazeteye abone olmak için üye girişi yapmanız gerekmektedir.",
      );
      return;
    }

    final rc = context.read<RevenueCatService>();
    if (!rc.supportsNativePurchaseUi) {
      await _selectNewspaperSubscriptionType(context);
      return;
    }
    final access = context.read<AccessProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await rc.syncWithAuthUser(user);
    final result = await rc.presentYeniasyaProPaywall(userId: user.id);
    if (!mounted) return;

    if (result.name == "purchased" || result.name == "restored") {
      await access.load(user.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Abonelik başarıyla aktif edildi.")),
      );
      return;
    }
    if (result.name == "notPresented" && rc.isYeniasyaProActive) {
      await access.load(user.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Aboneliğiniz zaten aktif.")),
      );
      return;
    }
    if (result.name == "cancelled") {
      messenger.showSnackBar(
        const SnackBar(content: Text("İşlem iptal edildi.")),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(rc.errorMessage ?? "Abonelik işlemi tamamlanamadı."),
      ),
    );
  }

  Future<void> _selectNewspaperSubscriptionType(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showLoginRequirementDialog(context);
      return;
    }

    try {
      final list = await _newspaperTypePriceService.getActiveTypes();
      if (!mounted) return;
      if (list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gazete abonelik seçenekleri bulunamadı."),
          ),
        );
        return;
      }

      final cart = context.read<CartProvider>();
      final imageUrl = newspapers.isNotEmpty
          ? (newspapers.first["image_url"] ?? "").toString()
          : "";

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "E-Gazete Aboneliği Seç",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final type = list[i];
                      final typeId =
                          int.tryParse(type["id"]?.toString() ?? "") ?? 0;
                      final months =
                          int.tryParse(
                            type["duration_months"]?.toString() ?? "",
                          ) ??
                          0;
                      final price =
                          double.tryParse(type["price"]?.toString() ?? "") ?? 0;
                      final title = (type["title"] ?? "").toString().trim();
                      final displayTitle = title.isNotEmpty
                          ? title
                          : (months > 0
                                ? "$months Aylık Abonelik"
                                : "Abonelik");
                      final cartItem = CartItem(
                        id: "news-sub-type-$typeId",
                        title: "E-Gazete",
                        subtitle: displayTitle,
                        imageUrl: imageUrl,
                        price: price,
                        quantity: 1,
                        type: CartItemType.newspaperSubscription,
                        metadata: {
                          "productId": "gazete-abonelik",
                          "newspaperSubscriptionTypeId": typeId,
                          "periodMonths": months,
                          "period": months > 0 ? months.toString() : null,
                          "typeTitle": displayTitle,
                        },
                      );
                      final alreadyInCart = cart.contains(cartItem);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(displayTitle),
                        subtitle: Text(
                          months > 0 ? "$months ay" : "E-Gazete Aboneliği",
                        ),
                        trailing: Text(
                          alreadyInCart
                              ? "Sepette"
                              : "₺${price.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: alreadyInCart ? Colors.grey : Colors.red,
                          ),
                        ),
                        onTap: alreadyInCart
                            ? null
                            : () {
                                final added = cart.addIfAbsent(cartItem);
                                if (added) {
                                  Navigator.pop(context);
                                  showAddedToCartDialog(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Bu ürün zaten sepette."),
                                    ),
                                  );
                                }
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Abonelik seçenekleri alınamadı: $e")),
      );
    }
  }

  void _openFromOrderItem(Map<String, dynamic> item) {
    final type = (item["product_type"] ?? "").toString();
    final meta = item["metadata"] as Map<String, dynamic>? ?? {};
    final productId =
        item["id"] ??
        item["product_id"] ??
        item["productId"] ??
        meta["product_id"] ??
        meta["id"];
    final fallbackFileUrl =
        meta["file_url"] ??
        meta["pdf_url"] ??
        meta["book_url"] ??
        item["file_url"] ??
        item["pdf_url"] ??
        item["book_url"];
    final mergedMeta = <String, dynamic>{
      ...meta,
      if (fallbackFileUrl != null && fallbackFileUrl.toString().isNotEmpty)
        "fileUrl": fallbackFileUrl,
    };

    Future<void> openPdf(String url, String title) async {
      try {
        await PdfOpenHelper.downloadAndOpen(
          context,
          url: url,
          title: title,
          isPrivate: true,
          showDialogProgress: true,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Dosya açılamadı: $e")));
      }
    }

    final pid = _toInt(productId);

    switch (type) {
      case "book":
        if (pid != null) {
          final local = books.firstWhere(
            (b) => b["id"] == pid,
            orElse: () => {},
          );
          if (local.isNotEmpty) {
            final baseDetail = _mapBookDetail(local);
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
            return;
          }
          _bookService.getBookById(pid).then((book) {
            final baseDetail = _mapBookDetail(book ?? {});
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
          });
          return;
        }
        break;
      case "magazine_issue":
        if (pid != null) {
          _magService.getIssueById(pid).then((issue) {
            final magId = issue?["magazine_id"] as int?;
            if (magId != null) {
              _magService.getMagazineById(magId).then((mag) {
                final baseDetail = _mapMagazineDetail(mag ?? {});
                final detail = baseDetail.copyWith(
                  forceAccess: true,
                  metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
                );
                _openProductDetail(detail);
              });
              return;
            }
            final name =
                issue?["magazine"]?["name"]?.toString() ?? "Dergi Sayısı";
            final issueNo = issue?["issue_number"]?.toString();
            final title = issueNo != null ? "$name - $issueNo" : name;
            final url =
                issue?["file_url"]?.toString() ?? meta["file_url"]?.toString();
            if (url != null && url.isNotEmpty) {
              openPdf(url, title);
            }
          });
          return;
        }
        break;
      case "magazine":
        if (pid != null) {
          final local = magazines.firstWhere(
            (m) => m["id"] == pid,
            orElse: () => {},
          );
          if (local.isNotEmpty) {
            final baseDetail = _mapMagazineDetail(local);
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
            return;
          }
          _magService.getMagazineById(pid).then((mag) {
            final baseDetail = _mapMagazineDetail(mag ?? {});
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
          });
          return;
        }
        break;
      case "newspaper_subscription":
      case "newspaper":
        if (pid != null) {
          final nw = newspapers.firstWhere(
            (n) => n["id"] == pid,
            orElse: () => {},
          );
          if (nw.isNotEmpty) {
            final baseDetail = _mapNewspaperDetail(nw);
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
            return;
          }
        }
        if (newspapers.isNotEmpty) {
          final baseDetail = _mapNewspaperDetail(newspapers.first);
          final detail = baseDetail.copyWith(
            forceAccess: true,
            metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
          );
          _openProductDetail(detail);
          return;
        }
        break;
      case "ek":
        _openEkDetail(item);
        return;
      default:
        break;
    }

    // Fallback: ürün detayı
    final detail = ProductDetail(
      id: "item-$productId",
      title: item["title"] ?? meta["title"] ?? "Ürün",
      description: meta["description"]?.toString() ?? "",
      imageUrl:
          meta["cover_image_url"]?.toString() ??
          meta["cover_url"]?.toString() ??
          "",
      price: _parsePrice(item["unit_price"] ?? item["line_total"]),
      type: CartItemType.book,
      metadata: {"productId": productId, ...mergedMeta},
      actionLabel: "Görüntüle",
      forceAccess: true,
    );
    _openProductDetail(detail);
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _buildHomeShowcaseList({
    required List<Map<String, dynamic>> baseItems,
    required List<Map<String, dynamic>> selectedEntries,
    required int maxItems,
    required String idKey,
    required String selectedIdKey,
  }) {
    if (baseItems.isEmpty) return [];
    final itemsById = <int, Map<String, dynamic>>{};
    for (final item in baseItems) {
      final id = _toInt(item[idKey]);
      if (id == null) continue;
      itemsById[id] = item;
    }
    final selectedIds = <int>{};
    final result = <Map<String, dynamic>>[];

    for (final entry in selectedEntries) {
      if (result.length >= maxItems) break;
      final entryId = _toInt(entry[selectedIdKey]);
      if (entryId == null) continue;
      final item = itemsById[entryId];
      if (item == null) continue;
      selectedIds.add(entryId);
      result.add(item);
    }

    for (final item in baseItems) {
      if (result.length >= maxItems) break;
      final id = _toInt(item[idKey]);
      if (id == null || selectedIds.contains(id)) continue;
      result.add(item);
    }

    return result;
  }

  List<Map<String, dynamic>> _orderedMagazinesForListing() {
    if (magazines.isEmpty) return const <Map<String, dynamic>>[];
    if (homeMagazineEntries.isEmpty) return magazines;
    return _buildHomeShowcaseList(
      baseItems: magazines,
      selectedEntries: homeMagazineEntries,
      maxItems: magazines.length,
      idKey: "id",
      selectedIdKey: "product_id",
    );
  }

  bool _hasPurchased(String type, int? itemId) {
    if (itemId == null) return false;
    final access = context.read<AccessProvider>();
    if (access.hasAccess(type, itemId: itemId)) return true;
    if (libraryOrders.isEmpty) return false;
    final items = libraryOrders
        .expand<Map<String, dynamic>>(
          (o) => List<Map<String, dynamic>>.from(o["order_items"] ?? []),
        )
        .toList();
    return items.any((i) {
      final itemType = (i["product_type"] ?? "").toString();
      if (itemType != type) return false;
      final meta = i["metadata"] as Map<String, dynamic>? ?? {};
      final pid = _toInt(
        meta["product_id"] ?? meta["id"] ?? i["product_id"] ?? i["id"],
      );
      return pid == itemId;
    });
  }

  Future<_AccessItem> _resolveAccessItem(
    String type,
    Map<String, dynamic> entry,
  ) async {
    final itemId = entry["item_id"];
    switch (type) {
      case "ek":
        if (itemId == null) return _AccessItem(title: "Bilinmeyen ek");
        final ek = await _ekService.getEk(itemId as int);
        final title = ek?["ad"]?.toString() ?? "Ek #$itemId";
        return _AccessItem(
          title: title,
          subtitle: "Ek",
          icon: _iconForType(type),
          onTap: (ek == null)
              ? null
              : () {
                  if (!mounted) return;
                  _openEkDetail(ek);
                },
        );
      case "book":
        if (itemId == null) return _AccessItem(title: "Bilinmeyen kitap");
        final book = await _bookService.getBookById(itemId as int);
        final title = book?["title"]?.toString() ?? "Kitap #$itemId";
        final url = book?["book_url"]?.toString();
        return _AccessItem(
          title: title,
          subtitle: "Kitap",
          icon: _iconForType(type),
          onTap: (url == null || url.isEmpty)
              ? null
              : () async {
                  try {
                    await PdfOpenHelper.downloadAndOpen(
                      context,
                      url: url,
                      title: title,
                      isPrivate: true,
                      showDialogProgress: true,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Dosya açılamadı: $e")),
                    );
                  }
                },
        );
      case "magazine_issue":
        if (itemId == null) return _AccessItem(title: "Bilinmeyen sayı");
        final issue = await _magService.getIssueById(itemId as int);
        final magName = issue?["magazine"]?["name"]?.toString() ?? "Dergi";
        final issueNumber = issue?["issue_number"]?.toString() ?? "#$itemId";
        final url = issue?["file_url"]?.toString();
        return _AccessItem(
          title: "$magName - $issueNumber",
          subtitle: "Dergi Sayısı",
          icon: _iconForType(type),
          onTap: (url == null || url.isEmpty)
              ? null
              : () async {
                  try {
                    await PdfOpenHelper.downloadAndOpen(
                      context,
                      url: url,
                      title: "$magName - $issueNumber",
                      isPrivate: true,
                      showDialogProgress: true,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Dosya açılamadı: $e")),
                    );
                  }
                },
        );
      case "magazine":
        if (itemId == null) return _AccessItem(title: "Dergi aboneliği");
        final mag = await _magService.getMagazineById(itemId as int);
        final name = mag?["name"]?.toString() ?? "Dergi #$itemId";
        final expiresAtRaw = entry["expires_at"]?.toString();
        final expiresAt = expiresAtRaw == null
            ? null
            : DateTime.tryParse(expiresAtRaw);
        final subtitle = expiresAt != null
            ? "Bitiş Tarihi: ${_formatDateShort(expiresAt)}"
            : "Dergi aboneliği";
        return _AccessItem(
          title: name,
          subtitle: subtitle,
          icon: _iconForType(type),
          onTap: () => _openMagazineIssuesFromLibrary(itemId, name),
        );
      case "newspaper_subscription":
        final expiresAtRaw = entry["expires_at"]?.toString();
        final expiresAt = expiresAtRaw == null
            ? null
            : DateTime.tryParse(expiresAtRaw);
        final isActive = _isLibraryAccessEntryActive(entry);
        return _AccessItem(
          title: "Gazete aboneliği",
          subtitle: expiresAt != null
              ? "Bitiş Tarihi: ${_formatDateShort(expiresAt)}"
              : "Abonelik aktif",
          icon: _iconForType(type),
          statusLabel: isActive ? "Aktif" : "Pasif",
          statusColor: isActive ? Colors.green : Colors.grey,
          onTap: null,
        );
      default:
        return _AccessItem(
          title: "Bilinmeyen içerik",
          icon: _iconForType(type),
        );
    }
  }

  Future<void> _openMagazineIssuesFromLibrary(
    int magazineId,
    String name,
  ) async {
    if (_loadingLibraryMagazineIssues || _libraryMagazineIssuesSheetOpen) {
      return;
    }

    setState(() => _loadingLibraryMagazineIssues = true);
    List<Map<String, dynamic>> issues = [];
    try {
      issues = await _magService.getIssues(magazineId);
    } finally {
      if (mounted) {
        setState(() => _loadingLibraryMagazineIssues = false);
      }
    }
    if (!mounted) return;
    if (_libraryMagazineIssuesSheetOpen) return;
    final visibleIssues = issues;

    setState(() => _libraryMagazineIssuesSheetOpen = true);
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          final mq = MediaQueryData.fromView(View.of(sheetContext));
          final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
          return SizedBox(
            height: mq.size.height,
            child: Padding(
              padding: EdgeInsets.only(
                top: mq.padding.top,
                bottom: viewInsets.bottom + mq.padding.bottom,
                left: 12,
                right: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$name Sayıları",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: visibleIssues.isEmpty
                        ? const Center(child: Text("Sayı bulunamadı"))
                        : ListView.separated(
                            itemCount: visibleIssues.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final issue = visibleIssues[i];
                              final title = "Sayı ${issue["issue_number"]}";
                              final imageUrl =
                                  issue["photo_url"]?.toString() ?? "";
                              return ListTile(
                                title: Text(title),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  final detail = _buildMagazineIssueDetail(
                                    issue: issue,
                                    issueNumber: title,
                                    magazineId: magazineId,
                                    magazineName: name,
                                    imageUrl: imageUrl,
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailScreen(detail: detail),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _libraryMagazineIssuesSheetOpen = false);
      } else {
        _libraryMagazineIssuesSheetOpen = false;
      }
    }
  }

  Future<void> _openAccessSheet(
    BuildContext context,
    String itemType,
    String title,
  ) async {
    if (_loadingAccessSheet) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _loadingAccessSheet = true);
    List<Map<String, dynamic>> entries = [];
    try {
      entries = await _accessService.getAccess(
        userId: userId,
        itemType: itemType,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erişim alınamadı: $e")));
      }
    } finally {
      if (mounted) setState(() => _loadingAccessSheet = false);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final mq = MediaQueryData.fromView(View.of(sheetContext));
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        return SizedBox(
          height: mq.size.height,
          child: Padding(
            padding: EdgeInsets.only(
              top: mq.padding.top,
              bottom: viewInsets.bottom + mq.padding.bottom,
              left: 12,
              right: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _loadingAccessSheet
                      ? const Center(child: CircularProgressIndicator())
                      : entries.isEmpty
                      ? const Center(child: Text("Kayıt bulunamadı"))
                      : ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final entry = entries[i];
                            return FutureBuilder<_AccessItem>(
                              future: _resolveAccessItem(itemType, entry),
                              builder: (_, snap) {
                                if (!snap.hasData) {
                                  return const ListTile(
                                    title: Text("Yükleniyor..."),
                                    trailing: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                final data = snap.data!;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.red.shade100,
                                    foregroundColor: Colors.red,
                                    child: Icon(
                                      data.icon ?? _iconForType(itemType),
                                    ),
                                  ),
                                  title: Text(data.title),
                                  subtitle: data.subtitle != null
                                      ? Text(data.subtitle!)
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (data.statusLabel != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (data.statusColor ??
                                                        Colors.grey)
                                                    .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            data.statusLabel!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  data.statusColor ??
                                                  Colors.grey,
                                            ),
                                          ),
                                        ),
                                      if (data.onTap != null) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ],
                                  ),
                                  onTap: data.onTap,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isLibraryAccessEntryActive(Map<String, dynamic> entry) {
    if (entry["is_active"] == false) return false;
    final expiresAtRaw = entry["expires_at"]?.toString();
    if (expiresAtRaw == null || expiresAtRaw.isEmpty) return true;
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null) return true;
    return expiresAt.isAfter(DateTime.now());
  }

  Future<void> _openMagazineIssues(int magazineId) async {
    try {
      final issues = await _magService.getPublicIssues(magazineId);
      if (!mounted) return;
      if (issues.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu dergiye ait sayı bulunamadı.")),
        );
        return;
      }
      showModalBottomSheet(
        context: context,
        builder: (_) => ListView.separated(
          itemCount: issues.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final issue = issues[i];
            final num = issue["issue_number"]?.toString() ?? "#${issue["id"]}";
            return ListTile(
              leading: const Icon(Icons.auto_stories),
              title: Text("Sayı $num"),
              onTap: () {
                Navigator.pop(context);
                final url = issue["file_url"]?.toString();
                if (url != null && url.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(
                        url: url,
                        title: "Dergi Sayısı $num",
                        isPrivate: true,
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Dergi sayıları alınamadı: $e")));
    }
  }

  ProductDetail _buildMagazineIssueDetail({
    required Map<String, dynamic> issue,
    required String issueNumber,
    required int magazineId,
    required String magazineName,
    required String imageUrl,
  }) {
    final issueId = issue["id"] as int?;
    final title = issueNumber.isNotEmpty
        ? "$magazineName - $issueNumber"
        : "$magazineName - Sayı";
    final rawPrice = issue["price"];
    final price = rawPrice is num ? rawPrice.toDouble() : _parsePrice(rawPrice);
    final description = (issue["description"] ?? "").toString().trim();
    final issueDate =
        issue["added_at"]?.toString() ??
        issue["publish_date"]?.toString() ??
        issue["created_at"]?.toString();
    final metadata = {
      "productId": issueId,
      "magazineId": magazineId,
      "issueDate": issueDate,
    };
    return ProductDetail(
      id: "mag-issue-${issueId ?? issueNumber.hashCode}",
      title: title,
      subtitle: magazineName,
      description: description.isEmpty
          ? "Bu dergi sayısına abonelik ile erişilir."
          : description,
      imageUrl: UploadService.normalizeUrl(imageUrl),
      price: price,
      type: CartItemType.magazineIssue,
      metadata: metadata,
      actionLabel: "Sepete Ekle",
    );
  }

  ProductDetail _mapMagazineDetail(Map<String, dynamic> mag) {
    final hasAccess = context.read<AccessProvider>().hasAccess(
      "magazine",
      itemId: mag["id"] as int?,
    );
    final actionLabel = hasAccess ? "E-dergiyi Gör" : "Abone Ol";
    final needsHydration = mag["created_at"] == null;
    return ProductDetail(
      id: "mag-${mag["id"]}",
      title: mag["name"] ?? "",
      subtitle: mag["category"] ?? "",
      description: mag["description"] ?? mag["category"] ?? "",
      imageUrl: mag["cover_image_url"] ?? "",
      price: 0,
      type: CartItemType.magazine,
      metadata: {
        "productId": mag["id"],
        "disableAdd": hasAccess,
        "period": mag["period"],
        "hydrateOnOpen": needsHydration,
      },
      actionLabel: actionLabel,
    );
  }

  ProductDetail _mapBookDetail(Map<String, dynamic> book) {
    final hasAccess = context.read<AccessProvider>().hasAccess(
      "book",
      itemId: book["id"] as int?,
    );
    final price = _effectiveBookPrice(book);
    final actionLabel = (hasAccess || price <= 0)
        ? "Kitabı Gör"
        : "Sepete Ekle";
    final needsHydration =
        book["book_url"] == null || book["description"] == null;
    return ProductDetail(
      id: "book-${book["id"]}",
      title: book["title"] ?? "",
      subtitle: book["author_rel"]?["name"] ?? "",
      description: book["description"] ?? book["min_description"] ?? "",
      imageUrl: book["cover_url"] ?? "",
      price: price,
      type: CartItemType.book,
      metadata: {
        "productId": book["id"],
        "disableAdd": hasAccess,
        "hydrateOnOpen": needsHydration,
      },
      actionLabel: actionLabel,
    );
  }

  double _effectiveBookPrice(Map<String, dynamic> book) {
    final rawPrice = _parsePrice(book["price"]);
    final discPriceRaw = book["discount_price"];
    double price = rawPrice;
    if (discPriceRaw != null) {
      final dp = _parsePrice(discPriceRaw);
      if (dp < price) {
        price = dp;
      }
    }
    return price;
  }

  ProductDetail _mapNewspaperDetail(Map<String, dynamic> news) {
    final dateStr = news["publish_date"]?.toString() ?? "";
    final hasSub = _hasNewspaperSubscription(context);
    final title = "E-Gazete";
    return ProductDetail(
      id: "news-${news["id"] ?? "subscription"}",
      title: title,
      subtitle: dateStr,
      description: dateStr.isNotEmpty
          ? "Yayın tarihi: $dateStr"
          : "Günlük gazete aboneliği.",
      imageUrl: news["image_url"] ?? "",
      price: 1.0,
      type: CartItemType.newspaperSubscription,
      metadata: {
        "productId": "gazete-abonelik",
        "newspaperId": news["id"],
        "disableAdd": hasSub,
        "period": news["period"],
      },
      actionLabel: hasSub ? "Görüntüle" : "Abone Ol",
    );
  }

  String _normalizeStandalonePath(String rawPath) {
    final path = rawPath.trim().toLowerCase();
    if (path.isEmpty || path == "/") return "/";
    return path.endsWith("/") ? path.substring(0, path.length - 1) : path;
  }

  Widget? _buildStandalonePageByPath(String rawPath) {
    final path = _normalizeStandalonePath(rawPath);

    if (path == "/sifre-sifirla" || path == "/reset-password") {
      return PasswordResetScreen(
        token: widget.initialUri?.queryParameters["token"],
        email: widget.initialUri?.queryParameters["email"],
      );
    }
    if (path == "/hesap-aktivasyon" || path == "/verify-email") {
      return EmailVerificationScreen(
        token: widget.initialUri?.queryParameters["token"],
        email: widget.initialUri?.queryParameters["email"],
      );
    }
    if (path == "/payment/pay/success" || path == "/payment/pay/error") {
      return PaymentWebReturnScreen(resultUri: widget.initialUri ?? Uri.base);
    }
    if (path == "/privacy" || path == "/gizlilik-politikasi") {
      return StaticInfoPage(
        title: "Gizlilik Politikası",
        content:
            footerPageContentMap["Gizlilik Politikası"] ??
            "Bu sayfa için içerik yakında eklenecek.",
      );
    }
    if (path == "/iletisim") {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text("İletişim"),
          elevation: 1,
        ),
        body: const SafeArea(
          child: ContactForm(popOnSuccess: false, showCompanyInfo: true),
        ),
      );
    }
    if (path == "/sss" || path == "/faq") {
      return const FaqPage();
    }

    final legalPathToTitle = <String, String>{
      "/kvkk": "KVKK",
      "/kvvk": "KVKK",
      "/cerez-politikasi": "Çerez Politikası",
      "/kullanim-kosullari": "Kullanım Koşulları",
    };
    final legalTitle = legalPathToTitle[path];
    if (legalTitle == null) return null;

    return StaticInfoPage(
      title: legalTitle,
      content:
          footerPageContentMap[legalTitle] ??
          "Bu sayfa için içerik yakında eklenecek.",
    );
  }

  void _scheduleInitialStandaloneRedirect() {
    if (_standaloneRouteHandled) return;
    final standalonePage = _buildStandalonePageByPath(
      widget.initialUri?.path ?? "",
    );
    if (standalonePage == null) return;
    _standaloneRouteHandled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => standalonePage));
    });
  }

  Widget _buildHomeStateMessage() {
    if (_homeLoadFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "İçerikler yüklenemedi.",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Bağlantı yavaş veya geçici olarak servis yanıt vermiyor olabilir.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshHome,
                child: const Text("Tekrar Dene"),
              ),
            ],
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Text(
          "İçerik bulunmamaktadır.",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHomeShowcaseSections(
    BuildContext context,
    bool isWeb,
    CartProvider cart,
  ) {
    final showcaseLimit = _showcaseItemLimit(isWeb);
    final magazineDisplayList = _hideMagazines
        ? const <Map<String, dynamic>>[]
        : _buildHomeShowcaseList(
            baseItems: magazines,
            selectedEntries: homeMagazineEntries,
            maxItems: showcaseLimit,
            idKey: "id",
            selectedIdKey: "product_id",
          );
    final bookDisplayList = _buildHomeShowcaseList(
      baseItems: books,
      selectedEntries: homeBookEntries,
      maxItems: showcaseLimit,
      idKey: "id",
      selectedIdKey: "product_id",
    );

    final sections = <Widget>[];
    if (!_hideNewspapers && newspapers.isNotEmpty) {
      sections.add(
        _newspaperShowcase(context, isWeb, itemLimit: showcaseLimit),
      );
    }
    if (magazineDisplayList.isNotEmpty) {
      sections.add(
        _magazineShowcase(context, isWeb, displayList: magazineDisplayList),
      );
    }
    if (bookDisplayList.isNotEmpty) {
      sections.add(
        _booksShowcase(context, isWeb, cart, displayList: bookDisplayList),
      );
    }
    if (attachments.isNotEmpty) {
      sections.add(
        _homeEkSection(
          context,
          isWeb,
          cart,
          items: attachments.take(isWeb ? 5 : 4).toList(growable: false),
        ),
      );
    }
    return sections;
  }

  Widget _buildLegacyScrollableBody(
    bool isWeb,
    bool isTablet,
    CartProvider cart, {
    required bool hasSlider,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshHome,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 64 : (isTablet ? 32 : 16),
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_section == HomeSection.home) ...[
                          if (hasSlider) _buildSlider(isWeb, isTablet),
                          if (hasSlider) const SizedBox(height: 16),
                        ],
                        _buildBodyContent(isWeb, isTablet, cart),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isWeb) YeniAsyaFooter(onCategoryTap: _openSectionFromFooter),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHomeBody(CartProvider cart) {
    final sections = _buildHomeShowcaseSections(context, false, cart);
    final children = <Widget>[];

    if (sliders.isNotEmpty) {
      children.add(_buildSlider(false, false));
    }

    if (sections.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 16));
      }
      for (var i = 0; i < sections.length; i++) {
        if (i > 0) {
          children.add(const SizedBox(height: 32));
        }
        children.add(sections[i]);
      }
    } else if (sliders.isEmpty) {
      children.add(_buildHomeStateMessage());
    }

    return RefreshIndicator(
      onRefresh: _refreshHome,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => children[index],
                childCount: children.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access provider'ı dinleyerek satın alınan içeriklerin UI'yi güncellemesini sağla
    context.watch<AccessProvider>();
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final hasSlider = sliders.isNotEmpty;

    if (loading) {
      return const AppBootstrapScreen(status: "İçerikler hazırlanıyor");
    }
    _scheduleInitialStandaloneRedirect();

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 6,
        shadowColor: Colors.black.withOpacity(0.18),
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 40 : (isTablet ? 32 : 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        "assets/images/logo.png",
                        height: isWeb ? 40 : 32,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 32),
                      if (isWeb)
                        Row(
                          children: [
                            _menuItem("Anasayfa", HomeSection.home),
                            if (!_hideNewspapers)
                              _menuItem("E-Gazete", HomeSection.newspapers),
                            if (!_hideMagazines)
                              _menuItem("E-Dergiler", HomeSection.magazines),
                            _menuItem("E-Kitaplar", HomeSection.books),
                            _menuItem("E-Ekler", HomeSection.attachments),
                          ],
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isWeb)
                        SizedBox(
                          width: 240,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Ara...",
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            onSubmitted: (q) => _openSearch(initialQuery: q),
                            onTap: () => _openSearch(),
                            readOnly: true,
                          ),
                        ),
                      if (isWeb) const SizedBox(width: 12),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.black87,
                            ),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: _cartCount(cart) > 0
                                    ? Colors.red
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _cartCount(cart).toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isWeb && !auth.isLoggedIn)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Giriş Yap"),
                          ),
                        ),
                      if (isWeb && auth.isLoggedIn)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                RouteGuard.guard(
                                  context: context,
                                  routeName: "/profile",
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Profilim"),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isWeb)
              const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _mobileNavIndex == 2 && !isWeb
            ? _libraryView(context, this)
            : (!isWeb && _section == HomeSection.home
                  ? _buildMobileHomeBody(cart)
                  : _buildLegacyScrollableBody(
                      isWeb,
                      isTablet,
                      cart,
                      hasSlider: hasSlider,
                    )),
      ),
      bottomNavigationBar: isWeb
          ? null
          : Container(
              color: Colors.white,
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                maintainBottomViewPadding: true,
                child: BottomNavigationBar(
                  elevation: 12,
                  backgroundColor: Colors.white,
                  selectedItemColor: Colors.red,
                  unselectedItemColor: Colors.grey,
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _mobileNavIndex,
                  onTap: (index) {
                    setState(() => _mobileNavIndex = index);
                    if (index == 0) {
                      setState(() => _section = HomeSection.home);
                    }
                    if (index == 1) {
                      _openSearch();
                    }
                    if (index == 2) {
                      _libraryWarmupTimer?.cancel();
                      _loadLibraryOrders();
                      _loadLibraryAccess();
                    }
                    if (index == 3) {
                      if (auth.isLoggedIn) {
                        Navigator.push(
                          context,
                          RouteGuard.guard(
                            context: context,
                            routeName: "/profile",
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      }
                    }
                  },
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.home),
                      label: "Ana Sayfa",
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.search),
                      label: "Ara",
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.library_books_outlined),
                      label: "Kütüphanem",
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline),
                      label: auth.isLoggedIn ? "Profil" : "Giriş Yap",
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBodyContent(bool isWeb, bool isTablet, CartProvider cart) {
    switch (_section) {
      case HomeSection.magazines:
        if (_hideMagazines) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeadingText("E-Dergiler"),
            const SizedBox(height: 16),
            _magazineListGrid(context, isWeb),
          ],
        );
      case HomeSection.books:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeadingText("E-Kitaplar"),
            const SizedBox(height: 16),
            isWeb
                ? _BookBrowseBody(homeState: this)
                : _bookListGrid(context, isWeb, isTablet),
            const SizedBox(height: 24),
          ],
        );
      case HomeSection.newspapers:
        if (_hideNewspapers) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeadingText("E-Gazete"),
            const SizedBox(height: 12),
            _newspaperFilters(context),
            const SizedBox(height: 16),
            _NewspaperBrowseBody(
              homeState: this,
              items: _filteredNewspapers(),
              isWeb: isWeb,
            ),
          ],
        );
      case HomeSection.attachments:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!isWeb)
                  IconButton(
                    onPressed: () =>
                        setState(() => _section = HomeSection.home),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: "Geri",
                  ),
                _sectionHeadingText("E-Ekler"),
              ],
            ),
            const SizedBox(height: 16),
            _attachmentsList(context, this, isWeb, cart),
          ],
        );
      case HomeSection.home:
        final sections = _buildHomeShowcaseSections(context, isWeb, cart);
        if (sections.isEmpty) {
          return sliders.isNotEmpty
              ? const SizedBox.shrink()
              : _buildHomeStateMessage();
        }

        final children = <Widget>[];
        for (var i = 0; i < sections.length; i++) {
          if (i > 0) {
            children.add(const SizedBox(height: 32));
          }
          children.add(sections[i]);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
    }
  }

  Widget _buildSlider(bool isWeb, bool isTablet) {
    if (sliders.isEmpty) return const SizedBox.shrink();
    final height = isWeb ? 360.0 : (isTablet ? 260.0 : 200.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _sliderController,
              itemCount: sliders.length,
              onPageChanged: (index) => setState(() => _sliderIndex = index),
              itemBuilder: (_, index) =>
                  _sliderSlide(sliders[index], isWeb: isWeb),
            ),
          ),
        ),
        if (sliders.length > 1) ...[
          const SizedBox(height: 10),
          _buildSliderIndicators(),
        ],
      ],
    );
  }

  Widget _sliderSlide(Map<String, dynamic> slide, {required bool isWeb}) {
    final imageUrl = UploadService.normalizeUrl(
      slide["image_url"]?.toString() ?? "",
    );
    final title = slide["title"]?.toString() ?? "";
    final subtitle = slide["subtitle"]?.toString() ?? "";
    final hasOverlay = title.isNotEmpty || subtitle.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSliderTap(slide),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isWeb) ...[
              safeImage(imageUrl, fit: BoxFit.cover, fallbackIcon: Icons.image),
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: safeImage(
                  imageUrl,
                  fit: BoxFit.contain,
                  fallbackIcon: Icons.image,
                ),
              ),
            ] else
              safeImage(imageUrl, fit: BoxFit.cover, fallbackIcon: Icons.image),
            if (hasOverlay)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.black.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(sliders.length, (index) {
        final active = index == _sliderIndex;
        return GestureDetector(
          onTap: () {
            if (!_sliderController.hasClients) return;
            _sliderController.animateToPage(
              index,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? Colors.red : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }

  Widget _magazineShowcase(
    BuildContext context,
    bool isWeb, {
    List<Map<String, dynamic>>? displayList,
  }) {
    final resolvedDisplayList =
        displayList ??
        _buildHomeShowcaseList(
          baseItems: magazines,
          selectedEntries: homeMagazineEntries,
          maxItems: _showcaseItemLimit(isWeb),
          idKey: "id",
          selectedIdKey: "product_id",
        );
    if (resolvedDisplayList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          "Öne Çıkan E-Dergiler",
          onViewAll: () {
            if (isWeb) {
              setState(() => _section = HomeSection.magazines);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _MagazineBrowseScreen(homeState: this),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isWeb ? 336 : 264,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: resolvedDisplayList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final magazine = resolvedDisplayList[i];
              final category = magazine["category"]?.toString().trim() ?? "";
              final description =
                  magazine["description"]?.toString().trim() ?? "";
              final isSubscribed = _hasPurchased(
                "magazine",
                _toInt(magazine["id"]),
              );
              return SizedBox(
                width: isWeb ? 160 : 146,
                child: _magazineCard(
                  {
                    "image": magazine["cover_image_url"],
                    "title": magazine["name"],
                    "desc": category.isNotEmpty ? category : description,
                    "price": isWeb && !isSubscribed ? "Fiyat için tıkla" : "",
                  },
                  imageHeight: isWeb ? 196 : 148,
                  spacious: isWeb,
                  fullWidthAction: true,
                  hideAction: isSubscribed,
                  onAdd: () => _openProductDetail(_mapMagazineDetail(magazine)),
                  onTap: () => _openProductDetail(_mapMagazineDetail(magazine)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _booksShowcase(
    BuildContext context,
    bool isWeb,
    CartProvider cart, {
    List<Map<String, dynamic>>? displayList,
  }) {
    context.watch<AccessProvider>();
    final resolvedDisplayList =
        displayList ??
        _buildHomeShowcaseList(
          baseItems: books,
          selectedEntries: homeBookEntries,
          maxItems: _showcaseItemLimit(isWeb),
          idKey: "id",
          selectedIdKey: "product_id",
        );
    if (resolvedDisplayList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          "Popüler E-Kitaplar",
          onViewAll: () {
            if (isWeb) {
              setState(() => _section = HomeSection.books);
            } else {
              _openFullList(
                context,
                "E-Kitaplar",
                (_) => _BookBrowseBody(homeState: this),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isWeb ? 285 : 272,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: resolvedDisplayList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final effectivePrice = _effectiveBookPrice(
                resolvedDisplayList[i],
              );
              final item = CartItem(
                id: "book-${resolvedDisplayList[i]["id"]}",
                title: resolvedDisplayList[i]["title"] ?? "",
                subtitle: resolvedDisplayList[i]["author_rel"]?["name"] ?? "",
                imageUrl: resolvedDisplayList[i]["cover_url"] ?? "",
                price: effectivePrice,
                quantity: 1,
                type: CartItemType.book,
                metadata: {"productId": resolvedDisplayList[i]["id"]},
              );
              final alreadyInCart = cart.contains(item);
              final isFree = effectivePrice <= 0;
              final purchased = _hasPurchased(
                "book",
                _toInt(resolvedDisplayList[i]["id"]),
              );
              return _bookCard(
                {
                  "image": resolvedDisplayList[i]["cover_url"],
                  "title": resolvedDisplayList[i]["title"],
                  "author":
                      resolvedDisplayList[i]["author_rel"]?["name"] ?? "-",
                  "salePrice": resolvedDisplayList[i]["price"],
                  "campaignPrice": resolvedDisplayList[i]["discount_price"],
                },
                isWeb,
                bookStyle: true,
                hideAction: purchased || isFree,
                onAdd: alreadyInCart || isFree
                    ? null
                    : () => _addToCart(context, cart, item),
                onTap: () {
                  _openProductDetail(_mapBookDetail(resolvedDisplayList[i]));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _newspaperShowcase(
    BuildContext context,
    bool isWeb, {
    int? itemLimit,
  }) {
    if (newspapers.isEmpty) return const SizedBox.shrink();
    const fallbackImage = "assets/images/gazete.jpg";
    final today = DateTime.now();
    final items = newspapers.take(itemLimit ?? _showcaseItemLimit(isWeb)).map((
      n,
    ) {
      final dateStr = n["publish_date"]?.toString() ?? "";
      final d = DateTime.tryParse(dateStr);
      final label = d != null ? _formatDateTr(d) : dateStr;
      final titleText = label.isNotEmpty ? label : _formatDateTr(today);
      return {
        "image": n["image_url"] ?? fallbackImage,
        "date": "E-Gazete",
        "title": titleText,
        "raw": n,
      };
    }).toList();

    final showRead = _hasNewspaperSubscription(context, listen: true);
    void openList() {
      if (isWeb) {
        setState(() => _section = HomeSection.newspapers);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _NewspaperListScreen(homeState: this),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          "E-Gazete",
          onViewAll: openList,
          forceSingleLineActions: true,
          trailingActions: [
            if (!showRead)
              _viewAllChipButton(
                context,
                label: "Abone Ol",
                onPressed: () => _openNewspaperPaywall(context),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isNotEmpty)
          SizedBox(
            height: isWeb ? 336 : 264,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final raw = items[i]["raw"] as Map<String, dynamic>;
                return SizedBox(
                  width: isWeb ? 160 : 146,
                  child: _magazineCard(
                    {
                      "image": items[i]["image"],
                      "title": items[i]["title"],
                      "desc": items[i]["date"],
                      "price": "",
                    },
                    imageHeight: isWeb ? 196 : 148,
                    spacious: isWeb,
                    fullWidthAction: true,
                    actionPadding: showRead
                        ? const EdgeInsets.symmetric(vertical: 4)
                        : EdgeInsets.zero,
                    hideAction: showRead,
                    onAdd: () => _openProductDetail(_mapNewspaperDetail(raw)),
                    onTap: () => _openProductDetail(_mapNewspaperDetail(raw)),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _newspaperFilters(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasSubscription = _hasNewspaperSubscription(context, listen: true);
    if (!auth.isLoggedIn || !hasSubscription) {
      return const SizedBox.shrink();
    }
    Future<void> pickSingleDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: _newspaperPickerInitialDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        locale: const Locale('tr', 'TR'),
      );
      if (picked == null) return;
      if (!mounted) return;
      _setNewspaperSelectedDate(picked);
      if (!context.mounted) return;
      await _openArchivedNewspaperForDate(context, picked);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: pickSingleDate,
              icon: const Icon(Icons.event),
              label: Text(_newspaperSelectedDateLabel),
            ),
            if (_newsSelectedDate != null)
              TextButton.icon(
                onPressed: () => _setNewspaperSelectedDate(null),
                icon: const Icon(Icons.close, size: 18),
                label: const Text("Temizle"),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
          ],
        ),
      ],
    );
  }

  Widget _homeEkSection(
    BuildContext context,
    bool isWeb,
    CartProvider cart, {
    List<Map<String, dynamic>>? items,
  }) {
    final list =
        items ?? attachments.take(isWeb ? 5 : 4).toList(growable: false);
    if (list.isEmpty) return const SizedBox.shrink();
    final viewportHeight = max(0.0, MediaQuery.of(context).size.height);
    final maxCardHeight = viewportHeight * (isWeb ? 0.35 : 0.38);
    final height = min(isWeb ? 324.0 : 278.0, maxCardHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          "E-Ekler",
          onViewAll: () {
            if (isWeb) {
              setState(() => _section = HomeSection.attachments);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _AttachmentListScreen(state: this, cart: cart),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final ek = list[i];
              final price = _parsePrice(ek["fiyat"]);
              final title = (ek["ad"] ?? "").toString();
              final desc = (ek["aciklama"] ?? "").toString();
              final imageUrl = UploadService.normalizeUrl(
                ek["photo_url"]?.toString() ?? "",
              );
              final isFree = price == 0;
              return SizedBox(
                width: isWeb ? 320 : 260,
                child: InkWell(
                  onTap: () => _openEkDetail(ek),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: safeImage(
                                imageUrl,
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.broken_image,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title.isNotEmpty ? title : "Ek",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc.isNotEmpty ? desc : "Ek açıklaması",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isFree
                                  ? "Ücretsiz"
                                  : "₺${price.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            _cardActionButton(
                              label: "Detay",
                              onPressed: () => _openEkDetail(ek),
                              icon: Icons.visibility_outlined,
                              variant: _CardActionVariant.neutral,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _magazineListGrid(BuildContext context, bool isWeb) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final access = Provider.of<AccessProvider>(context, listen: false);
    final orderedMagazines = _orderedMagazinesForListing();
    final crossAxisCount = isWeb ? 4 : (isTabletLayout(context) ? 2 : 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 16.0;
        final textScaler = MediaQuery.textScalerOf(context);
        final titleHeight =
            textScaler.scale(16) * 1.25 * (isWeb ? 2 : 1); // 1-2 lines
        final descHeight = textScaler.scale(13) * 1.25 * 2; // 2 lines
        final rowHeight = max(
          textScaler.scale(15) * 1.4,
          isWeb ? 38.0 : 40.0,
        ); // price/button row
        final verticalGaps = isWeb ? 6.0 + 12.0 : 4.0 + 8.0;
        final contentPadding = (isWeb ? 14.0 : 12.0) * 2;
        final imageHeight = isWeb ? 196.0 : 148.0;
        final safetyMargin = isWeb ? 16.0 : 10.0;
        final cardHeight =
            imageHeight +
            contentPadding +
            verticalGaps +
            titleHeight +
            descHeight +
            rowHeight +
            safetyMargin;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: isWeb
              ? SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 176,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: 16,
                  mainAxisExtent: cardHeight,
                )
              : SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: 16,
                  mainAxisExtent: cardHeight,
                ),
          itemCount: orderedMagazines.length,
          itemBuilder: (_, i) {
            final magazine = orderedMagazines[i];
            final hasAccess = _hasPurchased("magazine", _toInt(magazine["id"]));
            final card = _magazineCard(
              {
                "image": magazine["cover_image_url"],
                "title": magazine["name"],
                "desc": magazine["description"] ?? magazine["category"],
                "price": hasAccess ? "" : "Fiyat için tıkla",
              },
              imageHeight: isWeb ? 196 : 148,
              spacious: isWeb,
              hideAction: hasAccess,
              onAdd: hasAccess
                  ? null
                  : () {
                      _openProductDetail(_mapMagazineDetail(magazine));
                    },
              onTap: () {
                _openProductDetail(_mapMagazineDetail(magazine));
              },
            );
            if (!isWeb) return card;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: 160, child: card),
            );
          },
        );
      },
    );
  }

  Widget _bookListGrid(BuildContext context, bool isWeb, bool isTablet) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final access = context.watch<AccessProvider>();
    final crossAxisCount = isWeb ? 4 : (isTablet ? 3 : 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final textScaler = MediaQuery.textScalerOf(context);
        final titleHeight = textScaler.scale(15) * 1.3 * 2;
        final authorHeight = textScaler.scale(12) * 1.25; // 1 line
        final rowHeight = 36.0; // action button + price row
        const verticalGaps = 4.0; // SizedBox height between title/author
        final contentPadding = (isWeb ? 8.0 : 9.0) * 2;
        final imageHeight = isWeb ? 140.0 : 138.0;
        const safetyMargin = 8.0;
        final cardHeight =
            imageHeight +
            contentPadding +
            verticalGaps +
            titleHeight +
            authorHeight +
            rowHeight +
            safetyMargin;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: isWeb
              ? SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 176,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  mainAxisExtent: cardHeight,
                )
              : SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  mainAxisExtent: cardHeight,
                ),
          itemCount: books.length,
          itemBuilder: (_, i) {
            final effectivePrice = _effectiveBookPrice(books[i]);
            final item = CartItem(
              id: "book-${books[i]["id"]}",
              title: books[i]["title"] ?? "",
              subtitle: books[i]["author_rel"]?["name"] ?? "",
              imageUrl: books[i]["cover_url"] ?? "",
              price: effectivePrice,
              quantity: 1,
              type: CartItemType.book,
              metadata: {"productId": books[i]["id"]},
            );
            final alreadyInCart = cart.contains(item);
            final card = _bookCard(
              {
                "image": books[i]["cover_url"],
                "title": books[i]["title"],
                "author": books[i]["author_rel"]?["name"] ?? "-",
                "salePrice": books[i]["price"],
                "campaignPrice": books[i]["discount_price"],
              },
              isWeb,
              bookStyle: true,
              hideAction:
                  _hasPurchased("book", _toInt(books[i]["id"])) ||
                  effectivePrice <= 0,
              onAdd: alreadyInCart || effectivePrice <= 0
                  ? null
                  : () => _addToCart(context, cart, item),
              onTap: () {
                _openProductDetail(_mapBookDetail(books[i]));
              },
            );
            if (!isWeb) return card;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: 160, child: card),
            );
          },
        );
      },
    );
  }

  Widget _newspaperListGrid(
    BuildContext context,
    bool isWeb,
    List<Map<String, dynamic>> items,
    int? itemLimit,
  ) {
    final hasSub = _hasNewspaperSubscription(context, listen: true);
    final visibleItems = itemLimit == null
        ? items
        : items.take(itemLimit.clamp(0, items.length)).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final maxWidth = constraints.maxWidth;
        final targetCardWidth = isWeb ? 220.0 : 165.0;
        final minColumns = isWeb ? 3 : 2;
        final maxColumns = isWeb ? 6 : 3;
        final computedColumns =
            ((maxWidth + spacing) / (targetCardWidth + spacing))
                .floor()
                .clamp(minColumns, maxColumns)
                .toInt();
        final crossAxisCount = computedColumns;
        final cardWidth =
            (maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;
        // Keep newspaper cards portrait-oriented so full first page fits better.
        final imageHeight = (cardWidth * 1.45).clamp(
          190.0,
          isWeb ? 340.0 : 300.0,
        );
        final cardHeight = imageHeight + (hasSub ? 88.0 : 72.0);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cardHeight,
          ),
          itemCount: visibleItems.length,
          itemBuilder: (_, i) {
            final item = visibleItems[i];
            final dateStr = item["publish_date"]?.toString() ?? "";
            final dt = DateTime.tryParse(dateStr);
            final label = dt != null ? _formatDateTr(dt) : dateStr;
            final title = label.isNotEmpty ? label : "Gazete";
            return _newspaperPreviewCard(
              {"image": item["image_url"], "title": title, "date": "E-Gazete"},
              compact: true,
              imageHeight: imageHeight,
              showRead: hasSub,
              onTap: () => _openProductDetail(_mapNewspaperDetail(item)),
            );
          },
        );
      },
    );
  }

  bool _hasNewspaperSubscription(BuildContext context, {bool listen = false}) {
    final auth = Provider.of<AuthProvider>(context, listen: listen);
    if (!auth.isLoggedIn) return false;
    final access = Provider.of<AccessProvider>(context, listen: listen);
    final rc = Provider.of<RevenueCatService>(context, listen: listen);
    return access.hasAccess("newspaper_subscription") || rc.isYeniasyaProActive;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case "book":
        return Icons.menu_book_rounded;
      case "magazine":
        return Icons.auto_stories_rounded;
      case "magazine_issue":
        return Icons.chrome_reader_mode_outlined;
      case "newspaper_subscription":
        return Icons.newspaper;
      case "ek":
        return Icons.file_present;
      default:
        return Icons.article_outlined;
    }
  }

  Widget _menuItem(String title, HomeSection target) {
    final active = _section == target;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _section = target),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: active ? Colors.red : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

bool isTabletLayout(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width > 600 && width <= 1024;
}

Widget _sectionHeader(
  BuildContext context,
  String title, {
  VoidCallback? onViewAll,
  List<Widget> trailingActions = const [],
  bool forceSingleLineActions = false,
}) {
  final mobile = MediaQuery.of(context).size.width <= 800;
  final actionHeight = mobile ? 32.0 : 34.0;
  final actionButtonHeight = mobile ? 25.0 : 27.0;
  final actions = <Widget>[
    ...trailingActions,
    _viewAllChipButton(
      context,
      onPressed: onViewAll,
      height: actionButtonHeight,
    ),
  ];
  final actionRowItems = <Widget>[
    for (var i = 0; i < actions.length; i++) ...[
      if (i > 0) const SizedBox(width: 6),
      actions[i],
    ],
  ];

  return Container(
    width: double.infinity,
    height: actionHeight,
    padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
    decoration: BoxDecoration(
      color: Colors.red,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 14 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actions.isNotEmpty) const SizedBox(width: 6),
        if (actions.isNotEmpty)
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: forceSingleLineActions
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actionRowItems,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actions,
                    ),
            ),
          ),
      ],
    ),
  );
}

Widget _viewAllChipButton(
  BuildContext context, {
  VoidCallback? onPressed,
  String label = "Tümünü Gör",
  double? height,
}) {
  final mobile = MediaQuery.of(context).size.width <= 800;
  final buttonHeight = height ?? (mobile ? 25.0 : 27.0);
  return SizedBox(
    height: buttonHeight,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.red,
        padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 10),
        minimumSize: Size(0, buttonHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w700,
          fontSize: mobile ? 11 : 12,
        ),
      ),
    ),
  );
}

Widget _sectionHeadingText(String title) {
  return Text(
    title,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
  );
}

enum _CardActionVariant { primary, read, neutral }

Widget _cardActionButton({
  required String label,
  required VoidCallback? onPressed,
  IconData icon = Icons.menu_book_rounded,
  _CardActionVariant variant = _CardActionVariant.primary,
  bool compact = false,
  double height = 32,
  bool fullWidth = false,
}) {
  final disabled = onPressed == null;
  late final Color bg;
  late final Color fg;
  late final BorderSide side;

  switch (variant) {
    case _CardActionVariant.read:
      bg = disabled ? Colors.grey.shade400 : const Color(0xFF1976D2);
      fg = Colors.white;
      side = BorderSide.none;
      break;
    case _CardActionVariant.neutral:
      bg = disabled ? Colors.grey.shade100 : Colors.white;
      fg = disabled ? Colors.grey : Colors.black87;
      side = BorderSide(color: Colors.grey.shade300);
      break;
    case _CardActionVariant.primary:
      bg = disabled ? Colors.grey : Colors.red;
      fg = Colors.white;
      side = BorderSide.none;
      break;
  }

  final radius = BorderRadius.circular(8);
  if (compact) {
    return SizedBox(
      width: height,
      height: height,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Icon(icon, color: fg, size: 18),
        ),
      ),
    );
  }

  return SizedBox(
    width: fullWidth ? double.infinity : null,
    height: height,
    child: TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        side: side,
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    ),
  );
}

Widget _priceWidgetForItem(
  Map<String, dynamic> item, {
  required TextStyle saleStyle,
  required TextStyle campaignStyle,
  String emptyText = "-",
  bool vertical = true,
}) {
  if (item.containsKey("salePrice") || item.containsKey("campaignPrice")) {
    final info = PriceInfo.fromRaw(item["salePrice"], item["campaignPrice"]);
    return buildPriceText(
      info: info,
      saleStyle: saleStyle,
      campaignStyle: campaignStyle,
      emptyText: emptyText,
      vertical: vertical,
    );
  }
  final fallback = item["price"]?.toString() ?? emptyText;
  return Text(fallback, style: campaignStyle);
}

Widget _magazineCard(
  Map<String, dynamic> item, {
  VoidCallback? onAdd,
  VoidCallback? onTap,
  bool hideAction = false,
  double imageHeight = 170,
  bool spacious = false,
  bool fullWidthAction = false,
  EdgeInsetsGeometry actionPadding = EdgeInsets.zero,
}) {
  final contentPadding = spacious ? 14.0 : 12.0;
  final titleLines = spacious ? 2 : 1;
  final descLines = spacious ? 2 : 1;
  final actionHeight = spacious ? 38.0 : 32.0;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: _imageWidget(item["image"], height: imageHeight),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["title"] ?? "",
                    maxLines: titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacious ? 6 : 4),
                  Text(
                    item["desc"] ?? "",
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                    maxLines: descLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (hideAction)
                    Padding(
                      padding: actionPadding,
                      child: SizedBox(
                        width: double.infinity,
                        child: _cardActionButton(
                          label: "Oku",
                          onPressed: onTap,
                          icon: Icons.auto_stories_rounded,
                          variant: _CardActionVariant.read,
                          height: actionHeight,
                          fullWidth: fullWidthAction,
                        ),
                      ),
                    )
                  else if (onAdd != null)
                    Padding(
                      padding: actionPadding,
                      child: SizedBox(
                        width: double.infinity,
                        child: _cardActionButton(
                          label: "Abone Ol",
                          onPressed: onAdd,
                          icon: Icons.workspace_premium_rounded,
                          variant: _CardActionVariant.primary,
                          height: actionHeight,
                          fullWidth: fullWidthAction,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _bookCard(
  Map<String, dynamic> item,
  bool isWeb, {
  VoidCallback? onAdd,
  VoidCallback? onTap,
  bool hideAction = false,
  bool bookStyle = false,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: isWeb ? 160 : 146,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: _imageWidget(item["image"], height: isWeb ? 140 : 138),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 8 : 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["title"] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item["author"] ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const Spacer(),
                  if (hideAction)
                    bookStyle
                        ? SizedBox(
                            width: double.infinity,
                            child: _cardActionButton(
                              label: "Oku",
                              onPressed: onTap,
                              icon: Icons.auto_stories_rounded,
                              variant: _CardActionVariant.read,
                              height: 30,
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _cardActionButton(
                                  label: "Oku",
                                  onPressed: onTap,
                                  icon: Icons.auto_stories_rounded,
                                  variant: _CardActionVariant.read,
                                  height: 30,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _cardActionButton(
                                label: "",
                                onPressed: onTap,
                                icon: Icons.menu_book_rounded,
                                variant: _CardActionVariant.read,
                                compact: true,
                                height: 30,
                              ),
                            ],
                          )
                  else
                    Row(
                      children: [
                        if (bookStyle)
                          Expanded(
                            child: _priceWidgetForItem(
                              item,
                              saleStyle: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              campaignStyle: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (bookStyle) const SizedBox(width: 6),
                        _cardActionButton(
                          label: "",
                          onPressed: onAdd,
                          icon: bookStyle ? Icons.add : Icons.menu_book_rounded,
                          variant: _CardActionVariant.primary,
                          compact: true,
                          height: 30,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _newspaperCard(Map<String, dynamic> item, {VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item["title"] ?? "",
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: const Color(0xFFF8F8F8),
                child: SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: safeImage(
                      UploadService.normalizeUrl(
                        item["icon"]?.toString() ?? "",
                      ),
                      fit: BoxFit.contain,
                      fallbackIcon: Icons.broken_image,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _newspaperPreviewCard(
  Map<String, dynamic> item, {
  VoidCallback? onTap,
  double? width,
  double? imageHeight,
  bool compact = false,
  bool showRead = false,
}) {
  final title = item["title"]?.toString() ?? "";
  final date = item["date"]?.toString() ?? "";
  final imageUrl = UploadService.normalizeUrl(item["image"]?.toString() ?? "");

  final resolvedImageHeight = imageHeight ?? (compact ? 135 : 210);

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: ColoredBox(
              color: const Color(0xFFF8F8F8),
              child: SizedBox(
                height: resolvedImageHeight,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: safeImage(
                    imageUrl,
                    fit: BoxFit.contain,
                    fallbackIcon: Icons.broken_image,
                  ),
                ),
              ),
            ),
          ),
          if (compact)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (showRead) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 24,
                        child: _cardActionButton(
                          label: "Oku",
                          onPressed: onTap,
                          icon: Icons.auto_stories_rounded,
                          variant: _CardActionVariant.read,
                          height: 24,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (showRead)
                      _cardActionButton(
                        label: "Oku",
                        onPressed: onTap,
                        icon: Icons.auto_stories_rounded,
                        variant: _CardActionVariant.read,
                        height: 30,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _imageWidget(String? url, {double? height, double? width}) {
  final double h = height ?? 150;
  final double w = width ?? double.infinity;

  return safeImage(
    UploadService.normalizeUrl(url ?? ""),
    height: h,
    width: w,
    fallbackIcon: Icons.broken_image,
  );
}

String _formatDateTr(DateTime date) {
  const months = [
    "Ocak",
    "Şubat",
    "Mart",
    "Nisan",
    "Mayıs",
    "Haziran",
    "Temmuz",
    "Ağustos",
    "Eylül",
    "Ekim",
    "Kasım",
    "Aralık",
  ];
  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  return "$day $month $year";
}

String _formatDateShort(DateTime date) {
  final day = date.day.toString().padLeft(2, "0");
  final month = date.month.toString().padLeft(2, "0");
  final year = date.year.toString();
  return "$day.$month.$year";
}

int _cartCount(CartProvider cart) {
  return cart.items.fold<int>(0, (sum, item) => sum + item.quantity);
}

void _addToCart(BuildContext context, CartProvider cart, CartItem item) {
  final auth = context.read<AuthProvider>();
  if (!auth.isLoggedIn) {
    showLoginRequirementDialog(context);
    return;
  }
  final added = cart.addIfAbsent(item);
  if (added) {
    showAddedToCartDialog(context);
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Bu ürün zaten sepette.")));
  }
}

Widget _libraryView(BuildContext context, _HomeResponsiveScreenState state) {
  final auth = context.watch<AuthProvider>();

  if (!auth.isLoggedIn) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text("Kütüphaneyi görmek için üye girişi yapmalısınız."),
      ),
    );
  }

  if (state.libraryLoading && state.libraryOrders.isEmpty) {
    return const Center(child: CircularProgressIndicator());
  }

  return RefreshIndicator(
    onRefresh: () async {
      await state._loadLibraryAccess();
      await state._loadLibraryOrders();
    },
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Aboneliklerim / İçeriklerim",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        _librarySubscriptionCard(context, state),
      ],
    ),
  );
}

Widget _librarySubscriptionCard(
  BuildContext context,
  _HomeResponsiveScreenState state,
) {
  final tiles = <Widget>[];

  void addTile(Widget tile) {
    if (tiles.isNotEmpty) {
      tiles.add(const Divider(height: 1, thickness: 1));
    }
    tiles.add(tile);
  }

  addTile(
    _libraryMenuTile(
      Icons.menu_book_outlined,
      "E-Kitaplar",
      onTap: () => state._openAccessSheet(context, "book", "E-Kitaplar"),
    ),
  );

  if (!state._hideMagazines) {
    addTile(
      _libraryMenuTile(
        Icons.library_books,
        "E-Dergiler",
        onTap: () => state._openAccessSheet(context, "magazine", "E-Dergiler"),
      ),
    );
    addTile(
      _libraryMenuTile(
        Icons.history_edu,
        "Dergi Sayıları",
        onTap: () =>
            state._openAccessSheet(context, "magazine_issue", "Dergi Sayıları"),
      ),
    );
  }

  if (!state._hideNewspapers) {
    addTile(
      _libraryMenuTile(
        Icons.newspaper,
        "E-Gazete",
        onTap: () => state._openAccessSheet(
          context,
          "newspaper_subscription",
          "E-Gazete",
        ),
      ),
    );
  }

  addTile(
    _libraryMenuTile(
      Icons.file_present,
      "E-Ekler",
      onTap: () => state._openAccessSheet(context, "ek", "E-Ekler"),
    ),
  );

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: tiles),
    ),
  );
}

Widget _libraryMenuTile(IconData icon, String text, {VoidCallback? onTap}) {
  return ListTile(
    leading: Icon(icon, color: Colors.black54),
    title: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap ?? () {},
  );
}

Widget _libraryOrderCard(BuildContext context, Map<String, dynamic> order) {
  final id = order["id"]?.toString() ?? "-";
  final total = order["total_paid"]?.toString() ?? "0";
  final status = (order["status"] ?? "").toString().toLowerCase();
  final date = order["created_at"]?.toString() ?? "";

  return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order["id"] as int),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sipariş #$id",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusLabel(status),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            date,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Toplam",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                "₺$total",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _librarySection(
  BuildContext context,
  _HomeResponsiveScreenState state,
  String title,
  List<Map<String, dynamic>> items,
) {
  String itemTitle(Map<String, dynamic> item) {
    final metadata = Map<String, dynamic>.from(
      item["metadata"] as Map<String, dynamic>? ?? {},
    );
    final value =
        item["title"] ??
        metadata["title"] ??
        metadata["name"] ??
        metadata["ad"] ??
        item["ad"] ??
        "-";
    return value.toString();
  }

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text("Bulunamadı.", style: TextStyle(color: Colors.black54))
        else
          ...items.map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.red.shade400,
                child: Icon(
                  state._iconForType((i["product_type"] ?? "").toString()),
                ),
              ),
              title: Text(
                itemTitle(i),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                state._openFromOrderItem(i);
              },
            ),
          ),
      ],
    ),
  );
}

Widget _attachmentsList(
  BuildContext context,
  _HomeResponsiveScreenState state,
  bool isWeb,
  CartProvider cart,
) {
  final access = context.watch<AccessProvider>();

  if (state.loading) {
    return const Center(child: CircularProgressIndicator());
  }
  if (state.attachments.isEmpty) {
    return const Text("Henüz ek bulunmuyor.");
  }

  final crossAxisCount = isWeb ? 3 : 1;
  final ratio = isWeb ? 3 / 1.2 : 3 / 1.8;

  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: ratio,
    ),
    itemCount: state.attachments.length,
    itemBuilder: (_, i) {
      final ek = state.attachments[i];
      final price = state._parsePrice(ek["fiyat"]);
      final isFree = price == 0;
      final ekId = state._toInt(ek["id"]);
      final hasAccess = ekId != null && access.hasAccess("ek", itemId: ekId);
      final imageUrl = UploadService.normalizeUrl(
        ek["photo_url"]?.toString() ?? "",
      );

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: safeImage(
                imageUrl,
                width: 120,
                height: double.infinity,
                fit: BoxFit.cover,
                fallbackIcon: Icons.image_not_supported,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ek["ad"]?.toString() ?? "-",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (ek["aciklama"] ?? "").toString().isEmpty
                        ? "Açıklama yok"
                        : (ek["aciklama"] ?? "").toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _statusChip(
                        isFree ? "Ücretsiz" : "Ücretli",
                        isFree ? Colors.green : Colors.red,
                      ),
                      if (!isFree) ...[
                        const SizedBox(width: 10),
                        Text(
                          "₺${price.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _cardActionButton(
                    label: "Detay",
                    onPressed: () => state._openEkDetail(ek),
                    icon: Icons.visibility_outlined,
                    variant: _CardActionVariant.neutral,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AttachmentListScreen extends StatelessWidget {
  final _HomeResponsiveScreenState state;
  final CartProvider cart;

  const _AttachmentListScreen({required this.state, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("E-Ekler")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _attachmentsList(context, state, false, cart),
      ),
    );
  }
}

class _NewspaperListScreen extends StatefulWidget {
  final _HomeResponsiveScreenState homeState;

  const _NewspaperListScreen({required this.homeState});

  @override
  State<_NewspaperListScreen> createState() => _NewspaperListScreenState();
}

class _NewspaperListScreenState extends State<_NewspaperListScreen> {
  Future<void> _pickSingleDate() async {
    final auth = context.read<AuthProvider>();
    final canPick =
        auth.isLoggedIn &&
        widget.homeState._hasNewspaperSubscription(context, listen: false);
    if (!canPick) {
      if (!auth.isLoggedIn) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("E-gazete aboneliği gerekli.")),
        );
      }
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.homeState._newspaperPickerInitialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('tr', 'TR'),
    );
    if (picked == null) return;
    if (!mounted) return;
    widget.homeState._setNewspaperSelectedDate(picked);
    setState(() {});
    await widget.homeState._openArchivedNewspaperForDate(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.homeState._hideNewspapers) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text("E-Gazete"),
          elevation: 1,
        ),
        body: const Center(
          child: Text("Bu sürümde E-Gazete içeriği gizlidir."),
        ),
      );
    }
    final auth = context.watch<AuthProvider>();
    final hasSubscription = widget.homeState._hasNewspaperSubscription(
      context,
      listen: true,
    );
    final canPickDate = auth.isLoggedIn && hasSubscription;
    final hasSelectedDate = widget.homeState._newsSelectedDate != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("E-Gazete"),
        elevation: 1,
        actions: [
          if (canPickDate)
            TextButton.icon(
              onPressed: _pickSingleDate,
              icon: const Icon(Icons.event, size: 20),
              label: Text(widget.homeState._newspaperSelectedDateLabel),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          if (hasSelectedDate)
            IconButton(
              tooltip: "Tarihi Temizle",
              onPressed: () {
                widget.homeState._setNewspaperSelectedDate(null);
                setState(() {});
              },
              icon: const Icon(Icons.close, color: Colors.red),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _NewspaperBrowseBody(
            homeState: widget.homeState,
            items: widget.homeState._filteredNewspapers(),
            isWeb: false,
          ),
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case "pending":
      return "Beklemede";
    case "paid":
      return "Ödendi";
    case "shipped":
      return "Kargoda";
    case "delivered":
      return "Teslim Edildi";
    case "canceled":
      return "İptal";
    case "refunded":
      return "İade";
    default:
      return status.isEmpty ? "-" : status;
  }
}

void _openFullList(
  BuildContext context,
  String title,
  Widget Function(BuildContext) builder,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: Text(title),
          elevation: 1,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: builder(ctx),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NewspaperBrowseBody extends StatefulWidget {
  final _HomeResponsiveScreenState homeState;
  final List<Map<String, dynamic>> items;
  final bool isWeb;

  const _NewspaperBrowseBody({
    required this.homeState,
    required this.items,
    required this.isWeb,
  });

  @override
  State<_NewspaperBrowseBody> createState() => _NewspaperBrowseBodyState();
}

class _NewspaperBrowseBodyState extends State<_NewspaperBrowseBody> {
  static const int _webBatchSize = 18;
  static const int _mobileBatchSize = 12;

  int _visibleCount = 0;

  int get _batchSize => widget.isWeb ? _webBatchSize : _mobileBatchSize;

  @override
  void initState() {
    super.initState();
    _visibleCount = _initialVisibleCount(widget.items.length);
  }

  @override
  void didUpdateWidget(covariant _NewspaperBrowseBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items) ||
        oldWidget.items.length != widget.items.length) {
      _visibleCount = _initialVisibleCount(widget.items.length);
      return;
    }
    if (_visibleCount > widget.items.length) {
      _visibleCount = widget.items.length;
    }
  }

  int _initialVisibleCount(int total) {
    if (total <= 0) return 0;
    return total < _batchSize ? total : _batchSize;
  }

  void _loadMore() {
    if (_visibleCount >= widget.items.length) return;
    setState(() {
      final nextCount = _visibleCount + _batchSize;
      _visibleCount = nextCount > widget.items.length
          ? widget.items.length
          : nextCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    if (total == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: const Text(
          "Henüz e-gazete bulunamadı.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final visibleCount = _visibleCount.clamp(0, total);
    final hasMore = visibleCount < total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$visibleCount / $total gazete gösteriliyor",
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        widget.homeState._newspaperListGrid(
          context,
          widget.isWeb,
          widget.items,
          visibleCount,
        ),
        if (hasMore) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.expand_more),
              label: Text("Daha Fazla Göster (${total - visibleCount})"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Widget _statusChip(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _BookBrowseBody extends StatefulWidget {
  final _HomeResponsiveScreenState homeState;

  const _BookBrowseBody({required this.homeState});

  @override
  State<_BookBrowseBody> createState() => _BookBrowseBodyState();
}

class _BookBrowseBodyState extends State<_BookBrowseBody> {
  static const String _allAuthors = "__all_authors__";
  static const String _allCategories = "__all_categories__";

  String _selectedAuthor = _allAuthors;
  String _selectedCategory = _allCategories;

  String _authorName(Map<String, dynamic> book) {
    final rel = book["author_rel"];
    if (rel is Map && rel["name"] != null) {
      final name = rel["name"].toString().trim();
      if (name.isNotEmpty) return name;
    }
    final raw = book["author"]?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return "Bilinmeyen Yazar";
  }

  String _categoryName(Map<String, dynamic> book) {
    final rel = book["category_rel"];
    if (rel is Map && rel["name"] != null) {
      final name = rel["name"].toString().trim();
      if (name.isNotEmpty) return name;
    }
    final raw = book["category"]?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return "Diğer";
  }

  List<String> _authorOptions(List<Map<String, dynamic>> books) {
    final options = books.map(_authorName).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  List<String> _categoryOptions(List<Map<String, dynamic>> books) {
    final options = books.map(_categoryName).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  List<Map<String, dynamic>> _filteredBooks(List<Map<String, dynamic>> books) {
    return books.where((book) {
      final byAuthor =
          _selectedAuthor == _allAuthors ||
          _authorName(book) == _selectedAuthor;
      final byCategory =
          _selectedCategory == _allCategories ||
          _categoryName(book) == _selectedCategory;
      return byAuthor && byCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.homeState.books;
    final cart = context.watch<CartProvider>();
    final isWeb = MediaQuery.of(context).size.width > 900;
    final isTablet = isTabletLayout(context);
    final authorOptions = _authorOptions(books);
    final categoryOptions = _categoryOptions(books);
    final filtered = _filteredBooks(books);

    const spacing = 14.0;
    final textScaler = MediaQuery.textScalerOf(context);
    final titleHeight = textScaler.scale(15) * 1.3 * 2;
    final authorHeight = textScaler.scale(12) * 1.25;
    final rowHeight = 36.0;
    const verticalGaps = 4.0;
    final contentPadding = (isWeb ? 8.0 : 9.0) * 2;
    final imageHeight = isWeb ? 140.0 : 138.0;
    const safetyMargin = 8.0;
    final cardHeight =
        imageHeight +
        contentPadding +
        verticalGaps +
        titleHeight +
        authorHeight +
        rowHeight +
        safetyMargin;
    final crossAxisCount = isWeb ? 4 : (isTablet ? 3 : 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = isWeb
                  ? (((constraints.maxWidth - 10) / 2).clamp(
                      240.0,
                      360.0,
                    )).toDouble()
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedAuthor,
                      decoration: const InputDecoration(
                        labelText: "Yazar",
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: _allAuthors,
                          child: Text("Tüm Yazarlar"),
                        ),
                        ...authorOptions.map(
                          (author) => DropdownMenuItem<String>(
                            value: author,
                            child: Text(author),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedAuthor = value ?? _allAuthors);
                      },
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: "Kategori",
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: _allCategories,
                          child: Text("Tüm Kategoriler"),
                        ),
                        ...categoryOptions.map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(
                          () => _selectedCategory = value ?? _allCategories,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "${filtered.length} kitap listeleniyor",
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: const Text(
              "Seçilen filtrelerde kitap bulunamadı.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: isWeb
                ? SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 176,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: cardHeight,
                  )
                : SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: cardHeight,
                  ),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final book = filtered[i];
              final effectivePrice = widget.homeState._effectiveBookPrice(book);
              final item = CartItem(
                id: "book-${book["id"]}",
                title: book["title"] ?? "",
                subtitle: _authorName(book),
                imageUrl: book["cover_url"] ?? "",
                price: effectivePrice,
                quantity: 1,
                type: CartItemType.book,
                metadata: {"productId": book["id"]},
              );
              final alreadyInCart = cart.contains(item);
              final purchased = widget.homeState._hasPurchased(
                "book",
                widget.homeState._toInt(book["id"]),
              );
              final isFree = effectivePrice <= 0;
              final card = _bookCard(
                {
                  "image": book["cover_url"],
                  "title": book["title"],
                  "author": _authorName(book),
                  "salePrice": book["price"],
                  "campaignPrice": book["discount_price"],
                },
                false,
                bookStyle: true,
                hideAction: purchased || isFree,
                onAdd: alreadyInCart || isFree
                    ? null
                    : () => _addToCart(context, cart, item),
                onTap: () {
                  widget.homeState._openProductDetail(
                    widget.homeState._mapBookDetail(book),
                  );
                },
              );
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: isWeb ? 160 : 146, child: card),
              );
            },
          ),
      ],
    );
  }
}

class _MagazineBrowseScreen extends StatefulWidget {
  final _HomeResponsiveScreenState homeState;

  const _MagazineBrowseScreen({required this.homeState});

  @override
  State<_MagazineBrowseScreen> createState() => _MagazineBrowseScreenState();
}

class _MagazineBrowseScreenState extends State<_MagazineBrowseScreen> {
  final Map<int, Future<List<Map<String, dynamic>>>> _issuesFutures = {};

  Future<List<Map<String, dynamic>>> _issuesFor(int magazineId) {
    return _issuesFutures.putIfAbsent(
      magazineId,
      () async => widget.homeState._magService.getPublicIssues(magazineId),
    );
  }

  DateTime? _issueDate(Map<String, dynamic> issue) {
    final raw =
        issue["added_at"]?.toString() ?? issue["created_at"]?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool _isWithinAccessWindow({
    required DateTime issueDate,
    required DateTime start,
    required DateTime end,
  }) {
    final issueDay = DateTime(issueDate.year, issueDate.month, issueDate.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return !issueDay.isBefore(startDay) && !issueDay.isAfter(endDay);
  }

  Widget _browseMagazineCard(BuildContext context, Map<String, dynamic> mag) {
    final category = (mag["category"] ?? "").toString().trim();
    final description = (mag["description"] ?? "").toString().trim();
    final hasAccess = widget.homeState._hasPurchased(
      "magazine",
      widget.homeState._toInt(mag["id"]),
    );

    return SizedBox(
      width: 146,
      child: _magazineCard(
        {
          "image": mag["cover_image_url"],
          "title": mag["name"],
          "desc": category.isNotEmpty ? category : description,
          "price": hasAccess ? "" : "Fiyat için tıkla",
        },
        imageHeight: 148,
        hideAction: hasAccess,
        onAdd: hasAccess
            ? null
            : () => widget.homeState._openProductDetail(
                widget.homeState._mapMagazineDetail(mag),
              ),
        onTap: () => widget.homeState._openProductDetail(
          widget.homeState._mapMagazineDetail(mag),
        ),
      ),
    );
  }

  Widget _issueCard({
    required BuildContext context,
    required Map<String, dynamic> mag,
    required Map<String, dynamic> issue,
  }) {
    final issueNumber = (issue["issue_number"] ?? "").toString();
    final label = issueNumber.isEmpty ? "Sayı" : "Sayı $issueNumber";
    final photo = (issue["photo_url"] ?? mag["cover_image_url"] ?? "")
        .toString();
    final imageUrl = UploadService.normalizeUrl(photo);

    return Container(
      width: 142,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: safeImage(
              imageUrl,
              height: 132,
              width: double.infinity,
              fit: BoxFit.cover,
              fallbackIcon: Icons.auto_stories,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: _cardActionButton(
                    label: "Detay",
                    onPressed: () {
                      final detail = widget.homeState._buildMagazineIssueDetail(
                        issue: issue,
                        issueNumber: label,
                        magazineId: widget.homeState._toInt(mag["id"]) ?? 0,
                        magazineName: (mag["name"] ?? "").toString(),
                        imageUrl: photo,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(detail: detail),
                        ),
                      );
                    },
                    icon: Icons.visibility_outlined,
                    variant: _CardActionVariant.neutral,
                    height: 34,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.homeState._hideMagazines) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text("E-Dergiler"),
          elevation: 1,
        ),
        body: const Center(
          child: Text("Bu sürümde E-Dergiler içeriği gizlidir."),
        ),
      );
    }
    final access = context.watch<AccessProvider>();
    final mags = widget.homeState._orderedMagazinesForListing();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("E-Dergiler"),
        elevation: 1,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: mags.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (context, i) {
            final mag = mags[i];
            final magId = widget.homeState._toInt(mag["id"]);
            if (magId == null) return const SizedBox.shrink();

            final start = access.startDate("magazine", itemId: magId);
            final end = access.expiry("magazine", itemId: magId);
            final hasMagazineAccess = access.hasAccess(
              "magazine",
              itemId: magId,
            );

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _issuesFor(magId),
              builder: (context, snap) {
                final issues = snap.data ?? const <Map<String, dynamic>>[];

                return SizedBox(
                  height: 264,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 1 + issues.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, idx) {
                      if (idx == 0) return _browseMagazineCard(context, mag);
                      final issue = issues[idx - 1];
                      final issueId = widget.homeState._toInt(issue["id"]);
                      final directIssueAccess = access.hasAccess(
                        "magazine_issue",
                        itemId: issueId,
                      );
                      final issueDate = _issueDate(issue);
                      final windowAccess =
                          hasMagazineAccess &&
                          start != null &&
                          end != null &&
                          issueDate != null &&
                          _isWithinAccessWindow(
                            issueDate: issueDate,
                            start: start,
                            end: end,
                          );
                      return _issueCard(
                        context: context,
                        mag: mag,
                        issue: issue,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AccessItem {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? statusLabel;
  final Color? statusColor;
  final VoidCallback? onTap;

  _AccessItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.statusLabel,
    this.statusColor,
    this.onTap,
  });
}
