class Ingredient {
  final int id;
  final String name;
  final String unit;
  const Ingredient({required this.id, required this.name, required this.unit});
  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    id: json['id'] as int,
    name: json['name'] as String,
    unit: json['unit'] as String? ?? '',
  );
}
