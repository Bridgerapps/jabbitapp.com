# FAQ structured data (FAQPage) for Jabbit guides

This repo’s SEO guides often contain an on-page FAQ section (e.g. a `<dl class="faq">` with `<dt>` / `<dd>` pairs). When appropriate, we can add **FAQPage structured data** in JSON-LD so search engines can better understand the Q&A content.

## References (primary sources)

- Google Search Central — “Mark up FAQs with structured data” (FAQPage, Question, Answer):
  - https://developers.google.com/search/docs/appearance/structured-data/faqpage
- Schema.org — FAQPage type definition:
  - https://schema.org/FAQPage

## Important constraints (don’t get us in trouble)

From Google’s FAQPage documentation:
- Use FAQPage only when there is **a single, authoritative answer per question** (not user-generated alternatives). (Source: https://developers.google.com/search/docs/appearance/structured-data/faqpage)
- FAQ rich results availability is limited (Google notes it’s for “well-known, authoritative” government- or health-focused sites). This means: add the markup because it helps comprehension, but **don’t assume** it will produce rich results. (Source: https://developers.google.com/search/docs/appearance/structured-data/faqpage)

## Repo automation

We maintain a small script in `scripts/` that can:
1) extract FAQ dt/dd pairs from an HTML file, and
2) generate a JSON-LD `<script type="application/ld+json">…</script>` block.

We also maintain a **batch sync** helper so we don’t forget this step on new pages:
- `scripts/faq-jsonld-sync.py` — scans `jabbitapp.com/` and injects/updates FAQ JSON-LD anywhere a `<dl class="faq">` exists.

### Usage

Print the JSON-LD `<script>` block (copy/paste into HTML):

```bash
python3 scripts/faqpage_jsonld_from_dl.py jabbitapp.com/<page>.html
```

Inject (or update) the JSON-LD `<script>` block in-place (idempotent):

```bash
python3 scripts/faqpage_jsonld_from_dl.py jabbitapp.com/<page>.html --inplace
```

Notes:
- The script targets the first `<dl class="faq">` and generates a Schema.org `FAQPage`.
- In `--inplace` mode it inserts before `</head>` when possible and uses `id="faq-jsonld"` for safe replacement.

Batch sync (recommended):

```bash
# Apply to all pages under jabbitapp.com/
python3 scripts/faq-jsonld-sync.py

# Verify everything is already synced (non-zero exit if drift)
python3 scripts/faq-jsonld-sync.py --check --json
```

## After you edit pages

Run the one-command plumbing + audit pass:

```bash
scripts/site-sync.sh all
```
