#!/usr/bin/env bash
set -euo pipefail

# html-seo-audit.sh
# Scan jabbitapp.com/*.html for basic SEO hygiene:
# - <title>
# - meta name="description"
# - canonical link (must exist; must be https://(www.)?jabbitapp.com/...)
# - at least one <h1>
#
# Usage:
#   bash scripts/html-seo-audit.sh          # human-readable output
#   bash scripts/html-seo-audit.sh --json   # machine-readable output

WS="${WS:-/home/jabbit/.openclaw/workspace}"
SITE_DIR="${SITE_DIR:-$WS/jabbitapp.com}"
BASE="https://jabbitapp.com/"

MODE="text"
if [ "${1:-}" = "--json" ]; then
  MODE="json"
fi

if [ ! -d "$SITE_DIR" ]; then
  echo "ERROR: missing site dir: $SITE_DIR" >&2
  exit 2
fi

mapfile -t FILES < <(find "$SITE_DIR" -maxdepth 1 -type f -name '*.html' -printf '%p\n' | sort)

issues=()  # each entry: file|issue

for f in "${FILES[@]}"; do
  bn="$(basename "$f")"

  # <title>
  if ! grep -Eiq '<title[^>]*>[^<]+' "$f"; then
    issues+=("$bn|missing_title")
  fi

  # meta description
  if ! grep -Eiq '<meta[^>]+name=["\x27]description["\x27][^>]*>' "$f"; then
    issues+=("$bn|missing_meta_description")
  fi

  # canonical
  canon_line="$(grep -Eio '<link[^>]+rel=["\x27]canonical["\x27][^>]*>' "$f" | head -1 || true)"
  if [ -z "$canon_line" ]; then
    issues+=("$bn|missing_canonical")
  else
    href="$(printf '%s' "$canon_line" | sed -nE "s/.*href=['\"]([^'\"]+)['\"].*/\1/p" | head -1)"
    if [ -z "$href" ]; then
      issues+=("$bn|canonical_missing_href")
    elif ! printf '%s' "$href" | grep -Eq '^https://(www\.)?jabbitapp\.com/'; then
      issues+=("$bn|canonical_offsite_or_non_https")
    fi
  fi

  # H1
  if ! grep -Eiq '<h1(\s|>)' "$f"; then
    issues+=("$bn|missing_h1")
  fi

done

issue_count="${#issues[@]}"
file_count="${#FILES[@]}"

if [ "$MODE" = "json" ]; then
  issues_json="$(printf '%s\n' "${issues[@]:-}" | sed '/^$/d' | jq -R 'split("|") | {file:.[0], issue:.[1]}' | jq -s '.')"
  jq -n \
    --arg ws "$WS" \
    --arg site_dir "$SITE_DIR" \
    --arg base "$BASE" \
    --argjson file_count "$file_count" \
    --argjson issue_count "$issue_count" \
    --argjson issues "$issues_json" \
    '{ws:$ws, site_dir:$site_dir, base:$base, file_count:$file_count, issue_count:$issue_count, issues:$issues}'
else
  echo "html_seo_audit: files=$file_count issues=$issue_count"
  if [ "$issue_count" -gt 0 ]; then
    echo "ISSUES:";
    printf '%s\n' "${issues[@]}" | sed 's#^#  - #'
  else
    echo "OK"
  fi
fi

if [ "$issue_count" -gt 0 ]; then
  exit 1
fi
