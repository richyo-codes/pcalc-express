#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT=8080

usage() {
  cat <<'EOF'
Usage: tools/run_wasm.sh [--port PORT]

Builds the Flutter WebAssembly app without running tests, then serves it at
http://127.0.0.1:8080. Press Ctrl+C to stop the server.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      if [[ $# -lt 2 ]]; then
        echo "--port requires a value." >&2
        exit 2
      fi
      PORT="$2"
      shift 2
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
done

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "--port must be a number." >&2
  exit 2
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found; cannot start the local web server." >&2
  exit 1
fi

cd "$ROOT_DIR"
flutter config --enable-web
flutter pub get

# Fedora may put ccache under the clang name. Native Assets needs real Clang.
if [[ -x /usr/bin/clang ]]; then
  export PATH="/usr/bin:/bin:$PATH"
fi

flutter build web --wasm --release --no-pub

test -f build/web/assets/packages/tinyexpr_plusplus_ffi/lib/tinyexprpp.wasm
test -f build/web/assets/packages/tinyexpr_plusplus_ffi/lib/tinyexprpp_loader.js

echo "Running Wasm app at http://127.0.0.1:$PORT"
echo "Press Ctrl+C to stop the server."
exec python3 -m http.server "$PORT" --directory build/web
