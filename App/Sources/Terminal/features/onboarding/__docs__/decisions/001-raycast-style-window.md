---
status: accepted
date: 2026-11-27
---

# A Raycast-style onboarding window

## Context

Decided by Thibault on 2026-11-27 (see [Onboarding](../../../../../../../specs/11-onboarding.md)): a window without border or title bar, several steps, a progress bar on the left and buttons on the right, with animation.

## Considered options

- A borderless animated window with steps
- A welcome tab in the terminal
- No onboarding

## Decision

Chosen option: "A borderless animated window", shown once at first launch.

## Consequences

- Good: first-time choices (theme, shell, hotkey) are made before the first command.
- Bad: Core Animation code to maintain for a screen seen once.
