---
owner: friedrith
creation_date: 2026-11-26
status: active
---

# Tabs

Lets the user run several shells in one window, each in a tab named after its folder or running command, in a sidebar or along the top.

## How it works

- `Session` is one tab: its shell, its terminal surface, and the smart-input state driven by the shell integration (starting, at prompt, running).
- `TabSidebarView` (default, left) and `TabBarView` (top) draw the tabs; `⌘T`, `⌘W`, `⌘1`–`⌘9` come from the window.
- A background tab that finishes a command gets a dot until it is viewed.

## Related

- Spec: [Look](../../../../../specs/02-look.md)
- Uses: [Shell choice](../shell-choice/README.md), [Autocompletion](../autocompletion/README.md)
- Shown in: [Terminal window](../terminal-window/README.md)
- Decisions: see `__docs__/decisions/`.
