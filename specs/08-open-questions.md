# 8. Open questions

1. **Input position: bottom-pinned (Warp) or inline?**
   Recommended: bottom-pinned, since Warp's layout is one of the reasons for
   this project. Inline is simpler and keeps the shell's own prompt
   (Starship, Powerlevel10k…). Could become a config option later.
2. **Which shell?** zsh is assumed (macOS default). If it's fish, fish 4.1+
   already supports click events, which helps the inline fallback.
3. **App name.** "terminal" is the folder name for now.
4. **Default theme and font.** Decided: `midnight`, Warp-like, with
   JetBrains Mono 12. See [look](02-look.md).
5. **Default hotkey.** Decided: `⌘⇧\`.
6. **Fig specs licence.** Confirm it allows bundling before M5.
7. **libghostty version to pin.** Latest stable Ghostty release at M0 time
   (1.4.x at the time of writing, to confirm).
8. **Distribution.** Personal use only (local build), or signed and notarised
   for others too?
9. **Tab side.** The spec says right by default (as asked), but the Warp
   screenshot it is modelled on has them on the left. Confirm.
