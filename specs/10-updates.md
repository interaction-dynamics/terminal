# 10. Releases and updates

Releases are built by GitHub Actions and published on GitHub. The app checks
for a newer release and, if you agree, installs it and relaunches.

Decided by Thibault (2026-11-27): ad-hoc signing for now, a check at launch
and every 24 hours, ask before installing, and our own small updater rather
than Sparkle.

## Making a release

1. Once: `bun scripts/release-keys.ts --set-secret` creates the Ed25519 key
   pair. The public key goes to `App/Resources/update-public-key.txt`
   (committed); the private key goes to the `UPDATE_SIGNING_KEY` GitHub secret,
   with a copy in `~/.config/terminal-release/` to keep somewhere safe.
2. Each release: `git tag v0.2.0 && git push origin v0.2.0`.
3. `.github/workflows/release.yml` builds libghostty (cached), runs the
   tests, builds the app with that version (`bun scripts/bundle.ts --version`),
   zips it and signs the zip (`bun scripts/release-package.ts`), then creates
   the GitHub release with `Terminal-<version>.zip` and
   `Terminal-<version>.zip.sig`, and notes generated from the commits.

Builds are for Apple silicon (libghostty is built for the runner's arch).

## Signing

- The app is **ad-hoc signed**, not notarised. The first download from GitHub
  needs a right-click → Open (or `xattr -dr com.apple.quarantine
  Terminal.app`). Updates installed by the app don't need that.
- Every zip is signed with the Ed25519 key. The app installs nothing whose
  signature doesn't match the public key it ships with.
- Developer ID signing and notarisation can be added later in the workflow.

## The updater (in the app)

- **Only in release builds** (`TerminalReleaseBuild` in Info.plist, set by
  `bundle.ts --version`). Local builds never check.
- **When:** at launch if the last check is more than 24 h old, then every
  24 h while the app runs, and from **Check for Updates…** in the app menu.
  This is the one exception to "no network calls": one small request to
  GitHub's latest-release API, nothing sent about the user.
- **Found a newer version:** an alert with the release notes and three
  choices: **Install and Relaunch**, **Later**, **Skip This Version**. A
  background check waits until the app is in front before asking.
- **Install:** download the `.sig` and the zip, check the signature, unzip
  with `ditto`, check the bundle id and version, swap the app in place, and
  relaunch once the old process has exited. All of this runs off the main
  thread; only the alerts are on it.
- If the app sits somewhere it can't write to, it says so and installs
  nothing.
- Settings to tune (repository, interval) live in `UpdateTuning`
  (`App/Sources/Terminal/Update/Updater.swift`).

## Testing without publishing

`TERMINAL_UPDATE_URL` points the updater at another "latest release" URL.
A local Bun server that serves the same JSON and the two files is enough to
run the whole flow (check, alert, download, verify, swap, relaunch) on a
release build.
