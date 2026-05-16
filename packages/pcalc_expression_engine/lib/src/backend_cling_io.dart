import 'backend.dart';
import 'backend_repl_io_backup.dart' as backup;

final class ClingCxxBackend implements ExpressionBackend {
  ClingCxxBackend({required this.capabilities})
    : _backend = backup.ClingReplBackend(capabilities: capabilities);

  final BackendCapabilities capabilities;
  final backup.ClingReplBackend _backend;

  @override
  Future<void> initialize() => _backend.initialize();

  @override
  double evaluate(String input) => _backend.evaluate(input);

  @override
  String getLastErrorMessage() => _backend.getLastErrorMessage();

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.clingCxx,
    name: 'Cling C++ backend',
    description: 'Uses ROOT/Cling subprocess evaluation for full C++ syntax.',
    capabilities: capabilities,
  );
}
