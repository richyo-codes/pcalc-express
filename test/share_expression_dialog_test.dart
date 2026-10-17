import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_express/share_expression_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('share dialog encodes and copies the same expression link', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShareExpressionDialog(
                context: context,
                expression: '(0xFF << 2) & 10',
              ),
              child: const Text('Open sharing'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sharing'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    final link = tester.widget<SelectableText>(find.byType(SelectableText)).data;
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copiedText, link);
    expect(expressionFromLaunchUri(Uri.parse(copiedText!)), '(0xFF << 2) & 10');
    expect(tester.takeException(), isNull);
  });

  test('shared expression URL round-trips operator-heavy input', () {
    const expression = '(0xFF << 2) & 0b1010';

    final uri = buildSharedExpressionUri(expression);

    expect(uri.scheme, 'https');
    expect(uri.host, 'richyo-codes.github.io');
    expect(uri.path, '/pcalc-express/');
    expect(expressionFromLaunchUri(uri), expression);
  });

  test('empty shared expression opens the calculator without a query', () {
    final uri = buildSharedExpressionUri('  ');

    expect(uri.query, isEmpty);
    expect(expressionFromLaunchUri(uri), isNull);
  });
}
