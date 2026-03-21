# Reddit Manual Distribution Runbook (truthful + drivable)

**Non‑negotiable policy:** authenticated Reddit actions are **manual‑only**.
- Discovery/drafting can be automated.
- Reading the live thread, posting, and verifying results must be done by a human.
- No cookie/session automation, no background posting.

## Hard separation (to avoid bot-ban behavior)
- **Automated / no-auth lane:** opportunity discovery, candidate scoring, draft generation, run-file creation.
- **Manual / auth-adjacent lane:** opening the live thread, reading context, posting in browser/app, copying the final comment permalink, and logging the result.
- Automated jobs must never call cookie-based post/upvote/subscribe scripts.
- Manual posting must never rely on stale cron output; always start from a fresh discover run.

## Why this exists
We had stale opportunity packs + overlapping scripts that looked like they were "posting" but were either:
- operating on old candidate files, or
- attempting cookie-based posting (disallowed), creating confusion and bad attempts.

This runbook is the single operator path.

---

## One clean flow (recommended)

### 1) Discover fresh candidates (creates a run file with an expiry)

```bash
bash scripts/reddit.sh manual discover --limit 8 --expires-min 360
```

Output includes:
- `run_path=.../data/reddit/runs/reddit-<timestamp>-<suffix>.json`
- a numbered list of candidates with URLs

**Rule:** if the run is expired, throw it away and re-run discover.

### 2) Pick exactly one candidate to act on

```bash
bash scripts/reddit.sh manual prepare --run <run_path> --post-id <post_id>
```

This:
- writes `data/reddit/active_candidate.json`
- prints the draft + the manual checklist

### 3) Manual posting (human)

Open the thread URL, read the live context, edit the draft, and post.

### 4) Verify + log outcome (required)

After posting, copy the *final comment permalink* and log it:

```bash
bash scripts/reddit.sh manual log \
  --status posted \
  --comment-url 'https://www.reddit.com/r/<sub>/comments/<postid>/<slug>/<commentid>/' \
  --final-text '...paste what you actually posted...'
```

If you decide not to post:

```bash
bash scripts/reddit.sh manual log --status aborted --note 'why'
```

Logging writes to:
- `data/reddit/manual-actions-ledger.jsonl`

---

## Guardrails / failure modes this prevents

- **Stale packs:** every run has `expires_at_utc`; `prepare` and `log` refuse expired runs.
- **Ambiguous posting:** no script in this path posts on your behalf.
- **Mismatched metadata:** logging is tied to the currently prepared candidate.
- **Fake success:** `log --status posted` performs a best-effort unauthenticated URL resolve check.

---

## What NOT to use

These are disabled by policy and will error:
- `scripts/reddit_post_comment.sh`
- `scripts/reddit_direct_comment_once.sh`
- `python3 scripts/reddit_smart_review_post.py --post`

Use `bash scripts/reddit.sh help` to see supported commands.
