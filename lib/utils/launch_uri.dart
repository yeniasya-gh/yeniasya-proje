import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

Uri currentLaunchUri() {
  if (kIsWeb) {
    final routeName =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (routeName.isNotEmpty) {
      return Uri.parse(routeName);
    }
  }
  return Uri.base;
}
