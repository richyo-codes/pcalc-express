import 'package:dart_clang_constexpr/dart_clang_constexpr.dart' as clang;

import 'backend.dart';

final class ClangConstexprBackend implements ExpressionBackend {
  ClangConstexprBackend({required this.capabilities, required this.language});

  final BackendCapabilities capabilities;
  final clang.ClangExpressionLanguage language;

  @override
  Future<void> initialize() async {
    throw UnsupportedError('Clang constexpr is unavailable on this platform.');
  }

  @override
  ExpressionEvaluationResult evaluate(String input) {
    throw UnsupportedError('Clang constexpr is unavailable on this platform.');
  }

  @override
  String getLastErrorMessage() =>
      'Clang constexpr is unavailable on this platform.';

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.clangConstexpr,
    name: 'Clang constexpr unavailable',
    description: 'The native Clang evaluator is unavailable on this platform.',
    capabilities: capabilities,
  );
}
