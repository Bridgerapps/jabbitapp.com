#!/usr/bin/env bash
set -euo pipefail

JOBS_FILE="/home/jabbit/.openclaw/cron/jobs.json"

if [ ! -f "$JOBS_FILE" ]; then
  echo "cron-lint: jobs file not found: $JOBS_FILE"
  exit 0
fi

# Flags prompts that are broad, autonomous file-edit instructions.
RISK_RE='Do not wait for user prompts|Produce concrete output|create/update at least one workspace artifact|Autonomous .*execution loop|\bedit\b.*\bfile\b'

hits=$(jq -r '.jobs[] | select(.enabled==true) | [.id, .name, (.payload.message // "")] | @tsv' "$JOBS_FILE" \
  | awk -F'\t' -v re="$RISK_RE" '
      BEGIN{IGNORECASE=1}
      $3 ~ re {print $1"\t"$2}
    ')

if [ -n "$hits" ]; then
  echo "cron-lint: FAIL (risky autonomous-edit style jobs detected)"
  echo "$hits" | while IFS=$'\t' read -r id name; do
    echo " - $name ($id)"
  done
  exit 2
fi

# Detect duplicate enabled jobs (usually accidental). We define duplicates as:
# same name + schedule (kind/expr/tz/everyMs/at) + sessionTarget + payload kind + payload text/message.
# This prevents “N copies of the same hourly check” silently spamming the scheduler.
dupes=$(jq -r '
  .jobs
  | map(select(.enabled==true))
  | map({
      id, name,
      schedule_key: ((.schedule.kind//"") + "|" + (.schedule.expr//"") + "|" + (.schedule.tz//"") + "|" + ((.schedule.everyMs//0)|tostring) + "|" + (.schedule.at//"")),
      sessionTarget: (.sessionTarget//""),
      payloadKind: (.payload.kind//""),
      payloadBody: ((.payload.text // .payload.message // "") | gsub("\\s+";" ") | .[0:240])
    })
  | group_by(.name + "|" + .schedule_key + "|" + .sessionTarget + "|" + .payloadKind + "|" + .payloadBody)
  | map(select(length > 1))
  | .[]
  | "DUPLICATE\t" + (.[0].name) + "\t" + (.[0].schedule_key) + "\t" + (map(.id) | join(","))
' "$JOBS_FILE" 2>/dev/null || true)

if [ -n "$dupes" ]; then
  echo "cron-lint: FAIL (duplicate enabled jobs detected)"
  echo "$dupes" | while IFS=$'\t' read -r _ name sched ids; do
    echo " - $name [$sched] ids=$ids"
  done
  exit 3
fi

echo "cron-lint: OK"
