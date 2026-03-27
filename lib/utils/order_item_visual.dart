import 'package:flutter/material.dart';

import '../services/upload_service.dart';
import 'safe_image.dart';

String? orderItemImageUrl(Map<String, dynamic> item) {
  final candidates = <String?>[
    item["image_url"]?.toString(),
    item["imageUrl"]?.toString(),
    item["photo_url"]?.toString(),
    item["photoUrl"]?.toString(),
    item["cover_url"]?.toString(),
    item["coverUrl"]?.toString(),
    item["cover_image_url"]?.toString(),
    item["coverImageUrl"]?.toString(),
    item["thumbnail_url"]?.toString(),
    item["thumbnailUrl"]?.toString(),
    item["file_url"]?.toString(),
    item["fileUrl"]?.toString(),
  ];

  final metadata = item["metadata"];
  if (metadata is Map) {
    final meta = Map<String, dynamic>.from(metadata);
    candidates.addAll([
      meta["image_url"]?.toString(),
      meta["imageUrl"]?.toString(),
      meta["photo_url"]?.toString(),
      meta["photoUrl"]?.toString(),
      meta["cover_url"]?.toString(),
      meta["coverUrl"]?.toString(),
      meta["cover_image_url"]?.toString(),
      meta["coverImageUrl"]?.toString(),
      meta["thumbnail_url"]?.toString(),
      meta["thumbnailUrl"]?.toString(),
      meta["file_url"]?.toString(),
      meta["fileUrl"]?.toString(),
    ]);
  }

  for (final candidate in candidates) {
    final normalized = UploadService.normalizeUrl(candidate?.trim() ?? "");
    if (normalized.isNotEmpty) return normalized;
  }
  return null;
}

IconData orderItemFallbackIcon(Map<String, dynamic> item) {
  final productType = (item["product_type"] ?? item["type"] ?? "")
      .toString()
      .trim()
      .toLowerCase();
  switch (productType) {
    case "book":
      return Icons.menu_book_outlined;
    case "magazine":
    case "magazine_issue":
      return Icons.newspaper_outlined;
    case "newspaper":
    case "newspaper_subscription":
      return Icons.feed_outlined;
    case "supplement":
    case "ek":
      return Icons.inventory_2_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

Widget orderItemThumbnail(
  Map<String, dynamic> item, {
  double width = 56,
  double height = 72,
  BoxFit fit = BoxFit.cover,
}) {
  final imageUrl = orderItemImageUrl(item);
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: safeImage(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      fallbackIcon: orderItemFallbackIcon(item),
    ),
  );
}
