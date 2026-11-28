---
owner: friedrith
creation_date: 2026-11-26
status: active
---

# Settings

Lets the user change the theme, font size, opacity, tabs, hotkey window, shell and Dock visibility from a Settings tab with native controls.

## How it works

- `SettingsView` is the Settings tab (`⌘,` or the menu button), drawn in the terminal theme's colours. Every change is written to `~/.config/terminal/config` at once; the file watcher applies it.
- `ThemePickerView` shows each theme as a tiny terminal card.
- Uses the shell cards from Shell choice and the shortcut recorder from Hotkey window.

## Related

- Spec: [Settings](../../../../../specs/09-settings.md)
- Uses: [Shell choice](../shell-choice/README.md), [Hotkey window](../hotkey-window/README.md), [Updates](../updates/README.md)
- Opened in: [Terminal window](../terminal-window/README.md)
- Decisions: see `__docs__/decisions/`.
