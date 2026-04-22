import "dart:async";

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import '/screen/home_responsive_screen.dart';
import '/screen/login/login_screen.dart';
import '/screen/splash/splash_screen.dart';
import '/screen/splash/force_update_screen.dart';
import '/services/auth/auth_provider.dart';
import '/services/cart/cart_provider.dart';
import '/services/access_provider.dart';
import '/services/app_version_service.dart';
import '/services/notification_service.dart';
import '/services/revenuecat_service.dart';
import '/services/error/app_error_reporter.dart';
import '/utils/launch_uri.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  AppErrorReporter.instance.attachGlobalHandlers();
  runZonedGuarded(
    () {
      final launchUri = currentLaunchUri();
      debugPrint("Launch URI: $launchUri");

      final authProvider = AuthProvider();
      final cartProvider = CartProvider();
      final accessProvider = AccessProvider();
      final revenueCatService = RevenueCatService();

      // Link logout cleanup
      authProvider.onLogout = (reason) async {
        cartProvider.clear();
        accessProvider.clear();
        final navigator = rootNavigatorKey.currentState;
        final shouldShowLogin =
            reason == AuthLogoutReason.sessionRevoked ||
            reason == AuthLogoutReason.accountDeleted;
        if (shouldShowLogin) {
          // AppBootstrap already rebuilds to the forced login screen.
          // Avoid pushing a second login route on top of the stack, which can
          // leave the user on a blank page when navigating back.
          return;
        }
        navigator?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeResponsiveScreen(initialUri: launchUri),
          ),
          (route) => false,
        );
      };

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: cartProvider),
            ChangeNotifierProvider.value(value: accessProvider),
            ChangeNotifierProvider.value(value: revenueCatService),
          ],
          child: AppBootstrap(initialUri: launchUri),
        ),
      );
    },
    (error, stack) {
      unawaited(
        AppErrorReporter.instance.reportException(
          service: "AppBootstrap",
          operation: "runZonedGuarded",
          error: error,
          stackTrace: stack,
        ),
      );
    },
  );
}

class AppBootstrap extends StatefulWidget {
  final Uri initialUri;

  const AppBootstrap({super.key, required this.initialUri});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap>
    with WidgetsBindingObserver {
  bool _ready = false;
  String _status = "Uygulama hazırlanıyor";
  String? _lastRevenueCatIdentity;
  AuthProvider? _authProvider;
  final AppVersionService _appVersionService = AppVersionService();
  AppVersionGate? _forceUpdateGate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ready = kIsWeb;
    _authProvider = context.read<AuthProvider>();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authProvider?.removeListener(_handleAuthChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final authProvider = _authProvider;
    if (authProvider == null) return;
    unawaited(authProvider.refreshUser());
  }

  Future<void> _bootstrap() async {
    final authProvider = context.read<AuthProvider>();
    final revenueCatService = context.read<RevenueCatService>();
    final accessProvider = context.read<AccessProvider>();

    if (mounted) {
      setState(() => _status = "Sürüm kontrol ediliyor");
    }

    final forceUpdateGate = await _appVersionService.getGateForCurrentApp();
    if (!mounted) return;
    if (forceUpdateGate.forceUpdateRequired) {
      setState(() {
        _forceUpdateGate = forceUpdateGate;
        _status = "Güncelleme gerekli";
        _ready = true;
      });
      return;
    }

    if (mounted) {
      setState(() => _status = "Oturum hazırlanıyor");
    }

    await _initializeFirebaseSafely();
    await authProvider.loadSession();
    unawaited(AppErrorReporter.instance.flushPending());

    final user = authProvider.user;
    _lastRevenueCatIdentity = authProvider.isLoggedIn && user != null
        ? "user:${user.id}"
        : "guest";
    _authProvider?.removeListener(_handleAuthChanged);
    _authProvider?.addListener(_handleAuthChanged);

    if (user != null) {
      await revenueCatService.syncWithAuthUser(user);
      await accessProvider.load(user.id, force: true);
      await NotificationService().registerDeviceToken(userId: user.id);
    } else {
      unawaited(revenueCatService.syncWithAuthUser(user));
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  Future<void> _initializeFirebaseSafely() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error, stackTrace) {
      debugPrint("Firebase initialize failed: $error");
      debugPrintStack(stackTrace: stackTrace);
      unawaited(
        AppErrorReporter.instance.reportException(
          service: "AppBootstrap",
          operation: "Firebase.initializeApp",
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void _handleAuthChanged() {
    final authProvider = _authProvider;
    if (authProvider == null) return;

    final user = authProvider.user;
    final nextIdentity = authProvider.isLoggedIn && user != null
        ? "user:${user.id}"
        : "guest";
    if (nextIdentity == _lastRevenueCatIdentity) return;

    _lastRevenueCatIdentity = nextIdentity;
    unawaited(context.read<RevenueCatService>().syncWithAuthUser(user));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: MyApp(
        home: _forceUpdateGate != null
            ? ForceUpdateScreen(gate: _forceUpdateGate!)
            : _ready
            ? (authProvider.shouldForceLoginScreen
                  ? const LoginScreen()
                  : HomeResponsiveScreen(initialUri: widget.initialUri))
            : AppBootstrapScreen(status: _status),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final Widget home;

  const MyApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yeni Asya Dijital | E-Gazete / E-Dergi / E-Kitap',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      locale: const Locale('tr', 'TR'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.18),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 12,
          selectedItemColor: Colors.red,
          unselectedItemColor: Colors.grey,
        ),
      ),
      builder: (context, child) => ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          bottom: false,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: home,
      navigatorKey: rootNavigatorKey,
    );
  }
}
