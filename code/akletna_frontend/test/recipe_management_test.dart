import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/models/ingredient.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/recipe_nutrition.dart';
import 'package:akletna_frontend/models/user.dart';
import 'package:akletna_frontend/screens/recipes/create_recipe_screen.dart';
import 'package:akletna_frontend/screens/recipes/my_recipes_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:akletna_frontend/services/auth_service.dart';
import 'package:akletna_frontend/services/ingredient_service.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ownedRecipe = Recipe(
  id: 11,
  name: 'Lentil soup',
  description: 'Homemade',
  instructions: 'Cook gently.',
  servings: 4,
  cookingTime: 30,
  category: 'Soup',
  imageUrl: null,
  userId: 1,
  visibility: RecipeVisibility.public,
  ingredients: [
    RecipeIngredient(
      id: 21,
      recipeId: 11,
      ingredientId: 7,
      name: 'Lentils',
      quantity: 1.5,
      unit: 'cup',
    ),
  ],
);

class ManagementAuth extends AuthService {
  @override
  Future<User> getCurrentUser() async =>
      User(id: 1, name: 'Owner', email: 'owner@example.test');
}

class ManagementIngredients extends IngredientService {
  @override
  Future<List<Ingredient>> getIngredients() async => [
    const Ingredient(id: 7, name: 'Lentils', unit: 'cup'),
    const Ingredient(id: 8, name: 'Rice', unit: 'g'),
  ];
}

class ManagementRecipes extends RecipeService {
  @override
  Future<RecipeNutrition> getNutrition(int id) async =>
      const RecipeNutrition(status: NutritionStatus.unavailable);
  Recipe current = ownedRecipe;
  List<Recipe>? listed;
  ApiException? listFailure;
  ApiException? deleteFailure;
  ApiException? updateFailure;
  int deleted = 0;
  int loads = 0;
  int creates = 0;
  int catalogLoads = 0;
  int? updatedId;
  Map<String, dynamic>? updateRequest;
  @override
  Future<List<Recipe>> getMyRecipes() async {
    loads++;
    if (listFailure != null) {
      throw listFailure!;
    }
    return listed ?? (deleted > 0 ? [] : [current]);
  }

  @override
  Future<Recipe> getRecipeById(int id) async => current;
  @override
  Future<List<Recipe>> getRecipes() async {
    catalogLoads++;
    return deleted > 0 ? [] : [current];
  }

  @override
  Future<Recipe> createRecipe(Map<String, dynamic> request) async {
    creates++;
    return current;
  }

  @override
  Future<Recipe> updateRecipe(int id, Map<String, dynamic> request) async {
    updatedId = id;
    updateRequest = request;
    if (updateFailure != null) {
      throw updateFailure!;
    }
    current = Recipe.fromJson(
      {...current.toJson(), ...request},
      ingredients: (request['ingredients'] as List)
          .map(
            (line) => RecipeIngredient(
              id: 22,
              recipeId: id,
              ingredientId: line['ingredientId'] as int,
              name: line['ingredientId'] == 7 ? 'Lentils' : 'Rice',
              quantity: (line['quantity'] as num).toDouble(),
              unit: line['ingredientId'] == 7 ? 'cup' : 'g',
            ),
          )
          .toList(),
    );
    return current;
  }

  @override
  Future<void> deleteRecipe(int id) async {
    if (deleteFailure != null) {
      throw deleteFailure!;
    }
    deleted++;
  }
}

Future<void> renderMyRecipes(
  WidgetTester tester,
  ManagementRecipes service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MyRecipesScreen(
        recipeService: service,
        authService: ManagementAuth(),
        ingredientService: ManagementIngredients(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'My Recipes reloads edited and deleted recipes after detail navigation',
    (tester) async {
      final service = ManagementRecipes();
      await tester.pumpWidget(
        MaterialApp(
          home: MyRecipesScreen(
            recipeService: service,
            authService: ManagementAuth(),
            ingredientService: ManagementIngredients(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lentil soup'));
      await tester.tap(find.text('Lentil soup'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit recipe'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Catalog updated soup',
      );
      await tapVisible(tester, find.text('Save changes'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Catalog updated soup'), findsOneWidget);
      expect(service.loads, 2);
      await tester.ensureVisible(find.text('Catalog updated soup'));
      await tester.tap(find.text('Catalog updated soup'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete recipe'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Catalog updated soup'), findsNothing);
      expect(find.text("You haven't created any recipes yet."), findsOneWidget);
      expect(service.loads, 3);
    },
  );
  testWidgets('My Recipes authentication failure redirects to login', (
    tester,
  ) async {
    final service = ManagementRecipes()
      ..listFailure = ApiException(message: 'Expired session', statusCode: 401);
    await tester.pumpWidget(
      MaterialApp(
        home: MyRecipesScreen(recipeService: service),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Login destination')),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
  testWidgets('My Recipes renders real cards with public and private labels', (
    tester,
  ) async {
    final service = ManagementRecipes()
      ..listed = [
        ownedRecipe,
        const Recipe(id: 12, name: 'Private soup', userId: 1),
      ];
    await renderMyRecipes(tester, service);
    expect(find.text('My Recipes'), findsOneWidget);
    expect(find.text('Lentil soup'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Private soup').hitTestable(),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Private soup'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
  });
  testWidgets('empty My Recipes offers creation and failures offer retry', (
    tester,
  ) async {
    final service = ManagementRecipes()..listed = [];
    await renderMyRecipes(tester, service);
    expect(find.text("You haven't created any recipes yet."), findsOneWidget);
    expect(
      find.text('Create your first recipe and it will appear here.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Create Recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Create recipe'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    service.listFailure = ApiException(
      message: 'Server unavailable.',
      statusCode: 500,
    );
    await tester.tap(find.byTooltip('Refresh recipes'));
    await tester.pumpAndSettle();
    expect(find.text('Server unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text("You haven't created any recipes yet."), findsNothing);
    service.listFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text("You haven't created any recipes yet."), findsOneWidget);
  });
  testWidgets(
    'owner can edit a prepopulated form and detail/list reload after save',
    (tester) async {
      final service = ManagementRecipes();
      await renderMyRecipes(tester, service);
      await tester.ensureVisible(find.text('Lentil soup'));
      await tester.tap(find.text('Lentil soup'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit recipe'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit recipe'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Recipe'), findsOneWidget);
      expect(find.text('Lentil soup'), findsOneWidget);
      expect(find.text('Homemade'), findsOneWidget);
      expect(find.text('Cook gently.'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Lentils (cup)'), findsOneWidget);
      expect(find.text('1.5'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'Updated soup');
      await tester.enterText(fields.last, '3');
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<RecipeVisibility>),
      );
      await tester.tap(find.text('Private — only you').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save changes'));
      expect(service.updatedId, 11);
      expect(service.creates, 0);
      expect(service.updateRequest!['visibility'], 'PRIVATE');
      expect(service.updateRequest!['cookingTime'], 30);
      expect(service.updateRequest!['category'], 'Soup');
      expect(service.updateRequest!.containsKey('origin'), isFalse);
      expect(find.text('Updated soup'), findsOneWidget);
      await tester.ensureVisible(find.text('Ingredients'));
      await tester.tap(find.text('Ingredients'));
      await tester.pumpAndSettle();
      expect(find.text('3 cup Lentils'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Updated soup'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(service.loads, 2);
    },
  );
  testWidgets(
    'edit validation and failed saves preserve input and do not create recipes',
    (tester) async {
      final service = ManagementRecipes()
        ..updateFailure = ApiException(
          message: 'Save failed.',
          statusCode: 500,
        );
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
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, '');
      await tester.enterText(fields.last, '0');
      await tapVisible(tester, find.text('Save changes'));
      expect(service.updatedId, isNull);
      expect(find.text('Enter a positive quantity.'), findsOneWidget);
      await tester.enterText(fields.first, 'Updated soup');
      await tester.enterText(fields.last, '2');
      await tapVisible(tester, find.text('Save changes'));
      expect(find.text('Save failed.'), findsOneWidget);
      expect(find.text('Updated soup'), findsOneWidget);
      expect(service.creates, 0);
    },
  );
  testWidgets(
    'edit can remove the final ingredient and submits an exact empty collection',
    (tester) async {
      final service = ManagementRecipes()
        ..updateFailure = ApiException(message: 'Fixture keeps form open');
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
      await tapVisible(tester, find.text('Remove ingredient'));
      expect(find.byType(DropdownButtonFormField<Ingredient>), findsNothing);
      await tapVisible(tester, find.text('Save changes'));
      expect(service.updateRequest!['ingredients'], isEmpty);
    },
  );
  testWidgets(
    'delete requires confirmation, cancellation preserves recipe, success reloads list',
    (tester) async {
      final service = ManagementRecipes();
      await renderMyRecipes(tester, service);
      await tester.ensureVisible(find.text('Lentil soup'));
      await tester.tap(find.text('Lentil soup'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete recipe'));
      await tester.pumpAndSettle();
      expect(
        find.text('This will permanently delete this recipe.'),
        findsOneWidget,
      );
      expect(service.deleted, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.deleted, 0);
      await tester.tap(find.byTooltip('Delete recipe'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(service.deleted, 1);
      expect(find.text('My Recipes'), findsOneWidget);
      expect(find.text('Lentil soup'), findsNothing);
      expect(service.loads, 2);
    },
  );
  testWidgets(
    'referenced recipe deletion shows backend reason and keeps detail',
    (tester) async {
      final service = ManagementRecipes()
        ..deleteFailure = ApiException(
          message: 'This recipe is used in a meal plan.',
          statusCode: 400,
        );
      await renderMyRecipes(tester, service);
      await tester.ensureVisible(find.text('Lentil soup'));
      await tester.tap(find.text('Lentil soup'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete recipe'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('This recipe is used in a meal plan.'), findsOneWidget);
      expect(find.byTooltip('Edit recipe'), findsOneWidget);
      expect(service.deleted, 0);
    },
  );
  testWidgets('non-owner and curated recipes expose no mutation actions', (
    tester,
  ) async {
    for (final recipe in [
      const Recipe(
        id: 11,
        name: 'Other soup',
        userId: 2,
        visibility: RecipeVisibility.public,
      ),
      const Recipe(
        id: 11,
        name: 'Curated soup',
        userId: 1,
        origin: RecipeOrigin.curated,
        visibility: RecipeVisibility.public,
      ),
    ]) {
      final service = ManagementRecipes()..current = recipe;
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeDetailScreen(
            key: ValueKey(recipe.name),
            recipe: recipe,
            recipeService: service,
            authService: ManagementAuth(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit recipe'), findsNothing);
      expect(find.byTooltip('Delete recipe'), findsNothing);
    }
  });
}
