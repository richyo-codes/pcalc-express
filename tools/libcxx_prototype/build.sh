#!/usr/bin/env bash
# Builds isolated copies; never patches the supplied checkout or package cache.
set -euo pipefail
if [[ $# != 2 ]]; then
  echo "Usage: $0 EVALUATOR_CHECKOUT EMSDK_ROOT" >&2
  exit 2
fi
source_checkout=$(realpath "$1")
sdk=$(realpath "$2")
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
revision=483cd8144573cc3b0975c285ad2e34013191dee6
git -C "$source_checkout" cat-file -e "$revision^{commit}"
build_root=$(mktemp -d "${TMPDIR:-/tmp}/pcalc-libcxx-prototype.XXXXXX")
echo "Prototype artifacts: $build_root"
GIT_LFS_SKIP_SMUDGE=1 git clone --no-hardlinks --no-checkout "$source_checkout" "$build_root/evaluator"
GIT_LFS_SKIP_SMUDGE=1 git -C "$build_root/evaluator" checkout --detach "$revision"
git -C "$build_root/evaluator" apply "$script_dir/evaluator.patch"
node "$script_dir/generate_headers.mjs" "$sdk" "$build_root/libcxx.inc"
compiler=${CXX:-/usr/bin/clang++}
common=(-G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_C_COMPILER=${CC:-/usr/bin/clang}" "-DCMAKE_CXX_COMPILER=$compiler")
if [[ -n ${LLVM_DIR:-} ]]; then common+=("-DLLVM_DIR=$LLVM_DIR"); fi
if [[ -n ${Clang_DIR:-} ]]; then common+=("-DClang_DIR=$Clang_DIR"); fi
cmake -S "$build_root/evaluator" -B "$build_root/legacy" "${common[@]}"
cmake --build "$build_root/legacy" --target pcalc-constexpr-test -j "${BUILD_JOBS:-2}"
ctest --test-dir "$build_root/legacy" --output-on-failure
cmake -S "$build_root/evaluator" -B "$build_root/headers" "${common[@]}" "-DPCALC_LIBCXX_BUNDLE=$build_root/libcxx.inc"
cmake --build "$build_root/headers" --target pcalc-constexpr -j "${BUILD_JOBS:-2}"
"$compiler" -std=c++17 "$script_dir/probe.cpp" -I"$build_root/evaluator/include" \
  -L"$build_root/headers" -Wl,-rpath,"$build_root/headers" -ldart_clang_constexpr -o "$build_root/probe"
"$build_root/probe"
echo "Retained prototype artifacts: $build_root"
