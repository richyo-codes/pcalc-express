import 'package:flutter/foundation.dart';
import 'package:dart_clang_constexpr/dart_clang_constexpr.dart' as clang;
import 'package:tinyexpr_plusplus_ffi/tinyexpr_plusplus_ffi.dart' as tinyexpr;

import 'backend_cling.dart';
import 'backend_clang_constexpr.dart';
import 'backend_probe.dart';
import 'backend_repl.dart';

enum BackendKind {
  tinyExprFfi,
  clangConstexpr,
  clingRepl,
  rootFormula,
  clingCxx,
  pureDart,
}

enum ExpressionValueKind { integer, floating, boolean, text, error }

class ExpressionEvaluationResult {
  const ExpressionEvaluationResult({
    required this.backendKind,
    required this.kind,
    required this.displayText,
    this.numericValue,
    this.integerValue,
    this.bitWidth,
    this.isSigned,
    this.errorMessage,
    this.rawOutput,
  });

  final BackendKind backendKind;
  final ExpressionValueKind kind;
  final String displayText;
  final double? numericValue;
  final int? integerValue;
  final int? bitWidth;
  final bool? isSigned;
  final String? errorMessage;
  final String? rawOutput;

  bool get isError => kind == ExpressionValueKind.error;
  bool get hasNumericValue => numericValue != null;
}

class BackendCapabilities {
  const BackendCapabilities({
    required this.isWeb,
    required this.hasRoot,
    required this.hasCling,
  });

  final bool isWeb;
  final bool hasRoot;
  final bool hasCling;

  bool get supportsRootFormula => !isWeb && hasRoot;
  bool get supportsClingCxx => !isWeb && (hasRoot || hasCling);
  bool get supportsCling => supportsClingCxx;
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
  ExpressionEvaluationResult evaluate(String input);
  String getLastErrorMessage();
  ExpressionEngineInfo get info;
}

final class TinyExprBackend implements ExpressionBackend {
  TinyExprBackend({required this.capabilities});

  final BackendCapabilities capabilities;

  @override
  Future<void> initialize() => tinyexpr.initializeTinyExpr();

  @override
  ExpressionEvaluationResult evaluate(String input) {
    final value = tinyexpr.evaluateExpression(input);
    return _numericResult(value);
  }

  @override
  String getLastErrorMessage() => tinyexpr.getLastErrorMessage();

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.tinyExprFfi,
    name: capabilities.isWeb ? 'TinyExpr++ WASM' : 'TinyExpr++ FFI',
    description: capabilities.isWeb
        ? 'TinyExpr++ compiled to WebAssembly.'
        : capabilities.supportsRootFormula
        ? 'TinyExpr++ FFI with Linux ROOT formula backend available on PATH.'
        : 'TinyExpr++ FFI native backend.',
    capabilities: capabilities,
  );

  ExpressionEvaluationResult _numericResult(double value) {
    final isWhole = value.isFinite && value.truncateToDouble() == value;
    final integerValue = isWhole ? value.toInt() : value.truncate();
    return ExpressionEvaluationResult(
      backendKind: BackendKind.tinyExprFfi,
      kind: isWhole
          ? ExpressionValueKind.integer
          : ExpressionValueKind.floating,
      displayText: value.toString(),
      numericValue: value,
      integerValue: integerValue,
      bitWidth: 32,
      isSigned: true,
    );
  }
}

final class _PureDartBackendPlaceholder implements ExpressionBackend {
  _PureDartBackendPlaceholder({required this.capabilities});

  final BackendCapabilities capabilities;

  @override
  Future<void> initialize() async {}

  @override
  ExpressionEvaluationResult evaluate(String input) {
    throw UnsupportedError('Pure Dart backend is not implemented yet.');
  }

  @override
  String getLastErrorMessage() => 'Pure Dart backend is not implemented yet.';

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.pureDart,
    name: 'Pure Dart backend unavailable',
    description: 'Reserved for a future browser-safe Dart evaluator.',
    capabilities: capabilities,
  );
}

final class ExpressionSession {
  ExpressionSession({
    BackendKind? preferredBackend,
    bool debugLoggingEnabled = false,
    clang.ClangExpressionLanguage clangLanguage =
        clang.ClangExpressionLanguage.cpp20,
  }) : _preferredBackend = preferredBackend,
       _debugLoggingEnabled = debugLoggingEnabled,
       _clangLanguage = clangLanguage;

  ExpressionBackend? _selectedBackend;
  BackendKind? _preferredBackend;
  bool _debugLoggingEnabled;
  clang.ClangExpressionLanguage _clangLanguage;

  BackendCapabilities get _capabilities => BackendCapabilities(
    isWeb: kIsWeb,
    hasRoot: canUseRoot,
    hasCling: canUseCling,
  );

  bool Function() get _debugLoggingEnabledGetter =>
      () => _debugLoggingEnabled;

  ExpressionBackend _createBackend(BackendKind kind) {
    final capabilities = _capabilities;
    return switch (kind) {
      BackendKind.tinyExprFfi => TinyExprBackend(capabilities: capabilities),
      BackendKind.clangConstexpr => ClangConstexprBackend(
        capabilities: capabilities,
        language: _clangLanguage,
      ),
      BackendKind.clingRepl => RootFormulaBackend(
        capabilities: capabilities,
        isDebugLoggingEnabled: _debugLoggingEnabledGetter,
      ),
      BackendKind.rootFormula => RootFormulaBackend(
        capabilities: capabilities,
        isDebugLoggingEnabled: _debugLoggingEnabledGetter,
      ),
      BackendKind.clingCxx => ClingCxxBackend(
        capabilities: capabilities,
        isDebugLoggingEnabled: _debugLoggingEnabledGetter,
      ),
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
    if (canUseClangConstexpr) {
      return ClangConstexprBackend(
        capabilities: capabilities,
        language: _clangLanguage,
      );
    }
    if (!capabilities.isWeb) {
      return TinyExprBackend(capabilities: capabilities);
    }
    return _PureDartBackendPlaceholder(capabilities: capabilities);
  }

  Future<void> initialize() async {
    _selectedBackend = _selectBackend();
    await _selectedBackend!.initialize();
  }

  ExpressionEvaluationResult evaluate(String input) {
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

  clang.ClangExpressionLanguage get clangLanguage => _clangLanguage;

  void setClangLanguage(clang.ClangExpressionLanguage language) {
    _clangLanguage = language;
    _selectedBackend = null;
  }

  void reset() {
    _selectedBackend = null;
  }
}

final ExpressionSession _defaultSession = ExpressionSession();

ExpressionSession createExpressionSession({
  BackendKind? preferredBackend,
  bool debugLoggingEnabled = false,
  clang.ClangExpressionLanguage clangLanguage =
      clang.ClangExpressionLanguage.cpp20,
}) {
  return ExpressionSession(
    preferredBackend: preferredBackend,
    debugLoggingEnabled: debugLoggingEnabled,
    clangLanguage: clangLanguage,
  );
}

Future<void> initializeTinyExpr() => _defaultSession.initialize();

ExpressionEvaluationResult evaluateExpression(String input) =>
    _defaultSession.evaluate(input);

String getLastErrorMessage() => _defaultSession.getLastErrorMessage();

ExpressionEngineInfo selectedBackendInfo() =>
    _defaultSession.selectedBackendInfo();

void setBackendPreference(BackendKind? kind) =>
    _defaultSession.setBackendPreference(kind);

void setBackendDebugLoggingEnabled(bool enabled) =>
    _defaultSession.setBackendDebugLoggingEnabled(enabled);

bool get backendDebugLoggingEnabled =>
    _defaultSession.backendDebugLoggingEnabled;

clang.ClangExpressionLanguage get clangLanguage =>
    _defaultSession.clangLanguage;

void setClangLanguage(clang.ClangExpressionLanguage language) =>
    _defaultSession.setClangLanguage(language);

void resetExpressionSession() => _defaultSession.reset();
