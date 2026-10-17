#!/usr/bin/env bash
# Disposable Git fixtures. The CLI stub checks gating, not container behavior.
set -euo pipefail
script=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/task_workspace.sh
fixture=$(mktemp -d)
echo "Retaining task-workspace test fixtures at $fixture"
export GIT_AUTHOR_NAME='Workspace Test' GIT_AUTHOR_EMAIL='workspace@example.invalid'
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
git init -q -b main "$fixture/main"
cd "$fixture/main"
git remote add origin https://example.invalid/project.git
git commit -q --allow-empty -m base
bash "$script" create test "$fixture/task"
[[ $(git -C "$fixture/task" branch --show-current) == agent/test ]]
[[ $(git -C "$fixture/task" remote get-url origin) == https://example.invalid/project.git ]]
if bash "$script" create test "$fixture/task"; then exit 1; fi
if bash "$script" create '../bad' "$fixture/bad"; then exit 1; fi
git -C "$fixture/task" commit -q --allow-empty -m task
mkdir "$fixture/bin"
# shellcheck disable=SC2016 # Expanded by the stub when it runs, not here.
printf '#!/bin/sh\nexit "${GATE_EXIT:-0}"\n' > "$fixture/bin/devcontainer"
chmod +x "$fixture/bin/devcontainer"
export PATH="$fixture/bin:$PATH"
before=$(git rev-parse HEAD)
printf 'uncommitted\n' > "$fixture/main/unfinished"
if bash "$script" merge "$fixture/task"; then exit 1; fi
mv "$fixture/main/unfinished" "$fixture/unfinished"
printf 'uncommitted\n' > "$fixture/task/unfinished"
if bash "$script" merge "$fixture/task"; then exit 1; fi
mv "$fixture/task/unfinished" "$fixture/task-unfinished"
if GATE_EXIT=1 bash "$script" merge "$fixture/task"; then exit 1; fi
[[ $(git rev-parse HEAD) == "$before" ]]
bash "$script" merge "$fixture/task"
[[ $(git rev-list --parents -n 1 HEAD | wc -w) == 3 ]]
# A task based on an older destination cannot pass the merge gate.
if bash "$script" merge "$fixture/task"; then exit 1; fi
echo 'Task creation, invalid inputs, failed gate, successful merge, and stale-base checks passed.'
