---
status: proposed
date: 2026-11-27
---

# Smart input and command blocks only with zsh for now

## Context

The smart input and the command blocks rely on our shell integration (prompt marks, OSC 7, the empty prompt), which only exists for zsh (`App/Resources/shell-integration/zsh`). The shell choice was added on 2026-11-27 (see [Settings](../../../../../../../specs/09-settings.md)).

## Considered options

- Offer every shell, with the smart input only for zsh
- Only offer zsh
- Write the integration for bash and fish first

## Decision

Chosen option: "Offer every shell, with the smart input only for zsh", because the choice was asked for now and the other shells still work as a plain terminal. The Settings tab and the onboarding say so.

## Consequences

- Good: any shell works today.
- Bad: bash and fish users don't get the smart input or the blocks until their integration exists.
