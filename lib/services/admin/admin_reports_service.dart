import 'dart:math';

import '../hasura_manager.dart';

class AdminReportsService {
  final _hasura = HasuraManager.instance;

  Future<ReportResult> fetchReport({
    required String type,
    DateTime? start,
    DateTime? end,
  }) async {
    final variables = {
      "type": type,
      "start": start?.toIso8601String(),
      "end": end?.toIso8601String(),
    }..removeWhere((_, v) => v == null);

    const query = r'''
      query AdminReport($type: String!, $start: timestamp, $end: timestamp) {
        agg: order_items_aggregate(
          where: {
            product_type: { _eq: $type },
            created_at: { _gte: $start, _lte: $end }
          }
        ) {
          aggregate {
            count
            sum { line_total }
            avg { unit_price }
          }
        }
        items: order_items(
          where: {
            product_type: { _eq: $type },
            created_at: { _gte: $start, _lte: $end }
          },
          order_by: [{ line_total: desc_nulls_last }],
          limit: 100
        ) {
          id
          title
          quantity
          unit_price
          line_total
          created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query, variables: variables);
    final agg = data['agg']?['aggregate'] ?? {};
    final count = (agg['count'] ?? 0) as int;
    final revenue = double.tryParse((agg['sum']?['line_total']).toString()) ?? 0;
    final avgPrice = double.tryParse((agg['avg']?['unit_price']).toString()) ?? 0;

    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final series = _groupByDay(items);

    return ReportResult(
      count: count,
      revenue: revenue,
      avgPrice: avgPrice,
      items: items,
      series: series,
      peakValue: series.fold<double>(0, (p, e) => max(p, e.value)),
    );
  }

  List<ReportPoint> _groupByDay(List<Map<String, dynamic>> items) {
    final map = <String, double>{};
    for (final item in items) {
      final ts = item['created_at']?.toString();
      final total = double.tryParse(item['line_total']?.toString() ?? '') ?? 0;
      if (ts == null) continue;
      final date = DateTime.tryParse(ts);
      if (date == null) continue;
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      map.update(key, (v) => v + total, ifAbsent: () => total);
    }

    final sortedKeys = map.keys.toList()..sort();
    return sortedKeys.map((k) => ReportPoint(k, map[k]!)).toList();
  }
}

class ReportResult {
  final int count;
  final double revenue;
  final double avgPrice;
  final List<Map<String, dynamic>> items;
  final List<ReportPoint> series;
  final double peakValue;

  ReportResult({
    required this.count,
    required this.revenue,
    required this.avgPrice,
    required this.items,
    required this.series,
    required this.peakValue,
  });
}

class ReportPoint {
  final String label;
  final double value;

  ReportPoint(this.label, this.value);
}
