import '../core/presentation/quantity_label.dart';

class ShortageIngredient {
  final int? ingredientId;
  final String name;
  final String status;
  final String? quantity;
  final String? unit;
  const ShortageIngredient({
    this.ingredientId,
    required this.name,
    required this.status,
    this.quantity,
    this.unit,
  });
  factory ShortageIngredient.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String;
    final quantity = json['quantity'] as String?;
    final unit = json['unit'] as String?;
    if (![
          'REQUIRED',
          'ENOUGH',
          'SHORTAGE',
          'MISSING',
          'PRESENT_QUANTITY_UNKNOWN',
          'PRESENT_INCOMPARABLE',
        ].contains(status) ||
        (quantity != null &&
            (double.tryParse(quantity) == null ||
                !double.parse(quantity).isFinite ||
                double.parse(quantity) < 0)) ||
        (['SHORTAGE', 'MISSING', 'REQUIRED'].contains(status) !=
            (quantity != null)) ||
        (quantity != null && unit == null)) {
      throw const FormatException('Invalid grocery source amount.');
    }
    return ShortageIngredient(
      ingredientId: json['ingredientId'] as int?,
      name: json['ingredientName'] as String,
      status: status,
      quantity: quantity,
      unit: unit,
    );
  }
  bool get actionable => quantity != null;
  String get amount => quantity == null
      ? ''
      : '${decimalQuantityLabel(quantity!)} ${unit ?? ''}'.trim();
  String get explanation => switch (status) {
    'PRESENT_QUANTITY_UNKNOWN' =>
      'Quantity in pantry is unknown — check before adding.',
    'PRESENT_INCOMPARABLE' =>
      'Pantry quantity uses an incompatible unit — check before adding.',
    'ENOUGH' => 'Enough in pantry. Nothing added.',
    _ => amount,
  };
}

class RecipeShortage {
  final int recipeId;
  final String recipeName;
  final int servings;
  final bool pantryEmpty;
  final String status;
  final int? contributionId;
  final List<ShortageIngredient> ingredients;
  const RecipeShortage({
    required this.recipeId,
    required this.recipeName,
    required this.servings,
    required this.pantryEmpty,
    required this.status,
    this.contributionId,
    required this.ingredients,
  });
  factory RecipeShortage.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String;
    final servings = json['servings'] as int;
    if (servings <= 0 ||
        ![
          'PREVIEW',
          'ADDED',
          'ALREADY_ADDED',
          'NOTHING_TO_ADD',
          'PANTRY_EMPTY',
        ].contains(status) ||
        (['ADDED', 'ALREADY_ADDED'].contains(status) &&
            json['contributionId'] is! int)) {
      throw const FormatException('Invalid shortage response.');
    }
    return RecipeShortage(
      recipeId: json['recipeId'] as int,
      recipeName: json['recipeName'] as String,
      servings: servings,
      pantryEmpty: json['pantryEmpty'] as bool,
      status: status,
      contributionId: json['contributionId'] as int?,
      ingredients: (json['ingredients'] as List)
          .map((e) => ShortageIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  bool get added => status == 'ADDED' || status == 'ALREADY_ADDED';
}

class GroceryContribution {
  final int id;
  final String source;
  final String name;
  final int? servings;
  final List<ShortageIngredient> ingredients;
  const GroceryContribution({
    required this.id,
    required this.source,
    required this.name,
    this.servings,
    required this.ingredients,
  });
  factory GroceryContribution.fromJson(Map<String, dynamic> json) {
    final source = json['source'] as String;
    if (!['PLANNED_MEAL', 'RECIPE_SHORTAGE'].contains(source)) {
      throw const FormatException('Invalid grocery source.');
    }
    return GroceryContribution(
      id: json['id'] as int,
      source: source,
      name: json['sourceName'] as String,
      servings: json['servings'] as int?,
      ingredients: (json['ingredients'] as List)
          .map((e) => ShortageIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
