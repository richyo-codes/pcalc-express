# Portable, task-owned development workspaces

One environment recipe, three places to run it: a local Docker host, your own
remote server, or GitHub Codespaces. Each task gets an independent checkout,
`agent/<task>` branch, container, and workspace-local dependency cache. Reconnect
to the same workspace to resume processes; recreate from Git to move hosts.

## Environment

`.devcontainer/devcontainer.json` builds a non-root Linux environment with:

- Flutter revision `9584c6713b324636289d067944a46fd6b49df14b` (3.47.4, Dart 3.13.3).
- LLVM/Clang 22 from the LLVM Ubuntu repository, with matching CMake paths.
- Node 22.14.0 and Emscripten SDK 4.0.15.
- CMake, Ninja, Git LFS, and GTK3/native build dependencies.

Flutter and SDK downloads are image layers; Pub's `.devcache/pub` lives inside
the workspace and survives container rebuilds. Each task has its own cache;
these are disposable, not backups. The base image tag and apt package patch
versions are **not digest/snapshot locked**, so this is a version-selected
environment, not a bit-for-bit reproducible image. Budget several GB for the
initial build; 4 CPUs, 8 GB memory, and 32 GB disk are suggested starting points.
To use `em++` directly, run `source /opt/emsdk/emsdk_env.sh` in that terminal.
Setup runs `flutter pub get`; if the pinned SDK changes dependency resolution,
review and commit the resulting lockfile changes in the task branch. Setup does
not silently commit them, and the merge gate refuses uncommitted changes.

Scope: native unit tests, default Linux builds, and web builds/previews. This
image does not configure Chrome tests, physical devices, Android SDK/emulators,
GTK4 engines, or desktop display forwarding. Those need separate extensions.
Do not replace the SDK pin with `stable` without checking the Dart constraint.

The initial image build and Dev Container CLI startup were verified on Linux
x86-64 with Docker 29.7.2 and CLI 0.89.0. Codespaces/SSH instructions use the same
configuration but have not been tested on a hosted account or second server.
The container gate passed on a fresh checkout: analysis completed with 19
pre-existing warning/info diagnostics and no errors, all three native factorial
regressions passed, the Wasm library inventory ran, and the release Wasm build
succeeded. Setup was also successfully rerun. ShellCheck and disposable-repository
tests cover task creation, dirty-tree rejection, failed gates, successful merges,
and stale-base rejection; those merge tests stub the CLI, separately from the
real container build/test verification.

## Local or self-hosted task

Install Docker and the Dev Containers extension in VS Code. For the commands
below also install the [Dev Container CLI](https://github.com/devcontainers/cli).
The CLI runs on the **host**, not inside the agent's container.

With Node/npm installed on the host, the tested CLI version can be installed via
`npm install --global @devcontainers/cli@0.89.0`. Your editor can manage containers
without that CLI, but the task merge script uses it to run the test gate.

From the main checkout, after committing the environment configuration:

```bash
bash tools/task_workspace.sh create endian-tools ../pcalc-endian-tools
devcontainer up --workspace-folder ../pcalc-endian-tools
devcontainer exec --workspace-folder ../pcalc-endian-tools bash
```

The destination must not exist. An optional fourth argument selects the base
commit/branch; the default is HEAD. Only committed source is copied. Independent
clones avoid worktree `.git` paths escaping the container mount. The clone's
origin is the upstream repository, not your main checkout.

In VS Code, open the task directory and choose **Reopen in Container**. On your
own server, connect using **Remote - SSH**, clone the repo on that server, and
follow the same steps there. The files, Docker engine, and processes stay on the
server; reconnect from another computer to resume. Do not expose Docker's socket
over unauthenticated TCP. See [remote-host guidance](https://code.visualstudio.com/remote/advancedcontainers/develop-remote-host).

On SELinux-enforcing hosts, a bind mount may be readable as a directory but deny
file access. Have the host administrator give **only the dedicated task checkout**
a container-compatible SELinux label (or use an appropriately labeled Docker
volume). Do not disable SELinux globally or relabel your home directory. This is
a host setup concern, not a reason to grant the agent privileged containers.

## Hosted task (Codespaces)

Once this configuration is pushed, use GitHub's **Code → Codespaces → Create**
for the desired base branch. It will use the same devcontainer configuration.
Create a task branch in its terminal:

```bash
git switch -c agent/endian-tools
```

Start your agent in that workspace, review its committed changes, then push the
task branch and open a PR. Use repository CI/review gates before merging. A local
merge script cannot directly access a Codespace's filesystem; use Git branches
and PRs for that route. No hosted workspace or paid infrastructure is created by
the configuration itself. Stop idle workspaces and review account usage limits.
See [Codespaces lifecycle and persistence](https://docs.github.com/en/codespaces/about-codespaces/deep-dive).

## Agent handoff

Install/authenticate your chosen agent in the task environment; no particular
agent service is installed or given credentials automatically. A useful task
brief includes:

> Work only on this task branch. Implement [bounded outcome]. Preserve unrelated
> changes. Run `bash .devcontainer/check.sh` plus task-specific tests. Commit in
> logical pieces. Report the diff, test results, and remaining limitations. Do
> not push, merge, provision services, or access secrets unless authorized.

The lifecycle setup restores dependencies; it does **not** start an autonomous
agent on opening the repository. Give agents task-scoped credentials only when
needed. Devcontainers are not hardened sandboxes for hostile agents: they have
network access and can modify their mounted checkout, and editor tooling may
forward credentials/SSH agents. Review forwarding before granting access. Do
not mount the host Docker socket, home directory, or sibling task checkouts.
Use a separate VM/host for untrusted code and stronger isolation.

## Test, preview, and merge

Inside a workspace:

```bash
bash .devcontainer/check.sh
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

The check gate runs analysis (errors fatal; existing warnings/info reported), recursive-lambda native regressions, the library
inventory audit, and a release Wasm build. The inventory audit reports missing
APIs; it is not an assertion suite. Add task-specific tests before approving a
merge. Forward port 8080 through your editor; keep hosted previews private unless
you intentionally choose to publish them. No Docker host port is exposed.

For a reviewed task on the **same host**, run from the destination checkout:

Review directly in the task checkout using its base commit, or fetch its branch
into the destination first:

```bash
git fetch ../pcalc-endian-tools agent/endian-tools
git diff HEAD...FETCH_HEAD
bash tools/task_workspace.sh merge ../pcalc-endian-tools
```

The explicit merge command requires both checkouts to be clean, a task branch,
and the destination's current tip to be an ancestor of the task. It reruns the
container gate, verifies the tested task commit and destination did not change,
then creates a non-fast-forward merge commit. If the destination moved, integrate
its latest commit in the task checkout first, resolve conflicts there, and retry.
Review the gate script itself: task code can change it. These checks are workflow
guardrails, not independent security enforcement or a replacement for protected
branch CI. No task container, checkout, or branch is automatically deleted.

Keep source and task notes in Git. Container processes do not migrate with Git;
uncommitted work needs a separate backup. Removing a hosted workspace can remove
its caches and unpushed work. Secrets belong in the host/provider secret store,
never in the image, project files, or shared task prompt.
