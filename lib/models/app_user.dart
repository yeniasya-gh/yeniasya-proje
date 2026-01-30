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
      roleId: json["role_id"],
      roleName: json["role"]?["name"] ?? "user",
      payUniqe: json["payUniqe"]?.toString() ?? json["payuniqe"]?.toString(),
    );
  }

  bool get isAdmin => roleName.toLowerCase() == "admin";
}
