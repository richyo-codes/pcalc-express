#include "pcalc_constexpr/evaluator.h"
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <string>

int checks = 0;
pcalc_constexpr_result evaluate(int language, const char* expression) {
  pcalc_constexpr_result result{};
  pcalc_constexpr_evaluate_language(language, expression, std::strlen(expression), &result);
  return result;
}
void require(bool condition, const char* expression, const pcalc_constexpr_result& result) {
  ++checks;
  if (!condition) {
    std::cerr << "FAIL: " << expression << " value=" << result.integer_value
              << " error=" << result.error_message << '\n';
    std::exit(1);
  }
}
void integer(int language, const char* expression, const char* value, int width = 32, bool isSigned = true) {
  const auto result = evaluate(language, expression);
  require(result.status == 0 && std::string(result.integer_value) == value &&
          result.bit_width == width && bool(result.is_signed) == isSigned, expression, result);
}
void rejected(int language, const char* expression) {
  const auto result = evaluate(language, expression);
  require(result.status != 0 && std::strlen(result.error_message) > 0, expression, result);
}

int main() {
  for (const auto language : {PCALC_CONSTEXPR_CXX20, PCALC_CONSTEXPR_CXX23}) {
    integer(language, "std::popcount(0xF0u)", "4");
    integer(language, "std::countl_zero(0u)", "32");
    integer(language, "std::countr_zero(8u)", "3");
    integer(language, "std::rotl(1u, 35)", "8", 32, false);
    integer(language, "std::rotr(8u, 3)", "1", 32, false);
    integer(language, "std::bit_width(255u)", "8");
    integer(language, "std::gcd(-12, 18)", "6");
    integer(language, "std::lcm(12, 18)", "36");
    integer(language, "std::midpoint(2147483647, 2147483645)", "2147483646");
    integer(language, "std::clamp(99, 0, 10)", "10");
    integer(language, "[] { std::vector<int> v{3, 1, 2}; std::sort(v.begin(), v.end()); return v.front(); }()", "1");
    integer(language, "[] { std::vector<int> v; for (int i = 0; i < 100; ++i) v.push_back(i); return std::accumulate(v.begin(), v.end(), 0); }()", "4950");
    integer(language, "[] { std::vector<int> v{1, 2, 3}; v.insert(v.begin() + 1, 9); v.erase(v.begin()); v.pop_back(); return v.front() + v.back(); }()", "11");
    integer(language, "[] { std::vector<int> v; v.reserve(8); v.resize(3, 7); auto copy = v; v.clear(); return copy[2]; }()", "7");
    integer(language, "[] { std::vector<uint64_t> v{0xffffffffffffffffULL}; return v.front() == 0xffffffffffffffffULL ? 1 : 0; }()", "1");
    integer(language, "[] { std::vector<int> v; return v.empty() ? 1 : 0; }()", "1");
    rejected(language, "[] { std::vector<int> v{1}; return v.at(2); }()");
    rejected(language, "[] { std::vector<int> v{1}; return v[2]; }()");
    rejected(language, "std::vector<int>{1, 2}");
    // The header exists, but this pinned libc++ deque is not constexpr-capable.
    integer(language, "sizeof(std::deque<int>) > 0 ? 1 : 0", "1");
    rejected(language, "[] { std::deque<int> q{2}; q.push_front(1); q.push_back(3); return q.front() + q.back(); }()");
    integer(language, "[] { std::array<int, 3> a{3, 1, 2}; std::sort(a.begin(), a.end()); return a[0]; }()", "1");
    integer(language, "[] { int a[]{1, 2, 3}; return std::accumulate(a, a + 3, 0); }()", "6");
    integer(language, "std::numeric_limits<unsigned long long>::max()", "18446744073709551615", 64, false);
    integer(language, "[] { int a = 1, b = 2; return &std::min(a,b) == &a ? 1 : 0; }()", "1");
    integer(language, "std::numeric_limits<double>::epsilon() > 0 ? 1 : 0", "1");
    integer(language, "std::numbers::pi > 3.14 ? 1 : 0", "1");
    integer(language, "(unsigned char)270", "14", 8, false);
    integer(language, "[] { auto factorial = [](auto&& self, unsigned n) constexpr -> unsigned long long { return n <= 1 ? 1 : n * self(self, n - 1); }; return factorial(factorial, 10); }()", "3628800", 64, false);
    rejected(language, "std::popcount(-1)");
    rejected(language, "std::gcd(1.0, 2.0)");
    rejected(language, "#include <cstdio>\n1");
    rejected(language, "1); int injected = 2; (");
    rejected(language, "[] { while (true) {} return 1; }()");
  }
  integer(PCALC_CONSTEXPR_CXX23, "std::byteswap(uint32_t{0x12345678})", "2018915346", 32, false);
  rejected(PCALC_CONSTEXPR_CXX20, "std::byteswap(uint32_t{0x12345678})");
  rejected(PCALC_CONSTEXPR_CXX17, "std::popcount(1u)");
  rejected(PCALC_CONSTEXPR_CXX17, "[] { std::vector<int> v{1}; return v.front(); }()");
  rejected(PCALC_CONSTEXPR_CXX17, "[] { std::deque<int> q{1}; return q.front(); }()");
  integer(PCALC_CONSTEXPR_CXX17, "std::gcd(12,18)", "6");
  for (int language = PCALC_CONSTEXPR_C99; language <= PCALC_CONSTEXPR_C23; ++language)
    integer(language, "1 + 2 * 3", "7");
  std::cout << checks << " embedded evaluator checks passed\n";
  for (const auto* expression : {"abs(-42)", "std::abs(-42.5)", "sqrt(81.0)",
                                "pow(2, 10)", "sin(pi / 2)", "std::pi", "INT_MAX"}) {
    auto result = evaluate(PCALC_CONSTEXPR_CXX20, expression);
    std::cout << "legacy probe: " << expression << " => "
              << (result.status ? "rejected: " : "accepted: ")
              << (result.status ? result.error_message : result.integer_value) << '\n';
  }
}
