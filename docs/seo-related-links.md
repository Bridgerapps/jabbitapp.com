# SEO: Related links (internal linking sync)

Goal: keep internal linking consistent and **idempotent** across the static site pages in `jabbitapp.com/`.

This is part of the conversion funnel tightening:
- informational pages → link to high‑intent conversion pages (ex: injection tracker, dosing schedule)
- ensures new pages don’t become crawl dead‑ends

## Source of truth

- `data/seo/related-links.json`

Each rule targets a specific HTML file and defines a short list of internal links to inject.

## How it works

- Script: `scripts/related-links-sync.py`
- Injects (or updates) a block:

```html
<section id="related-links">
  <h2>Related</h2>
  <ul>
    <li><a href="/glp1-dosing-schedule.html">GLP‑1 dosing schedules (for logging & reminders)</a></li>
  </ul>
</section>
```

Placement order:
1. Before `<div class="source">` if present
2. Else before `</body>`

Idempotency:
- If a `<section id="related-links">` already exists, it is replaced.

## Commands

Dry run (no writes; exits non‑zero if changes needed):

```bash
python3 scripts/related-links-sync.py --check --json
```

Apply (write in-place):

```bash
python3 scripts/related-links-sync.py --json
```

## Reliability check (broken internal links)

- Script: `scripts/internal-link-audit.py`

```bash
python3 scripts/internal-link-audit.py --json
```

This check is wired into `scripts/health-check.sh` and will surface as a blocker if broken internal `.html` links appear.

## One-command workflow

After editing/adding pages, run:

```bash
scripts/site-sync.sh all
```

This will sync the topic tracker + related-links + sitemap, run audits, and refresh `data/status/health.json`.
