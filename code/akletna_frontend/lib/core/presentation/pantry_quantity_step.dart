/// Add one canonical inventory unit without passing decimal strings through
/// floating point. Null means the result violates the existing pantry contract.
String? pantryQuantityStep(String? quantity, int delta) {
  if (quantity == null ||
      !RegExp(r'^\d{1,15}(\.\d{1,12})?$').hasMatch(quantity)) {
    return null;
  }
  final parts = quantity.split('.');
  final digits = parts.length == 2 ? parts[1].length : 0;
  final scale = BigInt.from(10).pow(digits);
  final current = BigInt.parse(parts.join());
  final result = current + BigInt.from(delta) * scale;
  if (result <= BigInt.zero) return null;
  final whole = (result ~/ scale).toString();
  if (whole.length > 15) return null;
  if (digits == 0) return whole;
  final fraction = (result % scale)
      .toString()
      .padLeft(digits, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole : '$whole.$fraction';
}
