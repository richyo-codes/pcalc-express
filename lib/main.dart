import 'package:expressions/expressions.dart';
import 'package:flutter/material.dart';
import 'package:pcalc_express/app_brand.dart';
import 'package:pcalc_express/backend_preferences.dart';
import 'package:pcalc_express/calculator.dart';
import 'package:pcalc_express/eink_device.dart';
import 'package:pcalc_express/theme_preferences.dart';
import 'package:pcalc_express/input_preferences.dart';
import 'package:pcalc_express/result_preferences.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadInputPreferences();
  await loadResultPreferences();
  await detectEinkDevice();
  final backendPreference = await loadBackendPreference();
  final backendDebugLoggingEnabled = await loadBackendDebugLoggingEnabled();
  final clangLanguage = await loadClangLanguage();
  setBackendPreference(backendPreference);
  setBackendDebugLoggingEnabled(backendDebugLoggingEnabled);
  setClangLanguage(clangLanguage);
  try {
    await initializeTinyExpr();
  } catch (_) {
    setBackendPreference(null);
    await saveBackendPreference(null);
    await initializeTinyExpr();
  }
  await loadThemeMode(); // <-- Load theme mode before runApp
  final screenshotTheme = Uri.base.queryParameters['theme'];
  if (screenshotTheme == 'light') {
    themeModeNotifier.value = AppTheme.light;
  } else if (screenshotTheme == 'dark') {
    themeModeNotifier.value = AppTheme.dark;
  } else if (screenshotTheme == 'eink') {
    themeModeNotifier.value = AppTheme.eink;
  }

  // Desktop runners own initial sizing, visibility and frameless decorations.
  // WindowDragController handles subsequent native window operations.

  runApp(const PCalcApp());
}

class PCalcApp extends StatelessWidget {
  const PCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: appTitle,
        theme: mode == AppTheme.eink ? buildEinkTheme() : buildAppLightTheme(),
        darkTheme: buildAppDarkTheme(),
        themeMode: mode.materialMode,
        themeAnimationDuration: mode == AppTheme.eink
            ? Duration.zero
            : kThemeAnimationDuration,
        home: CalculatorScreen(themeColor: appThemeColor),
        scrollBehavior: AppScrollBehavior(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

bool isValidExpression(String input) {
  try {
    // Parse the expression
    Expression exp = Expression.parse(input);

    // Check if it only contains numbers, basic operators, and defined variables
    Set<String> allowedVars = {"x", "y"};
    List<String> allowedOperators = ["+", "-", "*", "/", "%"];

    bool isValid = exp
        .toString()
        .split(" ")
        .every(
          (token) =>
              allowedVars.contains(token) ||
              allowedOperators.contains(token) ||
              RegExp(r'^\d+(\.\d+)?$').hasMatch(token),
        ); // Numbers allowed

    return isValid;
  } catch (e) {
    return false; // Invalid syntax
  }
}
