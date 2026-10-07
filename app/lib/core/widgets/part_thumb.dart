import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Rounded product image with the category icon as placeholder/fallback.
/// Images are loaded from their source URL and cached on device; they are
/// never copied to our own servers.
class PartThumb extends StatelessWidget {
  const PartThumb({
    super.key,
    required this.imageUrl,
    required this.fallbackIcon,
    this.size = 44,
  });

  final Uri? imageUrl;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(fallbackIcon, color: scheme.primary, size: size * 0.5),
    );
    final url = imageUrl;
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Container(
        width: size,
        height: size,
        // Product shots are usually on white; keep them legible in dark mode.
        color: Colors.white,
        padding: EdgeInsets.all(size * 0.06),
        child: CachedNetworkImage(
          imageUrl: url.toString(),
          fit: BoxFit.contain,
          memCacheWidth: (size * 3).round(),
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
