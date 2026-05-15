import 'package:flutter/foundation.dart';
import 'package:tinyexpr_plusplus_ffi/tinyexpr_plusplus_ffi.dart' as tinyexpr;

import 'backend_probe.dart';
import 'backend_repl.dart';

enum BackendKind { tinyExprFfi, clingRepl, pureDart }

class BackendCapabilities {
  const BackendCapabilities({
    required this.isWeb,
    required this.hasRoot,
    required this.hasCling,
  });

  final bool isWeb;
  final bool hasRoot;
  final bool hasCling;

  bool get supportsCling => !isWeb && (hasRoot || hasCling);
  bool get prefersPureDart => isWeb;
}

class ExpressionEngineInfo {
  const ExpressionEngineInfo({
    required this.kind,
    required this.name,
    required this.description,
    required this.capabilities,
  });

  final BackendKind kind;
  final String name;
  final String description;
  final BackendCapabilities capabilities;
}

abstract class ExpressionBackend {
  Future<void> initialize();
  double evaluate(String input);
  String getLastErrorMessage();
  ExpressionEngineInfo get info;
}

final class TinyExprBackend implements ExpressionBackend {
  TinyExprBackend({required this.capabilities});

  final BackendCapabilities capabilities;

  @override
  Future<void> initialize() => tinyexpr.initializeTinyExpr();

  @override
  double evaluate(String input) => tinyexpr.evaluateExpression(input);

  @override
  String getLastErrorMessage() => tinyexpr.getLastErrorMessage();

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.tinyExprFfi,
    name: 'TinyExpr++ FFI',
    description: capabilities.supportsCling
        ? 'TinyExpr++ FFI with Linux ROOT/Cling available on PATH.'
        : 'TinyExpr++ FFI native backend.',
    capabilities: capabilities,
  );
}

final class _PureDartBackendPlaceholder implements ExpressionBackend {
  _PureDartBackendPlaceholder({required this.capabilities});

  final BackendCapabilities capabilities;

  @override
  Future<void> initialize() async {}

  @override
  double evaluate(String input) {
    throw UnsupportedError('Pure Dart backend is not implemented yet.');
  }

  @override
  String getLastErrorMessage() => 'Pure Dart backend is not implemented yet.';

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.pureDart,
    name: 'Pure Dart placeholder',
    description: 'Reserved for a browser-safe Dart evaluator fallback.',
    capabilities: capabilities,
  );
}

ExpressionBackend? _selectedBackend;
BackendKind? _preferredBackend;
bool _debugLoggingEnabled = false;

BackendCapabilities get _capabilities => BackendCapabilities(
  isWeb: kIsWeb,
  hasRoot: canUseRoot,
  hasCling: canUseCling,
);

ExpressionBackend _createBackend(BackendKind kind) {
  final capabilities = _capabilities;
  return switch (kind) {
    BackendKind.tinyExprFfi => TinyExprBackend(capabilities: capabilities),
    BackendKind.clingRepl => ClingReplBackend(capabilities: capabilities),
    BackendKind.pureDart => _PureDartBackendPlaceholder(
      capabilities: capabilities,
    ),
  };
}

ExpressionBackend _selectBackend() {
  final capabilities = _capabilities;
  if (_preferredBackend != null) {
    return _createBackend(_preferredBackend!);
  }
  if (!capabilities.isWeb) {
    return TinyExprBackend(capabilities: capabilities);
  }
  return _PureDartBackendPlaceholder(capabilities: capabilities);
}

Future<void> initializeTinyExpr() async {
  _selectedBackend = _selectBackend();
  await _selectedBackend!.initialize();
}

double evaluateExpression(String input) {
  final backend = _selectedBackend ?? _selectBackend();
  _selectedBackend ??= backend;
  return backend.evaluate(input);
}

String getLastErrorMessage() {
  final backend = _selectedBackend ?? _selectBackend();
  _selectedBackend ??= backend;
  return backend.getLastErrorMessage();
}

ExpressionEngineInfo selectedBackendInfo() {
  final backend = _selectedBackend ?? _selectBackend();
  return backend.info;
}

void setBackendPreference(BackendKind? kind) {
  _preferredBackend = kind;
  _selectedBackend = null;
}

void setBackendDebugLoggingEnabled(bool enabled) {
  _debugLoggingEnabled = enabled;
}

bool get backendDebugLoggingEnabled => _debugLoggingEnabled;
