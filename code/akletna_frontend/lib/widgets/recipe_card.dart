import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/recipe.dart';
import 'recipe_compatibility_view.dart';
import 'recipe_image.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final bool showEvaluation;
  final Widget? imageAction;
  final bool showOpenAction;
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.showEvaluation = true,
    this.imageAction,
    this.showOpenAction = false,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              RecipeImage(
                url: recipe.imageUrl,
                recipeName: recipe.name,
                height: 180,
              ),
              PositionedDirectional(
                top: 12,
                start: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: recipe.origin == RecipeOrigin.curated
                        ? AppColors.accentContainer
                        : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      recipe.origin == RecipeOrigin.curated
                          ? 'Curated'
                          : recipe.visibility == RecipeVisibility.private
                          ? 'Private recipe'
                          : 'Community',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: recipe.origin == RecipeOrigin.curated
                            ? AppColors.accentText
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ),
              if (imageAction != null)
                PositionedDirectional(top: 6, end: 6, child: imageAction!),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (recipe.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    recipe.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (recipe.category.isNotEmpty)
                      Text(
                        recipe.category,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (recipe.cookingTime > 0)
                      _metadata(
                        Icons.timer_outlined,
                        '${recipe.cookingTime} min',
                      ),
                    if ((recipe.servings ?? 0) > 0)
                      _metadata(
                        Icons.people_outline,
                        '${recipe.servings} ${recipe.servings == 1 ? "serving" : "servings"}',
                      ),
                    if (recipe.origin == RecipeOrigin.user &&
                        recipe.visibility == RecipeVisibility.public &&
                        recipe.saveCount != null)
                      Text(
                        '${recipe.saveCount} ${recipe.saveCount == 1 ? "save" : "saves"}',
                      ),
                  ],
                ),
                if (showEvaluation)
                  RecipeCompatibilityView(
                    evaluation: recipe.evaluation,
                    compact: true,
                  ),
                if (showOpenAction)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('View recipe'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _metadata(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    ],
  );
}
