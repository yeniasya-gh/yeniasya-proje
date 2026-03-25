import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/models/cart_item.dart';
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
  });
}
