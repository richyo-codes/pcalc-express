#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <numeric>

static_assert(sizeof(unsigned) == 4);
static_assert(std::popcount(0xF0u) == 4);
static_assert(std::countl_zero(1u) == 31);
static_assert(std::countr_zero(8u) == 3);
static_assert(std::rotl(1u, 3) == 8);
static_assert(std::rotr(8u, 3) == 1);
static_assert(std::bit_width(255u) == 8);
static_assert(std::byteswap(std::uint32_t{0x12345678}) == 0x78563412);
static_assert(std::gcd(12, 18) == 6);
static_assert(std::lcm(12, 18) == 36);
static_assert(std::midpoint(2, 10) == 6);
static_assert(std::clamp(99, 0, 10) == 10);
static_assert([] {
  std::array<int, 3> values{3, 1, 2};
  std::sort(values.begin(), values.end());
  return values[0] == 1 &&
         std::accumulate(values.begin(), values.end(), 0) == 6;
}());

int main() {
  // Volatile inputs prevent the probe from testing only folded constants.
  volatile double angle = 0.5;
  volatile double base = 9.0;
  volatile double exponent = 0.5;
  const double sine = std::sin(angle);
  const double power = std::pow(base, exponent);
  if (std::abs(sine - 0.479425538604203) > 1e-14 ||
      std::abs(power - 3.0) > 1e-14) return 1;
  std::printf("constexpr=pass sin=%.15f pow=%.15f\n", sine, power);

#ifdef PCALC_PROBE_FILES
  auto* input = std::fopen("/workspace/input.bin", "rb");
  if (!input) return 2;
  unsigned sum = 0;
  int byte;
  while ((byte = std::fgetc(input)) != EOF) sum += byte;
  if (std::ferror(input)) return 3;
  std::fclose(input);
  if (sum != 256) return 4;
  auto* counterFile = std::fopen("/workspace/counter.txt", "r");
  if (!counterFile) return 5;
  int counter = 0;
  if (std::fscanf(counterFile, "%d", &counter) != 1) return 6;
  std::fclose(counterFile);
  counterFile = std::fopen("/workspace/counter.txt", "w");
  if (!counterFile) return 7;
  if (std::fprintf(counterFile, "%d\n", ++counter) < 0) return 8;
  if (std::fclose(counterFile) != 0) return 9;
  std::printf("files=pass sum=%u counter=%d\n", sum, counter);
#endif
  return 0;
}
