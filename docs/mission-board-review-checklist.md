# Mission Board Review Checklist

Purpose: force every operator summary/review to come from the same frame instead of freehand rediscovery.

## Use this for
- morning mission-board review
- noon/day backlog review
- exec summaries when a quick structured scan is needed
- any manual "what matters now" check

## Read in this order
1. `docs/mission-board.md`
2. `data/status/health.json`
3. `data/status/systems.json`
4. `data/status/site-analytics.json`
5. `data/status/manual-growth-loop-ledger.json`
6. `data/status/manual-growth-loop-stagnation.json`
7. `data/status/reddit.json`
8. `data/status/reddit-daily-check.json` (if present)
9. `data/status/distribution-daily-check.json` (if present)
10. today's `docs/kpi-YYYY-MM-DD.md` (if present)

## Review questions
### 1) Measurement honesty
- Are analytics/App Store/Reddit feeds fresh?
- Is any core metric obviously broken, stale, or zeroed-out?
- If yes: what is the likely cause and exact next fix?

### 2) Backlog reality
- Is there `ready_to_send` backlog?
- Are we generating more briefs/docs instead of clearing queue?
- What is the single highest-leverage queued action?

### 3) Trust-surface execution
- Did Reddit get a real post-or-skip decision today?
- Is telemetry fresh enough to learn honestly?
- Are we drifting into drafts/opportunity piles instead of one real action?

### 4) Product / SEO / tooling
- Did we ship something because it mattered, or because it was easy to do?
- Is measurement good enough to justify interpretation?
- If product/SEO is not the bottleneck, say so.

### 5) Ops hygiene
- Is repo state clean enough to trust?
- Any dirty-tree / unpushed / stale-run / failing cron noise that affects decision quality?

## Output format
Keep it concise and decision-useful:
- **What shipped**
- **What moved installs**
- **What got stuck**
- **What was fake progress**
- **Single highest-leverage next action**

If a section is empty, say that plainly.
If attribution is weak, say **unknown**.

## Anti-fake-progress rules
- Do not create new plans if queue backlog exists.
- Do not praise activity that did not move state.
- If measurement is broken, lead with that.
- If nothing materially changed, say that plainly.
- Do not count script/cron/logging/guardrail changes as “self-improvement” unless they clearly removed a bottleneck or changed externally visible output.
- Do not imply SEO shipped = downloads moved unless attribution is actually supported.
- Treat blocked owner approvals and unexecuted manual trust-surface work as the real bottleneck when present.
