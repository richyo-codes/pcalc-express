import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_express/calculator.dart';

Future<void> _pumpCalculatorHarness(
  WidgetTester tester, {
  required Size surfaceSize,
  int initialPanel = 0,
}) async {
  // Keep browser viewport metrics native. Overriding physical size and DPR
  // independently can briefly produce invalid web view insets during resize.
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

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
  testWidgets('keypad buttons append to the expression on desktop', (
    tester,
  ) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(393, 852));

    final expressionField = find.byType(TextField);
    expect(tester.widget<TextField>(expressionField).selectAllOnFocus, isFalse);

    await tester.tap(expressionField);
    await tester.enterText(expressionField, '1+2');
    await tester.tap(find.widgetWithText(FilledButton, '3'));
    await tester.tap(find.widgetWithText(FilledButton, '4'));

    expect(tester.widget<TextField>(expressionField).controller!.text, '1+234');
  });

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
