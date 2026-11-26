# Store Prompt Specs in Spec Kit Format

## Context and Problem Statement

Most code in this repository is written by coding agents from prompts.
A prompt is the real requirement behind a change, but it disappears with the session: the pull request shows what the code does, not what was asked or why.
The next person or agent changing a feature cannot tell intended behaviour from accidental behaviour, and reviewers have nothing to check the diff against.
Decision records already capture technical choices (ADR 0001), but nothing captures the functional requirements.
Which format and location should agents use to store the specs that come from prompts?

## Considered Options

- GitHub Spec Kit feature specs in `specs/NNN-<feature>/spec.md`
- OpenSpec living specs in `openspec/specs/` with change folders in `openspec/changes/`
- Kiro specs (`requirements.md` in EARS notation, `design.md`, `tasks.md`)
- Free-form notes, or the prompt pasted in the pull request description

## Decision Outcome

Chosen option: "GitHub Spec Kit feature specs in `specs/NNN-<feature>/spec.md`", because it is the most widely used spec-driven development format, it is agent-agnostic, and the Interaction Dynamics `/business:write-spec` skill already writes client specs in this exact format and folder.
Prompt specs and client specs then share one format, one numbering and one set of tools (`/speckit.clarify`, `/speckit.plan`, `/speckit.tasks`).
Spec Kit's template already has a slot for the prompt (`**Input**: User description: "…"`), prioritised independently testable user stories, `Given / When / Then` scenarios, stable `FR-###` / `SC-###` IDs and `[NEEDS CLARIFICATION]` markers.

OpenSpec was the strongest alternative: its delta specs (`ADDED` / `MODIFIED` / `REMOVED` requirements, archived per change) fit a codebase that evolves prompt by prompt.
It was rejected because it would introduce a second format next to the client specs, and its change folders and archive step add process to every small prompt.
We keep its best idea instead: a spec is edited in place to describe the feature as it is now, and a `## Clarifications` log (Spec Kit's `/speckit.clarify` format) records each later prompt and the IDs it changed.

Kiro's EARS criteria are precise, but the format is tied to the Kiro IDE.
Free-form notes and pull request descriptions are neither structured nor findable when the feature changes again.

The rule lives in `.agents/rules/feature-specs.md`, the template in `specs/spec-template.md`.
`bun run check-spec-numbers` (in CI) fails when two parallel branches pick the same spec number, the clash that ADR numbers already hit.

### Consequences

- Good, because every behaviour asked for in a prompt has a durable, reviewable record next to the code.
- Good, because the specs work with Spec Kit if the project adopts its CLI, and with the client specs from `/business:write-spec`.
- Good, because stable requirement IDs let tests, pull requests and later prompts point at a precise requirement.
- Bad, because writing or updating a spec adds a step to every feature prompt, even small ones.
- Bad, because specs edited in place rely on Git history and the Clarifications log rather than explicit deltas, so a spec can drift from the code if an agent skips the update.
- Bad, because sequential numbers still collide across parallel branches; the CI check catches the clash but someone must renumber.
