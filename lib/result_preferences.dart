import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Null means automatic precision.
final floatPrecisionNotifier = ValueNotifier<int?>(null);
const floatPrecisionOptions = <int?>[null, 0, 2, 4, 6, 8, 12];
final hexGroupDigitsNotifier = ValueNotifier<int>(2);
final hexPrefixNotifier = ValueNotifier<bool>(false);

Future<void> loadResultPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt('floatPrecision') ?? -1;
  final precision = saved == -1 ? null : saved;
  floatPrecisionNotifier.value = floatPrecisionOptions.contains(precision)
      ? precision
      : null;
  final grouping = prefs.getInt('hexGroupDigits') ?? 2;
  hexGroupDigitsNotifier.value = [0, 2, 4, 8].contains(grouping) ? grouping : 2;
  hexPrefixNotifier.value = prefs.getBool('hexPrefix') ?? false;
}

Future<void> saveHexGroupDigits(int digits) async {
  if (![0, 2, 4, 8].contains(digits)) return;
  hexGroupDigitsNotifier.value = digits;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('hexGroupDigits', digits);
}

Future<void> saveHexPrefix(bool enabled) async {
  hexPrefixNotifier.value = enabled;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('hexPrefix', enabled);
}

Future<void> saveFloatPrecision(int? precision) async {
  if (!floatPrecisionOptions.contains(precision)) return;
  floatPrecisionNotifier.value = precision;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('floatPrecision', precision ?? -1);
}
