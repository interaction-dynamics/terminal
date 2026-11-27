# 11. Onboarding

Shown once, at first launch, over the first window. **Show Onboarding…** in
the menu button and the app menu opens it again.

Decided by Thibault (2026-11-27): a Raycast-style window, with these pages.

## Window

- Borderless, rounded (16 pt), dark, blurred, no title bar. Drag it by its
  background. **Esc** closes it.
- Footer: the **progress bar on the left** (one segment per step and
  "2 of 5"), **buttons on the right** (Back, Continue).
- Pages slide and fade between steps; their content rises in, one item after
  the other.
- Choices are written to the config file at once, so the windows behind
  change as you pick.
- Finishing or closing it marks it done (`onboarding.done` in the app's user
  defaults).

## Pages

1. **Welcome to The Terminal, the ultimate terminal for macOS.** An animated
   mark (turning gradient, blinking cursor, soft glow) and three points:
   - *Confidential:* no account, no telemetry; what you type never leaves
     the Mac.
   - *Light:* native and fast; nothing runs in the background.
   - *Aesthetic:* calm colours, clean type.
2. **Choose your look:** the theme cards (as in Settings).
3. **Your shell:** one card per installed shell, the login shell and zsh's
   smart input marked (see [settings](09-settings.md)).
4. **The hotkey window:** on/off, shortcut recorder, position, hide on blur, with a small
   screen that shows where the window drops in.
5. **Congratulations!** A check that draws itself with a burst of sparks,
   and a button to give feedback on GitHub (the issues page).

Sizes and timings live in `OnboardingTuning`
(`App/Sources/Terminal/Onboarding/Onboarding.swift`).
