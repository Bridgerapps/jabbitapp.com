# Mission Board

_Last updated: 2026-04-28 UTC_

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
- **Current blocker:** site analytics is **decision-unsafe**: it may return `ok=true` while still being **suspect** (e.g., only root page seen / extremely low event volume). We must treat that as a broken signal until disproven.
- **Next physical action:** trace the writer/collector for `site-analytics.json`, confirm real-world event ingestion (not just health pings), and keep the status explicitly **OK vs BROKEN vs SUSPECT** (never silently implying zero).
- **Last touched:** 2026-03-12 00:19 UTC
- **Success measure:** analytics file updates on schedule with plausible non-zero/stated-null data; executive summaries stop carrying a measurement-integrity warning.
- **State files / evidence:**
  - `data/status/site-analytics.json`
  - `docs/kpi-YYYY-MM-DD.md`
  - `data/status/health.json`

## 2) Distribution / installs
- **Owner:** Jon + Jabby
- **State:** hard blocked
- **What matters:** installs will not move from outbound until the sender identity is real and usable.
- **Current blocker:** unsolicited outreach is blocked because sender identity is still `jabbit@bridgerapps.com`, not `@jabbitapp.com`. That means we keep talking about distribution without actually being able to execute it safely.
- **Next physical action:** finish the `@jabbitapp.com` sender setup (From + Reply-To + domain verification), run one test send to self, then resume manual distribution.
- **Last touched:** 2026-04-28 15:00 UTC
- **Success measure:** outbound is unblocked with verified `@jabbitapp.com` identity and one successful canary send; only then do we judge outreach throughput.
- **State files / evidence:**
  - `data/status/distribution-daily-check.json`
  - `docs/distribution-daily-log.md`
  - `data/status/manual-growth-loop-ledger.json`

## 3) Reddit / trust surface
- **Owner:** Jon + Jabby
- **State:** stalled
- **What matters:** one real manual high-intent comment beats a week of passive monitoring.
- **Current blocker:** no actual manual Reddit action has been executed, so this lane is generating zero learning while still consuming attention in summaries.
- **Next physical action:** do one deliberate comment in a tracking/adherence/logging-fit thread, paste the URL here, then log the outcome and schedule exactly one 24h follow-up.
- **Last touched:** 2026-04-28 15:00 UTC
- **Success measure:** one real thread URL logged, one follow-up logged, and at least one observable reply/upvote/click outcome to learn from.
- **State files / evidence:**
  - `docs/reddit-daily-execution-checklist.md`
  - `data/status/reddit-daily-check.json`

## 4) Product / tool leverage
- **Owner:** Jabby
- **State:** reset in progress
- **What matters:** ship fewer changes, but tie each one to an install hypothesis on pages that already get real traffic.
- **Current blocker:** we spent the last two weeks producing many breaking-topic SEO pages, but traffic stayed tiny and attribution stayed weak. That was output, not proof.
- **Next physical action:** pause the breaking-topic SEO factory. Keep only focused conversion work on the homepage and the top existing high-intent pages until traffic or installs justify reopening the content lane.
- **Last touched:** 2026-04-28 15:00 UTC
- **Success measure:** each shipped page change is attached to an explicit hypothesis on an already-viewed page; no new low-signal SEO pages ship by default.
- **State files / evidence:**
  - `docs/kpi-YYYY-MM-DD.md`
  - `docs/seo-effectiveness-YYYY-MM-DD.md`
  - `data/status/site-analytics.json`

## 5) Ops hygiene
- **Owner:** Jabby
- **State:** needs cleanup
- **What matters:** dirty repos and unpushed state keep making summaries noisier than they should be.
- **Current blocker:** repo is still ahead and dirty because automation keeps touching generated SEO/support files faster than the system closes the loop.
- **Next physical action:** after pausing low-signal SEO automation, reconcile the remaining dirty files, commit intentional changes only, and push cleanly.
- **Last touched:** 2026-04-28 15:00 UTC
- **Success measure:** `git ahead=0 dirty=false` in health output and daily summaries stop repeating the same hygiene warning.
- **State files / evidence:**
  - `data/status/health.json`
  - `data/status/systems.json`

---

## Daily forcing-function order
When multiple things are wrong, prioritize in this order:
1. **Measurement honesty**
2. **Unblock sender identity / execution ability**
3. **One real trust-surface action (Reddit/manual distribution)**
4. **Focused conversion work on existing traffic pages**
5. **Only then new assets/pages/tools**

## Review frame
Use `docs/mission-board-review-checklist.md` for recurring reviews/summaries so they come from the same operator frame every time.

## Done definitions
- **Measurement integrity:** feed is fresh and believable
- **Distribution:** queued send executed or explicitly rescheduled with reason
- **Reddit:** one manual comment posted + logged, or explicit skip logged
- **Product/SEO:** one shipped change tied to a metric hypothesis
- **Ops:** repo clean/pushed and health checks green
