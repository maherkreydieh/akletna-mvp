import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:akletna_frontend/models/food_preferences.dart';
import 'package:akletna_frontend/models/ingredient.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/recipe_evaluation.dart';
import 'package:akletna_frontend/services/preferences_service.dart';
import 'package:akletna_frontend/services/ingredient_service.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:akletna_frontend/screens/preferences/food_preferences_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_catalog_screen.dart';
import 'package:akletna_frontend/widgets/recipe_compatibility_view.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';

import 'pantry_test.dart' show HomeAuth;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:akletna_frontend/core/network/api_client.dart';

import 'api_client_test.dart' show FixtureAdapter;
import 'auth_service_test.dart' show MemoryTokenStorage;
import 'pantry_matching_test.dart'
    show MatchFixture, matchJson, responseJson, app;

import 'package:akletna_frontend/models/pantry_matches.dart';

Map<String, dynamic> evaluationJson({
  String compatibility = 'COMPATIBLE',
  String budget = 'QUALIFIES',
  String protein = 'QUALIFIES',
  String diet = 'COMPATIBLE',
}) => {
  'compatibility': compatibility,
  'reasons': compatibility == 'CONFLICT'
      ? [
          {
            'code': 'ALLERGEN',
            'severity': 'AVOID',
            'message': 'Contains Sesame.',
            'ingredientId': 42,
          },
          {
            'code': 'DISLIKED',
            'severity': 'DISLIKE',
            'message': 'Contains disliked Eggplant.',
            'ingredientId': 43,
          },
        ]
      : [],
  'diets': {'VEGETARIAN': diet, 'VEGAN': diet},
  'mealGoals': {'BUDGET_FRIENDLY': budget, 'HIGH_PROTEIN': protein},
  'proteinGramsPerServing': protein == 'UNKNOWN' ? null : 25,
  'highProteinThresholdGrams': 20,
};

class PreferencesFixture extends PreferencesService {
  FoodPreferences value = const FoodPreferences();
  FoodPreferences? submitted;
  Object? failure;
  @override
  Future<FoodPreferences> getPreferences() async {
    if (failure != null) throw failure!;
    return value;
  }

  @override
  Future<FoodPreferences> save(FoodPreferences preferences) async {
    if (failure != null) throw failure!;
    submitted = preferences;
    return value = preferences;
  }
}

class FoodIngredients extends IngredientService {
  @override
  Future<List<Ingredient>> getIngredients() async => [
    const Ingredient(id: 43, name: 'Eggplant', unit: 'g'),
  ];
}

class DiscoveryFixture extends RecipeService {
  @override
  Future<List<Recipe>> getRecipes() async => [
    Recipe(
      id: 1,
      name: 'Both goals',
      category: 'Yakhnet',
      origin: RecipeOrigin.curated,
      visibility: RecipeVisibility.public,
      servings: 1,
      evaluation: RecipeEvaluation.fromJson(evaluationJson()),
    ),
    Recipe(
      id: 2,
      name: 'Low protein',
      category: 'Yakhnet',
      origin: RecipeOrigin.curated,
      visibility: RecipeVisibility.public,
      servings: 1,
      evaluation: RecipeEvaluation.fromJson(
        evaluationJson(protein: 'DOES_NOT_QUALIFY'),
      ),
    ),
    Recipe(
      id: 3,
      name: 'Unknown metadata',
      category: 'Salads',
      origin: RecipeOrigin.curated,
      visibility: RecipeVisibility.public,
      servings: 1,
      evaluation: RecipeEvaluation.fromJson(
        evaluationJson(
          compatibility: 'UNKNOWN',
          budget: 'UNKNOWN',
          protein: 'UNKNOWN',
          diet: 'UNKNOWN',
        ),
      ),
    ),
  ];
}

Widget preferencesApp(PreferencesFixture service) => MaterialApp(
  home: FoodPreferencesScreen(
    preferencesService: service,
    ingredientService: FoodIngredients(),
  ),
  routes: {'/login': (_) => const Scaffold(body: Text('Login destination'))},
);
Future<void> tapVisible(WidgetTester tester, String text) async {
  if (find.text(text).hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text).hitTestable(),
      120,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  test('preference service authenticates both reads and writes without owner or curator fields', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    final calls = <RequestOptions>[];
    dio.httpClientAdapter = FixtureAdapter((options) {
      calls.add(options);
      return ResponseBody.fromString(
        jsonEncode({
          'dietaryRestrictions': [],
          'allergies': [],
          'dislikedIngredientIds': [],
          'preferredMealGoals': [],
          'legacyAllergies': [],
          'legacyDietaryRestrictions': [],
          'dislikedIngredients': [],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final service = PreferencesService(
      apiClient: ApiClient(
        dio: dio,
        tokenStorage: MemoryTokenStorage('synthetic-session'),
      ),
    );
    await service.getPreferences();
    await service.save(
      const FoodPreferences(
        avoidances: {FoodAvoidance.sesame},
        dislikedIngredientIds: {43},
      ),
    );
    expect(calls.map((c) => c.method), ['GET', 'PUT']);
    expect(
      calls.every(
        (c) =>
            c.path == '/api/preferences' &&
            c.headers['Authorization'] == 'Bearer synthetic-session',
      ),
      isTrue,
    );
    expect(calls.last.data['dislikedIngredientIds'], [43]);
    expect(calls.last.data.containsKey('userId'), isFalse);
    expect(
      calls.last.headers.containsKey('X-Nutrition-Curator-Token'),
      isFalse,
    );
    dio.close();
  });
  testWidgets(
    '100 percent pantry readiness retains math and displays an explicit conflict warning',
    (tester) async {
      final data = matchJson(status: 'READY_TO_COOK', name: 'Sesame dish');
      data['score'] = 100.0;
      data['evaluation'] = evaluationJson(compatibility: 'CONFLICT');
      final fixture = MatchFixture()
        ..result = PantryMatches.fromJson(responseJson(matches: [data]));
      await tester.pumpWidget(app(fixture));
      await tester.pumpAndSettle();
      expect(find.textContaining('Avoid'), findsOneWidget);
      expect(find.textContaining('Pantry: Ready to Cook'), findsOneWidget);
      expect(find.textContaining('100.00%'), findsOneWidget);
      expect(find.text('Contains Sesame.'), findsOneWidget);
      expect(fixture.result.matches.single.score, 100);
    },
  );
  test('structured request uses IDs and keeps legacy data out of writes', () {
    final profile = FoodPreferences.fromJson({
      'dietaryRestrictions': ['VEGAN'],
      'allergies': ['SESAME'],
      'dislikedIngredientIds': [43],
      'preferredMealGoals': ['HIGH_PROTEIN'],
      'legacyAllergies': ['old restriction'],
      'legacyDietaryRestrictions': [],
      'dislikedIngredients': ['old name'],
    });
    expect(profile.toRequestJson(), {
      'dietaryRestrictions': ['VEGAN'],
      'allergies': ['SESAME'],
      'dislikedIngredientIds': [43],
      'preferredMealGoals': ['HIGH_PROTEIN'],
    });
    expect(profile.legacyAllergies, ['old restriction']);
  });
  test('unknown classifications remain unknown and invalid statuses fail', () {
    final value = RecipeEvaluation.fromJson(
      evaluationJson(compatibility: 'UNKNOWN', protein: 'UNKNOWN'),
    );
    expect(value.compatibility, DietaryCompatibility.unknown);
    expect(value.proteinPerServing, isNull);
    expect(
      () => RecipeEvaluation.fromJson(evaluationJson(compatibility: 'SAFE')),
      throwsFormatException,
    );
  });
  testWidgets(
    'select save and reopen all four optional preference dimensions',
    (tester) async {
      final service = PreferencesFixture();
      await tester.pumpWidget(preferencesApp(service));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Vegetarian');
      await tapVisible(tester, 'Sesame');
      await tester.scrollUntilVisible(
        find.byType(TextField).hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'egg');
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Eggplant');
      await tapVisible(tester, 'Budget Friendly');
      await tapVisible(tester, 'High Protein');
      await tapVisible(tester, 'Save Preferences');
      expect(service.submitted!.diets, {DietaryPreference.vegetarian});
      expect(service.submitted!.avoidances, {FoodAvoidance.sesame});
      expect(service.submitted!.dislikedIngredientIds, {43});
      expect(service.submitted!.goals, MealGoal.values.toSet());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(preferencesApp(service));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Vegetarian'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Sesame'))
            .selected,
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(InputChip, 'Eggplant'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.widgetWithText(InputChip, 'Eggplant'), findsOneWidget);
    },
  );
  testWidgets(
    'preferences load failures can retry and save failures retain selections',
    (tester) async {
      final service = PreferencesFixture()
        ..failure = ApiException(message: 'offline');
      await tester.pumpWidget(preferencesApp(service));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      service.failure = null;
      await tapVisible(tester, 'Retry');
      await tapVisible(tester, 'Vegan');
      service.failure = ApiException(message: 'offline');
      await tapVisible(tester, 'Save Preferences');
      expect(
        find.text('Could not save preferences. Please try again.'),
        findsOneWidget,
      );
      service.failure = null;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Save Preferences');
      expect(service.submitted!.diets, {DietaryPreference.vegan});
    },
  );
  testWidgets(
    'unknown remains in default discovery; category and goals compose and clear',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeCatalogScreen(
            recipeService: DiscoveryFixture(),
            authService: HomeAuth(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unknown metadata'), findsOneWidget);
      await tapVisible(tester, 'Yakhnet');
      await tester.ensureVisible(find.byTooltip('Recipe filters'));
      await tester.tap(find.byTooltip('Recipe filters'));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Budget Friendly');
      await tapVisible(tester, 'High Protein');
      await tapVisible(tester, 'Vegetarian');
      expect(find.text('Both goals'), findsOneWidget);
      expect(find.text('Low protein'), findsNothing);
      expect(find.text('Unknown metadata'), findsNothing);
      await tapVisible(tester, 'Clear filters');
      expect(find.text('Unknown metadata'), findsOneWidget);
      expect(find.text('Low protein'), findsOneWidget);
    },
  );
  testWidgets('strong conflict and softer dislike reasons are explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipeCompatibilityView(
            evaluation: RecipeEvaluation.fromJson(
              evaluationJson(compatibility: 'CONFLICT'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Contains Sesame.'), findsOneWidget);
    expect(find.text('Contains disliked Eggplant.'), findsOneWidget);
    expect(find.textContaining('Avoid'), findsOneWidget);
    expect(find.textContaining('allergy-safety'), findsOneWidget);
  });
}
