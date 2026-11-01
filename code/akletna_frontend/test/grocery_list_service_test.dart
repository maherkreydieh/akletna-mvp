import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/models/grocery_list.dart';
import 'package:akletna_frontend/services/grocery_list_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_client_test.dart' show FixtureAdapter;
import 'auth_service_test.dart' show MemoryTokenStorage;
import 'meal_plan_service_test.dart' show mealResponse;

const groceryItemJson = {
  'id': 100,
  'name': 'Lentils',
  'quantity': 3.5,
  'unit': 'cup',
  'checked': false,
};
const groceryListJson = {
  'id': 10,
  'updatedAt': '2026-10-03T12:00:00',
  'items': [groceryItemJson],
};

void main() {
  test(
    'uses authoritative display pairs while retaining canonical quantities',
    () {
      for (final row in [
        [750, 'g', 750, 'g', '750 g'],
        [1500, 'g', 1.5, 'kg', '1.5 kg'],
        [750, 'mL', 750, 'mL', '750 mL'],
        [2500, 'mL', 2.5, 'L', '2.5 L'],
        [1500.01, 'g', 1.50001, 'kg', '1.5 kg'],
      ]) {
        final item = GroceryItem.fromJson({
          ...groceryItemJson,
          'quantity': row[0],
          'unit': row[1],
          'displayQuantity': row[2],
          'displayUnit': row[3],
        });
        expect(item.quantity, row[0]);
        expect(item.unit, row[1]);
        expect(item.quantityLabel, row[4]);
      }
      // An older API gets an honest fallback, without locally deciding a conversion.
      expect(
        GroceryItem.fromJson({
          ...groceryItemJson,
          'quantity': 1500,
          'unit': 'g',
        }).quantityLabel,
        '1500 g',
      );
    },
  );
  test('rejects incomplete or invalid backend display pairs', () {
    for (final fields in [
      {'displayQuantity': 1},
      {'displayUnit': 'kg'},
      {'displayQuantity': -1, 'displayUnit': 'kg'},
      {'displayQuantity': double.infinity, 'displayUnit': 'kg'},
    ]) {
      expect(
        () => GroceryItem.fromJson({...groceryItemJson, ...fields}),
        throwsFormatException,
      );
    }
  });
  test(
    'grocery quantities accept numbers, preserve units and do not convert them',
    () {
      expect(GroceryItem.fromJson(groceryItemJson).quantityLabel, '3.5 cup');
      expect(
        GroceryItem.fromJson({...groceryItemJson, 'quantity': 2, 'unit': ' g '})
            .quantityLabel,
        '2 g',
      );
      for (final unit in [null, '', ' ']) {
        expect(
          GroceryItem.fromJson({
            ...groceryItemJson,
            'quantity': 2,
            'unit': unit,
          }).quantityLabel,
          '2',
        );
      }
      for (final quantity in [double.nan, double.infinity, -1]) {
        expect(
          () =>
              GroceryItem.fromJson({...groceryItemJson, 'quantity': quantity}),
          throwsFormatException,
        );
      }
      expect(
        GroceryList.fromJson({...groceryListJson, 'items': []}).items,
        isEmpty,
      );
    },
  );

  test('generation shares planner week dates and GET/PATCH reuse JWT authentication', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    addTearDown(dio.close);
    dio.httpClientAdapter = FixtureAdapter((options) {
      requests.add(options);
      return mealResponse(
        options.method == 'PATCH'
            ? {...groceryItemJson, 'checked': true}
            : groceryListJson,
      );
    });
    final service = GroceryListService(
      apiClient: ApiClient(
        dio: dio,
        tokenStorage: MemoryTokenStorage('test-session'),
      ),
    );
    expect(
      (await service.generateWeek(DateTime(2027, 1, 1))).items.single.name,
      'Lentils',
    );
    expect(requests.first.data, {
      'startDate': '2026-12-28',
      'endDate': '2027-01-03',
    });
    await service.getList();
    expect((await service.toggleItem(100)).checked, isTrue);
    expect(requests.map((request) => '${request.method} ${request.path}'), [
      'POST /api/grocery-list/generate',
      'GET /api/grocery-list',
      'PATCH /api/grocery-list/items/100/toggle',
    ]);
    expect(requests.last.data, isNull);
    expect(
      requests.every(
        (request) => request.headers['Authorization'] == 'Bearer test-session',
      ),
      isTrue,
    );
  });

  test(
    'malformed list/item responses fail rather than becoming an empty list',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      addTearDown(dio.close);
      final service = GroceryListService(
        apiClient: ApiClient(dio: dio, tokenStorage: MemoryTokenStorage()),
      );
      for (final data in [
        null,
        [],
        {...groceryListJson, 'items': null},
        {
          ...groceryListJson,
          'items': [
            {'name': 'Missing quantity'},
          ],
        },
      ]) {
        dio.httpClientAdapter = FixtureAdapter((_) => mealResponse(data));
        await expectLater(
          service.generateWeek(DateTime(2026, 10, 3)),
          throwsA(isA<ApiException>()),
        );
      }
      dio.httpClientAdapter = FixtureAdapter(
        (_) => mealResponse({...groceryItemJson, 'id': 999}),
      );
      await expectLater(service.toggleItem(100), throwsA(isA<ApiException>()));
    },
  );

  test(
    'HTTP failures retain status; failed PATCH clears a rejected session',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      addTearDown(dio.close);
      final storage = MemoryTokenStorage('test-session');
      final service = GroceryListService(
        apiClient: ApiClient(dio: dio, tokenStorage: storage),
      );
      for (final status in [500, 404, 403]) {
        dio.httpClientAdapter = FixtureAdapter(
          (_) => mealResponse({'message': 'Rejected'}, status),
        );
        await expectLater(
          service.generateWeek(DateTime(2026, 10, 3)),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'status',
              status,
            ),
          ),
        );
      }
      expect(storage.token, 'test-session');
      dio.httpClientAdapter = FixtureAdapter((_) => mealResponse({}, 401));
      await expectLater(
        service.toggleItem(100),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(storage.token, isNull);
    },
  );

  test('network failures do not produce fake empty groceries', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    addTearDown(dio.close);
    dio.httpClientAdapter = FixtureAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final service = GroceryListService(
      apiClient: ApiClient(dio: dio, tokenStorage: MemoryTokenStorage()),
    );
    await expectLater(
      service.generateWeek(DateTime(2026, 10, 3)),
      throwsA(isA<ApiException>()),
    );
  });
}
