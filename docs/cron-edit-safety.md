# Cron Edit Safety

## Problem this prevents
Some cron jobs tried to autonomously patch files using exact-text `edit` operations. On high-churn files (like homepage HTML), those edits fail when target text shifts.

## Policy
- Do **not** run broad autonomous jobs that can modify arbitrary files.
- Keep cron jobs single-purpose and script-driven.
- For file changes, use deterministic scripts or full rewrites after reading current file state.
- Avoid direct `edit` operations in autonomous cron prompts.

## Guardrail
Run:

```bash
bash /home/jabbit/.openclaw/workspace/scripts/cron-safety-lint.sh
```

Expected:

```text
cron-lint: OK
```

If it fails, remove or rewrite the flagged job prompt before re-enabling.
