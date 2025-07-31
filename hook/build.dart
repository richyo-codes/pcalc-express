import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'dart:io' show Platform;

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageName = input.packageName;

    var flags = ['-std=c++20'];

    if (Platform.isWindows) {
      flags = ['/std:c++20'];
    }

    var defines = {'TE_BITWISE_OPERATORS': '1'};

    if (Platform.isWindows) {
      defines.addAll({'WIN_EXPORT':'1', '_WIN32': '1'});
    }

    final cbuilder = CBuilder.library(
      name: "tinyexprpp_fii",
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
          Logger('')
            ..level = Level.ALL
            ..onRecord.listen((record) => print(record.message)),
    );
  });
}
