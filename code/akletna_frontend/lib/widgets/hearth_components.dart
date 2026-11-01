import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class HearthBadge extends StatelessWidget {
  const HearthBadge(this.label, {super.key, this.spice = false});
  final String label;
  final bool spice;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: spice ? AppColors.accentContainer : AppColors.primaryLight,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: spice ? AppColors.accentText : AppColors.primaryDark,
      ),
    ),
  );
}

class HearthSection extends StatelessWidget {
  const HearthSection(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class HearthTabs extends StatelessWidget {
  const HearthTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: List.generate(
        labels.length,
        (i) => Expanded(
          child: Semantics(
            selected: selected == i,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 12,
                ),
                backgroundColor: selected == i
                    ? AppColors.primaryDark
                    : Colors.transparent,
                foregroundColor: selected == i
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
              onPressed: () => onSelected(i),
              child: Text(labels[i], textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    ),
  );
}
