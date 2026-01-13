import 'package:flutter/material.dart';
import '../../services/loading_manager.dart';

class AdminLoadingIndicator extends StatelessWidget {
  final EdgeInsets padding;
  final double? size;

  const AdminLoadingIndicator({
    super.key,
    this.padding = const EdgeInsets.all(24),
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LoadingManager.instance,
      builder: (_, __) {
        if (LoadingManager.instance.loading) return const SizedBox.shrink();
        final indicator = CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        );
        return Center(
          child: Padding(
            padding: padding,
            child: size == null ? indicator : SizedBox(width: size, height: size, child: indicator),
          ),
        );
      },
    );
  }
}
