import '../hasura_manager.dart';

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
}
