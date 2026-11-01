import 'support/dashboard_fixtures.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/core/constants/app_constants.dart';
import 'package:akletna_frontend/models/ingredient.dart';
import 'package:akletna_frontend/models/pantry_item.dart';
import 'package:akletna_frontend/models/user.dart';
import 'package:akletna_frontend/services/ingredient_service.dart';
import 'package:akletna_frontend/services/pantry_service.dart';
import 'package:akletna_frontend/services/auth_service.dart';
import 'package:akletna_frontend/screens/pantry/my_pantry_screen.dart';
import 'package:akletna_frontend/screens/home/home_screen.dart';

import 'api_client_test.dart' show FixtureAdapter;
import 'auth_service_test.dart' show MemoryTokenStorage;
import 'meal_plan_service_test.dart' show mealResponse;

const rice = Ingredient(id: 7, name: 'Rice', unit: 'g');
const garlic = Ingredient(id: 8, name: 'Garlic', unit: 'piece');
Map<String, dynamic> pantryJson({
  int id = 41,
  int ingredientId = 7,
  String name = 'Rice',
  String? quantity = '1500',
  String? unit = 'g',
  String? displayQuantity = '1.5',
  String? displayUnit = 'kg',
}) => {
  'id': id,
  'ingredientId': ingredientId,
  'ingredientName': name,
  'quantity': quantity,
  'unit': unit,
  'displayQuantity': displayQuantity,
  'displayUnit': displayUnit,
  'updatedAt': '2026-10-04T00:00:00Z',
};
PantryItem presence({
  int id = 42,
  int ingredientId = 8,
  String name = 'Garlic',
}) => PantryItem.fromJson(
  pantryJson(
    id: id,
    ingredientId: ingredientId,
    name: name,
    quantity: null,
    unit: null,
    displayQuantity: null,
    displayUnit: null,
  ),
);

class PantryFixture extends PantryService {
  List<PantryItem> items = [];
  Completer<List<PantryItem>>? pending;
  Object? loadError;
  Object? mutationError;
  int reads = 0;
  int adds = 0;
  int updates = 0;
  int removals = 0;
  @override
  Future<List<PantryItem>> getPantry() async {
    reads++;
    if (loadError != null) throw loadError!;
    return pending == null ? List.of(items) : pending!.future;
  }

  @override
  Future<PantryItem> add(
    int ingredientId, {
    String? quantity,
    String? unit,
  }) async {
    adds++;
    if (mutationError != null) throw mutationError!;
    final item = quantity == null
        ? presence(
            id: 41,
            ingredientId: ingredientId,
            name: ingredientId == 7 ? 'Rice' : 'Garlic',
          )
        : PantryItem.fromJson(
            pantryJson(
              ingredientId: ingredientId,
              quantity: quantity,
              unit: unit,
              displayQuantity: quantity,
              displayUnit: unit,
            ),
          );
    items.add(item);
    return item;
  }

  @override
  Future<PantryItem> update(int id, {String? quantity, String? unit}) async {
    updates++;
    if (mutationError != null) throw mutationError!;
    final previous = items.firstWhere((item) => item.id == id);
    final item = PantryItem.fromJson(
      pantryJson(
        id: id,
        ingredientId: previous.ingredientId,
        name: previous.ingredientName,
        quantity: quantity,
        unit: unit,
        displayQuantity: quantity,
        displayUnit: unit,
      ),
    );
    items = [for (final old in items) old.id == id ? item : old];
    return item;
  }

  @override
  Future<void> remove(int id) async {
    removals++;
    if (mutationError != null) throw mutationError!;
    items.removeWhere((item) => item.id == id);
  }
}

class IngredientsFixture extends IngredientService {
  List<Ingredient> items = [rice, garlic];
  int creates = 0;
  @override
  Future<List<Ingredient>> getIngredients() async => List.of(items);
  @override
  Future<Ingredient> createIngredient(String name, String unit) async {
    creates++;
    final ingredient = Ingredient(id: 9, name: name, unit: unit);
    items.add(ingredient);
    return ingredient;
  }
}

class HomeAuth extends AuthService {
  @override
  Future<User> getCurrentUser() async =>
      User(id: 1, name: 'Test owner', email: 'owner@example.test');
}

Widget pantryApp(PantryFixture pantry, {IngredientsFixture? ingredients}) =>
    MaterialApp(
      home: MyPantryScreen(
        pantryService: pantry,
        ingredientService: ingredients ?? IngredientsFixture(),
      ),
      routes: {
        AppConstants.loginRoute: (_) =>
            const Scaffold(body: Text('Login destination')),
      },
    );
Future<void> input(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), value);
}

void main() {
  test('pantry parses exact decimals and explicit presence, rejecting inconsistent pairs', () {
    expect(PantryItem.fromJson(pantryJson()).quantityLabel, '1.5 kg');
    expect(presence().quantityLabel, 'In pantry');
    final exact = '999999999999.123456789012';
    expect(
      PantryItem.fromJson(
        pantryJson(quantity: exact, displayQuantity: exact, displayUnit: 'g'),
      ).quantity,
      exact,
    );
    for (final fields in [
      {'quantity': null},
      {'unit': null},
      {'displayQuantity': null},
      {'quantity': '0'},
      {'quantity': '-1'},
      {'quantity': 'bad'},
    ]) {
      expect(
        () => PantryItem.fromJson({...pantryJson(), ...fields}),
        throwsFormatException,
      );
    }
  });
  test('pantry service uses JWT and decimal strings without owner or ingredient mutation on PUT', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    addTearDown(dio.close);
    dio.httpClientAdapter = FixtureAdapter((options) {
      requests.add(options);
      return mealResponse(
        options.method == 'GET' ? [pantryJson()] : pantryJson(),
      );
    });
    final service = PantryService(
      apiClient: ApiClient(
        dio: dio,
        tokenStorage: MemoryTokenStorage('test-session'),
      ),
    );
    expect((await service.getPantry()).single.quantityLabel, '1.5 kg');
    await service.add(7, quantity: '1.5', unit: 'kg');
    await service.add(8);
    await service.update(41);
    await service.remove(41);
    expect(requests.map((r) => '${r.method} ${r.path}'), [
      'GET /api/pantry',
      'POST /api/pantry',
      'POST /api/pantry',
      'PUT /api/pantry/41',
      'DELETE /api/pantry/41',
    ]);
    expect(requests[1].data, {
      'ingredientId': 7,
      'quantity': '1.5',
      'unit': 'kg',
    });
    expect(requests[2].data, {
      'ingredientId': 8,
      'quantity': null,
      'unit': null,
    });
    expect(requests[3].data, {'quantity': null, 'unit': null});
    expect(
      requests.every(
        (r) => r.headers['Authorization'] == 'Bearer test-session',
      ),
      isTrue,
    );
  });
  testWidgets('loading error retry and empty pantry states are honest', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = PantryFixture()..pending = Completer<List<PantryItem>>();
    await tester.pumpWidget(pantryApp(fixture));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fixture.pending!.completeError(StateError('private failure'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('private failure'), findsNothing);
    fixture.pending = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Your pantry is empty'), findsOneWidget);
  });
  testWidgets(
    'search selects existing ingredients and adds presence without creating catalog data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = PantryFixture();
      final ingredients = IngredientsFixture();
      await tester.pumpWidget(pantryApp(fixture, ingredients: ingredients));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Ingredient'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search ingredients'),
        'Garlic',
      );
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Garlic'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('In pantry'), findsOneWidget);
      expect(fixture.adds, 1);
      expect(ingredients.creates, 0);
      expect(fixture.items.single.quantity, isNull);
    },
  );
  testWidgets(
    'known add validates positive paired amount and preserves exact input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = PantryFixture();
      await tester.pumpWidget(pantryApp(fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Ingredient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I know the quantity'));
      await tester.pumpAndSettle();
      await input(tester, 'Quantity', '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(fixture.adds, 0);
      expect(find.textContaining('Enter a positive amount'), findsOneWidget);
      expect(find.textContaining('Enter a unit'), findsOneWidget);
      await input(tester, 'Quantity', '500.123456789012');
      await input(tester, 'Unit', 'g');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(fixture.items.single.quantity, '500.123456789012');
      expect(find.text('500.12 g'), findsOneWidget);
    },
  );
  testWidgets(
    'edit transitions known to presence and back without recreation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = PantryFixture()
        ..items = [PantryItem.fromJson(pantryJson())];
      await tester.pumpWidget(pantryApp(fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Rice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I know the quantity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('In pantry'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit Rice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I know the quantity'));
      await tester.pumpAndSettle();
      await input(tester, 'Quantity', '3');
      await input(tester, 'Unit', 'piece');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('3 piece'), findsOneWidget);
      expect(fixture.updates, 2);
      expect(fixture.adds, 0);
      expect(fixture.removals, 0);
      expect(fixture.items.single.id, 41);
    },
  );
  testWidgets(
    'remove confirms, cancellation preserves and refresh reflects removal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = PantryFixture()..items = [presence()];
      await tester.pumpWidget(pantryApp(fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove Garlic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fixture.removals, 0);
      await tester.tap(find.byTooltip('Remove Garlic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Refresh pantry'));
      await tester.pumpAndSettle();
      expect(find.text('Your pantry is empty'), findsOneWidget);
      expect(fixture.removals, 1);
    },
  );
  testWidgets('failed and duplicate mutations retain authoritative inventory', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = PantryFixture()
      ..items = [PantryItem.fromJson(pantryJson())]
      ..mutationError = ApiException(
        message: 'Already in pantry. Edit the existing item.',
        statusCode: 409,
      );
    await tester.pumpWidget(pantryApp(fixture));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Rice'));
    await tester.pumpAndSettle();
    await input(tester, 'Quantity', '500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('1.5 kg'), findsOneWidget);
    expect(find.textContaining('Edit the existing item'), findsOneWidget);
    expect(fixture.reads, 2);
  });
  testWidgets('401 load and mutations navigate to existing login', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = PantryFixture()
      ..loadError = ApiException(message: 'Expired', statusCode: 401);
    await tester.pumpWidget(pantryApp(fixture));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    final authenticated = PantryFixture()
      ..items = [presence()]
      ..mutationError = ApiException(message: 'Expired', statusCode: 401);
    await tester.pumpWidget(pantryApp(authenticated));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Garlic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    expect(authenticated.reads, 1);
  });
  testWidgets(
    'missing ingredient creation requires explicit action and confirmation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = PantryFixture();
      final ingredients = IngredientsFixture();
      await tester.pumpWidget(pantryApp(fixture, ingredients: ingredients));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Ingredient'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search ingredients'),
        'Freekeh',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching ingredients'), findsOneWidget);
      expect(ingredients.creates, 0);
      await tester.tap(find.text('Add "Freekeh" as a new ingredient'));
      await tester.pumpAndSettle();
      await input(tester, 'Default unit', 'g');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(ingredients.creates, 1);
      expect(find.text('Add Freekeh'), findsOneWidget);
      expect(fixture.adds, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fixture.items, isEmpty);
    },
  );
  testWidgets('Home opens My Pantry while retaining the existing navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = PantryFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          recommendationService: DashboardRecommendations(),
          recipeService: DashboardRecipes(),
          mealPlanService: DashboardPlans(),
          groceryListService: DashboardGroceries(),
          matchingService: DashboardMatches(),
          authService: HomeAuth(),
          pantryService: fixture,
          ingredientService: IngredientsFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final title in ['Saved Recipes', 'My Recipes', 'Food Preferences']) {
      expect(find.text(title), findsOneWidget);
    }
    await tester.ensureVisible(find.text('Explore'));
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open My Pantry'));
    await tester.pumpAndSettle();
    expect(find.text('Your pantry is empty'), findsOneWidget);
  });
}
