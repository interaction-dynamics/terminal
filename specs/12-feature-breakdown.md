---
status: accepted
date: 2026-11-27
---

# Feature breakdown of `App/Sources/Terminal`

## Context

The app is one Swift package target (`Terminal`). Since the last refactor the
code is grouped in folders by capability (`Tabs/`, `Input/`, `Completion/`,
`HotkeyWindow/`…), but none of them is a features-cli feature: no `features`
folder, no feature README. `features --json App/Sources/Terminal` returns `[]`.

Swift has no per-file imports inside a module, so features-cli can't compute
dependencies between features. "Depends on" below is read from the code. The
hotkey window and the terminal window use each other (the dropdown shows a
window's content; the content's Settings tab shows hotkey controls), so their
order is a choice, not a strict dependency order.

## Layout

Features go in `App/Sources/Terminal/features/<name>/`. SwiftPM compiles every
`.swift` file under `Sources/Terminal`, so moving files changes nothing for the
build.

The specs in `specs/` stay the source of truth (CLAUDE.md). Each feature
README links to its spec, and its `__docs__/decisions/` holds short decision
records that point to the spec section they come from.

## Features

Migration order, top to bottom (fewest dependencies first).

| #   | Feature         | Path                     | Owner      | Description                                                              | Depends on                                     | Done |
| --- | --------------- | ------------------------ | ---------- | ------------------------------------------------------------------------ | ---------------------------------------------- | ---- |
| 1   | Shell choice    | `features/shell-choice`  | friedrith  | Pick the shell new tabs start with (zsh, bash, fish…)                    | —                                              | [x]  |
| 2   | Autocompletion  | `features/autocompletion`| friedrith  | Suggestions from history, folders, files, branches and scripts           | —                                              | [x]  |
| 3   | Updates         | `features/updates`       | friedrith  | Check GitHub releases, show the banner, install and relaunch             | —                                              | [x]  |
| 4   | Smart input     | `features/smart-input`   | friedrith  | Bottom text box edited with the mouse, with the prompt line chips        | autocompletion                                 | [x]  |
| 5   | Tabs            | `features/tabs`          | friedrith  | Shell sessions in tabs, in a sidebar or on top                           | shell-choice, autocompletion                   | [x]  |
| 6   | Hotkey window   | `features/hotkey-window` | friedrith  | Dropdown terminal on a global shortcut, over any app                     | terminal-window (its content)                  | [x]  |
| 7   | Settings        | `features/settings`      | friedrith  | The Settings tab: native controls that write the config file             | shell-choice, hotkey-window, updates           | [ ]  |
| 8   | Onboarding      | `features/onboarding`    | friedrith  | First-launch window: welcome, theme, shell, hotkey window, done          | settings, shell-choice, hotkey-window          | [ ]  |
| 9   | Terminal window | `features/terminal-window`| friedrith | Normal windows and the content every window shows (tabs, terminal, input, menu) | tabs, smart-input, settings, updates          | [ ]  |

### Shell choice

- `Shell/Shells.swift` → `features/shell-choice/Shells.swift`
- `ShellPickerView` (from `Settings/SettingsControls.swift`) → `features/shell-choice/ShellPickerView.swift`

Decisions: smart input and blocks only with zsh for now; login shell is the default and writes nothing (spec 09).

### Autocompletion

- `Completion/*.swift` → `features/autocompletion/`

Decisions: history-first ranking with folder context; no Fig specs, small native generators (spec 05).

### Updates

- `Update/Updater.swift`, `Update/UpdateBanner.swift` → `features/updates/`

Decisions: own updater instead of Sparkle, ad-hoc signing, check at launch and every 24 h (the one network exception), banner instead of alerts (spec 10).

### Smart input

- `Input/*.swift` → `features/smart-input/`

Decisions: prompt line chips, no `± changes` chip (needs a process per prompt) (spec 04).

### Tabs

- `Tabs/*.swift` → `features/tabs/`

Decisions: sidebar on the left by default (spec 02).

### Hotkey window

- `HotkeyWindow/*.swift` → `features/hotkey-window/`
- `ShortcutRecorder`, `ScreenPositionPreview`, `HotkeyPositions` (from `Settings/SettingsControls.swift`) → `features/hotkey-window/HotkeyControls.swift`

Decisions: default `⌘⇧\`, hide on blur by default, Dock icon only while a normal window is open (spec 03).

### Settings

- `Settings/SettingsView.swift`, the rest of `Settings/SettingsControls.swift` (`ThemePickerView`, `NSColor(hex:)`) → `features/settings/`

Decisions: settings are a tab, not a window; the config file stays the source of truth (spec 09).

### Onboarding

- `Onboarding/**` → `features/onboarding/` (keeps `Pages/`)

Decisions: borderless animated window, five steps, shown once (spec 11).

### Terminal window

- `Windows/*.swift` → `features/terminal-window/`
- `App/AboutWindow.swift` → `features/terminal-window/AboutWindow.swift` (opened from the window's menu button and the app menu)

## Shared code

Stays outside `features/`:

- `App/` (`main.swift`, `AppDelegate`, `MainMenu`, `AppInfo`, `Debug`): application glue.
- `Engine/`: the libghostty wrapper behind `TerminalSurface`, used by tabs and windows. CLAUDE.md requires that only this folder touches libghostty's C API.
- `Config/` (`AppConfig`, `ConfigWatcher`, `Theme`): global config and theme, read by every feature.
- `Git/GitInfo.swift`: used by tabs, smart input and autocompletion.
- `FlippedView` (in `Settings/SettingsView.swift`, used by settings and onboarding) → `Shared/FlippedView.swift`.

## CI

New workflow `.github/workflows/features.yml` on pull requests: `npx features-cli@latest check App/Sources/Terminal`.

## Answers (2026-11-27)

- Owner: `friedrith` for every feature (GitHub login, written without `@`).
- About window: inside `terminal-window`.
