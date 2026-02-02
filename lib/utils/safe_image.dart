import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../services/upload_service.dart';

/// Safe image loader with single cache-bust retry for flaky CDN responses.
Widget safeImage(
  String? url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  IconData fallbackIcon = Icons.broken_image,
}) {
  if (url == null || url.isEmpty) {
    return _placeholder(width, height, fallbackIcon);
  }

  if (url.startsWith("assets/")) {
    return Image.asset(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _placeholder(width, height, fallbackIcon),
    );
  }

  return _CachedNetworkImage(
    url: UploadService.normalizeUrl(url),
    width: width,
    height: height,
    fit: fit,
    fallbackIcon: fallbackIcon,
  );
}

Widget _placeholder(double? width, double? height, IconData icon) {
  return SizedBox(
    width: width,
    height: height,
    child: ColoredBox(
      color: const Color(0xFFE0E0E0),
      child: Icon(icon, color: Colors.black54),
    ),
  );
}

final CacheManager _imageCacheManager = CacheManager(
  Config(
    "imageCache",
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 600,
  ),
);

class _CachedNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;

  const _CachedNetworkImage({
    required this.url,
    this.width,
    this.height,
    required this.fit,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      cacheManager: _imageCacheManager,
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => _placeholder(width, height, Icons.image),
      errorWidget: (_, __, ___) => _placeholder(width, height, fallbackIcon),
    );
  }
}
