# Calculator keypad design

This is the working design guide for PCalc Express keypad layouts. It records
product decisions separately from the current widget implementation so layouts
can evolve without losing their rationale.

## Primary use

The keypad is an expression editor for programmers, not a four-function desk
calculator. It should make common C/C++ expressions quick to enter with touch,
especially on an e-reader where opening a software keyboard is disruptive.

The first reference target is a portrait e-ink reader. Phones, tablets, desktop
windows, installed web apps, pointer input, and physical keyboards remain
supported. Layout decisions should follow available logical space and input
method rather than platform names alone.

## Firm principles

- Use the available screen. Keys should grow with the keypad region instead of
  leaving large unused margins or clustering in a phone-sized block.
- Keep the numeric keypad spatially stable. `7 8 9`, `4 5 6`, and `1 2 3`
  should retain their familiar relationship across layouts.
- Put **Equals** at the bottom-right corner. It is the terminal action and
  should be easy to locate without reading.
- Put **Space** in the bottom editing row, near zero and Equals. Space is common
  in readable expressions and should feel like a small keyboard space bar, not
  an obscure programmer operator.
- Put **Delete** at an edge near cursor and editing controls. It should not
  interrupt the number/operator grid or sit where a calculation action is
  expected.
- On reader/tablet widths, promote hexadecimal prefixes, shifts, and common
  bitwise operators into a row directly above the main arithmetic area.
- When width and height allow comfortable keys, include an A–F row on General
  above the prefix/operator row. Keep it in Programmer and the operator palette
  when the main keypad is too cramped for an extra row.
- Keep less common operators in a categorized palette. Categories should be
  meaningful (`Numbers`, `Bitwise`, `Logic`, `Math`), remain in a stable order,
  and show both the symbol and a short description.
- A popup is secondary input, so it must be faster to scan than a flat list and
  must never be the only route to the operators used in the device's primary
  workflow.

## Adaptive layouts

Choose a layout from the actual keypad constraints. Do not treat Android as a
phone or web as a desktop. Important inputs are usable width, usable height,
text scale, touch versus pointer use, and whether an e-ink display was detected
or selected.

The compact layout should preserve comfortable touch targets and the core
number/arithmetic/editing set. The reader/tablet layout may add columns to keep
programmer operations visible. Added space should improve reach and grouping;
it should not merely stretch labels across very wide buttons.

When vertical space is limited, scrolling the keypad is preferable to shrinking
keys below a reliable touch size. Expression and result areas should remain
usable, but should not reserve so much height that the keypad becomes cramped on
a large reader screen.

## E-ink behavior

E-ink needs both a visual treatment and an interaction treatment:

- Prefer black, white, strong outlines, and large stable shapes.
- Avoid shadows, translucent feedback, ripples, and decorative color changes.
- Switch keypad pages and layout states immediately. Sliding, cross-fading, and
  short button animations create ghosting without conveying useful information.
- Avoid continuous animation and repeated repaints.
- Do not disable scrolling when content genuinely needs it; direct manipulation
  is still better than clipped controls.

Android can identify known e-ink reader families from manufacturer and model
information. There is no general browser or Flutter API that proves a
screen uses e-ink, so automatic detection is a convenience rather than the
source of truth. The explicit E-ink theme remains the portable override.

## Visual hierarchy

Numbers should read as one group, arithmetic operators as another, editing keys
as another, and programmer keys as another. Equals should carry the strongest
emphasis. Destructive actions need clear distinction without relying only on
color. In the E-ink theme, border weight, fill, position, label, and spacing must
carry the hierarchy.

Use concise key labels. Tooltips and semantics should spell out symbolic
operations for pointer users and assistive technology. A visible label and its
spoken label may differ, but changing the visible label must not change the
button's action.

## Result controls

Formatting belongs beside the result it affects. These controls are secondary:
use a small settings/tune icon and expose the current selection inside the menu
rather than consuming result-row width with a persistent label. Floating-point
precision defaults to automatic. Hex prefix and grouping choices should update
the displayed and copied value without recalculating the expression.

## Validation

Every layout change should be checked at minimum at:

- a narrow phone viewport;
- a short phone viewport;
- a typical portrait e-ink reader viewport;
- a typical landscape e-ink reader viewport;
- a wide desktop window;
- increased text scale;
- light, dark, and E-ink themes.

Tests should assert important spatial invariants such as Space in the bottom
row, Equals in the bottom-right corner, Delete in the editing row, and promoted
programmer operators on reader widths. Goldens should cover representative
layouts, while behavior tests should verify insertion at the current selection,
semantic labels, and immediate e-ink page changes.

## Open design questions

- The exact width at which the reader layout should replace the compact layout.
- Whether Space should span multiple columns once the grid supports key spans.
- Which bitwise operators deserve permanent reader-layout positions after real
  usage: `&`, `|`, `^`, `~`, shifts, or a smaller subset.
- Whether portrait and landscape readers need distinct arrangements.
- Whether users should be able to pin operators from the palette into the main
  keypad.

Resolve these with device use and observation. Avoid encoding a preference as a
universal rule until it has been tested on an e-ink reader and at least one compact
phone layout.
