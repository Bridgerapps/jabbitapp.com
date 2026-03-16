#!/usr/bin/env bash
set -euo pipefail

# record-finish.sh
# Append a "finish" record for the most recent run, with a required note.
# This complements the start-run record (which often has an empty note in cron).
#
# Usage:
#   scripts/manual-growth-loop/record-finish.sh --note "did X" [--tags "M,D,R"]

ROOT="/home/jabbit/.openclaw/workspace"
LATEST="$ROOT/data/status/manual-growth-loop-latest.json"

note=""
tags=""

while [ $# -gt 0 ]; do
  case "$1" in
    --note) note="$2"; shift 2;;
    --tags) tags="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

if [ -z "$note" ]; then
  echo "--note is required" >&2
  exit 2
fi

if [ ! -f "$LATEST" ]; then
  echo "missing latest pointer: $LATEST" >&2
  exit 2
fi

iteration=$(jq -r '.iteration' "$LATEST")
mode=$(jq -r '.mode' "$LATEST")

# Prefix note so audit tooling can prefer finish records.
finish_note="FINISH: ${note}"

bash "$ROOT/scripts/manual-growth-loop/record-run.sh" \
  --iteration "$iteration" \
  --mode "$mode" \
  ${tags:+--tags "$tags"} \
  --note "$finish_note"
