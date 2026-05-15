import 'dart:io';

bool get canUseRoot => _commandExists('root');

bool get canUseCling => _commandExists('cling') || canUseRoot;

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
