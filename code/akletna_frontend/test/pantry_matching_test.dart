import 'support/dashboard_fixtures.dart';

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/core/constants/app_constants.dart';
import 'package:akletna_frontend/models/pantry_matches.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/recipe_nutrition.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:akletna_frontend/services/pantry_matching_service.dart';
import 'package:akletna_frontend/screens/pantry/cook_with_what_i_have_screen.dart';
import 'package:akletna_frontend/screens/pantry/my_pantry_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:akletna_frontend/screens/home/home_screen.dart';

import 'api_client_test.dart' show FixtureAdapter;
import 'auth_service_test.dart' show MemoryTokenStorage;
import 'pantry_test.dart' show PantryFixture, IngredientsFixture, HomeAuth;

Map<String, dynamic> detailJson(String status, {int id = 1}) => {
  'ingredientId': id,
  'ingredientName': 'Ingredient $id',
  'status': status,
  'required': {'quantity': '500', 'unit': 'g'},
  'available': ['MISSING', 'PRESENT_QUANTITY_UNKNOWN'].contains(status)
      ? null
      : {
          'quantity': '300',
          'unit': status == 'PRESENT_INCOMPARABLE' ? 'cup' : 'g',
        },
  'shortage': status == 'SHORTAGE' ? {'quantity': '200', 'unit': 'g'} : null,
};
Map<String, dynamic> matchJson({
  String status = 'ALMOST_THERE',
  String name = 'Rice dish',
  int id = 1,
  List<Map<String, dynamic>>? ingredients,
}) => {
  'id': id,
  'name': name,
  'origin': 'USER',
  'visibility': 'PRIVATE',
  'servings': 4,
  'status': status,
  'score': 60.0,
  'counts': {
    'enough': 0,
    'shortage': 1,
    'unknown': 0,
    'incomparable': 0,
    'missing': 0,
  },
  'ingredients': ingredients ?? [detailJson('SHORTAGE')],
};
Map<String, dynamic> responseJson({
  bool empty = false,
  int count = 1,
  int excluded = 0,
  List<Map<String, dynamic>>? matches,
}) => {
  'pantryEmpty': empty,
  'readableRecipeCount': count,
  'excludedRecipeCount': excluded,
  'matches': matches ?? (empty || count == 0 ? [] : [matchJson()]),
};

class MatchFixture extends PantryMatchingService {
  PantryMatches result = PantryMatches.fromJson(responseJson());
  Object? error;
  Completer<PantryMatches>? pending;
  int reads = 0;
  @override
  Future<PantryMatches> getMatches() async {
    reads++;
    if (error != null) throw error!;
    return pending == null ? result : pending!.future;
  }
}

class DetailRecipes extends RecipeService {
  int reads = 0;
  @override
  Future<Recipe> getRecipeById(int id) async {
    reads++;
    return Recipe(
      id: id,
      name: 'Normal Recipe Detail',
      instructions: 'Cook rice',
      servings: 4,
    );
  }

  @override
  Future<RecipeNutrition> getNutrition(int id) async =>
      const RecipeNutrition(status: NutritionStatus.incomplete);
}

Widget app(
  MatchFixture service, {
  PantryFixture? pantry,
  DetailRecipes? recipes,
}) => MaterialApp(
  home: CookWithWhatIHaveScreen(
    matchingService: service,
    pantryService: pantry ?? PantryFixture(),
    ingredientService: IngredientsFixture(),
    recipeService: recipes ?? DetailRecipes(),
    authService: HomeAuth(),
  ),
  routes: {
    AppConstants.loginRoute: (_) =>
        const Scaffold(body: Text('Login destination')),
  },
);
void main() {
  test(
    'assumed staples accept no measured amount and explain the assumption',
    () {
      final staple = {
        ...detailJson('ENOUGH'),
        'available': null,
        'assumedStaple': true,
      };
      final match = PantryRecipeMatch.fromJson(
        matchJson(ingredients: [staple]),
      );
      expect(
        match.ingredients.single.explanation,
        contains('assumed available'),
      );
      expect(
        () => PantryRecipeMatch.fromJson(
          matchJson(
            ingredients: [
              {...staple, 'assumedStaple': false},
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => PantryRecipeMatch.fromJson(
          matchJson(
            ingredients: [
              {...staple, 'status': 'SHORTAGE'},
            ],
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test('models preserve exact amounts and reject unknown states or missing shortage', () {
    final exact = '999999999999.123456789012';
    final data = detailJson('SHORTAGE');
    data['shortage'] = {'quantity': exact, 'unit': 'g'};
    final match = PantryRecipeMatch.fromJson(matchJson(ingredients: [data]));
    expect(match.ingredients.single.shortage!.quantity, exact);
    expect(match.percentage, '60.00% pantry match');
    expect(
      () => PantryRecipeMatch.fromJson(matchJson(status: 'INVALID')),
      throwsFormatException,
    );
    expect(
      () => PantryRecipeMatch.fromJson(
        matchJson(
          ingredients: [
            {...data, 'status': 'INVALID'},
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => PantryRecipeMatch.fromJson(
        matchJson(
          ingredients: [
            {...data, 'shortage': null},
          ],
        ),
      ),
      throwsFormatException,
    );
  });
  test(
    'matching endpoint uses JWT in one read with no inventory mutations',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      addTearDown(dio.close);
      dio.httpClientAdapter = FixtureAdapter((options) {
        requests.add(options);
        return ResponseBody.fromString(
          jsonEncode(responseJson()),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final service = PantryMatchingService(
        apiClient: ApiClient(
          dio: dio,
          tokenStorage: MemoryTokenStorage('test-session'),
        ),
      );
      expect(
        (await service.getMatches()).matches.single.status,
        PantryMatchStatus.almostThere,
      );
      expect(requests.single.path, '/api/recipes/pantry-matches');
      expect(requests.single.method, 'GET');
      expect(requests.single.headers['Authorization'], 'Bearer test-session');
      expect(requests.single.queryParameters, isEmpty);
      dio.httpClientAdapter = FixtureAdapter(
        (_) => ResponseBody.fromString(
          '{}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await expectLater(service.getMatches(), throwsA(isA<ApiException>()));
    },
  );
  testWidgets(
    'loading, network error, retry and refresh use authoritative result',
    (tester) async {
      final service = MatchFixture()..pending = Completer<PantryMatches>();
      await tester.pumpWidget(app(service));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.pending!.completeError(
        ApiException(message: 'Internal error', statusCode: 500),
      );
      service.pending = null;
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Rice dish'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Rice dish'), findsOneWidget);
      service.result = PantryMatches.fromJson(
        responseJson(matches: [matchJson(name: 'Updated dish')]),
      );
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Updated dish'), findsOneWidget);
      expect(service.reads, 3);
    },
  );
  testWidgets(
    'empty pantry has useful action and reloads after existing pantry screen',
    (tester) async {
      final service = MatchFixture()
        ..result = PantryMatches.fromJson(responseJson(empty: true));
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      expect(find.text('Add ingredients to your pantry first'), findsOneWidget);
      expect(find.text('Rice dish'), findsNothing);
      await tester.tap(find.text('Open My Pantry'));
      await tester.pumpAndSettle();
      expect(find.byType(MyPantryScreen), findsOneWidget);
      service.result = PantryMatches.fromJson(responseJson());
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Rice dish'), findsOneWidget);
      expect(service.reads, 2);
    },
  );
  testWidgets(
    'no readable recipes is distinct from empty inventory and malformed exclusion',
    (tester) async {
      final service = MatchFixture()
        ..result = PantryMatches.fromJson(responseJson(count: 0));
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      expect(find.text('No recipes available yet'), findsOneWidget);
      expect(find.text('Add ingredients to your pantry first'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      service.result = PantryMatches.fromJson(
        responseJson(count: 1, excluded: 1, matches: []),
      );
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(
        find.text('No recipes with valid ingredient requirements'),
        findsOneWidget,
      );
      expect(
        find.textContaining('requirements are incomplete'),
        findsOneWidget,
      );
    },
  );
  for (final pair in {
    'READY_TO_COOK': 'Ready to Cook',
    'LIKELY_READY': 'Likely Ready',
    'ALMOST_THERE': 'Almost There',
    'MORE_SHOPPING_NEEDED': 'More Shopping Needed',
  }.entries) {
    testWidgets(
      '${pair.value} card exposes friendly status and match percentage',
      (tester) async {
        final service = MatchFixture()
          ..result = PantryMatches.fromJson(
            responseJson(matches: [matchJson(status: pair.key)]),
          );
        await tester.pumpWidget(app(service));
        await tester.pumpAndSettle();
        expect(find.textContaining(pair.value), findsOneWidget);
        expect(find.textContaining('60.00% pantry match'), findsOneWidget);
        expect(find.textContaining(pair.key), findsNothing);
      },
    );
  }
  testWidgets(
    'explanation distinguishes enough shortage unknown incomparable and missing',
    (tester) async {
      final details = [
        'ENOUGH',
        'SHORTAGE',
        'PRESENT_QUANTITY_UNKNOWN',
        'PRESENT_INCOMPARABLE',
        'MISSING',
      ];
      final service = MatchFixture()
        ..result = PantryMatches.fromJson(
          responseJson(
            matches: [
              matchJson(
                ingredients: [
                  for (var index = 0; index < details.length; index++)
                    detailJson(details[index], id: index + 1),
                ],
              ),
            ],
          ),
        );
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice dish'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enough — need 500 g'), findsOneWidget);
      expect(find.textContaining('missing 200 g'), findsOneWidget);
      expect(find.textContaining('quantity unknown'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Amount cannot be compared yet').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Amount cannot be compared yet'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Missing — need 500 g').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Missing — need 500 g'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Base recipe: 4 serving(s)').hitTestable(),
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Base recipe: 4 serving(s)'), findsOneWidget);
    },
  );
  testWidgets(
    'opens existing normal Recipe Detail and refreshes matches on return',
    (tester) async {
      final service = MatchFixture();
      final recipes = DetailRecipes();
      await tester.pumpWidget(app(service, recipes: recipes));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice dish'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Open Recipe Detail').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Open Recipe Detail'));
      await tester.pumpAndSettle();
      expect(find.byType(RecipeDetailScreen), findsOneWidget);
      expect(recipes.reads, 1);
      expect(find.text('Normal Recipe Detail'), findsWidgets);
      service.result = PantryMatches.fromJson(
        responseJson(matches: [matchJson(name: 'Refreshed match')]),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Refreshed match'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(service.reads, 3);
    },
  );
  testWidgets('authentication failure navigates to existing login route', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        MatchFixture()
          ..error = ApiException(message: 'Unauthorized', statusCode: 401),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    expect(find.text('Rice dish'), findsNothing);
  });
  testWidgets(
    'Home adds matching navigation while preserving previous features',
    (tester) async {
      final service = MatchFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            recommendationService: DashboardRecommendations(),
            recipeService: DashboardRecipes(),
            mealPlanService: DashboardPlans(),
            groceryListService: DashboardGroceries(),
            authService: HomeAuth(),
            matchingService: service,
            pantryService: PantryFixture(),
            ingredientService: IngredientsFixture(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Explore'));
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(find.byType(CookWithWhatIHaveScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      for (final name in ['My Recipes', 'Saved Recipes', 'Food Preferences']) {
        await tester.ensureVisible(find.text(name));
        expect(find.text(name), findsOneWidget);
      }
    },
  );
}
