#!/usr/bin/env bash
set -euo pipefail

# Report stale ready_to_send items with age + suggested next actions.
# Safe: read-only; prints a concise report.

WS="/home/jabbit/.openclaw/workspace"
LEDGER_DEFAULT="$WS/data/status/manual-growth-loop-ledger.json"
LEDGER="$LEDGER_DEFAULT"
THRESHOLD_SECONDS="${THRESHOLD_SECONDS:-86400}" # 24h

# Args:
#   stale-ready-report.sh [--hours N] [ledgerPath]
#   stale-ready-report.sh [--threshold-hours N] [ledgerPath]   # alias
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hours)
      shift
      [[ $# -gt 0 ]] || { echo "ERR: --hours requires a value" >&2; exit 2; }
      THRESHOLD_SECONDS=$(( $1 * 3600 ))
      shift
      ;;
    --threshold-hours)
      shift
      [[ $# -gt 0 ]] || { echo "ERR: --threshold-hours requires a value" >&2; exit 2; }
      THRESHOLD_SECONDS=$(( $1 * 3600 ))
      shift
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--hours N|--threshold-hours N] [ledgerPath]"; exit 0
      ;;
    *)
      LEDGER="$1"
      shift
      ;;
  esac
done

if [[ ! -f "$LEDGER" ]]; then
  echo "ERR: missing ledger: $LEDGER" >&2
  exit 2
fi

now=$(date -u +%s)

jq -r --argjson now "$now" --argjson thr "$THRESHOLD_SECONDS" '
  [.sendQueues[]?
    | select(.status=="ready_to_send")
    | . + {
        whenEpoch: (
          if .whenUtc then
            (try (.whenUtc | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) catch 0)
          else 0 end
        )
      }
    | . + {ageSec: ($now - .whenEpoch)}
    | select(.whenEpoch>0 and .ageSec >= $thr)
  ]
  | sort_by(.ageSec) | reverse
  | if length==0 then
      "STALE_READY_REPORT: none"
    else
      "STALE_READY_REPORT: " + (length|tostring) + " items >= " + ($thr|tostring) + "s\n" +
      (map(
        "- " + (.id//"(missing id)")
        + " | lead=" + (.leadId//"?")
        + " | channel=" + (.channel//"?")
        + " | to=" + (.to//"?")
        + " | ageSec=" + (.ageSec|tostring)
        + (if .brief then "\n  brief: " + .brief else "" end)
        + (if .doc then "\n  doc: " + .doc else "" end)
      ) | join("\n"))
    end
' "$LEDGER"

echo

echo "Next step: either (a) send top-3 now + mark sent, or (b) explicitly close/deprioritize stale leads so the loop can move."
