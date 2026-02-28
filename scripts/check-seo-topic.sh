#!/usr/bin/env bash
# SEO Page Topic Checker
# Usage: bash scripts/check-seo-topic.sh "topic-name"
# Returns:
#   0 if topic exists
#   1 if not found
#
# Why this exists:
# - Prevent duplicate SEO pages for the same topic.
# - Keep working even when naming drifts (e.g., glp1-* vs glp-1-*).

set -euo pipefail

WORKSPACE="/home/jabbit/.openclaw/workspace"
SITE_DIR="$WORKSPACE/jabbitapp.com"
TRACKER="$WORKSPACE/data/seo/page-tracker.json"

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <topic-name>" >&2
  exit 1
fi

TOPIC_RAW="$1"

norm() {
  # Normalize strings so "glp-1" and "glp1" match, and separators don’t matter.
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/\.html$//' \
    | sed -E 's/^glp-1/glp1/' \
    | sed -E 's/[^a-z0-9]+/-/g' \
    | sed -E 's/^-+//; s/-+$//; s/-{2,}/-/g'
}

TOPIC_N="$(norm "$TOPIC_RAW")"

# 1) Tracker lookup (preferred)
if [ -f "$TRACKER" ] && command -v jq >/dev/null 2>&1; then
  while IFS='|' read -r ttopic fname; do
    [ -z "${ttopic:-}" ] && continue
    [ -z "${fname:-}" ] && continue

    if [ "$(norm "$ttopic")" = "$TOPIC_N" ] || [ "$(norm "$fname")" = "$TOPIC_N" ]; then
      echo "EXISTS: $TOPIC_RAW -> $fname (tracker)"
      exit 0
    fi
  done < <(jq -r '.topics[] | "\(.topic)|\(.filename)"' "$TRACKER" 2>/dev/null || true)
fi

# 2) Filesystem fallback (source of truth)
if [ -d "$SITE_DIR" ]; then
  match=""
  while IFS= read -r f; do
    stem="$(basename "$f")"
    if [ "$(norm "$stem")" = "$TOPIC_N" ]; then
      match="$stem"; break
    fi
  done < <(find "$SITE_DIR" -maxdepth 1 -type f -name '*.html' -print | sort)

  if [ -n "$match" ]; then
    echo "EXISTS: $TOPIC_RAW -> $match (filesystem)"
    exit 0
  fi
fi

echo "AVAILABLE: $TOPIC_RAW can be created"
exit 1
