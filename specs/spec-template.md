# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`

**Created**: [DATE]

**Status**: Draft <!-- Draft | Implemented | Superseded by NNN-feature-name -->

**Input**: User description: "[the prompt, verbatim — secrets and personal data removed]"

<!--
  GitHub Spec Kit spec-template, plus a Clarifications log and Status values.
  Rule: .agents/rules/feature-specs.md. Keep headings and order so
  /speckit.clarify, /speckit.plan and /speckit.tasks can read this file.
  Describe WHAT users need and WHY, never HOW (no frameworks, tables, routes).
  Remove optional sections that do not apply, and these comments.
-->

## Clarifications

### Session [YYYY-MM-DD]

- Q: [question asked] → A: [user's answer]
- Prompt: "[later prompt]" → [what changed: stories and IDs touched]

## User Scenarios & Testing _(mandatory)_

<!--
  Prioritized user journeys. Each one is INDEPENDENTLY TESTABLE: shipping
  only P1 still gives users something that works.
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [The value, and why it has this priority]

**Independent Test**: [e.g. "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [The value, and why it has this priority]

**Independent Test**: [How this can be tested on its own]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### Edge Cases

- What happens when [boundary condition]?
- How does the system handle [error scenario]?

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: System MUST [specific capability]
- **FR-002**: Users MUST be able to [key interaction]
- **FR-003**: System MUST [NEEDS CLARIFICATION: question that changes scope, security or privacy]

### Key Entities _(include if the feature involves data)_

- **[Entity 1]**: [What it represents, key attributes without implementation]

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: [Measurable, technology-agnostic outcome, e.g. "Admins can block a user in under 30 seconds"]

## Assumptions

- [Reasonable default chosen where the prompt is silent]
- [Dependency on another feature, e.g. "Users are signed in (001-sign-in)"]
