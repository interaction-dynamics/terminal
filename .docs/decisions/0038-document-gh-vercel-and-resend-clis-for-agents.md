# Document the gh, Vercel and Resend CLIs for Agent-Driven Operations

## Context and Problem Statement

The boilerplate targets Vercel for hosting, Resend for email (ADR 0008) and GitHub for pull requests and CI (`.agents/rules/pr-watching.md`).
Setting up a deployment of a project generated from it means creating a Vercel project, adding environment variables per environment, attaching a domain, verifying a Resend sending domain and issuing an API key.
Nothing in the repository said which tools to use for that, so agents fell back to the dashboards, which they cannot drive, or guessed CLI flags from training data.
Real setups hit non-obvious failures: `vercel env add` for Preview fails with `git_branch_required` in non-interactive mode, `vercel link --project` is a no-op once `.vercel/repo.json` exists, setting `BETTER_AUTH_URL` on Preview breaks auth on every preview URL, and the first Drizzle migration needs the `"default"` schema to exist.
Which tools should agent-facing docs point to for these operations, and where should the knowledge live?

## Considered Options

- Document nothing and let each agent use dashboards or whatever it knows
- Document the official CLIs: GitHub CLI (`gh`), Vercel CLI (`vercel`) and Resend CLI (`resend-cli` on npm)
- Rely on vendor MCP servers (GitHub, Vercel) committed in `.mcp.json`
- Script the whole setup in a repository command
- Pin the CLIs in `mise.toml`

## Decision Outcome

Chosen option: "Document the official CLIs", because all three run non-interactively, authenticate once per machine without a committed secret, and expose every operation the setup needs, including raw REST calls (`vercel api`) when a subcommand falls short.
The knowledge lives in `.docs/how-to/deploy-to-vercel.md`, with a short pointer table in `AGENTS.md` so agents find it without loading the page on every task.

Vendor MCP servers were not chosen as the documented path: Resend has no official one, the GitHub and Vercel ones need per-developer OAuth or tokens, and ADR 0028 keeps `.mcp.json` to servers that help with code in this repository.
Agents that have them can still use them; the how-to describes what to do, not which transport to use.
A setup script was rejected because the steps depend on accounts, domains and DNS providers that differ per project, and a script would hide the gotchas instead of explaining them.
The CLIs are not pinned in `mise.toml`, because only whoever sets up or operates a deployment needs them, and Vercel and Resend accounts must be signed in to anyway.

### Consequences

- Good, because an agent can set up a full deployment from the terminal, and the known failure modes are written down next to the commands.
- Good, because the Better Auth URL rule per Vercel environment is now explicit rather than discovered through broken previews.
- Good, because no credential is committed; each CLI keeps its own login.
- Bad, because the commands are tied to CLI versions (checked with Vercel CLI 50.x, Resend CLI 2.x, GitHub CLI 2.x) and need updating when flags change.
- Bad, because contributors install the CLIs themselves, at whatever version is current.
