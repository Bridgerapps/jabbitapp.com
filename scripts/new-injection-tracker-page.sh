#!/usr/bin/env bash
# new-injection-tracker-page.sh
#
# Create a brand-intent "<Brand> injection tracker" landing page using the existing
# Zepbound landing page as a template.
#
# Why:
# - We keep creating near-identical injection-tracker pages (Zepbound, Mounjaro, Wegovy, etc.)
# - Copy/paste edits are error-prone (canonical, filename, source links)
#
# Usage:
#   bash scripts/new-injection-tracker-page.sh --brand "Mounjaro" --slug "mounjaro-injection-tracker" \
#     --source-url "https://pi.lilly.com/us/mounjaro-uspi.pdf?s=pi" \
#     --source-text "Eli Lilly: Mounjaro U.S. Prescribing Information (PDF)" \
#     --sync
#
# Notes:
# - This script does NOT post anywhere (no Reddit/Twitter).
# - --sync runs site-sync (which runs audits + health-check). Use when you want it in sitemap.
# - --pack generates a human-reviewable distribution pack under /output (NO posting).

set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"
SITE_DIR="$WS/jabbitapp.com"
TEMPLATE="$SITE_DIR/zepbound-injection-tracker.html"

BRAND=""
SLUG=""
SOURCE_URL=""
SOURCE_TEXT=""
DO_SYNC="false"
DO_PACK="false"

err() { echo "ERROR: $*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --brand) BRAND="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --source-url) SOURCE_URL="$2"; shift 2 ;;
    --source-text) SOURCE_TEXT="$2"; shift 2 ;;
    --sync) DO_SYNC="true"; shift 1 ;;
    --pack) DO_PACK="true"; shift 1 ;;
    -h|--help)
      sed -n '1,80p' "$0"
      exit 0
      ;;
    *) err "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -z "$BRAND" || -z "$SLUG" ]]; then
  err "Missing --brand or --slug"
  exit 2
fi

if [[ ! -f "$TEMPLATE" ]]; then
  err "Missing template: $TEMPLATE"
  exit 2
fi

OUT_FILE="$SLUG"
if [[ "$OUT_FILE" != *.html ]]; then OUT_FILE="$OUT_FILE.html"; fi
OUT_PATH="$SITE_DIR/$OUT_FILE"

if [[ -f "$OUT_PATH" ]]; then
  err "Refusing to overwrite existing file: $OUT_PATH"
  exit 2
fi

cp "$TEMPLATE" "$OUT_PATH"

# 1) Swap display brand
perl -pi -e "s/Zepbound/${BRAND}/g" "$OUT_PATH"

# 2) Fix canonical + any self-references to the template filename
perl -pi -e 's/zepbound-injection-tracker\.html/'"$OUT_FILE"'/g' "$OUT_PATH"

# 3) Update the Sources link (optional)
if [[ -n "$SOURCE_URL" || -n "$SOURCE_TEXT" ]]; then
  if [[ -z "$SOURCE_URL" || -z "$SOURCE_TEXT" ]]; then
    err "If you set --source-url or --source-text, you must set both"
    exit 2
  fi

  # Replace the entire first <li> under Sources.
  perl -0777 -pi -e 's#(<p><strong>Sources:</strong></p>\s*<ul>\s*)<li><a href="[^"]+"[^>]*>[^<]+</a></li>#${1}<li><a href="'"$SOURCE_URL"'" target="_blank" rel="noopener noreferrer">'"$SOURCE_TEXT"'</a></li>#s' "$OUT_PATH"
fi

echo "new_injection_tracker_page:ok:$OUT_PATH"

if [[ "$DO_SYNC" = "true" ]]; then
  python3 "$WS/scripts/related-links-suggest.py" --write >/dev/null || true
  bash "$WS/scripts/site-sync.sh" all >/dev/null
  echo "site_sync:ok"
fi

if [[ "$DO_PACK" = "true" ]]; then
  python3 "$WS/scripts/distribution-pack.py" --path "$OUT_PATH"
fi
