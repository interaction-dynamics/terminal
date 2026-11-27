# 6. Performance budget

"Very fast" is the first must-have, so it has numbers. These are starting
targets: measure Ghostty on the same Mac first and aim to match it.

| Metric | Target |
|---|---|
| Key press → character on screen | Same as Ghostty (aim ≤ 10 ms) |
| Hotkey → window visible | ≤ 50 ms (plus the slide animation, if on) |
| Launch → first prompt | ≤ 300 ms |
| New tab → prompt | ≤ 150 ms (mostly the shell's own start-up) |
| Ghost suggestion per keystroke | ≤ 5 ms |
| Tab menu | ≤ 50 ms |
| Memory, one tab idle | Within 20% of Ghostty |
| CPU, idle | ~0% (no timers, no polling) |
| `cat` of a 100 MB log | Same as Ghostty |

## Rules

- **Nothing runs in the background unless the user is using it.** No timers,
  no polling, no network. One decided exception: the update check, at launch
  and every 24 h in release builds ([updates](10-updates.md)).
- **Main thread does UI only.** Anything slower than 1 ms moves off it.
- **The hotkey window is never rebuilt**, only shown and hidden.
- **Every new feature gets a before/after measurement** of the table above.
  If it makes typing slower, it doesn't ship.

## Tooling

- `scripts/bench.ts` (Bun): runs the measurable rows (launch time, `cat`
  throughput, memory) and prints a comparison with the previous run and with
  Ghostty.
- Instruments (Time Profiler, Allocations) for anything that regresses.
