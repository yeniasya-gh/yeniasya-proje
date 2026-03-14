import 'package:flutter/material.dart';

import 'safe_image.dart';

class AppUserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final VoidCallback? onEditTap;
  final bool busy;

  const AppUserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 44,
    this.onEditTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: safeImage(
                  imageUrl ?? "assets/images/avatar.png",
                  width: diameter,
                  height: diameter,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.person,
                ),
              ),
            ),
          ),
          if (busy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (onEditTap != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Material(
                color: const Color(0xFFD32F2F),
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: busy ? null : onEditTap,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
