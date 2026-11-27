---
status: proposed
date: 2026-11-27
---

# No "files changed" chip in the prompt line

## Context

Warp's prompt shows `± N` next to the branch. Getting it means running `git status` at every prompt, and the lean rule forbids processes and background work the user didn't ask for (see [Smart input](../../../../../../../specs/04-smart-input.md)).

## Considered options

- Run `git status` at every prompt
- Leave the chip out

## Decision

Chosen option: "Leave the chip out" for now. Folder and branch are read from `.git` without starting a process.

## Consequences

- Good: typing and prompts stay fast.
- Bad: less information than Warp's prompt.
