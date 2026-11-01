import 'package:flutter/material.dart';

import '../widgets/kitchen_navigation_bar.dart';
import '../widgets/kitchen_destinations.dart';
import 'groceries/grocery_list_screen.dart';
import 'home/home_screen.dart';
import 'meal_plans/weekly_meal_planner_screen.dart';
import 'pantry/my_pantry_screen.dart';
import 'recipes/recipe_catalog_screen.dart';

/// Main destinations load on first visit and retain in-progress UI state.
/// Detail/form routes still use the existing application Navigator.
class KitchenShell extends StatefulWidget {
  const KitchenShell({super.key});

  @override
  State<KitchenShell> createState() => _KitchenShellState();
}

class _KitchenShellState extends State<KitchenShell> {
  int _selected = 0;
  DateTime? _plannerDate;
  int _plannerRequest = 0;
  final Set<int> _visited = {0};
  static const _screens = <Widget>[
    HomeScreen(),
    RecipeCatalogScreen(),
    WeeklyMealPlannerScreen(),
    GroceryListScreen(),
    MyPantryScreen(),
  ];

  void _select(int index) => setState(() {
    _selected = index;
    _visited.add(index);
  });

  @override
  Widget build(BuildContext context) => KitchenDestinations(
    select: _select,
    selectedIndex: _selected,
    plannerDate: _plannerDate,
    plannerRequest: _plannerRequest,
    selectPlanner: (date) => setState(() {
      _plannerDate = date;
      _plannerRequest++;
      _selected = 2;
      _visited.add(2);
    }),
    child: PopScope(
      canPop: _selected == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selected != 0) _select(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selected,
          children: List.generate(
            _screens.length,
            (index) => _visited.contains(index)
                ? TickerMode(
                    enabled: index == _selected,
                    child: _screens[index],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: KitchenNavigationBar(
          selectedIndex: _selected,
          onSelected: _select,
        ),
      ),
    ),
  );
}
