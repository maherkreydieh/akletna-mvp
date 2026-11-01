import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/recipe_photos.dart';

class RecipeImage extends StatelessWidget {
  final String? url;

  /// Used to find a bundled photo when [url] is empty.
  final String? recipeName;
  final double height;
  final bool showPlaceholderLabel;
  const RecipeImage({
    super.key,
    this.url,
    this.recipeName,
    this.height = 160,
    this.showPlaceholderLabel = true,
  });
  Widget _placeholder({bool loading = false}) => ColoredBox(
    color: AppColors.primaryLight,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.soup_kitchen_outlined,
            size: height < 80 ? 26 : 44,
            color: AppColors.primary,
          ),
          if (height >= 120 && showPlaceholderLabel) ...[
            const SizedBox(height: 8),
            Text(
              loading ? 'Loading image…' : 'Image unavailable',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    // Order: image link from the server, then a bundled photo, then placeholder.
    child: url == null || url!.trim().isEmpty
        ? (bundledRecipePhoto(recipeName) == null
              ? _placeholder()
              : Image.asset(
                  bundledRecipePhoto(recipeName)!,
                  fit: BoxFit.cover,
                  cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
                      .ceil(),
                  errorBuilder: (_, _, _) => _placeholder(),
                ))
        : Image.network(
            url!,
            fit: BoxFit.cover,
            cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
                .ceil(),
            errorBuilder: (_, _, _) => _placeholder(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _placeholder(loading: true),
          ),
  );
}
