import '../hasura_manager.dart';

class AdminMagazineService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getMagazines() async {
    const query = r'''
      query GetMagazines {
        magazine(order_by: {id: desc}) {
          id
        name
        category
        cover_image_url
        period
        description
        created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["magazine"]);
  }

  Future<Map<String, dynamic>?> getMagazineById(int id) async {
    const query = r'''
      query GetMagazine($id: Int!) {
        magazine_by_pk(id: $id) {
          id
        name
        category
        cover_image_url
        period
        description
        created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"id": id},
    );

    return data["magazine_by_pk"] as Map<String, dynamic>?;
  }

  Future<int> addMagazine({
    required String name,
    required String category,
    required String period,
    String? description,
    String? coverImageUrl,
  }) async {
    const mutation = r'''
      mutation AddMagazine(
        $name: String!,
        $category: String!,
        $period: magazine_period!,
        $description: String,
        $cover_image_url: String
      ) {
        insert_magazine_one(object: {
          name: $name,
          category: $category,
          period: $period,
          description: $description,
          cover_image_url: $cover_image_url
        }) {
          id
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "name": name,
        "category": category,
        "period": period,
        "description": description,
        "cover_image_url": coverImageUrl,
      },
    );

    return (data["insert_magazine_one"]?["id"] as int?) ?? 0;
  }

  Future<bool> updateMagazine({
    required int id,
    required String name,
    required String category,
    required String period,
    String? description,
    String? coverImageUrl,
  }) async {
    const mutation = r'''
      mutation UpdateMagazine(
        $id: Int!,
        $name: String!,
        $category: String!,
        $period: magazine_period!,
        $description: String,
        $cover_image_url: String
      ) {
        update_magazine_by_pk(
          pk_columns: {id: $id},
          _set: {
            name: $name,
            category: $category,
          period: $period,
          description: $description,
          cover_image_url: $cover_image_url
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
        "category": category,
        "period": period,
        "description": description,
        "cover_image_url": coverImageUrl,
      },
    );

    return true;
  }

  Future<bool> deleteMagazine(int id) async {
    const mutation = r'''
      mutation DeleteMagazine($id: Int!) {
        delete_magazine_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
    return true;
  }

  Future<List<Map<String, dynamic>>> getIssues(int magazineId) async {
    const query = r'''
      query GetIssues($magazine_id: Int!) {
        magazine_issue(
          where: {magazine_id: {_eq: $magazine_id}},
          order_by: {issue_number: desc}
        ) {
          id
          magazine_id
          issue_number
          file_url
          photo_url
          price
          description
          added_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"magazine_id": magazineId},
    );

    return List<Map<String, dynamic>>.from(data["magazine_issue"]);
  }

  Future<bool> addIssue({
    required int magazineId,
    required int issueNumber,
    required String fileUrl,
    String? photoUrl,
    required double price,
    String? description,
    String? addedAt,
  }) async {
    const mutation = r'''
      mutation AddIssue(
        $magazine_id: Int!,
        $issue_number: Int!,
        $file_url: String!,
        $photo_url: String,
        $price: numeric!,
        $description: String,
        $added_at: timestamptz
      ) {
        insert_magazine_issue_one(object: {
          magazine_id: $magazine_id,
          issue_number: $issue_number,
          file_url: $file_url,
          photo_url: $photo_url,
          price: $price,
          description: $description,
          added_at: $added_at
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "magazine_id": magazineId,
        "issue_number": issueNumber,
        "file_url": fileUrl,
        "photo_url": photoUrl,
        "price": price,
        "description": description,
        "added_at": addedAt,
      },
    );

    return true;
  }

  Future<bool> updateIssue({
    required int id,
    required int issueNumber,
    required String fileUrl,
    String? photoUrl,
    required double price,
    String? description,
    String? addedAt,
  }) async {
    const mutation = r'''
      mutation UpdateIssue(
        $id: Int!,
        $issue_number: Int!,
        $file_url: String!,
        $photo_url: String,
        $price: numeric!,
        $description: String,
        $added_at: timestamptz
      ) {
        update_magazine_issue_by_pk(
          pk_columns: {id: $id},
          _set: {
            issue_number: $issue_number,
            file_url: $file_url,
            photo_url: $photo_url,
            price: $price,
            description: $description,
            added_at: $added_at
          }
        ) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": id,
        "issue_number": issueNumber,
        "file_url": fileUrl,
        "photo_url": photoUrl,
        "price": price,
        "description": description,
        "added_at": addedAt,
      },
    );

    return true;
  }

  Future<bool> deleteIssue(int id) async {
    const mutation = r'''
      mutation DeleteIssue($id: Int!) {
        delete_magazine_issue_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
    return true;
  }

  Future<Map<String, dynamic>?> getIssueById(int id) async {
    const query = r'''
      query GetIssue($id: Int!) {
        magazine_issue_by_pk(id: $id) {
          id
          magazine_id
          issue_number
          file_url
          photo_url
          price
          description
          added_at
          magazine {
            id
            name
          }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"id": id},
    );

    return data["magazine_issue_by_pk"] as Map<String, dynamic>?;
  }
}
