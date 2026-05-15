import 'package:flutter/foundation.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String backendPreferenceKey = 'backendPreference';
const String backendDebugLoggingKey = 'backendDebugLogging';

Future<BackendKind?> loadBackendPreference() async {
  final prefs = await SharedPreferences.getInstance();
  final rawValue = prefs.getString(backendPreferenceKey);
  if (rawValue == null || rawValue == 'auto') {
    return null;
  }

  for (final kind in BackendKind.values) {
    if (kind.name == rawValue) {
      return kind;
    }
  }

  return null;
}

Future<void> saveBackendPreference(BackendKind? kind) async {
  final prefs = await SharedPreferences.getInstance();
  if (kind == null) {
    await prefs.setString(backendPreferenceKey, 'auto');
    return;
  }

  await prefs.setString(backendPreferenceKey, kind.name);
}

String backendPreferenceLabel(BackendKind? kind) {
  return switch (kind) {
    null => 'Auto',
    BackendKind.tinyExprFfi => 'TinyExpr++ FFI',
    BackendKind.clingRepl => 'ROOT subprocess',
    BackendKind.pureDart => 'Pure Dart',
  };
}

String backendPreferenceHelpText(BackendKind? kind) {
  return switch (kind) {
    null => 'Use the best backend for the current platform.',
    BackendKind.tinyExprFfi => 'Use the native TinyExpr++ FFI backend.',
    BackendKind.clingRepl => 'Use ROOT or Cling from PATH on Linux.',
    BackendKind.pureDart => 'Use the browser-safe pure Dart fallback.',
  };
}

bool backendPreferenceIsAvailable(BackendKind kind) {
  return switch (kind) {
    BackendKind.tinyExprFfi => !kIsWeb,
    BackendKind.clingRepl => canUseCling,
    BackendKind.pureDart => false,
  };
}

Future<bool> loadBackendDebugLoggingEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(backendDebugLoggingKey) ?? false;
}

Future<void> saveBackendDebugLoggingEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(backendDebugLoggingKey, enabled);
}
