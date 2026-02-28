# Runbook: Reddit draft queue (no posting)

Goal: produce a small batch of **high-intent Reddit threads** plus **draft comments** that can be reviewed and posted manually.

This is intentionally **non-automated**: it discovers and drafts, but does not post.

## Command

```bash
bash scripts/reddit-draft-batch.sh
# or
LIMIT=12 bash scripts/reddit-draft-batch.sh
```

## Output

- Markdown queue: `output/reddit-drafts-YYYY-MM-DD.md`
- Raw JSON (for tooling): `output/.reddit-drafts-YYYY-MM-DD.json`

## What it does (in order)

1. Runs `scripts/find_reddit_opportunities_newacct.py` (conservative filters for new accounts)
2. Generates candidate drafts with `scripts/reddit_comment_generator.py` (value gate; avoids explicit medical advice phrasing)
3. Formats the results into a reviewable markdown queue

## Review checklist (before posting)

- Confirm the draft actually matches the post’s intent (the excerpt is included for quick sanity-check)
- Ensure it’s **not medical advice** (keep it to neutral framing, questions, and personal experience if relevant)
- Check subreddit rules for self-promotion; when in doubt, remove any app mention
- Avoid posting multiple comments in the same thread / same sub in a tight time window

## Common failure modes

- **No candidates returned**: either nothing matched filters, or discovery reads are blocked.
- **ERROR: missing .reddit-session**: discovery needs a valid session cookie at `/.reddit-session`.

## Related

- `scripts/reddit_direct_comment_once.sh` (manual, single-comment action script — use only with explicit approval)
- `scripts/reddit-negative-feedback-blacklist.sh` (avoid threads that produced negative feedback)
