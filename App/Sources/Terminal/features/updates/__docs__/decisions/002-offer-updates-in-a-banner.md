---
status: accepted
date: 2026-11-27
---

# Offer updates in a banner, not an alert

## Context

Asked by Thibault on 2026-11-27: show a banner at the top of the window when a new version is available, like Warp's notices.

## Considered options

- An alert when the check finds a version
- A banner at the top of the windows

## Decision

Chosen option: "A banner". A background check never interrupts; Check for Updates… still answers with an alert.

## Consequences

- Good: the update waits until the user is ready.
- Bad: the banner takes one row of the terminal area while it shows.
