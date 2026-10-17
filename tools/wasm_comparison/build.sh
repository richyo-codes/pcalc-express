#!/usr/bin/env bash
set -euo pipefail

: "${EMXX:?Set EMXX to the Emscripten em++ executable}"
: "${WASI_SYSROOT:?Set WASI_SYSROOT to the extracted WASI sysroot}"
: "${WASI_BUILTINS:?Set WASI_BUILTINS to the matching libclang_rt.builtins.a}"
WASI_CXX="${WASI_CXX:-/usr/bin/clang++}"
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="${1:?Usage: build.sh OUTPUT_DIRECTORY}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

"$WASI_CXX" --version
"$EMXX" --version
for mode in numeric files; do
  defines=()
  em_options=(-sFILESYSTEM=0 -sEXPORTED_RUNTIME_METHODS=callMain)
  if [[ "$mode" == files ]]; then
    defines=(-DPCALC_PROBE_FILES=1)
    em_options=(-lnodefs.js -sEXPORTED_RUNTIME_METHODS=callMain,FS,NODEFS)
  fi
  "$WASI_CXX" --target=wasm32-wasip1 --sysroot="$WASI_SYSROOT" \
    -stdlib=libc++ -std=c++23 -O2 -fno-exceptions -fno-rtti \
    "${defines[@]}" "$source_dir/probe.cpp" -nodefaultlibs \
    -lc++ -lc++abi -lc -lm "$WASI_BUILTINS" -Wl,--strip-all \
    -o "$output_dir/wasi-$mode.wasm"
  "$EMXX" -std=c++23 -O2 -fno-exceptions -fno-rtti \
    "${defines[@]}" "$source_dir/probe.cpp" "${em_options[@]}" \
    -sMODULARIZE=1 -sEXPORT_ES6=1 -sENVIRONMENT=node -sEXIT_RUNTIME=1 \
    -o "$output_dir/emscripten-$mode.mjs"
done

# Record the constexpr/runtime distinction without accepting unrelated errors.
for backend in wasi emscripten; do
  if [[ "$backend" == wasi ]]; then
    compiler=("$WASI_CXX" --target=wasm32-wasip1 --sysroot="$WASI_SYSROOT" -stdlib=libc++)
  else
    compiler=("$EMXX")
  fi
  if "${compiler[@]}" -std=c++23 -fsyntax-only "$source_dir/constexpr_math.cpp" \
      >"$output_dir/$backend-constexpr-math.log" 2>&1; then
    echo "$backend: constexpr sin accepted"
  elif grep -q 'constant expression' "$output_dir/$backend-constexpr-math.log"; then
    echo "$backend: constexpr sin rejected (runtime probe compiled separately)"
  else
    cat "$output_dir/$backend-constexpr-math.log" >&2
    exit 1
  fi
done

node "$source_dir/run.mjs" "$output_dir"
