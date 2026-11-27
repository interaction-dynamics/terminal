---
owner: friedrith
creation_date: 2026-11-26
status: active
---

# Hotkey window

Lets the user drop a terminal over any app with one global shortcut, and send it away with the same shortcut.

## How it works

- `HotKey` registers the global shortcut (Carbon) and parses and displays shortcut specs such as `cmd+shift+backslash`.
- `HotkeyWindowController` slides the dropdown panel in on the screen under the mouse, on every Space and over full-screen apps, and hides it on blur when `hotkey-autohide` is on.
- `HotkeyControls.swift` holds the shortcut recorder and the position preview used by the Settings tab and the onboarding.

## Related

- Spec: [Hotkey window](../../../../../specs/03-hotkey-window.md)
- Shows: [Terminal window](../terminal-window/README.md)'s content
- Configured in: [Settings](../settings/README.md), [Onboarding](../onboarding/README.md)
- Decisions: see `__docs__/decisions/`.
