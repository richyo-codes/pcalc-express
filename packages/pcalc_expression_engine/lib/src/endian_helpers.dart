// Calculator extensions, not imported libc functions. The Clang backend uses a
// fixed little-endian wasm32 expression target on every host platform.
// Bind names through C++ lexical scope; never rewrite calls or their arguments.
const endianHelperPrelude = r'''
constexpr auto bswap16 = [](auto value) constexpr -> uint16_t {
  static_assert(__is_integral(decltype(value)), "endian helpers require an integer");
  uint16_t x = static_cast<uint16_t>(value);
  return static_cast<uint16_t>((x >> 8) | (x << 8));
};
constexpr auto bswap32 = [](auto value) constexpr -> uint32_t {
  static_assert(__is_integral(decltype(value)), "endian helpers require an integer");
  uint32_t x = static_cast<uint32_t>(value);
  return ((x & 0xffu) << 24) | ((x & 0xff00u) << 8) |
         ((x >> 8) & 0xff00u) | ((x >> 24) & 0xffu);
};
constexpr auto bswap64 = [](auto value) constexpr -> uint64_t {
  static_assert(__is_integral(decltype(value)), "endian helpers require an integer");
  uint64_t x = static_cast<uint64_t>(value), result = 0;
  for (int i = 0; i < 8; ++i) { result = (result << 8) | (x & 0xffu); x >>= 8; }
  return result;
};
constexpr auto htole16 = [](auto value) constexpr -> uint16_t {
  static_assert(__is_integral(decltype(value)), "endian helpers require an integer");
  return static_cast<uint16_t>(value);
};
constexpr auto htole32 = [](auto value) constexpr -> uint32_t {
  static_assert(__is_integral(decltype(value)), "endian helpers require an integer");
  return static_cast<uint32_t>(value);
};
constexpr auto htole64 = [](auto value) constexpr -> uint64_t {
  static_assert(__is_integral(decltype(value)), "endian helpers require an integer");
  return static_cast<uint64_t>(value);
};
constexpr auto htons = bswap16, ntohs = bswap16;
constexpr auto htonl = bswap32, ntohl = bswap32;
constexpr auto htobe16 = bswap16, be16toh = bswap16;
constexpr auto htobe32 = bswap32, be32toh = bswap32;
constexpr auto htobe64 = bswap64, be64toh = bswap64;
constexpr auto le16toh = htole16;
constexpr auto le32toh = htole32;
constexpr auto le64toh = htole64;
''';

final _helperName = RegExp(
  r'\b(?:bswap(?:16|32|64)|htons|ntohs|htonl|ntohl|'
  r'hto(?:le|be)(?:16|32|64)|(?:le|be)(?:16|32|64)toh)\b',
);

bool usesEndianHelpers(String input) => _helperName.hasMatch(input);

String withEndianHelpers(String input) =>
    '[] {\n$endianHelperPrelude\nreturn (\n$input\n);\n}()';
