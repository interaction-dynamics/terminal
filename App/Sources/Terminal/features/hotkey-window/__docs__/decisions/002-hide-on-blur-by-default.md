---
status: accepted
date: 2026-11-27
---

# Hide the dropdown on blur by default

## Context

Asked by Thibault on 2026-11-27: a setting to hide the hotkey window when it loses focus, on by default (see [Hotkey window](../../../../../../../specs/03-hotkey-window.md)).

## Considered options

- Hide when another app is clicked (default on)
- Stay until the shortcut is pressed again

## Decision

Chosen option: "Hide on blur, on by default", with a switch in Settings and the onboarding (`hotkey-autohide`). Our own menus, popovers and alerts don't count as blur.

## Consequences

- Good: behaves like a quick terminal out of the box.
- Bad: copying between the dropdown and another app needs the shortcut again.
