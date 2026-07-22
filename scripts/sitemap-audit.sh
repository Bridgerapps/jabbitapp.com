#!/usr/bin/env bash
set -euo pipefail

# sitemap-audit.sh
# Ensure every sitemap.xml URL resolves to a unique local static HTML page.
# Local utility/legal pages may intentionally be absent from the sitemap.
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

# Extract sitemap URLs exactly as published. Directory URLs map to their local
# index.html files; this is required for the current /guides/, /news/, and
# /peptides/ hubs and for nested peptide pages.
mapfile -t LOC_URLS < <(grep -oE '<loc>[^<]+' "$SITEMAP" | sed 's#<loc>##')
mapfile -t HTML_FILES < <(
  find "$SITE_DIR" -type f -name '*.html' \
    ! -path '*/.git/*' \
    ! -path '*/node_modules/*' \
    ! -path '*/tmp/*' \
    ! -path '*/_includes/*' \
    -printf '%P\n' | sort -u
)

missing=()
extra=()
declare -A seen_paths=()
for url in "${LOC_URLS[@]}"; do
  if [[ "$url" != "$BASE"* ]]; then
    extra+=("$url (outside expected base)")
    continue
  fi

  rel="${url#"$BASE"}"
  rel="${rel%%\#*}"
  rel="${rel%%\?*}"
  if [ -z "$rel" ] || [[ "$rel" == */ ]]; then
    rel="${rel}index.html"
  fi

  if [[ "$rel" == /* ]] || [[ "$rel" == *'..'* ]]; then
    extra+=("$url (invalid path)")
    continue
  fi
  if [[ -n "${seen_paths[$rel]:-}" ]]; then
    extra+=("$url (duplicate target: $rel)")
    continue
  fi
  seen_paths[$rel]=1

  if [ ! -f "$SITE_DIR/$rel" ]; then
    missing+=("$rel")
  fi
done

robots_points="unknown"
if [ -f "$ROBOTS" ] && grep -qE '^Sitemap: https://jabbitapp.com/sitemap.xml' "$ROBOTS"; then
  robots_points="ok"
fi

ok=true
if [ ${#missing[@]} -gt 0 ] || [ ${#extra[@]} -gt 0 ] || [ "$robots_points" != "ok" ]; then
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
    --argjson sitemap_urls "${#LOC_URLS[@]}" \
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
  "$robots_points" "${#LOC_URLS[@]}" "${#HTML_FILES[@]}"

if [ ${#missing[@]} -gt 0 ]; then
  echo "SITEMAP_TARGET_MISSING_LOCAL:"; printf '  - %s\n' "${missing[@]}"; exit 1
fi

if [ ${#extra[@]} -gt 0 ]; then
  echo "INVALID_OR_DUPLICATE_SITEMAP_URL:"; printf '  - %s\n' "${extra[@]}"; exit 1
fi

if [ "$robots_points" != "ok" ]; then
  echo "ROBOTS_SITEMAP_POINTER_MISSING: $ROBOTS"
  exit 1
fi

echo "OK: every sitemap URL resolves to a unique local page"
