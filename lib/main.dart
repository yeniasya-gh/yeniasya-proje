import "dart:async";

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import '/screen/home_responsive_screen.dart';
import '/services/auth/auth_provider.dart';
import '/services/cart/cart_provider.dart';
import '/services/access_provider.dart';
import '/services/revenuecat_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authProvider = AuthProvider();
  final cartProvider = CartProvider();
  final accessProvider = AccessProvider();
  final revenueCatService = RevenueCatService();

  // Link logout cleanup
  authProvider.onLogout = () async {
    cartProvider.clear();
    accessProvider.clear();
    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeResponsiveScreen(initialUri: Uri.base),
      ),
      (route) => false,
    );
  };

  await authProvider.loadSession();
  await revenueCatService.syncWithAuthUser(authProvider.user);

  String? lastRevenueCatIdentity =
      authProvider.isLoggedIn && authProvider.user != null
      ? "user:${authProvider.user!.id}"
      : "guest";
  authProvider.addListener(() {
    final user = authProvider.user;
    final nextIdentity = authProvider.isLoggedIn && user != null
        ? "user:${user.id}"
        : "guest";
    if (nextIdentity == lastRevenueCatIdentity) return;
    lastRevenueCatIdentity = nextIdentity;
    unawaited(revenueCatService.syncWithAuthUser(user));
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: cartProvider),
        ChangeNotifierProvider.value(value: accessProvider),
        ChangeNotifierProvider.value(value: revenueCatService),
      ],
      child: const AppWrapper(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Uri? initialUri;

  const MyApp({super.key, this.initialUri});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yeni Asya',
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
          bottom: true,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: HomeResponsiveScreen(initialUri: initialUri),
      navigatorKey: rootNavigatorKey,
    );
  }
}

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: MyApp(initialUri: Uri.base),
    );
  }
}
