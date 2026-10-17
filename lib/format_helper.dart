String formatHexResult(
  int intValue, {
  int bitWidth = 32,
  bool isSigned = true,
}) {
  final sanitizedBitWidth = bitWidth.clamp(1, 64);
  final significantBits = intValue == 0 ? 1 : intValue.bitLength;
  final compactWidth = significantBits <= 8
      ? 8
      : significantBits <= 16
      ? 16
      : significantBits <= 32
      ? 32
      : 64;
  final maximumDisplayWidth = sanitizedBitWidth < 8 ? 8 : sanitizedBitWidth;
  final bitWidthToUse = intValue < 0 && isSigned
      ? sanitizedBitWidth
      : compactWidth.clamp(8, maximumDisplayWidth).toInt();
  final hexDigits = (bitWidthToUse / 4).ceil();
  final hex = intValue
      .toUnsigned(bitWidthToUse)
      .toRadixString(16)
      .toUpperCase()
      .padLeft(hexDigits, '0');
  return hex
      .replaceAllMapped(RegExp(r'.{2}'), (match) => '${match.group(0)} ')
      .trim();
}

String formatBinaryResult(
  int intValue, {
  int bitWidth = 32,
  bool isSigned = true,
}) {
  final sanitizedBitWidth = bitWidth.clamp(1, 64);

  // For positive values, the declared C/C++ type is useful metadata but does
  // not need to consume the display with zeroes. Preserve conventional byte,
  // word, and dword boundaries. Negative signed values retain the full width,
  // since their leading one bits are part of the two's-complement value.
  final significantBits = intValue == 0 ? 1 : intValue.bitLength;
  final compactWidth = significantBits <= 8
      ? 8
      : significantBits <= 16
      ? 16
      : significantBits <= 32
      ? 32
      : 64;
  final maximumDisplayWidth = sanitizedBitWidth < 8 ? 8 : sanitizedBitWidth;
  final bitWidthToUse = intValue < 0 && isSigned
      ? sanitizedBitWidth
      : compactWidth.clamp(8, maximumDisplayWidth).toInt();
  final normalizedValue = intValue.toUnsigned(bitWidthToUse);

  final binary = normalizedValue
      .toRadixString(2)
      .toUpperCase()
      .padLeft(bitWidthToUse, '0');

  return binary
      .replaceAllMapped(RegExp(r'.{8}'), (match) => '${match.group(0)} ')
      .trim();
}

String formatFloatResult(double value, {int? decimalPlaces = 6}) {
  return decimalPlaces == null
      ? value.toString()
      : value.toStringAsFixed(decimalPlaces);
}

String formatHexDisplay(
  String hex, {
  int groupDigits = 2,
  bool showPrefix = false,
}) {
  final digits = hex.replaceAll(' ', '');
  if (digits.isEmpty) return '';
  final groups = <String>[];
  if (groupDigits > 0) {
    // Group from the least significant end, preserving the original bit width.
    for (var end = digits.length; end > 0; end -= groupDigits) {
      groups.insert(
        0,
        digits.substring((end - groupDigits).clamp(0, end), end),
      );
    }
  } else {
    groups.add(digits);
  }
  return '${showPrefix ? '0x' : ''}${groups.join(' ')}';
}
