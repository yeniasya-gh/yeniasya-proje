import 'package:flutter/foundation.dart';

class LoadingManager extends ChangeNotifier {
  LoadingManager._internal();
  static final LoadingManager instance = LoadingManager._internal();

  bool _loading = false;
  bool get loading => _loading;

  void show() {
    _loading = true;
    notifyListeners();
  }

  void hide() {
    _loading = false;
    notifyListeners();
  }
}