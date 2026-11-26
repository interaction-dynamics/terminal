# Feature specs

One folder per feature, in [GitHub Spec Kit](https://github.com/github/spec-kit) format: `NNN-<feature-name>/spec.md`, copied from [`spec-template.md`](spec-template.md).

Specs record what each feature must do and why, from the prompts and client documents that asked for it.
They are written or updated before the code, in the same pull request.

- Rule: [`.agents/rules/feature-specs.md`](../.agents/rules/feature-specs.md)
- Why this format: [ADR 0045](../.docs/decisions/0045-store-prompt-specs-in-spec-kit-format.md)
- `bun run check-spec-numbers` fails when two folders share a number.
