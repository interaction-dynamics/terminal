# Decision Records

Apply this rule whenever you make a non-trivial decision while working
in this repository — a technical choice (library, vendor, pattern,
protocol), an architectural change, or any other call worth explaining
to a future reader.

## Rule

Decisions are documented under `.docs`, never left implicit in code or
in a commit message alone.

- **Technical choices** (which library, vendor, framework, pattern, or
  protocol to adopt, replace, or drop) MUST be recorded as a MADR file
  in `.docs/decisions/`.
- **Architecture and design notes** (how subsystems fit together, data
  flows, system shape) live in `.docs/architecture/`.
- **Operational and usage guidance** (how to run, query, or operate a
  feature) lives in `.docs/how-to/`.

When a piece of work involves choosing one option over others, write the
decision down before or alongside the implementation, not after the fact.

## Writing a MADR

1. Copy [`.docs/decisions/0000-madr-template.md`](../../.docs/decisions/0000-madr-template.md)
   as the starting structure.
2. Name the file `NNNN-short-kebab-title.md`, where `NNNN` is the next
   sequential, zero-padded number after the highest existing record in
   `.docs/decisions/`.
   `bun run check-adr-numbers` (also run in CI) fails if two records
   share a number.
3. Fill in every section: **Context and Problem Statement**,
   **Considered Options**, **Decision Outcome** (state the chosen option
   and the justification), and **Consequences** (both the good and the
   bad).
4. Write one sentence per line so diffs stay readable — the folder's
   `.markdownlint.yml` relaxes line-length and duplicate-heading rules
   to support this.

## Red flags

- A new dependency, vendor SDK, or framework added without a matching
  MADR in `.docs/decisions/`.
- A decision captured only in a commit message, PR description, or chat
  instead of `.docs`.
- A MADR that lists a chosen option but omits the alternatives that were
  considered or the consequences of the choice.
- Reusing or skipping a record number instead of taking the next
  sequential one.

## Why

Recording decisions keeps a durable history of _why_ the codebase looks
the way it does, lets the team share that reasoning, and means a future
reader can revisit a choice with the original context intact rather than
reverse-engineering it from the diff.
