#!/usr/bin/env bash
# List the feat and fix commits merged on the default branch since a date.
#
# Usage: collect-commits.sh <since YYYY-MM-DD> [until YYYY-MM-DD] [ref]
#
# Prints one tab-separated line per kept commit, oldest first:
#   <date>\t<hash>\t<subject>
# and a count of the skipped commits per type on stderr.
set -euo pipefail

since="${1:?usage: collect-commits.sh <since YYYY-MM-DD> [until YYYY-MM-DD] [ref]}"
until_date="${2:-}"
ref="${3:-}"

# Read the latest history of the default branch, not the local checkout.
git fetch --quiet origin 2>/dev/null || echo "warning: git fetch failed, using local refs" >&2

if [ -z "$ref" ]; then
  ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  for candidate in origin/master origin/main HEAD; do
    [ -n "$ref" ] && break
    git rev-parse --verify --quiet "$candidate" >/dev/null && ref="$candidate"
  done
fi

# A bare date in --since means "that date at the current time of day" for git:
# pin it to midnight so the whole day is included.
args=(--no-merges --reverse --date=short --format='%cd%x09%h%x09%s' "--since=$since 00:00")
[ -n "$until_date" ] && args+=("--until=$until_date 23:59:59")

echo "Commits on $ref since $since${until_date:+ until $until_date}" >&2

git log "${args[@]}" "$ref" | awk -F '\t' '
  {
    subject = $3
    lower = tolower(subject)
    if (lower ~ /^(feat|fix)(\([^)]*\))?!?: /) { print; kept++; next }
    type = lower
    sub(/[(!:].*/, "", type)
    if (type == "" || type ~ /[^a-z]/) type = "other"
    skipped[type]++
  }
  END {
    printf "kept %d feat/fix commits", kept + 0 > "/dev/stderr"
    sep = "; skipped "
    for (t in skipped) { printf "%s%s=%d", sep, t, skipped[t] > "/dev/stderr"; sep = ", " }
    printf "\n" > "/dev/stderr"
  }
'
