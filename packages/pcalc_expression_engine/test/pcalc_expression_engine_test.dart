import 'package:flutter_test/flutter_test.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';

void main() {
  test('reports a backend and respects preference', () {
    setBackendPreference(null);
    addTearDown(() => setBackendPreference(null));
    final defaultInfo = selectedBackendInfo();
    expect(defaultInfo.name, isNotEmpty);

    setBackendPreference(BackendKind.pureDart);
    final preferredInfo = selectedBackendInfo();
    expect(preferredInfo.kind, BackendKind.pureDart);
    expect(preferredInfo.name, isNotEmpty);
  });

  test('can use the ROOT formula backend when available', () async {
    if (!canUseRoot) {
      return;
    }

    addTearDown(() => setBackendPreference(null));
    setBackendPreference(BackendKind.clingRepl);

    await initializeTinyExpr();

    final info = selectedBackendInfo();
    expect(info.kind, BackendKind.clingRepl);

    final result = evaluateExpression('1 + 2 * 3');
    expect(result, closeTo(7.0, 1e-9));
    expect(getLastErrorMessage(), isEmpty);
  });
}
