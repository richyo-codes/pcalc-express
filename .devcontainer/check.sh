#!/usr/bin/env bash
# Deliberately fails on any gate failure. No formatting, commits, or merges.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Existing project lints are reported; analyzer errors remain fatal.
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter test --no-pub test/recursive_factorial_test.dart
node tools/audit_standard_library.mjs
flutter build web --wasm --release --no-pub
git diff --check
