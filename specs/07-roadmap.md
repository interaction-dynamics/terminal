# 7. Roadmap

Each milestone ends with something usable and a run of the
[performance budget](06-performance.md).

## M0: a shell in a window (1–2 days)

- Xcode project, libghostty pinned and built by a Bun script
- `TerminalSurface` wrapper; one window running zsh with Ghostty's renderer
- settings.json read at launch

## M1: the hotkey window and the look (2–3 days)

- Global shortcut, dropdown panel, all Spaces, over full-screen apps,
  autohide, size and position from config
- Theme, font, padding, blur

**After M1 it can replace Warp for daily use** (without the smart input).

## M2: tabs (2–3 days)

- Vertical tab sidebar (left by default; right or top in settings), in both the dropdown and normal windows, with tab search and `+`
- ⌘T / ⌘W / ⌘1–9, labels from folder or running command

## M2.5: settings (2–3 days)

- settings.json with live file watching (both directions)
- Settings tab with native controls, opened by ⌘, and the menu button (top-right); onboarding at first launch
- Theme switcher: midnight (default), graphite, frost, paper

## M3: smart input (1–2 weeks)

- Shell integration injected automatically (zsh first)
- Prompt states from OSC 133; plain terminal fallback when missing
- Native text box with full mouse editing, bracketed-paste send
- Our own prompt line (folder, git branch, exit status, duration)
- ↑/↓ history, Ctrl+C/D/L, Emacs shortcuts

## M4: smart history (1 week)

- SQLite store with context, zsh history import, privacy filters
- Ranking, grey ghost text, Ctrl+R popup

## M5: Tab completion (1 week)

- Paths and commands natively
- Fig specs in JavaScriptCore with generators

## M6: polish

- Splits
- Scrollback search
- Launch at login
- Signing and notarisation for a clean install
- fish and bash integration

The times assume working with AI agents and are rough guesses.
