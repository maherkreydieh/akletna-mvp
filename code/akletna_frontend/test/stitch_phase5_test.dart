import 'package:akletna_frontend/core/constants/app_constants.dart';
import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/main.dart';
import 'package:akletna_frontend/models/user.dart';
import 'package:akletna_frontend/screens/auth/login_screen.dart';
import 'package:akletna_frontend/screens/auth/register_screen.dart';
import 'package:akletna_frontend/screens/home/home_screen.dart';
import 'package:akletna_frontend/screens/home/profile_screen.dart';
import 'package:akletna_frontend/screens/kitchen_shell.dart';
import 'package:akletna_frontend/screens/recipes/recipe_catalog_screen.dart';
import 'package:akletna_frontend/screens/meal_plans/weekly_meal_planner_screen.dart';
import 'package:akletna_frontend/screens/groceries/grocery_list_screen.dart';
import 'package:akletna_frontend/screens/pantry/my_pantry_screen.dart';
import 'package:akletna_frontend/widgets/kitchen_navigation_bar.dart';
import 'package:akletna_frontend/screens/recipes/my_recipes_screen.dart';
import 'package:akletna_frontend/screens/recipes/saved_recipes_screen.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipe_management_test.dart' show ManagementAuth, ManagementIngredients;
import 'support/dashboard_fixtures.dart';

class OfflineLibrary extends RecipeService {
  @override
  Future<List<Never>> getMyRecipes() async => throw StateError('offline');
}

void main() {
  testWidgets(
    'production shell tabs instantiate all five redesigned destinations',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const KitchenShell()),
      );
      final destinations = <Type>[
        HomeScreen,
        RecipeCatalogScreen,
        WeeklyMealPlannerScreen,
        GroceryListScreen,
        MyPantryScreen,
      ];
      for (var index = 0; index < destinations.length; index++) {
        await tester.tap(
          find.descendant(
            of: find.byType(KitchenNavigationBar),
            matching: find.text(KitchenNavigationBar.labels[index]),
          ),
        );
        await tester.pump();
        expect(find.byType(destinations[index]), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
      // Drain Dio's queued request callbacks after disposing the destinations.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('production named routes use the Stitch shell and auth screens', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const AkletnaApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(Navigator));
    expect(app.initialRoute, AppConstants.splashRoute);
    expect(app.routes![AppConstants.homeRoute]!(context), isA<KitchenShell>());
    expect(app.routes![AppConstants.loginRoute]!(context), isA<LoginScreen>());
    expect(
      app.routes![AppConstants.registerRoute]!(context),
      isA<RegisterScreen>(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Register'));
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'Home profile opens real account and existing personal recipe routes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(
            recommendationService: DashboardRecommendations(),
            authService: ManagementAuth(),
            recipeService: DashboardRecipes(),
            mealPlanService: DashboardPlans(),
            groceryListService: DashboardGroceries(),
            matchingService: DashboardMatches(),
            ingredientService: ManagementIngredients(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile & Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('owner@example.test'), findsOneWidget);
      await tester.ensureVisible(find.text('Saved Recipes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved Recipes'));
      await tester.pumpAndSettle();
      expect(find.byType(SavedRecipesScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('My Recipes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Recipes'));
      await tester.pumpAndSettle();
      expect(find.byType(MyRecipesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account actions remain reachable at 320dp with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var loggedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.8)),
            child: ProfileScreen(
              user: User(
                id: 1,
                name: 'A long account name',
                email: 'owner@example.test',
              ),
              onPreferences: () {},
              onSaved: () {},
              onRecipes: () {},
              onLogout: () => loggedOut = true,
            ),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Logout').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Logout'));
    expect(loggedOut, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unexpected library network failure provides retry without false counts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MyRecipesScreen(recipeService: OfflineLibrary()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load your recipes. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('0 recipes'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
