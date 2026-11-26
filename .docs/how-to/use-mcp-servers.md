# Use the project MCP servers

The repository commits a project-scoped [`.mcp.json`](../../.mcp.json) so coding agents get tools that understand this repo.
Why these servers were chosen is recorded in [ADR 0028](../decisions/0028-add-project-mcp-servers.md).

## Servers

| Server          | Package / endpoint                         | Use it to                                                          | Needs                               |
| --------------- | ------------------------------------------ | ------------------------------------------------------------------ | ----------------------------------- |
| `next-devtools` | `next-devtools-mcp@0.4.0` (stdio)          | Read build and runtime errors, logs, routes and Server Actions     | A running `bun run web` dev server  |
| `playwright`    | `@playwright/mcp@0.0.84` (stdio, headless) | Drive a real browser against the app, read accessibility snapshots | Google Chrome installed             |
| `neon-readonly` | `https://mcp.neon.tech/mcp?readonly=true`  | Inspect the Neon database schema and run `SELECT` queries          | A Neon account (OAuth on first use) |

No environment variable or secret is needed for the committed configuration.

### `next-devtools`

Next.js 16 serves its own MCP endpoint at `http://localhost:<port>/_next/mcp` while `next dev` runs.
`next-devtools-mcp` finds every running dev server and forwards calls to it, so the agent does not need to know the port.

- `nextjs_index` lists running dev servers and their runtime tools (on Next.js 16.4: `get_errors`, `get_logs`, `get_routes`, `get_compilation_issues`, `compile_route`, `get_page_metadata`, `get_request_insights`, `get_project_metadata`, `get_server_action_by_id`).
- `nextjs_call` calls one of those runtime tools.
- `nextjs_docs` points the agent at the docs bundled in `node_modules/next/dist/docs/`, which match the installed Next.js version.

Start the app first with `bun run web`; without a dev server only the docs tool is useful.

### `playwright`

Use it to reproduce a UI bug, check a page renders, or explore a flow before writing a test in `apps/web/e2e`.
`browser_snapshot` returns the page's accessibility tree, which is a quick way to spot missing labels and roles.

It does not run axe.
The axe checks live in `apps/web/e2e/accessibility.test.ts`; run them with `cd apps/web && bun run test:e2e`.

The server runs headless and `--isolated` (a fresh in-memory profile per session), so it works without a display and never reuses cookies.
It writes snapshots and console logs to `.playwright-mcp/`, which is gitignored.
It uses the Google Chrome channel by default; if Chrome is missing, install it with `cd apps/web && bunx playwright install chrome`.

### `neon-readonly`

The app's database is Neon (`infrastructure/adapters/src/database/drizzle/db.ts` uses the `neon-http` driver), so the database server is Neon's hosted MCP server.
`?readonly=true` limits it to read tools: `run_sql` for `SELECT`, `describe_table_schema`, `get_database_tables`, `explain_sql_statement` and the like.
Branch, migration, role and project changes are not exposed.

On first use, authenticate from your client (`/mcp` in Claude Code) and pick the read-only scope on Neon's consent page.
Schema changes still go through Drizzle: edit the entity and schema, then `cd infrastructure/adapters && bun run db:generate` (see `.agents/rules/domain-entities.md`).

Do not point it at a production project.
Use a development branch, or scope the server to one project as shown below.

## Approve the servers

Claude Code asks before it starts servers from a committed `.mcp.json`.
Run `claude` in the repository and accept the prompt, or approve them in `/mcp`.
`claude mcp list` shows `⏸ Pending approval` until then.

To check they start:

```bash
claude mcp list
```

`next-devtools` and `playwright` should report `✔ Connected`; `neon-readonly` reports `! Needs authentication` until you sign in.

## Override locally

Keep personal changes out of `.mcp.json`; add a local-scope server with the same name, which wins over the project one.

Scope Neon to a single project and authenticate with an API key instead of OAuth:

```bash
claude mcp add --scope local --transport http neon-readonly \
  "https://mcp.neon.tech/mcp?readonly=true&projectId=<your-project-id>" \
  --header "Authorization: Bearer $NEON_API_KEY"
```

Watch the browser instead of running headless:

```bash
claude mcp add --scope local playwright -- npx -y @playwright/mcp@0.0.84 --isolated
```

## Other agents

Cursor reads `.cursor/mcp.json` and Codex reads its own `config.toml`; neither reads `.mcp.json`.
Copy the three entries into your client's config, or register them with the client's CLI, for example for Codex:

```bash
codex mcp add next-devtools -- npx -y next-devtools-mcp@0.4.0
codex mcp add playwright -- npx -y @playwright/mcp@0.0.84 --isolated --headless
codex mcp add neon-readonly --url "https://mcp.neon.tech/mcp?readonly=true"
```

## Upgrade a server

Versions are pinned so every agent gets the same tools.
To upgrade, check the latest version with `npm view <package> version`, bump it in `.mcp.json` and in this page, and confirm `claude mcp list` still reports the server as connected.
