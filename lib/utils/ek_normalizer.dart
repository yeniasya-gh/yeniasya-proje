import '../services/upload_service.dart';

Map<String, dynamic> normalizeEk(Map<String, dynamic> raw) {
  final metadata = Map<String, dynamic>.from(
    raw["metadata"] as Map<String, dynamic>? ?? {},
  );

  dynamic pick(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty) return s;
        continue;
      }
      return v;
    }
    return null;
  }

  int? toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  double toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  final id = toInt(
    pick([
      raw["id"],
      raw["product_id"],
      raw["productId"],
      metadata["productId"],
      metadata["product_id"],
      metadata["id"],
      raw["item_id"],
      metadata["item_id"],
    ]),
  );

  final name =
      pick([
        raw["ad"],
        raw["title"],
        raw["name"],
        metadata["ad"],
        metadata["title"],
        metadata["name"],
      ])?.toString() ??
      "Ek";

  final desc =
      pick([
        raw["aciklama"],
        raw["description"],
        metadata["aciklama"],
        metadata["description"],
      ])?.toString() ??
      "";

  final price = toDouble(
    pick([
      raw["fiyat"],
      raw["price"],
      raw["unit_price"],
      metadata["fiyat"],
      metadata["price"],
      metadata["unit_price"],
    ]),
  );

  final pdfUrl =
      pick([
        raw["pdf_url"],
        raw["file_url"],
        metadata["pdf_url"],
        metadata["file_url"],
      ])?.toString() ??
      "";

  final photoUrl =
      pick([
        raw["photo_url"],
        raw["image_url"],
        metadata["photo_url"],
        metadata["photoUrl"],
        metadata["image_url"],
      ])?.toString() ??
      "";

  final isPublic = pick([
    raw["is_public"],
    metadata["is_public"],
    raw["isPublic"],
    metadata["isPublic"],
  ]);

  return {
    ...raw,
    "id": id ?? raw["id"],
    "ad": name,
    "aciklama": desc,
    "fiyat": price,
    "pdf_url": pdfUrl,
    "photo_url": UploadService.normalizeUrl(photoUrl),
    "is_public": isPublic ?? raw["is_public"],
    "metadata": metadata.isNotEmpty ? metadata : raw["metadata"],
  };
}

