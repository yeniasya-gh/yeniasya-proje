import 'package:flutter/material.dart';

import 'user_content_access_service.dart';

class AccessProvider extends ChangeNotifier {
  final _service = UserContentAccessService();

  bool _loading = false;
  bool get loading => _loading;

  final Map<String, Set<int?>> _access = {
    "book": <int?>{},
    "magazine": <int?>{},
    "magazine_issue": <int?>{},
    "newspaper_subscription": <int?>{},
  };

  bool hasAccess(String type, {int? itemId}) {
    final set = _access[type] ?? {};
    // subscriptions may have null itemId
    if (itemId == null) return set.isNotEmpty;
    return set.contains(itemId);
  }

  Future<void> load(int userId) async {
    _loading = true;
    notifyListeners();
    try {
      final entries = await _service.getAll(userId: userId);
      for (final key in _access.keys) {
        _access[key] = <int?>{};
      }
      for (final e in entries) {
        final type = (e["item_type"] ?? "").toString();
        final itemId = e["item_id"] as int?;
        _access.putIfAbsent(type, () => <int?>{}).add(itemId);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    for (final key in _access.keys) {
      _access[key]!.clear();
    }
    notifyListeners();
  }
}
