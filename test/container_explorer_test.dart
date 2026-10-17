import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_express/container_explorer.dart';
import 'package:pcalc_express/theme_preferences.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';

ScalarSnapshot integer(int value) => ScalarSnapshot.integer(
  '$value',
  typeName: 'int32_t',
  width: 32,
  signed: true,
);

void main() {
  test(
    'snapshots own their elements, enforce limits and preserve exact integers',
    () {
      final elements = <ResultSnapshot>[integer(1)];
      final snapshot = ContainerSnapshot(typeName: 'array', elements: elements);
      elements.clear();
      expect(snapshot.elements, hasLength(1));
      expect(() => snapshot.elements.clear(), throwsUnsupportedError);
      expect(
        () => ContainerSnapshot(
          typeName: 'array',
          elements: [integer(1)],
          totalCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ContainerSnapshot(
          typeName: 'array',
          elements: List.generate(4096, integer),
        ),
        throwsArgumentError,
      );
      expect(
        () => ScalarSnapshot.integer(
          '256',
          typeName: 'uint8_t',
          width: 8,
          signed: false,
        ),
        throwsArgumentError,
      );
      final huge = ScalarSnapshot.integer(
        '18446744073709551615',
        typeName: 'uint64_t',
        width: 64,
        signed: false,
      );
      expect(
        jsonEncode(huge.toJson()),
        contains('"value":"18446744073709551615"'),
      );
      var nested = ContainerSnapshot(typeName: 'array', elements: []);
      for (var i = 1; i < 8; i++) {
        nested = ContainerSnapshot(typeName: 'array', elements: [nested]);
      }
      expect(
        () => ContainerSnapshot(typeName: 'array', elements: [nested]),
        throwsArgumentError,
      );
    },
  );

  Future<void> pump(
    WidgetTester tester,
    ContainerSnapshot snapshot, {
    double width = 380,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEinkTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: ContainerExplorer(snapshot: snapshot),
          ),
        ),
      ),
    );
  }

  testWidgets('compact nested navigation, exact hex and copy snapshot', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
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
    final nested = ContainerSnapshot(
      typeName: 'vector<uint64_t>',
      elements: [
        ScalarSnapshot.integer(
          '18446744073709551615',
          typeName: 'uint64_t',
          width: 64,
          signed: false,
        ),
      ],
    );
    await pump(
      tester,
      ContainerSnapshot(typeName: 'array', elements: [nested]),
    );
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    expect(find.textContaining('Result[0]'), findsOneWidget);
    await tester.tap(find.text('Copy snapshot'));
    await tester.pump();
    expect(copied, contains('18446744073709551615'));
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hex'));
    await tester.pump();
    expect(find.textContaining('FF FF FF FF FF FF FF FF'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to container'));
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.byTooltip('Back to container'));
    await tester.pump();
    expect(find.textContaining('Result · array'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'paging, index validation, partial data and snapshot replacement',
    (tester) async {
      await pump(
        tester,
        ContainerSnapshot(
          typeName: 'vector<int>',
          elements: List.generate(70, integer),
          totalCount: 100,
        ),
        width: 1000,
      );
      expect(find.textContaining('Partial snapshot'), findsOneWidget);
      await tester.tap(find.byTooltip('Next page'));
      await tester.pump();
      expect(find.text('32–63 of 70 captured'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '90');
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(find.text('Enter a captured index'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '69');
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(find.text('64–69 of 70 captured'), findsOneWidget);
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();
      expect(find.textContaining('Element [64]'), findsOneWidget);
      await pump(
        tester,
        ContainerSnapshot(typeName: 'empty', elements: []),
        width: 1000,
      );
      expect(find.text('Empty container'), findsOneWidget);
      expect(find.textContaining('Element [64]'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
