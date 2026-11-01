import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/services/recipe_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const metadata = {
  'id': 11,
  'name': 'Lentil soup',
  'instructions': 'Cook the lentils.',
  'cookingTime': 30,
  'servings': 4,
};
const ingredientLine = {
  'id': 21,
  'recipeId': 11,
  'ingredientId': 7,
  'ingredientName': 'Lentils',
  'unit': 'cup',
  'quantity': 1.5,
};

class FixtureApiClient extends ApiClient {
  final Map<String, dynamic> responses;
  final requests = <String>[];
  final mutations = <String>[];
  Map<String, dynamic>? posted;
  FixtureApiClient(this.responses);

  @override
  Future<Response<dynamic>> put(String path, {dynamic data}) async {
    mutations.add('PUT $path');
    posted = data as Map<String, dynamic>;
    final response = responses[path];
    if (response is Exception) {
      throw response;
    }
    return Response(
      data: response,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<dynamic>> delete(String path) async {
    mutations.add('DELETE $path');
    final response = responses[path];
    if (response is Exception) {
      throw response;
    }
    return Response(
      statusCode: 204,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {dynamic data}) async {
    requests.add(path);
    posted = data as Map<String, dynamic>;
    final response = responses[path];
    if (response is Exception) {
      throw response;
    }
    return Response(
      data: response,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add(path);
    final data = responses[path];
    if (data is Exception) throw data;
    return Response(
      data: data,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  test(
    'My Recipes uses authenticated mine route without a supplied owner ID',
    () async {
      final api = FixtureApiClient({
        '/api/recipes/mine': [
          {...metadata, 'origin': 'USER', 'visibility': 'PRIVATE', 'userId': 1},
        ],
      });
      final recipes = await RecipeService(apiClient: api).getMyRecipes();
      expect(api.requests, ['/api/recipes/mine']);
      expect(recipes.single.userId, 1);
      api.responses['/api/recipes/mine'] = {'unexpected': []};
      await expectLater(
        RecipeService(apiClient: api).getMyRecipes(),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test('edit uses existing PUT identity and submits complete ingredient replacement', () async {
    final api = FixtureApiClient({
      '/api/recipes/11': {
        ...metadata,
        'name': 'Edited soup',
        'visibility': 'PUBLIC',
        'origin': 'USER',
      },
    });
    final payload = {
      'name': 'Edited soup',
      'instructions': 'Cook',
      'servings': 2,
      'visibility': 'PUBLIC',
      'ingredients': [
        {'ingredientId': 7, 'quantity': 3},
      ],
    };
    final recipe = await RecipeService(apiClient: api)
        .updateRecipe(11, payload);
    expect(api.mutations, ['PUT /api/recipes/11']);
    expect(api.posted, payload);
    expect(recipe.id, 11);
    expect(recipe.name, 'Edited soup');
    await RecipeService(apiClient: api).deleteRecipe(11);
    expect(api.mutations.last, 'DELETE /api/recipes/11');
  });
  test(
    'edit and delete preserve validation, authorization and reference failures',
    () async {
      for (final status in [400, 401, 403, 500]) {
        final api = FixtureApiClient({
          '/api/recipes/11': ApiException(
            message: 'Backend reason',
            statusCode: status,
          ),
        });
        await expectLater(
          RecipeService(apiClient: api).updateRecipe(11, {}),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', status),
          ),
        );
        await expectLater(
          RecipeService(apiClient: api).deleteRecipe(11),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', status),
          ),
        );
      }
    },
  );
  test('creation posts atomic ingredient contract and parses origin/visibility/creator', () async {
    final api = FixtureApiClient({
      '/api/recipes': {
        ...metadata,
        'origin': 'USER',
        'visibility': 'PUBLIC',
        'userId': 1,
        'userName': 'Owner',
      },
    });
    final request = {
      'name': 'Soup',
      'instructions': 'Cook',
      'servings': 2,
      'visibility': 'PUBLIC',
      'ingredients': [
        {'ingredientId': 7, 'quantity': 1.5},
      ],
    };
    final recipe = await RecipeService(apiClient: api).createRecipe(request);
    expect(api.requests, ['/api/recipes']);
    expect(api.posted, request);
    expect(recipe.origin, RecipeOrigin.user);
    expect(recipe.visibility, RecipeVisibility.public);
    expect(recipe.userId, 1);
    expect(recipe.userName, 'Owner');
  });
  test('creation preserves authenticated/backend failures without fabricating a recipe', () async {
    for (final status in [400, 401, 500]) {
      final api = FixtureApiClient({
        '/api/recipes': ApiException(message: 'Failed', statusCode: status),
      });
      await expectLater(
        RecipeService(apiClient: api).createRecipe({'name': 'Soup'}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', status),
        ),
      );
      expect(api.requests, ['/api/recipes']);
    }
  });
  test(
    'recipe details compose metadata with the actual ingredient endpoint',
    () async {
      final api = FixtureApiClient({
        '/api/recipes/11': metadata,
        '/api/recipes/11/ingredients': [ingredientLine],
      });
      final recipe = await RecipeService(apiClient: api).getRecipeById(11);
      expect(api.requests, ['/api/recipes/11', '/api/recipes/11/ingredients']);
      expect(recipe.name, 'Lentil soup');
      expect(recipe.ingredients.single.displayLine, '1.5 cup Lentils');
      expect(recipe.ingredients.single.ingredientId, 7);
      expect(recipe.ingredients.single.toJson(), ingredientLine);
      expect(recipe.ingredients.single.toRequestJson(), {
        'ingredientId': 7,
        'quantity': 1.5,
        'unit': 'cup',
      });
    },
  );

  test(
    'integer quantities parse and empty ingredient lists stay empty',
    () async {
      expect(
        RecipeIngredient.fromJson({...ingredientLine, 'quantity': 2})
            .displayLine,
        '2 cup Lentils',
      );
      final api = FixtureApiClient({
        '/api/recipes/11': metadata,
        '/api/recipes/11/ingredients': [],
      });
      expect(
        (await RecipeService(apiClient: api).getRecipeById(11)).ingredients,
        isEmpty,
      );
    },
  );

  test(
    'ownership failures are preserved and do not request recipe lines',
    () async {
      final api = FixtureApiClient({
        '/api/recipes/11': ApiException(
          message: 'Access denied.',
          statusCode: 403,
        ),
      });
      await expectLater(
        RecipeService(apiClient: api).getRecipeById(11),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
      expect(api.requests, ['/api/recipes/11']);
    },
  );

  test(
    'ingredient errors are surfaced rather than reported as an empty recipe',
    () async {
      final api = FixtureApiClient({
        '/api/recipes/11': metadata,
        '/api/recipes/11/ingredients': ApiException(
          message: 'Session expired.',
          statusCode: 401,
        ),
      });
      await expectLater(
        RecipeService(apiClient: api).getRecipeById(11),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    },
  );

  test('malformed catalog JSON is an error, not a false empty state', () async {
    final api = FixtureApiClient({
      '/api/recipes': {'unexpected': []},
    });
    await expectLater(
      RecipeService(apiClient: api).getRecipes(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Could not read the recipe response.',
        ),
      ),
    );
  });
}
