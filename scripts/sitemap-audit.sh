#!/usr/bin/env bash
set -euo pipefail

# sitemap-audit.sh
# Ensure the sitemap.xml URLs match the local set of static HTML pages.
# Also checks that robots.txt points at the sitemap.
#
# Usage:
#   bash scripts/sitemap-audit.sh
#   bash scripts/sitemap-audit.sh --json

WS="${WS:-/home/jabbit/.openclaw/workspace}"
SITE_DIR="${SITE_DIR:-$WS/jabbitapp.com}"
SITEMAP="${SITEMAP:-$SITE_DIR/sitemap.xml}"
ROBOTS="${ROBOTS:-$SITE_DIR/robots.txt}"
BASE="${BASE:-https://jabbitapp.com/}"

MODE="text"
if [ "${1:-}" = "--json" ]; then
  MODE="json"
fi

if [ ! -f "$SITEMAP" ]; then
  echo "ERROR: missing sitemap: $SITEMAP" >&2
  exit 2
fi

# Extract filenames from sitemap
mapfile -t LOC_FILES < <(grep -oE '<loc>[^<]+' "$SITEMAP" \
  | sed 's#<loc>##' \
  | sed "s#^${BASE}##" \
  | sort -u)

# Local html files
mapfile -t HTML_FILES < <(find "$SITE_DIR" -maxdepth 1 -type f -name '*.html' -printf '%f\n' | sort -u)

# Compute missing/extra
loc_blob="$(printf '%s\n' "${LOC_FILES[@]}")"
html_blob="$(printf '%s\n' "${HTML_FILES[@]}")"

missing=()
for f in "${HTML_FILES[@]}"; do
  if ! grep -Fxq -- "$f" <<< "$loc_blob"; then
    missing+=("$f")
  fi
done

extra=()
for f in "${LOC_FILES[@]}"; do
  [ -z "$f" ] && continue
  if ! grep -Fxq -- "$f" <<< "$html_blob"; then
    extra+=("$f")
  fi
done

robots_points="unknown"
if [ -f "$ROBOTS" ] && grep -qE '^Sitemap: https://jabbitapp.com/sitemap.xml' "$ROBOTS"; then
  robots_points="ok"
fi

ok=true
if [ ${#missing[@]} -gt 0 ] || [ ${#extra[@]} -gt 0 ]; then
  ok=false
fi

if [ "$MODE" = "json" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required for --json output" >&2
    exit 2
  fi

  missing_json="$({ if [ ${#missing[@]} -gt 0 ]; then printf '%s\n' "${missing[@]}" | jq -R . | jq -s .; else echo '[]'; fi; })"
  extra_json="$({ if [ ${#extra[@]} -gt 0 ]; then printf '%s\n' "${extra[@]}" | jq -R . | jq -s .; else echo '[]'; fi; })"

  jq -n \
    --arg ws "$WS" \
    --arg site_dir "$SITE_DIR" \
    --arg sitemap "$SITEMAP" \
    --arg robots "$ROBOTS" \
    --arg base "$BASE" \
    --arg robots_points "$robots_points" \
    --argjson sitemap_urls "${#LOC_FILES[@]}" \
    --argjson local_html "${#HTML_FILES[@]}" \
    --argjson missing_count "${#missing[@]}" \
    --argjson extra_count "${#extra[@]}" \
    --argjson missing "$missing_json" \
    --argjson extra "$extra_json" \
    --argjson ok "$ok" \
    '{ws:$ws, site_dir:$site_dir, base:$base, sitemap:$sitemap, robots:$robots, robots_points:$robots_points, sitemap_urls:$sitemap_urls, local_html:$local_html, missing_count:$missing_count, extra_count:$extra_count, missing:$missing, extra:$extra, ok:$ok}'

  if [ "$ok" != "true" ]; then
    exit 1
  fi
  exit 0
fi

printf 'sitemap_audit: robots=%s sitemap_urls=%s local_html=%s\n' \
  "$robots_points" "${#LOC_FILES[@]}" "${#HTML_FILES[@]}"

if [ ${#missing[@]} -gt 0 ]; then
  echo "MISSING_IN_SITEMAP:"; printf '  - %s\n' "${missing[@]}"; exit 1
fi

if [ ${#extra[@]} -gt 0 ]; then
  echo "EXTRA_IN_SITEMAP:"; printf '  - %s\n' "${extra[@]}"; exit 1
fi

echo "OK: sitemap matches local html set"
