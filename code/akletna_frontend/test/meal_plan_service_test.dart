import 'dart:convert';

import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/models/meal_plan.dart';
import 'package:akletna_frontend/services/meal_plan_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_client_test.dart' show FixtureAdapter;
import 'auth_service_test.dart' show MemoryTokenStorage;

const mealJson = {
  'id': 31,
  'recipeId': 11,
  'plannedServings': 4,
  'recipeName': 'Lentil soup',
  'recipeCategory': null,
  'date': '2026-09-28',
  'mealType': 'LUNCH',
  'createdAt': '2026-10-03T12:00:00',
};

ResponseBody mealResponse(Object? data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  test(
    'snapshot fields preserve server display and reject invalid snapshot state',
    () {
      final meal = MealPlan.fromJson({
        ...mealJson,
        'recipeName': 'Original rice',
        'snapshotState': 'READY',
        'recipeBaseServings': 4,
        'recipeImageUrl': 'https://example.test/rice.png',
      });
      expect(meal.recipeName, 'Original rice');
      expect(meal.recipeBaseServings, 4);
      expect(meal.recipeImageUrl, 'https://example.test/rice.png');
      expect(meal.snapshotState, 'READY');
      expect(
        MealPlan.fromJson({
          ...mealJson,
          'snapshotState': 'UNRESOLVED',
          'recipeBaseServings': null,
        }).snapshotState,
        'UNRESOLVED',
      );
      expect(
        () => MealPlan.fromJson({...mealJson, 'snapshotState': 'FORGED'}),
        throwsFormatException,
      );
      for (final base in [0, -1, 2.5, '4']) {
        expect(
          () => MealPlan.fromJson({...mealJson, 'recipeBaseServings': base}),
          throwsFormatException,
        );
      }
    },
  );
  test('planned-serving response preserves unresolved legacy values and rejects malformed counts', () {
    expect(MealPlan.fromJson(mealJson).plannedServings, 4);
    expect(
      MealPlan.fromJson({...mealJson, 'plannedServings': null}).plannedServings,
      isNull,
    );
    for (final value in [0, -1, 2.5, '4']) {
      expect(
        () => MealPlan.fromJson({...mealJson, 'plannedServings': value}),
        throwsFormatException,
      );
    }
  });
  test('serving update uses existing PUT contract without changing source/date/slot', () async {
    RequestOptions? request;
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    addTearDown(dio.close);
    dio.httpClientAdapter = FixtureAdapter((options) {
      request = options;
      return mealResponse({...mealJson, 'plannedServings': 6});
    });
    final service = MealPlanService(
      apiClient: ApiClient(
        dio: dio,
        tokenStorage: MemoryTokenStorage('test-session'),
      ),
    );
    final updated = await service.updateServings(
      MealPlan.fromJson(mealJson),
      6,
    );
    expect(updated.plannedServings, 6);
    expect(request!.method, 'PUT');
    expect(request!.path, '/api/meal-plans/31');
    expect(request!.data, {
      'recipeId': 11,
      'date': '2026-09-28',
      'mealType': 'LUNCH',
      'plannedServings': 6,
    });
    expect(request!.headers['Authorization'], 'Bearer test-session');
  });
  test('week boundaries use calendar dates across month and year changes', () {
    expect(
      mealPlanDate(mealPlanWeekStart(DateTime(2026, 10, 4, 23))),
      '2026-09-28',
    );
    expect(mealPlanDate(mealPlanWeekStart(DateTime(2027, 1, 1))), '2026-12-28');
    expect(mealPlanDate(mealPlanDay(DateTime(2026, 12, 28), 6)), '2027-01-03');
    expect(
      mealPlanDate(mealPlanWeekStart(DateTime(2026, 10, 5))),
      '2026-10-05',
    );
  });

  test('meal response parses nullable category and all four real slots', () {
    for (final type in MealType.values) {
      final meal = MealPlan.fromJson({...mealJson, 'mealType': type.apiValue});
      expect(meal.mealType, type);
      expect(meal.recipeCategory, isNull);
      expect(meal.recipeId, 11);
    }
    for (final date in ['2026-02-30', '2026-10-03T00:00:00Z', null]) {
      expect(
        () => MealPlan.fromJson({...mealJson, 'date': date}),
        throwsFormatException,
      );
    }
    expect(
      () => MealPlan.fromJson({...mealJson, 'mealType': 'BRUNCH'}),
      throwsFormatException,
    );
  });

  test(
    'weekly GET, POST and DELETE use real payloads and the existing JWT client',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.httpClientAdapter = FixtureAdapter((options) {
        requests.add(options);
        if (options.method == 'GET') return mealResponse([mealJson]);
        if (options.method == 'POST') return mealResponse(mealJson, 201);
        return ResponseBody.fromString('', 204);
      });
      addTearDown(dio.close);
      final service = MealPlanService(
        apiClient: ApiClient(
          dio: dio,
          tokenStorage: MemoryTokenStorage('test-session'),
        ),
      );
      expect(
        (await service.getWeek(DateTime(2026, 10, 3))).single.recipeName,
        'Lentil soup',
      );
      expect(requests.first.queryParameters, {
        'startDate': '2026-09-28',
        'endDate': '2026-10-04',
      });
      final meal = await service.addMeal(
        plannedServings: 4,
        recipeId: 11,
        date: DateTime(2026, 9, 28, 16),
        mealType: MealType.lunch,
      );
      await service.removeMeal(meal.id);
      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'GET /api/meal-plans',
        'POST /api/meal-plans',
        'DELETE /api/meal-plans/31',
      ]);
      expect(requests[1].data, {
        'plannedServings': 4,
        'recipeId': 11,
        'date': '2026-09-28',
        'mealType': 'LUNCH',
      });
      expect(
        requests.every(
          (request) =>
              request.headers['Authorization'] == 'Bearer test-session',
        ),
        isTrue,
      );
    },
  );

  test(
    'empty plans are valid; malformed responses are readable errors',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      addTearDown(dio.close);
      final service = MealPlanService(
        apiClient: ApiClient(dio: dio, tokenStorage: MemoryTokenStorage()),
      );
      dio.httpClientAdapter = FixtureAdapter((_) => mealResponse([]));
      expect(await service.getWeek(DateTime(2026, 10, 3)), isEmpty);
      for (final data in [
        null,
        {'meals': []},
        [
          {...mealJson, 'mealType': 'UNKNOWN'},
        ],
      ]) {
        dio.httpClientAdapter = FixtureAdapter((_) => mealResponse(data));
        await expectLater(
          service.getWeek(DateTime(2026, 10, 3)),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              'Could not read your meal plan.',
            ),
          ),
        );
      }
      dio.httpClientAdapter = FixtureAdapter(
        (_) => mealResponse({'id': 31}, 201),
      );
      await expectLater(
        service.addMeal(
          plannedServings: 4,
          recipeId: 11,
          date: DateTime(2026, 10, 3),
          mealType: MealType.dinner,
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'authorization, conflict and server errors preserve HTTP status',
    () async {
      final storage = MemoryTokenStorage('test-session');
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      addTearDown(dio.close);
      final service = MealPlanService(
        apiClient: ApiClient(dio: dio, tokenStorage: storage),
      );
      for (final status in [400, 403, 404, 500, 401]) {
        dio.httpClientAdapter = FixtureAdapter(
          (_) => mealResponse({'message': 'Request rejected'}, status),
        );
        await expectLater(
          service.getWeek(DateTime(2026, 10, 3)),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'status',
              status,
            ),
          ),
        );
      }
      expect(storage.token, isNull);
    },
  );

  test(
    'network failures remain ApiException rather than an empty plan',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      addTearDown(dio.close);
      dio.httpClientAdapter = FixtureAdapter(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      final service = MealPlanService(
        apiClient: ApiClient(dio: dio, tokenStorage: MemoryTokenStorage()),
      );
      await expectLater(
        service.getWeek(DateTime(2026, 10, 3)),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
