#!/usr/bin/env bash
# Remove only expired, reproducible Reddit pipeline artifacts.
# Scheduled by the user crontab at 03:00 UTC. Use --dry-run to inspect candidates.

set -euo pipefail

WORKSPACE_ROOT="/home/jabbit/.openclaw/workspace"
REDDIT_DATA="$WORKSPACE_ROOT/data/reddit"
LOG_DIR="$WORKSPACE_ROOT/logs"
LOG_FILE="$LOG_DIR/nightly-cleanup.log"
DRY_RUN=false

case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=true ;;
  *)
    echo "Usage: $0 [--dry-run]" >&2
    exit 64
    ;;
esac

mkdir -p "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$1" | tee -a "$LOG_FILE"
}

if [[ ! -d "$REDDIT_DATA" ]]; then
  log "Reddit data directory is absent; nothing to clean: $REDDIT_DATA"
  exit 0
fi

# Prevent a manual run and the cron run from deleting the same artifact.
exec 9>"$LOG_DIR/nightly-cleanup.lock"
if ! flock -n 9; then
  log "Another nightly cleanup is already running; exiting safely"
  exit 0
fi

candidate_count=0
removed_count=0
candidate_bytes=0

cleanup_pattern() {
  local search_root="$1"
  local pattern="$2"
  local age_days="$3"
  local label="$4"
  local file size
  local -a candidates=()

  if [[ ! -d "$search_root" ]]; then
    log "$label: search directory absent; skipped"
    return
  fi

  mapfile -d '' candidates < <(
    find "$search_root" -type f -name "$pattern" -mtime "+$age_days" -print0
  )

  log "$label: ${#candidates[@]} expired candidate(s)"
  for file in "${candidates[@]}"; do
    # Defense in depth: every deletion target must remain under data/reddit.
    [[ "$file" == "$REDDIT_DATA/"* ]] || {
      log "Refusing target outside Reddit data directory: $file"
      return 1
    }

    size=$(stat -c '%s' -- "$file" 2>/dev/null || printf '0')
    candidate_count=$((candidate_count + 1))
    candidate_bytes=$((candidate_bytes + size))

    if $DRY_RUN; then
      log "WOULD_REMOVE $file"
    else
      rm -- "$file"
      removed_count=$((removed_count + 1))
      log "REMOVED $file"
    fi
  done
}

mode="live"
$DRY_RUN && mode="dry-run"
log "=== Starting nightly data cleanup ($mode) ==="

# These are transient pipeline outputs, not ledgers, account state, telemetry,
# review queues, run records, or hand-authored data.
cleanup_pattern "$REDDIT_DATA" 'classify_queue_*.json' 2 'classify queues (>72h)'
cleanup_pattern "$REDDIT_DATA" 'queue_filtered_*.json' 2 'filtered queues (>72h)'
cleanup_pattern "$REDDIT_DATA" 'engagement_queue_*.json' 2 'engagement queues (>72h)'
cleanup_pattern "$REDDIT_DATA" 'results_*.json' 3 'result artifacts (>96h)'
cleanup_pattern "$REDDIT_DATA/raw" 'posts_*.json' 3 'raw post snapshots (>96h)'

if $DRY_RUN; then
  log "Dry run complete: $candidate_count candidate(s), $candidate_bytes byte(s); removed 0"
else
  log "Cleanup complete: $removed_count/$candidate_count candidate(s) removed; up to $candidate_bytes byte(s) reclaimed"
fi
log "Current Reddit data size: $(du -sb "$REDDIT_DATA" | cut -f1) bytes"
log "=== Nightly data cleanup complete ==="
