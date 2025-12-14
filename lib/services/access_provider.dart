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
  final Map<String, Map<int?, DateTime?>> _expires = {
    "book": <int?, DateTime?>{},
    "magazine": <int?, DateTime?>{},
    "magazine_issue": <int?, DateTime?>{},
    "newspaper_subscription": <int?, DateTime?>{},
  };

  bool hasAccess(String type, {int? itemId}) {
    final set = _access[type] ?? {};
    // subscriptions may have null itemId
    if (itemId == null) return set.isNotEmpty;
    return set.contains(itemId);
  }

  DateTime? expiry(String type, {int? itemId}) {
    return _expires[type]?[itemId];
  }

  Future<void> load(int userId) async {
    _loading = true;
    notifyListeners();
    try {
      final entries = await _service.getAll(userId: userId);
      for (final key in _access.keys) {
        _access[key] = <int?>{};
        _expires[key] = <int?, DateTime?>{};
      }
      for (final e in entries) {
        final type = (e["item_type"] ?? "").toString();
        final itemId = e["item_id"] as int?;
        _access.putIfAbsent(type, () => <int?>{}).add(itemId);
        final expiresRaw = e["expires_at"]?.toString();
        final expDt = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
        _expires.putIfAbsent(type, () => <int?, DateTime?>{})[itemId] = expDt;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    for (final key in _access.keys) {
      _access[key]!.clear();
      _expires[key]!.clear();
    }
    notifyListeners();
  }
}
