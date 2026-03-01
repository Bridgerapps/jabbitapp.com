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

echo "cron-lint: OK"
