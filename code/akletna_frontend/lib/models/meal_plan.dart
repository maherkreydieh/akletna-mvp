enum MealType {
  breakfast('BREAKFAST', 'Breakfast'),
  lunch('LUNCH', 'Lunch'),
  dinner('DINNER', 'Dinner'),
  snack('SNACK', 'Snack');

  const MealType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MealType fromJson(Object? value) => values.firstWhere(
    (type) => type.apiValue == value,
    orElse: () => throw const FormatException('Invalid meal type.'),
  );
}

// Backend dates are LocalDate values, not UTC instants.
String mealPlanDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime mealPlanDay(DateTime date, [int offset = 0]) =>
    DateTime(date.year, date.month, date.day + offset);

DateTime mealPlanWeekStart(DateTime date) =>
    mealPlanDay(date, DateTime.monday - date.weekday);

/// A planned entry references a source recipe; it does not edit that recipe.
class MealPlan {
  final String snapshotState;
  final int? recipeBaseServings;
  final String? recipeImageUrl;
  final int? plannedServings;
  final int id;
  final int recipeId;
  final String recipeName;
  final String? recipeCategory;
  final DateTime date;
  final MealType mealType;
  final DateTime createdAt;

  const MealPlan({
    this.snapshotState = 'READY',
    this.recipeBaseServings,
    this.recipeImageUrl,
    this.plannedServings,
    required this.id,
    required this.recipeId,
    required this.recipeName,
    this.recipeCategory,
    required this.date,
    required this.mealType,
    required this.createdAt,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final state = json['snapshotState'] ?? 'READY';
    final base = json['recipeBaseServings'];
    if (!['READY', 'UNRESOLVED'].contains(state) ||
        (base != null && (base is! int || base <= 0))) {
      throw const FormatException('Invalid planned recipe data.');
    }
    final plannedServings = json['plannedServings'];
    if (plannedServings != null &&
        (plannedServings is! int || plannedServings <= 0)) {
      throw const FormatException('Invalid planned servings.');
    }
    final rawDate = json['date'];
    if (rawDate is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate)) {
      throw const FormatException('Invalid planned date.');
    }
    final date = DateTime.parse(rawDate);
    if (mealPlanDate(date) != rawDate) {
      throw const FormatException('Invalid planned date.');
    }
    return MealPlan(
      snapshotState: state as String,
      recipeBaseServings: base as int?,
      recipeImageUrl: json['recipeImageUrl'] as String?,
      plannedServings: plannedServings as int?,
      id: json['id'] as int,
      recipeId: json['recipeId'] as int,
      recipeName: json['recipeName'] as String,
      recipeCategory: json['recipeCategory'] as String?,
      date: date,
      mealType: MealType.fromJson(json['mealType']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
