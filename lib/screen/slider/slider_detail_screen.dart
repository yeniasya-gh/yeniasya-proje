import 'package:flutter/material.dart';

import '../../services/upload_service.dart';
import '../../utils/safe_image.dart';

class SliderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> slide;
  final VoidCallback? onOpenLink;

  const SliderDetailScreen({
    super.key,
    required this.slide,
    this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final title = (slide["title"] ?? "").toString();
    final subtitle = (slide["subtitle"] ?? "").toString();
    final description = (slide["description"] ?? "").toString();
    final imageUrl = UploadService.normalizeUrl(slide["image_url"]?.toString() ?? "");
    final hasLink = (slide["link_url"] ?? "").toString().trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Duyuru Detayı"),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: safeImage(
                  imageUrl,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.image,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (title.isNotEmpty)
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                description,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
            ],
            if (hasLink && onOpenLink != null) const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: hasLink && onOpenLink != null
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: onOpenLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Bağlantıyı Aç"),
                ),
              ),
            )
          : null,
    );
  }
}
