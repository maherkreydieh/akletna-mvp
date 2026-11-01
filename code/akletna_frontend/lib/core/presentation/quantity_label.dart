/// Presentation only. Never use rounded values in API requests or calculations.
String quantityLabel(num value, {int decimals = 2}) {
  if (decimals == 0) return value.toStringAsFixed(0);
  if (value > 0 && value < 0.01 && decimals == 2) return '<0.01';
  return value.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Display decimal strings without converting their exact values to doubles.
/// Never use the rounded label in requests or calculations.
String decimalQuantityLabel(String value) {
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
    return quantityLabel(num.parse(value));
  }
  final parts = value.split('.');
  final fraction = parts.length == 1 ? '' : parts[1];
  final padded = fraction.padRight(3, '0');
  final whole = BigInt.parse(parts[0]);
  if (whole == BigInt.zero &&
      padded.substring(0, 2) == '00' &&
      RegExp(r'[1-9]').hasMatch(fraction)) {
    return '<0.01';
  }
  var cents = whole * BigInt.from(100) + BigInt.parse(padded.substring(0, 2));
  if (int.parse(padded[2]) >= 5) cents += BigInt.one;
  final decimals = (cents % BigInt.from(100))
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  final integer = cents ~/ BigInt.from(100);
  return decimals.isEmpty ? '$integer' : '$integer.$decimals';
}
