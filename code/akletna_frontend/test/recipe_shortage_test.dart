import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/models/recipe_shortage.dart';
import 'package:akletna_frontend/models/grocery_list.dart';
import 'package:akletna_frontend/services/grocery_list_service.dart';
import 'package:akletna_frontend/screens/groceries/recipe_shortage_screen.dart';
import 'package:akletna_frontend/screens/groceries/grocery_list_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:akletna_frontend/screens/pantry/cook_with_what_i_have_screen.dart';
import 'package:akletna_frontend/models/pantry_matches.dart';

import 'pantry_matching_test.dart' show DetailRecipes, MatchFixture, matchJson;
import 'recipe_management_test.dart' show ManagementAuth, ownedRecipe;

const known = ShortageIngredient(
  ingredientId: 1,
  name: 'Rice',
  status: 'SHORTAGE',
  quantity: '200',
  unit: 'g',
);
const unknown = ShortageIngredient(
  ingredientId: 2,
  name: 'Salt',
  status: 'PRESENT_QUANTITY_UNKNOWN',
);
const incompatible = ShortageIngredient(
  ingredientId: 3,
  name: 'Flour',
  status: 'PRESENT_INCOMPARABLE',
);

class ShortageFixture extends GroceryListService {
  bool empty = false, added = false, fail = false;
  int additions = 0, previews = 0, removed = 0;
  final servings = <int>[];
  Completer<RecipeShortage>? pending;
  RecipeShortage result(int count) => RecipeShortage(
    recipeId: 1,
    recipeName: 'Rice recipe',
    servings: count,
    pantryEmpty: empty,
    status: added
        ? 'ALREADY_ADDED'
        : empty
        ? 'PANTRY_EMPTY'
        : 'PREVIEW',
    contributionId: added ? 9 : null,
    ingredients: empty ? [] : [known, unknown, incompatible],
  );
  @override
  Future<RecipeShortage> previewShortages(int id, int count) async {
    previews++;
    servings.add(count);
    if (fail) throw ApiException(message: 'Could not check ingredients');
    if (pending != null) return pending!.future;
    return result(count);
  }

  @override
  Future<RecipeShortage> addShortages(int id, int count) async {
    additions++;
    added = true;
    return result(count);
  }

  GroceryList get groceries => GroceryList(
    id: 1,
    updatedAt: DateTime(2026),
    items: [
      GroceryItem(
        id: 1,
        name: 'Rice',
        quantity: added ? 700 : 500,
        unit: 'g',
        checked: false,
      ),
    ],
    contributions: [
      if (added)
        const GroceryContribution(
          id: 9,
          source: 'RECIPE_SHORTAGE',
          name: 'Rice recipe',
          servings: 4,
          ingredients: [known, unknown, incompatible],
        ),
    ],
  );
  @override
  Future<GroceryList> generateWeek(DateTime date) async => groceries;
  @override
  Future<GroceryList> getList() async => groceries;
  @override
  Future<GroceryList> removeContribution(int id) async {
    removed = id;
    added = false;
    return groceries;
  }
}

Widget app(ShortageFixture f) => MaterialApp(
  home: RecipeShortageScreen(
    recipeId: 1,
    recipeName: 'Rice recipe',
    initialServings: 4,
    service: f,
  ),
);
void main() {
  testWidgets('Recipe Detail opens shared server shortage workflow', (
    tester,
  ) async {
    final f = ShortageFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: ownedRecipe,
          recipeService: DetailRecipes(),
          authService: ManagementAuth(),
          groceryListService: f,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.text('Check missing ingredients');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(RecipeShortageScreen), findsOneWidget);
    expect(f.previews, 1);
    expect(find.text('200 g'), findsOneWidget);
  });
  testWidgets(
    'pantry explanation opens shared shortage workflow and refreshes on return',
    (tester) async {
      final f = ShortageFixture();
      final matches = MatchFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: PantryMatchDetailsScreen(
            match: PantryRecipeMatch.fromJson(matchJson()),
            matchingService: matches,
            groceryListService: f,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Missing to Groceries'));
      await tester.pumpAndSettle();
      expect(f.previews, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(matches.reads, 1);
      expect(find.byType(PantryMatchDetailsScreen), findsOneWidget);
    },
  );
  test('uncertain backend data cannot masquerade as a numeric shortage', () {
    expect(
      () => ShortageIngredient.fromJson({
        'ingredientName': 'Rice',
        'status': 'PRESENT_QUANTITY_UNKNOWN',
        'quantity': '0',
        'unit': 'g',
      }),
      throwsFormatException,
    );
    expect(
      () => ShortageIngredient.fromJson({
        'ingredientName': 'Rice',
        'status': 'SHORTAGE',
        'quantity': null,
        'unit': 'g',
      }),
      throwsFormatException,
    );
    expect(
      ShortageIngredient.fromJson({
        'ingredientName': 'Rice',
        'status': 'SHORTAGE',
        'quantity': '0.333333333333',
        'unit': 'g',
      }).quantity,
      '0.333333333333',
    );
  });
  testWidgets(
    'loading, explicit skipped states, successful add and duplicate prevention',
    (tester) async {
      final f = ShortageFixture()..pending = Completer();
      await tester.pumpWidget(app(f));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      f.pending!.complete(f.result(4));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Quantity in pantry is unknown'),
        findsOneWidget,
      );
      expect(find.textContaining('incompatible unit'), findsOneWidget);
      expect(find.text('200 g'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Add Missing to Groceries').hitTestable(),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add Missing to Groceries'));
      // Repeat before a rebuild disables the old callback.
      await tester.tap(find.text('Add Missing to Groceries'));
      await tester.pumpAndSettle();
      expect(f.additions, 1);
      expect(
        find.textContaining('Already added for this recipe'),
        findsOneWidget,
      );
      expect(find.text('Add Missing to Groceries'), findsNothing);
    },
  );
  testWidgets('empty pantry explains populate first without implicit add-all', (
    tester,
  ) async {
    await tester.pumpWidget(app(ShortageFixture()..empty = true));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your pantry is empty'), findsOneWidget);
    expect(find.text('Open My Pantry'), findsOneWidget);
    expect(find.text('Add Missing to Groceries'), findsNothing);
  });
  testWidgets('failed preview is an error with retry, never empty success', (
    tester,
  ) async {
    final f = ShortageFixture()..fail = true;
    await tester.pumpWidget(app(f));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Your pantry is empty'), findsNothing);
    f.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(f.previews, 2);
    expect(find.text('200 g'), findsOneWidget);
  });
  testWidgets('serving selection requests a fresh server comparison', (
    tester,
  ) async {
    final f = ShortageFixture();
    await tester.pumpWidget(app(f));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change servings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Decrease servings'));
    await tester.pump();
    await tester.tap(find.byTooltip('Decrease servings'));
    await tester.pump();
    await tester.tap(find.text('Check ingredients'));
    await tester.pumpAndSettle();
    expect(f.servings, [4, 2]);
    expect(find.text('2 servings'), findsOneWidget);
  });
  testWidgets(
    'grocery source removal refreshes aggregate and preserves plan amount',
    (tester) async {
      final f = ShortageFixture()..added = true;
      await tester.pumpWidget(
        MaterialApp(home: GroceryListScreen(groceryListService: f)),
      );
      await tester.pumpAndSettle();
      expect(find.text('700 g'), findsOneWidget);
      await tester.tap(find.text('Recipe sources'));
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('remove-source-9'));
      await tester.scrollUntilVisible(
        remove.hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove addition'));
      await tester.pumpAndSettle();
      expect(f.removed, 9);
      await tester.scrollUntilVisible(
        find.text('Shopping list'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Shopping list'));
      await tester.pumpAndSettle();
      expect(find.text('500 g'), findsOneWidget);
      expect(find.text('700 g'), findsNothing);
    },
  );
}
