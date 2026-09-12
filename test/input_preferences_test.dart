import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_express/input_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('mobile hosts suppress the system keyboard by default', () async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      await loadInputPreferences();
      expect(useSystemKeyboardNotifier.value, isFalse);
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await loadInputPreferences();
    expect(useSystemKeyboardNotifier.value, isTrue);
  });

  test('saved keyboard choice overrides the platform default', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await saveUseSystemKeyboard(true);
    useSystemKeyboardNotifier.value = false;
    await loadInputPreferences();
    expect(useSystemKeyboardNotifier.value, isTrue);

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await saveUseSystemKeyboard(false);
    useSystemKeyboardNotifier.value = true;
    await loadInputPreferences();
    expect(useSystemKeyboardNotifier.value, isFalse);
  });
}
