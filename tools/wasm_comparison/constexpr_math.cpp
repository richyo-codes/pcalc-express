#include <cmath>
// A runtime math export is not evidence of constexpr support.
constexpr double value = std::sin(0.5);
static_assert(value > 0.47 && value < 0.49);
