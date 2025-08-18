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

void main() async {
  // Set window size for Linux desktop
  if (Platform.isLinux) {
    // WidgetsFlutterBinding.ensureInitialized();
    // await windowManager.ensureInitialized();

    // WindowOptions windowOptions = const WindowOptions(
    //   size: Size(620, 800), // Set initial size here
    //   center: true,
    //   backgroundColor: Colors.transparent,
    //   skipTaskbar: false,
    //   titleBarStyle: TitleBarStyle.normal,
    // );
    // windowManager.waitUntilReadyToShow(windowOptions, () async {
    //   await windowManager.show();
    //   await windowManager.focus();
    // });
  }
  runApp(ProgrammerCalculator());
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
