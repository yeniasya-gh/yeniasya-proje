import '../hasura_manager.dart';

class AdminOrdersPageResult {
  final List<Map<String, dynamic>> items;
  final int totalCount;

  const AdminOrdersPageResult({
    required this.items,
    required this.totalCount,
  });
}

bool _isMissingPaymentProviderColumnError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains("payment_provider") ||
      message.contains("merchant_payment_id") ||
      message.contains("payment_session_token");
}

class AdminOrderService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    const queryWithProvider = r'''
      query GetAllOrders {
        orders(order_by: {created_at: desc}) {
          id
          total_paid
          status
          created_at
          payment_provider
          merchant_payment_id
          payment_session_token
          user_id
          user {
            id
            name
            email
          }
        }
      }
    ''';
    const queryWithMerchantOnly = r'''
      query GetAllOrders {
        orders(order_by: {created_at: desc}) {
          id
          total_paid
          status
          created_at
          merchant_payment_id
          payment_session_token
          user_id
          user {
            id
            name
            email
          }
        }
      }
    ''';
    const queryWithoutChannel = r'''
      query GetAllOrders {
        orders(order_by: {created_at: desc}) {
          id
          total_paid
          status
          created_at
          user_id
          user {
            id
            name
            email
          }
        }
      }
    ''';

    Map<String, dynamic> data;
    try {
      data = await _hasura.graphQLRequest(query: queryWithProvider);
    } catch (error) {
      if (!_isMissingPaymentProviderColumnError(error)) {
        rethrow;
      }
      try {
        data = await _hasura.graphQLRequest(query: queryWithMerchantOnly);
      } catch (merchantError) {
        if (!_isMissingPaymentProviderColumnError(merchantError)) {
          rethrow;
        }
        data = await _hasura.graphQLRequest(query: queryWithoutChannel);
      }
    }
    return List<Map<String, dynamic>>.from(data["orders"] ?? []);
  }

  Future<AdminOrdersPageResult> listOrdersPage({
    String keyword = "",
    String status = "all",
    String sort = "created_desc",
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    const query = r'''
      query ListOrdersPage(
        $keyword: String
        $status: String
        $sort: String
        $start_date: String
        $end_date: String
        $page: Int!
        $page_size: Int!
      ) {
        orders {
          id
          total_paid
          status
          created_at
          payment_provider
          merchant_payment_id
          payment_session_token
          user_id
          user {
            id
            name
            email
          }
        }
        orders_aggregate {
          aggregate {
            count
          }
        }
      }
    ''';

    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 20 : pageSize;

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {
        "keyword": keyword.trim().isEmpty ? null : keyword.trim(),
        "status": status.trim().isEmpty ? "all" : status.trim(),
        "sort": sort.trim().isEmpty ? "created_desc" : sort.trim(),
        "start_date": startDate?.trim().isEmpty == true ? null : startDate?.trim(),
        "end_date": endDate?.trim().isEmpty == true ? null : endDate?.trim(),
        "page": safePage,
        "page_size": safePageSize,
      },
    );

    final items = List<Map<String, dynamic>>.from(
      data["orders"] ?? const [],
    );
    final totalCount = _toInt(
          data["orders_aggregate"]?["aggregate"]?["count"],
        ) ??
        items.length;
    return AdminOrdersPageResult(items: items, totalCount: totalCount);
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
