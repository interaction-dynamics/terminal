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
- Built with Zig as an xcframework and linked into the Xcode project. The exact
  build steps must be confirmed against the pinned Ghostty version and written
  into `scripts/` (Bun/TypeScript).
- Ghostty is MIT-licensed. Keep its licence file in the repo.

## Shell integration

- Reuse Ghostty's shell integration scripts (zsh, bash, fish) to emit prompt
  marks and the current folder. Inject them automatically when a shell starts,
  so the user's dotfiles don't need changes.
- **zsh first** (the macOS default), then fish and bash.

## Threads

- **Main thread:** UI and input only. Nothing that can take more than ~1 ms.
- **Engine threads:** owned by libghostty (IO, rendering).
- **Background queue:** history queries, ranking, completion specs, file
  listing. Every query is cancellable: a new keystroke cancels the old one.

## Repo layout (proposal)

```text
terminal/
├── README.md
├── CLAUDE.md               # rules for agents working in this repo
├── specs/                  # this folder
├── App/                    # Xcode project, Swift sources
│   ├── Windows/            # hotkey window, normal windows
│   ├── TabBar/
│   ├── Engine/             # TerminalSurface + libghostty wrapper
│   ├── Input/              # smart input text box
│   ├── Completion/         # history store, ranking, specs runner
│   └── Config/
├── Vendor/ghostty/         # pinned libghostty build output
└── scripts/                # Bun/TypeScript tooling (build libghostty, bench)
```

## Config

- One plain text file: `~/.config/terminal/config` (name TBD with the app).
- Same `key = value` style as Ghostty, so Ghostty options can be passed
  through to the engine where it makes sense (fonts, colours).
- Reloaded live when the file changes.
