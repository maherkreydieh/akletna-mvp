import 'dart:async';
import 'dart:convert';

import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/food_preferences.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/recommendations.dart';
import 'package:akletna_frontend/screens/home/home_screen.dart';
import 'package:akletna_frontend/screens/preferences/food_preferences_screen.dart';
import 'package:akletna_frontend/screens/recipes/my_recipes_screen.dart';
import 'package:akletna_frontend/screens/recipes/saved_recipes_screen.dart';
import 'package:akletna_frontend/services/recommendation_service.dart';
import 'package:akletna_frontend/widgets/recipe_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_client_test.dart' show FixtureAdapter;
import 'auth_service_test.dart' show MemoryTokenStorage;
import 'food_preferences_test.dart' show PreferencesFixture, FoodIngredients;
import 'pantry_test.dart' show HomeAuth;
import 'recommendations_test.dart' show itemJson;
import 'support/dashboard_fixtures.dart';

Map<String, dynamic> response({bool configured = true, bool empty = false}) => {
  'preferencesConfigured': configured,
  'limitations': empty
      ? ['Some ingredient and allergen information is incomplete.']
      : <String>[],
  'selection': {
    'pantryEmpty': true,
    'readableRecipeCount': 1,
    'excludedRecipeCount': empty ? 1 : 0,
    'recommendations': empty ? <dynamic>[] : [itemJson(emptyPantry: true)],
  },
};

class HomeLibrary extends DashboardRecipes {
  @override
  Future<List<Recipe>> getMyRecipes() async => [];
}

class PersonalSelection extends RecommendationService {
  PersonalSelection(this.preferences);
  final PreferencesFixture preferences;
  bool empty = false;
  bool fail = false;
  int reads = 0;
  Completer<HomeRecommendations>? pending;
  @override
  Future<HomeRecommendations> getHomeRecommendations({
    String? category,
    Set<MealGoal> goals = const {},
    DietaryPreference? diet,
  }) async {
    reads++;
    if (fail) throw ApiException(message: 'offline');
    if (pending != null) return pending!.future;
    final data = response(
      configured: preferences.value.diets.isNotEmpty,
      empty: empty,
    );
    if (!empty && preferences.value.diets.contains(DietaryPreference.vegan)) {
      final item =
          ((data['selection'] as Map)['recommendations'] as List).single as Map;
      (item['recipe'] as Map)['name'] = 'Vegan selection after save';
    }
    return HomeRecommendations.fromJson(data);
  }
}

Future<void> render(WidgetTester tester, PersonalSelection selection) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: HomeScreen(
        authService: HomeAuth(),
        recipeService: HomeLibrary(),
        recommendationService: selection,
        preferencesService: selection.preferences,
        ingredientService: FoodIngredients(),
        mealPlanService: DashboardPlans(),
        groceryListService: DashboardGroceries(),
        matchingService: DashboardMatches(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Home endpoint authenticates the request without user-supplied identity',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.httpClientAdapter = FixtureAdapter((options) {
        expect(options.path, '/api/recipes/recommendations/home');
        expect(options.headers['Authorization'], 'Bearer test-session');
        expect(options.queryParameters, isEmpty);
        return ResponseBody.fromString(
          jsonEncode(response()),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      final service = RecommendationService(
        apiClient: ApiClient(
          dio: dio,
          tokenStorage: MemoryTokenStorage('test-session'),
        ),
      );
      expect(
        (await service.getHomeRecommendations())
            .selection
            .items
            .single
            .recipe
            .name,
        'Recommended lentils',
      );
      dio.close();
    },
  );

  testWidgets(
    'Home removes legacy sections and contains exactly the three kitchen shortcuts',
    (tester) async {
      final selection = PersonalSelection(PreferencesFixture());
      await render(tester, selection);
      expect(find.text('My Kitchen'), findsOneWidget);
      for (final label in ['Food Preferences', 'Saved Recipes', 'My Recipes']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final old in [
        'From the Akletna Kitchen',
        'Recommended For You',
        'Cook With What I Have',
        'Plan & Shop',
        'Make it yours',
        'Recipes',
        'Community',
        'Weekly Meal Plan',
        'Grocery List',
        'My Pantry',
      ]) {
        expect(find.text(old), findsNothing);
      }
      expect(find.text('Recommended for You'), findsOneWidget);
      expect(find.text('Set Food Preferences'), findsNothing);
      expect(find.text('Selected using your saved Food Preferences.'), findsNothing);
      expect(find.textContaining('recommendations do not guarantee allergy safety'), findsNothing);
      expect(find.textContaining('General recipe selection'), findsOneWidget);
      final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
      expect(card.showEvaluation, isFalse);
      expect(card.recipe.name, 'Recommended lentils');
    },
  );

  for (final entry in <String, Type>{
    'Food Preferences': FoodPreferencesScreen,
    'Saved Recipes': SavedRecipesScreen,
    'My Recipes': MyRecipesScreen,
  }.entries) {
    testWidgets('My Kitchen opens ${entry.key}', (tester) async {
      await render(tester, PersonalSelection(PreferencesFixture()));
      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'saving Food Preferences reloads Home selection without restart',
    (tester) async {
      final preferences = PreferencesFixture();
      final selection = PersonalSelection(preferences);
      await render(tester, selection);
      expect(find.text('Recommended lentils'), findsOneWidget);
      await tester.ensureVisible(find.text('Food Preferences'));
      await tester.tap(find.text('Food Preferences'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Vegan').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Vegan'));
      await tester.scrollUntilVisible(
        find.text('Save Preferences').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save Preferences'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(selection.reads, 2);
      expect(find.text('Vegan selection after save'), findsOneWidget);
      expect(find.text('Recommended lentils'), findsNothing);
      expect(
        find.text('Selected using your saved Food Preferences.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'empty personalized selection explains incomplete data without general fallback',
    (tester) async {
      final prefs = PreferencesFixture()
        ..value = const FoodPreferences(diets: {DietaryPreference.vegan});
      await render(tester, PersonalSelection(prefs)..empty = true);
      expect(
        find.textContaining('No recipes meet your saved preferences'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'ingredient and allergen information is incomplete',
        ),
        findsOneWidget,
      );
      expect(find.text('Review Food Preferences'), findsOneWidget);
      expect(find.byType(RecipeCard), findsNothing);
      expect(find.textContaining('General recipe selection'), findsNothing);
    },
  );

  testWidgets(
    'failed selection offers retry and never substitutes the curated feed',
    (tester) async {
      final selection = PersonalSelection(PreferencesFixture())..fail = true;
      await render(tester, selection);
      expect(find.byType(RecipeCard), findsNothing);
      selection.fail = false;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Recommended lentils'), findsOneWidget);
      expect(selection.reads, 2);
    },
  );
}
