#!/usr/bin/env bun
// Claude Code PreToolUse hook: runs the repository checks before `git push`
// and denies the push with the failing output when any check fails.
// See .docs/decisions/0033-run-affected-checks-in-parallel-before-push.md.
import { spawn, spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { resolve } from 'node:path';

type ToolUseInput = {
  cwd?: string;
  tool_name?: string;
  tool_input?: { command?: string };
};

type Check = { name: string; argv: string[]; env?: Record<string, string> };

type CheckResult = { name: string; ok: boolean; output: string; seconds: number };

// Root scripts added by other tooling; run them when present, skip otherwise.
const OPTIONAL_ROOT_SCRIPTS = [
  'check-adr-numbers',
  'check-auth-schema',
  'check-features',
  'lint:boundaries',
  'knip',
];
// Base branches tried, in order, when origin/HEAD is not set.
const BASE_CANDIDATES = ['origin/master', 'origin/main', 'master', 'main'];
// Failure output budget: errors usually sit at the end, so keep more tail.
const HEAD_LINES = 20;
const TAIL_LINES = 120;
const MAX_CHARS_PER_CHECK = 8_000;

const input = (await Bun.stdin.json()) as ToolUseInput;
const command = input?.tool_input?.command ?? '';

// A shell word: a double- or single-quoted string, or a run of non-spaces.
const WORD = String.raw`("[^"]*"|'[^']*'|\S+)`;
const PUSH = new RegExp(String.raw`(^|[\s;&|\x60(])git\s+(?:-C\s+${WORD}\s+)?push(\s|$)`);

const pushMatch = PUSH.exec(command);
if (!pushMatch) {
  process.exit(0);
}

const skipFromEnv = process.env.SKIP_PREPUSH_CHECK === '1';
const skipFromCommand = /(^|\s)SKIP_PREPUSH_CHECK=1(\s|$)/.test(command);
if (skipFromEnv || skipFromCommand) {
  process.stderr.write('Skipping pre-push checks (SKIP_PREPUSH_CHECK=1)\n');
  process.exit(0);
}

function unquote(word: string): string {
  const bare = /^(["']).*\1$/.test(word) ? word.slice(1, -1) : word;
  return bare.replace(/^~(?=\/|$)/, homedir()).replace(/^\$HOME(?=\/|$)/, homedir());
}

// The directory the push runs in: the session's cwd at the time of the tool
// call, moved by a `cd <dir>` before the push or by `git -C <dir> push`.
// Claude Code starts this hook from the project directory, which in a git
// worktree session is the main checkout, so neither `process.cwd()` nor this
// file's location says which checkout is being pushed.
function pushDirectory(): string {
  let dir = input?.cwd || process.cwd();
  const beforePush = command.slice(0, pushMatch!.index + pushMatch![1].length);
  const cdPattern = new RegExp(String.raw`(?:^|[;&|(]\s*)cd\s+${WORD}`, 'g');
  for (const [, target] of beforePush.matchAll(cdPattern)) {
    dir = resolve(dir, unquote(target));
  }
  if (pushMatch![2]) dir = resolve(dir, unquote(pushMatch![2]));
  return dir;
}

function resolveRepoRoot(): string {
  const result = spawnSync('git', ['rev-parse', '--show-toplevel'], {
    cwd: pushDirectory(),
    encoding: 'utf8',
  });
  const toplevel = result.status === 0 ? result.stdout.trim() : '';
  return toplevel || resolve(import.meta.dir, '../..');
}

const repoRoot = resolveRepoRoot();
process.stderr.write(`Pre-push checks run in ${repoRoot}\n`);

function git(...args: string[]): string | undefined {
  const result = spawnSync('git', args, { cwd: repoRoot, encoding: 'utf8' });
  return result.status === 0 ? result.stdout.trim() : undefined;
}

// Resolve the commit `--affected` compares against. Using the merge-base SHA
// with the remote default branch keeps a stale local `master` (common in
// worktrees) from widening or narrowing the diff. Returns undefined when no
// base can be found (e.g. shallow clone), in which case every package runs.
function resolveAffectedBase(): string | undefined {
  if (process.env.TURBO_SCM_BASE) return process.env.TURBO_SCM_BASE;
  const originHead = git('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD');
  const candidates = originHead ? [originHead, ...BASE_CANDIDATES] : BASE_CANDIDATES;
  for (const ref of candidates) {
    if (!git('rev-parse', '--verify', '--quiet', `${ref}^{commit}`)) continue;
    const mergeBase = git('merge-base', 'HEAD', ref);
    if (mergeBase) return mergeBase;
  }
  return undefined;
}

function rootScripts(): Record<string, string> {
  try {
    const pkg = JSON.parse(readFileSync(resolve(repoRoot, 'package.json'), 'utf8')) as {
      scripts?: Record<string, string>;
    };
    return pkg.scripts ?? {};
  } catch {
    return {};
  }
}

const affectedBase = resolveAffectedBase();
const scripts = rootScripts();

const turboArgv = [
  'bunx',
  'turbo',
  'run',
  'build',
  'check-types',
  'test:ci',
  '--output-logs=errors-only',
  '--continue=dependencies-successful',
  '--ui=stream',
];
if (affectedBase) turboArgv.push('--affected');

const checks: Check[] = [
  { name: 'format', argv: ['bun', 'run', 'format'] },
  { name: 'lint', argv: ['bun', 'run', 'lint'] },
  ...OPTIONAL_ROOT_SCRIPTS.filter((name) => name in scripts).map((name) => ({
    name,
    argv: ['bun', 'run', name],
  })),
  { name: 'commitlint', argv: ['bun', 'run', 'commitlint'] },
  {
    name: affectedBase ? 'build/check-types/test:ci (affected)' : 'build/check-types/test:ci',
    argv: turboArgv,
    env: {
      NEXT_TELEMETRY_DISABLED: '1',
      ...(affectedBase ? { TURBO_SCM_BASE: affectedBase } : {}),
    },
  },
];

function run({ name, argv, env }: Check): Promise<CheckResult> {
  const started = performance.now();
  return new Promise((done) => {
    const chunks: Buffer[] = [];
    const child = spawn(argv[0], argv.slice(1), {
      cwd: repoRoot,
      env: { ...process.env, FORCE_COLOR: '0', ...env },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    child.stdout.on('data', (chunk: Buffer) => chunks.push(chunk));
    child.stderr.on('data', (chunk: Buffer) => chunks.push(chunk));
    const finish = (ok: boolean, extra = '') =>
      done({
        name,
        ok,
        output: Buffer.concat(chunks).toString('utf8') + extra,
        seconds: (performance.now() - started) / 1000,
      });
    child.on('error', (error) => finish(false, `\n${error.message}`));
    child.on('close', (code) => finish(code === 0));
  });
}

// Strip ANSI escapes and keep the head and tail of long output so the deny
// reason stays readable for the agent without losing the actual errors.
function truncate(raw: string): string {
  // oxlint-disable-next-line no-control-regex
  const text = raw.replace(/\u001b\[[0-9;?]*[A-Za-z]/g, '').trim();
  if (!text) return '(no output)';
  let lines = text.split('\n');
  if (lines.length > HEAD_LINES + TAIL_LINES) {
    const omitted = lines.length - HEAD_LINES - TAIL_LINES;
    lines = [
      ...lines.slice(0, HEAD_LINES),
      `… ${omitted} lines omitted …`,
      ...lines.slice(-TAIL_LINES),
    ];
  }
  const joined = lines.join('\n');
  return joined.length > MAX_CHARS_PER_CHECK
    ? `… output truncated …\n${joined.slice(-MAX_CHARS_PER_CHECK)}`
    : joined;
}

const started = performance.now();
const results = await Promise.all(checks.map(run));
const total = ((performance.now() - started) / 1000).toFixed(1);
const timings = results
  .map(({ name, ok, seconds }) => `${ok ? 'ok  ' : 'FAIL'} ${name} (${seconds.toFixed(1)}s)`)
  .join('\n');
process.stderr.write(`Pre-push checks finished in ${total}s\n${timings}\n`);

const failures = results.filter((result) => !result.ok);
if (failures.length === 0) {
  process.exit(0);
}

const reason = [
  'Pre-push checks failed. Fix the issues below before pushing.',
  'Override only when truly necessary by re-running with SKIP_PREPUSH_CHECK=1.',
  '',
  `Checks (${total}s, run in parallel):`,
  timings,
  '',
  ...failures.map(({ name, output }) => `--- ${name} failed ---\n${truncate(output)}`),
].join('\n');

process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: reason,
    },
  }),
);
process.exit(0);
