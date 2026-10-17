#!/usr/bin/env bash
# Run on the host, never inside an agent container with Docker socket access.
set -euo pipefail
usage() {
  echo 'Usage: task_workspace.sh create TASK DESTINATION [BASE=HEAD]'
  echo '       task_workspace.sh merge TASK_CHECKOUT'
}
root=$(git rev-parse --show-toplevel)
case "${1:-}" in
  create)
    [[ $# == 3 || $# == 4 ]] || { usage; exit 2; }
    task=$2
    [[ "$task" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo 'Use lowercase letters, digits, - or _ for TASK.' >&2; exit 2; }
    destination=$3
    [[ ! -e "$destination" ]] || { echo 'Destination must not exist.' >&2; exit 2; }
    revision=$(git -C "$root" rev-parse --verify --end-of-options "${4:-HEAD}^{commit}")
    upstream=$(git -C "$root" remote get-url origin)
    # Independent repository: no worktree metadata pointing outside the mount,
    # no shared Git objects writable by a task agent.
    GIT_LFS_SKIP_SMUDGE=1 git clone --no-local --no-checkout -- "$root" "$destination"
    git -C "$destination" remote set-url origin "$upstream"
    git -C "$destination" checkout -b "agent/$task" "$revision"
    echo "Created agent/$task from committed revision $revision. Uncommitted work was not copied."
    echo "Next: devcontainer up --workspace-folder $destination"
    ;;
  merge)
    [[ $# == 2 ]] || { usage; exit 2; }
    task_root=$(cd -- "$2" && git rev-parse --show-toplevel)
    [[ "$task_root" != "$root" ]] || { echo 'Expected a separate task checkout.' >&2; exit 2; }
    [[ -z $(git -C "$root" status --porcelain) && -z $(git -C "$task_root" status --porcelain) ]] || {
      echo 'Both repositories must be clean; commit task work and preserve destination edits first.' >&2; exit 1;
    }
    branch=$(git -C "$task_root" symbolic-ref --short HEAD)
    [[ "$branch" == agent/* ]] || { echo 'Task must be on an agent/ branch.' >&2; exit 2; }
    git -C "$root" symbolic-ref --quiet HEAD >/dev/null
    revision=$(git -C "$task_root" rev-parse HEAD)
    # Require a task based on the current destination tip. If the destination
    # moved, integrate it in the task checkout and rerun tests before merging.
    destination_revision=$(git -C "$root" rev-parse HEAD)
    if ! git -C "$task_root" merge-base --is-ancestor "$destination_revision" "$revision" 2>/dev/null; then
      echo 'Integrate the destination tip into the task branch before merging.' >&2
      exit 1
    fi
    devcontainer exec --workspace-folder "$task_root" bash .devcontainer/check.sh
    [[ $(git -C "$task_root" rev-parse HEAD) == "$revision" && -z $(git -C "$task_root" status --porcelain) ]]
    [[ $(git -C "$root" rev-parse HEAD) == "$destination_revision" && -z $(git -C "$root" status --porcelain) ]]
    git -C "$root" fetch --no-tags "$task_root" "$branch"
    [[ $(git -C "$root" rev-parse FETCH_HEAD) == "$revision" ]]
    git -C "$root" merge --no-ff -m "Merge task $branch" "$revision"
    ;;
  *) usage; exit 2 ;;
esac
