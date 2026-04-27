import '../hasura_manager.dart';

class AdminPromoCodeService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getPromoCodes() async {
    const query = r'''
      query AdminPromoCodes {
        promo_codes(order_by: {created_at: desc}) {
          id
          code
          discount_percent
          starts_at
          ends_at
          is_active
          usage_limit
          usage_count
          applicable_categories
          created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["promo_codes"] ?? []);
  }

  Future<bool> createPromoCode({
    required String code,
    required double discountPercent,
    required DateTime startsAt,
    required DateTime endsAt,
    bool isActive = true,
    int? usageLimit,
    List<String> applicableCategories = const [],
  }) async {
    const mutation = r'''
      mutation InsertPromoCode(
        $code: String!,
        $discount_percent: numeric!,
        $starts_at: timestamptz!,
        $ends_at: timestamptz!,
        $is_active: Boolean!,
        $usage_limit: Int,
        $applicable_categories: [String!]
      ) {
        insert_promo_codes_one(object: {
          code: $code,
          discount_percent: $discount_percent,
          starts_at: $starts_at,
          ends_at: $ends_at,
          is_active: $is_active,
          usage_limit: $usage_limit,
          applicable_categories: $applicable_categories
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "code": code,
        "discount_percent": discountPercent,
        "starts_at": startsAt.toIso8601String(),
        "ends_at": endsAt.toIso8601String(),
        "is_active": isActive,
        "usage_limit": usageLimit,
        "applicable_categories": applicableCategories,
      },
    );

    return true;
  }

  Future<bool> toggleActive({required int id, required bool isActive}) async {
    const mutation = r'''
      mutation TogglePromo($id: bigint!, $is_active: Boolean!) {
        update_promo_codes_by_pk(pk_columns: {id: $id}, _set: {is_active: $is_active}) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id, "is_active": isActive},
    );
    return true;
  }

  Future<bool> deletePromoCode(int id) async {
    const mutation = r'''
      mutation DeletePromo($id: bigint!) {
        delete_promo_codes_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
    return true;
  }
}
