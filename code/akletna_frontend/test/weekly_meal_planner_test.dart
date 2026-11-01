import 'dart:async';

import 'package:akletna_frontend/core/constants/app_constants.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/meal_plan.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/recipe_nutrition.dart';
import 'package:akletna_frontend/screens/meal_plans/meal_recipe_picker_screen.dart';
import 'package:akletna_frontend/screens/meal_plans/weekly_meal_planner_screen.dart';
import 'package:akletna_frontend/services/meal_plan_service.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const sourceRecipe = Recipe(
  id: 11,
  name: 'Lentil soup',
  category: 'Soup',
  servings: 4,
);

class PlannerFixture extends MealPlanService {
  final meals = <MealPlan>[];
  final weeks = <DateTime>[];
  final removed = <int>[];
  final updates = <int>[];
  Object? loadError;
  Object? mutationError;
  Completer<List<MealPlan>>? pending;

  @override
  Future<List<MealPlan>> getWeek(DateTime date) async {
    weeks.add(date);
    if (loadError != null) throw loadError!;
    if (pending != null) return pending!.future;
    return List.of(meals);
  }

  @override
  Future<MealPlan> addMeal({
    required int recipeId,
    required int plannedServings,
    required DateTime date,
    required MealType mealType,
  }) async {
    if (mutationError != null) throw mutationError!;
    final meal = MealPlan(
      id: 31,
      recipeId: recipeId,
      recipeName: sourceRecipe.name,
      recipeCategory: sourceRecipe.category,
      date: date,
      mealType: mealType,
      createdAt: DateTime(2026, 10, 3),
      plannedServings: plannedServings,
    );
    meals.add(meal);
    return meal;
  }

  @override
  Future<void> removeMeal(int id) async {
    if (mutationError != null) throw mutationError!;
    removed.add(id);
    meals.removeWhere((meal) => meal.id == id);
  }

  @override
  Future<MealPlan> updateServings(MealPlan meal, int servings) async {
    if (mutationError != null) throw mutationError!;
    updates.add(servings);
    final updated = MealPlan(
      id: meal.id,
      recipeId: meal.recipeId,
      recipeName: meal.recipeName,
      recipeCategory: meal.recipeCategory,
      date: meal.date,
      mealType: meal.mealType,
      createdAt: meal.createdAt,
      plannedServings: servings,
    );
    meals[meals.indexWhere((candidate) => candidate.id == meal.id)] = updated;
    return updated;
  }
}

class RecipeFixture extends RecipeService {
  @override
  Future<Recipe> getRecipeById(int id) async =>
      recipes.firstWhere((r) => r.id == id);
  @override
  Future<RecipeNutrition> getNutrition(int id) async =>
      const RecipeNutrition(status: NutritionStatus.unavailable);
  @override
  Future<List<Recipe>> getSavedRecipes() async => [];
  int reads = 0;
  List<Recipe> recipes = [sourceRecipe];
  Object? error;
  @override
  Future<List<Recipe>> getAvailableRecipes() async {
    reads++;
    if (error != null) throw error!;
    return recipes;
  }
}

Widget plannerApp(PlannerFixture planner, [RecipeFixture? recipes]) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: WeeklyMealPlannerScreen(
        mealPlanService: planner,
        recipeService: recipes ?? RecipeFixture(),
        initialDate: DateTime(2026, 9, 28),
      ),
      routes: {
        AppConstants.loginRoute: (_) =>
            const Scaffold(body: Text('Login destination')),
      },
    );

Future<void> chooseLunch(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('add-2026-09-28-LUNCH')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lentil soup'));
  await tester.pumpAndSettle();
  final selection = find.widgetWithText(
    FilledButton,
    'Select for Lunch · 2026-09-28',
  );
  if (tester.widget<FilledButton>(selection).onPressed != null) {
    await tester.tap(selection);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'planned display survives unavailable source without catalog requests',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final planner = PlannerFixture();
      planner.meals.add(
        MealPlan(
          id: 31,
          recipeId: 11,
          recipeName: 'Original planned rice',
          plannedServings: 2,
          recipeBaseServings: 4,
          date: DateTime(2026, 9, 28),
          mealType: MealType.lunch,
          createdAt: DateTime(2026, 9, 27),
        ),
      );
      final recipes = RecipeFixture()
        ..error = ApiException(message: 'Unavailable', statusCode: 404);
      await tester.pumpWidget(plannerApp(planner, recipes));
      await tester.pumpAndSettle();
      expect(find.text('Original planned rice'), findsOneWidget);
      expect(find.textContaining('2 servings'), findsOneWidget);
      expect(recipes.reads, 0);
      expect(find.text('Could not load your meal plan.'), findsNothing);
    },
  );

  testWidgets(
    'unresolved legacy meal stays removable with serving edit disabled',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final planner = PlannerFixture();
      planner.meals.add(
        MealPlan(
          id: 31,
          recipeId: 11,
          recipeName: 'Unresolved planned meal',
          snapshotState: 'UNRESOLVED',
          date: DateTime(2026, 9, 28),
          mealType: MealType.lunch,
          createdAt: DateTime(2026, 9, 27),
        ),
      );
      await tester.pumpWidget(plannerApp(planner));
      await tester.pumpAndSettle();
      expect(find.text('Unresolved planned meal'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('edit-servings-31')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('remove-31')))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'base servings default, increment, decrement and lower bound reach the create request',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final planner = PlannerFixture();
      await tester.pumpWidget(plannerApp(planner));
      await tester.pumpAndSettle();
      await chooseLunch(tester);
      expect(find.text('Servings: 4'), findsOneWidget);
      await tester.tap(find.byTooltip('Increase servings'));
      await tester.pump();
      expect(find.text('Servings: 5'), findsOneWidget);
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Decrease servings'));
        await tester.pump();
      }
      expect(find.text('Servings: 1'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Decrease servings',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Add meal'));
      await tester.pumpAndSettle();
      expect(planner.meals.single.plannedServings, 1);
      expect(find.textContaining('1 serving'), findsOneWidget);
      expect(sourceRecipe.servings, 4);
    },
  );
  testWidgets(
    'existing planned servings can be edited without recreating a meal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final planner = PlannerFixture();
      await planner.addMeal(
        recipeId: 11,
        plannedServings: 4,
        date: DateTime(2026, 9, 28),
        mealType: MealType.lunch,
      );
      await tester.pumpWidget(plannerApp(planner));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-servings-31')));
      await tester.pumpAndSettle();
      expect(find.text('Servings: 4'), findsOneWidget);
      for (int i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Increase servings'));
        await tester.pump();
      }
      await tester.tap(find.text('Save servings'));
      await tester.pumpAndSettle();
      expect(planner.updates, [6]);
      expect(planner.meals.single.id, 31);
      expect(find.textContaining('6 servings'), findsOneWidget);
      expect(planner.removed, isEmpty);
      expect(sourceRecipe.servings, 4);
    },
  );
  testWidgets(
    'failed planned-serving update retains stored count and reloads',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final planner = PlannerFixture();
      await planner.addMeal(
        recipeId: 11,
        plannedServings: 4,
        date: DateTime(2026, 9, 28),
        mealType: MealType.lunch,
      );
      planner.mutationError = ApiException(
        message: 'Server error',
        statusCode: 500,
      );
      await tester.pumpWidget(plannerApp(planner));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-servings-31')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Increase servings'));
      await tester.pump();
      await tester.tap(find.text('Save servings'));
      await tester.pumpAndSettle();
      expect(planner.meals.single.plannedServings, 4);
      expect(find.textContaining('4 servings'), findsOneWidget);
      expect(
        find.text(
          'Could not confirm serving changes. Refresh your plan before trying again.',
        ),
        findsOneWidget,
      );
      expect(planner.weeks.length, 2);
    },
  );
  testWidgets('editing servings with an expired session returns to login', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planner = PlannerFixture();
    await planner.addMeal(
      recipeId: 11,
      plannedServings: 4,
      date: DateTime(2026, 9, 28),
      mealType: MealType.lunch,
    );
    planner.mutationError = ApiException(message: 'Expired', statusCode: 401);
    await tester.pumpWidget(plannerApp(planner));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-servings-31')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase servings'));
    await tester.pump();
    await tester.tap(find.text('Save servings'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
  });
  testWidgets(
    'invalid legacy recipe baseline cannot silently default a new meal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final recipes = RecipeFixture()
        ..recipes = [const Recipe(id: 11, name: 'Lentil soup', servings: null)];
      final planner = PlannerFixture();
      await tester.pumpWidget(plannerApp(planner, recipes));
      await tester.pumpAndSettle();
      await chooseLunch(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Select for Lunch · 2026-09-28',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Add planned meal?'), findsNothing);
      expect(planner.meals, isEmpty);
    },
  );

  testWidgets(
    'empty week selects Monday through Sunday and all four slots on a phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(360, 720));
      final planner = PlannerFixture();
      await tester.pumpWidget(plannerApp(planner));
      await tester.pumpAndSettle();
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      for (var day = 0; day < 7; day++) {
        final date = mealPlanDay(DateTime(2026, 9, 28), day);
        final button = find.byKey(
          ValueKey('select-date-${mealPlanDate(date)}'),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('${days[day]} Schedule'), findsOneWidget);
        for (final type in MealType.values) {
          final slot = find.byKey(
            ValueKey('add-${mealPlanDate(date)}-${type.apiValue}'),
          );
          await tester.scrollUntilVisible(
            slot,
            100,
            scrollable: find.byType(Scrollable).first,
          );
          expect(slot, findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'add, refresh, cancel removal, remove and refresh use planned entry IDs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final planner = PlannerFixture();
      final original = sourceRecipe.toJson();
      await tester.pumpWidget(plannerApp(planner));
      await tester.pumpAndSettle();
      await chooseLunch(tester);
      expect(planner.meals, isEmpty);
      await tester.tap(find.text('Add meal'));
      await tester.pumpAndSettle();
      expect(planner.meals.single.mealType, MealType.lunch);
      expect(mealPlanDate(planner.meals.single.date), '2026-09-28');
      expect(find.text('Lentil soup'), findsOneWidget);
      // Pull-to-refresh is the only refresh control on the planner.
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await tester.pumpAndSettle();
      expect(find.text('Lentil soup'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('remove-31')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(planner.removed, isEmpty);
      await tester.tap(find.byKey(const ValueKey('remove-31')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove meal'));
      await tester.pumpAndSettle();
      expect(planner.removed, [31]);
      // Pull-to-refresh is the only refresh control on the planner.
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await tester.pumpAndSettle();
      expect(find.text('Lentil soup'), findsNothing);
      expect(
        find.byKey(const ValueKey('add-2026-09-28-LUNCH')),
        findsOneWidget,
      );
      expect(planner.weeks.length, 5);
      expect(sourceRecipe.toJson(), original);
    },
  );

  testWidgets('cancel add never saves a planned meal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planner = PlannerFixture();
    await tester.pumpWidget(plannerApp(planner));
    await tester.pumpAndSettle();
    await chooseLunch(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(planner.meals, isEmpty);
  });

  testWidgets('week navigation loads the selected calendar week', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planner = PlannerFixture();
    await tester.pumpWidget(plannerApp(planner));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(mealPlanDate(planner.weeks.last), '2026-10-05');
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    expect(mealPlanDate(planner.weeks.last), '2026-09-28');
  });

  testWidgets('loading and retry hide technical failures and recover', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planner = PlannerFixture()..pending = Completer<List<MealPlan>>();
    await tester.pumpWidget(plannerApp(planner));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    planner.pending!.completeError(StateError('private stack details'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('private stack details'), findsNothing);
    planner.pending = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your week is empty. Tap an empty slot to plan a meal.'),
      findsOneWidget,
    );
  });

  testWidgets('401 while loading redirects to existing login route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planner = PlannerFixture()
      ..loadError = ApiException(message: 'Session expired', statusCode: 401);
    await tester.pumpWidget(plannerApp(planner));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
  });

  testWidgets('failed add refreshes and offers a readable message', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planner = PlannerFixture()
      ..mutationError = StateError('private stack details');
    await tester.pumpWidget(plannerApp(planner));
    await tester.pumpAndSettle();
    await chooseLunch(tester);
    await tester.tap(find.text('Add meal'));
    await tester.pumpAndSettle();
    expect(planner.weeks.length, 2);
    expect(
      find.textContaining('Could not confirm the new meal'),
      findsOneWidget,
    );
    expect(find.textContaining('private stack details'), findsNothing);
  });

  testWidgets('401 while adding returns to login without a false saved meal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planner = PlannerFixture()
      ..mutationError = ApiException(
        message: 'Session expired',
        statusCode: 401,
      );
    await tester.pumpWidget(plannerApp(planner));
    await tester.pumpAndSettle();
    await chooseLunch(tester);
    await tester.tap(find.text('Add meal'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    expect(planner.meals, isEmpty);
  });

  testWidgets('failed removal keeps the persisted meal after reload', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planner = PlannerFixture();
    await planner.addMeal(
      plannedServings: 4,
      recipeId: 11,
      date: DateTime(2026, 9, 28),
      mealType: MealType.lunch,
    );
    planner.mutationError = ApiException(
      message: 'Server error',
      statusCode: 500,
    );
    await tester.pumpWidget(plannerApp(planner));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-31')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove meal'));
    await tester.pumpAndSettle();
    expect(find.text('Lentil soup'), findsOneWidget);
    expect(planner.removed, isEmpty);
    expect(planner.weeks.length, 2);
    expect(find.textContaining('Could not confirm removal'), findsOneWidget);
  });

  testWidgets(
    'recipe images are optional; picker errors retry and search uses existing recipes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final recipes = RecipeFixture()..error = ApiException(message: 'Offline');
      await tester.pumpWidget(plannerApp(PlannerFixture(), recipes));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('add-2026-09-28-LUNCH')));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      recipes.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kibbeh');
      await tester.pumpAndSettle();
      expect(find.text('No matching recipes'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'lentil');
      await tester.pumpAndSettle();
      expect(find.text('Lentil soup'), findsOneWidget);
    },
  );

  testWidgets('recipe picker with no recipes has a useful empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final recipes = RecipeFixture()..recipes = [];
    await tester.pumpWidget(
      MaterialApp(home: MealRecipePickerScreen(recipeService: recipes)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No recipes available yet. Add a recipe before planning a meal.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });
}
