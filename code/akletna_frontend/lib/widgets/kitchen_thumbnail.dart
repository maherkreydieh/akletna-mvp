import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/recipe_photos.dart';

class KitchenThumbnail extends StatelessWidget {
  const KitchenThumbnail({
    super.key,
    this.url,
    this.recipeName,
    this.size = 80,
    this.icon = Icons.restaurant_outlined,
  });
  final String? url;

  /// Used to find a bundled photo when [url] is empty.
  final String? recipeName;
  final double size;
  final IconData icon;
  Widget _fallback(String label) => ColoredBox(
    color: AppColors.primaryLight,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: size,
      height: size,
      child: url?.trim().isNotEmpty == true
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              errorBuilder: (_, _, _) => _fallback('No photo'),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _fallback('Loading…'),
            )
          : bundledRecipePhoto(recipeName) != null
          ? Image.asset(
              bundledRecipePhoto(recipeName)!,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              errorBuilder: (_, _, _) => _fallback('No photo'),
            )
          : _fallback('No photo'),
    ),
  );
}
