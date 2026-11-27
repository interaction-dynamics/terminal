# 1. Architecture

## Principle

Build the **app**, not the **engine**. Everything this project cares about
(look, hotkey window, smart input, autocompletion) sits next to the engine,
not inside it.

## Layers

```text
┌──────────────────────────────────────────────────────────┐
│ App (Swift / AppKit)                                     │
│  • Windows: hotkey dropdown + normal windows             │
│  • Tab bar, theme, config                                │
│  • Smart input: text box, ghost suggestions, Tab menu    │
│  • History store (SQLite) + ranking                      │
│  • Completion specs runner (JavaScriptCore)              │
├──────────────────────────────────────────────────────────┤
│ Engine layer (our own thin Swift wrapper)                │
│  • TerminalSurface protocol: write input, resize,        │
│    focus, events (title, cwd, prompt marks, exit codes)  │
├──────────────────────────────────────────────────────────┤
│ libghostty (Zig, C API)                                  │
│  • PTY + shell process                                   │
│  • Escape-code parsing, screen grid, scrollback          │
│  • Metal renderer, fonts, Unicode                        │
└──────────────────────────────────────────────────────────┘
```

## The engine layer

- All engine calls go through **one Swift protocol** (`TerminalSurface`).
  No other file imports the libghostty C API.
- This keeps the engine swappable. If we later want more control, the planned
  path is **libghostty-vt** (parsing and screen state only) plus our own Metal
  renderer, behind the same protocol.
- Events the app needs from the engine:
  - **Prompt marks** (OSC 133: prompt start, input start, command started,
    command finished with exit code). These drive the smart input.
  - **Current folder** (OSC 7).
  - **Window title**, bell, child process exit.
  - **Alternate screen** on/off (full-screen programs like vim, htop).

## libghostty

- Ghostty's macOS app is itself Swift on top of libghostty's C API, so this is
  a known-good path. cmux is an outside app that embeds it the same way.
- **The API is not officially stable.** Pin libghostty to one Ghostty commit
  or release. Upgrade on purpose, never automatically.
- Pinned to **Ghostty v1.4.0**, built with Zig 0.17.1 (pinned in `mise.toml`)
  as `GhosttyKit.xcframework` by `scripts/build-libghostty.ts`. Needs Xcode's
  Metal Toolchain. The app is a Swift package (`Package.swift`) linking that
  xcframework; `scripts/bundle.ts` assembles and signs `Terminal.app`.
- **Conditional config breaks per-surface options.** When the config uses a
  `light:…,dark:…` theme, libghostty rebuilds each new surface's config from
  the file and drops the env vars and command the app passes. The app
  resolves light/dark itself and hands libghostty a plain theme.
- Ghostty is MIT-licensed. Keep its licence file in the repo.

## Shell integration

- **Our own scripts**, not Ghostty's: Ghostty's shell integration is GPL-3.0,
  unlike the rest of Ghostty, so it is neither reused nor bundled. They live in
  `App/Resources/shell-integration/` and are injected when a shell starts
  (zsh: `ZDOTDIR` points at ours, which then loads the user's), so dotfiles
  don't need changes.
- zsh: `precmd` emits OSC 133;D (exit code) and OSC 7 (folder, host
  `localhost` because libghostty only accepts a local host), `preexec` emits
  OSC 133;C. OSC 7 at each prompt is how the app knows the prompt is ready.
  With the smart input on, the shell's own prompt is emptied.
- **zsh first** (the macOS default), then fish and bash.

## Threads

- **Main thread:** UI and input only. Nothing that can take more than ~1 ms.
- **Engine threads:** owned by libghostty (IO, rendering).
- **Background queue:** history queries, ranking, completion specs, file
  listing. Every query is cancellable: a new keystroke cancels the old one.

## Repo layout

```text
terminal/
├── README.md
├── CLAUDE.md               # rules for agents working in this repo
├── specs/                  # this folder
├── Package.swift           # Swift package: the app and its tests
├── App/
│   ├── Sources/Terminal/
│   │   ├── App/            # launch, menus
│   │   ├── Windows/        # hotkey window, normal windows
│   │   ├── Tabs/           # sessions, tab bar
│   │   ├── Engine/         # TerminalSurface + libghostty wrapper
│   │   ├── Input/          # smart input text box
│   │   ├── Completion/     # history store, ranking, completers
│   │   └── Config/
│   ├── Resources/          # shell integration scripts
│   └── Tests/
├── Vendor/ghostty/         # pinned libghostty build output
└── scripts/                # Bun/TypeScript tooling (build libghostty, bench)
```

## Settings

- One JSON file, `~/.config/terminal/settings.json`, edited by hand or
  through the Settings tab, kept in sync in real time.
  See [settings](09-settings.md).
