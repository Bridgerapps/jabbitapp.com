# Distribution Pack (human-reviewable snippets)

Goal: turn an on-disk HTML page into ready-to-copy drafts for distribution **without posting automatically**.

## Generate for one page

```bash
cd /home/jabbit/.openclaw/workspace
python3 scripts/distribution-pack.py --file wegovy-injection-tracker.html
```

Output goes to:

- `output/distribution-pack-YYYY-MM-DD-<slug>.md`

## Generate for the injection-tracker set

```bash
cd /home/jabbit/.openclaw/workspace
bash scripts/generate-distribution-packs.sh
```

## Safety / guardrails

- Output is *draft text* only. No posting.
- Snippets reuse `<title>`, meta description, and first `<h1>` verbatim from the HTML to avoid inventing claims.
- When using Reddit drafts, follow each subreddit’s self-promo rules and avoid medical advice.
- Reddit manual workflow runbook: `docs/reddit-manual-distribution-runbook.md`.
