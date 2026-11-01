import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/models/ingredient.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/screens/recipes/create_recipe_screen.dart';
import 'package:akletna_frontend/services/ingredient_service.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class IngredientsFixture extends IngredientService {
  @override
  Future<List<Ingredient>> getIngredients() async => [
    const Ingredient(id: 7, name: 'Lentils', unit: 'cup'),
  ];
}

class RecipesFixture extends RecipeService {
  Map<String, dynamic>? saved;
  bool fail = false;
  @override
  Future<Recipe> createRecipe(Map<String, dynamic> request) async {
    saved = request;
    if (fail) {
      throw ApiException(message: 'Server unavailable.', statusCode: 500);
    }
    return Recipe.fromJson({
      'id': 12,
      ...request,
      'origin': 'USER',
      'userId': 1,
    });
  }
}

Future<void> showForm(WidgetTester tester, RecipesFixture recipes) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CreateRecipeScreen(
        recipeService: recipes,
        ingredientService: IngredientsFixture(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'renders private default and validates before sending a request',
    (tester) async {
      final recipes = RecipesFixture();
      await showForm(tester, recipes);
      expect(find.text('Create Recipe'), findsOneWidget);
      expect(find.text('Private — only you'), findsOneWidget);
      await tapVisible(tester, find.text('Create recipe'));
      expect(find.text('Enter a name with 2–150 characters.'), findsOneWidget);
      expect(find.text('Enter cooking instructions.'), findsOneWidget);
      expect(find.text('Select an ingredient.'), findsOneWidget);
      expect(recipes.saved, isNull);
    },
  );
  testWidgets('adds and removes ingredient rows', (tester) async {
    await showForm(tester, RecipesFixture());
    await tapVisible(tester, find.text('Add ingredient row'));
    expect(find.byType(DropdownButtonFormField<Ingredient>), findsNWidgets(2));
    await tapVisible(tester, find.text('Remove ingredient').last);
    expect(find.byType(DropdownButtonFormField<Ingredient>), findsOneWidget);
  });
  testWidgets(
    'public selection and quantities reach save; failures preserve form',
    (tester) async {
      final recipes = RecipesFixture()..fail = true;
      await showForm(tester, recipes);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Lentil soup');
      await tester.enterText(fields.at(2), 'Cook lentils.');
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<RecipeVisibility>),
      );
      await tester.tap(find.text('Public — shared with others').last);
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<Ingredient>),
      );
      await tester.tap(find.text('Lentils (cup)').last);
      await tester.pumpAndSettle();
      await tester.enterText(fields.last, '1.5');
      await tapVisible(tester, find.text('Create recipe'));
      expect(recipes.saved!['visibility'], 'PUBLIC');
      expect(recipes.saved!['ingredients'], [
        {'ingredientId': 7, 'quantity': 1.5, 'unit': 'cup'},
      ]);
      expect(recipes.saved!.containsKey('origin'), isFalse);
      expect(find.text('Server unavailable.'), findsOneWidget);
      expect(find.text('Lentil soup'), findsOneWidget);
    },
  );
  testWidgets('successful save returns persisted recipe to caller', (
    tester,
  ) async {
    final recipes = RecipesFixture();
    Recipe? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<Recipe>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateRecipeScreen(
                      recipeService: recipes,
                      ingredientService: IngredientsFixture(),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Soup');
    await tester.enterText(fields.at(2), 'Cook.');
    await tapVisible(tester, find.byType(DropdownButtonFormField<Ingredient>));
    await tester.tap(find.text('Lentils (cup)').last);
    await tester.pumpAndSettle();
    await tester.enterText(fields.last, '2');
    await tapVisible(tester, find.text('Create recipe'));
    expect(result?.id, 12);
    expect(result?.visibility, RecipeVisibility.private);
    expect(find.text('Open'), findsOneWidget);
  });
}
