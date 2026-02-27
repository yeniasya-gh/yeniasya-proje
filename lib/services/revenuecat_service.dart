import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:purchases_flutter/purchases_flutter.dart";
import "package:purchases_ui_flutter/purchases_ui_flutter.dart";

import "../config/revenuecat_config.dart";
import "../models/app_user.dart";
import "auth/auth_token_store.dart";
import "revenuecat_backend_service.dart";

class RevenueCatService with ChangeNotifier {
  final RevenueCatBackendService _backendService = RevenueCatBackendService();
  static const Duration _backendSyncDedupWindow = Duration(seconds: 4);
  static const Duration _backendEventDedupWindow = Duration(seconds: 2);

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isLoadingOfferings = false;
  bool _isPaywallInProgress = false;
  bool _isRestoreInProgress = false;
  bool _listenerAttached = false;
  String? _currentAppUserId;
  String? _expectedAppUserId;
  int? _currentDbUserId;
  String? _lastSyncedIdentity;
  String? _errorMessage;
  String? _lastBackendWarning;
  DateTime? _lastBackendSyncAt;
  String? _lastBackendSyncSource;
  bool? _lastBackendSyncSuccess;
  String? _lastBackendSyncError;
  DateTime? _lastBackendEventAt;
  String? _lastBackendEventResult;
  bool? _lastBackendEventSuccess;
  String? _lastBackendEventError;
  String? _lastBackendSyncFingerprint;
  DateTime? _lastBackendSyncAttemptAt;
  String? _lastBackendEventFingerprint;
  DateTime? _lastBackendEventAttemptAt;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  PaywallResult? _lastPaywallResult;
  DateTime? _lastUpdatedAt;

  bool get isInitialized => _isInitialized;
  bool get isLoadingOfferings => _isLoadingOfferings;
  bool get isPaywallInProgress => _isPaywallInProgress;
  bool get isRestoreInProgress => _isRestoreInProgress;
  String? get errorMessage => _errorMessage;
  String? get lastBackendWarning => _lastBackendWarning;
  DateTime? get lastBackendSyncAt => _lastBackendSyncAt;
  String? get lastBackendSyncSource => _lastBackendSyncSource;
  bool? get lastBackendSyncSuccess => _lastBackendSyncSuccess;
  String? get lastBackendSyncError => _lastBackendSyncError;
  DateTime? get lastBackendEventAt => _lastBackendEventAt;
  String? get lastBackendEventResult => _lastBackendEventResult;
  bool? get lastBackendEventSuccess => _lastBackendEventSuccess;
  String? get lastBackendEventError => _lastBackendEventError;
  String? get currentAppUserId => _currentAppUserId;
  String? get expectedAppUserId => _expectedAppUserId;
  int? get currentDbUserId => _currentDbUserId;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;
  PaywallResult? get lastPaywallResult => _lastPaywallResult;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  String get identityStatusLabel {
    final expected = _expectedAppUserId?.trim();
    if (expected == null || expected.isEmpty) return "Misafir";
    final current = _currentAppUserId?.trim();
    if (current == null || current.isEmpty) return "Bekleniyor";
    return current == expected ? "Eşleşti" : "Eşleşmedi";
  }

  bool get isIdentityMatched => identityStatusLabel != "Eşleşmedi";

  bool get supportsNativePurchaseUi =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isYeniasyaProActive =>
      _customerInfo
          ?.entitlements
          .all[RevenueCatConfig.entitlementYeniasyaPro]
          ?.isActive ==
      true;

  String get newspaperStatusLabel =>
      isYeniasyaProActive ? "Abonelik Var" : "Abonelik Yok";

  Offering? get currentOffering =>
      _offerings?.getOffering(RevenueCatConfig.offeringId) ??
      _offerings?.current;

  Package? get monthlyPackage =>
      currentOffering?.getPackage(RevenueCatConfig.monthlyPackageId) ??
      currentOffering?.monthly;

  Package? get yearlyPackage =>
      currentOffering?.getPackage(RevenueCatConfig.yearlyPackageId) ??
      currentOffering?.annual;

  Package? get lifetimePackage =>
      currentOffering?.getPackage(RevenueCatConfig.lifetimePackageId) ??
      currentOffering?.lifetime;

  List<Package> get configuredPackages => [
    if (monthlyPackage != null) monthlyPackage!,
    if (yearlyPackage != null) yearlyPackage!,
    if (lifetimePackage != null) lifetimePackage!,
  ];

  Future<void> initialize({AppUser? appUser}) async {
    if (!supportsNativePurchaseUi) {
      _errorMessage = null;
      notifyListeners();
      return;
    }
    if (kReleaseMode && RevenueCatConfig.isTestApiKey) {
      _errorMessage = "Release ortamında test RevenueCat API key kullanılamaz.";
      notifyListeners();
      return;
    }

    if (appUser != null) {
      _expectedAppUserId = appUser.revenueCatUserId;
    }
    if (_isInitializing) return;
    if (_isInitialized) {
      if (!_listenerAttached) {
        Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
        _listenerAttached = true;
      }
      if (appUser != null) {
        await _setSubscriberAttributes(appUser);
      }
      return;
    }

    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final configured = await Purchases.isConfigured;
      if (!configured) {
        await Purchases.setLogLevel(
          kDebugMode ? LogLevel.debug : LogLevel.info,
        );
        final initialAppUserId = appUser?.revenueCatUserId;
        final config = PurchasesConfiguration(RevenueCatConfig.apiKey)
          ..appUserID = initialAppUserId;
        await Purchases.configure(config);
      }

      if (!_listenerAttached) {
        Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
        _listenerAttached = true;
      }

      _isInitialized = true;
      _currentAppUserId = await Purchases.appUserID;
      _currentDbUserId = appUser?.id;
      if (appUser != null) {
        await _setSubscriberAttributes(appUser);
      }
      await loadOfferings();
      await refreshCustomerInfo(source: "sdk_initialize", userId: appUser?.id);
    } on PlatformException catch (e) {
      _errorMessage = _formatPurchasesPlatformError(e);
    } catch (e) {
      _errorMessage = "RevenueCat başlatılamadı: $e";
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> syncWithAuthUser(AppUser? user) async {
    _expectedAppUserId = user?.revenueCatUserId;
    _currentDbUserId = user?.id;

    if (!supportsNativePurchaseUi) {
      _currentAppUserId = user?.revenueCatUserId;
      if (user != null) {
        await _refreshBackendSubscription(
          user: user,
          source: "auth_sync_non_native",
        );
      }
      notifyListeners();
      return;
    }

    await initialize(appUser: user);
    if (!_isInitialized) return;

    final identity = user?.revenueCatUserId ?? "__anonymous__";
    if (_lastSyncedIdentity == identity && _customerInfo != null) {
      return;
    }

    _errorMessage = null;
    try {
      if (user == null) {
        _currentDbUserId = null;
        try {
          final info = await Purchases.logOut();
          _currentAppUserId = await Purchases.appUserID;
          _updateCustomerInfo(info, source: "auth_logout");
        } on PlatformException catch (e) {
          final code = PurchasesErrorHelper.getErrorCode(e);
          if (code != PurchasesErrorCode.logOutWithAnonymousUserError) {
            rethrow;
          }
          _currentAppUserId = await Purchases.appUserID;
        }
      } else {
        final appUserId = user.revenueCatUserId;
        if (_currentAppUserId != appUserId) {
          final logInResult = await Purchases.logIn(appUserId);
          _currentAppUserId = appUserId;
          _updateCustomerInfo(logInResult.customerInfo, source: "auth_login");
        }
        _currentDbUserId = user.id;
        await _setSubscriberAttributes(user);
      }

      _lastSyncedIdentity = identity;
      await refreshCustomerInfo(source: "auth_sync", userId: user?.id);
      await loadOfferings();
    } on PlatformException catch (e) {
      _errorMessage = _formatPurchasesPlatformError(e);
      notifyListeners();
    } catch (e) {
      _errorMessage = "RevenueCat kullanıcı senkronu başarısız: $e";
      notifyListeners();
    }
  }

  Future<void> loadOfferings() async {
    if (!supportsNativePurchaseUi || !_isInitialized) return;
    _isLoadingOfferings = true;
    notifyListeners();
    try {
      _offerings = await Purchases.getOfferings();
      _errorMessage = null;
    } on PlatformException catch (e) {
      _errorMessage = _formatPurchasesPlatformError(e);
    } catch (e) {
      _errorMessage = "Teklifler alınamadı: $e";
    } finally {
      _isLoadingOfferings = false;
      notifyListeners();
    }
  }

  Future<void> refreshCustomerInfo({
    String source = "manual_refresh",
    int? userId,
  }) async {
    if (!supportsNativePurchaseUi || !_isInitialized) return;
    try {
      final info = await Purchases.getCustomerInfo();
      _updateCustomerInfo(info, source: source, userId: userId);
    } on PlatformException catch (e) {
      _errorMessage = _formatPurchasesPlatformError(e);
      notifyListeners();
    } catch (e) {
      _errorMessage = "Abonelik bilgisi alınamadı: $e";
      notifyListeners();
    }
  }

  Future<PaywallResult> presentYeniasyaProPaywall({int? userId}) async {
    if (!supportsNativePurchaseUi) {
      _errorMessage = "Paywall bu platformda desteklenmiyor.";
      notifyListeners();
      return PaywallResult.error;
    }

    await initialize();
    if (!_isInitialized) return PaywallResult.error;

    _isPaywallInProgress = true;
    _errorMessage = null;
    _lastBackendWarning = null;
    notifyListeners();

    try {
      if (_offerings == null) {
        await loadOfferings();
      }
      final result = await RevenueCatUI.presentPaywallIfNeeded(
        RevenueCatConfig.entitlementYeniasyaPro,
        offering: currentOffering,
      );
      _lastPaywallResult = result;
      if (result == PaywallResult.error &&
          (_errorMessage == null || _errorMessage!.isEmpty)) {
        _errorMessage = "Satın alma işlemi tamamlanamadı.";
      }
      if (result == PaywallResult.cancelled) {
        _errorMessage = "İşlem iptal edildi.";
      }

      final success =
          result == PaywallResult.purchased || result == PaywallResult.restored;
      await _safeReportPaywallEvent(
        source: "paywall",
        result: result.name,
        success: success,
        userId: userId,
      );

      await refreshCustomerInfo(
        source: "paywall_${result.name}",
        userId: userId,
      );
      return result;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      _errorMessage = code == PurchasesErrorCode.purchaseCancelledError
          ? "İşlem iptal edildi."
          : _formatPurchasesPlatformError(e);
      await _safeReportPaywallEvent(
        source: "paywall_exception",
        result: "error",
        success: false,
        userId: userId,
        message: _errorMessage,
      );
      return PaywallResult.error;
    } catch (e) {
      _errorMessage = "Paywall açılırken hata oluştu: $e";
      await _safeReportPaywallEvent(
        source: "paywall_exception",
        result: "error",
        success: false,
        userId: userId,
        message: _errorMessage,
      );
      return PaywallResult.error;
    } finally {
      _isPaywallInProgress = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases({int? userId}) async {
    if (!supportsNativePurchaseUi) return;
    _isRestoreInProgress = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final info = await Purchases.restorePurchases();
      _updateCustomerInfo(info, source: "restore", userId: userId);
      final isActive =
          info
              .entitlements
              .all[RevenueCatConfig.entitlementYeniasyaPro]
              ?.isActive ==
          true;
      if (!isActive) {
        _errorMessage = "Geri yüklenecek aktif abonelik bulunamadı.";
      }
      await _safeReportPaywallEvent(
        source: "restore",
        result: isActive ? "restored" : "no_active_subscription",
        success: isActive,
        userId: userId,
        message: isActive ? null : _errorMessage,
      );
    } on PlatformException catch (e) {
      _errorMessage = _formatPurchasesPlatformError(e);
      await _safeReportPaywallEvent(
        source: "restore",
        result: "error",
        success: false,
        userId: userId,
        message: _errorMessage,
      );
    } catch (e) {
      _errorMessage = "Satın alımlar geri yüklenemedi: $e";
      await _safeReportPaywallEvent(
        source: "restore",
        result: "error",
        success: false,
        userId: userId,
        message: _errorMessage,
      );
    } finally {
      _isRestoreInProgress = false;
      notifyListeners();
    }
  }

  Future<void> presentCustomerCenter({int? userId}) async {
    if (!supportsNativePurchaseUi) {
      _errorMessage = "Customer Center bu platformda desteklenmiyor.";
      notifyListeners();
      return;
    }
    try {
      await RevenueCatUI.presentCustomerCenter(
        onRestoreCompleted: (customerInfo) {
          _updateCustomerInfo(
            customerInfo,
            source: "customer_center_restore",
            userId: userId,
          );
        },
        onRestoreFailed: (error) {
          _errorMessage = error.message;
          notifyListeners();
        },
      );
      await refreshCustomerInfo(
        source: "customer_center_close",
        userId: userId,
      );
    } on PlatformException catch (e) {
      _errorMessage = _formatPurchasesPlatformError(e);
      notifyListeners();
    } catch (e) {
      _errorMessage = "Customer Center açılırken hata oluştu: $e";
      notifyListeners();
    }
  }

  void clearTransientState() {
    _errorMessage = null;
    _lastBackendWarning = null;
    _lastPaywallResult = null;
    notifyListeners();
  }

  Future<void> _setSubscriberAttributes(AppUser user) async {
    final attrs = <String, String>{
      "user_id": user.id.toString(),
      "rc_user_id": user.revenueCatUserId,
      "email": user.email,
      if (user.phone != null && user.phone!.trim().isNotEmpty)
        "phone": user.phone!.trim(),
      "role": user.roleName,
    };
    await Purchases.setAttributes(attrs);
    await Purchases.setEmail(user.email);
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _updateCustomerInfo(info, source: "listener");
  }

  void _updateCustomerInfo(
    CustomerInfo info, {
    required String source,
    int? userId,
  }) {
    if (_customerInfo == info) return;
    _customerInfo = info;
    _lastUpdatedAt = DateTime.now();
    _errorMessage = null;
    notifyListeners();
    unawaited(
      _safeSyncSubscriptionToBackend(
        source: source,
        userId: userId,
        info: info,
      ),
    );
  }

  int? _resolvedBackendUserId(int? userId) {
    return userId ?? _currentDbUserId ?? int.tryParse(_currentAppUserId ?? "");
  }

  bool _shouldSkipBackendSync(String fingerprint) {
    final now = DateTime.now();
    final shouldSkip =
        _lastBackendSyncFingerprint == fingerprint &&
        _lastBackendSyncAttemptAt != null &&
        now.difference(_lastBackendSyncAttemptAt!) < _backendSyncDedupWindow;
    _lastBackendSyncFingerprint = fingerprint;
    _lastBackendSyncAttemptAt = now;
    return shouldSkip;
  }

  bool _shouldSkipBackendEvent(String fingerprint) {
    final now = DateTime.now();
    final shouldSkip =
        _lastBackendEventFingerprint == fingerprint &&
        _lastBackendEventAttemptAt != null &&
        now.difference(_lastBackendEventAttemptAt!) < _backendEventDedupWindow;
    _lastBackendEventFingerprint = fingerprint;
    _lastBackendEventAttemptAt = now;
    return shouldSkip;
  }

  String _syncFingerprint({
    required String source,
    required String entitlementId,
    required bool isActive,
    required int? userId,
    String? productIdentifier,
    String? expirationDate,
    List<String>? activeSubscriptions,
  }) {
    final subscriptions = [...?activeSubscriptions]..sort();
    return [
      source,
      entitlementId,
      isActive ? "1" : "0",
      _currentAppUserId ?? "",
      _expectedAppUserId ?? "",
      userId?.toString() ?? "",
      productIdentifier ?? "",
      expirationDate ?? "",
      subscriptions.join(","),
    ].join("|");
  }

  String _eventFingerprint({
    required String source,
    required String result,
    required bool success,
    required int? userId,
    String? message,
    List<String>? productIdentifiers,
  }) {
    final products = [...?productIdentifiers]..sort();
    return [
      source,
      result,
      success ? "1" : "0",
      _currentAppUserId ?? "",
      _expectedAppUserId ?? "",
      userId?.toString() ?? "",
      message ?? "",
      products.join(","),
    ].join("|");
  }

  bool _hasBackendAuthToken() {
    final token = AuthTokenStore.token;
    return token != null && token.trim().isNotEmpty;
  }

  Future<void> _refreshBackendSubscription({
    required AppUser user,
    required String source,
  }) async {
    if (!_hasBackendAuthToken()) {
      if (kDebugMode) {
        debugPrint(
          "RevenueCat backend refresh skipped: missing auth token (source=$source)",
        );
      }
      return;
    }
    try {
      await _backendService.refreshSubscription(
        source: source,
        entitlementId: RevenueCatConfig.entitlementYeniasyaPro,
        appUserId: user.revenueCatUserId,
        expectedAppUserId: user.revenueCatUserId,
        identityMatched: true,
        userId: user.id,
      );
      _lastBackendSyncAt = DateTime.now();
      _lastBackendSyncSource = source;
      _lastBackendSyncSuccess = true;
      _lastBackendSyncError = null;
      _lastBackendWarning = null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("RevenueCat backend refresh warning: $e");
      }
      _lastBackendSyncAt = DateTime.now();
      _lastBackendSyncSource = source;
      _lastBackendSyncSuccess = false;
      _lastBackendSyncError = e.toString();
      _lastBackendWarning =
          "Abonelik durumu sunucudan güncellenirken sorun oluştu.";
    }
  }

  Future<void> _safeSyncSubscriptionToBackend({
    required String source,
    required CustomerInfo info,
    int? userId,
  }) async {
    try {
      final entitlement =
          info.entitlements.all[RevenueCatConfig.entitlementYeniasyaPro];
      final identityMatched = isIdentityMatched;
      final resolvedUserId = _resolvedBackendUserId(userId);
      if (!_hasBackendAuthToken()) {
        if (kDebugMode) {
          debugPrint(
            "RevenueCat backend sync skipped: missing auth token (source=$source)",
          );
        }
        return;
      }
      final syncFingerprint = _syncFingerprint(
        source: source,
        entitlementId: RevenueCatConfig.entitlementYeniasyaPro,
        isActive: entitlement?.isActive == true,
        userId: resolvedUserId,
        productIdentifier: entitlement?.productIdentifier,
        expirationDate: entitlement?.expirationDate,
        activeSubscriptions: info.activeSubscriptions,
      );
      if (_shouldSkipBackendSync(syncFingerprint)) {
        if (kDebugMode) {
          debugPrint(
            "RevenueCat backend sync skipped (dedupe): source=$source",
          );
        }
        return;
      }
      await _backendService.syncSubscription(
        source: source,
        entitlementId: RevenueCatConfig.entitlementYeniasyaPro,
        isActive: entitlement?.isActive == true,
        appUserId: _currentAppUserId,
        expectedAppUserId: _expectedAppUserId,
        identityMatched: identityMatched,
        userId: resolvedUserId,
        productIdentifier: entitlement?.productIdentifier,
        expirationDate: entitlement?.expirationDate,
        activeSubscriptions: info.activeSubscriptions,
        customerInfoRaw: _customerInfoSummary(info),
      );
      _lastBackendSyncAt = DateTime.now();
      _lastBackendSyncSource = source;
      _lastBackendSyncSuccess = true;
      _lastBackendSyncError = null;
      _lastBackendWarning = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("RevenueCat backend sync warning: $e");
      }
      _lastBackendSyncAt = DateTime.now();
      _lastBackendSyncSource = source;
      _lastBackendSyncSuccess = false;
      _lastBackendSyncError = e.toString();
      _lastBackendWarning =
          "Abonelik durumu sunucuya aktarılırken sorun oluştu.";
      notifyListeners();
    }
  }

  Future<void> _safeReportPaywallEvent({
    required String source,
    required String result,
    required bool success,
    int? userId,
    String? message,
  }) async {
    try {
      final identityMatched = isIdentityMatched;
      final resolvedUserId = _resolvedBackendUserId(userId);
      if (!_hasBackendAuthToken()) {
        if (kDebugMode) {
          debugPrint(
            "RevenueCat backend event skipped: missing auth token (source=$source result=$result)",
          );
        }
        return;
      }
      final productIdentifiers = configuredPackages
          .map((p) => p.storeProduct.identifier)
          .toList();
      final eventFingerprint = _eventFingerprint(
        source: source,
        result: result,
        success: success,
        userId: resolvedUserId,
        message: message,
        productIdentifiers: productIdentifiers,
      );
      if (_shouldSkipBackendEvent(eventFingerprint)) {
        if (kDebugMode) {
          debugPrint(
            "RevenueCat backend event skipped (dedupe): source=$source result=$result",
          );
        }
        return;
      }
      await _backendService.reportPaywallEvent(
        source: source,
        entitlementId: RevenueCatConfig.entitlementYeniasyaPro,
        result: result,
        success: success,
        message: message,
        appUserId: _currentAppUserId,
        expectedAppUserId: _expectedAppUserId,
        identityMatched: identityMatched,
        userId: resolvedUserId,
        productIdentifiers: productIdentifiers,
        metadata: {
          "offering": currentOffering?.identifier,
          "entitlementActive": isYeniasyaProActive,
          "identityStatus": identityStatusLabel,
        },
      );
      _lastBackendEventAt = DateTime.now();
      _lastBackendEventResult = result;
      _lastBackendEventSuccess = true;
      _lastBackendEventError = null;
      _lastBackendWarning = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("RevenueCat backend event warning: $e");
      }
      _lastBackendEventAt = DateTime.now();
      _lastBackendEventResult = result;
      _lastBackendEventSuccess = false;
      _lastBackendEventError = e.toString();
      _lastBackendWarning =
          "Abonelik olayları sunucuya aktarılırken sorun oluştu.";
      notifyListeners();
    }
  }

  Map<String, dynamic> _customerInfoSummary(CustomerInfo info) {
    final entitlement =
        info.entitlements.all[RevenueCatConfig.entitlementYeniasyaPro];
    return <String, dynamic>{
      "appUserId": _currentAppUserId,
      "expectedAppUserId": _expectedAppUserId,
      "identityStatus": identityStatusLabel,
      "originalAppUserId": info.originalAppUserId,
      "requestDate": info.requestDate,
      "activeSubscriptions": info.activeSubscriptions,
      "allPurchasedProductIdentifiers": info.allPurchasedProductIdentifiers,
      "entitlement": {
        "identifier": entitlement?.identifier,
        "isActive": entitlement?.isActive,
        "willRenew": entitlement?.willRenew,
        "productIdentifier": entitlement?.productIdentifier,
        "expirationDate": entitlement?.expirationDate,
      },
    };
  }

  String _formatPurchasesPlatformError(PlatformException e) {
    try {
      final code = PurchasesErrorHelper.getErrorCode(e);
      switch (code) {
        case PurchasesErrorCode.purchaseCancelledError:
          return "İşlem iptal edildi.";
        case PurchasesErrorCode.networkError:
        case PurchasesErrorCode.offlineConnectionError:
          return "Ağ hatası. İnternet bağlantınızı kontrol edin.";
        case PurchasesErrorCode.invalidCredentialsError:
          return "RevenueCat API anahtarı geçersiz veya eksik.";
        case PurchasesErrorCode.configurationError:
          return "RevenueCat yapılandırması hatalı.";
        case PurchasesErrorCode.productNotAvailableForPurchaseError:
          return "Ürün şu anda satın alınamıyor.";
        default:
          final details = e.message?.trim();
          if (details != null && details.isNotEmpty) {
            return "Satın alma hatası: $details";
          }
          return "Satın alma işlemi sırasında bir hata oluştu.";
      }
    } catch (_) {
      final details = e.message?.trim();
      if (details != null && details.isNotEmpty) {
        return "Satın alma hatası: $details";
      }
      return "Satın alma işlemi sırasında bir hata oluştu.";
    }
  }
}
