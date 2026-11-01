import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Shared native navigation. Labels remain readable at increased text scales.
class KitchenNavigationBar extends StatelessWidget {
  const KitchenNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const labels = ['Home', 'Discover', 'Meal Plan', 'Grocery', 'Pantry'];
  static const icons = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.calendar_month_outlined,
    Icons.shopping_cart_outlined,
    Icons.inventory_2_outlined,
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    elevation: 8,
    shadowColor: AppColors.primaryDark.withValues(alpha: .12),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(labels.length, (index) {
            final selected = index == selectedIndex;
            return Expanded(
              child: Semantics(
                selected: selected,
                button: true,
                child: Tooltip(
                  message: labels[index],
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: () => onSelected(index),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryDark
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[index],
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
