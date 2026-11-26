# Vendor tasteskill for frontend design

## Context and Problem Statement

Agents building pages in this boilerplate fall back on the same generic landing-page look: centred hero, three feature cards, gradient blobs, vague copy.
The `frontend-design` skill in `.claude/skills/` gives taste guidance in prose only, with no way to check the result.
[tasteskill](https://tasteskill.dev) (`design-taste-frontend`, MIT, from `github.com/Leonxlnx/taste-skill`) is an Agent Skill that deals a palette, font pairing and hero layout per page kind, ships a component and photograph kit, and checks the built page in headless Chrome with a finish gate that runs as a Claude Code `Stop` hook.
How do we make it available to every agent working on a project created from this boilerplate?

## Considered Options

- Vendor the whole skill in `.agents/skills/design-taste-frontend`, linked from `.claude/skills/`
- Document the `npx skills add https://github.com/Leonxlnx/taste-skill --skill design-taste-frontend` command and commit nothing
- Register the `Leonxlnx/taste-skill` Claude Code plugin marketplace in `.claude/settings.json`

## Decision Outcome

Chosen option: "Vendor the whole skill in `.agents/skills/design-taste-frontend`, linked from `.claude/skills/`", because it is how the other third-party skills (`shadcn`, `frontend-design`, the features-cli skills, ADR 0047) are shipped: pinned, reviewable, available offline and to every agent that reads `.agents/skills/`, not only Claude Code.

- The vendored copy is `skills/taste-skill/` of upstream commit `d1a2bb41d927083ac7118f60cfc9cdf711810ea0` (`tasteskill 2.5.1`), plus its `LICENSE`, unmodified.
  The folder is named after the skill (`design-taste-frontend`) because its `Stop` hook looks for `gate.mjs` under `$CLAUDE_PROJECT_DIR/.claude/skills/design-taste-frontend/` and `.agents/skills/design-taste-frontend/`.
- To update it, copy `skills/taste-skill/` and `LICENSE` from a newer upstream commit over the folder, record the commit here, and review the diff of `scripts/` (the hook runs `scripts/gate.mjs`).
- oxfmt, oxlint and knip ignore the folder so it stays byte-identical to upstream.
- `.taste-skill/` (deal history, gate state and Chrome profiles the scripts write in the project) is git-ignored.
- `.agents/rules/ui-conventions.md` defers to the skill for visual design on any UI work, while keeping the repo's implementation rules: theme tokens in `globals.css`, `next/font`, `next/image`, shadcn/ui primitives, Server Components and accessibility.
  In `apps/web` the skill builds inside the existing Next.js app and runs its checker and gate against the running app, never by switching it to a static export.
- `frontend-design` stays; tasteskill is the one to follow when both apply.

### Consequences

- Good, because pages built by agents follow one opinionated, checked design system instead of the model's defaults.
- Good, because the checker and the finish gate catch empty visuals, contrast drops, misaligned edges and placeholder copy in a real browser before the page is handed over.
- Good, because the scripts install nothing and need no API keys; they use Node 22+ and the Chromium already present in CI images and cloud sessions.
- Bad, because the folder adds about 40 MB (1,600 files, mostly the bundled photograph, icon and component kit) to every clone of the boilerplate.
- Bad, because the vendored copy does not update itself; upstream fixes need a manual refresh.
- Bad, because the skill favours expressive pages (dealt fonts, scroll moments, shaders on software pages) over the restrained look the UI rule asked for so far; the rule now defers to it on visual design.
- Bad, because the scripts fetch Google Fonts, brand icons (jsDelivr, GitHub) and extra photographs (Wikimedia Commons, Unsplash) when they are not bundled, so sessions with a restricted network may need those hosts allowed.
