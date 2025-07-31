import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart' as ffitype;

import 'dart:ffi' as ffi;



String getLastErrorMessage() {
  final ptr = tepp_get_last_error_message().cast<ffitype.Utf8>();
  return ptr.address == nullptr.address ? '' : ptr.toDartString();
}

int getLastErrorPosition() => tepp_get_last_error_position();

typedef tepp_set_constant_native = Void Function(Pointer<ffitype.Utf8>, Double);
typedef TeppSetConstant = void Function(Pointer<ffitype.Utf8>, double);


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
  final exprPtr = name.toNativeUtf8().cast<ffi.Void>();
  final namePtr = name.toNativeUtf8().cast<ffi.Char>();
  try {
    tepp_set_constant(exprPtr, namePtr, value);
  } finally {
    ffitype.calloc.free(namePtr);
  }
}


double evaluateExpression(String expression) {
  final exprPtr = expression.toNativeUtf8();
  try {
    return tepp_eval(exprPtr as Pointer<Char>);
  } 
  catch(e) {
    print(e);

    return double.nan;
  }
  finally {
    ffitype.calloc.free(exprPtr);
  }
}


/// Evaluate an expression
@ffi.Native<ffi.Double Function(ffi.Pointer<ffi.Char>)>()
external double tepp_eval(
  ffi.Pointer<ffi.Char> expression,
);

/// Compile an expression
@ffi.Native<
    ffi.Pointer<ffi.Void> Function(
        ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Int>)>()
external ffi.Pointer<ffi.Void> tepp_compile(
  ffi.Pointer<ffi.Char> expression,
  ffi.Pointer<ffi.Int> error,
);

/// Evaluate a compiled expression
@ffi.Native<ffi.Double Function(ffi.Pointer<ffi.Void>)>()
external double tepp_eval_compiled(
  ffi.Pointer<ffi.Void> compiled_expr,
);

/// Free a compiled expression
@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Void>)>()
external void tepp_free(
  ffi.Pointer<ffi.Void> compiled_expr,
);

/// Set a constant variable
@ffi.Native<
    ffi.Void Function(
        ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>, ffi.Double)>()
external void tepp_set_constant(
  ffi.Pointer<ffi.Void> compiled_expr,
  ffi.Pointer<ffi.Char> name,
  double value,
);

/// Get a constant variable
@ffi.Native<ffi.Double Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>)>()
external double tepp_get_constant(
  ffi.Pointer<ffi.Void> compiled_expr,
  ffi.Pointer<ffi.Char> name,
);

/// Returns the last error message (null-terminated string, valid until next call)
@ffi.Native<ffi.Pointer<ffi.Char> Function()>()
external ffi.Pointer<ffi.Char> tepp_get_last_error_message();

/// Returns the last error position (character index, or -1 if none)
@ffi.Native<ffi.Int Function()>()
external int tepp_get_last_error_position();

