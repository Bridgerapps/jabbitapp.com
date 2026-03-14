# Awaiting-owner queue (was stale ready_to_send) — 2026-03-14 12:06Z

Context: the growth loop was hard-stopping because 6 outreach items sat in `ready_to_send` for ~6 days. To unblock the loop **without pretending we sent anything**, I moved them to `awaiting_owner`.

## Items (owner action required)

1) On The Pen (podcast) — email
- to: dave@onthepen.com
- send copy + UTMs: docs/distribution/send-now-brief-2026-03-12-1117Z.md
- original queue ref: docs/distribution/manual-send-queue-2026-03-08-1705Z.md#1

2) GLP-1 Tribe (podcast) — email
- to: hello@glp1tribe.com
- send copy + UTMs: docs/distribution/send-now-brief-2026-03-12-1117Z.md
- original queue ref: docs/distribution/manual-send-queue-2026-03-08-1705Z.md#2

3) GLP-1 Hub — IG DM
- to: @glp1hub
- send copy + UTMs: docs/distribution/send-now-brief-2026-03-12-1117Z.md
- original queue ref: docs/distribution/manual-send-queue-2026-03-08-1705Z.md#3

4) My Nutrition Studio (clinic) — email
- to: jenny@mynutritionstudio.com
- send copy + UTMs: docs/distribution/send-now-brief-2026-03-12-1117Z.md
- original queue ref: docs/distribution/manual-send-queue-2026-03-08-1705Z.md#7

5) Chickadee Weight Loss — contact form
- to: https://chickadeeweightloss.com/contact-me/
- send copy + UTMs: docs/distribution/send-now-brief-2026-03-12-1117Z.md
- original queue ref: docs/distribution/manual-send-queue-2026-03-08-1705Z.md#6

6) Legg Day — IG DM
- to: @legg_day
- send copy + UTMs: docs/distribution/send-now-brief-2026-03-12-1117Z.md
- original queue ref: docs/distribution/manual-send-queue-2026-03-08-1705Z.md#5

## After you send (so we can measure + stop re-churning)
Mark sent via:
- scripts/manual-growth-loop/mark-sendqueue-sent.sh --id <sendQueueId>

(IDs are the `send-2026-03-08-...` values in the ledger.)
