import '/services/auth/screen_access.dart';

class AppScreens {
  static final Map<String, ScreenAccess> accessMap = {
    "/home": ScreenAccess.public,
    "/login": ScreenAccess.public,
    "/profile": ScreenAccess.authenticated,
    "/admin": ScreenAccess.admin,
  };
}