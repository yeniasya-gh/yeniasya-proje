import "dart:async";

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import '/screen/home_responsive_screen.dart';
import '/screen/login/login_screen.dart';
import '/screen/splash/splash_screen.dart';
import '/services/auth/auth_provider.dart';
import '/services/cart/cart_provider.dart';
import '/services/access_provider.dart';
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
        if (navigator != null && shouldShowLogin) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
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

  bool get _shouldGateHomeUntilBootstrap {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return false;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ready = !_shouldGateHomeUntilBootstrap;
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

    if (_shouldGateHomeUntilBootstrap && mounted) {
      setState(() => _status = "Oturum hazırlanıyor");
    }

    unawaited(_initializeFirebaseSafely());
    await authProvider.loadSession();
    unawaited(AppErrorReporter.instance.flushPending());

    final user = authProvider.user;
    _lastRevenueCatIdentity = authProvider.isLoggedIn && user != null
        ? "user:${user.id}"
        : "guest";
    _authProvider?.removeListener(_handleAuthChanged);
    _authProvider?.addListener(_handleAuthChanged);

    if (_shouldGateHomeUntilBootstrap && mounted) {
      setState(() => _ready = true);
    }

    unawaited(revenueCatService.syncWithAuthUser(user));
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
        home: _ready
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
