import '../../models/app_user.dart';
import '../hasura_manager.dart';
import '../../utils/hash_helper.dart';

class UserService {
  final _hasura = HasuraManager.instance;

  Future<AppUser> register({
    required String name,
    String? phone,
    required String email,
    required String password,
  }) async {
    final hashedPassword = HashHelper.hashPassword(password);

    const String mutation = r'''
      mutation Register(
        $name: String!,
        $phone: String,
        $email: String!,
        $password: String!
      ) {
        insert_users_one(object: {
          name: $name,
          phone: $phone,
          email: $email,
          password: $password
        }) {
          id
          name
          phone
          email
          payUniqe
          role_id
          role { id name }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "name": name,
        "phone": phone,
        "email": email,
        "password": hashedPassword,
      },
    );

    return AppUser.fromJson(data["insert_users_one"]);
  }

  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    final hashedPassword = HashHelper.hashPassword(password);

    const String query = r'''
  query Login(
    $email: String!,
    $password: String!
    ) {
      users(
      where: {
        email: { _eq: $email },
        password: { _eq: $password },
        is_active: { _eq: true }
      },
      limit: 1
    ) {
      id
      name
      phone
      email
      payUniqe
      role_id
      role {
        id
        name
      }
    }
  }
''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"email": email, "password": hashedPassword},
    );

    final list = data["users"] as List;
    if (list.isEmpty) return null;

    return AppUser.fromJson(list.first);
  }

  Future<AppUser?> getUserByEmail(String email) async {
    const String query = r'''
      query GetUserByEmail($email: String!) {
        users(where: {email: {_eq: $email}}, limit: 1) {
          id
          name
          phone
          email
          payUniqe
          role_id
          role { id name }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"email": email},
    );

    final list = data["users"] as List<dynamic>? ?? [];
    if (list.isEmpty) return null;
    return AppUser.fromJson(list.first as Map<String, dynamic>);
  }

  Future<AppUser?> getUserById(int id) async {
  const String query = r'''
    query GetUser($id: bigint!) {
      users_by_pk(id: $id) {
        id
        name
        phone
        email
        payUniqe
        role_id
        role { id name }
      }
    }
  ''';

  final data = await _hasura.graphQLRequest(
    query: query,
    variables: {"id": id},
  );

  final json = data["users_by_pk"];

  if (json == null) {
    return null;
  }

  return AppUser.fromJson(json);
}

  Future<AppUser?> updateProfile({
    required int id,
    required String name,
    String? phone,
  }) async {
    const mutation = r'''
      mutation UpdateProfile($id: bigint!, $name: String!, $phone: String) {
        update_users_by_pk(
          pk_columns: {id: $id},
          _set: {name: $name, phone: $phone}
        ) {
          id
          name
          phone
          email
          payUniqe
          role_id
          role { id name }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id, "name": name, "phone": phone},
    );

    final json = data["update_users_by_pk"];
    if (json == null) return null;
    return AppUser.fromJson(json);
  }

  Future<bool> changePassword({
    required int id,
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentHashed = HashHelper.hashPassword(currentPassword);
    final newHashed = HashHelper.hashPassword(newPassword);

    const mutation = r'''
      mutation ChangePassword($id: bigint!, $current: String!, $next: String!) {
        update_users(
          where: {id: {_eq: $id}, password: {_eq: $current}},
          _set: {password: $next}
        ) {
          affected_rows
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": id,
        "current": currentHashed,
        "next": newHashed,
      },
    );

    final rows = data["update_users"]?["affected_rows"] as int? ?? 0;
    return rows > 0;
  }
}
