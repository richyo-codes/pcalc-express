import 'backend.dart';

final class ClingCxxBackend implements ExpressionBackend {
  ClingCxxBackend({required this.capabilities});

  final BackendCapabilities capabilities;

  @override
  Future<void> initialize() async {
    throw UnsupportedError(
      'Cling C++ backend is not available on this platform.',
    );
  }

  @override
  double evaluate(String input) {
    throw UnsupportedError(
      'Cling C++ backend is not available on this platform.',
    );
  }

  @override
  String getLastErrorMessage() =>
      'Cling C++ backend is not available on this platform.';

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.clingCxx,
    name: 'Cling C++ backend',
    description: 'Reserved for a full C++ interpreter backend.',
    capabilities: capabilities,
  );
}
