import '../core/presentation/quantity_label.dart';
import 'recipe_evaluation.dart';

enum RecipeOrigin { user, curated }

enum RecipeVisibility { private, public }

class RecipeIngredient {
  final int id;
  final int recipeId;
  final int ingredientId;
  final String name;
  final double quantity;
  final String? unit;

  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    required this.name,
    required this.quantity,
    this.unit,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] as int,
      recipeId: json['recipeId'] as int,
      ingredientId: json['ingredientId'] as int,
      name: json['ingredientName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipeId': recipeId,
      'ingredientId': ingredientId,
      'ingredientName': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  /// Payload for the existing recipe-line POST/PUT endpoints.
  Map<String, dynamic> toRequestJson() => {
    'ingredientId': ingredientId,
    'quantity': quantity,
    'unit': unit,
  };

  /// Helper to display ingredient line (e.g., "2 cups Rice" or "Salt")
  String get displayLine {
    final parts = <String>[];
    final cleanQuantity = quantityLabel(quantity);
    parts.add(cleanQuantity);
    if (unit != null && unit!.trim().isNotEmpty) {
      parts.add(unit!.trim());
    }
    if (name.isNotEmpty) {
      parts.add(name.trim());
    }
    return parts.join(' ');
  }
}

class Recipe {
  final RecipeEvaluation? evaluation;
  final bool saved;
  final int? saveCount;
  final DateTime? savedAt;
  final RecipeOrigin origin;
  final RecipeVisibility visibility;
  final int? userId;
  final String? userName;
  final int id;
  final String name;
  final String description;
  final String instructions;
  final int cookingTime;
  final int? servings;
  final String category;
  final String? imageUrl;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    this.evaluation,
    this.saved = false,
    this.saveCount,
    this.savedAt,
    this.origin = RecipeOrigin.user,
    this.visibility = RecipeVisibility.private,
    this.userId,
    this.userName,
    required this.id,
    required this.name,
    this.description = '',
    this.instructions = '',
    this.cookingTime = 0,
    this.servings = 1,
    this.category = '',
    this.imageUrl,
    this.ingredients = const [],
  });

  factory Recipe.fromJson(
    Map<String, dynamic> json, {
    List<RecipeIngredient> ingredients = const [],
  }) {
    return Recipe(
      evaluation: json['evaluation'] == null
          ? null
          : RecipeEvaluation.fromJson(
              json['evaluation'] as Map<String, dynamic>,
            ),
      saved: json['saved'] as bool? ?? false,
      saveCount: (json['saveCount'] as num?)?.toInt(),
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? ''),
      origin: RecipeOrigin.values.byName(
        (json['origin'] as String? ?? 'USER').toLowerCase(),
      ),
      visibility: RecipeVisibility.values.byName(
        (json['visibility'] as String? ?? 'PRIVATE').toLowerCase(),
      ),
      userId: json['userId'] as int?,
      userName: json['userName'] as String?,
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      cookingTime: json['cookingTime'] as int? ?? 0,
      servings: json['servings'] as int?,
      category: json['category'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      ingredients: ingredients,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'instructions': instructions,
      'cookingTime': cookingTime,
      'servings': servings,
      'category': category,
      'origin': origin.name.toUpperCase(),
      'visibility': visibility.name.toUpperCase(),
      if (userId != null) 'userId': userId,
      if (userName != null) 'userName': userName,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }
}
