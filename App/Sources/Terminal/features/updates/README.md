---
owner: friedrith
creation_date: 2026-11-27
status: active
---

# Updates

Tells the user when a new version is on GitHub and installs it in one click, then relaunches.

## How it works

- `Updater` checks GitHub's latest release at launch and every 24 h (release builds only), verifies the Ed25519 signature of the zip, swaps the app and relaunches.
- `UpdateBanner` shows a newer version at the top of every window: Release Notes, Install and Relaunch, Skip This Version, close.
- Releases are built by `.github/workflows/release.yml` from a `vX.Y.Z` tag.

## Related

- Spec: [Releases and updates](../../../../../specs/10-updates.md)
- Shown in: [Terminal window](../terminal-window/README.md)
- Decisions: see `__docs__/decisions/`.
