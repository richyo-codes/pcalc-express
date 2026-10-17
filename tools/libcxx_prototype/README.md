# Embedded libc++ prototype

This is an opt-in patch to the **actual embedded Clang evaluator**, not another
standalone C++ program. It does not change the application's dependency or its
shipped Android/Wasm artifacts.

## Reproduce

Requirements: Linux, Git, Node, Ninja, CMake, Clang/LLVM development libraries,
an installed Emscripten SDK, and a local evaluator Git checkout containing commit
`483cd8144573cc3b0975c285ad2e34013191dee6`. Downloads/installations are separate.

```bash
LLVM_DIR=/usr/lib64/cmake/llvm Clang_DIR=/usr/lib64/cmake/clang \
  bash tools/libcxx_prototype/build.sh /path/to/evaluator /path/to/emsdk
```

The script clones the pinned commit into a new temporary directory, applies
`evaluator.patch`, generates headers, runs the existing native regression suite
with the bundle disabled, then builds and tests the real-header configuration.
It leaves the supplied checkout and app dependency untouched. Artifacts are
retained at the printed path. `CC`, `CXX`, and `BUILD_JOBS` can override defaults.
The SDK path is explicit but not version-enforced: use the versions below to
reproduce this recorded result.

## Verified configuration and results (2026-09-21)

- Native compiler and embedded Clang: Fedora 22.1.8.
- Headers: Emscripten SDK 4.0.15, libc++ `_LIBCPP_VERSION=200100`.
- Expression target: `wasm32-unknown-emscripten`; C retains its existing target.
- Bundle: 1,806 headers, 26,527,453 generated source bytes; SHA-256
  `46d8a0883427aec48a76a2d4c185204aee6b7885d586ea34ba98740f85922456`.
- 78 embedded evaluator assertions passed: C++ bit/numeric operations,
  array/sort/accumulate, limits, reference semantics, integer widths/signs,
  standard-version gates, invalid types, rejected directive/declaration input,
  evaluation limits, and C-mode arithmetic.
- Existing native regression suite passed with the bundle disabled.

The prototype now includes `<vector>` and `<deque>`. In C++20/23, vector
construction, growth, sorting, accumulation, insert/erase/pop, reserve/resize,
copying, and 64-bit elements pass. Invalid indexing and returning an allocated
vector as the result are rejected. C++17 vector construction is rejected.
Deque type inspection works, but constructing/using a deque is rejected in all
tested modes: the pinned libc++ implementation is not constexpr-capable. This
is **not deque operation support**, nor are either container's operations
available in the shipped app yet. Structured container results need a separate
result API and explorer UI; neither is implemented by this patch.

The patch supplies headers through the existing in-memory filesystem, configures
system include paths and target predefined macros, and replaces the handwritten
C++ prelude only when explicitly enabled. No host filesystem is added to the
expression filesystem. Input rejection probes are regression checks, not a
security audit.

It also fixes constant-result extraction: stripping implicit expressions removed
the conversion needed to evaluate `std::clamp`'s reference result. Keeping the
complete initializer passes that test and the existing legacy regression suite.

## Compatibility and rollout boundaries

This is **not ready to enable by default**. Probes show that `abs(-42)`,
`std::abs(-42.5)`, `sqrt(81.0)`, and `pow(2, 10)` are rejected in the real-header
configuration. Legacy `pi` and `std::pi` aliases are absent; standard
`std::numbers::pi` works. `INT_MAX` remains available in this tested configuration.
The probe prints these compatibility findings separately from required checks.

Next steps before shipping:

1. Decide and implement a distinct calculator-math compatibility layer without
   redefining upstream `std` functions or calling approximations exact libc.
2. Minimize/package the header set, retain SDK/library licenses, and measure
   per-evaluation parsing time and memory. Generated source size is not download
   size; no browser performance claim is made here.
3. Validate the compiler/header combination used by each production build; this
   host-Clang/SDK-header combination is only the tested prototype configuration.
4. Build and test the full Wasm and Android evaluator artifacts, including the
   existing regression matrix; publish a dependency revision before switching
   the app or adding operators to its UI.

Header availability does not implement runtime libc, file I/O, or libm execution.
The evaluator still returns a numeric constant-expression result. WASI/Wanix
hosting remains a separate decision; see the
[toolchain comparison](../../docs/WASM_TOOLCHAIN_COMPARISON.md).
