import 'package:expressions/expressions.dart';
import 'package:flutter/material.dart';
import 'package:pcalc_express/app_brand.dart';
import 'package:pcalc_express/backend_preferences.dart';
import 'package:pcalc_express/calculator.dart';
import 'package:pcalc_express/platform_capabilities.dart';
import 'package:pcalc_express/theme_preferences.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    themeModeNotifier.value = ThemeMode.light;
  } else if (screenshotTheme == 'dark') {
    themeModeNotifier.value = ThemeMode.dark;
  }

  // Configure frameless desktop window and custom drag areas.
  if (isLinux || isWindows) {
    await windowManager.ensureInitialized();

    const WindowOptions windowOptions = WindowOptions(
      size: Size(620, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: appTitle,
      titleBarStyle: TitleBarStyle.hidden,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setAsFrameless();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: appTitle,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: mode,
        home: const ProgrammerCalculator(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
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
