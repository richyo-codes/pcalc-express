# Emscripten, WASI, and Wanix comparison

Date: 2026-09-21. Status: bounded toolchain experiment completed; no application
runtime migration or evaluator-library upgrade performed.

Follow-up: the [embedded libc++ prototype](../tools/libcxx_prototype/README.md)
now exercises real headers inside the native evaluator. It is opt-in and does
not change the shipped app or the standalone comparison results below.

## Recommendation

Keep the existing Emscripten evaluator integration while implementing real
libc++ header support. Prototype WASI as a separate execution target if shared
workspace files and external tools become a product requirement. Evaluate Wanix
as an optional browser host for that target, not as a prerequisite for basic
calculator storage.

The experiment found no tested numeric capability that requires migration to
WASI. Both toolchains compile actual libc++ implementations for the chosen
constexpr operations and run ordinary libm calls. Neither toolchain makes
runtime functions callable from the application's constexpr evaluator.

## Three independent decisions

1. **Evaluator executable:** our web evaluator is currently compiled through
   Emscripten and loaded through its generated JavaScript module.
2. **Expression target and headers:** embedded Clang currently evaluates a
   `wasm32-unknown-unknown` target using an in-memory filesystem and a handwritten
   prelude. A matching, pinned header environment must be provided separately.
3. **Runtime execution:** running user code with files or runtime math would
   require an execution backend beyond the existing `EvaluateAsConstantExpr`.

Using WASI SDK headers for a prototype does not automatically introduce a WASI
runtime. However, target macros, C headers, libc++ configuration, and Clang must
agree. Do not mix host Linux headers with a Wasm expression target.

## Reproducible experiment

Sources and runner are in [`tools/wasm_comparison`](../tools/wasm_comparison).
The same `probe.cpp` is compiled twice, with a numeric-only variant and a file
variant for each toolchain. These are small standalone programs, **not builds of
the full Clang evaluator**. Runs use Node, not a browser or an e-ink device.

| Component | Version tested |
| --- | --- |
| WASI compiler | Fedora Clang 22.1.8; target `wasm32-wasip1` |
| WASI headers/libraries | Official WASI SDK 32.0 sysroot and compiler builtins |
| WASI libc++ headers | `_LIBCPP_VERSION=220100` |
| Emscripten | 4.0.15, SDK build `b412b6307e541b93dd93f01b61181e15c17302ec` |
| Emscripten compiler | Clang 22.0.0git, commit `3388d40684742e950b3c5d1d2dafe5a40695cfc1` |
| Emscripten libc++ headers | `_LIBCPP_VERSION=200100` |
| Execution host | Node 24.18.0, built-in WASI Preview 1 / generated Emscripten loader |
| Common flags | C++23, `-O2`, exceptions and RTTI disabled |

These are pinned test configurations, not a comparison of the latest releases.
Compiler/library revisions differ; this is a feasibility check, not a controlled
performance or implementation-equivalence benchmark.

```bash
export EMXX=/path/to/activated/emsdk/upstream/emscripten/em++
export WASI_CXX=/usr/bin/clang++
export WASI_SYSROOT=/path/to/wasi-sysroot-32.0
export WASI_BUILTINS=/path/to/libclang_rt-32.0/wasm32-unknown-wasip1/libclang_rt.builtins.a
bash tools/wasm_comparison/build.sh /tmp/pcalc-wasm-comparison
```

Use a dedicated output directory: the runner creates/resets its own test input
and counter files inside it. The script downloads nothing, changes no app
dependencies, and fails if compilation or a runtime assertion fails. It also
records the expected constexpr math rejection separately from runtime success.

Downloaded archive checksums used for this run:

| Archive | SHA-256 |
| --- | --- |
| `wasi-sysroot-32.0.tar.gz` | `f2537f6e5804f7f24e32dd140e9371e9670a9fd2646b6a813ddb896b29954b12` |
| `libclang_rt-32.0.tar.gz` | `e42ba168766a4a1161d44b740d22c336b39424190ca7a672acbd8b71b8d4372a` |
| emsdk source tag `4.0.15` tarball | `35be7626493e3bd22860ee2177147f9bca3b6ff871edeab27c5b061a9ed9d23d` |

The sysroot digest was checked against official release metadata. The other
digests record the downloaded artifacts for reproducibility.

## Measured results

| Check | WASI build | Emscripten build |
| --- | --- | --- |
| Compile-time `popcount`, leading/trailing zeros, rotations, bit width | Pass | Pass |
| Compile-time C++23 `byteswap` | Pass | Pass |
| Compile-time `gcd`, `lcm`, `midpoint`, `clamp` | Pass | Pass |
| Compile-time `array`, `sort`, `accumulate` | Pass | Pass |
| Runtime `sin(0.5)` with volatile input | `0.479425538604203` | `0.479425538604203` |
| Runtime fractional `pow(9.0, 0.5)` with volatile inputs | `3.000000000000000` | `3.000000000000000` |
| C++23 `constexpr std::sin(0.5)` | Rejected | Rejected |
| Read binary file with `fopen`/`fgetc` | Pass; sum 256 | Pass; sum 256 |
| Write counter and reopen in a fresh module instance | Pass; 1 then 2 | Pass; 1 then 2 |

Runtime math checks allow an absolute error of `1e-14` for these two inputs.
Matching results here do not establish bit-exact libm behavior across all inputs.
Compile-time cases use `static_assert`, so a successful build checks actual
constant evaluation rather than runtime folding alone.

Persistence in this test is supplied by the host: a WASI preopened temporary
directory versus Emscripten NODEFS mounted on its own temporary directory. This
does **not** test OPFS, IndexedDB, browser reloads, PWA offline operation, or Wanix.

| Raw artifact size | WASI | Emscripten |
| --- | ---: | ---: |
| Numeric Wasm | 33,510 bytes | 24,311 bytes |
| Numeric generated JS loader | None; host required | 8,882 bytes |
| File probe Wasm | 63,118 bytes | 56,098 bytes |
| File probe generated JS loader | None; host required | 65,332 bytes |

WASI host implementation size is excluded, as is Node itself. Emscripten's file
loader includes NODEFS support specific to this test. These uncompressed sizes
are not an app download estimate or evidence that WASI is smaller overall. No
startup, memory, throughput, or device responsiveness measurements were made.

## Imports and compatibility

The WASI numeric module imports five Preview 1 functions, including stdout and
exit operations. Its file variant imports ten, adding reads, path opening,
preopened-directory discovery, and descriptor flags.

The Emscripten numeric module imports `wasi_snapshot_preview1.fd_write`. Its file
variant additionally imports Emscripten `env` functions such as
`__syscall_openat`, `__syscall_fcntl64`, `__syscall_ioctl`, and
`emscripten_resize_heap`, alongside WASI-style descriptor operations.

Therefore, shared WASI import names do not establish full WASI compatibility.
Keep the Emscripten-generated loader with its corresponding binary. A future
WASI target must deliberately select a supported ABI/host; this experiment only
tests Preview 1, not Preview 2 components or later interfaces.

## Browser files and Wanix

Emscripten supports virtual filesystems: MEMFS for memory, IDBFS for browser
persistence with synchronization, and NODEFS for Node. Our current evaluator is
built with `FILESYSTEM=0`; enabling files in that module is a build/integration
change, not a capability it already exposes. [Filesystem documentation](https://emscripten.org/docs/api_reference/Filesystem-API.html)

Wanix documents WASI tasks, JavaScript workers, composable namespaces, and OPFS
storage. This makes it a candidate for sharing files between the calculator,
an editor, and other tools. Its optional terminal/workbench need not replace
the calculator UI. [Wanix documentation](https://github.com/tractordev/wanix)

The existence of a WASI task driver is not proof that every import or lifecycle
assumption in our future evaluator is supported. Wanix compatibility and browser
persistence have not been run in this experiment.

The next Wanix-specific acceptance test should:

1. Bind the file probe into a namespace backed by OPFS and run it twice.
2. Reload the browser and verify that the counter persists, then test offline.
3. Exercise worker startup/termination and a Flutter-to-filesystem bridge.
4. Measure additional compressed assets, startup time and memory on an e-ink
   device, with the full evaluator present.

Adopt Wanix only if that demonstrates a useful shared-filesystem workflow and
acceptable cost. Saving a JSON library alone does not need a Unix-like host.

## Consequences for the standard-library work

The successful compiler probes support proceeding with real libc++ headers.
They do not yet validate embedding those headers in our manually configured
Clang parser. The app's [support tracker](STANDARD_LIBRARY_SUPPORT.md) remains
unchanged: these functions are still missing from the shipped evaluator.

Next implementation step: construct a pinned header environment compatible with
the embedded Clang version, validate it against the expression evaluator, and
rebuild platform artifacts. Keep filesystem hosting and runtime execution as
separate capabilities so either Emscripten or a future WASI target can use them.

Primary references:

- [WASI SDK releases and target setup](https://github.com/WebAssembly/wasi-sdk)
- [Emscripten runtime environment](https://emscripten.org/docs/porting/emscripten-runtime-environment.html)
- [Emscripten filesystem API](https://emscripten.org/docs/api_reference/Filesystem-API.html)
- [Node WASI API](https://nodejs.org/api/wasi.html)
- [Wanix](https://github.com/tractordev/wanix)
