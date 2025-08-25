import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'dart:io' show Platform, Process;

Future<String> _detectCompilerFamily(CCompilerConfig? cc) async {
  if (cc == null) {
    return "unknown";
  }

  final cxx = cc.compiler.path;

  if (cxx.contains("cl.exe") || cxx.contains("msvc")) return 'msvc';

  return "unknown";
}

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    final codeCfg = input.config?.code;
    final cc = codeCfg?.cCompiler; // e.g. "/usr/bin/clang" or "cl"
    final compilerFamily = await _detectCompilerFamily(cc);

    // ---------- Flags ----------
    final flags = <String>[];
    switch (compilerFamily) {
      case 'msvc':
        // MSVC-style flags
        flags.addAll([
          '/std:c++20',
          // Optional but common for DLLs:
          // '/MD',     // link against the dynamic CRT
          // '/EHsc',   // standard C++ exceptions
        ]);
        break;
      case 'clang':
      case 'gcc':
      default:
        // POSIX-style flags (Clang/GCC; includes Android NDK Clang)
        flags.addAll(['-std=c++20', '-fPIC']);
        break;
    }

    // ---------- Defines ----------
    final defines = <String, String>{'TE_BITWISE_OPERATORS': '1'};

    // Only add Windows/MSVC-specific defines when we’re actually using MSVC.
    // (If you’re on Windows but targeting Android via NDK Clang, do NOT set _WIN32.)
    if (compilerFamily == 'msvc') {
      defines.addAll({'WIN_EXPORT': '1', '_WIN32': '1'});
    }

    // If you know you’re targeting Android with NDK Clang, you can also add:
    // defines['__ANDROID__'] = '1';
    // and pass API level via flags like: -D__ANDROID_API__=24 (if needed by your setup)

    final cbuilder = CBuilder.library(
      name: 'tinyexprpp_fii',
      assetName: 'tinyexprpp_fii.dart',
      includes: ['native/'],
      defines: defines,
      sources: ['native/tinyexprpp_wrapper.cpp', 'native/tinyexpr.cpp'],
      flags: flags,
      language: Language.cpp,
    );

    await cbuilder.run(
      input: input,
      output: output,
      logger:
          (Logger('')
            ..level = Level.ALL
            ..onRecord.listen((r) => print(r.message))),
    );
  });
}
