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

- Opened by the **gear icon** at the top-right of the window's title strip
  (always visible, whatever the tab position, also in the hotkey dropdown), by
  `⌘,`, or from the menu bar.
- Opens **as a popup over the terminal**, anchored to the gear, not as a tab
  or a separate window. **Esc** or a **click outside** closes it; pressing the
  gear again closes it too.
- Sections: **Appearance** (theme picker with live preview, font, size,
  padding, opacity), **Tabs** (position: left / right / top, width),
  **Hotkey** (record a shortcut, position, size, screen, autohide),
  **Input** (bottom / inline), and a link **"Open settings.json"** that opens
  the file in the default editor.
- Every change applies **immediately** (no Save button) and is written to the
  file.

> **Status (built so far):** the app still reads the first-cut
> `~/.config/terminal/config` (Ghostty-style `key = value` lines; unknown keys
> go to libghostty). The popup edits that file in place (other lines and
> comments kept) and the file watcher applies the change. The popup has theme,
> tab position, font size, hotkey (typed, e.g. `cmd+shift+backslash`), smart
> input, open at login, and "Open config file…". Moving to `settings.json` and
> the remaining sections is still to do.

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
