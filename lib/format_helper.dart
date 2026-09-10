String formatHexResult(int intValue, {int bitWidth = 32}) {
  final normalizedBitWidth = bitWidth <= 0 ? 32 : bitWidth;
  final hexDigits = (normalizedBitWidth / 4).ceil();
  final hex = intValue
      .toUnsigned(normalizedBitWidth)
      .toRadixString(16)
      .toUpperCase()
      .padLeft(hexDigits, '0');
  return hex
      .replaceAllMapped(RegExp(r'.{2}'), (match) => '${match.group(0)} ')
      .trim();
}

String formatBinaryResult(int intValue, {int bitWidth = 32}) {
  final sanitizedBitWidth = bitWidth <= 0 ? 32 : bitWidth;
  final normalizedValue = intValue.toUnsigned(sanitizedBitWidth);
  final bitWidthToUse = sanitizedBitWidth <= 8
      ? 8
      : sanitizedBitWidth <= 16
      ? 16
      : sanitizedBitWidth <= 32
      ? 32
      : 64;

  final binary = normalizedValue
      .toRadixString(2)
      .toUpperCase()
      .padLeft(bitWidthToUse, '0');

  return binary
      .replaceAllMapped(RegExp(r'.{8}'), (match) => '${match.group(0)} ')
      .trim();
}

String formatFloatResult(double value) {
  // Format float with 6 decimal places
  return value.toStringAsFixed(6);
}
