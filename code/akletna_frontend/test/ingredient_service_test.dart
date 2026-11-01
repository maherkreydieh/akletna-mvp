import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/services/ingredient_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipe_service_test.dart' show FixtureApiClient;

void main() {
  test('shared catalog and missing ingredient use existing endpoints and fixed unit', () async {
    final api = FixtureApiClient({
      '/api/ingredients': [
        {'id': 7, 'name': 'Lentils', 'unit': 'cup'},
      ],
    });
    final service = IngredientService(apiClient: api);
    final items = await service.getIngredients();
    expect(items.single.id, 7);
    expect(items.single.unit, 'cup');
    api.responses['/api/ingredients'] = {'id': 8, 'name': 'Rice', 'unit': 'g'};
    final created = await service.createIngredient(' Rice ', ' g ');
    expect(created.id, 8);
    expect(api.posted, {'name': 'Rice', 'unit': 'g'});
    expect(api.requests, ['/api/ingredients', '/api/ingredients']);
  });
  test(
    'duplicate and malformed ingredient responses surface failures',
    () async {
      final api = FixtureApiClient({
        '/api/ingredients': ApiException(
          message: 'Already exists',
          statusCode: 400,
        ),
      });
      await expectLater(
        IngredientService(apiClient: api).createIngredient('Rice', 'g'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
      );
      api.responses['/api/ingredients'] = {'unexpected': []};
      await expectLater(
        IngredientService(apiClient: api).getIngredients(),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
