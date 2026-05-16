# pcalc_expression_engine

Backend orchestration for `pcalc express`.

This package keeps the public evaluator API stable while allowing different
implementations to be selected by platform and capability.

## Current surface

- `initializeTinyExpr()`
- `evaluateExpression()`
- `getLastErrorMessage()`
- `selectedBackendInfo()`

## Planned backends

- TinyExpr++ FFI native backend
- Linux `ROOT` formula subprocess backend
- Linux `Cling`/ROOT C++ backend for casts and full syntax
- pure Dart fallback for browser-constrained builds

## Current behavior

The package still delegates to TinyExpr++ as the working backend by default.
The Linux ROOT formula backend is available as `BackendKind.rootFormula`.
The full C++ backend is available as `BackendKind.clingCxx`.

For install notes, see [docs/ROOT_CLING.md](/home/ry/code_flutter/rnd_pcalc_ng_public/docs/ROOT_CLING.md).
