# Terminal

A very fast, pretty macOS terminal (Swift + libghostty) with Warp's look and hotkey window.

Start with the [specs](specs/README.md).

## Build

Needs macOS 14+, Xcode with the Metal Toolchain, and [mise](https://mise.jdx.dev)
(for the pinned Zig and Bun).

```bash
xcodebuild -downloadComponent MetalToolchain   # once
mise install
bun scripts/build-libghostty.ts                # clones and builds Ghostty v1.4.0 (a few minutes)
bun scripts/bundle.ts --open                   # builds build/Terminal.app and opens it
```

`swift test` runs the logic tests (config, history ranking, completion).
Launch with `TERMINAL_DEBUG=1` to print shell events to stderr.
