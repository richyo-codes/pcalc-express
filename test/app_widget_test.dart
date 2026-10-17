import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_express/calculator.dart';
import 'package:pcalc_express/main.dart';
import 'package:pcalc_express/theme_preferences.dart';

void main() {
  tearDown(() => themeModeNotifier.value = AppTheme.system);

  testWidgets('the app has one MaterialApp and one root navigator', (
    tester,
  ) async {
    themeModeNotifier.value = AppTheme.light;
    await tester.pumpWidget(const PCalcApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Navigator), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(CalculatorScreen))).primaryColor,
      appThemeColor,
    );
  });

  testWidgets('the root app applies theme preference changes', (tester) async {
    themeModeNotifier.value = AppTheme.light;
    await tester.pumpWidget(const PCalcApp());
    await tester.pumpAndSettle();
    final screen = find.byType(CalculatorScreen);
    expect(Theme.of(tester.element(screen)).brightness, Brightness.light);

    themeModeNotifier.value = AppTheme.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(screen)).brightness, Brightness.dark);

    themeModeNotifier.value = AppTheme.eink;
    await tester.pumpAndSettle();
    expect(isEinkTheme(tester.element(screen)), isTrue);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
