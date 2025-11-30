import 'package:flutter/material.dart';

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

  final isNetwork = url.startsWith("http://") || url.startsWith("https://");
  if (!isNetwork) {
    return Image.asset(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _placeholder(width, height, fallbackIcon),
    );
  }

  return _SafeNetworkImage(
    url: url,
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

class _SafeNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;

  const _SafeNetworkImage({
    required this.url,
    this.width,
    this.height,
    required this.fit,
    required this.fallbackIcon,
  });

  @override
  State<_SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<_SafeNetworkImage> {
  late String _currentUrl;
  int _attempt = 0;
  static const int _maxAttempts = 10;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _currentUrl,
      key: ValueKey(_currentUrl),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _placeholder(widget.width, widget.height, Icons.image);
      },
      errorBuilder: (_, __, ___) {
        if (_attempt < _maxAttempts - 1) {
          _attempt++;
          final uri = Uri.parse(widget.url);
          final busted = uri.replace(queryParameters: {
            ...uri.queryParameters,
            "cb": "${DateTime.now().millisecondsSinceEpoch}$_attempt",
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentUrl = busted.toString();
              });
            }
          });
          return _placeholder(widget.width, widget.height, widget.fallbackIcon);
        }
        return _placeholder(widget.width, widget.height, widget.fallbackIcon);
      },
    );
  }
}
