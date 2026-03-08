#!/usr/bin/env bash
set -euo pipefail

# Creates/updates a stable pointer to the most recent send-now brief.
# Why: prevents us from generating N nearly-identical briefs and losing the "one true" place to act.

ROOT="/home/jabbit/.openclaw/workspace"
DIR="$ROOT/docs/distribution"
LINK="$DIR/send-now-brief-latest.md"

if [ ! -d "$DIR" ]; then
  echo "missing dir: $DIR" >&2
  exit 1
fi

# Prefer today's brief; fallback to most recent overall.
TODAY_UTC="$(date -u +%F)"
LATEST_TODAY="$(ls -1t "$DIR"/send-now-brief-${TODAY_UTC}-*.md 2>/dev/null | head -n 1 || true)"
LATEST_ANY="$(ls -1t "$DIR"/send-now-brief-*.md 2>/dev/null | head -n 1 || true)"

TARGET="${LATEST_TODAY:-$LATEST_ANY}"

if [ -z "$TARGET" ]; then
  echo "no send-now brief found (expected $DIR/send-now-brief-*.md)" >&2
  exit 2
fi

ln -sf "$(basename "$TARGET")" "$LINK"
echo "$LINK -> $(readlink "$LINK")"
