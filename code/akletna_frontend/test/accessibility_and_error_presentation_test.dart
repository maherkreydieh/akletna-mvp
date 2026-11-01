import 'support/dashboard_fixtures.dart';

import 'package:akletna_frontend/core/constants/app_colors.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/core/presentation/quantity_label.dart';
import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/screens/auth/login_screen.dart';
import 'package:akletna_frontend/screens/home/home_screen.dart';
import 'package:akletna_frontend/screens/recipes/create_recipe_screen.dart';
import 'package:akletna_frontend/widgets/recipe_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'create_recipe_screen_test.dart' show IngredientsFixture, RecipesFixture;
import 'pantry_test.dart' show HomeAuth;

Widget phone(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8)),
    child: child!,
  ),
  home: child,
);

void main() {
  test('presentation rounds macros without turning tiny amounts into zero', () {
    expect(quantityLabel(108.333333), '108.33');
    expect(quantityLabel(23.475), '23.48');
    expect(quantityLabel(2), '2');
    expect(quantityLabel(0), '0');
    expect(quantityLabel(0.001), '<0.01');
  });

  test('secondary body text meets normal-text contrast on both surfaces', () {
    for (final background in [AppColors.surface, AppColors.background]) {
      final ratio =
          (background.computeLuminance() + .05) /
          (AppColors.textSecondary.computeLuminance() + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });

  test('technical response bodies stay out of user-facing errors', () {
    final request = RequestOptions(path: '/example');
    for (final body in [
      '<html>proxy unavailable</html>',
      {'message': 'java.lang.Exception SQL failure at https://example.test'},
    ]) {
      final error = ApiException.fromDioException(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: request,
            statusCode: 400,
            data: body,
          ),
        ),
      );
      expect(error.statusCode, 400);
      expect(error.message, isNot(contains('java.')));
      expect(error.message, isNot(contains('<html>')));
      expect(error.message, isNot(contains('https://')));
    }
  });

  testWidgets(
    'long recipe card remains tappable at narrow width and large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = false;
      await tester.pumpWidget(
        phone(
          Scaffold(
            body: SingleChildScrollView(
              child: RecipeCard(
                recipe: const Recipe(
                  id: 1,
                  name: 'Mujadara with caramelized onions and a very long descriptive recipe name',
                  category: 'Traditional Lebanese home cooking',
                  cookingTime: 120,
                  servings: 12,
                ),
                onTap: () => opened = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(RecipeCard));
      expect(opened, isTrue);
    },
  );

  testWidgets(
    'Home sections remain reachable with large text on a narrow phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        phone(
          HomeScreen(
            recommendationService: DashboardRecommendations(),
            recipeService: DashboardRecipes(),
            mealPlanService: DashboardPlans(),
            groceryListService: DashboardGroceries(),
            matchingService: DashboardMatches(),
            authService: HomeAuth(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final title in [
        'Recommended for You',
        'Saved Recipes',
        'My Kitchen',
        'Food Preferences',
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'login keyboard layout and accessible register action do not overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(phone(const LoginScreen()));
      await tester.ensureVisible(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Register'), findsOneWidget);
      expect(find.byTooltip('Show or hide password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'create form remains scrollable on a narrow phone with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        phone(
          CreateRecipeScreen(
            recipeService: RecipesFixture(),
            ingredientService: IngredientsFixture(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create recipe'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
