import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart' as ffi;

typedef tepp_get_last_error_message_native = Pointer<ffi.Utf8> Function();
typedef TeppGetLastErrorMessage = Pointer<ffi.Utf8> Function();

final TeppGetLastErrorMessage teppGetLastErrorMessage =
    _lib
        .lookup<NativeFunction<tepp_get_last_error_message_native>>(
          'tepp_get_last_error_message',
        )
        .asFunction();

String getLastErrorMessage() {
  final ptr = teppGetLastErrorMessage();
  return ptr.address == nullptr.address ? '' : ptr.toDartString();
}

typedef tepp_get_last_error_position_native = Int32 Function();
typedef TeppGetLastErrorPosition = int Function();

final TeppGetLastErrorPosition teppGetLastErrorPosition =
    _lib
        .lookup<NativeFunction<tepp_get_last_error_position_native>>(
          'tepp_get_last_error_position',
        )
        .asFunction();

int getLastErrorPosition() => teppGetLastErrorPosition();

typedef tepp_set_constant_native = Void Function(Pointer<ffi.Utf8>, Double);
typedef TeppSetConstant = void Function(Pointer<ffi.Utf8>, double);

final TeppSetConstant teppSetConstant =
    _lib
        .lookup<NativeFunction<tepp_set_constant_native>>('tepp_set_constant')
        .asFunction();

// typedef tepp_get_last_error_position_native = Int32 Function();
// typedef TeppGetLastErrorPosition = int Function();

// final TeppGetLastErrorPosition teppGetLastErrorPosition =
//     _lib
//         .lookup<NativeFunction<tepp_get_last_error_position_native>>(
//           'tepp_get_last_error_position',
//         )
//         .asFunction();

// int getLastErrorPosition() => teppGetLastErrorPosition();

void setCustomVariable(String name, double value) {
  final namePtr = name.toNativeUtf8();
  try {
    teppSetConstant(namePtr, value);
  } finally {
    ffi.calloc.free(namePtr);
  }
}

typedef tepp_eval_native = Double Function(Pointer<ffi.Utf8>);
typedef TeppEval = double Function(Pointer<ffi.Utf8>);

final DynamicLibrary _lib = _loadLibrary();

DynamicLibrary _loadLibrary() {
  List<String> _possiblePaths() {
    if (Platform.isAndroid) {
      return [
        // Path when running as packaged APK
        path.join('libtinyexprpp.so'),
      ];
    } else if (Platform.isLinux) {
      return [
        path.join(
          Directory.current.path,
          'assets',
          'linux',
          'libtinyexprpp.so',
        ),
      ];
    } else if (Platform.isMacOS) {
      return ['libtinyexprplusplus.dylib'];
    } else if (Platform.isWindows) {
      return ['tinyexprplusplus.dll'];
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  final paths = _possiblePaths();
  for (final libPath in paths) {
    try {
      return DynamicLibrary.open(libPath);
    } catch (_) {
      // Try next path
    }
  }
  throw Exception(
    'Failed to load tinyexpr-plusplus library. Tried: ${paths.join(', ')}',
  );
}

final TeppEval teppEval =
    _lib.lookup<NativeFunction<tepp_eval_native>>('tepp_eval').asFunction();

double evaluateExpression(String expression) {
  final exprPtr = expression.toNativeUtf8();
  try {
    return teppEval(exprPtr);
  } finally {
    ffi.calloc.free(exprPtr);
  }
}
