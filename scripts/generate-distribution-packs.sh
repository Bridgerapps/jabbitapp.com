#!/usr/bin/env bash
set -euo pipefail

# Generate distribution packs (Markdown snippets for human review) for one or more
# jabbitapp.com HTML pages.
#
# Why: we keep shipping pages and repeatedly asking “what should we post where?”
# This is a one-command helper that *does not post anything*.
#
# Usage:
#   bash scripts/generate-distribution-packs.sh                 # injection tracker set
#   bash scripts/generate-distribution-packs.sh wegovy-injection-tracker.html
#   bash scripts/generate-distribution-packs.sh foo.html bar.html

WS="${WS:-/home/jabbit/.openclaw/workspace}"
SITE_DIR="${SITE_DIR:-$WS/jabbitapp.com}"

if [ ! -f "$WS/scripts/distribution-pack.py" ]; then
  echo "ERROR: missing $WS/scripts/distribution-pack.py" >&2
  exit 2
fi

if [ ! -d "$SITE_DIR" ]; then
  echo "ERROR: missing site dir: $SITE_DIR" >&2
  exit 2
fi

pages=()
if [ "$#" -gt 0 ]; then
  pages=("$@")
else
  pages=(
    "wegovy-injection-tracker.html"
    "ozempic-injection-tracker.html"
    "zepbound-injection-tracker.html"
    "mounjaro-injection-tracker.html"
  )
fi

ok=0
bad=0
for p in "${pages[@]}"; do
  if [ ! -f "$SITE_DIR/$p" ]; then
    echo "distribution_pack:missing:$p" >&2
    bad=$((bad+1))
    continue
  fi

  python3 "$WS/scripts/distribution-pack.py" --file "$p"
  ok=$((ok+1))
done

echo "distribution_pack:done ok=$ok bad=$bad"
