import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import 'hearth_components.dart';
import 'recipe_image.dart';

class RecipeSpotlight extends StatelessWidget {
  const RecipeSpotlight({
    super.key,
    required this.title,
    this.description,
    this.imageUrl,
    this.badge,
    required this.onOpen,
    this.actionLabel = 'View recipe',
    this.metadata = const [],
    this.bookmark,
    this.insetTitle = false,
  });
  final String title;
  final String? description;
  final String? imageUrl;
  final String? badge;
  final VoidCallback onOpen;
  final String actionLabel;
  final List<String> metadata;
  final Widget? bookmark;
  final bool insetTitle;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 2,
    shadowColor: AppColors.primaryDark.withValues(alpha: .12),
    child: InkWell(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              RecipeImage(
                url: imageUrl,
                recipeName: title,
                showPlaceholderLabel: !insetTitle,
                height: insetTitle
                    ? 260 *
                          MediaQuery.textScalerOf(context)
                              .scale(1)
                              .clamp(1, 1.8)
                    : 200,
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC15291E)],
                    ),
                  ),
                ),
              ),
              if (badge != null)
                PositionedDirectional(
                  top: 12,
                  start: 12,
                  end: 64,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: HearthBadge(badge!, spice: true),
                  ),
                ),
              if (bookmark != null)
                PositionedDirectional(top: 6, end: 6, child: bookmark!),
              PositionedDirectional(
                bottom: 16,
                start: 16,
                end: 16,
                child: Container(
                  padding: insetTitle
                      ? const EdgeInsets.all(12)
                      : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: insetTitle ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: insetTitle ? 18 : 20,
                          fontWeight: FontWeight.w700,
                          color: insetTitle
                              ? AppColors.textPrimary
                              : Colors.white,
                        ),
                      ),
                      if (insetTitle &&
                          (description?.trim().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 6),
                        Text(
                          description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!insetTitle &&
                    (description?.trim().isNotEmpty ?? false)) ...[
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                ],
                if (metadata.isNotEmpty) ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: metadata
                        .map(
                          (m) => Text(
                            m,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.restaurant_outlined),
                    label: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
