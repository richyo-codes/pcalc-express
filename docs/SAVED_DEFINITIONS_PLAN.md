# Saved variables and custom functions

Status: proposed design, not implemented. This extends the session model in
[SESSION_MODEL_PLAN.md](SESSION_MODEL_PLAN.md).

## First useful release

Provide a persistent Library of named numeric definitions in the default
workspace. Users can insert a name into an expression, edit its definition,
and see its value or error. Start with Clang in C++17 and newer modes; expose
support as a backend capability. Other backends and C language modes must show
an explicit unsupported message when definitions are required. Never switch
languages or change operator semantics silently.

Example library:

```text
mask   = 0xFFu
header = 0xA5u << 8
packet = header | mask
```

The expression editor can then evaluate `packet & mask`.

## Meaning of a saved variable

Distinguish two actions instead of making a saved value change unexpectedly:

- **Save definition** stores source such as `header | mask`. It is evaluated
  against the current workspace definitions when the user calculates.
- **Save result** captures an exact typed value at that moment. It does not
  change when the original expression or its dependencies change.

Ship Save definition first. Save result needs a lossless typed-literal encoder
and can follow separately. Never reconstruct either kind from the rounded Float
display or grouped Hex display, or funnel integer values through a Dart double.
Preserve integer width and signedness, booleans, and floating-point type where
the engine exposes them. Existing result metadata and Dart integer range limits
need auditing before promising exact result snapshots on every platform.

Definitions are read-only within a calculation. Editing a library entry updates
its source; entering `mask = 3` in the calculator does not persist a new value.
AC clears the expression, while deleting a definition is a separate action.

## Evaluator approach and feasibility gate

Current evidence:

- `ExpressionSession` owns backend selection but has no symbol registry.
- `ExpressionBackend.evaluate` accepts only an input string.
- The pinned Clang package exposes expression evaluation without a preamble or
  declarations parameter.
- The recursive-factorial fixture already uses an immediately invoked lambda
  with local declarations. That is a candidate for supplying library entries.
- The existing Add Custom Variable UI is feature-flagged and does not save or
  register anything. Replace it when the real feature is available.

Prototype compiling an expression of this shape through the existing backend:

```cpp
[] {
    constexpr auto mask = (0xFFu);
    constexpr auto header = (0xA5u << 8);
    constexpr auto packet = (header | mask);
    constexpr auto low_byte = [](auto x) constexpr {
        return x & mask;
    };
    return (low_byte(packet));
}()
```

This is illustrative, not a verified lowering contract. The spike must establish
capture rules, type preservation, diagnostics, and behavior on native and Wasm
before committing to this mechanism. A context/declarations API in the Clang
package is the alternative if the wrapper cannot preserve the required behavior.

Let Clang resolve lexical names and scopes. Do not expand function bodies by
string replacement: it can repeat argument evaluation and mis-handle strings,
comments, local variables, member access, and shadowing. Likewise, a regex over
identifiers cannot reliably discover dependencies in arbitrary C++ expressions.

For the initial release, definitions form an ordered list and may reference
earlier enabled entries. Show this rule in the editor and allow reordering.
Forward references and cycles fail validation without recursive expansion.
Automatic dependency ordering is a later feature requiring compiler-derived
references or a deliberately restricted, parsed definition language.

Compile enabled entries together with the expression. Initially, an invalid
enabled entry blocks calculation and is identified by name; disabling it is
the escape hatch. Evaluating only reachable definitions is deferred until
dependency analysis exists. Map generated source locations back to the entry
and body position rather than exposing only wrapper line numbers.

Validate identifiers, duplicate names, keywords, parameter names, and reserved
internal names. Validate each body as an expression in its intended context;
generated-source interpolation alone is not expression validation. Saving a
definition must not bypass the evaluator's existing input restrictions.

## Custom functions

Second release: named expression-bodied functions with positional parameters:

```text
low_byte(x) = x & 0xFFu
combine(hi, lo) = (hi << 8) | low_byte(lo)
```

Use compiler-bound parameters, initially inferred from arguments. Functions can
reference earlier library definitions. Keep standard C++ arithmetic and return
type inference; do not imply a portable formula language. Built-in availability
continues to depend on the evaluator, so examples must not assume `min`, `max`,
or standard-library headers exist.

Defer named-function recursion, overloading, defaults, variadic parameters, and
statement-body editors. Existing raw-expression lambda capabilities remain as
they are. Function insertion writes `low_byte()` and places the cursor inside
the parentheses; show parameter names in the library.

## UI and e-ink behavior

Use one Library entry in the application menu and operator palette. A spacious
layout can show a side panel; a compact layout uses a dialog or sheet following
the existing e-ink motion rules. Avoid allocating permanent main-keypad rows to
every saved name. Pinned shortcuts can follow after real usage.

Each entry shows its name, definition, value/type preview, and error status.
Provide Insert, Edit, Duplicate, Enable/Disable, and Delete. Confirm deletion
or provide undo. A function's Insert action includes parentheses. Inserting a
variable replaces the current selection and restores editor focus.

Definition editing uses a draft. Validate on an explicit action rather than
compiling on every keystroke. Saving a valid draft updates the workspace and
marks dependent displayed results stale until the next calculation. Preserve
the previously saved entry if validation or persistence fails.

## Ownership and persistence

Keep definitions in an immutable workspace snapshot supplied to the session.
The engine owns validation and evaluation; app code owns storage and widgets.
Start with one persistent default workspace, using stable entry IDs, a revision,
an ordered definition list, and the selected language profile.

Persist source as the authority. Evaluated values are disposable previews tied
to a workspace revision and backend/language, not authoritative stored values.
Restarting an evaluator reapplies the saved snapshot; clearing a workspace is
an explicit separate operation.

Use a versioned JSON format behind a repository interface. A small first version
can use SharedPreferences consistently with existing app preferences, but the
interface should allow a file/database implementation later. Check write
results, preserve unreadable or unknown-version data, serialize writes, and
provide export before treating this as the user's durable calculation library.

Suggested separation:

- Engine: definition models, validation, session context, backend adapter.
- App: workspace repository and controller.
- UI: library panel, definition editor, reusable entry row.

Keep these out of the already large calculator screen.

## Sharing and history

An expression referring to library names needs its definitions to be reproducible.
The first implementation should flag that dependency rather than silently
sharing an incomplete expression link. Add versioned workspace export/import
before extending QR payloads.

Imports open for review, never overwrite the current library automatically, and
do not execute on opening. Resolve name collisions explicitly. Include source,
definition order, and language requirements. For large exports offer a file;
QR capacity is limited and encoding does not make source private.

History should retain the workspace revision used for each result. Re-evaluating
against current definitions must be distinguishable from restoring a historical
snapshot. Do not advertise reproducible history until snapshots are retained.

## Implementation slices and acceptance checks

1. **Clang feasibility spike:** verify the wrapper or context API on native and
   Wasm, with unsigned masks, booleans, casts, floating values, lexical shadowing,
   strings/comments, diagnostics, and existing recursive-lambda expressions.
2. **Session definitions:** immutable snapshots, ordered validation, capability
   reporting, duplicate/invalid-name errors, and two-session isolation. Backend
   or language changes must not silently discard or reinterpret definitions.
3. **Saved library:** versioned persistence, load/error recovery, editable drafts,
   insertion at selection, deletion/disable behavior, and restart persistence.
   Verify compact, spacious, and e-ink layouts.
4. **Custom functions:** parameter binding, nested calls, argument counts, type
   behavior, and clear diagnostics. Use the same library and storage model.
5. **Snapshots and interchange:** exact Save result semantics, historical
   snapshots, export/import, then definition-aware links and QR codes.

Each slice should be independently reviewable and committed separately. The
first implementation task is the feasibility spike, not enabling the placeholder
variable dialog.
