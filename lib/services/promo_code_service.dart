import '../models/cart_item.dart';
import '../models/promo_code.dart';
import 'hasura_manager.dart';

class PromoCodeService {
  final _hasura = HasuraManager.instance;

  Future<PromoCode?> validateAndGet(
    String rawCode, {
    List<CartItem> cartItems = const [],
  }) async {
    final code = rawCode.trim();
    if (code.isEmpty) throw Exception("Kod boş olamaz");

    const query = r'''
      query PromoCode($code: String!) {
        promo_codes(where: {code: {_ilike: $code}, is_active: {_eq: true}}, limit: 1) {
          id
          code
          discount_percent
          starts_at
          ends_at
          is_active
          usage_limit
          usage_count
          applicable_categories
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"code": code},
    );
    final list = List<Map<String, dynamic>>.from(data["promo_codes"] ?? []);
    final found = list.isEmpty ? null : list.first;
    if (found == null) return null;

    final promo = PromoCode.fromMap(found);
    final now = DateTime.now();

    if (now.isBefore(promo.startsAt)) {
      throw Exception("Kod henüz aktif değil");
    }
    if (now.isAfter(promo.endsAt)) {
      throw Exception("Kodun süresi dolmuş");
    }

    final limit = found["usage_limit"];
    final count = found["usage_count"];
    if (limit != null) {
      final parsedLimit = int.tryParse(limit.toString());
      final parsedCount = int.tryParse(count?.toString() ?? "0") ?? 0;
      if (parsedLimit != null && parsedCount >= parsedLimit) {
        throw Exception("Kod kullanım limiti dolmuş");
      }
    }

    if (!promo.isApplicableToItems(cartItems)) {
      throw Exception("Promosyon kodu seçili ürünler için geçerli değil.");
    }

    return promo;
  }

  Future<void> markUsed(int promoId) async {
    const mutation = r'''
      mutation IncreaseUsage($id: bigint!) {
        update_promo_codes_by_pk(pk_columns: {id: $id}, _inc: {usage_count: 1}) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": promoId});
  }
}
