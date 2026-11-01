import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/grocery_list.dart';
import 'package:akletna_frontend/models/meal_plan.dart';
import 'package:akletna_frontend/models/pantry_matches.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/screens/home/home_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_catalog_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:akletna_frontend/screens/recipes/recipe_plan_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipe_management_test.dart'
    show ManagementRecipes, ManagementAuth, ownedRecipe;
import 'support/dashboard_fixtures.dart';

const curated = Recipe(
  id: 90,
  name: 'Mountain lentils',
  description: 'Lentils with rice and gently caramelized onions.',
  instructions:
      'Rinse the lentils.\nSimmer until tender.\nServe with the onions.',
  servings: 4,
  cookingTime: 30,
  category: 'Home cooking',
  origin: RecipeOrigin.curated,
  visibility: RecipeVisibility.public,
  ingredients: [
    RecipeIngredient(
      id: 901,
      recipeId: 90,
      ingredientId: 7,
      name: 'Lentils',
      quantity: 200,
      unit: 'g',
    ),
  ],
);
const privateRecipe = Recipe(
  id: 92,
  name: 'Private family recipe',
  visibility: RecipeVisibility.private,
);

class PhaseRecipes extends ManagementRecipes {
  final Set<int> saved = {90};
  bool failSaved = false;
  Completer<List<Recipe>>? communityPending;
  Completer<List<Recipe>>? savedPending;
  PhaseRecipes() {
    current = curated;
  }
  @override
  Future<List<Recipe>> getRecipes() async => [
    curated,
    ownedRecipe,
    privateRecipe,
  ];
  @override
  Future<List<Recipe>> getCommunityRecipes() async => communityPending == null
      ? [ownedRecipe, curated, privateRecipe]
      : communityPending!.future;
  @override
  Future<List<Recipe>> getSavedRecipes() async {
    if (failSaved) throw ApiException(message: 'offline');
    if (savedPending != null) return savedPending!.future;
    return saved.contains(90) ? [curated] : [];
  }

  @override
  Future<void> saveRecipe(int id) async {
    saved.add(id);
  }

  @override
  Future<void> unsaveRecipe(int id) async {
    saved.remove(id);
  }
}

class PhasePlans extends DashboardPlans {
  int? addedRecipe, addedServings;
  DateTime? addedDate;
  MealType? addedType;
  int writes = 0;
  Object? failure;
  Completer<void>? pending;
  @override
  Future<List<MealPlan>> getWeek(DateTime date) async => [
    MealPlan(
      id: 31,
      recipeId: 90,
      recipeName: 'Captured family lunch',
      recipeCategory: 'Home cooking',
      recipeBaseServings: 4,
      plannedServings: 6,
      date: mealPlanDay(date),
      mealType: MealType.lunch,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];
  @override
  Future<MealPlan> addMeal({
    required int plannedServings,
    required int recipeId,
    required DateTime date,
    required MealType mealType,
  }) async {
    writes++;
    addedRecipe = recipeId;
    addedServings = plannedServings;
    addedDate = date;
    addedType = mealType;
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    return MealPlan(
      id: 32,
      recipeId: recipeId,
      recipeName: curated.name,
      plannedServings: plannedServings,
      date: date,
      mealType: mealType,
      createdAt: DateTime.now(),
    );
  }
}

class PhaseGroceries extends DashboardGroceries {
  bool checked = false;
  int? toggledId;
  bool fail = false;
  @override
  Future<GroceryList> getList() async {
    if (fail) throw ApiException(message: 'offline');
    return GroceryList(
      id: 1,
      updatedAt: null,
      items: [
        GroceryItem(
          id: 42,
          name: 'Lemons',
          quantity: 250,
          unit: 'g',
          checked: checked,
        ),
        const GroceryItem(
          id: 43,
          name: 'Rice',
          quantity: 1,
          unit: 'kg',
          checked: true,
        ),
      ],
    );
  }

  @override
  Future<GroceryItem> toggleItem(int id) async {
    toggledId = id;
    checked = !checked;
    return GroceryItem(
      id: id,
      name: 'Lemons',
      quantity: 250,
      unit: 'g',
      checked: checked,
    );
  }
}

class PhaseMatches extends DashboardMatches {
  @override
  Future<PantryMatches> getMatches() async => PantryMatches.fromJson({
    'pantryEmpty': false,
    'readableRecipeCount': 2,
    'excludedRecipeCount': 0,
    'matches': [
      for (final status in ['READY_TO_COOK', 'LIKELY_READY'])
        {
          'id': status == 'READY_TO_COOK' ? 90 : 91,
          'name': 'Matched recipe',
          'origin': 'CURATED',
          'visibility': 'PUBLIC',
          'status': status,
          'score': 100,
          'counts': {
            'enough': 1,
            'shortage': 0,
            'unknown': 0,
            'incomparable': 0,
            'missing': 0,
          },
          'ingredients': [
            {
              'ingredientId': 7,
              'ingredientName': 'Lentils',
              'status': 'ENOUGH',
              'required': {'quantity': '200', 'unit': 'g'},
              'available': {'quantity': '250', 'unit': 'g'},
            },
          ],
        },
    ],
  });
}

const captureKey = ValueKey('stitch-capture');
Future<void> render(
  WidgetTester tester,
  Widget screen, {
  double width = 390,
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(key: captureKey, child: screen),
      routes: {
        '/login': (_) => const Scaffold(body: Text('Login destination')),
      },
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('STITCH_CAPTURE')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final screenshot = await boundary.toImage(pixelRatio: 1);
    final data = await screenshot.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/stitch-phase3');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    screenshot.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('STITCH_CAPTURE')) return;
    const fonts = String.fromEnvironment('STITCH_FONT_DIR');
    if (fonts.isEmpty) {
      throw StateError(
        'Set STITCH_FONT_DIR to the Flutter material_fonts cache for local captures.',
      );
    }
    final roboto = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      roboto.addFont(
        File('$fonts/roboto-$weight.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await roboto.load();
    final platformFallback = FontLoader('Ahem');
    for (final weight in ['regular', 'medium', 'bold']) {
      platformFallback.addFont(
        File('$fonts/roboto-$weight.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await platformFallback.load();
    await (FontLoader('MaterialIcons')..addFont(
          File('$fonts/MaterialIcons-Regular.otf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
  });
  testWidgets(
    'Home uses meal snapshots, confirmed readiness and stored grocery IDs',
    (tester) async {
      final grocery = PhaseGroceries();
      await render(
        tester,
        HomeScreen(
          recommendationService: DashboardRecommendations(),
          authService: ManagementAuth(),
          recipeService: PhaseRecipes(),
          mealPlanService: PhasePlans(),
          groceryListService: grocery,
          matchingService: PhaseMatches(),
        ),
      );
      expect(find.textContaining('Owner'), findsWidgets);
      expect(find.text('Captured family lunch'), findsOneWidget);
      expect(find.text('6 servings'), findsOneWidget);
      expect(find.text('1 ready'), findsOneWidget);
      await capture(tester, 'home');
      final check = find.byKey(const ValueKey('home-grocery-42'));
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(grocery.toggledId, 42);
      expect(tester.widget<CheckboxListTile>(check).value, isTrue);
      expect(find.text('0 items remaining'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Home module failure preserves other real results and retries', (
    tester,
  ) async {
    final grocery = PhaseGroceries()..fail = true;
    await render(
      tester,
      HomeScreen(
        recommendationService: DashboardRecommendations(),
        authService: ManagementAuth(),
        recipeService: PhaseRecipes(),
        mealPlanService: PhasePlans(),
        groceryListService: grocery,
        matchingService: PhaseMatches(),
      ),
    );
    expect(find.text('Captured family lunch'), findsOneWidget);
    expect(find.text('1 ready'), findsOneWidget);
    expect(find.text('Unavailable. Check your connection.'), findsOneWidget);
    grocery.fail = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('1 item remaining'), findsOneWidget);
  });
  testWidgets(
    'Discover switches collections, keeps search and updates actual bookmarks',
    (tester) async {
      final recipes = PhaseRecipes();
      await render(
        tester,
        RecipeCatalogScreen(
          recipeService: recipes,
          authService: ManagementAuth(),
        ),
      );
      expect(find.text('Mountain lentils'), findsOneWidget);
      expect(find.text('Lentil soup'), findsNothing);
      expect(find.text('Private family recipe'), findsNothing);
      await capture(tester, 'discover');
      await tester.tap(find.byTooltip('Unsave recipe'));
      await tester.pumpAndSettle();
      expect(recipes.saved, isEmpty);
      await tester.tap(find.byTooltip('Save recipe'));
      await tester.pumpAndSettle();
      expect(recipes.saved, {90});
      await tester.tap(find.text('Community Recipes'));
      await tester.pumpAndSettle();
      expect(find.text('Lentil soup'), findsOneWidget);
      expect(find.text('Mountain lentils'), findsNothing);
      expect(find.text('Private family recipe'), findsNothing);
      await tester.enterText(find.byType(TextField), 'not present');
      await tester.pumpAndSettle();
      expect(find.text('No matching recipes'), findsOneWidget);
      await tester.tap(find.text('Curated Kitchen'));
      await tester.pumpAndSettle();
      expect(find.text('No matching recipes'), findsOneWidget);
    },
  );
  testWidgets(
    'stale collection response cannot replace the newly selected collection',
    (tester) async {
      final recipes = PhaseRecipes()
        ..communityPending = Completer<List<Recipe>>();
      await render(tester, RecipeCatalogScreen(recipeService: recipes));
      await tester.tap(find.text('Community Recipes'));
      await tester.pump();
      await tester.tap(find.text('Curated Kitchen'));
      await tester.pumpAndSettle();
      recipes.communityPending!.complete([ownedRecipe]);
      await tester.pumpAndSettle();
      expect(find.text('Mountain lentils'), findsOneWidget);
      expect(find.text('Lentil soup'), findsNothing);
    },
  );
  testWidgets(
    'detail scales quantities, retains checklist across tabs and plans selected servings',
    (tester) async {
      final plans = PhasePlans();
      await render(
        tester,
        RecipeDetailScreen(
          recipe: curated,
          recipeService: PhaseRecipes(),
          authService: ManagementAuth(),
          mealPlanService: plans,
        ),
      );
      expect(find.text('UNAVAILABLE'), findsOneWidget);
      expect(find.byKey(const ValueKey('nutrition-stats')), findsNothing);
      await capture(tester, 'detail');
      await tester.ensureVisible(find.text('Ingredients'));
      await tester.tap(find.text('Ingredients'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Increase servings'));
      await tester.tap(find.byTooltip('Increase servings'));
      await tester.pumpAndSettle();
      expect(find.text('250 g Lentils'), findsOneWidget);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(find.text('1/1 checked'), findsOneWidget);
      await tester.ensureVisible(find.text('Steps'));
      await tester.tap(find.text('Steps'));
      await tester.pumpAndSettle();
      expect(find.text('Simmer until tender.'), findsOneWidget);
      expect(find.text('3 instruction sections'), findsOneWidget);
      await capture(tester, 'detail-steps');
      await tester.tap(find.byTooltip('Ingredient checklist'));
      await tester.pumpAndSettle();
      expect(find.text('1/1 checked'), findsOneWidget);
      await tester.tap(find.text('Add to Meal Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add meal'));
      await tester.pumpAndSettle();
      expect(plans.addedRecipe, 90);
      expect(plans.addedServings, 5);
      expect(plans.addedType, MealType.lunch);
      expect(mealPlanDate(plans.addedDate!), mealPlanDate(DateTime.now()));
      expect(plans.writes, 1);
    },
  );
  testWidgets(
    'meal submission blocks duplicates and reports an occupied slot honestly',
    (tester) async {
      final plans = PhasePlans()
        ..pending = Completer<void>()
        ..failure = ApiException(message: 'occupied', statusCode: 409);
      await render(
        tester,
        Scaffold(
          body: RecipePlanSheet(
            recipeId: 90,
            servings: 4,
            service: plans,
            onUnauthorized: () {},
          ),
        ),
      );
      await tester.tap(find.text('Add meal'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(plans.writes, 1);
      plans.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('already filled'), findsOneWidget);
      expect(plans.writes, 1);
    },
  );
  testWidgets('all Phase 3 detail tabs work at 320dp with 1.8 text scaling', (
    tester,
  ) async {
    await render(
      tester,
      RecipeDetailScreen(
        recipe: curated,
        recipeService: PhaseRecipes(),
        authService: ManagementAuth(),
      ),
      width: 320,
      scale: 1.8,
    );
    for (final tab in ['Ingredients', 'Steps', 'Recipe']) {
      await tester.ensureVisible(find.widgetWithText(TextButton, tab));
      await tester.tap(find.widgetWithText(TextButton, tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'populated Home and Discover stay usable at 320dp and enlarged text',
    (tester) async {
      await render(
        tester,
        HomeScreen(
          recommendationService: DashboardRecommendations(),
          authService: ManagementAuth(),
          recipeService: PhaseRecipes(),
          mealPlanService: PhasePlans(),
          groceryListService: PhaseGroceries(),
          matchingService: PhaseMatches(),
        ),
        width: 320,
        scale: 1.8,
      );
      await tester.ensureVisible(find.text('Food Preferences'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await render(
        tester,
        RecipeCatalogScreen(
          recipeService: PhaseRecipes(),
          authService: ManagementAuth(),
        ),
        width: 320,
        scale: 1.8,
      );
      await tester.tap(find.byTooltip('Recipe filters'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Home has no search bar and shows Recommended first', (
    tester,
  ) async {
    await render(
      tester,
      HomeScreen(
        recommendationService: DashboardRecommendations(),
        authService: ManagementAuth(),
        recipeService: PhaseRecipes(),
        mealPlanService: PhasePlans(),
        groceryListService: PhaseGroceries(),
        matchingService: PhaseMatches(),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(
      tester.getTopLeft(find.text('Recommended for You')).dy,
      lessThan(tester.getTopLeft(find.text("This Week's Table")).dy),
    );
  });
  testWidgets(
    'failed saved collection exposes an unknown state and opens authoritative detail',
    (tester) async {
      await render(
        tester,
        RecipeCatalogScreen(
          recipeService: PhaseRecipes()..failSaved = true,
          authService: ManagementAuth(),
        ),
      );
      expect(find.byTooltip('Save recipe'), findsNothing);
      expect(find.byTooltip('Unsave recipe'), findsNothing);
      await tester.tap(find.byTooltip('Open recipe to check bookmark'));
      await tester.pumpAndSettle();
      expect(find.byType(RecipeDetailScreen), findsOneWidget);
      expect(find.byTooltip('Save recipe'), findsOneWidget);
    },
  );
  testWidgets(
    'stale saved-library read cannot undo a confirmed bookmark change',
    (tester) async {
      final recipes = PhaseRecipes();
      await render(
        tester,
        RecipeCatalogScreen(
          recipeService: recipes,
          authService: ManagementAuth(),
        ),
      );
      recipes.savedPending = Completer<List<Recipe>>();
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Unsave recipe'));
      await tester.pumpAndSettle();
      recipes.savedPending!.complete([curated]);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save recipe'), findsOneWidget);
      expect(find.byTooltip('Unsave recipe'), findsNothing);
    },
  );
  testWidgets(
    '401 during meal submission returns to the existing login route',
    (tester) async {
      final plans = PhasePlans()
        ..failure = ApiException(message: 'expired', statusCode: 401);
      await render(
        tester,
        RecipeDetailScreen(
          recipe: curated,
          recipeService: PhaseRecipes(),
          authService: ManagementAuth(),
          mealPlanService: plans,
        ),
      );
      await tester.tap(find.text('Add to Meal Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add meal'));
      await tester.pumpAndSettle();
      expect(find.text('Login destination'), findsOneWidget);
      expect(find.textContaining('Meal added.'), findsNothing);
    },
  );
}
