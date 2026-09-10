# pcalc_expression_engine

Backend orchestration for `pcalc express`.

This package keeps the public evaluator API stable while allowing different
implementations to be selected by platform and capability.

## Current surface

- `initializeTinyExpr()`
- `evaluateExpression()`
- `getLastErrorMessage()`
- `selectedBackendInfo()`
- `ExpressionEvaluationResult`
- `ExpressionSession`
- `createExpressionSession()`
- `resetExpressionSession()`

## Planned backends

- TinyExpr++ FFI native backend
- Linux `ROOT` formula subprocess backend
- Linux `Cling`/ROOT C++ backend for casts and full syntax
- pure Dart fallback for browser-constrained builds

## Current behavior

The package still delegates to TinyExpr++ as the working backend by default.
The Linux ROOT formula backend is available as `BackendKind.rootFormula`.
The full C++ backend is available as `BackendKind.clingCxx`.

## Wrapper model

- Use the raw ROOT/Cling CLI for ad-hoc debugging.
- Use the app backend wrapper for stable machine-readable results.
- Keep formula-only math separate from C++/cast evaluation.
- The wrapper now carries result metadata such as kind, width, and signedness
  so the UI can render `char`, integer, floating, and boolean results without
  guessing.
- `ExpressionSession` is the stateful API for tabs or separate workspaces. The
  app still uses a default session today, but the session object is the shape
  to build on when the UI grows into multiple panes or saved language profiles.
- `createExpressionSession()` is the embeddable entrypoint for callers that
  want their own isolated session right away.
- `resetExpressionSession()` is the notebook-style restart hook for the default
  session.

For install notes, see [ROOT/Cling setup](../../docs/ROOT_CLING.md).
Embedded Cling is not part of the current roadmap. The portable typed-expression
path is the Clang constexpr backend.
