#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_dir="${PCALC_LINUX_BUNDLE:-$repo_dir/build/linux/x64/release/bundle}"
output_dir="${1:-$repo_dir/build/linux/packages}"
source_version="${2:-${SEMVER:-1.0.0}}"
package_variant="${3:-gtk3}"

case "$package_variant" in
  gtk3) package_name="pcalc-express" ;;
  gtk4) package_name="pcalc-express-gtk4" ;;
  *) echo "Expected package variant gtk3 or gtk4, got: $package_variant" >&2; exit 2 ;;
esac

if [[ ! -x "$bundle_dir/pcalc_express" ]]; then
  echo "Linux release bundle is missing: $bundle_dir" >&2
  echo "Run 'flutter build linux --release' first." >&2
  exit 1
fi
if ! command -v patchelf >/dev/null 2>&1; then
  echo "patchelf is required to prepare relocatable Linux packages." >&2
  exit 1
fi

# CPack and RPM reserve '-' for package release information. Convert a
# git-describe value such as 1.2.3-4-gabc123 to version 1.2.3 and release
# 4.gabc123 while retaining a useful fallback for untagged revisions.
if [[ "$source_version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)(-([0-9]+)-g([0-9a-f]+))?(-dirty)?$ ]]; then
  package_version="${BASH_REMATCH[1]}"
  package_release="${BASH_REMATCH[3]:-1}"
  if [[ -n "${BASH_REMATCH[4]:-}" ]]; then
    package_release+=".g${BASH_REMATCH[4]}"
  fi
  if [[ -n "${BASH_REMATCH[5]:-}" ]]; then
    package_release+=".dirty"
  fi
else
  package_version="0.0.0"
  package_release="0.$(printf '%s' "$source_version" | tr -c '[:alnum:].+' '.')"
fi

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/pcalc-packages.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
mkdir -p "$output_dir/deb" "$output_dir/rpm"

# Flutter plugins can retain a build-tree RUNPATH. Package a sanitized copy so
# installed libraries resolve only their siblings in the private bundle.
prepared_bundle="$build_dir/bundle"
mkdir -p "$prepared_bundle"
cp -a "$bundle_dir/." "$prepared_bundle/"
patchelf --set-rpath '$ORIGIN/lib' "$prepared_bundle/pcalc_express"
while IFS= read -r -d '' library; do
  patchelf --set-rpath '$ORIGIN' "$library"
done < <(find "$prepared_bundle/lib" -maxdepth 1 -type f -name '*.so' -print0)

cmake -S "$repo_dir/packaging/linux" -B "$build_dir" -G Ninja \
  -DPCALC_BUNDLE_DIR="$prepared_bundle" \
  -DPCALC_PACKAGE_VERSION="$package_version" \
  -DPCALC_PACKAGE_RELEASE="$package_release" \
  -DPCALC_PACKAGE_NAME="$package_name"

cpack --config "$build_dir/CPackConfig.cmake" -G DEB -B "$output_dir/deb"
cpack --config "$build_dir/CPackConfig.cmake" -G RPM -B "$output_dir/rpm"

find "$output_dir" -maxdepth 2 -type f \
  \( -name '*.deb' -o -name '*.rpm' -o -name '*.sha256' \) -print
