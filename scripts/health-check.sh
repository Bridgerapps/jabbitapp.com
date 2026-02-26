#!/usr/bin/env bash
# Unified health check - consolidates all health checks

echo "=== Health Check ==="

# Reddit
echo -n "Reddit: "
bash ~/.openclaw/workspace/scripts/reddit-health-check.sh 2>/dev/null | head -1

# Twitter  
echo -n "Twitter: "
bash ~/.openclaw/workspace/scripts/twitter-health-check.sh 2>/dev/null | head -1

# Pipeline
echo -n "Pipeline: "
bash ~/.openclaw/workspace/scripts/pipeline-health-check.sh 2>/dev/null | head -1

# Circuit breaker
echo -n "Circuit: "
bash ~/.openclaw/workspace/scripts/circuit-breaker-daily-reset.sh --check 2>/dev/null | head -1

echo "Done."
