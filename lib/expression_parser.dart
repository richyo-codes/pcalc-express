//import 'package:math_expressions/math_expressions.dart';

import 'package:expressions/expressions.dart';

const cConstants = {
  "INT_MAX": 2147483647,
  "INT_MIN": -2147483648,
  "UINT_MAX": 4294967295,
  "LONG_MAX": 9223372036854775807,
  "LONG_MIN": -9223372036854775808,
  //"ULONG_MAX": 18446744073709551615,
  "CHAR_BIT": 8,
  "SCHAR_MAX": 127,
  "SCHAR_MIN": -128,
  "UCHAR_MAX": 255,
  "SHRT_MAX": 32767,
  "SHRT_MIN": -32768,
  "USHRT_MAX": 65535,
};

const cSizes = {
  "sizeof(char)": 1,
  "sizeof(short)": 2,
  "sizeof(int)": 4,
  "sizeof(long)": 8,
  "sizeof(long long)": 8,
  "sizeof(float)": 4,
  "sizeof(double)": 8,
  "sizeof(long double)": 16,
};

String preprocessExpression(String input) {
  return input
      .replaceAllMapped(
        RegExp(r"(\d+)\s*<<\s*(\d+)"),
        (match) => "left_shift(${match[1]}, ${match[2]})",
      )
      .replaceAllMapped(
        RegExp(r"(\d+)\s*>>\s*(\d+)"),
        (match) => "right_shift(${match[1]}, ${match[2]})",
      )
      .replaceAllMapped(
        RegExp(r"(\d+)\s*&\s*(\d+)"),
        (match) => "bit_and(${match[1]}, ${match[2]})",
      )
      .replaceAllMapped(
        RegExp(r"(\d+)\s*\|\s*(\d+)"),
        (match) => "bit_or(${match[1]}, ${match[2]})",
      )
      .replaceAllMapped(
        RegExp(r"(\d+)\s*\^\s*(\d+)"),
        (match) => "bit_xor(${match[1]}, ${match[2]})",
      )
      .replaceAllMapped(RegExp(r"~\s*(\d+)"), (match) => "bit_not(${match[1]})")
      .replaceAllMapped(RegExp(r"!\s*(\d+)"), (match) => "lnot(${match[1]})")
      .replaceAllMapped(
        RegExp(r"(\d+)\s*\||\s*(\d+)"),
        (match) => "lor(${match[1]}, ${match[2]})",
      )
      .replaceAllMapped(
        RegExp(r"(\d+)\s*\&&\s*(\d+)"),
        (match) => "land(${match[1]}, ${match[2]})",
      );
}

// void parse(String inputText) {
//   String input = preprocessExpression(inputText);
//   try {
//     var expression = Expression.parse(input);
//     var context = {
//       //"sqrt": sqrt,
//       // "square": (num x) => x * x,
//       // "mod": (num a, num b) => a % b,
//       // "abs": (num x) => x.abs(),
//       //"pow": pow,
//       // "ceil": (num x) => x.ceil(),
//       // "floor": (num x) => x.floor(),
//       // "trunc": (num x) => x.truncate(),
//       // "round": (num x) => x.round(),
//       //"log": log,
//       //"exp": exp,
//       "bit_and": (int a, int b) => a & b,
//       "bit_or": (int a, int b) => a | b,
//       "bit_xor": (int a, int b) => a ^ b,
//       "bit_not": (int a) => ~a,
//       "left_shift": (int a, int b) => a << b,
//       "right_shift": (int a, int b) => a >> b,
//       //...cConstants,
//       //...cSizes,
//     };

//     final evaluator = const ExpressionEvaluator();
//     var eval = evaluator.eval(expression, context);

//     int intValue = eval.toInt();
//     double floatValue = eval.toDouble();

//     // setState(() {
//     //   decimalResult = intValue.toString();
//     //   hexResult = intValue.toRadixString(16).toUpperCase();
//     //   binaryResult = intValue.toRadixString(2);
//     //   floatResult = floatValue.toString();
//     //   history.add(
//     //     "$input = $decimalResult (Dec) | $floatResult (Float) | $hexResult (Hex) | $binaryResult (Bin)",
//     //   );
//   } catch (e) {
//     return "Error: ${e.toString()}";
//   }
// }
