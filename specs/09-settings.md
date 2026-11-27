# 9. Settings

Settings live in **one JSON file**, and the terminal has its **own settings
UI** to edit it. Both stay in sync in real time.

## The file

- Path: `~/.config/terminal/settings.json` (name follows the app name).
- Created with the defaults below on first launch.
- Human-editable. Unknown keys are kept when the UI saves (round-trip), so
  nothing typed by hand is lost.

```json
{
  "theme": "midnight",
  "font": { "family": "JetBrains Mono", "size": 12 },
  "tabs": { "position": "left", "width": 220 },
  "hotkey": {
    "shortcut": "cmd+shift+backslash",
    "position": "top",
    "height": "45%",
    "screen": "mouse",
    "autohide": true,
    "animation": 0.12
  },
  "window": { "padding": [16, 12], "opacity": 1.0, "blur": 0 },
  "input": { "position": "bottom" },
  "cursor": { "style": "bar", "blink": true }
}
```

## The settings UI

Decided by Thibault (2026-11-27): settings are **a tab**, not a popup or a
separate window.

- Opened with `⌘,` or **Settings…** in the menu button (see
  [look](02-look.md)) or the app menu. It opens a **Settings tab** at the end
  of the tab list (gear icon, no `⌘N`), or switches to it if it is open.
- The tab shows **native controls in the terminal area** (no smart input under
  it), in the terminal theme's colours. It closes like a tab (`⌘W`, its X).
- Sections:
  - **Appearance:** theme cards (a tiny terminal in each theme's colours), font
    size, tab position.
  - **Hotkey window:** on/off, shortcut recorder, position.
  - **General:** shell, Dock and app switcher, smart input, open at login.
  - **About:** version, Check for Updates…, Show Onboarding…, Send Feedback…,
    Open Config File….
- Every change applies **immediately** (no Save button) and is written to the
  file.

### Shell

`shell = /bin/bash` (any path; `auto` or no line = the login shell). The
picker lists `/etc/shells` plus the usual Homebrew shells (fish, nu, bash,
zsh…) that are installed. New tabs start it as a login shell; open tabs keep
theirs. Smart input and command blocks come from the zsh integration, so
other shells get a plain terminal for now; the UI says so.

### Dock and app switcher

`dock-icon = auto | always | never`. `auto` (default): shown while a normal
window is open, hidden when only the hotkey window is in use (or always shown
if the hotkey window is off, so the app stays reachable). Hidden means
no Dock icon, no `⌘⇥` entry and no menu bar; the menu button has everything.

> **Status (built so far):** the app still reads the first-cut
> `~/.config/terminal/config` (Ghostty-style `key = value` lines; unknown keys
> go to libghostty). The Settings tab edits that file in place (other lines and
> comments kept) and the file watcher applies the change. Built: everything
> listed above. Moving to `settings.json`, padding, opacity, hotkey size and
> screen are still to do.

## Real-time sync

- **File → app:** the app watches the file. When it changes (in any editor,
  by a script, by git), the new settings apply within ~100 ms, including in an
  open settings tab.
  - Watch the file **and** its folder: most editors save by writing a new
    file and renaming it, which breaks a plain file watcher.
  - Debounce changes by ~50 ms.
- **App → file:** the UI writes atomically (temp file + rename), and the app
  ignores the change event caused by its own write (compare a content hash).
- **Invalid JSON:** keep the last valid settings, show a small non-blocking
  banner ("settings.json has an error on line N"), and recover as soon as the
  file is fixed. Never overwrite a broken file from the UI.
- Settings that can't change live (none planned) would say so in the UI.

## Themes

A few built-in themes, switchable in the UI or with `"theme"` in the file:

| Name | Style |
|---|---|
| `midnight` (default) | Warp-like near-black, see [look](02-look.md) |
| `graphite` | Softer dark grey, lower contrast |
| `frost` | Dark blue-grey (Nord-like) |
| `paper` | Light |

A custom theme can be added later as a JSON file in
`~/.config/terminal/themes/`, using the same keys as the built-ins.
