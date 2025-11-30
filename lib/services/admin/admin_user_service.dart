import '../hasura_manager.dart';

class AdminUserService {
  final _hasura = HasuraManager.instance;

    Future<List<Map<String, dynamic>>> getAllRoles() async {
    const query = r'''
      query GetRoles {
        roles(order_by: {id: asc}) {
          id
          name
          description
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["roles"]);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    const String query = r'''
      query GetAllUsers {
        users(order_by: {id: asc}) {
          id
          name
          email
          phone
          role_id
          role { id name }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);

    final List users = data["users"];

    return users.map<Map<String, dynamic>>((u) {
      return {
        "id": u["id"],
        "name": u["name"],
        "email": u["email"],
        "phone": u["phone"],
        "role_id": u["role_id"],
        "role": u["role"]?["name"] ?? "User",
      };
    }).toList();
  }

  Future<bool> addUser({
    required String name,
    required String email,
    required String password,
    String? phone,
    int roleId = 1,
  }) async {
    const String mutation = r'''
      mutation AddUser(
        $name: String!,
        $email: String!,
        $password: String!,
        $phone: String,
        $role_id: bigint!
      ) {
        insert_users_one(object: {
          name: $name,
          email: $email,
          password: $password,
          phone: $phone,
          role_id: $role_id
        }) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "name": name,
        "email": email,
        "password": password,
        "phone": phone,
        "role_id": roleId,
      },
    );

    return true;
  }

  /// Kullanıcı güncelle
  Future<bool> updateUser({
    required int id,
    required String name,
    required String email,
    String? phone,
    required int roleId,
  }) async {
    const String mutation = r'''
      mutation UpdateUser(
        $id: bigint!,
        $name: String!,
        $email: String!,
        $phone: String,
        $role_id: bigint!
      ) {
        update_users_by_pk(
          pk_columns: {id: $id},
          _set: {
            name: $name,
            email: $email,
            phone: $phone,
            role_id: $role_id
          }
        ) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": id,
        "name": name,
        "email": email,
        "phone": phone,
        "role_id": roleId,
      },
    );

    return true;
  }

  /// Kullanıcı sil
  Future<bool> deleteUser(int id) async {
    const String mutation = r'''
      mutation DeleteUser($id: Int!) {
        delete_users_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id},
    );

    return true;
  }
}