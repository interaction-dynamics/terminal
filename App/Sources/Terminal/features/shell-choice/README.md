---
owner: friedrith
creation_date: 2026-11-27
status: active
---

# Shell choice

Lets the user pick the shell new tabs start with: zsh, bash, fish or any other installed shell.

## How it works

- `Shells` lists the shells in `/etc/shells` plus Homebrew's, finds the login shell, and resolves the `shell` config key (`auto` means the login shell).
- `ShellPickerView` shows one card per shell; the Settings tab and the onboarding use it. Choosing the login shell removes the `shell` line from the config.
- Tabs start the chosen shell as a login shell. Only zsh loads our shell integration.

## Related

- Spec: [Settings](../../../../../specs/09-settings.md)
- Used by: [Tabs](../tabs/README.md), [Settings](../settings/README.md), [Onboarding](../onboarding/README.md)
- Decisions: see `__docs__/decisions/`.
