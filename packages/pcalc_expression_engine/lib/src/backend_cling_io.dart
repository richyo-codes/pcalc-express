import 'dart:io';

import 'backend.dart';

final class ClingCxxBackend implements ExpressionBackend {
  ClingCxxBackend({
    required this.capabilities,
    required this.isDebugLoggingEnabled,
  });

  static const String _resultPrefix = '__PCALC_RESULT__=';
  static const String _errorPrefix = '__PCALC_ERROR__=';

  final BackendCapabilities capabilities;
  final bool Function() isDebugLoggingEnabled;
  String _lastErrorMessage = '';
  _Launcher? _launcher;

  @override
  Future<void> initialize() async {
    if (!capabilities.supportsClingCxx) {
      throw UnsupportedError(
        'ROOT/Cling C++ backend is not available on this platform.',
      );
    }

    _launcher = _resolveLauncher();
    if (_launcher == null) {
      throw StateError('ROOT/Cling command was not found on PATH.');
    }

    final probeResult = _evaluateViaCling('(char)1 + 1');
    if (probeResult.isError) {
      final message = _lastErrorMessage;
      throw StateError(
        message.isEmpty
            ? 'ROOT/Cling C++ backend failed its startup probe.'
            : message,
      );
    }
  }

  @override
  ExpressionEvaluationResult evaluate(String input) {
    _launcher ??= _resolveLauncher();
    if (_launcher == null) {
      _lastErrorMessage = 'ROOT/Cling command was not found on PATH.';
      return _errorResult(_lastErrorMessage);
    }
    return _evaluateViaCling(input);
  }

  @override
  String getLastErrorMessage() => _lastErrorMessage;

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.clingCxx,
    name: 'Cling C++ backend',
    description: capabilities.supportsClingCxx
        ? 'Uses ROOT/Cling subprocess evaluation for full C++ syntax.'
        : 'ROOT/Cling subprocess backend is unavailable on this platform.',
    capabilities: capabilities,
  );

  _Launcher? _resolveLauncher() {
    if (_commandExists('root')) {
      return const _Launcher(command: 'root', prefixArgs: <String>[]);
    }
    if (_commandExists('cling')) {
      return const _Launcher(command: 'cling', prefixArgs: <String>[]);
    }
    if (_canUseHostSpawn() && _hostCommandExists('root')) {
      return const _Launcher(
        command: 'flatpak-spawn',
        prefixArgs: <String>['--host', 'root'],
      );
    }
    if (_canUseHostSpawn() && _hostCommandExists('cling')) {
      return const _Launcher(
        command: 'flatpak-spawn',
        prefixArgs: <String>['--host', 'cling'],
      );
    }
    return null;
  }

  ExpressionEvaluationResult _evaluateViaCling(String input) {
    final launcher = _launcher ?? _resolveLauncher();
    if (launcher == null) {
      _lastErrorMessage = 'ROOT/Cling command was not found on PATH.';
      return _errorResult(_lastErrorMessage);
    }

    final script = _buildMacro(input);
    try {
      final args = <String>[
        ...launcher.prefixArgs,
        '-b',
        '-q',
        '-l',
        '-e',
        script,
      ];
      _logInvocation(launcher.command, args);
      final result = Process.runSync(launcher.command, args);
      final stdoutText = (result.stdout as Object?)?.toString() ?? '';
      final stderrText = (result.stderr as Object?)?.toString() ?? '';
      final combined = '$stdoutText\n$stderrText';
      _logResult(launcher.command, result.exitCode, stdoutText, stderrText);
      final parsed = _parseResult(combined);
      if (parsed != null) {
        _lastErrorMessage = '';
        return parsed;
      }

      _lastErrorMessage =
          _extractErrorMessage(combined) ??
          'ROOT/Cling subprocess evaluation failed with exit code ${result.exitCode}.';
      return _errorResult(_lastErrorMessage, rawOutput: combined);
    } catch (error) {
      _lastErrorMessage = error.toString();
      return _errorResult(_lastErrorMessage);
    }
  }

  String _buildMacro(String input) {
    return '''
#include <cstdint>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <string>
#include <type_traits>

template <typename T>
void pcalc_emit_metadata() {
  if constexpr (std::is_same_v<T, bool>) {
    std::cout << "__PCALC_KIND__=boolean" << std::endl;
    std::cout << "__PCALC_BITS__=1" << std::endl;
    std::cout << "__PCALC_SIGNED__=0" << std::endl;
  } else if constexpr (
      std::is_same_v<T, char> ||
      std::is_same_v<T, signed char> ||
      std::is_same_v<T, unsigned char>) {
    std::cout << "__PCALC_KIND__="
              << (std::is_same_v<T, unsigned char> ? "unsigned_char"
                  : std::is_same_v<T, signed char> ? "signed_char"
                                                   : "char")
              << std::endl;
    std::cout << "__PCALC_BITS__=" << (sizeof(T) * 8) << std::endl;
    std::cout << "__PCALC_SIGNED__=" << (std::is_signed_v<T> ? 1 : 0)
              << std::endl;
  } else if constexpr (std::is_integral_v<T>) {
    std::cout << "__PCALC_KIND__=integer" << std::endl;
    std::cout << "__PCALC_BITS__=" << (sizeof(T) * 8) << std::endl;
    std::cout << "__PCALC_SIGNED__=" << (std::is_signed_v<T> ? 1 : 0)
              << std::endl;
  } else if constexpr (std::is_floating_point_v<T>) {
    std::cout << "__PCALC_KIND__=floating" << std::endl;
    std::cout << "__PCALC_BITS__=" << (sizeof(T) * 8) << std::endl;
    std::cout << "__PCALC_SIGNED__=1" << std::endl;
  } else {
    std::cout << "__PCALC_KIND__=text" << std::endl;
  }
}

template <typename T>
void pcalc_print_value(const T& value) {
  if constexpr (std::is_same_v<T, bool>) {
    std::cout << (value ? 1 : 0);
  } else if constexpr (
      std::is_same_v<T, char> ||
      std::is_same_v<T, signed char> ||
      std::is_same_v<T, unsigned char>) {
    std::cout << static_cast<int>(value);
  } else if constexpr (std::is_integral_v<T>) {
    std::cout << static_cast<long long>(value);
  } else if constexpr (std::is_floating_point_v<T>) {
    std::cout << std::setprecision(17) << value;
  } else {
    std::cout << value;
  }
}

void pcalc_eval() {
  auto value = ($input);
  pcalc_emit_metadata<decltype(value)>();
  std::cout << "$_resultPrefix";
  pcalc_print_value(value);
  std::cout << std::endl;
}

pcalc_eval();
''';
  }

  ExpressionEvaluationResult? _parseResult(String output) {
    final lines = output.split(RegExp(r'\r?\n'));
    final metadata = <String, String>{};
    String? resultText;
    String? errorText;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith(_errorPrefix)) {
        errorText = trimmed.substring(_errorPrefix.length).trim();
        continue;
      }
      if (trimmed.startsWith(_resultPrefix)) {
        resultText = trimmed.substring(_resultPrefix.length).trim();
        continue;
      }
      if (trimmed.startsWith('__PCALC_KIND__=')) {
        metadata['kind'] = trimmed.substring('__PCALC_KIND__='.length).trim();
        continue;
      }
      if (trimmed.startsWith('__PCALC_BITS__=')) {
        metadata['bits'] = trimmed.substring('__PCALC_BITS__='.length).trim();
        continue;
      }
      if (trimmed.startsWith('__PCALC_SIGNED__=')) {
        metadata['signed'] = trimmed
            .substring('__PCALC_SIGNED__='.length)
            .trim();
        continue;
      }
    }

    if (errorText != null) {
      return _errorResult(errorText, rawOutput: output);
    }

    final resultLine = output
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.startsWith(_resultPrefix), orElse: () => '');
    if (resultLine.isEmpty || resultText == null) {
      return null;
    }
    final kindText = metadata['kind'] ?? '';
    final bits = int.tryParse(metadata['bits'] ?? '');
    final signed = metadata['signed'] == '1';

    if (kindText == 'text') {
      return ExpressionEvaluationResult(
        backendKind: BackendKind.clingCxx,
        kind: ExpressionValueKind.text,
        displayText: resultText,
        rawOutput: output,
      );
    }

    if (kindText == 'floating') {
      final numeric = double.tryParse(resultText);
      if (numeric == null) {
        return null;
      }
      return ExpressionEvaluationResult(
        backendKind: BackendKind.clingCxx,
        kind: ExpressionValueKind.floating,
        displayText: resultText,
        numericValue: numeric,
        integerValue: numeric.truncate(),
        bitWidth: bits,
        isSigned: signed,
        rawOutput: output,
      );
    }

    if (kindText == 'boolean') {
      final integer = int.tryParse(resultText);
      if (integer == null) {
        return null;
      }
      return ExpressionEvaluationResult(
        backendKind: BackendKind.clingCxx,
        kind: ExpressionValueKind.boolean,
        displayText: integer.toString(),
        numericValue: integer.toDouble(),
        integerValue: integer,
        bitWidth: bits ?? 1,
        isSigned: false,
        rawOutput: output,
      );
    }

    final integer = int.tryParse(resultText);
    if (integer != null) {
      return ExpressionEvaluationResult(
        backendKind: BackendKind.clingCxx,
        kind: ExpressionValueKind.integer,
        displayText: integer.toString(),
        numericValue: integer.toDouble(),
        integerValue: integer,
        bitWidth: bits ?? 32,
        isSigned: signed,
        rawOutput: output,
      );
    }

    final numeric = double.tryParse(resultText);
    if (numeric != null) {
      return ExpressionEvaluationResult(
        backendKind: BackendKind.clingCxx,
        kind: ExpressionValueKind.floating,
        displayText: resultText,
        numericValue: numeric,
        integerValue: numeric.truncate(),
        bitWidth: bits,
        isSigned: signed,
        rawOutput: output,
      );
    }

    return null;
  }

  ExpressionEvaluationResult _errorResult(String message, {String? rawOutput}) {
    return ExpressionEvaluationResult(
      backendKind: BackendKind.clingCxx,
      kind: ExpressionValueKind.error,
      displayText: message,
      errorMessage: message,
      rawOutput: rawOutput,
    );
  }

  String? _extractErrorMessage(String output) {
    final lines = output.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith(_errorPrefix)) {
        return trimmed.substring(_errorPrefix.length).trim();
      }
    }
    final stderrLines = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (stderrLines.isEmpty) {
      return null;
    }
    return stderrLines.last;
  }

  bool _commandExists(String command) {
    final result = Process.runSync('sh', [
      '-lc',
      'command -v ${_escapeForShell(command)} >/dev/null 2>&1',
    ]);
    return result.exitCode == 0;
  }

  bool _hostCommandExists(String command) {
    if (!_canUseHostSpawn()) {
      return false;
    }
    final result = Process.runSync('flatpak-spawn', [
      '--host',
      'sh',
      '-lc',
      'command -v ${_escapeForShell(command)} >/dev/null 2>&1',
    ]);
    return result.exitCode == 0;
  }

  bool _canUseHostSpawn() {
    return Platform.environment['FLATPAK_ID'] != null &&
        _commandExists('flatpak-spawn');
  }

  String _escapeForShell(String input) {
    if (input.isEmpty) {
      return "''";
    }
    return "'${input.replaceAll("'", r"'\''")}'";
  }

  void _logInvocation(String command, List<String> args) {
    if (!isDebugLoggingEnabled()) {
      return;
    }
    final rendered = _renderCommandLine(command, args);
    stdout.writeln('[pcalc express][backend] $rendered');
  }

  void _logResult(
    String command,
    int exitCode,
    String stdoutText,
    String stderrText,
  ) {
    if (!isDebugLoggingEnabled()) {
      return;
    }
    stdout.writeln('[pcalc express][backend] $command exited with $exitCode');
    if (stdoutText.trim().isNotEmpty) {
      stdout.writeln('[pcalc express][backend][stdout]');
      stdout.write(stdoutText);
      if (!stdoutText.endsWith('\n')) {
        stdout.writeln();
      }
    }
    if (stderrText.trim().isNotEmpty) {
      stdout.writeln('[pcalc express][backend][stderr]');
      stdout.write(stderrText);
      if (!stderrText.endsWith('\n')) {
        stdout.writeln();
      }
    }
  }

  String _renderCommandLine(String command, List<String> args) {
    final renderedArgs = args.map(_escapeForShell).join(' ');
    return [command, renderedArgs].join(' ').trimRight();
  }
}

final class _Launcher {
  const _Launcher({required this.command, required this.prefixArgs});

  final String command;
  final List<String> prefixArgs;
}
