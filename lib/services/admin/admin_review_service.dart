import '../hasura_manager.dart';

class AdminReviewsPageResult {
  final List<Map<String, dynamic>> items;
  final int totalCount;

  const AdminReviewsPageResult({
    required this.items,
    required this.totalCount,
  });
}

class AdminReviewService {
  final _hasura = HasuraManager.instance;

  Future<Map<String, dynamic>> getReviews({
    required String productType,
    required int productId,
  }) async {
    const query = r'''
      query AdminProductReviews($product_type: String!, $product_id: bigint!) {
        product_reviews(
          where: {product_type: {_eq: $product_type}, product_id: {_eq: $product_id}},
          order_by: {created_at: desc}
        ) {
          id
          rating
          comment
          status
          created_at
          user_id
          user_name
          user_email
          product_title
        }
        product_reviews_aggregate(
          where: {product_type: {_eq: $product_type}, product_id: {_eq: $product_id}}
        ) {
          aggregate {
            count
            avg { rating }
          }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query, variables: {
      "product_type": productType,
      "product_id": productId,
    });

    final reviews = List<Map<String, dynamic>>.from(data["product_reviews"] ?? []);
    final agg = data["product_reviews_aggregate"]?["aggregate"] ?? {};
    final avg = (agg["avg"]?["rating"] is num) ? (agg["avg"]["rating"] as num).toDouble() : 0.0;
    final count = agg["count"] ?? 0;

    return {
      "reviews": reviews,
      "average": avg,
      "count": count,
    };
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    const query = r'''
      query AdminAllReviews {
        product_reviews(order_by: {created_at: desc}) {
          id
          product_type
          product_id
          product_title
          user_id
          user_name
          user_email
          rating
          comment
          status
          created_at
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["product_reviews"] ?? []);
  }

  Future<AdminReviewsPageResult> listReviewsPage({
    String keyword = "",
    String status = "all",
    String sort = "created_desc",
    int page = 1,
    int pageSize = 20,
  }) async {
    const query = r'''
      query ListReviewsPage(
        $keyword: String
        $status: String
        $sort: String
        $limit: Int!
        $offset: Int!
      ) {
        product_reviews {
          id
          product_type
          product_id
          product_title
          user_id
          user_name
          user_email
          rating
          comment
          status
          created_at
        }
        product_reviews_aggregate {
          aggregate {
            count
          }
        }
      }
    ''';

    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 20 : pageSize;
    final offset = (safePage - 1) * safePageSize;

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {
        "keyword": keyword.trim().isEmpty ? null : keyword.trim(),
        "status": status.trim().isEmpty ? "all" : status.trim(),
        "sort": sort.trim().isEmpty ? "created_desc" : sort.trim(),
        "limit": safePageSize,
        "offset": offset,
      },
    );

    final items = List<Map<String, dynamic>>.from(
      data["product_reviews"] ?? const [],
    );
    final totalCount = _toInt(
          data["product_reviews_aggregate"]?["aggregate"]?["count"],
        ) ??
        items.length;

    return AdminReviewsPageResult(items: items, totalCount: totalCount);
  }

  Future<void> updateStatus({
    required int id,
    required String status,
  }) async {
    const mutation = r'''
      mutation UpdateReviewStatus($id: bigint!, $status: String!) {
        update_product_reviews_by_pk(pk_columns: {id: $id}, _set: {status: $status}) { id }
      }
    ''';
    await _hasura.graphQLRequest(query: mutation, variables: {"id": id, "status": status});
  }

  Future<void> deleteReview(int id) async {
    const mutation = r'''
      mutation DeleteReview($id: bigint!) {
        delete_product_reviews_by_pk(id: $id) { id }
      }
    ''';
    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
