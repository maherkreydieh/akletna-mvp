import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/meal_plan.dart';
import 'package:akletna_frontend/screens/home/home_dashboard.dart';
import 'package:akletna_frontend/screens/recipes/recipe_catalog_screen.dart';
import 'package:akletna_frontend/widgets/recipe_spotlight.dart';
import 'package:akletna_frontend/widgets/recipe_image.dart';
import 'package:akletna_frontend/widgets/weekday_strip.dart';
import 'package:akletna_frontend/widgets/kitchen_destinations.dart';

import 'experimental_regression_test.dart' show CatalogRecipes;
import 'support/dashboard_fixtures.dart';
import 'pantry_test.dart' show HomeAuth;

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Home weekdays center in one equal-width row at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeDashboard(
                selectedDate: DateTime(2026, 10, 29),
                onDateSelected: (_) {},
                refreshToken: 0,
                openPlanner: (_) {},
                openGroceries: () {},
                openPantryMatches: () {},
                openDiscover: () {},
                openPreferences: () {},
                recommendationService: DashboardRecommendations(),
                recipeService: DashboardRecipes(),
                mealPlanService: DashboardPlans(),
                groceryService: DashboardGroceries(),
                matchingService: DashboardMatches(),
                authService: HomeAuth(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rects = [
        for (var i = 0; i < 7; i++)
          tester.getRect(
            find.byKey(
              ValueKey('home-date-${mealPlanDate(DateTime(2026, 10, 26 + i))}'),
            ),
          ),
      ];
      final strip = tester.getRect(find.byType(WeekdayStrip));
      expect(rects.first.left, closeTo(strip.left, 0.01));
      expect(rects.last.right, closeTo(strip.right, 0.01));
      for (final rect in rects) {
        expect(rect.top, rects.first.top);
        expect(rect.width, closeTo(rects.first.width, 0.01));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'inset spotlight has no obscured fallback label but detail retains it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                RecipeSpotlight(
                  title: 'Hummus',
                  description: 'A familiar dish',
                  insetTitle: true,
                  onOpen: () {},
                ),
                const RecipeImage(),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Image unavailable'), findsOneWidget);
      final image = tester.widget<RecipeImage>(
        find.descendant(
          of: find.byType(RecipeSpotlight),
          matching: find.byType(RecipeImage),
        ),
      );
      expect(image.showPlaceholderLabel, isFalse);
      expect(find.text('Hummus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'catalog button reconciles after destination refresh and layout reset',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = 1;
      late StateSetter update;
      final service = CatalogRecipes();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return KitchenDestinations(
                selectedIndex: selected,
                select: (_) {},
                child: IndexedStack(
                  index: selected == 1 ? 0 : 1,
                  children: [
                    RecipeCatalogScreen(recipeService: service),
                    const Scaffold(body: Text('Other destination')),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1100));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back to top'), findsOneWidget);
      update(() => selected = 2);
      await tester.pumpAndSettle();
      update(() => selected = 1);
      await tester.pumpAndSettle();
      final scroll = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(
        find.byTooltip('Back to top'),
        scroll.controller!.offset > 400 ? findsOneWidget : findsNothing,
      );
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Back to top'),
        scroll.controller!.offset > 400 ? findsOneWidget : findsNothing,
      );
      if (scroll.controller!.offset > 400) {
        await tester.tap(find.byTooltip('Back to top'));
        await tester.pumpAndSettle();
      }
      expect(find.byTooltip('Back to top'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
