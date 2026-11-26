# 4. Smart input

Edit the command line like a normal text field, with the mouse, the way Warp
does. Ghostty 1.3 only does part of this (Option+click in zsh, plain click in
fish) and cannot select text at the prompt.

## The idea

While the shell is **waiting for a command**, the app shows its **own native
text box** instead of letting the shell draw the line. When you press Enter,
the text is sent to the shell. While a command **runs**, the box hides and
keys go straight to the program.

## States

Driven by the prompt marks from shell integration (OSC 133):

| State | Between | Input box | Keys go to |
|---|---|---|---|
| At prompt | input start → command started | Visible, focused | The input box |
| Running | command started → command finished | Hidden | The program (PTY) |
| Full-screen | alternate screen on | Hidden, terminal fills the window | The program (PTY) |
| No integration | no prompt marks seen | Hidden | The program (PTY), plain terminal |

The last row is the safety net: inside `ssh`, a container, or a shell without
integration, the app behaves like a plain terminal.

## Mouse and editing (must work)

- Click to place the cursor
- Drag to select, Shift+click to extend, double-click a word, triple-click the line
- Type or delete to replace the selection
- ⌘C / ⌘X / ⌘V, ⌘Z / ⇧⌘Z (undo, redo)
- ⌥←/⌥→ by word, ⌘←/⌘→ to start/end of line
- Multi-line commands (⇧Enter for a new line)
- Standard macOS text features for free: input methods, accents, emoji
  picker, spell check off

## Sending the command

- On Enter, send the text using **bracketed paste**, then a carriage return,
  so the shell receives it as one piece and does not interpret any key inside
  it.
- The command is saved to the history store with its context (see
  [autocompletion](05-autocompletion.md)).

## Shell keys we must handle ourselves

The shell's own line editor is bypassed, so these are rebuilt in the input box:

| Key | Behaviour |
|---|---|
| ↑ / ↓ | Previous / next command from history (on the first / last line) |
| → or End at end of text | Accept the grey suggestion |
| ⌥→ | Accept one word of the suggestion |
| Tab | Completion menu (paths, then Fig specs) |
| Ctrl+R | History search popup (fuzzy, ranked) |
| Ctrl+C | Clear the input (and send interrupt if the shell needs it) |
| Ctrl+D | On empty input, send EOF to the shell |
| Ctrl+L / ⌘K | Clear the screen |
| Ctrl+A / Ctrl+E / Ctrl+U / Ctrl+K / Ctrl+W | Emacs-style shortcuts, like a shell |

## Prompt line

- Drawn by us above the input box: current folder, git branch, last exit
  status, and how long the last command took.
- The shell integration sets the shell's own prompt to empty inside this
  terminal only, so it is not drawn twice.
- Inline mode (fallback, see [open questions](08-open-questions.md)): keep the
  shell's own prompt and place the text box right after it.

## Known limitations (accepted)

- Shell plugins that work by editing the line (zsh-autosuggestions,
  zsh-syntax-highlighting, fzf's Ctrl+R widget) do nothing in the input box.
  Our own features replace them.
- Custom zsh key bindings (`bindkey`) are not honoured in the input box.
