import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_express/calculator.dart';

Future<void> _pumpCalculatorHarness(
  WidgetTester tester, {
  required Size surfaceSize,
  int initialPanel = 0,
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      home: CalculatorScreen(
        showCalcButtonsDesktop: true,
        themeColor: Colors.red,
        initialPanel: initialPanel,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders compact phone keypad layout', (tester) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(393, 852));

    await expectLater(
      find.byType(CalculatorScreen),
      matchesGoldenFile('goldens/calculator_phone_keypad.png'),
    );
  });

  testWidgets('renders short phone keypad layout', (tester) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(360, 740));

    await expectLater(
      find.byType(CalculatorScreen),
      matchesGoldenFile('goldens/calculator_short_phone_keypad.png'),
    );
  });

  testWidgets('renders compact programmer keypad layout', (tester) async {
    await _pumpCalculatorHarness(
      tester,
      surfaceSize: const Size(393, 852),
      initialPanel: 1,
    );

    await expectLater(
      find.byType(CalculatorScreen),
      matchesGoldenFile('goldens/calculator_phone_programmer_keypad.png'),
    );
  });
}
