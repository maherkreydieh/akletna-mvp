import '../core/presentation/quantity_label.dart';
import 'recipe.dart';

enum IngredientMatchStatus {
  enough,
  shortage,
  presentQuantityUnknown,
  presentIncomparable,
  missing;

  String get label => switch (this) {
    enough => 'Fully available',
    shortage => 'Partially available',
    presentQuantityUnknown => 'Quantity unknown',
    presentIncomparable => 'Units cannot be compared',
    missing => 'Missing',
  };

  static IngredientMatchStatus parse(String value) => switch (value) {
    'ENOUGH' => enough,
    'SHORTAGE' => shortage,
    'PRESENT_QUANTITY_UNKNOWN' => presentQuantityUnknown,
    'PRESENT_INCOMPARABLE' => presentIncomparable,
    'MISSING' => missing,
    _ => throw const FormatException('Invalid ingredient match status'),
  };
}

enum PantryMatchStatus {
  readyToCook,
  likelyReady,
  almostThere,
  moreShoppingNeeded;

  String get label => switch (this) {
    readyToCook => 'Ready to Cook',
    likelyReady => 'Likely Ready',
    almostThere => 'Almost There',
    moreShoppingNeeded => 'More Shopping Needed',
  };
  static PantryMatchStatus parse(String value) => switch (value) {
    'READY_TO_COOK' => readyToCook,
    'LIKELY_READY' => likelyReady,
    'ALMOST_THERE' => almostThere,
    'MORE_SHOPPING_NEEDED' => moreShoppingNeeded,
    _ => throw const FormatException('Invalid recipe match status'),
  };
}

class MatchAmount {
  final String quantity;
  final String unit;
  MatchAmount.fromJson(Map<String, dynamic> json)
    : quantity = json['quantity'] as String,
      unit = json['unit'] as String {
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(quantity) || unit.trim().isEmpty) {
      throw const FormatException('Invalid match amount');
    }
  }
  String get label => '${decimalQuantityLabel(quantity)} $unit';
}

class IngredientMatch {
  final int ingredientId;
  final String name;
  final IngredientMatchStatus status;
  final MatchAmount required;
  final MatchAmount? available;
  final MatchAmount? shortage;
  final bool assumedStaple;
  IngredientMatch.fromJson(Map<String, dynamic> json)
    : assumedStaple = json['assumedStaple'] == true,
      ingredientId = json['ingredientId'] as int,
      name = json['ingredientName'] as String,
      status = IngredientMatchStatus.parse(json['status'] as String),
      required = MatchAmount.fromJson(json['required'] as Map<String, dynamic>),
      available = json['available'] == null
          ? null
          : MatchAmount.fromJson(json['available'] as Map<String, dynamic>),
      shortage = json['shortage'] == null
          ? null
          : MatchAmount.fromJson(json['shortage'] as Map<String, dynamic>);
  String get explanation => switch (status) {
    IngredientMatchStatus.enough =>
      assumedStaple
          ? 'Kitchen staple: assumed available. Need ${required.label}'
          : 'Enough — need ${required.label}, have ${available!.label}',
    IngredientMatchStatus.shortage =>
      'Need ${required.label} — have ${available!.label} — missing ${shortage!.label}',
    IngredientMatchStatus.presentQuantityUnknown =>
      'In pantry — quantity unknown. Need ${required.label}',
    IngredientMatchStatus.presentIncomparable =>
      '${available == null ? 'Amount unavailable' : 'Have ${available!.label}'}; recipe requires ${required.label}. Amount cannot be compared yet.',
    IngredientMatchStatus.missing => 'Missing — need ${required.label}',
  };
}

class PantryRecipeMatch {
  final Recipe recipe;
  final PantryMatchStatus status;
  final double score;
  final Map<String, int> counts;
  final List<IngredientMatch> ingredients;
  PantryRecipeMatch.fromJson(Map<String, dynamic> json)
    : recipe = Recipe.fromJson(json),
      status = PantryMatchStatus.parse(json['status'] as String),
      score = (json['score'] as num).toDouble(),
      counts = (json['counts'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as int),
      ),
      ingredients = (json['ingredients'] as List)
          .map(
            (value) => IngredientMatch.fromJson(value as Map<String, dynamic>),
          )
          .toList() {
    if (!score.isFinite ||
        score < 0 ||
        score > 100 ||
        ingredients.isEmpty ||
        [
          'enough',
          'shortage',
          'unknown',
          'incomparable',
          'missing',
        ].any((key) => !counts.containsKey(key))) {
      throw const FormatException('Invalid pantry match');
    }
    for (final item in ingredients) {
      if (item.assumedStaple && item.status != IngredientMatchStatus.enough) {
        throw const FormatException('Invalid staple assumption');
      }
      if ((item.status == IngredientMatchStatus.enough ||
                  item.status == IngredientMatchStatus.shortage) &&
              item.available == null &&
              !item.assumedStaple ||
          item.status == IngredientMatchStatus.shortage &&
              item.shortage == null) {
        throw const FormatException('Missing comparable amount');
      }
    }
  }
  String get percentage => '${score.toStringAsFixed(2)}% pantry match';
  String get summary {
    final problems = counts['shortage']! + counts['missing']!;
    final uncertain = counts['unknown']! + counts['incomparable']!;
    if (problems > 0) {
      return '$problems ingredient requirement${problems == 1 ? '' : 's'} missing or short${uncertain > 0 ? '; $uncertain uncertain' : ''}';
    }
    if (ingredients.any((item) => item.assumedStaple) && uncertain == 0) {
      return 'Requirements covered, including assumed kitchen staples';
    }
    return uncertain > 0
        ? '$uncertain ingredient amount${uncertain == 1 ? '' : 's'} to check'
        : 'All ingredient quantities confirmed';
  }
}

class PantryMatches {
  final bool pantryEmpty;
  final int readableRecipeCount;
  final int excludedRecipeCount;
  final List<PantryRecipeMatch> matches;
  PantryMatches.fromJson(Map<String, dynamic> json)
    : pantryEmpty = json['pantryEmpty'] as bool,
      readableRecipeCount = json['readableRecipeCount'] as int,
      excludedRecipeCount = json['excludedRecipeCount'] as int,
      matches = (json['matches'] as List)
          .map(
            (value) =>
                PantryRecipeMatch.fromJson(value as Map<String, dynamic>),
          )
          .toList();
}
