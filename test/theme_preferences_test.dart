import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_express/theme_preferences.dart';
import 'package:pcalc_express/eink_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    themeModeNotifier.value = AppTheme.system;
    einkDeviceNotifier.value = false;
  });

  test('existing themes and e-ink survive preference reload', () async {
    for (final theme in AppTheme.values) {
      SharedPreferences.setMockInitialValues({'themeMode': theme.name});
      await loadThemeMode();
      expect(themeModeNotifier.value, theme);
      await saveThemeMode(AppTheme.eink);
      await loadThemeMode();
      expect(themeModeNotifier.value, AppTheme.eink);
      expect(themeModeNotifier.value.materialMode, ThemeMode.light);
    }
  });

  test('unknown saved theme falls back to system', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'unknown'});
    await loadThemeMode();
    expect(themeModeNotifier.value, AppTheme.system);
  });

  test('known e-ink devices default to e-ink until a theme is saved', () async {
    einkDeviceNotifier.value = true;
    SharedPreferences.setMockInitialValues({});
    await loadThemeMode();
    expect(themeModeNotifier.value, AppTheme.eink);

    SharedPreferences.setMockInitialValues({'themeMode': 'light'});
    await loadThemeMode();
    expect(themeModeNotifier.value, AppTheme.light);
  });
}
