import 'package:flutter/material.dart';
import 'package:rnd_pcalc_ng/calculator.dart';
import 'package:tinyexpr_plusplus_ffi/tinyexpr_plusplus_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeTinyExpr();

  runApp(
    MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const CalculatorScreen(
        showCalcButtonsDesktop: true,
        themeColor: Colors.red,
      ),
      scrollBehavior: AppScrollBehavior(),
      debugShowCheckedModeBanner: false,
    ),
  );
}
