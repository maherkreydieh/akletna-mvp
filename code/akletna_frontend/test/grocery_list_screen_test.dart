import 'dart:async';

import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';

import 'api_client_test.dart' show FixtureAdapter;
import 'auth_service_test.dart' show MemoryTokenStorage;
import 'meal_plan_service_test.dart' show mealResponse;

import 'package:akletna_frontend/core/constants/app_constants.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/core/theme/app_theme.dart';
import 'package:akletna_frontend/models/grocery_list.dart';
import 'package:akletna_frontend/screens/groceries/grocery_list_screen.dart';
import 'package:akletna_frontend/services/grocery_list_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const lentils = GroceryItem(
  id: 100,
  name: 'Lentils',
  quantity: 3.5,
  unit: 'cup',
  checked: false,
);
const salt = GroceryItem(id: 101, name: 'Salt', quantity: 0.67, checked: false);
const grams = GroceryItem(
  id: 102,
  name: 'Lentils',
  quantity: 100,
  unit: 'g',
  checked: false,
);

GroceryItem withCheck(GroceryItem item, bool checked) => GroceryItem(
  id: item.id,
  name: item.name,
  quantity: item.quantity,
  unit: item.unit,
  checked: checked,
  displayQuantity: item.displayQuantity,
  displayUnit: item.displayUnit,
);

class GroceryFixture extends GroceryListService {
  List<GroceryItem> items = [lentils, salt, grams];
  final weeks = <DateTime>[];
  final toggled = <int>[];
  int storedReads = 0;
  Object? loadError;
  Object? toggleError;
  bool loseToggleResponse = false;
  Completer<GroceryList>? pending;

  GroceryList get list => GroceryList(
    id: 10,
    updatedAt: DateTime(2026, 10, 3),
    items: List.of(items),
  );

  @override
  Future<GroceryList> generateWeek(DateTime date) async {
    weeks.add(date);
    if (loadError != null) throw loadError!;
    if (pending != null) return pending!.future;
    items = [for (final item in items) withCheck(item, false)];
    return list;
  }

  @override
  Future<GroceryList> getList() async {
    storedReads++;
    if (loadError != null) throw loadError!;
    if (pending != null) return pending!.future;
    return list;
  }

  @override
  Future<GroceryItem> toggleItem(int id) async {
    toggled.add(id);
    if (toggleError != null) throw toggleError!;
    items = [
      for (final item in items)
        item.id == id ? withCheck(item, !item.checked) : item,
    ];
    if (loseToggleResponse) throw ApiException(message: 'Lost response');
    return items.firstWhere((item) => item.id == id);
  }
}

Widget groceryApp(GroceryFixture fixture) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: GroceryListScreen(
    groceryListService: fixture,
    initialDate: DateTime(2026, 10, 3),
  ),
  routes: {
    AppConstants.loginRoute: (_) =>
        const Scaffold(body: Text('Login destination')),
  },
);

void main() {
  testWidgets(
    'renders backend g kg mL L and incompatible rows separately across toggle',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = GroceryFixture()
        ..items = [
          const GroceryItem(
            id: 100,
            name: 'Rice',
            quantity: 1500,
            unit: 'g',
            displayQuantity: 1.5,
            displayUnit: 'kg',
            checked: false,
          ),
          const GroceryItem(
            id: 101,
            name: 'Rice',
            quantity: 2,
            unit: 'cup',
            displayQuantity: 2,
            displayUnit: 'cup',
            checked: false,
          ),
          const GroceryItem(
            id: 102,
            name: 'Flour',
            quantity: 750,
            unit: 'g',
            displayQuantity: 750,
            displayUnit: 'g',
            checked: false,
          ),
          const GroceryItem(
            id: 103,
            name: 'Milk',
            quantity: 2500,
            unit: 'mL',
            displayQuantity: 2.5,
            displayUnit: 'L',
            checked: false,
          ),
          const GroceryItem(
            id: 104,
            name: 'Juice',
            quantity: 750,
            unit: 'mL',
            displayQuantity: 750,
            displayUnit: 'mL',
            checked: false,
          ),
        ];
      await tester.pumpWidget(groceryApp(fixture));
      await tester.pumpAndSettle();
      for (final label in ['1.5 kg', '2 cup', '750 g', '2.5 L', '750 mL']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Rice'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('grocery-100')));
      await tester.pumpAndSettle();
      expect(find.text('1.5 kg'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('grocery-100')))
            .value,
        isTrue,
      );
    },
  );
  testWidgets(
    'grocery UI displays backend-scaled quantities and refreshes without local scaling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = GroceryFixture()
        ..items = [
          const GroceryItem(
            id: 100,
            name: 'Rice',
            quantity: 450,
            unit: 'g',
            checked: false,
          ),
        ];
      await tester.pumpWidget(groceryApp(fixture));
      await tester.pumpAndSettle();
      expect(find.textContaining('450 g'), findsOneWidget);
      fixture.items = [
        const GroceryItem(
          id: 100,
          name: 'Rice',
          quantity: 150,
          unit: 'g',
          checked: false,
        ),
      ];
      await tester.tap(find.byTooltip('Refresh groceries'));
      await tester.pumpAndSettle();
      expect(find.textContaining('150 g'), findsOneWidget);
      expect(find.textContaining('450 g'), findsNothing);
    },
  );
  testWidgets(
    'unsafe legacy scaling shows the backend explanation instead of fake quantities',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = GroceryFixture()
        ..loadError = ApiException(
          message: 'This recipe has no valid base serving count.',
          statusCode: 400,
        );
      await tester.pumpWidget(groceryApp(fixture));
      await tester.pumpAndSettle();
      expect(
        find.text('This recipe has no valid base serving count.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    },
  );
  testWidgets(
    'actual client/service distinguishes HTTP 200 empty items from failure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      addTearDown(dio.close);
      final service = GroceryListService(
        apiClient: ApiClient(dio: dio, tokenStorage: MemoryTokenStorage()),
      );
      dio.httpClientAdapter = FixtureAdapter(
        (_) => mealResponse({
          'id': 10,
          'updatedAt': '2026-10-03T12:00:00',
          'items': [],
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: GroceryListScreen(groceryListService: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your grocery list is empty'), findsOneWidget);
      expect(
        find.text(
          'Plan meals or add missing recipe ingredients to start your list.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Could not load your groceries'),
        findsNothing,
      );
      expect(find.text('Retry'), findsNothing);
      dio.httpClientAdapter = FixtureAdapter((_) => mealResponse({}, 500));
      await tester.tap(find.byTooltip('Refresh groceries'));
      await tester.pumpAndSettle();
      expect(find.text('Your grocery list is empty'), findsNothing);
      expect(
        find.textContaining('Could not load your groceries'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('renders backend totals and units separately on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 720));
    final fixture = GroceryFixture();
    await tester.pumpWidget(groceryApp(fixture));
    await tester.pumpAndSettle();
    for (final item in fixture.items) {
      final row = find.byKey(ValueKey('grocery-${item.id}'));
      await tester.scrollUntilVisible(
        row,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(of: row, matching: find.text(item.quantityLabel)),
        findsOneWidget,
      );
    }
    await tester.scrollUntilVisible(
      find.text('0 of 3 purchased'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('0 of 3 purchased'), findsOneWidget);
    expect(fixture.items.length, 3);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty week offers planner navigation and refresh', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = GroceryFixture()..items = [];
    await tester.pumpWidget(groceryApp(fixture));
    await tester.pumpAndSettle();
    expect(find.text('Your grocery list is empty'), findsOneWidget);
    expect(find.text('Plan meals'), findsOneWidget);
    expect(find.byTooltip('Open weekly meal planner'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.byTooltip('Refresh groceries'));
    await tester.pumpAndSettle();
    expect(fixture.weeks, isEmpty);
    expect(fixture.storedReads, 2);
  });

  testWidgets(
    'refresh replaces old quantities and removes groceries after remote plan removal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = GroceryFixture();
      await tester.pumpWidget(groceryApp(fixture));
      await tester.pumpAndSettle();
      fixture.items = [
        const GroceryItem(
          id: 200,
          name: 'Lentils',
          quantity: 1.5,
          unit: 'cup',
          checked: false,
        ),
      ];
      await tester.tap(find.byTooltip('Refresh groceries'));
      await tester.pumpAndSettle();
      expect(find.text('1.5 cup'), findsOneWidget);
      expect(find.text('Salt'), findsNothing);
      fixture.items = [];
      await tester.tap(find.byTooltip('Refresh groceries'));
      await tester.pumpAndSettle();
      expect(find.text('Lentils'), findsNothing);
      expect(find.text('Your grocery list is empty'), findsOneWidget);
    },
  );

  testWidgets('checked rows use backend state and regeneration resets checks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = GroceryFixture();
    await tester.pumpWidget(groceryApp(fixture));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grocery-100')));
    await tester.pumpAndSettle();
    expect(fixture.toggled, [100]);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const ValueKey('grocery-100')))
          .value,
      isTrue,
    );
    expect(find.text('1 of 3 purchased'), findsOneWidget);
    expect(fixture.weeks, isEmpty);
    await tester.tap(find.byTooltip('Refresh groceries'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const ValueKey('grocery-100')))
          .value,
      isTrue,
    );
    final generate = find.text('Generate Grocery List');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(fixture.weeks.length, 1);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const ValueKey('grocery-100')))
          .value,
      isFalse,
    );
  });

  testWidgets(
    'lost toggle response reads saved state without toggling twice or resetting checks',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = GroceryFixture()..loseToggleResponse = true;
      await tester.pumpWidget(groceryApp(fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grocery-100')));
      await tester.pumpAndSettle();
      expect(fixture.toggled, [100]);
      expect(fixture.storedReads, 2);
      expect(fixture.weeks, isEmpty);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('grocery-100')))
            .value,
        isTrue,
      );
    },
  );

  testWidgets(
    'loading and error retry recover without exposing technical details',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = GroceryFixture()..pending = Completer<GroceryList>();
      await tester.pumpWidget(groceryApp(fixture));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      fixture.pending!.completeError(StateError('private stack details'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('private stack details'), findsNothing);
      fixture.pending = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Salt'), findsOneWidget);
    },
  );

  testWidgets('401 generation and toggle return to existing login route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = GroceryFixture()
      ..loadError = ApiException(message: 'Unauthorized', statusCode: 401);
    await tester.pumpWidget(groceryApp(fixture));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    final authenticated = GroceryFixture()
      ..toggleError = ApiException(message: 'Unauthorized', statusCode: 401);
    await tester.pumpWidget(groceryApp(authenticated));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grocery-100')));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    expect(authenticated.storedReads, 1);
  });

  testWidgets(
    'previous and next weeks use the same Monday boundaries as planner',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = GroceryFixture();
      await tester.pumpWidget(groceryApp(fixture));
      await tester.pumpAndSettle();
      expect(fixture.weeks, isEmpty);
      expect(find.text('2026-09-28 – 2026-10-04'), findsOneWidget);
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(find.text('2026-10-05 – 2026-10-11'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous week'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-28 – 2026-10-04'), findsOneWidget);
      expect(fixture.weeks, isEmpty);
    },
  );
}
