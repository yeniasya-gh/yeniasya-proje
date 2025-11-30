import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/auth/auth_provider.dart';
import 'app_screens.dart';
import '/services/auth/screen_access.dart';
import '../screen/login/login_screen.dart';
import '../screen/not_authorized/not_authorized_screen.dart'; 

class RouteGuard {
  static Route<dynamic> guard({
    required BuildContext context,
    required WidgetBuilder builder,
    required String routeName,
  }) {
    final auth = context.read<AuthProvider>();
    final access = AppScreens.accessMap[routeName] ?? ScreenAccess.public;

    if (access == ScreenAccess.public) {
      return MaterialPageRoute(builder: builder);
    }

    if (access == ScreenAccess.authenticated && !auth.isLoggedIn) {
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    }

    if (access == ScreenAccess.admin) {
      if (!auth.isLoggedIn) {
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      }
      if (auth.user?.isAdmin != true) {
        return MaterialPageRoute(builder: (_) => const NotAuthorizedScreen());
      }
    }

    return MaterialPageRoute(builder: builder);
  }
}