import 'recipe.dart';
import 'pantry_matches.dart';

class HomeRecommendations {
  final bool preferencesConfigured;
  final List<String> limitations;
  final Recommendations selection;
  HomeRecommendations.fromJson(Map<String, dynamic> json)
    : preferencesConfigured = json['preferencesConfigured'] as bool,
      limitations = (json['limitations'] as List).cast<String>(),
      selection = Recommendations.fromJson(
        json['selection'] as Map<String, dynamic>,
      );
}

class RecommendationReason {
  final String code, message;
  final double points;
  RecommendationReason.fromJson(Map<String, dynamic> json)
    : code = json['code'] as String,
      message = json['message'] as String,
      points = (json['points'] as num).toDouble() {
    if (!points.isFinite) throw const FormatException('Invalid reason points');
  }
}

class Recommendation {
  final int rank;
  final Recipe recipe;
  final double score;
  final PantryMatchStatus? pantryStatus;
  final double? pantryPercentage;
  final List<RecommendationReason> reasons;
  Recommendation.fromJson(Map<String, dynamic> json)
    : rank = json['rank'] as int,
      recipe = Recipe.fromJson(json['recipe'] as Map<String, dynamic>),
      score = (json['score'] as num).toDouble(),
      pantryStatus = json['pantryStatus'] == null
          ? null
          : PantryMatchStatus.parse(json['pantryStatus'] as String),
      pantryPercentage = (json['pantryPercentage'] as num?)?.toDouble(),
      reasons = (json['reasons'] as List)
          .map((v) => RecommendationReason.fromJson(v as Map<String, dynamic>))
          .toList() {
    if (rank <= 0 ||
        !score.isFinite ||
        score < 0 ||
        score > 100 ||
        reasons.isEmpty ||
        recipe.evaluation == null ||
        (pantryStatus == null) != (pantryPercentage == null) ||
        (pantryPercentage != null &&
            (!pantryPercentage!.isFinite ||
                pantryPercentage! < 0 ||
                pantryPercentage! > 100))) {
      throw const FormatException('Invalid recommendation');
    }
  }
}

class Recommendations {
  final bool pantryEmpty;
  final int readableRecipeCount, excludedRecipeCount;
  final List<Recommendation> items;
  Recommendations.fromJson(Map<String, dynamic> json)
    : pantryEmpty = json['pantryEmpty'] as bool,
      readableRecipeCount = json['readableRecipeCount'] as int,
      excludedRecipeCount = json['excludedRecipeCount'] as int,
      items = (json['recommendations'] as List)
          .map((v) => Recommendation.fromJson(v as Map<String, dynamic>))
          .toList() {
    if (readableRecipeCount < 0 ||
        excludedRecipeCount < 0 ||
        excludedRecipeCount > readableRecipeCount ||
        (pantryEmpty && items.any((r) => r.pantryPercentage != null))) {
      throw const FormatException('Invalid recommendation collection');
    }
  }
}
