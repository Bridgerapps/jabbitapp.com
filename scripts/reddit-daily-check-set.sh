#!/usr/bin/env bash
set -euo pipefail

# Update data/status/reddit-daily-check.json with an explicit daily truth.
# This is a forcing function: every day must be either POSTED or SKIPPED (with reason).
#
# Usage:
#   scripts/reddit-daily-check-set.sh post --subreddit r/glp1 --thread_url "https://..." --jabbit_mentioned true --why "..." --followup_due_utc "2026-03-14T12:00:00Z" --notes "..."
#   scripts/reddit-daily-check-set.sh skip --reason "travel day" --followup_due_utc "2026-03-14T12:00:00Z" --notes "..."

WS="/home/jabbit/.openclaw/workspace"
OUT="$WS/data/status/reddit-daily-check.json"
DATE_UTC=$(date -u +%Y-%m-%d)
NOW_UTC=$(date -u +%FT%TZ)

cmd="${1:-}"
shift || true

subreddit=""
thread_url=""
jabbit_mentioned="false"
why_this_thread=""
followup_due_utc=""
notes=""
skip_reason=""

while [ $# -gt 0 ]; do
  case "$1" in
    --subreddit) subreddit="$2"; shift 2;;
    --thread_url) thread_url="$2"; shift 2;;
    --jabbit_mentioned) jabbit_mentioned="$2"; shift 2;;
    --why|--why_this_thread) why_this_thread="$2"; shift 2;;
    --followup_due_utc) followup_due_utc="$2"; shift 2;;
    --notes) notes="$2"; shift 2;;
    --reason|--skip_reason) skip_reason="$2"; shift 2;;
    -h|--help) cmd="help"; shift;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

usage() {
  cat <<'EOF'
Set Reddit daily execution truth.

Commands:
  post  - mark that we posted a manual comment today
  skip  - mark an explicit skip (must include --reason)

Examples:
  scripts/reddit-daily-check-set.sh post --subreddit r/Ozempic --thread_url "https://reddit.com/..." \
    --jabbit_mentioned false --why "high-intent tracking question" --followup_due_utc "2026-03-14T12:00:00Z"

  scripts/reddit-daily-check-set.sh skip --reason "no safe threads (mod rules)" --followup_due_utc "2026-03-14T12:00:00Z"
EOF
}

mkdir -p "$WS/data/status"
if [ ! -f "$OUT" ]; then
  printf '{"date":"%s","posted":false,"skip_reason":"","subreddit":"","thread_url":"","jabbit_mentioned":false,"why_this_thread":"","followup_due_utc":"","followup_checked":false,"notes":""}\n' "$DATE_UTC" > "$OUT"
fi

case "$cmd" in
  post)
    if [ -z "$thread_url" ] || [ -z "$subreddit" ]; then
      echo "post requires --subreddit and --thread_url" >&2
      exit 2
    fi
    UPDATED=$(jq --arg date "$DATE_UTC" --arg now "$NOW_UTC" \
      --arg subreddit "$subreddit" --arg thread_url "$thread_url" \
      --arg why "$why_this_thread" --arg followup "$followup_due_utc" \
      --arg notes "$notes" --argjson jm "$jabbit_mentioned" '
        .date=$date
        | .posted=true
        | .skip_reason=""
        | .subreddit=$subreddit
        | .thread_url=$thread_url
        | .jabbit_mentioned=$jm
        | .why_this_thread=$why
        | .followup_due_utc=$followup
        | .notes=$notes
        | .last_updated_utc=$now
      ' "$OUT")
    ;;
  skip)
    if [ -z "$skip_reason" ]; then
      echo "skip requires --reason" >&2
      exit 2
    fi
    UPDATED=$(jq --arg date "$DATE_UTC" --arg now "$NOW_UTC" \
      --arg reason "$skip_reason" --arg followup "$followup_due_utc" --arg notes "$notes" '
        .date=$date
        | .posted=false
        | .skip_reason=$reason
        | .subreddit=""
        | .thread_url=""
        | .jabbit_mentioned=false
        | .why_this_thread=""
        | .followup_due_utc=$followup
        | .notes=$notes
        | .last_updated_utc=$now
      ' "$OUT")
    ;;
  help|""|--help|-h)
    usage
    exit 0
    ;;
  *)
    echo "unknown command: $cmd" >&2
    usage
    exit 2
    ;;
esac

TMP="$OUT.tmp"
printf "%s\n" "$UPDATED" > "$TMP"
mv "$TMP" "$OUT"

# Print one-line summary for logs
jq -r '"ok date=\(.date) posted=\(.posted) skip_reason=\(.skip_reason|@json) thread_url=\(.thread_url|@json)"' "$OUT"
