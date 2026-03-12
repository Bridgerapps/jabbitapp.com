# HEARTBEAT.md

Keep this short. Heartbeats are for lightweight operator checks, not long projects.
They are the **watchdog layer**, not the primary execution engine.

## Rules
- If nothing below needs action, reply exactly: `HEARTBEAT_OK`
- Be quiet by default between **23:00–08:00 ET** unless something is urgent
- Don’t resurrect old tasks from prior chats unless explicitly listed here
- Prefer checking existing local status/docs before doing anything noisy
- Traction over artifacts: don’t create new plans/docs unless they unblock action
- If a recurring task needs guaranteed timing, put it on cron and point it at a board/ledger instead of relying on heartbeat luck

## On each heartbeat, do at most ONE of these

1. **Ops sanity check**
   - Read `data/status/systems.json`
   - If there is a real blocker/regression/stale telemetry, send a short operator alert with:
     - what changed
     - likely cause
     - confidence
     - immediate next fix

2. **Growth bottleneck check**
   - If `data/status/manual-growth-loop-stagnation.json` shows ongoing stagnation or `manual-growth-loop-ledger.json` has `ready_to_send` backlog, send one short nudge focused on the single highest-leverage action
   - Do not generate more outreach packs/briefs from heartbeat alone

3. **Measurement honesty check**
   - If site analytics / App Store / Reddit telemetry is stale or obviously broken, alert once with the suspected cause and the exact fix to run next

4. **Memory maintenance**
   - Only occasionally (not every heartbeat): review recent `memory/YYYY-MM-DD.md` files and distill anything important into `MEMORY.md`

## Reach out only when
- there is a new blocker
- a metric/telemetry feed is stale or broken
- there is one clear action Jon should take now
- something materially changed that affects decisions

Otherwise: `HEARTBEAT_OK`
