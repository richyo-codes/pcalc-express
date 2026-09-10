import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';

void main() {
  test('reports a backend and respects preference', () {
    setBackendPreference(null);
    addTearDown(() => setBackendPreference(null));
    final defaultInfo = selectedBackendInfo();
    expect(defaultInfo.name, isNotEmpty);
    if (canUseClangConstexpr) {
      expect(defaultInfo.kind, BackendKind.clangConstexpr);
    }

    setBackendPreference(BackendKind.pureDart);
    final preferredInfo = selectedBackendInfo();
    expect(preferredInfo.kind, BackendKind.pureDart);
    expect(preferredInfo.name, isNotEmpty);
  });

  test('sessions can carry separate backend preferences', () {
    final formulaSession = ExpressionSession(
      preferredBackend: BackendKind.rootFormula,
    );
    final clingSession = ExpressionSession(
      preferredBackend: BackendKind.clingCxx,
      debugLoggingEnabled: true,
    );

    expect(formulaSession.selectedBackendInfo().kind, BackendKind.rootFormula);
    expect(clingSession.selectedBackendInfo().kind, BackendKind.clingCxx);
    expect(clingSession.backendDebugLoggingEnabled, isTrue);
  });

  test('factory creates isolated sessions', () {
    final session = createExpressionSession(
      preferredBackend: BackendKind.rootFormula,
    );

    expect(session.selectedBackendInfo().kind, BackendKind.rootFormula);
    session.setBackendPreference(BackendKind.clingCxx);
    expect(session.selectedBackendInfo().kind, BackendKind.clingCxx);
  });

  test('can use the ROOT formula backend when available', () async {
    if (!canUseRoot) {
      return;
    }

    addTearDown(() => setBackendPreference(null));
    setBackendPreference(BackendKind.rootFormula);

    await initializeTinyExpr();

    final info = selectedBackendInfo();
    expect(info.kind, BackendKind.rootFormula);

    final result = evaluateExpression('1 + 2 * 3');
    expect(result.numericValue, closeTo(7.0, 1e-9));
    expect(result.integerValue, 7);
    expect(result.bitWidth, 32);
    expect(getLastErrorMessage(), isEmpty);
  });

  test('can use the Cling C++ backend when available', () async {
    if (!canUseCling) {
      return;
    }

    addTearDown(() => setBackendPreference(null));
    setBackendPreference(BackendKind.clingCxx);

    await initializeTinyExpr();

    final info = selectedBackendInfo();
    expect(info.kind, BackendKind.clingCxx);
    final result = evaluateExpression('(char)1');
    expect(result.isError, isFalse);
    expect(result.numericValue, isNotNull);
  });

  test('can use the embedded Clang constexpr backend when available', () async {
    if (!canUseClangConstexpr) return;

    final session = ExpressionSession(
      preferredBackend: BackendKind.clangConstexpr,
    );
    await session.initialize();

    final result = session.evaluate('(char)255');
    expect(result.isError, isFalse);
    expect(result.integerValue, -1);
    expect(result.bitWidth, 8);
    expect(result.isSigned, isTrue);
  });
}
