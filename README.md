# Ship it

A boilerplate with [Next.js](https://nextjs.org/), [Tailwind CSS](https://tailwindcss.com/), and [TypeScript](https://www.typescriptlang.org/) following the best practices and using the latest technologies.

## Use as a Base for Your Project

```bash
git clone <your-repository-url>
git remote add boilerplate git@github.com:interaction-dynamics/ship-it.git
git pull boilerplate master --rebase
```

> You can also follow the steps in the [GETTING_STARTED.md](./GETTING_STARTED.md) for more customization.
>
> To rename the project, ask your coding agent to run the `rebrand-project` skill: it replaces every "Ship it" variant with your product's name and lists the images to replace by hand.

## Getting Started

If you use [mise](https://mise.jdx.dev/), install the Bun and Node versions pinned in `mise.toml`:

```bash
mise trust
mise install
```

Then, run the development server:

```bash
bun install

bun dev
```

## Libraries

This is a [Next.js](https://nextjs.org/) project bootstrapped with [`create-next-app`](https://github.com/vercel/next.js/tree/canary/packages/create-next-app).

- React
- [Next.js](https://nextjs.org/)
- Tailwind
- Typescript
- Vitest
- React Testing Library
- Oxlint
- Oxfmt
- Playwright (including accessibility tests)
- Commitlint
- Github Actions
- Dark mode
- Custom Translation system
- Lefthook
- [shadcn/ui](https://ui.shadcn.com/)
- Stripe
- Google Analytics
- Hotjar
- Markdown support
- [Mailgun](https://www.mailgun.com/) OR [Resend](https://resend.com) with [React.Email](https://react.email)
- [Better Auth](https://www.better-auth.com)
- Custom Error pages
- Localized date and time formatting
- Dark mode toggle
- Language selector
- PostHog OR Vercel flags OR Statsig

## AI Agent Support

This project ships with pre-configured rules and skills for AI coding assistants (Claude Code, Cursor, etc.).

- **`.agents/rules/`** — coding conventions the agent must follow (commits, architecture, Next.js, UI, etc.)
- **`.agents/skills/`** — step-by-step procedures the agent can invoke (`drizzle-schema-change`, `hexagonal-adapters`, `conventional-commit-pr`, `rebrand-project`, `client-changelog`, `design-taste-frontend`)
- **`.agents/hooks/`** — pre-push checks (format, lint, commitlint, and build, type check and unit tests for affected packages) run in parallel before every `git push`
- **`.claude/`** — Claude Code session configuration (permissions, hooks, launch targets)

No extra setup required — the rules and skills are picked up automatically when you open the project in a supported editor.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
