# Reddit Touchpoints Audit — 2026-03-03

## Scripts touching Reddit
- scripts/find_reddit_opportunities.py
- scripts/find_reddit_opportunities_newacct.py
- scripts/reddit-account-health-check.sh
- scripts/reddit-backup.sh
- scripts/reddit-circuit-breaker.sh
- scripts/reddit-cleanup.sh
- scripts/reddit-draft-batch.sh
- scripts/reddit-health-check.sh
- scripts/reddit-post-new-page.sh
- scripts/reddit-proxy-rotate-target.sh
- scripts/reddit-telemetry.sh
- scripts/reddit.env
- scripts/reddit.sh
- scripts/reddit_candidate_comments.py
- scripts/reddit_comment_generator.py
- scripts/reddit_daily_metrics.py
- scripts/reddit_direct_comment_once.sh
- scripts/reddit_discover_big_research_subs.py
- scripts/reddit_expand_watchlist.py
- scripts/reddit_ladder_params.sh
- scripts/reddit_mine_upvoted_patterns.py
- scripts/reddit_negative_feedback_blacklist.sh
- scripts/reddit_post_comment.sh
- scripts/reddit_residential_warmup.sh
- scripts/reddit_shotsy_watch.py
- scripts/reddit_shotsy_watchlist_refresh.py
- scripts/reddit_smart_review_post.py
- scripts/reddit_subscribe_shotsy_subs.sh
- scripts/reddit_track_comments_progress.sh
- scripts/reddit_upvote_user_comment_daily.sh
- scripts/reddit_upvote_user_daily.sh
- scripts/run_reddit_warmup_metrics.sh

## Reddit data/state files
- data/reddit/.circuit_breaker
- data/reddit/community-watch-subreddits.json
- data/reddit/community-watch-subreddits.txt
- data/reddit/daily-baseline/2026-03-01.txt
- data/reddit/daily-baseline/2026-03-02.txt
- data/reddit/daily-baseline/2026-03-03.txt
- data/reddit/negative-post-blacklist.txt
- data/reddit/poodpound-comment-progress.json
- data/reddit/posted-ids.txt
- data/reddit/reddit-health.json
- data/reddit/research-peptide-biohacking-subs.json
- data/reddit/research-peptide-biohacking-subs.txt
- data/reddit/review-queue-latest.json
- data/reddit/shotsy-opportunities.json
- data/reddit/shotsy-watch-subreddits.json
- data/reddit/shotsy-watch-subreddits.txt
- data/reddit/subscription-activity.json
- data/reddit/upvoted-comment-patterns.json
- data/reddit/user-comment-upvote-state.json

## Cron jobs (Reddit-related)
- reddit-opportunity-surface-noauth-4h (fae93aeb-d141-4192-b449-fd904356d4d7) — DISABLED
- reddit-daily-metrics-summary (2480c56f-eef9-4815-91c3-5b6ccd18be76) — DISABLED
- reddit-direct-comment-8h (359f691d-587f-4a37-a32f-b354d8a61240) — DISABLED
- reddit-residential-warmup (63edc70a-ecc7-4919-a2d9-b2f52bc40a72) — DISABLED
- reddit-telemetry-hourly (8fb6c3c4-4eef-457d-9cd6-8309aca5b12c) — DISABLED
- reddit-upvoted-pattern-miner-6h (aff059cb-9524-4676-bf17-47839392ab82) — DISABLED
- reddit-comment-engagement-report-noauth (d61cc1bc-4f71-4912-8d91-e06c5beb3f5f) — DISABLED
- reddit-upvote-poodpound-comments-daily (db1d4383-7591-47db-a181-048e7d64a2de) — DISABLED
- reddit-residential-warmup-8h (e0bfa920-b465-4b03-87b9-ef103fc28fb3) — DISABLED
- reddit-high-value-comment-daily (e50fd8c7-ca5c-46e0-bff2-1f4dc07f2d8a) — DISABLED
- reddit-smart-review-8h (ea37dcfb-1018-4974-8b26-8d9b45183b84) — DISABLED
- reddit-shotsy-watch-3h (ed2f78c0-962f-4ccd-a8e2-b559566c1d0e) — DISABLED
- reddit-account-health-hourly (fd8cfd24-ade1-4f61-a500-2d9dbd2b0040) — DISABLED

## Immediate hardening applied
- `scripts/reddit_post_comment.sh` now fails if `/api/comment` is non-JSON or if Reddit does not return a valid `t1_...` comment fullname.
- Last enabled Reddit automation (`reddit-opportunity-surface-noauth-4h`) is now disabled to fully pause Reddit automation.
