import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class AppLaunchScreen extends StatelessWidget {
  final String status;
  final bool showProgress;

  const AppLaunchScreen({
    super.key,
    this.status = "Uygulama hazırlanıyor",
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB71C1C);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBEAEA),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFECC0C0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    "assets/images/logo.png",
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Yeni Asya Dijital",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Color(0xFF111111),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6D6D6D),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showProgress) ...[
                  const SizedBox(height: 22),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppBootstrapScreen extends StatelessWidget {
  final String status;
  final bool showProgress;

  const AppBootstrapScreen({
    super.key,
    this.status = "Uygulama hazırlanıyor",
    this.showProgress = true,
  });

  static bool get _showBrandedLayout {
    if (kIsWeb) return false;
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
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(backgroundColor: Colors.white, body: SizedBox.expand());
    }

    if (_showBrandedLayout) {
      return AppLaunchScreen(status: status, showProgress: showProgress);
    }

    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB71C1C)),
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBootstrapScreen();
  }
}
