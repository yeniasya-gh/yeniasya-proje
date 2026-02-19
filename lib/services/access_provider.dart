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
    "ek": <int?>{},
  };
  final Map<String, Map<int?, DateTime?>> _expires = {
    "book": <int?, DateTime?>{},
    "magazine": <int?, DateTime?>{},
    "magazine_issue": <int?, DateTime?>{},
    "newspaper_subscription": <int?, DateTime?>{},
    "ek": <int?, DateTime?>{},
  };
  final Map<String, Map<int?, DateTime?>> _starts = {
    "book": <int?, DateTime?>{},
    "magazine": <int?, DateTime?>{},
    "magazine_issue": <int?, DateTime?>{},
    "newspaper_subscription": <int?, DateTime?>{},
    "ek": <int?, DateTime?>{},
  };

  bool hasAccess(String type, {int? itemId}) {
    final set = _access[type] ?? {};
    // subscriptions or legacy rows may have null itemId
    if (itemId == null) return set.isNotEmpty;
    if (set.contains(null)) return true;
    return set.contains(itemId);
  }

  /// Checks access only for a specific item id (ignores wildcard `null` rows).
  bool hasAccessExact(String type, {required int itemId}) {
    final set = _access[type] ?? {};
    return set.contains(itemId);
  }

  DateTime? expiry(String type, {int? itemId}) {
    return _expires[type]?[itemId];
  }

  DateTime? startDate(String type, {int? itemId}) {
    return _starts[type]?[itemId];
  }

  Future<void> load(int userId) async {
    _loading = true;
    notifyListeners();
    try {
      final entries = await _service.getAll(userId: userId);
      final now = DateTime.now();
      for (final key in _access.keys) {
        _access[key] = <int?>{};
        _expires[key] = <int?, DateTime?>{};
        _starts[key] = <int?, DateTime?>{};
      }
      for (final e in entries) {
        final type = (e["item_type"] ?? "").toString();
        final rawId = e["item_id"];
        int? itemId;
        if (rawId is int) {
          itemId = rawId;
        } else if (rawId != null) {
          itemId = int.tryParse(rawId.toString());
        }
        final expiresRaw = e["expires_at"]?.toString();
        final expDt = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
        if (expDt != null && !expDt.isAfter(now)) {
          continue;
        }
        _access.putIfAbsent(type, () => <int?>{}).add(itemId);
        final expMap = _expires.putIfAbsent(type, () => <int?, DateTime?>{});
        if (!expMap.containsKey(itemId)) {
          expMap[itemId] = expDt;
        }
        final startedRaw = e["started_at"]?.toString();
        final startedDt = startedRaw == null
            ? null
            : DateTime.tryParse(startedRaw);
        final startMap = _starts.putIfAbsent(type, () => <int?, DateTime?>{});
        if (!startMap.containsKey(itemId)) {
          startMap[itemId] = startedDt;
        }
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
      _starts[key]!.clear();
    }
    notifyListeners();
  }
}
