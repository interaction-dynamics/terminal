---
owner: friedrith
creation_date: 2026-11-26
status: active
---

# Terminal window

Gives the user normal terminal windows (⌘N), and the content every window shows: tabs, terminal, smart input, update banner and the menu button.

## How it works

- `NormalWindowController` is a regular window; the hotkey dropdown hosts the same content.
- `TerminalContentController` owns the tabs, the active terminal and the Settings tab; `+Input` connects the smart input to the tab's shell; `+Menu` is the menu button (Settings, Check for Updates, Show Onboarding, Send Feedback, About, Quit).
- `ContentRootView` lays out the title strip, the sidebar or tab bar, the update banner, the terminal and the input box. `AboutWindow` is the About window.

## Related

- Spec: [Look](../../../../../specs/02-look.md)
- Uses: [Tabs](../tabs/README.md), [Smart input](../smart-input/README.md), [Settings](../settings/README.md), [Updates](../updates/README.md)
- Hosted by: [Hotkey window](../hotkey-window/README.md)
