class AppUser {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final int roleId;
  final String roleName;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.roleId,
    required this.roleName,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json["id"],
      name: json["name"],
      email: json["email"],
      phone: json["phone"],
      roleId: json["role_id"],
      roleName: json["role"]?["name"] ?? "user",
    );
  }

  bool get isAdmin => roleName.toLowerCase() == "admin";
}