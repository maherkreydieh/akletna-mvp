import '../core/presentation/quantity_label.dart';

class PantryItem {
  final int id;
  final int ingredientId;
  final String ingredientName;
  // Decimal strings preserve inventory precision through edit and save.
  final String? quantity;
  final String? unit;
  final String? displayQuantity;
  final String? displayUnit;
  final DateTime updatedAt;
  const PantryItem({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    this.quantity,
    this.unit,
    this.displayQuantity,
    this.displayUnit,
    required this.updatedAt,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    final quantity = json['quantity'] as String?;
    final unit = json['unit'] as String?;
    final displayQuantity = json['displayQuantity'] as String?;
    final displayUnit = json['displayUnit'] as String?;
    bool valid(String? value) =>
        value != null &&
        RegExp(r'^\d+(\.\d+)?$').hasMatch(value) &&
        RegExp(r'[1-9]').hasMatch(value);
    if ((quantity == null) != (unit == null) ||
        (quantity == null) != (displayQuantity == null) ||
        (quantity == null) != (displayUnit == null) ||
        (quantity != null &&
            (!valid(quantity) ||
                !valid(displayQuantity) ||
                unit!.trim().isEmpty ||
                displayUnit!.trim().isEmpty))) {
      throw const FormatException('Invalid pantry amount.');
    }
    return PantryItem(
      id: json['id'] as int,
      ingredientId: json['ingredientId'] as int,
      ingredientName: json['ingredientName'] as String,
      quantity: quantity,
      unit: unit,
      displayQuantity: displayQuantity,
      displayUnit: displayUnit,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
  String get quantityLabel => quantity == null
      ? 'In pantry'
      : '${decimalQuantityLabel(displayQuantity!)} $displayUnit';
}
