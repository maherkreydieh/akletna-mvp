import '../core/presentation/quantity_label.dart' as presentation;
import 'recipe_shortage.dart';

class GroceryItem {
  final int id;
  final String name;
  final double quantity;
  final String? unit;
  final bool checked;
  final double? displayQuantity;
  final String? displayUnit;

  const GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.unit,
    required this.checked,
    this.displayQuantity,
    this.displayUnit,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num).toDouble();
    if (!quantity.isFinite || quantity < 0) {
      throw const FormatException('Invalid grocery quantity.');
    }
    final displayQuantity = (json['displayQuantity'] as num?)?.toDouble();
    final displayUnit = json['displayUnit'] as String?;
    if ((displayQuantity == null) != (displayUnit == null) ||
        (displayQuantity != null &&
            (!displayQuantity.isFinite || displayQuantity < 0))) {
      throw const FormatException('Invalid grocery display quantity.');
    }
    return GroceryItem(
      id: json['id'] as int,
      name: json['name'] as String,
      quantity: quantity,
      unit: json['unit'] as String?,
      checked: json['checked'] as bool,
      displayQuantity: displayQuantity,
      displayUnit: displayUnit,
    );
  }

  String get quantityLabel {
    final shownQuantity = displayQuantity ?? quantity;
    final amount = presentation.quantityLabel(shownQuantity);
    final measurement = (displayUnit ?? unit)?.trim() ?? '';
    return measurement.isEmpty ? amount : '$amount $measurement';
  }
}

class GroceryList {
  final List<GroceryContribution> contributions;
  final int? id;
  final DateTime? updatedAt;
  final List<GroceryItem> items;

  const GroceryList({
    this.contributions = const [],
    required this.id,
    required this.updatedAt,
    required this.items,
  });

  factory GroceryList.fromJson(Map<String, dynamic> json) => GroceryList(
    contributions: (json['contributions'] as List? ?? [])
        .map((e) => GroceryContribution.fromJson(e as Map<String, dynamic>))
        .toList(),
    id: json['id'] as int?,
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt'] as String),
    items: (json['items'] as List<dynamic>)
        .map((item) => GroceryItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
