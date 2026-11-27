# 2. Look

Goal: as pretty as Warp, as fast as Ghostty. Looks are a must-have: a plain,
unstyled terminal is not acceptable. **Dark by default**, modelled on
Thibault's current Warp setup.

## Layout (Warp-like)

- **Vertical tab sidebar**, drawn by us (not native macOS tabs).
  - **Position is a setting: left (default), right, or top** (horizontal tab
    bar). See [settings](09-settings.md).
  - Top of the sidebar: a **"New tab" row** (`+`, `⌘T`); a **"Search tabs…"
    field** comes later.
  - Each tab is a small card: an icon (shell, or the running program), the
    title (folder or running command, truncated with "…"), the full path
    below it in dim text, and its shortcut on the right (`⌘1`, `⌘2`…).
    The selected tab has a slightly lighter background and a thin border.
- **Title strip** across the top of the window: traffic lights on the left,
  the active tab's title in the middle (sidebar modes), and a **gear icon
  always visible at the top-right**, for every tab position and in the hotkey
  dropdown. The gear opens the [settings](09-settings.md) as a popup over the
  terminal. The strip drags the window; double-click zooms it.
- **Terminal output** fills the rest of the window. Each command starts with
  a dim header line (folder, git branch) and ends with a thin line carrying
  its exit code (when it failed, in red) and its duration such as `0.084s`.
- **Input area pinned at the bottom**, like Warp: a small chip with the
  current folder, then the smart input text box. See
  [smart input](04-smart-input.md).
- While a full-screen program runs (vim, htop, Claude Code), the input area
  hides and the terminal takes the whole window.

## Default theme: `midnight` (Warp-like)

Colours picked from a screenshot of Thibault's Warp; tune by eye against it.

| Element | Colour (approx.) |
|---|---|
| Terminal background | `#0E0E0E` (near-black) |
| Sidebar background | `#141414` |
| Selected tab | `#1E1E1E`, border `#2C2C2C` |
| Separators | `#222222` |
| Main text | `#D4D4D4` |
| Dim text (paths, durations, headers) | `#6E6E6E` |
| Success (✓) | `#4EBA65` |
| Error (✗) | `#E5534B` |
| Links / underlined paths | Main text, underlined |
| Banner (warnings) | `#1A1A1A` with a yellow `⚠` icon |

| Setting | Default |
|---|---|
| Font | Monospace, small: JetBrains Mono 12 |
| Window padding | 16 px horizontal, 12 px vertical |
| Background | Opaque (no blur by default; available in settings) |
| Cursor | Bar, blinking |
| Corners | Rounded, matching macOS |

Other built-in themes (`graphite`, `frost`, `paper`) are listed in
[settings](09-settings.md). The ANSI colour palette for each theme can also
reuse Ghostty's theme files (the iTerm2 colour scheme collection).

## Feel

- Animations short and optional (hotkey slide ≤ 150 ms; tab switch instant).
- **Zoom**: `⌘+` / `⌘−` / `⌘0` change the text size in every window and the
  app's own chrome (8–36 pt). Zoom is not saved: each launch starts at the
  configured size.
- No spinners, no splash screen, no "what's new" pop-ups.
- Subtle separators, no heavy borders.
