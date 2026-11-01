import 'package:akletna_frontend/core/constants/app_constants.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/main.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/user.dart';
import 'package:akletna_frontend/screens/recipes/recipe_detail_screen.dart';
import 'package:akletna_frontend/screens/splash_screen.dart';
import 'package:akletna_frontend/services/auth_service.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_service_test.dart' show MemoryTokenStorage;
import 'recipe_service_test.dart'
    show FixtureApiClient, metadata, ingredientLine;

class FailingProfileService extends AuthService {
  final int? status;
  FailingProfileService(this.status);
  @override
  Future<User> getCurrentUser() async =>
      throw ApiException(message: 'Profile unavailable', statusCode: status);
}

class FailingSessionDelete extends MemoryTokenStorage {
  FailingSessionDelete() : super('test-session');
  @override
  Future<void> deleteToken() async => throw StateError('Storage unavailable');
}

Widget splashApp(MemoryTokenStorage storage, int? status) => MaterialApp(
  home: SplashScreen(
    tokenStorage: storage,
    authService: FailingProfileService(status),
  ),
  routes: {
    AppConstants.loginRoute: (_) =>
        const Scaffold(body: Text('Login destination')),
  },
);

void main() {
  testWidgets('session cleanup failure offers retry without an async crash', (
    tester,
  ) async {
    await tester.pumpWidget(splashApp(FailingSessionDelete(), 401));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not clear your session. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Login destination'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Akletna opens login when there is no stored session', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const AkletnaApp());
    expect(find.text('Akletna'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('network failure offers retry and preserves the stored session', (
    tester,
  ) async {
    final storage = MemoryTokenStorage('test-session');
    await tester.pumpWidget(splashApp(storage, null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(storage.token, 'test-session');
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Login destination'), findsNothing);
  });

  testWidgets('rejected session is cleared and returns to login', (
    tester,
  ) async {
    final storage = MemoryTokenStorage('test-session');
    await tester.pumpWidget(splashApp(storage, 401));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(storage.token, isNull);
    expect(find.text('Login destination'), findsOneWidget);
  });

  testWidgets('recipe detail shows backend ingredient names and quantities', (
    tester,
  ) async {
    final api = FixtureApiClient({
      '/api/recipes/11': metadata,
      '/api/recipes/11/ingredients': [ingredientLine],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: Recipe.fromJson(metadata),
          recipeService: RecipeService(apiClient: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingredients'));
    await tester.pumpAndSettle();
    expect(find.text('1.5 cup Lentils'), findsOneWidget);
    expect(find.text('No ingredients listed for this recipe.'), findsNothing);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(find.text('1/1 checked'), findsOneWidget);
  });
}
