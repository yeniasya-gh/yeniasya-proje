import '../hasura_manager.dart';

class AdminStatsService {
  final _hasura = HasuraManager.instance;

  Future<Map<String, dynamic>> fetchStats() async {
    const query = r'''
      query AdminStats {
        books_aggregate { aggregate { count } }
        magazine_aggregate { aggregate { count } }
        newspaper_aggregate { aggregate { count } }
        orders_aggregate { aggregate { count } }
        users_aggregate { aggregate { count } }
        orders_today: orders_aggregate(where: {created_at: {_gte: "2024-01-01"}}) { aggregate { count } }
        orders_last_month: orders_aggregate(where: {created_at: {_gte: "2024-01-01"}}) { aggregate { count } }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    int _count(String key) => (data[key]?["aggregate"]?["count"] ?? 0) as int;

    return {
      "books": _count("books_aggregate"),
      "magazines": _count("magazine_aggregate"),
      "newspapers": _count("newspaper_aggregate"),
      "orders": _count("orders_aggregate"),
      "users": _count("users_aggregate"),
      "orders_today": _count("orders_today"),
      "orders_last_month": _count("orders_last_month"),
    };
  }
}
