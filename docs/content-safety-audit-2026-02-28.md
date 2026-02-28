# Content Safety Audit — 2026-02-28

Scope: All top-level `*.html` content pages in `jabbitapp.com/` **excluding `index.html`**.

Audit goals:
- Remove/soften directive medical language (e.g., “must/should/stop/take/inject/dose”) where it could be read as personal medical advice.
- Reduce/repair strong quantitative/regulatory claims that lack nearby citations/links.
- Normalize a brief disclaimer where missing: **informational only + consult a healthcare professional**.

## Files reviewed (18)

Top-level HTML pages reviewed:
- `bpc-157-complete-guide.html`
- `compounded-tirzepatide-guide.html`
- `glp-1-injection-tracking-guide.html`
- `glp-1-side-effects-guide.html`
- `glp1-alcohol-guide.html`
- `glp1-cost-without-insurance.html`
- `glp1-fatigue-guide.html`
- `glp1-kidney-health-guide.html`
- `glp1-serum-levels-explained.html`
- `glp1-stress-anxiety-hrv-guide.html`
- `glp1-stress-hrv-guide.html`
- `injection-site-rotation-science.html`
- `peptide-reconstitution-guide.html`
- `peptide-site-rotation-guide.html`
- `peptide-storage-stability-guide.html`
- `semaglutide-half-life.html`
- `semaglutide-vs-tirzepatide.html`
- `tb-500-thymosin-beta-guide.html`

## Files changed (10)

### 1) `compounded-tirzepatide-guide.html`
**Issues found**
- Disclaimer language present but not in consistent “informational only / not medical advice” form.
- Strong regulatory/legal claim about 503B compounding without a citation link.
- Imperative phrasing (“must ask”, “should send you running”).
- Minor HTML typos (`</h3e>`, stray characters) that could break rendering.

**Fixes applied**
- Normalized disclaimer text to: informational only + consult licensed professional.
- Added an explicit FDA link for the **503B Bulks List**.
- Softened headings/phrasing (“Seven Questions to Ask”, “Red Flags Worth Taking Seriously”).
- Fixed the malformed `h3` tag and typoed closing tag.

### 2) `glp-1-injection-tracking-guide.html`
**Issues found**
- Missing explicit “not medical advice” disclaimer.
- Strong quantitative claims (e.g., % improvements) without source links.

**Fixes applied**
- Added a short top-of-article disclaimer (informational only / consult clinician).
- Rewrote strong numeric/“single strongest predictor” claims to **association/possibility** language without exact numbers.

### 3) `glp-1-side-effects-guide.html`
**Issues found**
- Missing explicit “not medical advice” disclaimer.
- Several precise percentages/timelines (trial %s, week-by-week peaks, pancreatitis incidence) without source links.
- Some directive language (“Stop eating…”, “Call your doctor if…”).

**Fixes applied**
- Added a short top-of-article disclaimer.
- Replaced precise trial percentages/timelines with safer general phrasing.
- Softened directives to “one approach…”, “consider contacting a clinician…”.

### 4) `glp1-cost-without-insurance.html`
**Issues found**
- Missing explicit “not medical advice” disclaimer.
- Uncited coverage denial statistic (“Over 72%…”).
- Overconfident statement about compounded products having “the same active ingredients”.

**Fixes applied**
- Added an informational-only disclaimer near the top.
- Replaced the hard denial statistic with “many plans…” language.
- Softened compounded-ingredient claim to acknowledge variability and the need for verification.

### 5) `glp1-kidney-health-guide.html`
**Issues found**
- FDA-approval banner claim lacked an inline source link.
- “Proven cardiovascular protection” phrasing was too absolute.
- Disclaimer wasn’t in consistent “informational only / not medical advice” form.

**Fixes applied**
- Added a brief informational-only disclaimer under the subtitle.
- Updated the banner to link to a **JAMA** summary of the FDA indication expansion.
- Softened “proven” → “shown in multiple studies for some GLP-1s”.

### 6) `glp1-stress-anxiety-hrv-guide.html`
**Issues found**
- Direct medication directive: “Don’t stop medication without talking to your prescriber…”

**Fixes applied**
- Softened to “If you’re considering stopping… it’s generally safest to talk with your prescriber first…”.

### 7) `injection-site-rotation-science.html`
**Issues found**
- Multiple specific numeric outcomes (25–50%, 60%, 40%) presented without citation links.

**Fixes applied**
- Replaced exact numbers with qualitative, uncertainty-safe phrasing (“substantial proportion”, “meaningfully lower”, “lower rates”).

### 8) `peptide-reconstitution-guide.html`
**Issues found**
- Missing explicit “not medical advice” disclaimer.
- “Standard dosing protocol” language + dose numbers could be read as prescribing.
- Several hard-storage timeline statements (e.g., “28 days…”) stated as universal.
- Strong imperatives around use/discard.

**Fixes applied**
- Added a short top-of-article disclaimer.
- Reframed dosing as **hypothetical math examples** and removed “standard” phrasing.
- Replaced universal storage timelines with “follow pharmacy label/manufacturer instructions”.
- Softened “do not use” language to “treat as safety concern / contact pharmacy/clinician”.

### 9) `peptide-site-rotation-guide.html`
**Issues found**
- Missing explicit “not medical advice” disclaimer.
- Directive rotation instructions (“Start at Zone 1…”, “don’t inject…”).

**Fixes applied**
- Added a short top-of-article disclaimer.
- Softened the key directive lines to “one simple scheme is…” / “try not to…”.

### 10) `semaglutide-half-life.html`
**Issues found**
- Missing explicit “not medical advice” disclaimer.
- Precise “serum levels decline by 50%” phrasing reads overly certain.
- FDA-label references without a link.

**Fixes applied**
- Added a short top-of-article disclaimer.
- Reframed “50%” as a simplified half-life model approximation.
- Added a **Drugs@FDA** link for Ozempic prescribing info context.

### 11) `semaglutide-vs-tirzepatide.html`
**Issues found**
- Missing explicit “not medical advice” disclaimer.
- Many quantitative trial % claims without source links.
- Some strong retrospective/real-world numeric claims without a link.

**Fixes applied**
- Added a short top-of-article disclaimer.
- Added source links to primary trials (STEP 1 / SURMOUNT-1) near the “Let’s talk numbers” section.
- Softened uncited real-world/switching numeric claims to uncertainty-safe phrasing.

## Notes
- No new citations were fabricated. Where a strong numeric/regulatory claim lacked a reliable in-page source, it was either linked to an external primary/summary source or rewritten to remove hard numbers.
- Changes were intentionally minimal/surgical to preserve SEO intent and readability.
