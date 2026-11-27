---
owner: friedrith
creation_date: 2026-11-26
status: active
---

# Smart input

Lets the user type commands in a real text box at the bottom of the window, edit them with the mouse, and accept suggestions.

## How it works

- `InputAreaView` pins the box to the bottom; `SmartTextView` is the editable text with ghost suggestions and the usual shell shortcuts.
- `PromptLineView` draws the folder and branch chips above the box, then the last exit status and duration.
- `SuggestionPopup` lists completions and history matches. The window's content controller sends the command to the tab's shell on Enter.

## Related

- Spec: [Smart input](../../../../../specs/04-smart-input.md)
- Uses: [Autocompletion](../autocompletion/README.md)
- Shown in: [Terminal window](../terminal-window/README.md)
- Decisions: see `__docs__/decisions/`.
