# Feature Specs

Apply this rule when a prompt asks for new or changed behaviour that a
user, an admin or another system can observe: a feature, a change to an
existing feature, or a bug fix that reveals a case the spec missed.

Skip it for work with no observable behaviour change: refactors,
dependency bumps, CI, tooling, formatting and documentation. Those get a
decision record instead when they involve a choice
(`decision-records.md`).

## Rule

Every behaviour asked for in a prompt is stored as a
[GitHub Spec Kit](https://github.com/github/spec-kit) feature spec in
`specs/`, written or updated **before** the code, and committed in the
same pull request as the code.

The spec is the durable record of _what_ was asked and _why_. The code,
the decision records and `plan.md` record _how_.

## Where

```
specs/
  spec-template.md          ← copy this
  NNN-<feature-name>/
    spec.md                 ← required
    plan.md, tasks.md       ← optional (Spec Kit /speckit.plan, /speckit.tasks)
```

- `NNN` is the next free three-digit number after the highest folder
  in `specs/`. `bun run check-spec-numbers` (also run in CI) fails if
  two folders share a number: on a clash after a rebase, take the next
  free number.
- `<feature-name>` is 2–4 kebab-case words naming the capability, not
  the task (`004-block-users`, not `004-fix-admin-bug`).
- Client specs written by `/business:write-spec` live in the same folder
  and follow the same format.

## New spec or existing one

Search `specs/` first (folder names, then `grep` for the feature's
words).

- **The prompt extends or changes a specced feature** → edit that
  `spec.md` in place so it describes the feature as it is now. Add a
  bullet under `## Clarifications` for the prompt (see below). Never
  create a second spec for the same capability.
- **The prompt adds a new capability** → copy `specs/spec-template.md`
  to `specs/NNN-<feature-name>/spec.md`.
- **The prompt covers several independent capabilities** → one spec per
  capability, each shippable on its own.
- **A bug fix** restoring behaviour the spec already describes needs no
  spec change. If the spec missed the case, add it as an edge case,
  acceptance scenario or `FR-###`.

## Writing the spec

Follow `specs/spec-template.md`; keep its headings and order so Spec Kit
commands (`/speckit.clarify`, `/speckit.plan`, `/speckit.tasks`) can
read it.

- **Input**: the prompt, quoted verbatim. Remove secrets, credentials
  and personal data first, and say `(redacted)` where you did. For a
  long prompt, quote the request and summarise the rest.
- **What and why, never how**: no frameworks, libraries, tables, routes
  or file names. Technical choices go in a decision record or `plan.md`.
- **User stories**: prioritised (`P1` = smallest useful slice), each
  independently testable, with `Given / When / Then` scenarios.
- **Requirements**: `FR-###: System MUST …` / `Users MUST be able to …`,
  one testable capability each. IDs never change once committed; mark a
  dropped one `~~FR-004~~ (removed YYYY-MM-DD: reason)` rather than
  renumbering.
- **Success criteria**: `SC-###`, measurable and technology-agnostic.
- **Gaps**: make an informed guess for low-impact gaps and list it in
  _Assumptions_. Ask the user (`AskUserQuestion`) only for gaps that
  change scope, security, privacy or the user experience, at most three
  at a time, and record each answer in _Clarifications_. Anything still
  open stays as `[NEEDS CLARIFICATION: …]`.
- **Size**: match the prompt. A one-line change gets one story and a
  couple of requirements; remove optional sections that do not apply
  instead of writing "N/A".

## Clarifications log

`## Clarifications` keeps the history of the conversation that shaped
the spec, in Spec Kit's `/speckit.clarify` format, one session per day:

```markdown
## Clarifications

### Session 2026-11-20

- Q: Can a blocked user still sign in? → A: No, their sessions end immediately.
- Prompt: "let admins unblock users too" → Added User Story 3, FR-007, FR-008.
```

- `Q: … → A: …` for a question you asked and the user's answer.
- `Prompt: "…" → <what changed>` for each later prompt that changed
  the spec, naming the stories and IDs it touched.

## Status

- `Draft` — written, not implemented yet.
- `Implemented` — set in the pull request that ships it.
- `Superseded by NNN-<feature-name>` — when another spec replaces it;
  keep the file.

## Red flags

- Behaviour shipped with no spec, or a spec that no longer matches the
  code after a change.
- Two specs describing the same capability.
- A spec naming frameworks, tables, endpoints or components.
- A follow-up prompt that changed the feature but left no
  _Clarifications_ entry.
- Secrets or personal data copied into _Input_.

## Why

Prompts are the requirements of agent-written code, but they vanish
with the session. Stored as specs, they tell the next person or agent
what the feature is supposed to do, catch drift between intent and
code, and give reviewers something to check the diff against. Spec
Kit's format is the one the team already uses for client specs; see
ADR 0045 for the comparison with OpenSpec and Kiro.
