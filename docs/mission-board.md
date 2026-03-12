# Mission Board

_Last updated: 2026-03-12 UTC_

Purpose: one small source of truth for what matters, what state it is in, what the next physical action is, and what counts as done.

## Rules
- This board is for **active priorities only**.
- Every lane must have: **owner, state, next action, last touched, success measure**.
- If a workflow recurs, it must point to a **ledger/state file**.
- No new briefs/docs when an execution backlog already exists.
- If telemetry is stale, fixing measurement outranks interpretation.

---

## 1) Measurement integrity
- **Owner:** Jabby
- **State:** blocked / suspect
- **What matters:** we need honest install + traffic visibility or we optimize blind.
- **Current blocker:** `data/status/site-analytics.json` is reporting all zeros; likely ingestion/tracking failure, not literal zero demand.
- **Next physical action:** trace the writer/collector for `site-analytics.json`, confirm source path/credentials/event flow, and restore non-zero reporting or explicitly mark the feed broken.
- **Last touched:** 2026-03-12 00:19 UTC
- **Success measure:** analytics file updates on schedule with plausible non-zero/stated-null data; executive summaries stop carrying a measurement-integrity warning.
- **State files / evidence:**
  - `data/status/site-analytics.json`
  - `docs/kpi-YYYY-MM-DD.md`
  - `data/status/health.json`

## 2) Distribution / installs
- **Owner:** Jon + Jabby
- **State:** execution backlog
- **What matters:** installs move fastest when the existing ready-to-send queue gets cleared.
- **Current blocker:** 7 `ready_to_send` items are sitting in the growth ledger; system is generating nudges faster than sends happen.
- **Next physical action:** clear the top 3 ready-to-send sends, starting with On The Pen, GLP-1 Tribe, and one coach/clinic contact.
- **Last touched:** 2026-03-12 00:05 UTC
- **Success measure:** ready-to-send backlog drops from 7 to <=3; follow-up states logged cleanly; installs can be tied back to outreach.
- **State files / evidence:**
  - `data/status/manual-growth-loop-ledger.json`
  - `data/status/manual-growth-loop-stagnation.json`
  - `docs/distribution/send-now-brief-latest.md`

## 3) Reddit / trust surface
- **Owner:** Jabby
- **State:** not in a clean daily execution rhythm
- **What matters:** one useful manual comment/day or an explicit logged skip; no draft piles.
- **Current blocker:** telemetry is stale and the daily action loop is not being logged as a hard yes/no.
- **Next physical action:** run one deliberate daily execution check: either identify/post one high-value manual comment or log an explicit skip with reason and next follow-up time.
- **Last touched:** 2026-03-11 13:37 UTC
- **Success measure:** daily log shows `posted=1` or `skip_reason=<clear reason>` every day; 24h follow-up logged; telemetry freshness restored.
- **State files / evidence:**
  - `docs/reddit-daily-execution-checklist.md`
  - `data/status/reddit.json`
  - `data/status/reddit-daily-check.json`

## 4) Product / tool leverage
- **Owner:** Jabby
- **State:** opportunistic, not currently the bottleneck
- **What matters:** only ship product/site changes that clearly lift installs or retention.
- **Current blocker:** measurement integrity is weak, so product/SEO changes are harder to judge honestly.
- **Next physical action:** do not spin up broad product work until analytics honesty is restored; when unblocked, ship the single highest-leverage conversion or utility improvement.
- **Last touched:** 2026-03-11 13:37 UTC
- **Success measure:** shipped change tied to a specific metric hypothesis (install CTR, retention behavior, or user trust signal).
- **State files / evidence:**
  - `docs/breaking-topics-radar.md`
  - `docs/seo-effectiveness-YYYY-MM-DD.md`
  - `WORKLOG.md`

## 5) Ops hygiene
- **Owner:** Jabby
- **State:** needs cleanup
- **What matters:** hidden repo state and stale telemetry create false confidence and execution drag.
- **Current blocker:** repo is ahead by 6 commits and dirty; healthcheck flags both.
- **Next physical action:** commit/reconcile current changes, push cleanly, and keep healthcheck green.
- **Last touched:** 2026-03-11 13:37 UTC
- **Success measure:** `git ahead=0 dirty=false` in health output; no recurring git hygiene alerts.
- **State files / evidence:**
  - `data/status/health.json`
  - `data/status/systems.json`

---

## Daily forcing-function order
When multiple things are wrong, prioritize in this order:
1. **Measurement honesty**
2. **Execution backlog clearance**
3. **One real trust-surface action (Reddit/manual distribution)**
4. **Only then new assets/pages/tools**

## Done definitions
- **Measurement integrity:** feed is fresh and believable
- **Distribution:** queued send executed or explicitly rescheduled with reason
- **Reddit:** one manual comment posted + logged, or explicit skip logged
- **Product/SEO:** one shipped change tied to a metric hypothesis
- **Ops:** repo clean/pushed and health checks green
