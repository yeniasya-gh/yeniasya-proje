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

Future<AppUser?> getUserById(int id) async {
  const String query = r'''
    query GetUser($id: bigint!) {
      users_by_pk(id: $id) {
        id
        name
        phone
        email
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
}
