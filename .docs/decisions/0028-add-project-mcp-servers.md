# Commit project MCP servers for Next.js, Playwright and a read-only Neon database

## Context and Problem Statement

Coding agents working in this repository could only read files and run shell commands.
They could not see the dev server's build and runtime errors, drive a browser against the app, or inspect the database schema without writing throwaway scripts.
Each developer configured MCP servers by hand, if at all, so agents behaved differently from one machine to the next.

Which MCP servers should the repository commit in a project-scoped `.mcp.json`, and how should the database server get access without a committed secret?

## Considered Options

- Next.js runtime: `next-devtools-mcp`, pointing clients straight at Next.js 16's `/_next/mcp` endpoint, or no Next.js server.
- Browser: `@playwright/mcp`, Chrome DevTools MCP, or none.
- Database: Neon's hosted MCP server with `?readonly=true`, Postgres MCP Pro (`postgres-mcp --access-mode=restricted`) with a connection string, the archived `@modelcontextprotocol/server-postgres`, or a community npm read-only Postgres server.
- Versions: pinned exact versions, or `@latest`.

## Decision Outcome

Chosen options:

- `next-devtools-mcp@0.4.0`, because it discovers every running dev server on its own, so the config does not hard-code a port, and it adds a docs tool that reads the Next.js docs bundled in `node_modules`.
  Next.js 16.4.5 does serve `/_next/mcp` in dev (verified: nine runtime tools), but a direct entry would need a fixed port, and the dev server picks another port when 3000 is busy.
- `@playwright/mcp@0.0.84` with `--isolated --headless`, because the e2e suite in `apps/web/e2e` already uses Playwright and its accessibility snapshots help with the axe checks.
  Headless keeps it working in cloud and CI-like sessions without a display; `--isolated` stops sessions sharing cookies.
  Chrome DevTools MCP overlaps with it and adds nothing this repo needs.
- Neon's hosted server at `https://mcp.neon.tech/mcp?readonly=true`, because the app's database is Neon (`db.ts` uses the `neon-http` driver), Neon maintains it, and it authenticates with OAuth, so nothing secret is committed and no environment variable is needed.
  `readonly=true` removes branch, migration, role and project tools and leaves `SELECT` and schema inspection.
- Exact versions, because `@latest` would give each agent different tools and could break every session at once on a bad release.
  A hosted HTTP server cannot be pinned; Neon versions it.

Connection-string servers were rejected:

- `@modelcontextprotocol/server-postgres` is archived and deprecated on npm.
- Postgres MCP Pro cannot be installed today: its latest release, 0.3.0, and its main branch pin `pglast` versions (`7.2`, `7.11`) that are no longer on PyPI, so `uvx` fails to resolve it; it also needs Python and `uv`.
- The community npm read-only servers are single-maintainer packages with little usage, which is a supply-chain risk for a tool that receives database credentials.

### Consequences

- Good, because every agent that reads `.mcp.json` gets the same tools, approved once per developer.
- Good, because no credential is committed or required; Neon access follows each developer's own Neon permissions.
- Good, because agents can read source-mapped errors and logs from the running app instead of guessing from terminal output.
- Bad, because the database server is tied to Neon; moving the database adapter to another Postgres host means replacing it.
- Bad, because the Neon server is account-wide unless a developer scopes it to one project in a local override, so it can read any project the developer can.
- Bad, because Cursor and Codex do not read `.mcp.json`; their users copy the entries by hand, as `.docs/how-to/use-mcp-servers.md` explains.
- Bad, because pinned versions need manual bumps.
