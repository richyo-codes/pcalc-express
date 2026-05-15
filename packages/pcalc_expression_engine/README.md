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
- Linux `ROOT`/`Cling` subprocess backend
- pure Dart fallback for browser-constrained builds

## Current behavior

The package still delegates to TinyExpr++ as the working backend by default.
The Linux ROOT subprocess backend is available as an explicit opt-in via
`BackendKind.clingRepl`.

For install notes, see [docs/ROOT_CLING.md](/home/ry/code_flutter/rnd_pcalc_ng_public/docs/ROOT_CLING.md).
