# Keyboard interaction plan

The expression field is the primary keyboard surface. Normal text editing
must take priority over calculator-specific shortcuts.

## Implemented

| Key | Behavior |
| --- | --- |
| Left/Right | Move the expression caret. |
| Shift+Left/Right | Extend the text selection. |
| Home/End, Ctrl+Arrow, Backspace, Delete | Standard platform text editing. |
| Enter | Evaluate the current expression. |
| Ctrl+E | Refocus the expression field without selecting its contents. |
| Typed digits and operators | Insert directly into the expression. |

## Rules for future shortcuts

- Do not bind plain digits, operators, arrows, Backspace, Delete, or standard
  clipboard/undo shortcuts; the field already handles them correctly.
- Avoid browser-reserved shortcuts such as Ctrl+L, Ctrl+W, Ctrl+R, and Ctrl+1
  through Ctrl+9 so the web build remains usable.
- Prefer explicit, discoverable shortcuts for actions that cannot be expressed
  naturally as text: Ctrl+E for returning to the expression and Enter for
  evaluation.
- Keep Escape reserved for dismissing dialogs and transient UI rather than
  clearing a formula.

## Candidates to evaluate later

- F1 to open Help.
- A shortcut to show or hide the desktop keypad, provided it does not conflict
  with browser or window-manager behavior.
- A shortcut to switch General and Programmer keypads, only if it can be made
  discoverable and safe on both desktop and web.
