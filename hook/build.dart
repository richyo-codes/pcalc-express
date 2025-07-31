import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageName = input.packageName;
    print(packageName);
    final cbuilder = CBuilder.library(
      name: "tinyexprpp_fii",
      assetName: 'tinyexprpp_fii.dart',
      includes: ['native/'],
      defines: {'TE_BITWISE_OPERATORS': '1'},
      sources: ['native/tinyexprpp_wrapper.cpp', 'native/tinyexpr.cpp'],
       flags: [
        '-std=c++20',
       ],
       language: Language.cpp
    );
    await cbuilder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}