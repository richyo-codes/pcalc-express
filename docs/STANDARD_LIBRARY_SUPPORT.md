# Standard-library support tracker

Last audited: 2026-09-21. Evaluator: `dart_clang_constexpr`, revision
`483cd8144573cc3b0975c285ad2e34013191dee6`.

## What “supported” means

The calculator does **not** expose all of libc or libc++. Its current Clang
evaluator supplies a handwritten C++ prelude, evaluates a single constant
expression, and returns a numeric result. It supplies no standard-library
headers. C modes do not receive the C++ prelude.

Library code linked into the evaluator's own executable/Wasm module is separate
from functions available inside user expressions. Exporting a Wasm symbol does
not make Clang's constant evaluator able to execute that symbol.

Status vocabulary:

- **Partial helper:** a calculator implementation exists, not the upstream
  libc/libc++ implementation or a claim of full standard behavior.
- **Missing:** no corresponding public definition/header is supplied.
- **Runtime:** requires execution facilities outside the current constexpr path.
- **Candidate:** proposed upstream-header support, not implemented yet.

“Wasm pass” below means representative expressions passed through the pinned
package's shipped Wasm module in Node. It does not establish edge-case accuracy,
all overloads, browser integration, or native/Android parity. Native source was
inspected; native and Android runtime verification remain pending for this audit.

## Current exposed helpers

| API | Source implementation | Wasm C++20 probe | Important gaps |
| --- | --- | --- | --- |
| `abs`, `std::abs` | Partial helper | `abs(-42)` passes | Selected numeric overloads; not a full `<cstdlib>`/`<cmath>` API |
| `ceil`, `floor`, `trunc`, `round` and `std::` forms | Partial helper | Ordinary positive/negative examples pass | Implementation casts through `long long`; large values, nonfinite values, and signed zero need coverage |
| `sqrt`, `std::sqrt` | Partial helper, recursive approximation | `sqrt(81.0)` passes | No libm accuracy guarantee; domain and convergence limits need coverage |
| `pow`, `std::pow` | Partial helper, integral exponents | `pow(2, 10)` passes | **`pow(9.0, 0.5)` is rejected**; selected overloads only |
| `sin`, `cos`, `tan` and `std::` forms | Partial helper, finite series | Zero-angle examples pass | Not upstream libm; large arguments and numerical accuracy need coverage |
| `fmin`, `fmax` and `std::` forms | Partial helper, comparisons | Ordinary finite examples pass | NaN and signed-zero semantics are not established |
| `std::min`, `std::max`, `std::clamp` | Partial helper | Simple scalar examples pass | Return by value, unlike standard reference overloads; comparator/initializer-list overloads absent |
| `std::numeric_limits<T>` | Partial helper | `numeric_limits<int>::max()` passes | Only selected integer specializations and `min`/`max`/`lowest`; floating specialization probe rejected |
| `pi`, `std::pi`, `std::numbers::pi` | Calculator constants | Source inspected | `std::pi` is a calculator extension; `numbers::pi` uses `long double` here, unlike the standard double constant; no `pi_v<T>` family |
| `int8_t`…`uint64_t` | Calculator aliases | Source inspected | Global aliases; not complete `<stdint.h>` or `<cstdint>` support |
| `CHAR_BIT`, selected `INT*_MIN/MAX`, `UINT*_MAX`, `INT_MIN/MAX`, `UINT_MAX`, `LLONG_MIN/MAX`, `ULLONG_MAX` | Calculator macros | Source inspected | Partial set, C++ prelude only; not complete limits headers |

Do not promote a helper to “libc++ supported” just because its ordinary numeric
result matches. Implementation provenance, types, overloads, and language gates
are part of the support contract.

## Priority C++ additions

### App-supplied endian helpers

The Clang adapter now supplies these **calculator constexpr extensions** in
C++17/20/23, independently of the real-libc++ prototype. They are not linked
socket functions and do not establish libc header support.

| Helpers | Behavior |
| --- | --- |
| `htons`, `ntohs` | Host/network conversion, unsigned 16-bit result |
| `htonl`, `ntohl` | Host/network conversion, unsigned 32-bit result |
| `bswap16`, `bswap32`, `bswap64` | Unconditional byte reversal |
| `htobe16/32/64`, `be16/32/64toh` | Host/big-endian conversion |
| `htole16/32/64`, `le16/32/64toh` | Host/little-endian conversion |

Here slash-separated widths denote separate function names, e.g. `be64toh`.
Host always means the evaluator's fixed little-endian Wasm target, including
native builds. Network order is big-endian. Inputs must be integral; they are
converted modulo 2^width before conversion, and results retain unsigned width.
Arguments are evaluated once. These names are lexically bound constexpr lambdas
inside the expression wrapper, not textual call replacements or global symbols.
Nested user lambdas can use `[&]` to access the surrounding helpers.

`htons(0x1234)` produces `0x3412`; `ntohl(htonl(0x12345678))` returns the input.
The 64-bit helpers operate at full width inside Clang, but existing Dart result
range/JavaScript integer-display limitations still apply to returned values.
Use an in-expression comparison when inspecting values beyond the app's range.

Verification: 28 shared cases in each of C++17/20/23 pass natively and through
the shipped Wasm evaluator. Cases cover all names, widths/signs, round trips,
truncation, negative inputs, 64-bit all-ones, single argument evaluation, and
invalid types/argument counts. Android device execution has not been tested.

```bash
flutter test --no-pub test/endian_helpers_test.dart
node tools/test_endian_helpers.mjs
```

### Upstream standard-library candidates

| Header / APIs | Current status | Wasm probe evidence | Proposed work |
| --- | --- | --- | --- |
| `<bit>`: `popcount`, `countl_zero`, `countr_zero`, `rotl`, `rotr`, `bit_width` | Missing; candidate | All rejected | Real libc++ headers; C++20 gates, unsigned constraints, width/zero/rotation tests |
| `<bit>`: `countl_one`, `countr_one`, `has_single_bit`, `bit_floor`, `bit_ceil`, `bit_cast` | Missing; candidate | Not individually probed | Expand bit test matrix, including invalid inputs and type preservation |
| `<bit>`: `byteswap` | Missing; candidate | Not probed in C++23 yet | C++23 gate and width tests |
| `<numeric>`: `gcd`, `lcm`, `midpoint` | Missing; candidate | All rejected | Real implementations, language gates, signed inputs and overflow conditions |
| `<numeric>`: `accumulate` | Missing; candidate | Array/lambda example rejected | C++20 constexpr evaluation with small arrays |
| `<algorithm>`: real `min`, `max`, `clamp` | Partial helper; replacement candidate | Existing scalar helpers pass | Replace conflicting prelude definitions and preserve actual overload semantics |
| `<array>` and `<algorithm>`: `array`, `sort` | Missing; candidate | Combined lambda example rejected | Small compile-time collections; return numeric result |
| `<limits>`, `<numbers>` | Partial helper; replacement candidate | See above | Replace handwritten approximations with pinned headers and correct language availability |
| `<type_traits>`, `<utility>`, `<cstdint>` | Missing as supplied standard headers | Not individually probed | Dependencies of the primary headers; include in packaging and compatibility tests |

## C library coverage by area

This is a family-level inventory, not an exhaustive per-symbol conformance list.
Each family should gain individual rows and tests as implementation starts.
Global C spellings, `std::` spellings, and C language modes must be tracked
separately; availability of one does not imply the others.

| C header / family | Current expression support | Missing examples / disposition |
| --- | --- | --- |
| `<math.h>` / `<cmath>` | Partial helpers above, in C++ modes | `log`, `exp`, `fabs`, `fmod` probes rejected. Also track inverse/hyperbolic trig, `atan2`, `hypot`, `cbrt`, `exp2`, `log2`, `log10`, `remainder`, `fma`, classification, decomposition and special functions individually |
| `<stdlib.h>` numeric conversion | Missing | `atoi("42")` rejected; `strtol`, `strtoul`, `strtod` need runtime or explicitly supported constexpr semantics |
| `<stdlib.h>` integer arithmetic | Partial `abs` helper only | `labs`, `llabs`, `div`, `ldiv`, `lldiv` not supplied |
| `<string.h>` / `<cstring>` | Missing | `strlen` and `strcmp` probes rejected; memory/string operations not supplied |
| `<ctype.h>` / `<cctype>` | Missing | `isdigit('4')` probe rejected; classification/case conversion and locale semantics need explicit design |
| `<limits.h>`, `<stdint.h>` | Partial calculator aliases/macros in C++ | Full header APIs absent |
| `<float.h>`, `<inttypes.h>` | Missing | Floating characteristics, format macros and conversion interfaces absent |
| `<stddef.h>`, `<stdbool.h>`, `<stdalign.h>`, `<stdnoreturn.h>` | Headers not supplied | Built-in language facilities do not establish library-header support |
| `<assert.h>`, `<errno.h>`, `<fenv.h>` | Not exposed | Runtime error/assertion/floating-environment model required |
| `<stdio.h>` | Runtime, not currently planned | File and terminal operations do not fit numeric constant evaluation |
| Allocation, `qsort`, `bsearch` | Not exposed | Runtime/pointer API design required; constexpr language allocation is a separate feature |
| `<time.h>`, `<locale.h>` | Runtime, deferred | Clock/environment-dependent results need an explicit execution model |
| `<wchar.h>`, `<wctype.h>`, `<uchar.h>` | Missing, deferred | Wide/multibyte/Unicode interfaces not supplied |
| `<complex.h>`, `<tgmath.h>` | Missing, deferred | Complex values also require result-model changes |
| `<stdarg.h>`, `<setjmp.h>`, `<signal.h>` | Not exposed | Runtime calling/control-flow facilities |
| `<stdatomic.h>`, `<threads.h>` | Not exposed | Runtime concurrency facilities |
| C23 `<stdbit.h>`, `<stdckdint.h>` | Missing, candidate for later C support | Distinct from C++ `<bit>`; needs C23-specific probes |

## Reproducing and expanding the audit

```bash
flutter pub get
node tools/audit_standard_library.mjs
```

The script resolves the installed package via `.dart_tool/package_config.json`
and prints representative C++20 results from the actual shipped Wasm artifact.
Rejected probes are inventory findings, not script failures. This script is an
audit tool, not a replacement for regression tests or a conformance suite.

When adding support, record the dependency revision, actual libc++/Clang versions,
language mode, exact implementation source, and separate native/Wasm/Android
results. Include overload and boundary cases rather than only happy paths.

## Implementation dependency and rollout

The [WASI/Emscripten comparison](WASM_TOOLCHAIN_COMPARISON.md) records successful
standalone library probes with both toolchains. Those are not yet capabilities
of this app's embedded evaluator.

The header loader and generated prelude live in the separate
`clang-constexpr.dart` dependency, not in this app. This app currently consumes
Linux source builds and prebuilt Android/Wasm artifacts. Changes to source
alone will not update those prebuilt platforms.

Required sequence:

1. Add a pinned libc++ header bundle and its required compiler/C headers to the
   evaluator's in-memory filesystem, with licenses and reproducible generation.
2. Configure header search and target/compiler definitions. Supply internal
   includes without opening arbitrary host filesystem access or relaxing user
   expression validation.
3. Remove or isolate conflicting handwritten `std` definitions. Define which
   legacy calculator aliases remain supported.
4. Verify bit/numeric/algorithm expressions, exact types, diagnostics, standard
   gates, evaluation limits, and existing expression regressions.
5. Rebuild and test Linux, Android and Wasm artifacts, publish an evaluator
   revision, then update the app's dependency and operator palette/docs.

Current rollout status: an opt-in [embedded libc++ prototype](../tools/libcxx_prototype/README.md)
passes 78 native evaluator checks using real Emscripten SDK headers, including
bit/numeric/algorithm operations, type checks, and language gates. The existing
native regression suite passes with the bundle disabled. This is a reproducible
dependency patch, **not shipped app support**: legacy math compatibility and
production Wasm/Android builds remain outstanding. The tables above describe
the pinned shipped dependency, not this prototype. Runtime libc/libm exports remain
a separate extension; they cannot be wired into `EvaluateAsConstantExpr` merely
by linking/exporting functions.

The prototype also tests real `<vector>` operations in C++20/23. `<deque>` is
included, but deque construction/operations are rejected because the pinned
implementation is not constexpr-capable. Neither is shipped container support;
numeric results remain required. See the prototype README for tested operations.

The app adapter additionally supplies unqualified calculator bit helpers:
`popcount`, `countl_zero`, `countr_zero`, `countl_one`, `countr_one`,
`has_single_bit`, `bit_width`, `bit_floor`, `bit_ceil`, `rotl`, and `rotr`.
These are not upstream `std` implementations. They require unsigned integers
(not bool) in Clang C++17 or newer; use `u`/`ULL` literals or fixed-width casts.
Counts return `int`; rotations and floor/ceil retain input width and unsignedness.
Zero has width leading/trailing zero bits, `bit_width(0u)` is 0, and
`bit_ceil(0u)` is 1. Unrepresentable bit ceilings are rejected. Rotation counts
are integral, reduced modulo width, and negative counts reverse direction.
Palette entries and Wasm verification for these new bit helpers are pending.

References: [Emscripten library support](https://emscripten.org/docs/compiling/Building-Projects.html),
[exporting compiled functions](https://emscripten.org/docs/porting/connecting_cpp_and_javascript/Interacting-with-code.html),
[libc++ C++20 status](https://libcxx.llvm.org/Status/Cxx20.html),
[C++23 status](https://libcxx.llvm.org/Status/Cxx23.html),
[C++26 status](https://libcxx.llvm.org/Status/Cxx26.html).
