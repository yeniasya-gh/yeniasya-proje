class AppUser {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final int roleId;
  final String roleName;
  final String? payUniqe;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.roleId,
    required this.roleName,
    this.payUniqe,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json["id"],
      name: json["name"],
      email: json["email"],
      phone: json["phone"],
      roleId: json["role_id"] ?? 0,
      roleName: json["role"]?["name"] ?? json["role_name"] ?? "user",
      payUniqe: json["payUniqe"]?.toString() ?? json["payuniqe"]?.toString(),
    );
  }

  factory AppUser.fromAuthJson(Map<String, dynamic> json) {
    final roleId = json["role_id"] ?? 0;
    return AppUser(
      id: json["id"],
      name: json["name"],
      email: json["email"],
      phone: json["phone"],
      roleId: roleId,
      roleName: json["role_name"] ?? (roleId == 2 ? "admin" : "user"),
      payUniqe: json["payUniqe"]?.toString() ?? json["payuniqe"]?.toString(),
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
      if (payUniqe != null) "payUniqe": payUniqe,
    };
  }

  bool get isAdmin => roleName.toLowerCase() == "admin";
}
