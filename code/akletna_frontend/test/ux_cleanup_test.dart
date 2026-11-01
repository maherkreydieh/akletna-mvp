import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/meal_plan.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/screens/home/home_screen.dart';
import 'package:akletna_frontend/screens/meal_plans/weekly_meal_planner_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_catalog_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pantry_test.dart' show HomeAuth;
import 'support/dashboard_fixtures.dart';
import 'weekly_meal_planner_test.dart' show PlannerFixture, RecipeFixture;
import 'stitch_phase4_test.dart' show ReplacementPlanner;
import 'meal_plan_service_test.dart' show mealJson;

Future<void> phone(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, home: screen),
  );
  await tester.pumpAndSettle();
}

MealPlan saved(DateTime date, String name) => MealPlan(
  id: 31,
  recipeId: 11,
  recipeName: name,
  date: date,
  mealType: MealType.lunch,
  plannedServings: 3,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  testWidgets(
    'Home retains displayed date across refresh and shows persisted changes and removal',
    (tester) async {
      final today = mealPlanDay(DateTime.now());
      final date = mealPlanDay(mealPlanWeekStart(today), today.weekday % 7);
      final plans = PlannerFixture()
        ..meals.addAll([
          saved(today, 'Today only'),
          saved(date, 'Selected date lunch'),
        ]);
      await phone(
        tester,
        HomeScreen(
          authService: HomeAuth(),
          mealPlanService: plans,
          recipeService: DashboardRecipes(),
          recommendationService: DashboardRecommendations(),
          groceryListService: DashboardGroceries(),
          matchingService: DashboardMatches(),
        ),
      );
      final dateButton = find.byKey(
        ValueKey('home-date-${mealPlanDate(date)}'),
      );
      await tester.ensureVisible(dateButton);
      await tester.tap(dateButton);
      await tester.pumpAndSettle();
      expect(find.text('Selected date lunch'), findsOneWidget);
      expect(find.text('Today only'), findsNothing);
      expect(find.text('A little room for something delicious.'), findsNothing);
      plans.meals.removeLast();
      plans.meals.add(saved(date, 'Updated saved lunch'));
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.text('ON YOUR TABLE · ${mealPlanDate(date)}'),
        findsOneWidget,
      );
      expect(find.text('Updated saved lunch'), findsOneWidget);
      plans.meals.removeLast();
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.text('A little room for something delicious.'),
        findsOneWidget,
      );
      expect(find.text('Today only'), findsNothing);
      plans.meals.add(saved(date, 'New saved dinner'));
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('New saved dinner'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Full plan').hitTestable(),
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Full plan'));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyMealPlannerScreen), findsOneWidget);
      expect(
        find.byKey(ValueKey('select-date-${mealPlanDate(date)}')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<WeeklyMealPlannerScreen>(
              find.byType(WeeklyMealPlannerScreen),
            )
            .initialDate,
        date,
      );
      expect(find.text('New saved dinner'), findsOneWidget);
    },
  );

  for (final type in MealType.values) {
    testWidgets(
      'Discover search and detail preserve ${type.label} date and save once',
      (tester) async {
        final plans = PlannerFixture();
        final recipes = RecipeFixture();
        final date = DateTime(2026, 11, 4);
        await phone(
          tester,
          WeeklyMealPlannerScreen(
            mealPlanService: plans,
            recipeService: recipes,
            initialDate: date,
          ),
        );
        final add = find.byKey(
          ValueKey('add-${mealPlanDate(date)}-${type.apiValue}'),
        );
        await tester.scrollUntilVisible(
          add.hitTestable(),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(find.byType(RecipeCatalogScreen), findsOneWidget);
        expect(find.text('Choose ${type.label} · 2026-11-04'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'lentil');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Lentil soup').hitTestable(),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Lentil soup'));
        await tester.pumpAndSettle();
        expect(find.byType(RecipeDetailScreen), findsOneWidget);
        final select = find.widgetWithText(
          FilledButton,
          'Select for ${type.label} · 2026-11-04',
        );
        final selectAction = tester.widget<FilledButton>(select).onPressed!;
        selectAction();
        selectAction(); // Guard stale callbacks before the disabled state is rebuilt.
        await tester.pumpAndSettle();
        expect(find.text('Add planned meal?'), findsOneWidget);
        expect(plans.meals, isEmpty);
        final saveAction = tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Add meal'))
            .onPressed!;
        saveAction();
        saveAction();
        await tester.pumpAndSettle();
        expect(plans.meals.length, 1);
        expect(plans.meals.single.date, date);
        expect(plans.meals.single.mealType, type);
        expect(plans.meals.single.recipeId, 11);
        expect(find.byType(RecipeCatalogScreen), findsNothing);
        expect(find.byType(RecipeDetailScreen), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Wednesday Schedule').hitTestable(),
          -100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Wednesday Schedule'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'replacement through Discover requires confirmation and cancellation preserves snapshot',
    (tester) async {
      final plans = ReplacementPlanner()
        ..meals.add(MealPlan.fromJson(mealJson));
      final recipes = RecipeFixture()
        ..recipes = [const Recipe(id: 22, name: 'Chickpea stew', servings: 2)];
      await phone(
        tester,
        WeeklyMealPlannerScreen(
          mealPlanService: plans,
          recipeService: recipes,
          initialDate: DateTime(2026, 9, 28),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('replace-31')).hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('replace-31')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Chickpea stew').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Chickpea stew'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select for Lunch · 2026-09-28'));
      await tester.pumpAndSettle();
      expect(find.text('Change planned recipe?'), findsOneWidget);
      expect(plans.replacedId, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(plans.replacedId, isNull);
      expect(plans.meals.single.id, 31);
      expect(plans.meals.single.recipeId, 11);
    },
  );
}
