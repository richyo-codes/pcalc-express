import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';

void main() {
  for (final language in [
    ClangExpressionLanguage.cpp17,
    ClangExpressionLanguage.cpp20,
    ClangExpressionLanguage.cpp23,
  ]) {
    test('bit helpers in ${language.name}', () async {
      final session = ExpressionSession(
        preferredBackend: BackendKind.clangConstexpr,
        clangLanguage: language,
      );
      await session.initialize();
      const cases = {
        'popcount(0xf0u)': 4,
        'popcount(0xffffffffffffffffULL)': 64,
        'countl_zero(0u)': 32,
        'countr_zero(0ULL)': 64,
        'countl_zero((uint8_t)1)': 7,
        'countr_zero(8u)': 3,
        'countl_one((uint8_t)0xff)': 8,
        'countr_one(7u)': 3,
        'has_single_bit(8u) ? 1 : 0': 1,
        'has_single_bit(0u) ? 1 : 0': 0,
        'bit_width(0u)': 0,
        'bit_width(255u)': 8,
        'bit_floor((uint8_t)255)': 128,
        'bit_floor(0u)': 0,
        'bit_ceil(0u)': 1,
        'bit_ceil((uint8_t)127)': 128,
        'rotl((uint8_t)0x81, 1)': 3,
        'rotr((uint8_t)3, 1)': 129,
        'rotl(1u, 35)': 8,
        'rotl(8u, -3)': 1,
        'rotr(1u, -3)': 8,
        'rotl(7ULL, 64)': 7,
        'rotl(1u, (-2147483647 - 1))': 1,
        'rotr(1ULL, 1) == (1ULL << 63) ? 1 : 0': 1,
        'popcount(htons(0xf0))': 4,
      };
      for (final entry in cases.entries) {
        final result = session.evaluate(entry.key);
        expect(
          result.isError,
          false,
          reason: '${entry.key}: ${result.errorMessage}',
        );
        expect(result.integerValue, entry.value, reason: entry.key);
      }
      for (final expression in [
        'popcount(-1)',
        'popcount(true)',
        'popcount(1.5)',
        'rotl(1u, 1.5)',
        'rotl(1u, true)',
        'bit_ceil((uint8_t)129)',
        'bit_ceil(0xffffffffffffffffULL)',
      ]) {
        expect(session.evaluate(expression).isError, true, reason: expression);
      }
      final rotation = session.evaluate('rotl((uint8_t)0x81, 1)');
      expect(rotation.bitWidth, 8);
      expect(rotation.isSigned, false);
      final count = session.evaluate('popcount(1u)');
      expect(count.bitWidth, 32);
      expect(count.isSigned, true);
    });
  }
}
