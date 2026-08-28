#!/usr/bin/env bash
set -euo pipefail

# Build and test the browser version using Dart-to-Wasm, then serve it locally.
# Requires Flutter with web support, a Chrome-compatible browser, and Python 3.

SERVE=true
PORT=8080

usage() {
  cat <<'EOF'
Usage: tools/build_test_wasm.sh [--no-serve] [--port PORT]

Builds and tests the WASM web app. By default it then serves build/web at
http://127.0.0.1:8080. Press Ctrl+C to stop the server.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-serve)
      SERVE=false
      ;;
    --port)
      if [[ $# -lt 2 ]]; then
        echo "--port requires a value." >&2
        exit 2
      fi
      PORT="$2"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH." >&2
  exit 1
fi

# Fedora's ccache package can place compiler-named wrappers ahead of Clang.
# Flutter Native Assets detects `clang` for package hooks, so prefer the real
# system compiler before invoking Flutter.
if [[ -x /usr/bin/clang ]]; then
  export PATH="/usr/bin:/bin:$PATH"
fi

if ! command -v google-chrome >/dev/null 2>&1; then
  for browser in chromium-browser chromium google-chrome-stable; do
    if command -v "$browser" >/dev/null 2>&1; then
      export CHROME_EXECUTABLE="$(command -v "$browser")"
      echo "Using $browser for web tests."
      break
    fi
  done
fi

if [[ -z "${CHROME_EXECUTABLE:-}" ]] && ! command -v google-chrome >/dev/null 2>&1; then
  echo "No Chrome-compatible browser found for Flutter web tests." >&2
  echo "Install Google Chrome or Chromium, or set CHROME_EXECUTABLE." >&2
  exit 1
fi

flutter config --enable-web
flutter pub get
flutter test --platform chrome --wasm
flutter build web --wasm --release --no-pub

TINYEXPR_WASM="$ROOT_DIR/build/web/assets/packages/tinyexpr_plusplus_ffi/lib/tinyexprpp.wasm"
TINYEXPR_LOADER="$ROOT_DIR/build/web/assets/packages/tinyexpr_plusplus_ffi/lib/tinyexprpp_loader.js"
if [[ ! -f "$TINYEXPR_WASM" || ! -f "$TINYEXPR_LOADER" ]]; then
  echo "TinyExpr++ WASM runtime assets were not included in the web build." >&2
  exit 1
fi

echo "WASM web build created: $ROOT_DIR/build/web"

if [[ "$SERVE" != true ]]; then
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found; cannot start the local web server." >&2
  exit 1
fi

echo "Serving WASM build at http://127.0.0.1:$PORT"
echo "Press Ctrl+C to stop the server."
exec python3 -m http.server "$PORT" --directory "$ROOT_DIR/build/web"
