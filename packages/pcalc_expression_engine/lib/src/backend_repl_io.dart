import 'dart:io';

import 'backend.dart';

final class RootFormulaBackend implements ExpressionBackend {
  RootFormulaBackend({
    required this.capabilities,
    required this.isDebugLoggingEnabled,
  });

  static const String _resultPrefix = '__PCALC_RESULT__=';
  static const String _errorPrefix = '__PCALC_ERROR__=';

  final BackendCapabilities capabilities;
  final bool Function() isDebugLoggingEnabled;
  String _lastErrorMessage = '';

  @override
  Future<void> initialize() async {
    if (!capabilities.hasRoot) {
      throw UnsupportedError('ROOT is not available on this platform.');
    }

    final result = _evaluateFormula('1 + 1');
    if (result.isError) {
      final message = _lastErrorMessage;
      throw StateError(
        message.isEmpty
            ? 'ROOT formula backend failed its startup probe.'
            : message,
      );
    }
  }

  @override
  ExpressionEvaluationResult evaluate(String input) => _evaluateFormula(input);

  @override
  String getLastErrorMessage() => _lastErrorMessage;

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.rootFormula,
    name: 'ROOT formula backend',
    description: capabilities.hasRoot
        ? 'Uses ROOT TFormula through a subprocess for formula-only math.'
        : 'ROOT formula backend is unavailable on this platform.',
    capabilities: capabilities,
  );

  ExpressionEvaluationResult _evaluateFormula(String input) {
    final command = _resolveRootCommand();
    if (command == null) {
      _lastErrorMessage = 'ROOT is not available on PATH.';
      return _errorResult('ROOT is not available on PATH.');
    }

    final script = _buildFormulaScript(input);
    final args = <String>['-b', '-q', '-l', '-e', script];
    _logInvocation(command, args);

    try {
      final result = Process.runSync(command, args);
      final stdoutText = (result.stdout as Object?)?.toString() ?? '';
      final stderrText = (result.stderr as Object?)?.toString() ?? '';
      final combined = '$stdoutText\n$stderrText';
      _logResult(command, result.exitCode, stdoutText, stderrText);

      final parsed = _parseResult(combined);
      if (parsed != null) {
        _lastErrorMessage = '';
        return parsed;
      }

      _lastErrorMessage =
          _extractErrorMessage(combined) ??
          'ROOT subprocess evaluation failed with exit code ${result.exitCode}.';
      return _errorResult(_lastErrorMessage, rawOutput: combined);
    } catch (error) {
      _lastErrorMessage = error.toString();
      return _errorResult(_lastErrorMessage);
    }
  }

  String? _resolveRootCommand() {
    if (_commandExists('root')) {
      return 'root';
    }
    return null;
  }

  String _buildFormulaScript(String input) {
    final escaped = _escapeForCString(input);
    return '''
#include <TFormula.h>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>
#include <string>

void pcalc_eval() {
  const std::string expr = "$escaped";
  TFormula formula("pcalc", expr.c_str());
  const double value = formula.Eval(0.0);
  if (std::isfinite(value)) {
    std::cout << "$_resultPrefix" << std::setprecision(17) << value << std::endl;
    return;
  }
  std::cout << "$_errorPrefix" << "expression evaluated to non-finite value" << std::endl;
}

pcalc_eval();
''';
  }

  ExpressionEvaluationResult? _parseResult(String output) {
    final resultLine = output
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.startsWith(_resultPrefix), orElse: () => '');
    if (resultLine.isEmpty) {
      return null;
    }
    final valueText = resultLine.substring(_resultPrefix.length).trim();
    final value = double.tryParse(valueText);
    if (value == null) {
      return null;
    }
    final isWhole = value.isFinite && value.truncateToDouble() == value;
    final integerValue = isWhole ? value.toInt() : value.truncate();
    return ExpressionEvaluationResult(
      backendKind: BackendKind.rootFormula,
      kind: isWhole
          ? ExpressionValueKind.integer
          : ExpressionValueKind.floating,
      displayText: value.toString(),
      numericValue: value,
      integerValue: integerValue,
      bitWidth: 32,
      isSigned: true,
      rawOutput: output,
    );
  }

  ExpressionEvaluationResult _errorResult(String message, {String? rawOutput}) {
    return ExpressionEvaluationResult(
      backendKind: BackendKind.rootFormula,
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

  String _escapeForCString(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      switch (rune) {
        case 0x5C:
          buffer.write(r'\\');
        case 0x22:
          buffer.write(r'\"');
        case 0x0A:
          buffer.write(r'\n');
        case 0x0D:
          buffer.write(r'\r');
        case 0x09:
          buffer.write(r'\t');
        default:
          buffer.write(String.fromCharCode(rune));
      }
    }
    return buffer.toString();
  }

  bool _commandExists(String command) {
    final result = Process.runSync('sh', [
      '-lc',
      'command -v ${_escapeForShell(command)} >/dev/null 2>&1',
    ]);
    return result.exitCode == 0;
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
    stdout.writeln('[pcalc express][backend] $command ${args.join(' ')}');
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
}
