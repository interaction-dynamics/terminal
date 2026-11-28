---
owner: friedrith
creation_date: 2026-11-26
status: active
---

# Autocompletion

Suggests the next command and completes words as the user types: from their history, folders, files, git branches and package scripts.

## How it works

- `HistoryStore` keeps every command with its folder, git repo, exit code and duration (SQLite, off the main thread). `HistoryIndex` and `Ranker` rank them for the current context.
- `Completer` completes the word under the cursor: paths, commands on `$PATH`, git branches, npm/bun/pnpm/yarn scripts and a few other generators.
- The smart input asks for suggestions and shows them as ghost text and in the popup.

## Related

- Spec: [Autocompletion](../../../../../specs/05-autocompletion.md)
- Used by: [Smart input](../smart-input/README.md), [Tabs](../tabs/README.md) (records history)
