import 'package:flutter/foundation.dart';
import '../../models/cart_item.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  double get totalPrice => _items.fold(0, (sum, item) => sum + item.price * item.quantity);

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
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
