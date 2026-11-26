# Terminal

A **very fast**, **pretty** macOS terminal with Warp's look and hotkey window,
and none of Warp's weight.

> Status: specification, nothing built yet. Written 2026-11-26.

## Why

Warp has the right layout and the right look, but it is heavy and slow, and
the slowness comes from its extra features (AI, cloud, sign-in, blocks), not
its language. Ghostty is fast but not pretty, and its mouse support at the
prompt is limited. This project keeps Ghostty's engine for speed and builds
the parts Warp gets right on top of it.

## Must-haves

1. **Speed.** Typing, scrolling and showing the window must feel instant.
   See [performance budget](06-performance.md).
2. **The look.** Warp-like layout, theme, padding, blur and tab bar.
   See [look](02-look.md).
3. **The hotkey window.** A dropdown summoned by a global shortcut.
   See [hotkey window](03-hotkey-window.md).
4. **The smart input:**
   - mouse editing of the command line, like a normal text field.
     See [smart input](04-smart-input.md).
   - smart autocompletion learned from history.
     See [autocompletion](05-autocompletion.md).

## Non-goals (the lean rule)

Leaving these out is what keeps the app fast. Adding one needs a deliberate
decision and a performance check.

- No AI features by default
- No account, sign-in, cloud sync or telemetry
- No Warp-style "blocks" (output split into cards)
- No plugin system, no settings window (one config file instead)
- No Linux or Windows version
- No custom terminal engine (see [architecture](01-architecture.md))

## Stack

| Layer | Choice |
|---|---|
| Language | Swift |
| UI | AppKit (SwiftUI only where it is clearly faster to write and costs nothing) |
| Terminal engine | libghostty (Ghostty's core: escape codes, screen state, Metal renderer) |
| History store | SQLite, local only |
| Completion specs | Fig's open-source specs (TypeScript/JS), run in JavaScriptCore |
| Tooling scripts | TypeScript on Bun (no Python) |

## Specs

1. [Architecture](01-architecture.md)
2. [Look](02-look.md)
3. [Hotkey window](03-hotkey-window.md)
4. [Smart input](04-smart-input.md)
5. [Autocompletion](05-autocompletion.md)
6. [Performance budget](06-performance.md)
7. [Roadmap](07-roadmap.md)
8. [Open questions](08-open-questions.md)
9. [Rules for agents](agent-rules.md)
