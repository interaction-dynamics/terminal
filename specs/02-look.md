# 2. Look

Goal: as pretty as Warp, as fast as Ghostty. Looks are a must-have: a plain,
unstyled terminal is not acceptable.

## Layout (Warp-like)

- **Tab bar in the title bar**, drawn by us (not native macOS tabs): rounded
  tabs, current folder or running command as the label, a `+` button.
- **Terminal output** fills the window above the input.
- **Input area pinned at the bottom**, like Warp: our own prompt line (folder,
  git branch, last exit status) and the smart input text box below it.
  See [smart input](04-smart-input.md). Inline input is the fallback, see
  [open questions](08-open-questions.md).
- While a full-screen program runs (vim, htop, Claude Code), the input area
  hides and the terminal takes the whole window.

## Styling

| Setting | Default |
|---|---|
| Theme | A dark theme close to Warp's default (to pick) |
| Font | JetBrains Mono 14 (to pick) |
| Window padding | 16 px horizontal, 12 px vertical, balanced |
| Background | Slightly transparent (around 0.92) with blur |
| Cursor | Bar, blinking |
| Corners | Rounded, matching macOS |
| Light/dark | Follows the system, with one theme for each |

- Themes come from the same theme files Ghostty uses (the iTerm2 colour
  scheme collection), so hundreds are available from day one.
- All of it is set in the config file. No settings window.

## Feel

- Animations short and optional (hotkey slide ≤ 150 ms; tab switch instant).
- No spinners, no splash screen, no "what's new" pop-ups.
- Subtle separators, no heavy borders.
