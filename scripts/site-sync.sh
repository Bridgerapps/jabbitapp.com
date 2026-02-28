#!/usr/bin/env bash
# Sync + audit static site SEO plumbing.
#
# Why this exists:
# After editing/adding pages we repeatedly need to:
#   1) sync topic tracker
#   2) apply related-links rules
#   3) regenerate sitemap
#   4) run audits
#   5) refresh health status JSON
# This script makes that a single, repeatable command.

set -euo pipefail

WS="/home/jabbit/.openclaw/workspace"

cmd="${1:-all}"

run_sync() {
  python3 "$WS/scripts/seo-sync-tracker.py" >/dev/null
  python3 "$WS/scripts/related-links-sync.py" >/dev/null
  # Keep FAQPage structured data in sync for any pages that include <dl class="faq">.
  python3 "$WS/scripts/faq-jsonld-sync.py" >/dev/null
  python3 "$WS/scripts/generate-sitemap.py" >/dev/null
}

run_audit() {
  bash "$WS/scripts/html-seo-audit.sh" >/dev/null
  bash "$WS/scripts/sitemap-audit.sh" >/dev/null
  python3 "$WS/scripts/internal-link-audit.py" >/dev/null
  # Ensure FAQ JSON-LD is up-to-date (no-op when already synced).
  python3 "$WS/scripts/faq-jsonld-sync.py" --check --json >/dev/null
}

case "$cmd" in
  sync)
    run_sync
    echo "site-sync: ok"
    ;;
  audit)
    run_audit
    echo "site-audit: ok"
    ;;
  health)
    bash "$WS/scripts/health-check.sh" >/dev/null
    echo "health-check: ok"
    ;;
  all|verify)
    run_sync
    run_audit
    bash "$WS/scripts/health-check.sh" >/dev/null
    echo "site-verify: ok"
    ;;
  *)
    echo "Usage: $0 {sync|audit|health|all}" >&2
    exit 2
    ;;
esac
