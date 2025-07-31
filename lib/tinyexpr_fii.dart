// import 'dart:ffi';
// import 'dart:io';
// import 'package:ffi/ffi.dart' as ffi;

// typedef te_interp_native = Double Function(Pointer<ffi.Utf8>, Int32);
// typedef TeInterp = double Function(Pointer<ffi.Utf8>, int);

// final DynamicLibrary _lib = () {
//   if (Platform.isMacOS) {
//     return DynamicLibrary.open('libtinyexpr.dylib');
//   } else if (Platform.isLinux) {
//     return DynamicLibrary.open('libtinyexpr.so');
//   } else if (Platform.isWindows) {
//     return DynamicLibrary.open('tinyexpr.dll');
//   } else {
//     throw UnsupportedError('Unsupported platform');
//   }
// }();

// final TeInterp teInterp =
//     _lib.lookup<NativeFunction<te_interp_native>>('te_interp').asFunction();
