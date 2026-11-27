---
owner: friedrith
creation_date: 2026-11-27
status: active
---

# Onboarding

Welcomes a new user and walks them through the theme, the shell and the hotkey window, in five animated steps.

## How it works

- `Onboarding` shows a borderless, rounded window at first launch (and from Show Onboarding…), with the progress at the bottom left and the buttons at the bottom right.
- One file per page in `Pages/`: welcome, theme, shell, hotkey window, done. Choices are written to the config as they are made.
- Reuses the theme cards (Settings), the shell cards (Shell choice) and the shortcut recorder (Hotkey window).

## Related

- Spec: [Onboarding](../../../../../specs/11-onboarding.md)
- Uses: [Settings](../settings/README.md), [Shell choice](../shell-choice/README.md), [Hotkey window](../hotkey-window/README.md)
- Decisions: see `__docs__/decisions/`.
