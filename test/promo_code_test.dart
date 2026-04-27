import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/models/cart_item.dart';
import 'package:YeniAsya/models/promo_code.dart';

CartItem _cartItem({required String id, required CartItemType type}) {
  return CartItem(
    id: id,
    title: id,
    imageUrl: '',
    price: 100,
    quantity: 1,
    type: type,
    metadata: const {'productId': 1},
  );
}

void main() {
  group('PromoCode', () {
    test('parses applicable categories and scope label', () {
      final promo = PromoCode.fromMap({
        'id': 3,
        'code': 'KITAP',
        'discount_percent': 20,
        'starts_at': '2026-01-01T00:00:00Z',
        'ends_at': '2027-01-01T00:00:00Z',
        'is_active': true,
        'applicable_categories': ['book', 'magazine'],
      });

      expect(promo.applicableCategories, ['book', 'magazine']);
      expect(promo.scopeLabel, 'Kitap, Dergi');
    });

    test('validates cart compatibility by category scope', () {
      final promo = PromoCode(
        id: 1,
        code: 'BOOK10',
        discountPercent: 10,
        startsAt: DateTime(2026, 1, 1),
        endsAt: DateTime(2027, 1, 1),
        isActive: true,
        applicableCategories: const ['book'],
      );

      expect(
        promo.isApplicableToItems([
          _cartItem(id: 'b1', type: CartItemType.book),
        ]),
        isTrue,
      );
      expect(
        promo.isApplicableToItems([
          _cartItem(id: 'b1', type: CartItemType.book),
          _cartItem(id: 'm1', type: CartItemType.magazine),
        ]),
        isFalse,
      );
      expect(
        promo.isApplicableToItems([
          _cartItem(id: 'i1', type: CartItemType.magazineIssue),
        ]),
        isFalse,
      );
    });
  });
}
