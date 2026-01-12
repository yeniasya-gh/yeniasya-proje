import '../hasura_manager.dart';

class AdminSliderService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAll({bool onlyActive = false}) async {
    const baseQuery = r'''
      query GetSliders {
        slider(order_by: {sort_order: asc, created_at: desc}) {
          id
          title
          subtitle
          description
          image_url
          link_url
          sort_order
          is_active
          created_at
          updated_at
        }
      }
    ''';

    const activeQuery = r'''
      query GetSliders {
        slider(
          where: {is_active: {_eq: true}},
          order_by: {sort_order: asc, created_at: desc}
        ) {
          id
          title
          subtitle
          description
          image_url
          link_url
          sort_order
          is_active
          created_at
          updated_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: onlyActive ? activeQuery : baseQuery);
    return List<Map<String, dynamic>>.from(data["slider"] ?? []);
  }

  Future<bool> add({
    required String title,
    String? subtitle,
    String? description,
    required String imageUrl,
    String? linkUrl,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    const mutation = r'''
      mutation AddSlider(
        $title: String!,
        $subtitle: String,
        $description: String,
        $image_url: String!,
        $link_url: String,
        $sort_order: Int!,
        $is_active: Boolean!
      ) {
        insert_slider_one(object: {
          title: $title,
          subtitle: $subtitle,
          description: $description,
          image_url: $image_url,
          link_url: $link_url,
          sort_order: $sort_order,
          is_active: $is_active
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "title": title,
        "subtitle": subtitle,
        "description": description,
        "image_url": imageUrl,
        "link_url": linkUrl,
        "sort_order": sortOrder,
        "is_active": isActive,
      },
    );
    return true;
  }

  Future<bool> update({
    required int id,
    required String title,
    String? subtitle,
    String? description,
    required String imageUrl,
    String? linkUrl,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    const mutation = r'''
      mutation UpdateSlider(
        $id: Int!,
        $title: String!,
        $subtitle: String,
        $description: String,
        $image_url: String!,
        $link_url: String,
        $sort_order: Int!,
        $is_active: Boolean!
      ) {
        update_slider_by_pk(
          pk_columns: {id: $id},
          _set: {
            title: $title,
            subtitle: $subtitle,
            description: $description,
            image_url: $image_url,
            link_url: $link_url,
            sort_order: $sort_order,
            is_active: $is_active
          }
        ) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": id,
        "title": title,
        "subtitle": subtitle,
        "description": description,
        "image_url": imageUrl,
        "link_url": linkUrl,
        "sort_order": sortOrder,
        "is_active": isActive,
      },
    );
    return true;
  }

  Future<bool> delete(int id) async {
    const mutation = r'''
      mutation DeleteSlider($id: Int!) {
        delete_slider_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
    return true;
  }
}
