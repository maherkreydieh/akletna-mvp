import 'dart:async';

import 'package:akletna_frontend/core/constants/app_constants.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:akletna_frontend/screens/recipes/saved_recipes_screen.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipe_management_test.dart'
    show ManagementRecipes, ManagementAuth, ownedRecipe;
import 'recipe_service_test.dart' show FixtureApiClient, metadata;

class SavedFixture extends ManagementRecipes {
  int saves = 0;
  int unsaves = 0;
  int savedLoads = 0;
  bool saved = false;
  ApiException? saveFailure;
  Completer<void>? pendingSave;
  Completer<List<Recipe>>? pendingList;
  List<Recipe> collection = [];
  @override
  Future<Recipe> getRecipeById(int id) async => Recipe(
    id: id,
    name: ownedRecipe.name,
    instructions: ownedRecipe.instructions,
    userId: 1,
    saved: saved,
    visibility: RecipeVisibility.public,
  );
  @override
  Future<void> saveRecipe(int id) async {
    saves++;
    if (saveFailure != null) throw saveFailure!;
    if (pendingSave != null) await pendingSave!.future;
    saved = true;
  }

  @override
  Future<void> unsaveRecipe(int id) async {
    unsaves++;
    if (saveFailure != null) throw saveFailure!;
    saved = false;
    collection = [];
  }

  @override
  Future<List<Recipe>> getSavedRecipes() async {
    savedLoads++;
    if (listFailure != null) throw listFailure!;
    return pendingList == null ? collection : pendingList!.future;
  }
}

Future<void> detail(WidgetTester tester, SavedFixture service) async {
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        AppConstants.loginRoute: (_) =>
            const Scaffold(body: Text('Login screen')),
      },
      home: RecipeDetailScreen(
        recipe: ownedRecipe,
        recipeService: service,
        authService: ManagementAuth(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> library(WidgetTester tester, SavedFixture service) async {
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        AppConstants.loginRoute: (_) =>
            const Scaffold(body: Text('Login screen')),
      },
      home: SavedRecipesScreen(
        recipeService: service,
        authService: ManagementAuth(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('saved metadata is additive and timestamp/count remain optional', () {
    final legacy = Recipe.fromJson(metadata);
    expect(legacy.saved, false);
    expect(legacy.saveCount, isNull);
    final recipe = Recipe.fromJson({
      ...metadata,
      'saved': true,
      'saveCount': 2,
      'savedAt': '2026-10-04T10:00:00Z',
    });
    expect(recipe.saved, true);
    expect(recipe.saveCount, 2);
    expect(recipe.savedAt, DateTime.utc(2026, 10, 4, 10));
  });
  test(
    'saved service uses current-user collection and idempotent routes',
    () async {
      final api = FixtureApiClient({
        '/api/recipes/saved': [
          {...metadata, 'saved': true},
        ],
      });
      final service = RecipeService(apiClient: api);
      expect((await service.getSavedRecipes()).single.saved, true);
      await service.saveRecipe(11);
      await service.unsaveRecipe(11);
      expect(api.requests, ['/api/recipes/saved']);
      expect(api.mutations, [
        'PUT /api/recipes/11/save',
        'DELETE /api/recipes/11/save',
      ]);
      expect(api.posted, isEmpty);
    },
  );
  test('saved service propagates authentication failures', () async {
    final service = RecipeService(
      apiClient: FixtureApiClient({
        '/api/recipes/11/save': ApiException(
          message: 'Expired',
          statusCode: 401,
        ),
      }),
    );
    await expectLater(service.saveRecipe(11), throwsA(isA<ApiException>()));
    await expectLater(service.unsaveRecipe(11), throwsA(isA<ApiException>()));
  });
  testWidgets('detail loads unsaved state then saves and unsaves', (
    tester,
  ) async {
    final service = SavedFixture();
    await detail(tester, service);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    await tester.tap(find.byTooltip('Save recipe'));
    await tester.pumpAndSettle();
    expect(service.saves, 1);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    await tester.tap(find.byTooltip('Unsave recipe'));
    await tester.pumpAndSettle();
    expect(service.unsaves, 1);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });
  testWidgets('detail obtains saved state from detail response', (
    tester,
  ) async {
    await detail(tester, SavedFixture()..saved = true);
    expect(find.byTooltip('Unsave recipe'), findsOneWidget);
  });
  testWidgets('pending save disables duplicate taps and competing management', (
    tester,
  ) async {
    final service = SavedFixture()..pendingSave = Completer<void>();
    await detail(tester, service);
    await tester.tap(find.byTooltip('Save recipe'));
    await tester.pump();
    await tester.tap(find.byTooltip('Save recipe'));
    await tester.pump();
    expect(service.saves, 1);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Save recipe',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Edit recipe',
            ),
          )
          .onPressed,
      isNull,
    );
    service.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unsave recipe'), findsOneWidget);
  });
  testWidgets('save failure preserves honest unsaved state and allows retry', (
    tester,
  ) async {
    final service = SavedFixture()
      ..saveFailure = ApiException(message: 'Cannot save now');
    await detail(tester, service);
    await tester.tap(find.byTooltip('Save recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Cannot save now'), findsOneWidget);
    expect(find.byTooltip('Save recipe'), findsOneWidget);
    service.saveFailure = null;
    await tester.tap(find.byTooltip('Save recipe'));
    await tester.pumpAndSettle();
    expect(service.saves, 2);
    expect(find.byTooltip('Unsave recipe'), findsOneWidget);
  });
  testWidgets('unsave failure retains saved state', (tester) async {
    final service = SavedFixture()
      ..saved = true
      ..saveFailure = ApiException(message: 'Cannot unsave now');
    await detail(tester, service);
    await tester.tap(find.byTooltip('Unsave recipe'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unsave recipe'), findsOneWidget);
    expect(find.text('Cannot unsave now'), findsOneWidget);
  });
  testWidgets('save authentication failure returns to login', (tester) async {
    final service = SavedFixture()
      ..saveFailure = ApiException(message: 'Expired', statusCode: 401);
    await detail(tester, service);
    await tester.tap(find.byTooltip('Save recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Login screen'), findsOneWidget);
  });
  testWidgets('saved list loading resolves to honest empty state', (
    tester,
  ) async {
    final service = SavedFixture()..pendingList = Completer<List<Recipe>>();
    await library(tester, service);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.pendingList!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No saved recipes yet'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
  testWidgets('saved list error retries to populated state', (tester) async {
    final service = SavedFixture()
      ..listFailure = ApiException(message: 'Offline');
    await library(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    service.listFailure = null;
    service.collection = [ownedRecipe];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(ownedRecipe.name), findsOneWidget);
    expect(service.savedLoads, 2);
  });
  testWidgets('saved list opens detail and refreshes after unsave', (
    tester,
  ) async {
    final service = SavedFixture()
      ..saved = true
      ..collection = [ownedRecipe];
    await library(tester, service);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ownedRecipe.name));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Unsave recipe'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('No saved recipes yet'), findsOneWidget);
    expect(service.savedLoads, 2);
  });
  testWidgets('saved library authentication failure returns to login', (
    tester,
  ) async {
    await library(
      tester,
      SavedFixture()
        ..listFailure = ApiException(message: 'Expired', statusCode: 401),
    );
    await tester.pumpAndSettle();
    expect(find.text('Login screen'), findsOneWidget);
  });
}
