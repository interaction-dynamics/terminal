---
status: accepted
date: 2026-11-27
---

# Settings are a tab, and the config file stays the source of truth

## Context

Decided by Thibault on 2026-11-27 (see [Settings](../../../../../../../specs/09-settings.md)): settings open as a tab in the terminal with native controls, not a popup or a settings window.

## Considered options

- A popover from a gear button
- A separate settings window
- A tab in the terminal window

## Decision

Chosen option: "A tab". Each control writes its key to the config file, which stays readable and editable by hand.

## Consequences

- Good: no settings window (a non-goal), the file and the UI never disagree.
- Bad: every change reloads the config, so continuous controls (the opacity slider) write on release.
