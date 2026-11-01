import 'dart:io';
import 'dart:ui' as ui;

import 'package:akletna_frontend/core/presentation/pantry_quantity_step.dart';
import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/meal_plan.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/pantry_item.dart';
import 'package:akletna_frontend/models/grocery_list.dart';
import 'package:akletna_frontend/screens/meal_plans/weekly_meal_planner_screen.dart';
import 'package:akletna_frontend/screens/groceries/grocery_list_screen.dart';
import 'package:akletna_frontend/screens/pantry/my_pantry_screen.dart';
import 'package:akletna_frontend/screens/pantry/cook_with_what_i_have_screen.dart';
import 'package:akletna_frontend/services/meal_plan_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'weekly_meal_planner_test.dart' show PlannerFixture, RecipeFixture;
import 'pantry_test.dart'
    show PantryFixture, IngredientsFixture, pantryJson, presence;
import 'grocery_list_screen_test.dart' show GroceryFixture, withCheck;
import 'meal_plan_service_test.dart' show mealJson;
import 'recipe_service_test.dart' show FixtureApiClient;
import 'pantry_matching_test.dart' show MatchFixture;
import 'recipe_shortage_test.dart' show ShortageFixture;

class ReplacementPlanner extends PlannerFixture {
  int? replacedId, newRecipeId, newServings;
  DateTime? replacementDate;
  MealType? replacementType;
  @override
  Future<MealPlan> replaceRecipe(
    MealPlan meal,
    int recipeId,
    int plannedServings,
  ) async {
    replacedId = meal.id;
    newRecipeId = recipeId;
    newServings = plannedServings;
    replacementDate = meal.date;
    replacementType = meal.mealType;
    final result = MealPlan(
      id: meal.id,
      recipeId: recipeId,
      recipeName: 'Chickpea stew',
      plannedServings: plannedServings,
      recipeBaseServings: 2,
      date: meal.date,
      mealType: meal.mealType,
      createdAt: meal.createdAt,
    );
    meals[meals.indexWhere((m) => m.id == meal.id)] = result;
    return result;
  }
}

const _capture = ValueKey('phase4-capture');
Future<void> screen(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  double width = 390,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(key: _capture, child: child),
      routes: {
        '/login': (_) => const Scaffold(body: Text('Login destination')),
      },
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder.hitTestable(),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('STITCH_CAPTURE')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/stitch-phase4').create(recursive: true);
    await File('build/stitch-phase4/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  test(
    'quantity stepping preserves all decimal digits and existing limits',
    () {
      expect(pantryQuantityStep('500.123456789012', 1), '501.123456789012');
      expect(pantryQuantityStep('500.123456789012', -1), '499.123456789012');
      expect(pantryQuantityStep('0.000000000001', 1), '1.000000000001');
      expect(pantryQuantityStep('1', -1), isNull);
      expect(pantryQuantityStep('0.5', -1), isNull);
      expect(pantryQuantityStep('999999999999999.999999999999', 1), isNull);
      expect(pantryQuantityStep(null, 1), isNull);
    },
  );
  test(
    'replacement PUT keeps the entry ID, date, meal type and selected servings',
    () async {
      final old = MealPlan.fromJson(mealJson);
      final api = FixtureApiClient({
        '/api/meal-plans/31': {
          ...mealJson,
          'recipeId': 22,
          'plannedServings': 3,
        },
      });
      final result = await MealPlanService(apiClient: api)
          .replaceRecipe(old, 22, 3);
      expect(api.mutations, ['PUT /api/meal-plans/31']);
      expect(api.posted, {
        'recipeId': 22,
        'date': '2026-09-28',
        'mealType': 'LUNCH',
        'plannedServings': 3,
      });
      expect(result.recipeId, 22);
      expect(old.recipeId, 11);
    },
  );
  testWidgets(
    'planner changes a saved meal via the picker without delete and re-add',
    (tester) async {
      final planner = ReplacementPlanner()
        ..meals.add(MealPlan.fromJson(mealJson));
      final recipes = RecipeFixture()
        ..recipes = [const Recipe(id: 22, name: 'Chickpea stew', servings: 2)];
      await screen(
        tester,
        WeeklyMealPlannerScreen(
          mealPlanService: planner,
          recipeService: recipes,
          initialDate: DateTime(2026, 9, 28),
        ),
      );
      await capture(tester, 'planner');
      await tapVisible(tester, find.byKey(const ValueKey('replace-31')));
      await tester.tap(find.text('Chickpea stew'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select for Lunch · 2026-09-28'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Increase servings'));
      await tester.pump();
      await tester.tap(find.text('Change recipe'));
      await tester.pumpAndSettle();
      expect(planner.replacedId, 31);
      expect(planner.newRecipeId, 22);
      expect(planner.newServings, 3);
      expect(planner.replacementType, MealType.lunch);
      expect(mealPlanDate(planner.replacementDate!), '2026-09-28');
      expect(planner.removed, isEmpty);
      expect(planner.meals.length, 1);
      expect(find.text('Chickpea stew'), findsOneWidget);
    },
  );
  testWidgets(
    'selected day uses real dates and weekly totals include other days',
    (tester) async {
      final planner = PlannerFixture()..meals.add(MealPlan.fromJson(mealJson));
      await screen(
        tester,
        WeeklyMealPlannerScreen(
          mealPlanService: planner,
          initialDate: DateTime(2026, 9, 29),
        ),
      );
      expect(find.text('Tuesday Schedule'), findsOneWidget);
      expect(find.text('Lentil soup'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('select-date-2026-09-28')),
      );
      await tester.tap(find.byKey(const ValueKey('select-date-2026-09-28')));
      await tester.pumpAndSettle();
      expect(find.text('Lentil soup'), findsOneWidget);
      await tapVisible(tester, find.text('Your Weekly Table'));
      expect(find.text('1 planned meal this week'), findsOneWidget);
    },
  );
  testWidgets(
    'grocery opening, refresh and cancelled generation keep saved checks',
    (tester) async {
      final grocery = GroceryFixture()
        ..items = [
          withCheck(
            const GroceryItem(
              id: 100,
              name: 'Rice',
              quantity: 2,
              unit: 'cup',
              checked: false,
            ),
            true,
          ),
        ];
      await screen(
        tester,
        GroceryListScreen(
          groceryListService: grocery,
          initialDate: DateTime(2026, 9, 28),
        ),
      );
      await capture(tester, 'grocery');
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('grocery-100')))
            .value,
        isTrue,
      );
      await tester.tap(find.byTooltip('Refresh groceries'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Generate Grocery List'));
      expect(
        find.textContaining('Purchased checks will reset'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(grocery.weeks, isEmpty);
      expect(grocery.items.single.checked, isTrue);
    },
  );
  testWidgets(
    'same-name rows and incompatible units remain independent under filters',
    (tester) async {
      final grocery = GroceryFixture()
        ..items = [
          const GroceryItem(
            id: 1,
            name: 'Rice',
            quantity: 150,
            unit: 'g',
            checked: false,
          ),
          const GroceryItem(
            id: 2,
            name: 'Rice',
            quantity: 200,
            unit: 'g',
            checked: true,
          ),
          const GroceryItem(
            id: 3,
            name: 'Rice',
            quantity: 2,
            unit: 'cup',
            checked: false,
          ),
        ];
      await screen(tester, GroceryListScreen(groceryListService: grocery));
      for (final id in [1, 2, 3]) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('grocery-$id')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(ValueKey('grocery-$id')), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Purchased'));
      await tester.tap(find.text('Purchased'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('grocery-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('grocery-1')), findsNothing);
      expect(find.byKey(const ValueKey('grocery-3')), findsNothing);
      expect(grocery.weeks, isEmpty);
    },
  );
  testWidgets(
    'sources show ingredient names and uncertain requirement explanations',
    (tester) async {
      await screen(
        tester,
        GroceryListScreen(groceryListService: ShortageFixture()..added = true),
      );
      await tester.tap(find.text('Recipe sources'));
      await tester.pumpAndSettle();
      expect(find.text('Rice recipe'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      expect(find.textContaining('Ingredient #'), findsNothing);
      expect(find.textContaining('incompatible unit'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    },
  );
  testWidgets(
    'pantry uses inventory IDs and canonical units without decimal loss',
    (tester) async {
      final pantry = PantryFixture()
        ..items = [
          PantryItem.fromJson(
            pantryJson(
              quantity: '500.123456789012',
              displayQuantity: '500.123456789012',
              displayUnit: 'g',
            ),
          ),
        ];
      await screen(
        tester,
        MyPantryScreen(
          pantryService: pantry,
          ingredientService: IngredientsFixture(),
        ),
      );
      await capture(tester, 'pantry');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('pantry-increase-41')),
      );
      expect(pantry.items.single.id, 41);
      expect(pantry.items.single.ingredientId, 7);
      expect(pantry.items.single.quantity, '501.123456789012');
      expect(pantry.items.single.unit, 'g');
      expect(pantry.updates, 1);
    },
  );
  testWidgets(
    'pantry amount filters and search keep unknown quantities explicit',
    (tester) async {
      final pantry = PantryFixture()
        ..items = [PantryItem.fromJson(pantryJson()), presence()];
      await screen(
        tester,
        MyPantryScreen(
          pantryService: pantry,
          ingredientService: IngredientsFixture(),
        ),
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Amount unknown'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Amount unknown'));
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pantry-42')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('pantry-increase-42')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('In pantry'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'rice');
      await tester.pumpAndSettle();
      expect(
        find.text('No ingredients match your search or filter.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'pantry matching uses the existing matching screen and services',
    (tester) async {
      await screen(
        tester,
        MyPantryScreen(
          pantryService: PantryFixture(),
          ingredientService: IngredientsFixture(),
          matchingService: MatchFixture(),
        ),
      );
      await tapVisible(tester, find.text('Find matching recipes'));
      expect(find.byType(CookWithWhatIHaveScreen), findsOneWidget);
    },
  );
  testWidgets('all Phase 4 screens remain usable at 320dp and 1.8 text scale', (
    tester,
  ) async {
    final planner = PlannerFixture()..meals.add(MealPlan.fromJson(mealJson));
    await screen(
      tester,
      WeeklyMealPlannerScreen(
        mealPlanService: planner,
        initialDate: DateTime(2026, 9, 28),
      ),
      width: 320,
      scale: 1.8,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('remove-31')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await screen(
      tester,
      GroceryListScreen(groceryListService: GroceryFixture()),
      width: 320,
      scale: 1.8,
    );
    await tester.scrollUntilVisible(
      find.text('Shopping progress'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await screen(
      tester,
      MyPantryScreen(
        pantryService: PantryFixture()
          ..items = [PantryItem.fromJson(pantryJson())],
      ),
      width: 320,
      scale: 1.8,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pantry-increase-41')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
