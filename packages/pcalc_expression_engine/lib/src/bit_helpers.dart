// Calculator extensions, deliberately outside namespace std. Unsigned argument
// types select the bit width; casts let callers request 8/16/32/64-bit behavior.
const bitHelperPrelude = r'''
constexpr auto popcount = [](auto value) constexpr -> int {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  int count = 0;
  while (value) { value &= value - 1; ++count; }
  return count;
};
constexpr auto countl_zero = [](auto value) constexpr -> int {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  constexpr int width = sizeof(value) * 8;
  uint64_t x = value;
  int count = 0;
  for (int i = width - 1; i >= 0 && !(x & (uint64_t{1} << i)); --i) ++count;
  return count;
};
constexpr auto countr_zero = [](auto value) constexpr -> int {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  constexpr int width = sizeof(value) * 8;
  int count = 0;
  while (count < width && !(value & 1)) { ++count; value >>= 1; }
  return count;
};
constexpr auto countl_one = [](auto value) constexpr -> int {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  constexpr int width = sizeof(value) * 8;
  uint64_t x = value;
  int count = 0;
  for (int i = width - 1; i >= 0 && (x & (uint64_t{1} << i)); --i) ++count;
  return count;
};
constexpr auto countr_one = [](auto value) constexpr -> int {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  constexpr int width = sizeof(value) * 8;
  int count = 0;
  while (count < width && (value & 1)) { ++count; value >>= 1; }
  return count;
};
constexpr auto has_single_bit = [](auto value) constexpr -> bool {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  return value != 0 && (value & (value - 1)) == 0;
};
constexpr auto bit_width = [](auto value) constexpr -> int {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  int width = 0;
  while (value) { ++width; value >>= 1; }
  return width;
};
constexpr auto bit_floor = [](auto value) constexpr -> decltype(value) {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  if (value == 0) return 0;
  uint64_t result = 1;
  while (value >>= 1) result <<= 1;
  return static_cast<decltype(value)>(result);
};
constexpr auto bit_ceil = [](auto value) constexpr -> decltype(value) {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  constexpr int width = sizeof(value) * 8;
  // Executing trap is not a constant expression; reject overflow without
  // requiring C++ exceptions (disabled in the embedded evaluator).
  if (value > (uint64_t{1} << (width - 1))) __builtin_trap();
  uint64_t result = 1;
  while (result < value) result <<= 1;
  return static_cast<decltype(value)>(result);
};
constexpr auto rotl = [](auto value, auto amount) constexpr -> decltype(value) {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  static_assert(__is_integral(decltype(amount)) && !__is_same(decltype(amount), bool), "rotation count must be an integer, not bool");
  constexpr int width = sizeof(value) * 8;
  int shift = static_cast<int>(amount % static_cast<decltype(amount)>(width));
  if (shift < 0) shift += width;
  if (shift == 0) return value;
  uint64_t x = value;
  return static_cast<decltype(value)>((x << shift) | (x >> (width - shift)));
};
constexpr auto rotr = [](auto value, auto amount) constexpr -> decltype(value) {
  static_assert(__is_integral(decltype(value)) && __is_unsigned(decltype(value)) && !__is_same(decltype(value), bool), "bit helpers require an unsigned integer, not bool");
  static_assert(__is_integral(decltype(amount)) && !__is_same(decltype(amount), bool), "rotation count must be an integer, not bool");
  constexpr int width = sizeof(value) * 8;
  int shift = static_cast<int>(amount % static_cast<decltype(amount)>(width));
  if (shift < 0) shift += width;
  if (shift == 0) return value;
  uint64_t x = value;
  return static_cast<decltype(value)>((x >> shift) | (x << (width - shift)));
};
''';

final _helperName = RegExp(
  r'\b(?:popcount|count[lr]_(?:zero|one)|has_single_bit|bit_(?:width|floor|ceil)|rot[lr])\b',
);

bool usesBitHelpers(String input) => _helperName.hasMatch(input);
