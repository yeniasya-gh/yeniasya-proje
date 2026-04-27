import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/models/cart_item.dart';
import 'package:YeniAsya/models/promo_code.dart';
import 'package:YeniAsya/services/cart/cart_provider.dart';

CartItem _magazineCartItem({
  required int productId,
  required int magazineTypeId,
  required String subtitle,
}) {
  return CartItem(
    id: 'mag-$productId-type-$magazineTypeId',
    title: 'Örnek Dergi',
    subtitle: subtitle,
    imageUrl: '',
    price: 100,
    quantity: 1,
    type: CartItemType.magazine,
    metadata: {
      'productId': productId,
      'magazineTypeId': magazineTypeId,
      'periodMonths': magazineTypeId == 1 ? 1 : 3,
    },
  );
}

void main() {
  group('CartProvider', () {
    test('aynı dergi farklı süreyle ikinci kez eklenmez', () {
      final cart = CartProvider();
      final oneMonth = _magazineCartItem(
        productId: 12,
        magazineTypeId: 1,
        subtitle: '1 Aylık',
      );
      final threeMonth = _magazineCartItem(
        productId: 12,
        magazineTypeId: 3,
        subtitle: '3 Aylık',
      );

      expect(cart.addIfAbsent(oneMonth), isTrue);
      expect(cart.contains(threeMonth), isTrue);
      expect(cart.addIfAbsent(threeMonth), isFalse);
      expect(cart.items, hasLength(1));
      expect(cart.items.first.subtitle, '1 Aylık');
    });

    test('uyumsuz promosyon sepet değişince otomatik temizlenir', () {
      final cart = CartProvider();
      final book = CartItem(
        id: 'book-1',
        title: 'İşte Hayatım',
        imageUrl: '',
        price: 100,
        quantity: 1,
        type: CartItemType.book,
        metadata: {'productId': 1},
      );
      final magazine = CartItem(
        id: 'mag-2',
        title: 'Dergi',
        imageUrl: '',
        price: 50,
        quantity: 1,
        type: CartItemType.magazine,
        metadata: {'productId': 2},
      );
      final promo = PromoCode(
        id: 1,
        code: 'KITAP10',
        discountPercent: 10,
        startsAt: DateTime(2026, 1, 1),
        endsAt: DateTime(2027, 1, 1),
        isActive: true,
        applicableCategories: const ['book'],
      );

      expect(cart.addIfAbsent(book), isTrue);
      expect(cart.applyPromo(promo), isTrue);
      expect(cart.appliedPromo?.code, 'KITAP10');

      expect(cart.addIfAbsent(magazine), isTrue);
      expect(cart.appliedPromo, isNull);
      expect(cart.discountAmount, 0);
    });
  });
}
