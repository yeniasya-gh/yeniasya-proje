import 'hasura_manager.dart';

class ReviewService {
  final _hasura = HasuraManager.instance;

  Future<Map<String, dynamic>> getReviews({
    required String productType,
    required int productId,
  }) async {
    const query = r'''
      query ProductReviews($product_type: String!, $product_id: bigint!) {
        product_reviews(
          where: {
            product_type: {_eq: $product_type},
            product_id: {_eq: $product_id},
            status: {_eq: "published"}
          },
          order_by: {created_at: desc}
        ) {
          id
          rating
          comment
          created_at
          user_id
          user_name
          user_email
          status
        }
        product_reviews_aggregate(
          where: {
            product_type: {_eq: $product_type},
            product_id: {_eq: $product_id},
            status: {_eq: "published"}
          }
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

  Future<void> addReview({
    required String productType,
    required int productId,
    required int userId,
    required int rating,
    required String comment,
    String? userName,
    String? userEmail,
    String? productTitle,
  }) async {
    const mutation = r'''
      mutation InsertReview(
        $product_type: String!,
        $product_id: bigint!,
        $user_id: bigint!,
        $rating: Int!,
        $comment: String!,
        $user_name: String,
        $user_email: String,
        $product_title: String,
        $status: String!
      ) {
        insert_product_reviews_one(object: {
          product_type: $product_type,
          product_id: $product_id,
          user_id: $user_id,
          rating: $rating,
          comment: $comment,
          status: $status,
          user_name: $user_name,
          user_email: $user_email,
          product_title: $product_title
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {
      "product_type": productType,
      "product_id": productId,
      "user_id": userId,
      "rating": rating,
      "comment": comment,
      "user_name": userName,
      "user_email": userEmail,
      "product_title": productTitle,
      "status": "pending",
    });
  }
}
