import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Shared, scroll-safe empty/error content. Can also sit inside a list.
class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primaryLight,
            child: Icon(icon, size: 30, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        if (onAction != null) ...[
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel ?? 'Retry'),
          ),
        ],
      ],
    ),
  );
}

class AppErrorView extends StatelessWidget {
  final String title;
  final VoidCallback? onRetry;
  const AppErrorView({super.key, required this.title, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: AppStateView(
        icon: Icons.cloud_off_outlined,
        title: title,
        message: 'Check your connection and try again.',
        onAction: onRetry,
      ),
    ),
  );
}
