import 'package:flutter/material.dart';

import '../screen/cart/cart_screen.dart';

Future<void> showAddedToCartDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Bilgi"),
      content: const Text("Ürün sepete eklendi."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Alışverişe Devam Et"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
          child: const Text("Sepete Git"),
        ),
      ],
    ),
  );
}
