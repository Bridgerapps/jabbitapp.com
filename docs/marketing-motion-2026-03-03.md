# Marketing Motion — 2026-03-03

## Hard numbers (today)

### Reddit (daily)
- Total karma: **1**
- New karma today: **0**
- Jabbit mentions today: **0**
- Competitor mentions today: **1**

### App Store (lagged)
- Report date (PT): **2026-03-02** (1-day lag)
- Units: **2**
- Revenue: **$0.00**

### Reddit draft batch
- Candidates generated: **12**
- Draft queue file: `/home/jabbit/.openclaw/workspace/output/reddit-drafts-2026-03-03.md`

### Free marketing tests
- Pass rate: **46/50 (92.0%)**
- Report: `/home/jabbit/.openclaw/workspace/docs/free-marketing-tests-2026-03-03.md`
- Notable fails: **Schema missing** on:
  - `/shotsy-alternative.html`
  - `/glp1-injection-tracker.html`
  - `/guides/`

---

## Notes / interpretation
- **Reddit:** 0 new karma + 0 mentions suggests we’re either not posting yet (expected) or posts aren’t landing. The draft queue exists, but most drafts currently read like *meta advice* (“include timeline/dose context”) rather than directly answering OP.
- **SEO:** `docs/seo-effectiveness-2026-03-03.md` still shows **0 organic visits** over 7d/30d; could be (a) truly no traffic yet, (b) tracking/source attribution not capturing organic, or (c) pages too new (many are in the incubation window).

## Blockers / risks
1. **Schema gaps on key pages** likely reduce SERP eligibility / rich results (low-to-medium impact, easy fix).
2. **Reddit drafts are too generic** to earn upvotes/comments; risk of “non-answer” vibes (high impact on Reddit traction).
3. **Organic visits = 0** could indicate instrumentation/reporting gaps; if measurement is wrong we’ll make bad calls.

## Next 3 actions (next 12 hours)
1. **Upgrade the 12 Reddit drafts** into *direct answers first* (1–2 lines answering the actual question), then optional context + soft mention of tracking only if naturally relevant.
2. **Add/repair schema** on the 3 failing pages (at minimum: WebPage + FAQ/HowTo where appropriate; validate with test script after).
3. **Sanity-check analytics for organic** (confirm GA/GSC tags firing + source/medium reporting) so “0 organic” is trusted.
