# Session Model Plan

Cling's Jupyter kernel is useful because it treats the interpreter as a
long-lived session instead of a one-shot CLI. That is the shape we want for
`pcalc express` as the app grows toward tabs, saved workspaces, and multiple
language backends.

## Goals

- Keep one reusable evaluation session per tab/workspace.
- Let a session own backend choice, debug logging, and interpreter state.
- Preserve a default global session for the current single-screen app flow.
- Keep evaluation and presentation separate.

## What we already have

- Structured evaluation results with type, width, and signedness metadata.
- ROOT formula and Cling C++ backends.
- A default session wrapper around the backend selection logic.

## Next steps

1. Expose `ExpressionSession` as a first-class API.
2. Add an explicit `reset()` / `restart()` path for session state.
3. Move future tab support to per-tab session objects.
4. Add language profiles for C++, Python, and formula subsets.
5. Keep browser/WASM on a smaller evaluator path until a JIT-free backend is
   viable.

## Later refactors for Cling itself

- Keep `cling::Interpreter` as the engine.
- Peel CLI/Jupyter/UI layers away from the embeddable core.
- Split result formatting from execution.
- Prefer a small session facade over driver entrypoints.
