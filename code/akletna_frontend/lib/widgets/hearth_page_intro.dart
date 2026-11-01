import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// A shared editorial header for the kitchen's secondary routes.
class HearthPageIntro extends StatelessWidget {
  const HearthPageIntro({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.restaurant_menu,
  });
  final String title, subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryDark, size: 28),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

/// Constrains forms on tablets without compromising keyboard scrolling.
class HearthFormSurface extends StatelessWidget {
  const HearthFormSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    ),
  );
}
