import 'dart:io';

import 'package:expressions/expressions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rnd_pcalc_ng/calculator.dart';
import 'package:rnd_pcalc_ng/settings_page.dart';

import 'package:rnd_pcalc_ng/tinyexprpp_fii.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:rnd_pcalc_ng/help_screen.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:rnd_pcalc_ng/format_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final modeString = prefs.getString('themeMode') ?? 'system';
  switch (modeString) {
    case 'light':
      themeModeNotifier.value = ThemeMode.light;
      break;
    case 'dark':
      themeModeNotifier.value = ThemeMode.dark;
      break;
    default:
      themeModeNotifier.value = ThemeMode.system;
  }
}

Future<void> saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  String modeString;
  switch (mode) {
    case ThemeMode.light:
      modeString = 'light';
      break;
    case ThemeMode.dark:
      modeString = 'dark';
      break;
    default:
      modeString = 'system';
  }
  await prefs.setString('themeMode', modeString);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadThemeMode(); // <-- Load theme mode before runApp

  // Configure frameless desktop window and custom drag areas.
  if (Platform.isLinux || Platform.isWindows) {
    await windowManager.ensureInitialized();

    const WindowOptions windowOptions = WindowOptions(
      size: Size(620, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
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
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: mode,
        home: ProgrammerCalculator(),
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
