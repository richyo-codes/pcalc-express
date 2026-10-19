// Reads fixture files and exercises the native evaluator.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';

void main() {
  final cases = jsonDecode(
    File('test/fixtures/endian_cases.json').readAsStringSync(),
  ) as List;
  for (final language in [
    ClangExpressionLanguage.cpp17,
    ClangExpressionLanguage.cpp20,
    ClangExpressionLanguage.cpp23,
  ]) {
    test('endian helpers: ${language.name}', () async {
      final session = ExpressionSession(
        preferredBackend: BackendKind.clangConstexpr,
        clangLanguage: language,
      );
      await session.initialize();
      for (final entry in cases) {
        final result = session.evaluate(entry['expression'] as String);
        expect(
          result.isError,
          entry['error'] == true,
          reason: '${entry['expression']}: ${result.errorMessage}',
        );
        if (entry['error'] != true) {
          expect(
            result.displayText,
            entry['value'],
            reason: entry['expression'],
          );
          expect(result.bitWidth, entry['width']);
          expect(result.isSigned, false);
        }
      }
      expect(session.evaluate('sqrt(81.0) + htons(0)').numericValue, 9);
      expect(session.evaluate('1 + 2').integerValue, 3);
    });
  }
  test('C mode reports endian helper requirement', () async {
    final session = ExpressionSession(
      preferredBackend: BackendKind.clangConstexpr,
      clangLanguage: ClangExpressionLanguage.c17,
    );
    await session.initialize();
    expect(session.evaluate('htons(1)').errorMessage, contains('C++17'));
    expect(session.evaluate('1 + 2').integerValue, 3);
  });
}
