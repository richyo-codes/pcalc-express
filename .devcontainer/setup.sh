#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f /.dockerenv && ! -f /run/.containerenv ]]; then
  echo 'Run this setup inside the development container, not on the host.' >&2
  exit 1
fi
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Dev Container tools may remap vscode's UID to the host user. These SDKs live
# in the container image, not in host mounts, and Flutter needs a writable cache.
if [[ ! -w /opt/flutter || ! -w /opt/emsdk ]]; then
  sudo chown -R "$(id -u):$(id -g)" /opt/flutter /opt/emsdk
fi
git lfs install --local
flutter pub get
echo 'Workspace ready. Check: bash .devcontainer/check.sh'
echo 'Preview: flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080'
