# 5. Autocompletion

Very smart suggestions, learned from history. Because every command goes
through our input box, the app knows far more about each command than a shell
history file does.

## Two kinds of suggestions

1. **Grey ghost text** after the cursor: the single best guess for the whole
   command, from history. → accepts it, ⌥→ accepts one word.
2. **Tab menu**: a list of completions for the current word (files, folders,
   git branches, script names, flags).

## History store

Local SQLite file in `~/Library/Application Support/<app>/history.sqlite`.
Never synced, never sent anywhere.

```sql
CREATE TABLE commands (
  id           INTEGER PRIMARY KEY,
  command      TEXT    NOT NULL,
  cwd          TEXT    NOT NULL,   -- from OSC 7
  git_root     TEXT,               -- repo root, if inside one
  exit_code    INTEGER,            -- from OSC 133 "command finished"
  started_at   INTEGER NOT NULL,   -- unix ms
  duration_ms  INTEGER,
  session_id   TEXT    NOT NULL,   -- one per tab
  prev_id      INTEGER REFERENCES commands(id)  -- command just before, same tab
);
CREATE INDEX idx_commands_command ON commands(command);
CREATE INDEX idx_commands_cwd     ON commands(cwd);
```

- **Import on first launch:** `~/.zsh_history` (and fish/bash history) so
  suggestions work from day one. Imported commands have no folder or exit
  code, so they rank lower.
- **Privacy:** commands starting with a space are not saved (same convention
  as `HIST_IGNORE_SPACE`). Commands that look like they contain secrets
  (`export *TOKEN=`, `*PASSWORD*`, `Authorization:` and similar) are not saved.
  A command can be deleted from the Ctrl+R popup.

## Ranking

For the text typed so far, candidates are past commands that **start with it**
(ghost text) or **fuzzily match it** (Ctrl+R). Each gets a score:

| Signal | Effect |
|---|---|
| Same folder | Strong boost |
| Same git repo (different folder) | Medium boost |
| Follows the previous command in this tab (seen `A` then `B` before) | Strong boost |
| Frequency | Boost, on a log scale so very common commands don't drown the rest |
| Recency | Boost that decays over days |
| Last run failed | Penalty; failed-only commands hidden from ghost text |
| Imported (no context) | Small penalty |

- Start with **hand-tuned weights** in one Swift file, easy to tweak.
- Log which suggestion was accepted, to tune weights later (locally).
- This is how McFly and Atuin rank history; no machine learning needed for v1.

## Tab completion

1. **Paths:** files and folders, natively with `FileManager`. Hidden files only
   after typing `.`.
2. **Commands:** from `$PATH`, cached.
3. **Arguments and flags:** Fig's open-source completion specs
   (`withfig/autocomplete`, around 500 CLIs: git, bun, npm, docker, brew…).
   - Specs are JavaScript compiled from TypeScript, run with
     **JavaScriptCore** (built into macOS).
   - "Generators" (for example listing git branches) run shell commands in
     the background with a timeout (300 ms) and cached results.
   - Bundle a pinned copy of the specs. Check the licence before bundling.
   - **Built so far:** native generators instead (git subcommands and
     branches, npm/bun/pnpm/yarn scripts from `package.json`, make targets).
     Fig specs come later.
4. **History** fills in when nothing else matches.

## Performance

- Distinct commands loaded into memory at launch (deduplicated with counts),
  SQLite only for writes and Ctrl+R detail.
- The index keeps every distinct command in byte order (one binary search per
  prefix). When a short prefix matches thousands of commands, the app uses a
  list ranked once per prompt, off the main thread, instead of scoring them
  all. Measured: < 0.1 ms per lookup over 200,000 commands; ranking takes
  ~70 ms in the background when the prompt comes back.
- Ghost text lookup ≤ 5 ms per keystroke with 200,000 history entries.
- Every lookup runs off the main thread and is cancelled by the next keystroke.
- Tab menu appears ≤ 50 ms for paths and specs (generators may fill in later).

## Later (not v1)

- Optional AI suggestion (off by default, local model preferred).
- Learned weights from accepted suggestions.
- Typo fix ("did you mean `git status`?") from history.
