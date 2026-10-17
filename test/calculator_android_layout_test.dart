import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_express/calculator.dart';
import 'package:pcalc_express/calculator_keypad.dart';
import 'package:pcalc_express/eink_device.dart';
import 'package:pcalc_express/input_preferences.dart';
import 'package:pcalc_express/theme_preferences.dart';
import 'package:pcalc_express/result_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpCalculatorHarness(
  WidgetTester tester, {
  required Size surfaceSize,
  int initialPanel = 0,
  bool eink = false,
}) async {
  // Keep browser viewport metrics native. Overriding physical size and DPR
  // independently can briefly produce invalid web view insets during resize.
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: eink ? buildEinkTheme() : ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: surfaceSize),
        child: child!,
      ),
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
  testWidgets(
    'inline formats update the current result without recalculation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await loadResultPreferences();
      addTearDown(() {
        floatPrecisionNotifier.value = null;
        hexGroupDigitsNotifier.value = 2;
        hexPrefixNotifier.value = false;
      });
      await _pumpCalculatorHarness(tester, surfaceSize: const Size(900, 900));
      await tester.enterText(find.byType(TextField), '43707 + 0.125');
      await tester.tap(find.widgetWithText(FilledButton, '=').first);
      await tester.pumpAndSettle();
      expect(find.text('43707.125'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'unfinished');
      await tester.tap(find.byTooltip('Floating point precision'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<int>, '2 decimal places'),
      );
      await tester.pumpAndSettle();
      expect(find.text('43707.13'), findsOneWidget);
      await tester.tap(find.byTooltip('Floating point precision'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<int>, 'Auto precision'),
      );
      await tester.pumpAndSettle();
      expect(find.text('43707.125'), findsOneWidget);
      await tester.tap(find.byTooltip('Hexadecimal formatting'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<int>, 'Show 0x prefix'),
      );
      await tester.pumpAndSettle();
      expect(find.text('0xAA BB'), findsOneWidget);
      await tester.tap(find.byTooltip('Hexadecimal formatting'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<int>, 'No spacing'),
      );
      await tester.pumpAndSettle();
      expect(find.text('0xAABB'), findsOneWidget);
      await _pumpCalculatorHarness(tester, surfaceSize: const Size(360, 740));
      await tester.tap(find.byTooltip('Show one result unit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Float'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Floating point precision'), findsOneWidget);
      expect(find.text('43707.125'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hex'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hexadecimal formatting'), findsOneWidget);
      expect(find.text('0xAABB'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'unfinished',
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final keyboardEnabled in [false, true]) {
    testWidgets(
      'editor expands on first unfocused mouse click (keyboard $keyboardEnabled)',
      (tester) async {
        final previous = useSystemKeyboardNotifier.value;
        addTearDown(() => useSystemKeyboardNotifier.value = previous);
        useSystemKeyboardNotifier.value = keyboardEnabled;
        await _pumpCalculatorHarness(
          tester,
          surfaceSize: const Size(1280, 1000),
        );
        final field = find.byType(TextField);
        await tester.enterText(field, '(1 + 2)');
        tester.widget<TextField>(field).focusNode!.unfocus();
        await tester.pumpAndSettle();
        final initialHeight = tester.getSize(field).height;
        await tester.tap(
          find.byTooltip('Expand expression editor'),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(tester.getSize(field).height, greaterThan(initialHeight));
        expect(find.byTooltip('Collapse expression editor'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'multiline editor drag preserves text, cursor and chosen height',
    (tester) async {
      await _pumpCalculatorHarness(tester, surfaceSize: const Size(900, 900));
      final field = find.byType(TextField);
      final handle = find.byKey(const ValueKey('expression-resize-handle'));
      expect(handle, findsNothing);
      await tester.tap(find.byTooltip('Expand expression editor'));
      await tester.pumpAndSettle();
      await tester.enterText(field, '1 +\n2');
      final controller = tester.widget<TextField>(field).controller!;
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      final initialHeight = tester.getSize(field).height;

      await tester.drag(handle, const Offset(0, 100));
      await tester.pumpAndSettle();
      final chosenHeight = tester.getSize(field).height;
      expect(chosenHeight, greaterThan(initialHeight));
      expect(controller.text, '1 +\n2');
      expect(controller.selection.extentOffset, 3);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

      await _pumpCalculatorHarness(tester, surfaceSize: const Size(360, 640));
      expect(tester.getSize(field).height, lessThan(chosenHeight));
      expect(tester.takeException(), isNull);
      await _pumpCalculatorHarness(tester, surfaceSize: const Size(900, 900));
      expect(tester.getSize(field).height, chosenHeight);

      await tester.tap(find.byTooltip('Collapse expression editor'));
      await tester.pumpAndSettle();
      expect(handle, findsNothing);
      expect(tester.getSize(field).height, 56);
      await tester.tap(find.byTooltip('Expand expression editor'));
      await tester.pumpAndSettle();
      expect(tester.getSize(field).height, chosenHeight);
      await tester.drag(handle, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(tester.getSize(field).height, 80);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('multiline drag height stays bounded on a short phone', (
    tester,
  ) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(360, 640));
    await tester.tap(find.byTooltip('Expand expression editor'));
    await tester.pumpAndSettle();
    final handle = find.byKey(const ValueKey('expression-resize-handle'));
    await tester.drag(handle, const Offset(0, 2000));
    await tester.pumpAndSettle();
    final height = tester.getSize(find.byType(TextField)).height;
    expect(height, inInclusiveRange(80, 340));
    expect(tester.takeException(), isNull);
    await tester.drag(handle, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TextField)).height, 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded editor calculates with Control Enter', (tester) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(900, 800));
    await tester.tap(find.byTooltip('Expand expression editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '6 * 7');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '6 * 7',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expression editor expands without losing text or selection', (
    tester,
  ) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(393, 852));
    final field = find.byType(TextField);
    await tester.enterText(field, '1 + 2');
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    final compactHeight = tester.getSize(field).height;

    await tester.tap(find.byTooltip('Expand expression editor'));
    await tester.pumpAndSettle();
    expect(tester.getSize(field).height, greaterThan(compactHeight));
    expect(tester.widget<TextField>(field).maxLines, isNull);
    expect(
      tester.widget<TextField>(field).textInputAction,
      TextInputAction.newline,
    );
    expect(controller.selection.extentOffset, 3);

    await tester.tap(find.byTooltip('Insert newline'));
    await tester.pump();
    expect(controller.text, '1 +\n 2');
    expect(controller.selection.extentOffset, 4);
    await tester.tap(find.byTooltip('Collapse expression editor'));
    await tester.pumpAndSettle();
    expect(tester.getSize(field).height, compactHeight);
    expect(controller.text, '1 +\n 2');
    expect(controller.selection.extentOffset, 4);
    expect(
      tester.widget<TextField>(field).textInputAction,
      TextInputAction.done,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded editor supports keypad newlines on a short phone', (
    tester,
  ) async {
    final previous = useSystemKeyboardNotifier.value;
    addTearDown(() => useSystemKeyboardNotifier.value = previous);
    useSystemKeyboardNotifier.value = false;
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(360, 640));
    await tester.tap(find.byTooltip('Expand expression editor'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).keyboardType, TextInputType.none);
    await tester.tap(find.byTooltip('Insert newline'));
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '\n');
    expect(tester.takeException(), isNull);
  });

  testWidgets('application menu offers the AGPL source code', (tester) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(620, 800));
    await tester.tap(find.byTooltip('Application menu'));
    await tester.pumpAndSettle();

    expect(find.text('Source code (AGPLv3)'), findsOneWidget);
  });

  testWidgets('mobile grouped keys insert at the cursor', (tester) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(393, 852));
    final field = find.byType(TextField);
    await tester.enterText(field, '0x+1');
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    expect(tester.getSize(field).width, greaterThan(350));

    await tester.tap(find.text('More ▾'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'F'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'F'));
    await tester.pumpAndSettle();
    expect(controller.text, '0xF+1');
    expect(controller.selection.extentOffset, 3);

    await tester.tap(find.text('More ▾'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bitwise'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '<<'));
    await tester.pumpAndSettle();
    expect(controller.text, '0xF<<+1');
    await tester.tap(find.widgetWithText(FilledButton, '←'));
    await tester.pump();
    expect(controller.selection.extentOffset, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard preference keeps the expression editable', (
    tester,
  ) async {
    final previous = useSystemKeyboardNotifier.value;
    addTearDown(() => useSystemKeyboardNotifier.value = previous);
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(393, 852));
    useSystemKeyboardNotifier.value = false;
    await tester.pump();
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).keyboardType, TextInputType.none);
    expect(tester.widget<TextField>(field).readOnly, isFalse);
    useSystemKeyboardNotifier.value = true;
    await tester.pump();
    expect(tester.widget<TextField>(field).keyboardType, TextInputType.text);
  });

  testWidgets('expression colors distinguish literals and operators', (
    tester,
  ) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(620, 800));
    final field = find.byType(TextField);
    const expression = "0xFF + 1e-3 + var2 + '+'";
    await tester.enterText(field, expression);
    final controller = tester.widget<TextField>(field).controller!;
    final span = controller.buildTextSpan(
      context: tester.element(field),
      style: const TextStyle(color: Colors.black),
      withComposing: false,
    );
    Color? colorAt(int offset) =>
        (span.children![offset] as TextSpan).style?.color;
    expect(span.toPlainText(), expression);
    expect(colorAt(0), isNotNull);
    expect(colorAt(5), isNot(colorAt(0)));
    expect(colorAt(expression.indexOf('-')), colorAt(0));
    expect(colorAt(expression.indexOf('2')), isNull);
    expect(colorAt(expression.lastIndexOf('+')), colorAt(0));
  });

  testWidgets('matching brackets do not paint over the caret', (tester) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(620, 800));
    final field = find.byType(TextField);
    await tester.enterText(field, '()');
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();

    final span = controller.buildTextSpan(
      context: tester.element(field),
      style: const TextStyle(color: Colors.black),
      withComposing: false,
    );
    final opening = span.children![0] as TextSpan;
    final closing = span.children![1] as TextSpan;

    for (final bracket in [opening, closing]) {
      expect(bracket.style?.backgroundColor, isNull);
      expect(bracket.style?.decoration, TextDecoration.underline);
    }
  });

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

  testWidgets(
    'e-ink General has outlined keys and inserts space at selection',
    (tester) async {
      await _pumpCalculatorHarness(
        tester,
        surfaceSize: const Size(600, 800),
        eink: true,
      );
      final field = find.byType(TextField);
      await tester.enterText(field, '123');
      final controller = tester.widget<TextField>(field).controller!;
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 2,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'SPACE').first);
      await tester.pump();
      expect(controller.text, '1 3');
      expect(controller.selection.extentOffset, 2);
      final key = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '7'),
      );
      expect(key.style!.backgroundColor!.resolve({}), Colors.white);
      expect(key.style!.foregroundColor!.resolve({}), Colors.black);
      expect(key.style!.elevation!.resolve({}), 0);
      await tester.tap(find.text('More ▾'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/operators_eink.png'),
      );
      await tester.tap(find.byTooltip('Close operators'));
      await tester.pumpAndSettle();
      expect(controller.text, '1 3');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reader layout exposes editing and programmer rows', (
    tester,
  ) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(600, 900));

    Offset keyCenter(String label) =>
        tester.getCenter(find.widgetWithText(FilledButton, label).first);

    final top = keyCenter('AC').dy;
    for (final label in ['(', ')', '←', '→', 'DEL']) {
      expect(keyCenter(label).dy, top);
    }
    final programmerRow = keyCenter('0x').dy;
    for (final label in ['0b', '<<', '>>', '&', 'More ▾']) {
      expect(keyCenter(label).dy, programmerRow);
    }
    expect(programmerRow, greaterThan(top));
    expect(programmerRow, lessThan(keyCenter('7').dy));

    final bottom = keyCenter('=').dy;
    expect(keyCenter('SPACE').dy, bottom);
    expect(keyCenter('=').dx, greaterThan(keyCenter('SPACE').dx));
  });

  testWidgets(
    'roomy General keypad inserts hex digits without changing panels',
    (tester) async {
      await _pumpCalculatorHarness(
        tester,
        surfaceSize: const Size(600, 1000),
        eink: true,
      );
      final controller = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!;
      controller.text = '0x + 1';
      controller.selection = const TextSelection.collapsed(offset: 2);
      final row = tester.getCenter(find.widgetWithText(FilledButton, 'A')).dy;
      for (final digit in ['A', 'B', 'C', 'D', 'E', 'F']) {
        final key = find.widgetWithText(FilledButton, digit);
        expect(tester.getCenter(key).dy, row);
        expect(tester.getSize(key).height, greaterThanOrEqualTo(48));
        await tester.tap(key);
        await tester.pump();
      }
      expect(controller.text, '0xABCDEF + 1');
      expect(controller.selection.extentOffset, 8);
      expect(
        row,
        lessThan(tester.getCenter(find.widgetWithText(FilledButton, '0x')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short General keypad does not squeeze in a hex row', (
    tester,
  ) async {
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(600, 650));
    final grid = tester.widget<CalculatorButtonGrid>(
      find.byType(CalculatorButtonGrid).first,
    );
    expect(
      grid.rows.expand((row) => row).map((key) => key.displayText),
      isNot(contains('A')),
    );
    await tester.drag(find.byType(GridView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'SPACE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detected e-ink devices disable keypad page swiping', (
    tester,
  ) async {
    einkDeviceNotifier.value = true;
    addTearDown(() => einkDeviceNotifier.value = false);
    await _pumpCalculatorHarness(tester, surfaceSize: const Size(600, 900));
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
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
