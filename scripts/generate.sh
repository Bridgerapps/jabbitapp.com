#!/usr/bin/env bash
# Unified generator - consolidates all report generators

CMD="${1:-all}"

case "$CMD" in
  daily-brief) bash ~/.openclaw/workspace/scripts/generate-daily-exec-brief.sh ;;
  daily-review) bash ~/.openclaw/workspace/scripts/generate-daily-review.sh ;;
  kpi) bash ~/.openclaw/workspace/scripts/generate-kpi-dashboard.sh ;;
  operator) bash ~/.openclaw/workspace/scripts/generate-operator-update.sh ;;
  all)
    echo "=== Daily Brief ==="
    bash ~/.openclaw/workspace/scripts/generate-daily-exec-brief.sh
    echo ""
    echo "=== KPI Dashboard ==="
    bash ~/.openclaw/workspace/scripts/generate-kpi-dashboard.sh
    ;;
  *) echo "Usage: $0 {daily-brief|daily-review|kpi|operator|all}" ;;
esac
