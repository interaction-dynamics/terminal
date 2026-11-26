# Rules for working on the terminal app

Read `specs/README.md` and the other files in `specs/` before changing
anything. The specs are the source of truth; update them when a decision
changes.

## The four must-haves

Speed, the look, the hotkey window, the smart input (mouse editing +
autocompletion). Every change serves one of them.

## The lean rule

- Don't add anything on the non-goals list in `specs/README.md` (AI by
  default, accounts, sync, telemetry, blocks, plugins) without
  an explicit decision from Thibault.
- Nothing runs in the background unless the user is using it. No timers,
  polling or network calls.
- The main thread does UI only.
- Every feature is checked against `specs/06-performance.md` before it ships.
  If typing gets slower, it doesn't ship.

## Engine

- Never modify libghostty. Use it through the `TerminalSurface` protocol only;
  no other file imports its C API.
- libghostty is pinned. Upgrade it on purpose, in its own commit, after
  re-running the benchmarks.

## Code

- Swift and AppKit for the app.
- Tooling scripts in **TypeScript on Bun**. Don't write Python.
- Keep weights, defaults and magic numbers in one obvious place each, so they
  are easy to tune.
