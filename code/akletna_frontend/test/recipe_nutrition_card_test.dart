import 'package:akletna_frontend/models/recipe_nutrition.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:akletna_frontend/widgets/recipe_nutrition_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipe_library_nutrition_test.dart' show LibraryFixture;
import 'recipe_management_test.dart' show ownedRecipe, ManagementAuth;

const macros = {
  'caloriesKcal': 120,
  'proteinGrams': 10,
  'carbohydratesGrams': 15,
  'fatGrams': 2,
};
Map<String, dynamic> complete() => {
  'status': 'COMPLETE',
  'totals': {
    'caloriesKcal': 480,
    'proteinGrams': 40,
    'carbohydratesGrams': 60,
    'fatGrams': 8,
  },
  'perServing': macros,
  'issues': <dynamic>[],
};

class CountingNutrition extends LibraryFixture {
  int nutritionReads = 0;
  @override
  Future<RecipeNutrition> getNutrition(int id) async {
    nutritionReads++;
    return RecipeNutrition.fromJson(complete());
  }
}

void main() {
  test('complete response preserves totals and scales the batch without changing portion size', () {
    final nutrition = RecipeNutrition.fromJson(complete());
    expect(nutrition.totals!.caloriesKcal, 480);
    expect(nutrition.totalForServings(4, 8)!.caloriesKcal, 960);
    expect(nutrition.perServingFor(4, 8)!.caloriesKcal, 120);
    expect(nutrition.totalForServings(4, 1)!.proteinGrams, 10);
    expect(nutrition.totalForServings(0, 8), isNull);
    expect(nutrition.totalForServings(4, 0), isNull);
  });

  test('complete status cannot hide partial totals or unresolved issues', () {
    for (final json in [
      {...complete(), 'totals': null},
      {
        ...complete(),
        'totals': {'caloriesKcal': 480},
      },
      {
        ...complete(),
        'totals': {...macros, 'fatGrams': -1},
      },
      {
        ...complete(),
        'perServing': {...macros, 'caloriesKcal': double.nan},
      },
      {
        ...complete(),
        'issues': [
          {'recipeIngredientId': 21, 'reason': 'MISSING_MAPPING'},
        ],
      },
    ]) {
      final result = RecipeNutrition.fromJson(json);
      expect(result.status, NutritionStatus.unavailable);
      expect(result.totals, isNull);
      expect(result.perServing, isNull);
    }
  });

  test('incomplete response with accidental numeric fields never exposes partial totals', () {
    final result = RecipeNutrition.fromJson({
      ...complete(),
      'status': 'INCOMPLETE',
      'issues': [
        {'recipeIngredientId': 21, 'reason': 'UNSUPPORTED_QUANTITY_OR_UNIT'},
      ],
    });
    expect(result.totals, isNull);
    expect(result.perServingFor(4, 8), isNull);
    expect(result.issues.single.recipeIngredientId, 21);
  });

  testWidgets(
    'serving adjustment updates visible batch totals without another nutrition request',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = CountingNutrition();
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeDetailScreen(
            recipe: ownedRecipe,
            recipeService: service,
            authService: ManagementAuth(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ingredients'));
      await tester.tap(find.text('Ingredients'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Increase servings'));
      await tester.tap(find.byTooltip('Increase servings'));
      await tester.pumpAndSettle();
      expect(find.text('Servings: 5'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Recipe'));
      await tester.tap(find.widgetWithText(TextButton, 'Recipe'));
      await tester.pumpAndSettle();
      expect(find.text('Total for 5 servings'), findsOneWidget);
      expect(find.textContaining('600 kcal ·'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('nutrition-cal'))).data,
        '120 kcal',
      );
      expect(service.nutritionReads, 1);
    },
  );

  testWidgets(
    'mapping and unsupported-unit issues identify actual ingredient lines without macros',
    (tester) async {
      final nutrition = RecipeNutrition.fromJson({
        'status': 'INCOMPLETE',
        'totals': null,
        'perServing': null,
        'issues': [
          {'recipeIngredientId': 21, 'reason': 'MISSING_MAPPING'},
          {'recipeIngredientId': 22, 'reason': 'UNSUPPORTED_QUANTITY_OR_UNIT'},
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecipeNutritionCard(
                nutrition: nutrition,
                loading: false,
                failed: false,
                onRetry: () {},
                baseServings: 4,
                selectedServings: 8,
                ingredientNames: const {21: 'Lentils', 22: 'Olive oil'},
              ),
            ),
          ),
        ),
      );
      expect(find.text('INCOMPLETE'), findsOneWidget);
      expect(find.textContaining('Lentils: A reviewed food'), findsOneWidget);
      expect(
        find.textContaining('Olive oil: A positive quantity in g or kg'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('nutrition-stats')), findsNothing);
      expect(
        find.textContaining('Partial totals are withheld'),
        findsOneWidget,
      );
    },
  );
}
