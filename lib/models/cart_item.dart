enum CartItemType {
  book,
  magazine,
  magazineIssue,
  newspaperSubscription,
}

class CartItem {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final double price;
  final int quantity;
  final CartItemType type;
  final Map<String, dynamic>? metadata;

  CartItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    required this.price,
    required this.quantity,
    required this.type,
    this.metadata,
  });

  CartItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    double? price,
    int? quantity,
    CartItemType? type,
    Map<String, dynamic>? metadata,
  }) {
    return CartItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }
}
