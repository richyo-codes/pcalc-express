String formatHexResult(int intValue) {
  // Convert to 8-character hex string (32 bits), padded with zeros
  final hex = intValue
      .toUnsigned(32)
      .toRadixString(16)
      .toUpperCase()
      .padLeft(8, '0');
  // Insert a space every 2 characters (every byte)
  final spacedHex = hex.replaceAllMapped(
    RegExp(r'.{2}'),
    (match) => '${match.group(0)} ',
  );
  return spacedHex.trim();
}

String formatBinaryResult(int intValue) {
  final hexResult = intValue.toRadixString(2).toUpperCase().padLeft(32, '0');

  return hexResult;
}

String formatFloatResult(double value) {
  // Format float with 6 decimal places
  return value.toStringAsFixed(6);
}
