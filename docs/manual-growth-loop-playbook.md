# Manual Growth Loop — Playbook

Purpose: keep the hourly loop **distribution-first**, non-repetitive, and tied to **installs** (track paid, but optimize for installs first).

## 0) Inputs (always read)
- `WORKLOG.md` (what we actually did)
- `docs/kpi-YYYY-MM-DD.md` (north star + funnel health)
- `MEMORY.md` (hard rules + preferences)
- `data/status/manual-growth-loop-ledger.json` (what’s actually queued)

Fast check (recommended at the top of every run):
- `scripts/manual-growth-loop/operator-next.sh` → prints the **single** next move (normal vs self-improvement vs SEND-ONLY)
- `scripts/manual-growth-loop/preflight.sh` → shows next iteration/mode + ledger queue counts (no mutations)
- `scripts/manual-growth-loop/ensure-kpi-today.sh` → creates today’s `docs/kpi-YYYY-MM-DD.md` if missing (safe, idempotent)
- `scripts/manual-growth-loop/execution-gate.sh` → hard-stops the loop if anything is `ready_to_send` (prevents “brief churn”)
- `scripts/manual-growth-loop/ledger-next.sh` → shows overdue + next-24h sendQueue items.
- `scripts/manual-growth-loop/stale-ready-to-send-nudge.sh` → prints a ready-to-send “nudge payload” if the queue is stagnating (rate-limited by a local state file).

Reliability tip:
- Record each run in `data/status/manual-growth-loop-history.json` via `scripts/manual-growth-loop/record-run.sh` (makes self-improvement audits faster, reduces repetition)

## 1) Action taxonomy (for de-dupe)
When choosing actions, tag each one:
- **D** = distribution execution (DMs/emails posted *manually by Jon/Tim/Jabby in-session*)
- **L** = lead discovery (identify targets + contact path)
- **C** = copy pack (templates, outreach scripts)
- **R** = Reddit opportunity (unauthenticated sourcing only; execution remains manual; prioritize high-intent comments over attempts at viral posting)
- **M** = measurement/instrumentation (analytics sanity, App Store reporting, KPI refresh)
- **CRO** = on-site conversion improvement (max 1 website push/day)

Hard anti-busywork rule:
- In any 3-action run, **at least 1** must be **D** or **M**. If we can’t do D (because it requires humans), we do M.

**Backlog-first rule (new):**
- If the ledger has **any** `ready_to_send` items, *do not* spend the run sourcing new leads or writing more copy.
- Instead, produce a **10-minute send plan** (who sends what, where, with links) and/or do **M** (measurement) so we can attribute outcomes.

## 2) Non-repetition guardrail
Before acting, scan the last ~5 WORKLOG entries and avoid repeating the same taxonomy two runs in a row.
Examples:
- If the last run was mostly **C** (copy packs), the next run should be **L** or **M**.
- If we already generated clinic outreach copy this cycle, the next run should find *new* leads or create a *manual send plan*.

## 3) Web search reliability (429 fallback)
If `web_search` rate limits (429) or is flaky:
1. Switch to **local docs + existing lead lists** (don’t stall the run).
2. Use **web_fetch** only for 1–2 known URLs (targeted, low volume).
3. Capture the failure in WORKLOG + add a “retry later” note (don’t loop).

## 4) Output that actually moves installs (72h lens)
Preferred hourly outputs:
- A short **manual send queue**: 3 targets + exact message + when to send + expected outcome.
- A **single** high-intent Reddit thread plan (subreddit + search query + comment angle + where a Jabbit mention fits naturally).
- Prefer Reddit plans where the comment is useful even **without** the Jabbit mention. Mentions are earned relevance, not the payload.
- If Reddit is the chosen lane for the run, the output must point to `docs/reddit-daily-execution-checklist.md` and name **one** thread to either post on now or explicitly skip with reason. No multi-thread draft piles.
- A measurement check that prevents self-deception (test traffic, broken tracking, stale App Store report date).

**Brief de-dupe rule (new):**
- Keep **one** canonical “send-now brief” per day.
- If you need to adjust priorities, **update the existing brief** instead of writing a fresh one.
- Use: `scripts/manual-growth-loop/send-now-brief-latest.sh` (creates `docs/distribution/send-now-brief-latest.md` symlink)

**Anti-stall rule (new):** every run must *advance state* somewhere.
- Update `data/status/manual-growth-loop-ledger.json` with at least one of:
  - a new lead (with contact path) OR
  - a sendQueue item (who/what/when) OR
  - a follow-up action (nextTouch)
This prevents “infinite copy packs” and makes follow-ups the default.

## 5) Self-improvement run (every 5th)
Checklist:
- What repeated in the last 5 runs?
- What did we avoid (manual execution plans, measurement, or follow-ups)?
- What broke (rate limits, missing tools, missing files)?
- Add 1 guardrail + apply 1 safe fix immediately (docs/script), then verify + commit.
