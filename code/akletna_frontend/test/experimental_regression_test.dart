import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/core/presentation/quantity_label.dart';
import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/food_preferences.dart';
import 'package:akletna_frontend/models/grocery_list.dart';
import 'package:akletna_frontend/models/meal_plan.dart';
import 'package:akletna_frontend/models/pantry_item.dart';
import 'package:akletna_frontend/models/pantry_matches.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/recipe_shortage.dart';
import 'package:akletna_frontend/screens/groceries/grocery_source_cards.dart';
import 'package:akletna_frontend/screens/meal_plans/weekly_meal_planner_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_catalog_screen.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:akletna_frontend/services/recommendation_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'weekly_meal_planner_test.dart' show PlannerFixture, RecipeFixture;

class CatalogRecipes extends RecipeService {
  @override
  Future<List<Recipe>> getRecipes() async => List.generate(
    30,
    (i) => Recipe(
      id: i + 1,
      name: 'Recipe $i',
      origin: RecipeOrigin.curated,
      visibility: RecipeVisibility.public,
    ),
  );
  @override
  Future<List<Recipe>> getSavedRecipes() async => [];
}

class RecommendationClient extends ApiClient {
  final queries = <Map<String, dynamic>?>[];
  Object? error;
  dynamic data;
  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    queries.add(queryParameters);
    if (error != null) throw error!;
    return Response(
      requestOptions: RequestOptions(path: path),
      data: data,
    );
  }
}

void main() {
  test(
    'labels round only presentation, retaining exact request and model values',
    () {
      for (final entry in {
        '0': '0',
        '1.0000': '1',
        '1.234567': '1.23',
        '1.235': '1.24',
        '1.999': '2',
        '12.5': '12.5',
        '0.00001': '<0.01',
        '999999999999.999999999999': '1000000000000',
        '999999999999.123456789012': '999999999999.12',
      }.entries) {
        expect(decimalQuantityLabel(entry.key), entry.value);
      }
      const ingredient = RecipeIngredient(
        id: 1,
        recipeId: 2,
        ingredientId: 3,
        name: 'Lentils',
        quantity: 1.234567,
        unit: 'g',
      );
      expect(ingredient.displayLine, '1.23 g Lentils');
      expect(ingredient.toRequestJson()['quantity'], 1.234567);
      const grocery = GroceryItem(
        id: 1,
        name: 'Lentils',
        quantity: 1234.567,
        displayQuantity: 1.234567,
        displayUnit: 'kg',
        unit: 'g',
        checked: false,
      );
      expect(grocery.quantityLabel, '1.23 kg');
      expect(grocery.quantity, 1234.567);
      final pantry = PantryItem(
        id: 1,
        ingredientId: 3,
        ingredientName: 'Lentils',
        quantity: '999999999999.123456789012',
        unit: 'g',
        displayQuantity: '999999999999.123456789012',
        displayUnit: 'g',
        updatedAt: DateTime(2026),
      );
      expect(pantry.quantityLabel, '999999999999.12 g');
      expect(pantry.quantity, '999999999999.123456789012');
      const shortage = ShortageIngredient(
        ingredientId: 3,
        name: 'Lentils',
        status: 'SHORTAGE',
        quantity: '1.234567890123',
        unit: 'g',
      );
      expect(shortage.explanation, '1.23 g');
      expect(shortage.quantity, '1.234567890123');
      final match = MatchAmount.fromJson({
        'quantity': '12.3456789',
        'unit': 'g',
      });
      expect(match.label, '12.35 g');
      expect(match.quantity, '12.3456789');
    },
  );

  testWidgets(
    'grocery sources show captured names and rounded amounts without IDs',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrocerySourceCards(
              busy: false,
              onRemove: (_, _) {},
              sources: const [
                GroceryContribution(
                  id: 1,
                  source: 'RECIPE_SHORTAGE',
                  name: 'Soup',
                  ingredients: [
                    ShortageIngredient(
                      ingredientId: 987,
                      name: 'Red lentils',
                      status: 'MISSING',
                      quantity: '2.34567',
                      unit: 'g',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Red lentils'), findsOneWidget);
      expect(find.text('2.35 g'), findsOneWidget);
      expect(find.textContaining('987'), findsNothing);
    },
  );

  for (final width in [320.0, 390.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('planner days fit at width $width and text scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: WeeklyMealPlannerScreen(
              initialDate: DateTime(2026, 10, 11),
              mealPlanService: PlannerFixture(),
              recipeService: RecipeFixture(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final monday = DateTime(2026, 10, 5);
        for (var i = 0; i < 7; i++) {
          final button = find.byKey(
            ValueKey('select-date-${mealPlanDate(mealPlanDay(monday, i))}'),
          );
          expect(button, findsOneWidget);
          final rect = tester.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(rect.width, greaterThanOrEqualTo(32));
          final first = tester.getRect(
            find.byKey(const ValueKey('select-date-2026-10-05')),
          );
          expect(rect.top, closeTo(first.top, 0.01));
          expect(rect.width, closeTo(first.width, 0.01));
        }
        final mondayButton = find.byKey(
          const ValueKey('select-date-2026-10-05'),
        );
        await tester.ensureVisible(mondayButton);
        await tester.tap(mondayButton);
        await tester.pumpAndSettle();
        expect(find.text('Monday Schedule'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('catalog Back to top appears after scroll and returns to start', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RecipeCatalogScreen(recipeService: CatalogRecipes()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back to top'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back to top'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to top'));
    await tester.pumpAndSettle();
    final scroll = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    expect(scroll.controller!.offset, 0);
    expect(find.byTooltip('Back to top'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'recommendation endpoints share filters and preserve API errors',
    () async {
      final client = RecommendationClient();
      final service = RecommendationService(apiClient: client);
      final empty = {
        'pantryEmpty': true,
        'readableRecipeCount': 0,
        'excludedRecipeCount': 0,
        'recommendations': <dynamic>[],
      };
      client.data = empty;
      await service.getRecommendations(
        category: ' Soup ',
        goals: {MealGoal.highProtein},
      );
      client.data = {
        'preferencesConfigured': false,
        'limitations': <String>[],
        'selection': empty,
      };
      await service.getHomeRecommendations(
        category: ' Soup ',
        goals: {MealGoal.highProtein},
      );
      expect(client.queries[0], client.queries[1]);
      expect(client.queries[0], {'category': 'Soup', 'goal': 'HIGH_PROTEIN'});
      for (final home in [false, true]) {
        final error = ApiException(message: 'Session expired', statusCode: 401);
        client.error = error;
        await expectLater(
          home
              ? service.getHomeRecommendations()
              : service.getRecommendations(),
          throwsA(same(error)),
        );
        client.error = null;
        client.data = {'malformed': true};
        await expectLater(
          home
              ? service.getHomeRecommendations()
              : service.getRecommendations(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Could not read recommendations. Please refresh.',
            ),
          ),
        );
      }
    },
  );
}
