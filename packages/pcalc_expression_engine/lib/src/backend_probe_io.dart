import 'dart:ffi';
import 'dart:io';

bool get canUseClangConstexpr =>
    Platform.isLinux ||
    (Platform.isAndroid && Abi.current() == Abi.androidArm64);

bool get canUseRoot => _commandExists('root') || _hostCommandExists('root');

bool get canUseCling =>
    _commandExists('cling') || canUseRoot || _hostCommandExists('cling');

bool _commandExists(String command) {
  final result = Process.runSync('sh', [
    '-lc',
    'command -v ${_escapeForShell(command)} >/dev/null 2>&1',
  ]);
  return result.exitCode == 0;
}

bool _hostCommandExists(String command) {
  if (Platform.environment['FLATPAK_ID'] == null) {
    return false;
  }
  if (!_commandExists('flatpak-spawn')) {
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

String _escapeForShell(String input) {
  if (input.isEmpty) {
    return "''";
  }
  return "'${input.replaceAll("'", r"'\''")}'";
}
