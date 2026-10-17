# Container result explorer

## Current status

The structured-result contract and explorer UI are implemented. The calculator
recognizes a successful `ExpressionEvaluationResult.fromContainer(...)` and
opens its contents from a result summary card. **No shipped evaluator currently
produces that result.** Vector/deque expressions have not become supported app
results as a consequence of this UI work. There is no fake/demo result injected
into normal calculations.

The real-libc++ prototype can evaluate vector operations to a scalar, but still
needs extraction before temporary allocations are destroyed. Deque construction
is not constexpr-capable in its pinned headers. Backend extraction, new native/
Wasm artifacts, and end-to-end evaluation are the next implementation step.

## Interaction

- Indexed element rows show exact values and type names.
- Nested containers open with an indexed path and Back navigation.
- Compact screens show the selected scalar detail in place of the list; wide
  screens show the list and detail side by side.
- Lists use 32-element pages and a validated Go to index field.
- Integer detail supports exact decimal, hexadecimal, and binary representations,
  including full-width unsigned 64-bit values and two's-complement negatives.
- Floating detail keeps the backend's original text and offers a formatted float
  view. Unsupported representations show a dash, not invented conversions.
- Existing Hex/Float formatting preferences are reused. Copy a displayed scalar
  representation or export the current container snapshot as typed JSON.
- Navigation and the fullscreen explorer opening have no slide/expansion
  animations. The explorer inherits the e-ink theme.

## Snapshot contract

`ContainerSnapshot` owns an unmodifiable list of scalar or nested container nodes.
Integers are stored as exact decimal text with width and signedness; never pass
through a double. Floating values retain exact display text separately from the
double used for optional formatting. The node also includes a backend type name.

Captured elements are a contiguous prefix starting at index zero. `totalCount`
may be larger than the captured prefix, in which case the explorer explicitly
reports partial data and does not offer inaccessible indices. Captured data is
not lazily fetched; changing pages does not re-execute the expression.

Snapshots are limited to 4,096 nodes and 8 container levels. Backend extraction
must enforce those limits **before allocating/traversing the entire result**;
the Dart constructor validates the already-created snapshot as a second check.
No native pointers or evaluator callbacks may escape into UI state.

JSON export preserves type names, integer widths/signedness, exact scalar text,
total counts, and truncation. It is an export format, not an implemented workspace
import or persisted-history format. Map keys, structs, editable elements, backend
paging, and saved container history remain out of scope for this first version.

## Verification

```bash
flutter test --no-pub test/container_explorer_test.dart
```

Tests cover model ownership and limits, exact large integers, nested compact
navigation, clipboard export, wide-layout paging, invalid indices, partial data,
and replacing a snapshot while browsing. Fixtures exercise the explorer without
claiming that current scalar-only evaluator artifacts return containers.
