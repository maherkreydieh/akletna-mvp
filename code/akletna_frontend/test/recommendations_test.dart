import 'support/dashboard_fixtures.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/models/recommendations.dart';
import 'package:akletna_frontend/models/food_preferences.dart';
import 'package:akletna_frontend/services/recommendation_service.dart';
import 'package:akletna_frontend/screens/recipes/recommendations_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:akletna_frontend/screens/home/home_screen.dart';

import 'api_client_test.dart' show FixtureAdapter;
import 'auth_service_test.dart' show MemoryTokenStorage;
import 'food_preferences_test.dart' show evaluationJson;
import 'pantry_test.dart' show HomeAuth, IngredientsFixture;
import 'pantry_matching_test.dart' show DetailRecipes;

Map<String, dynamic> itemJson({
  bool emptyPantry = false,
  String compatibility = 'COMPATIBLE',
}) => {
  'rank': 1,
  'score': 95.0,
  'pantryStatus': emptyPantry ? null : 'READY_TO_COOK',
  'pantryPercentage': emptyPantry ? null : 100.0,
  'recipe': {
    'id': 1,
    'name': 'Recommended lentils',
    'category': 'Yakhnet',
    'origin': 'CURATED',
    'visibility': 'PUBLIC',
    'servings': 1,
    'saved': true,
    'saveCount': 1,
    'evaluation': evaluationJson(compatibility: compatibility),
  },
  'reasons': [
    if (compatibility == 'UNKNOWN')
      {
        'code': 'UNKNOWN',
        'message': 'Some dietary/allergen information is incomplete.',
        'points': 0,
      },
    {
      'code': 'PANTRY',
      'message': emptyPantry
          ? 'Add pantry ingredients for better recommendations.'
          : 'You have everything needed',
      'points': emptyPantry ? 0 : 50,
    },
    {'code': 'SAVED', 'message': 'Saved by you', 'points': 5},
    {
      'code': 'GOAL_HIGH_PROTEIN',
      'message': 'Matches your High Protein goal',
      'points': 7.5,
    },
    {
      'code': 'DISLIKE',
      'message': 'Contains an ingredient you dislike: eggplant',
      'points': -5,
    },
  ],
};
Map<String, dynamic> collectionJson({
  bool emptyPantry = false,
  bool noRecipes = false,
  String compatibility = 'COMPATIBLE',
}) => {
  'pantryEmpty': emptyPantry,
  'readableRecipeCount': noRecipes ? 0 : 1,
  'excludedRecipeCount': 0,
  'recommendations': noRecipes
      ? []
      : [itemJson(emptyPantry: emptyPantry, compatibility: compatibility)],
};

class RecommendationsFixture extends RecommendationService {
  @override
  Future<HomeRecommendations> getHomeRecommendations({
    String? category,
    Set<MealGoal> goals = const {},
    DietaryPreference? diet,
  }) async {
    await getRecommendations(category: category, goals: goals, diet: diet);
    return HomeRecommendations.fromJson({
      'preferencesConfigured': true,
      'limitations': <String>[],
      'selection': collectionJson(),
    });
  }

  Recommendations result = Recommendations.fromJson(collectionJson());
  Completer<Recommendations>? pending;
  Object? error;
  int reads = 0;
  String? category;
  Set<MealGoal> goals = {};
  DietaryPreference? diet;
  @override
  Future<Recommendations> getRecommendations({
    String? category,
    Set<MealGoal> goals = const {},
    DietaryPreference? diet,
  }) async {
    reads++;
    this.category = category;
    this.goals = Set.of(goals);
    this.diet = diet;
    if (error != null) throw error!;
    return pending == null ? result : pending!.future;
  }
}

Widget app(RecommendationsFixture service, {DetailRecipes? recipes}) =>
    MaterialApp(
      home: RecommendationsScreen(
        recommendationService: service,
        recipeService: recipes ?? DetailRecipes(),
        authService: HomeAuth(),
        ingredientService: IngredientsFixture(),
      ),
      routes: {
        '/login': (_) => const Scaffold(body: Text('Login destination')),
      },
    );
void main() {
  test('model preserves backend rank, score, exact pantry percentage and structured reasons', () {
    final r = Recommendations.fromJson(collectionJson()).items.single;
    expect(r.rank, 1);
    expect(r.score, 95);
    expect(r.pantryPercentage, 100);
    expect(r.recipe.saved, isTrue);
    expect(r.reasons.last.points, -5);
    final bad = itemJson()..['score'] = 101;
    expect(() => Recommendation.fromJson(bad), throwsFormatException);
    expect(
      Recommendations.fromJson(collectionJson(emptyPantry: true))
          .items
          .single
          .pantryPercentage,
      isNull,
    );
  });
  test(
    'service uses authenticated endpoint and existing AND filter conventions',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      RequestOptions? call;
      dio.httpClientAdapter = FixtureAdapter((options) {
        call = options;
        return ResponseBody.fromString(
          jsonEncode(collectionJson()),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final service = RecommendationService(
        apiClient: ApiClient(
          dio: dio,
          tokenStorage: MemoryTokenStorage('synthetic-session'),
        ),
      );
      await service.getRecommendations(
        category: ' Yakhnet ',
        goals: {MealGoal.budgetFriendly, MealGoal.highProtein},
        diet: DietaryPreference.vegetarian,
      );
      expect(call!.path, '/api/recipes/recommendations');
      expect(call!.headers['Authorization'], 'Bearer synthetic-session');
      expect(call!.queryParameters, {
        'category': 'Yakhnet',
        'goal': 'BUDGET_FRIENDLY,HIGH_PROTEIN',
        'diet': 'VEGETARIAN',
      });
      dio.httpClientAdapter = FixtureAdapter(
        (_) => ResponseBody.fromString(
          '{}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await expectLater(
        service.getRecommendations(),
        throwsA(isA<ApiException>()),
      );
      dio.close();
    },
  );
  testWidgets(
    'loading becomes ranked content with backend explanations and unchanged pantry match',
    (tester) async {
      final service = RecommendationsFixture()
        ..pending = Completer<Recommendations>();
      await tester.pumpWidget(app(service));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.pending!.complete(service.result);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('95 Akletna recommendation score'),
        findsOneWidget,
      );
      expect(find.textContaining('100% pantry match'), findsOneWidget);
      expect(find.text('Saved by you'), findsOneWidget);
      expect(find.text('You have everything needed'), findsOneWidget);
      expect(find.text('Recommended lentils'), findsOneWidget);
      // Taller recipe imagery can require more than one lazy-list layout before
      // the explanation action becomes tappable on the default test viewport.
      await tester.scrollUntilVisible(
        find.text('Why this recommendation?').hitTestable(),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Why this recommendation?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not a probability'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Contains an ingredient you dislike: eggplant'),
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'empty inventory has guidance and no fabricated percentage; empty candidates are useful',
    (tester) async {
      final service = RecommendationsFixture()
        ..result = Recommendations.fromJson(collectionJson(emptyPantry: true));
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Add pantry ingredients to see'),
        findsOneWidget,
      );
      expect(find.textContaining('% pantry match'), findsNothing);
      service.result = Recommendations.fromJson(
        collectionJson(noRecipes: true),
      );
      await tester.tap(find.byTooltip('Refresh recommendations'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No recipes match yet'), findsOneWidget);
    },
  );
  testWidgets(
    'error retries and explicit refresh reload authoritative results',
    (tester) async {
      final service = RecommendationsFixture()
        ..error = ApiException(message: 'Network unavailable');
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      expect(find.text('Network unavailable'), findsOneWidget);
      service.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Refresh recommendations'));
      await tester.pumpAndSettle();
      expect(service.reads, 3);
    },
  );
  testWidgets(
    'unknown wording remains honest and filters are sent then cleared',
    (tester) async {
      final service = RecommendationsFixture()
        ..result = Recommendations.fromJson(
          collectionJson(compatibility: 'UNKNOWN'),
        );
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      expect(
        find.text('Some dietary/allergen information is incomplete.'),
        findsOneWidget,
      );
      expect(find.text('Safe for you'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Yakhnet'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'High Protein'));
      await tester.pumpAndSettle();
      expect(service.category, 'Yakhnet');
      expect(service.goals, {MealGoal.highProtein});
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(service.category, isNull);
      expect(service.goals, isEmpty);
    },
  );
  testWidgets(
    'opens existing Recipe Detail and reloads recommendations on return',
    (tester) async {
      final service = RecommendationsFixture();
      final recipes = DetailRecipes();
      await tester.pumpWidget(app(service, recipes: recipes));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Recommended lentils'));
      await tester.tap(find.text('Recommended lentils'));
      await tester.pumpAndSettle();
      expect(find.byType(RecipeDetailScreen), findsOneWidget);
      expect(recipes.reads, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(service.reads, 2);
    },
  );
  testWidgets('401 returns to login without ranking a stale result', (
    tester,
  ) async {
    final service = RecommendationsFixture()
      ..error = ApiException(message: 'Expired', statusCode: 401);
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
  });
  testWidgets(
    'Home retains existing navigation and opens Recommended For You',
    (tester) async {
      final service = RecommendationsFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            recipeService: DashboardRecipes(),
            mealPlanService: DashboardPlans(),
            groceryListService: DashboardGroceries(),
            matchingService: DashboardMatches(),
            authService: HomeAuth(),
            recommendationService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('See all'));
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.byType(RecommendationsScreen), findsOneWidget);
      expect(service.reads, 2);
    },
  );
}
