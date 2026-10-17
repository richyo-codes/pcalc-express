import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_express/result_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('format preferences round trip including automatic precision', () async {
    SharedPreferences.setMockInitialValues({});
    await loadResultPreferences();
    expect(floatPrecisionNotifier.value, null);
    expect(hexGroupDigitsNotifier.value, 2);
    expect(hexPrefixNotifier.value, false);
    await saveFloatPrecision(null);
    await saveHexGroupDigits(4);
    await saveHexPrefix(true);
    floatPrecisionNotifier.value = 6;
    hexGroupDigitsNotifier.value = 2;
    hexPrefixNotifier.value = false;
    await loadResultPreferences();
    expect(floatPrecisionNotifier.value, null);
    expect(hexGroupDigitsNotifier.value, 4);
    expect(hexPrefixNotifier.value, true);
  });
}
