import 'support/dashboard_fixtures.dart';

import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/screens/home/home_screen.dart';
import 'package:akletna_frontend/widgets/kitchen_destinations.dart';
import 'package:akletna_frontend/widgets/kitchen_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pantry_test.dart' show HomeAuth;

void main() {
  testWidgets('all destinations are usable at 320dp with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: StatefulBuilder(
          builder: (context, setState) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              bottomNavigationBar: KitchenNavigationBar(
                selectedIndex: selected,
                onSelected: (index) => setState(() => selected = index),
              ),
            ),
          ),
        ),
      ),
    );
    for (var index = 0; index < KitchenNavigationBar.labels.length; index++) {
      await tester.tap(find.text(KitchenNavigationBar.labels[index]));
      await tester.pumpAndSettle();
      expect(selected, index);
      expect(tester.takeException(), isNull);
      final target = tester.getSize(find.byType(InkWell).at(index));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('Home planner action selects shell destination', (tester) async {
    int? destination;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: KitchenDestinations(
          select: (index) => destination = index,
          child: HomeScreen(
            recommendationService: DashboardRecommendations(),
            recipeService: DashboardRecipes(),
            mealPlanService: DashboardPlans(),
            groceryListService: DashboardGroceries(),
            matchingService: DashboardMatches(),
            authService: HomeAuth(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Full plan'));
    await tester.tap(find.text('Full plan'));
    await tester.pumpAndSettle();
    expect(destination, 2);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
