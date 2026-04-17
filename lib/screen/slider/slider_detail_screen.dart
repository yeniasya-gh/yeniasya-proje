import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/upload_service.dart';
import '../../utils/launch_uri.dart';
import '../../utils/safe_image.dart';

class SliderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> slide;
  final VoidCallback? onOpenLink;

  const SliderDetailScreen({super.key, required this.slide, this.onOpenLink});

  String _shareLink() {
    final id = slide["id"];
    if (id == null) return "";

    final baseUri = currentLaunchUri();
    final fallbackBase = Uri.parse("https://yeniasyadijital.com/");
    final resolvedBase = baseUri.hasAuthority && baseUri.host.isNotEmpty
        ? baseUri
        : fallbackBase;

    return resolvedBase
        .replace(
          path: "/",
          queryParameters: {"type": "slider", "id": id.toString()},
        )
        .toString();
  }

  Future<void> _share(BuildContext context) async {
    final link = _shareLink();
    if (link.isEmpty) return;
    final title = (slide["title"] ?? "Duyuru").toString().trim();
    try {
      await Share.share("$title\n$link");
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Paylaşım başlatılamadı.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final imageHeight = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(220.0, 420.0)
        .toDouble();
    final title = (slide["title"] ?? "").toString();
    final subtitle = (slide["subtitle"] ?? "").toString();
    final description = (slide["description"] ?? "").toString();
    final imageUrl = UploadService.normalizeUrl(
      slide["image_url"]?.toString() ?? "",
    );
    final hasLink = (slide["link_url"] ?? "").toString().trim().isNotEmpty;
    final canShare = _shareLink().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Duyuru Detayı"),
        actions: [
          if (canShare)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _share(context),
              tooltip: "Paylaş",
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: const Color(0xFFF5F5F5),
                      child: SizedBox(
                        width: double.infinity,
                        height: imageHeight,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: safeImage(
                            imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            fallbackIcon: Icons.image,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (title.isNotEmpty)
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
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
      ),
      bottomNavigationBar: hasLink && onOpenLink != null
          ? SafeArea(
              minimum: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                isAndroid ? 20 : 16,
              ),
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: onOpenLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Bağlantıyı Aç"),
                ),
              ),
            )
          : null,
    );
  }
}
