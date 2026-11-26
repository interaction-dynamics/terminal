#!/usr/bin/env bash
# SessionStart hook: install workspace dependencies so lint, format, tests,
# and the pre-push hook all work the moment a Claude Code session starts.
#
# Runs only in Claude Code on the web. Local sessions are expected to have
# already run `bun install` (postinstall wires lefthook).

set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

if ! command -v bun >/dev/null 2>&1; then
  echo "session-start: bun not on PATH, skipping install" >&2
  exit 0
fi

echo "session-start: installing workspace dependencies with bun..." >&2
bun install --frozen-lockfile

echo "session-start: ready." >&2
