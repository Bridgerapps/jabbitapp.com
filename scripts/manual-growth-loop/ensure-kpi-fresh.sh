#!/usr/bin/env bash
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DAY="$(date -u +%F)"
KPI="$WS/docs/kpi-$DAY.md"
LEDGER="$WS/data/status/manual-growth-loop-ledger.json"
GEN="$WS/scripts/generate-kpi-dashboard.sh"

# If KPI missing, just ensure it exists (delegates to generator)
if [ ! -f "$KPI" ]; then
  "$GEN" "$KPI" >/dev/null
  echo "kpi:fresh:created:$KPI"
  exit 0
fi

# If ledger missing, nothing to freshness-check.
if [ ! -f "$LEDGER" ]; then
  echo "kpi:fresh:skip:no-ledger"
  exit 0
fi

# If ledger is newer than KPI, regenerate so the dashboard reflects ready_to_send truth.
if [ "$LEDGER" -nt "$KPI" ]; then
  "$GEN" "$KPI" >/dev/null
  echo "kpi:fresh:regenerated:$KPI"
else
  echo "kpi:fresh:ok:$KPI"
fi
