import 'backend.dart';

final class ClingReplBackend implements ExpressionBackend {
  ClingReplBackend({required this.capabilities});

  final BackendCapabilities capabilities;

  @override
  Future<void> initialize() async {
    throw UnsupportedError(
      'ROOT formula backend is not available on this platform.',
    );
  }

  @override
  double evaluate(String input) {
    throw UnsupportedError(
      'ROOT formula backend is not available on this platform.',
    );
  }

  @override
  String getLastErrorMessage() =>
      'ROOT formula backend is not available on this platform.';

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.clingRepl,
    name: 'ROOT formula backend',
    description: 'Reserved for a ROOT subprocess evaluator backend.',
    capabilities: capabilities,
  );
}
