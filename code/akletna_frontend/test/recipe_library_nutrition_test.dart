import 'dart:async';

import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/recipe_nutrition.dart';
import 'package:akletna_frontend/screens/recipes/community_recipes_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_catalog_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:akletna_frontend/screens/recipes/create_recipe_screen.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipe_management_test.dart'
    show
        ManagementRecipes,
        ManagementAuth,
        ManagementIngredients,
        ownedRecipe,
        tapVisible;
import 'recipe_service_test.dart' show FixtureApiClient, metadata;

class LibraryFixture extends ManagementRecipes {
  List<Recipe> collection = [ownedRecipe];
  Completer<List<Recipe>>? pending;
  RecipeNutrition nutrition = const RecipeNutrition(
    status: NutritionStatus.unavailable,
  );
  @override
  Future<List<Recipe>> getCommunityRecipes() async {
    if (listFailure != null) throw listFailure!;
    return pending == null ? collection : pending!.future;
  }

  @override
  Future<List<Recipe>> getRecipes() async => collection;
  @override
  Future<RecipeNutrition> getNutrition(int id) async => nutrition;
}

Future<void> community(WidgetTester tester, LibraryFixture service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CommunityRecipesScreen(
        recipeService: service,
        authService: ManagementAuth(),
        ingredientService: ManagementIngredients(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('missing or malformed nutrition never invents macros', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'status': null},
      {'status': 'COMPLETE', 'perServing': null},
      {
        'status': 'COMPLETE',
        'perServing': {'caloriesKcal': 100},
      },
      {'status': 'UNKNOWN'},
    ]) {
      final result = RecipeNutrition.fromJson(json);
      expect(result.status, NutritionStatus.unavailable);
      expect(result.perServing, isNull);
    }
  });
  testWidgets('complete status with missing values displays unavailable', (
    tester,
  ) async {
    final service = LibraryFixture()
      ..nutrition = const RecipeNutrition(status: NutritionStatus.complete);
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
    expect(
      find.text('Nutrition information is not available for this recipe yet.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nutrition-stats')), findsNothing);
  });
  test(
    'community, planner and nutrition use their distinct backend contracts',
    () async {
      final api = FixtureApiClient({
        '/api/recipes/community': [
          {...metadata, 'origin': 'USER', 'visibility': 'PUBLIC'},
        ],
        '/api/recipes/available': [metadata],
        '/api/recipes/11/nutrition': {
          'status': 'UNAVAILABLE',
          'totals': null,
          'perServing': null,
        },
      });
      final service = RecipeService(apiClient: api);
      expect(
        (await service.getCommunityRecipes()).single.visibility,
        RecipeVisibility.public,
      );
      expect((await service.getAvailableRecipes()).single.id, 11);
      expect((await service.getNutrition(11)).perServing, isNull);
      expect(api.requests, [
        '/api/recipes/community',
        '/api/recipes/available',
        '/api/recipes/11/nutrition',
      ]);
      expect(Recipe.fromJson({...metadata, 'servings': null}).servings, isNull);
      expect(ownedRecipe.ingredients.single.toRequestJson()['unit'], 'cup');
    },
  );
  testWidgets('Community loads cards and opens real recipe detail', (
    tester,
  ) async {
    await community(tester, LibraryFixture());
    expect(find.text('Community Recipes'), findsOneWidget);
    await tester.tap(find.text('Lentil soup'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Ingredients'));
    await tester.tap(find.text('Ingredients'));
    await tester.pumpAndSettle();
    expect(find.text('1.5 cup Lentils'), findsOneWidget);
  });
  testWidgets('Community has an honest empty state', (tester) async {
    await community(tester, LibraryFixture()..collection = []);
    expect(find.text('No community recipes yet'), findsOneWidget);
    expect(
      find.text(
        'Public recipes shared by the Akletna community will appear here.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('Community errors provide retry without an empty state', (
    tester,
  ) async {
    final service = LibraryFixture()
      ..listFailure = ApiException(message: 'Connection failed.');
    await community(tester, service);
    expect(find.text('Connection failed.'), findsOneWidget);
    expect(find.text('No community recipes yet'), findsNothing);
    service.listFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Lentil soup'), findsOneWidget);
  });
  testWidgets('Community displays loading while the request is pending', (
    tester,
  ) async {
    final service = LibraryFixture()..pending = Completer<List<Recipe>>();
    await tester.pumpWidget(
      MaterialApp(home: CommunityRecipesScreen(recipeService: service)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No community recipes yet'), findsOneWidget);
  });
  testWidgets(
    'curated Recipes exclude USER and Community excludes curated and private',
    (tester) async {
      const curated = Recipe(
        id: 90,
        name: 'Reviewed recipe',
        origin: RecipeOrigin.curated,
        visibility: RecipeVisibility.public,
      );
      const private = Recipe(id: 91, name: 'Private recipe');
      final service = LibraryFixture()
        ..collection = [curated, ownedRecipe, private];
      await tester.pumpWidget(
        MaterialApp(home: RecipeCatalogScreen(recipeService: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reviewed recipe'), findsOneWidget);
      expect(find.text('Lentil soup'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await community(tester, service);
      expect(find.text('Lentil soup'), findsOneWidget);
      expect(find.text('Reviewed recipe'), findsNothing);
      expect(find.text('Private recipe'), findsNothing);
    },
  );
  testWidgets('complete nutrition renders per serving synthetic fixture only', (
    tester,
  ) async {
    final service = LibraryFixture()
      ..nutrition = const RecipeNutrition(
        status: NutritionStatus.complete,
        totals: NutritionValues(
          caloriesKcal: 492,
          proteinGrams: 16,
          carbohydratesGrams: 48,
          fatGrams: 8,
        ),
        perServing: NutritionValues(
          caloriesKcal: 123,
          proteinGrams: 4,
          carbohydratesGrams: 12,
          fatGrams: 2,
        ),
      );
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
    expect(find.text('Per serving'), findsOneWidget);
    String stat(String id) =>
        tester.widget<Text>(find.byKey(ValueKey('nutrition-$id'))).data!;
    expect(stat('cal'), '123 kcal');
    expect(stat('protein'), '4 g');
    expect(stat('carbs'), '12 g');
    expect(stat('fat'), '2 g');
  });
  testWidgets(
    'unknown and incomplete nutrition never display fabricated zero macros',
    (tester) async {
      for (final status in [
        NutritionStatus.unavailable,
        NutritionStatus.incomplete,
      ]) {
        final service = LibraryFixture()
          ..nutrition = RecipeNutrition(status: status);
        await tester.pumpWidget(
          MaterialApp(
            home: RecipeDetailScreen(
              key: ValueKey(status),
              recipe: ownedRecipe,
              recipeService: service,
              authService: ManagementAuth(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Nutrition information is not available for this recipe yet.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('nutrition-stats')), findsNothing);
      }
    },
  );
  testWidgets(
    'editing changes line unit without changing shared ingredient default',
    (tester) async {
      final service = LibraryFixture()
        ..updateFailure = ApiException(message: 'Keep fixture form open');
      await tester.pumpWidget(
        MaterialApp(
          home: CreateRecipeScreen(
            recipe: ownedRecipe,
            recipeService: service,
            ingredientService: ManagementIngredients(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final unit = find.widgetWithText(TextFormField, 'Unit (g, kg, mL, cup…)');
      await tester.ensureVisible(unit);
      await tester.enterText(unit, 'kg');
      await tapVisible(tester, find.text('Save changes'));
      expect(
        (service.updateRequest!['ingredients'] as List).single['unit'],
        'kg',
      );
    },
  );
}
