class AppUser {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final int roleId;
  final String roleName;
  final String? payUniqe;
  final String? avatarUrl;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.roleId,
    required this.roleName,
    this.payUniqe,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final roleId = _readInt(json["role_id"]) ?? 0;
    final payIdentity = _readPayIdentity(json);
    return AppUser(
      id: _readRequiredInt(json["id"], fieldName: "id"),
      name: _readString(json["name"]) ?? "",
      email: _readString(json["email"]) ?? "",
      phone: _readString(json["phone"]),
      roleId: roleId,
      roleName: _readRoleName(json, fallbackRoleId: roleId),
      payUniqe: payIdentity,
      avatarUrl: _readAvatarUrl(json),
    );
  }

  factory AppUser.fromAuthJson(Map<String, dynamic> json) {
    final roleId = _readInt(json["role_id"]) ?? 0;
    final payIdentity = _readPayIdentity(json);
    return AppUser(
      id: _readRequiredInt(json["id"], fieldName: "id"),
      name: _readString(json["name"]) ?? "",
      email: _readString(json["email"]) ?? "",
      phone: _readString(json["phone"]),
      roleId: roleId,
      roleName: _readRoleName(json, fallbackRoleId: roleId),
      payUniqe: payIdentity,
      avatarUrl: _readAvatarUrl(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "phone": phone,
      "role_id": roleId,
      "role_name": roleName,
      if (avatarUrl != null) "avatar_url": avatarUrl,
      if (payUniqe != null) "payUniqe": payUniqe,
    };
  }

  bool get isAdmin => roleName.toLowerCase() == "admin";

  // RevenueCat için sabit hesap kimliği:
  // anonim RC id'leri yerine hesap bazlı users.id'e düş.
  String get revenueCatUserId {
    final candidate = payUniqe?.trim();
    if (candidate != null &&
        candidate.isNotEmpty &&
        !candidate.startsWith(r"$RCAnonymousID:")) {
      return candidate;
    }
    return id.toString();
  }

  static String? _readPayIdentity(Map<String, dynamic> json) {
    final keys = <String>[
      "payUniqe",
      "payuniqe",
      "pay_unique",
      "payUnique",
      "revenuecat_user_id",
    ];
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String _readRoleName(
    Map<String, dynamic> json, {
    required int fallbackRoleId,
  }) {
    final roleRaw = json["role"];
    if (roleRaw is Map) {
      final nested = _readString(roleRaw["name"]);
      if (nested != null) return nested;
    } else {
      final direct = _readString(roleRaw);
      if (direct != null) return direct;
    }

    return _readString(json["role_name"]) ??
        (fallbackRoleId == 2 ? "admin" : "user");
  }

  static String? _readAvatarUrl(Map<String, dynamic> json) {
    final keys = <String>["avatar_url", "avatarUrl"];
    for (final key in keys) {
      final value = _readString(json[key]);
      if (value != null) return value;
    }
    return null;
  }

  static int _readRequiredInt(dynamic value, {required String fieldName}) {
    final parsed = _readInt(value);
    if (parsed == null) {
      throw FormatException("Invalid `$fieldName` value: $value");
    }
    return parsed;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
