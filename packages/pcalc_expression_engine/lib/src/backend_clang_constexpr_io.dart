import 'package:dart_clang_constexpr/dart_clang_constexpr.dart' as clang;

import 'backend.dart';
import 'backend_probe.dart';
import 'endian_helpers.dart';
import 'bit_helpers.dart';

final class ClangConstexprBackend implements ExpressionBackend {
  ClangConstexprBackend({required this.capabilities, required this.language});

  final BackendCapabilities capabilities;
  final clang.ClangExpressionLanguage language;
  String _lastError = '';

  @override
  Future<void> initialize() async {
    if (!canUseClangConstexpr) {
      throw UnsupportedError(
        'Clang constexpr is unavailable on this platform.',
      );
    }
    await clang.initializeClangConstexpr();
    evaluate('1 + 1');
  }

  @override
  ExpressionEvaluationResult evaluate(String input) {
    try {
      final endian = usesEndianHelpers(input);
      final bits = usesBitHelpers(input);
      if (endian || bits) {
        if (!language.isCxx ||
            language == clang.ClangExpressionLanguage.cpp11 ||
            language == clang.ClangExpressionLanguage.cpp14) {
          throw const clang.ClangEvaluationException(
            'Calculator bit/endian helpers require Clang C++17 or newer.',
          );
        }
        final prelude =
            '${endian ? endianHelperPrelude : ''}\n'
            '${bits ? bitHelperPrelude : ''}';
        input = '[] {\n$prelude\nreturn (\n$input\n);\n}()';
      }
      final result = clang.evaluateClangExpression(input, language: language);
      _lastError = '';
      final integer = result.kind == clang.ClangValueKind.floating
          ? null
          : int.tryParse(result.displayText);
      final numeric = result.floatingValue ?? integer?.toDouble();
      if (numeric == null) {
        throw const clang.ClangEvaluationException(
          'Integer result exceeds the current Dart result range.',
        );
      }
      return ExpressionEvaluationResult(
        backendKind: BackendKind.clangConstexpr,
        kind: switch (result.kind) {
          clang.ClangValueKind.floating => ExpressionValueKind.floating,
          clang.ClangValueKind.boolean => ExpressionValueKind.boolean,
          clang.ClangValueKind.integer ||
          clang.ClangValueKind.character => ExpressionValueKind.integer,
          clang.ClangValueKind.error => ExpressionValueKind.error,
        },
        displayText: result.displayText,
        numericValue: numeric,
        integerValue: integer,
        bitWidth: result.bitWidth,
        isSigned: result.isSigned,
      );
    } on clang.ClangEvaluationException catch (error) {
      _lastError = error.message;
      return ExpressionEvaluationResult(
        backendKind: BackendKind.clangConstexpr,
        kind: ExpressionValueKind.error,
        displayText: error.message,
        errorMessage: error.message,
      );
    }
  }

  @override
  String getLastErrorMessage() => _lastError;

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.clangConstexpr,
    name: 'Clang constexpr',
    description: capabilities.isWeb
        ? 'Typed ${language.displayName} constant expressions through Clang WebAssembly.'
        : 'Typed ${language.displayName} constant expressions through embedded Clang.',
    capabilities: capabilities,
  );
}
