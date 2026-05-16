import 'dart:io';

import 'backend.dart';

final class ClingReplBackend implements ExpressionBackend {
  ClingReplBackend({required this.capabilities});

  static const String _resultPrefix = '__PCALC_RESULT__=';
  static const String _errorPrefix = '__PCALC_ERROR__=';

  final BackendCapabilities capabilities;
  String _lastErrorMessage = '';
  String? _command;

  @override
  Future<void> initialize() async {
    if (!capabilities.supportsCling) {
      throw UnsupportedError(
        'ROOT/Cling backend is not available on this platform.',
      );
    }

    final command = _resolveCommand();
    if (command == null) {
      throw StateError('ROOT is not available on PATH.');
    }

    _command = command;
    final probeResult = _evaluateViaRoot('1 + 1');
    if (probeResult.isNaN) {
      final message = _lastErrorMessage;
      throw StateError(
        message.isEmpty
            ? 'ROOT/Cling backend failed its startup probe.'
            : message,
      );
    }
  }

  @override
  double evaluate(String input) {
    if (_command == null) {
      _command = _resolveCommand();
      if (_command == null) {
        _lastErrorMessage = 'ROOT is not available on PATH.';
        return double.nan;
      }
    }
    return _evaluateViaRoot(input);
  }

  @override
  String getLastErrorMessage() => _lastErrorMessage;

  @override
  ExpressionEngineInfo get info => ExpressionEngineInfo(
    kind: BackendKind.clingRepl,
    name: 'ROOT formula backend',
    description: capabilities.supportsCling
        ? 'Uses ROOT subprocess evaluation as an exploratory Linux backend.'
        : 'ROOT subprocess backend is unavailable on this platform.',
    capabilities: capabilities,
  );

  String? _resolveCommand() {
    if (_commandExists('root')) {
      return 'root';
    }
    if (_commandExists('cling')) {
      return 'cling';
    }
    return null;
  }

  double _evaluateViaRoot(String input) {
    final command = _command ?? _resolveCommand();
    if (command == null) {
      _lastErrorMessage = 'ROOT/Cling command was not found on PATH.';
      return double.nan;
    }

    final script = _buildMacro(input);
    try {
      final args = switch (command) {
        'root' => <String>['-b', '-q', '-l', '-e', script],
        'cling' => <String>['-b', '-q', '-l', '-e', script],
        _ => <String>['-b', '-q', '-l', '-e', script],
      };
      _logInvocation(command, args);
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
      return double.nan;
    } catch (error) {
      _lastErrorMessage = error.toString();
      return double.nan;
    }
  }

  String _buildMacro(String input) {
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

  double? _parseResult(String output) {
    final resultLine = output
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.startsWith(_resultPrefix), orElse: () => '');
    if (resultLine.isEmpty) {
      return null;
    }
    final valueText = resultLine.substring(_resultPrefix.length).trim();
    return double.tryParse(valueText);
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
    if (!backendDebugLoggingEnabled) {
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
    if (!backendDebugLoggingEnabled) {
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
