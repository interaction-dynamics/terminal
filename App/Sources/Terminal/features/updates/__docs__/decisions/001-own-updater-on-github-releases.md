---
status: accepted
date: 2026-11-27
---

# Own small updater on GitHub releases instead of Sparkle

## Context

Decided by Thibault on 2026-11-27 (see [Releases and updates](../../../../../../../specs/10-updates.md)). The lean rule allows no background network calls; the update check is the one decided exception.

## Considered options

- Sparkle
- Our own updater reading GitHub's latest-release API

## Decision

Chosen option: "Our own updater", ad-hoc signed builds, a check at launch and every 24 h, and nothing installed without the user's click.

## Consequences

- Good: no third-party framework, one small request a day, nothing sent about the user.
- Bad: ad-hoc signing means the first download needs right-click → Open.
