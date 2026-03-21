#!/usr/bin/env bash
# Unified Reddit script (operator entrypoint)
set -euo pipefail

ACTION="${1:-help}"

help() {
  cat <<'EOF'
Usage: bash scripts/reddit.sh <command> [args]

Core (manual-only posting):
  manual discover [--limit N] [--expires-min M]   Discover fresh candidates (no auth)
  manual prepare --run <run.json> --post-id <id>  Select exactly one candidate + print checklist
  manual log --status posted --comment-url <url>  Log the result (verifies URL resolves)
  manual show-active                              Show currently prepared candidate

Other utilities:
  warmup   Run residential warmup (no posting)
  health   Run reddit health check
  cleanup  Cleanup reddit workspace artifacts
  params   Print ladder params

DEPRECATED / REMOVED FOR SAFETY:
  comment  (old auto-comment scripts; policy requires manual-only)

Policy split:
  - automated/no-auth: discovery, drafting, run-file generation
  - manual/auth: reading live thread, browser/app posting, verification, logging
EOF
}

case "$ACTION" in
  help|-h|--help) help ;;

  manual)
    shift
    python3 /home/jabbit/.openclaw/workspace/scripts/reddit_manual_ops.py "$@"
    ;;

  warmup)
    bash /home/jabbit/.openclaw/workspace/scripts/reddit_residential_warmup.sh
    ;;

  # kept for backwards compatibility, but will refuse in the target script.
  comment)
    bash /home/jabbit/.openclaw/workspace/scripts/reddit_direct_comment_once.sh
    ;;

  health|status)
    bash /home/jabbit/.openclaw/workspace/scripts/reddit-health-check.sh
    ;;

  cleanup)
    bash /home/jabbit/.openclaw/workspace/scripts/reddit-cleanup.sh
    ;;

  params)
    bash /home/jabbit/.openclaw/workspace/scripts/reddit_ladder_params.sh "$@"
    ;;

  *)
    echo "error: unknown command: $ACTION" >&2
    echo >&2
    help >&2
    exit 2
    ;;
esac
