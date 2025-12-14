import 'package:flutter/foundation.dart';
import '../../models/cart_item.dart';
import '../../models/promo_code.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  PromoCode? _promoCode;

  List<CartItem> get items => List.unmodifiable(_items);

  PromoCode? get appliedPromo => _promoCode;

  double get totalPrice => _items.fold(0, (sum, item) => sum + item.price * item.quantity);

  double get discountAmount {
    if (_promoCode == null) return 0;
    final value = totalPrice * (_promoCode!.discountPercent / 100);
    return value < 0 ? 0 : value;
  }

  double get totalAfterDiscount {
    final total = totalPrice - discountAmount;
    if (total < 0) return 0;
    return total;
  }

  void addOrIncrement(CartItem incoming) {
    final index = _items.indexWhere(
      (e) => e.type == incoming.type && e.metadata?['productId'] == incoming.metadata?['productId'],
    );

    if (index >= 0) {
      final existing = _items[index];
      _items[index] = existing.copyWith(quantity: existing.quantity + incoming.quantity);
    } else {
      _items.add(incoming);
    }
    notifyListeners();
  }

  void updateQuantity(String id, int quantity) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    if (quantity <= 0) {
      _items.removeAt(idx);
    } else {
      _items[idx] = _items[idx].copyWith(quantity: quantity);
    }
    if (_items.isEmpty) {
      _promoCode = null;
    }
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    if (_items.isEmpty) {
      _promoCode = null;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _promoCode = null;
    notifyListeners();
  }

  void applyPromo(PromoCode promoCode) {
    _promoCode = promoCode;
    notifyListeners();
  }

  void clearPromo() {
    _promoCode = null;
    notifyListeners();
  }
}
