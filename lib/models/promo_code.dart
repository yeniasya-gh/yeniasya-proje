class PromoCode {
  final int id;
  final String code;
  final double discountPercent;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;

  PromoCode({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  factory PromoCode.fromMap(Map<String, dynamic> json) {
    return PromoCode(
      id: json["id"] is int ? json["id"] as int : int.tryParse(json["id"]?.toString() ?? "") ?? 0,
      code: json["code"]?.toString() ?? "",
      discountPercent:
          (json["discount_percent"] is num) ? (json["discount_percent"] as num).toDouble() : double.tryParse(json["discount_percent"]?.toString() ?? "0") ?? 0,
      startsAt: DateTime.tryParse(json["starts_at"]?.toString() ?? "") ?? DateTime.now(),
      endsAt: DateTime.tryParse(json["ends_at"]?.toString() ?? "") ?? DateTime.now(),
      isActive: json["is_active"] == null ? true : json["is_active"] == true || json["is_active"].toString() == "true",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "code": code,
      "discount_percent": discountPercent,
      "starts_at": startsAt.toIso8601String(),
      "ends_at": endsAt.toIso8601String(),
      "is_active": isActive,
    };
  }

  bool get isCurrentlyValid {
    final now = DateTime.now();
    return isActive && now.isAfter(startsAt) && now.isBefore(endsAt);
  }
}
