import 'package:flutter/material.dart';
import 'package:pcalc_express/calculator.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';

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
