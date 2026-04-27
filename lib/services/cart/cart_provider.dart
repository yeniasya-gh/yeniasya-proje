import 'package:flutter/foundation.dart';
import '../../models/cart_item.dart';
import '../../models/promo_code.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  PromoCode? _promoCode;

  List<CartItem> get items => List.unmodifiable(_items);

  PromoCode? get appliedPromo => _promoCode;

  double get totalPrice =>
      _items.fold(0, (sum, item) => sum + item.price * item.quantity);

  double get discountAmount {
    if (_promoCode == null) return 0;
    if (!_promoCode!.isApplicableToItems(_items)) return 0;
    final value = totalPrice * (_promoCode!.discountPercent / 100);
    return value < 0 ? 0 : value;
  }

  double get totalAfterDiscount {
    final total = totalPrice - discountAmount;
    if (total < 0) return 0;
    return total;
  }

  int _matchIndex(CartItem incoming) {
    final incomingProductId = incoming.metadata?['productId'];
    return _items.indexWhere((e) {
      if (e.type != incoming.type) return false;
      if (e.type == CartItemType.magazine) {
        return e.metadata?['productId'] == incomingProductId;
      }
      if (e.metadata?['productId'] != incomingProductId) return false;
      return true;
    });
  }

  bool contains(CartItem incoming) => _matchIndex(incoming) >= 0;

  bool addIfAbsent(CartItem incoming) {
    final index = _matchIndex(incoming);
    if (index >= 0) return false;
    _items.add(incoming.copyWith(quantity: 1));
    _clearInvalidPromoIfNeeded();
    notifyListeners();
    return true;
  }

  @Deprecated('Use addIfAbsent instead.')
  void addOrIncrement(CartItem incoming) {
    addIfAbsent(incoming);
  }

  void updateQuantity(String id, int quantity) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    if (quantity <= 0) {
      _items.removeAt(idx);
    } else {
      _items[idx] = _items[idx].copyWith(quantity: 1);
    }
    _clearInvalidPromoIfNeeded();
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    _clearInvalidPromoIfNeeded();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _promoCode = null;
    notifyListeners();
  }

  bool applyPromo(PromoCode promoCode) {
    if (!promoCode.isApplicableToItems(_items)) {
      return false;
    }
    _promoCode = promoCode;
    notifyListeners();
    return true;
  }

  void clearPromo() {
    _promoCode = null;
    notifyListeners();
  }

  bool _clearInvalidPromoIfNeeded() {
    if (_promoCode == null) return false;
    if (_promoCode!.isApplicableToItems(_items)) return false;
    _promoCode = null;
    return true;
  }
}
