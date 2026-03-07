# Apple Search Ads: $100 Promo Credit + First Hard‑Capped Campaign (Jabbit)

Owner: Jon  
Last updated: 2026-03-05  
Scope: **Apple Search Ads (App Store)** only.

This is a **do-this-exactly** runbook to:
1) make sure the **$100 Apple Ads promo credit** is actually applied, and
2) launch a **first campaign that cannot run away** (hard caps + kill-switch rules), and
3) optimize the first 72 hours without overthinking.

> Notes / reality checks
> - Apple’s UI labels change. The concepts below are stable even if buttons move.
> - Apple’s promo credit is typically **auto-granted for new accounts** and shows on the **Billing** page after you add a payment method. If you don’t see it, stop and do not spend real money until you confirm.

---

## 0) Prereqs (2 minutes)

- You can log into **Apple Ads** with the Apple ID that has permission to advertise the Jabbit app.
- You have:
  - App Store app link (for reference): https://apps.apple.com/app/id6756848719
  - A credit card ready to add (required even if you intend to only spend the credit).

---

## 1) Claim / verify the $100 promo credit (must-do before launch)

1) Go to Apple Ads:
   - https://searchads.apple.com/  (or the current Apple Ads login for App Store ads)
2) Create / finish setting up the Apple Ads account (if it’s the first time).
3) Navigate to **Account Settings → Billing** (wording varies).
4) **Add payment method** (credit card + billing address).
5) On the Billing page, look for **Promotional Credit / Credit / Promo** banner.
   - Expected: you see a line item or banner indicating **$100 promotional credit** (or equivalent in your region).
6) If you do **not** see promo credit:
   - Do **not** launch campaigns.
   - Try:
     - refresh / log out/in
     - confirm you’re in the correct Apple Ads account (some people accidentally create multiple)
     - confirm the app is selectable in Apple Ads
   - If still missing: open Apple Ads support chat/ticket and ask specifically: “New Apple Ads account promo credit not appearing after adding payment method. Can you confirm eligibility and apply?”

**Definition of “claimed”** in this runbook: credit is visible on Billing and your upcoming spend will draw down the promo balance.

---

## 2) Campaign strategy: one tiny, controlled Search Results campaign

We’re doing **Search Results** only (high intent, simplest). No Search Tab / Today tab / Product Pages / Display expansions.

### Targeting approach (simple)
- 1 campaign (US)
- 2 ad groups:
  1) **Brand** (protects “Jabbit” + misspellings)
  2) **Non‑brand High Intent** (tight exact/phrase keywords only)

---

## 3) Create the campaign (exact setup fields)

In Apple Ads, click **Create Campaign**.

### Campaign level
- **Campaign name:** `Jabbit | Search Results | US | Credit Test`
- **Ad placement:** Search Results
- **Countries/Regions:** United States (start with one market)
- **Daily budget:** **$5/day** (hard cap)
  - If you want even safer: start at **$3/day** for first 24h.
- **Start date:** today
- **End date:** optional; if available set **End date = +21 days** (extra guardrail)

### Optional but recommended controls (if present)
- **Search Match:** OFF (at least for the first 72h)
  - Rationale: prevents Apple from expanding to loosely related queries.
- **Audience / Demographics:** leave default (don’t over-filter on day 1)
- **Dayparting / Ad schedule:** if available, run 24/7 initially (budget is tiny anyway)

---

## 4) Ad groups + keywords (seed list)

### Ad Group 1: Brand
- **Ad group name:** `Brand | Exact`
- **Default CPT bid:** **$0.50**
  - If you see “Suggested bid” much higher, still start low. We’re testing cheaply.
- **Keywords (Match type: Exact unless noted):**
  - `jabbit`
  - `jabbit app`
  - `jabbit peptide tracker`
  - Common misspells (add if you know them)

**Brand negatives:** none.

---

### Ad Group 2: Non‑brand High Intent
- **Ad group name:** `Nonbrand | Tight`
- **Default CPT bid:** **$0.60** (start)
- **Keyword match types:** mostly **Exact**, a few **Phrase**.

#### Seed keywords (copy/paste list)
**GLP‑1 intent (Exact):**
- `glp 1 tracker`
- `glp-1 tracker`
- `semaglutide tracker`
- `tirzepatide tracker`
- `wegovy tracker`
- `ozempic tracker`
- `mounjaro tracker`
- `zepbound tracker`
- `shot tracker`
- `injection tracker`

**Workflow intent (Exact):**
- `injection site rotation`
- `shot reminder`
- `injection reminder`
- `medication reminder` (optional; can be broad—monitor)
- `vial tracker`

**Peptide / protocol intent (Exact):**
- `peptide tracker`
- `peptide app`
- `peptide library`
- `reconstitution calculator` (optional; monitor)

**Phrase match (use sparingly):**
- `"peptide tracker"`
- `"injection tracker"`
- `"shot tracker"`

> Keep it small. The goal is not coverage—it’s controlled learning.

---

## 5) Negative keywords (do this immediately)

Add these as **Campaign-level negative keywords** (Exact or Phrase) to reduce junk.

### Obvious free/low-intent
- `free`
- `pdf`
- `template`
- `printable`
- `worksheet`

### Jobs / careers / unrelated
- `salary`
- `jobs`
- `career`

### Pharmacy / purchasing intent we don’t want to pay for (adjust as you learn)
- `coupon`
- `discount`
- `buy`
- `order`
- `online pharmacy`

### Adult / unsafe adjacency (cheap insurance)
- `steroids`
- `testosterone`

> If Apple Ads requires match type formatting, use Phrase negatives for multi-word terms (e.g., "online pharmacy").

---

## 6) “Zero runaway spend guardrails” (non-negotiable)

These are explicit limits to ensure we **cannot** accidentally burn real money.

1) **Daily budget hard cap:** $5/day (campaign level)
2) **Bid hard cap:**
   - Brand: max **$0.75 CPT**
   - Nonbrand: max **$1.25 CPT**
3) **No Search Match** for first 72h.
4) **One country only** (US).
5) **One campaign only** until metrics look sane.
6) **Billing guardrail:**
   - Confirm promo credit is present **before enabling**.
   - If promo credit is not present, campaign stays **Paused**.
7) **Stop conditions (kill switch):**
   - Any day spend > **$7** (shouldn’t happen with $5/day; if it does, pause immediately and investigate)
   - CPI (cost per install) > **$8** after **10+ taps** with **0 trials/subs** (proxy for irrelevant traffic)
   - Any obvious irrelevant query pattern you can’t negative out quickly
8) **Calendar reminder:** set a reminder for **24h after launch** to check spend + search terms.

---

## 7) Launch checklist (the actual clicks)

1) Ensure campaign is **Paused** while you finish keywords + negatives.
2) Verify:
   - Daily budget = $5
   - Search Match = OFF
   - Only two ad groups (Brand + Nonbrand)
   - Negatives added at campaign level
3) Enable campaign: switch to **Active**.
4) Screenshot or note:
   - promo credit balance
   - campaign daily budget
   - default bids

---

## 8) First 72 hours optimization loop (15 minutes/day)

### Timing
- Check at ~24h, ~48h, ~72h.

### What to look at
- Spend (should be <= $5/day)
- Taps
- Installs
- Search terms (query report)
- CPT by keyword

### Day 1 (after 24h)
1) Pull **Search Terms / Search Query** report.
2) Add negatives for irrelevant queries (campaign-level).
3) If you have **0 impressions**:
   - Increase Nonbrand bid from $0.60 → **$0.80** (still capped)
   - Or loosen 1–2 keywords to Phrase match.
4) If you have impressions/taps but no installs:
   - Don’t panic. First make sure search terms are relevant.

### Day 2 (after 48h)
1) Identify keywords with:
   - high taps, no installs → **lower bid 20%** or pause
   - installs at reasonable CPT → **keep**
2) Expand carefully (max 5 new keywords):
   - Add only queries you saw that are clearly relevant.

### Day 3 (after 72h)
1) Decide: keep / iterate / stop.
2) If you have at least a few installs:
   - Split Nonbrand into 2 ad groups:
     - GLP‑1 specific
     - Peptide/workflow
   - Keep total daily budget at $5 until you see trial/sub conversion.

---

## 9) 5‑minute quick checklist (Jon can do this fast)

- [ ] Login to Apple Ads → Billing: confirm **$100 promo credit visible**
- [ ] Create campaign: `Jabbit | Search Results | US | Credit Test`
- [ ] Set **Daily budget = $5/day**, **Search Match = OFF**
- [ ] Create 2 ad groups: **Brand** (bid $0.50) + **Nonbrand** (bid $0.60)
- [ ] Paste keyword seeds (keep tight) + add campaign negative keywords
- [ ] Confirm stop conditions + set a **24h reminder**
- [ ] Activate campaign + screenshot promo credit + budget

---

## Appendix: Keyword seed list (one block)

Use this if Apple Ads supports bulk entry.

**Exact:**
- jabbit
- jabbit app
- jabbit peptide tracker
- glp 1 tracker
- glp-1 tracker
- semaglutide tracker
- tirzepatide tracker
- wegovy tracker
- ozempic tracker
- mounjaro tracker
- zepbound tracker
- shot tracker
- injection tracker
- injection site rotation
- shot reminder
- injection reminder
- vial tracker
- peptide tracker
- peptide app
- peptide library

**Phrase (optional):**
- "peptide tracker"
- "injection tracker"
- "shot tracker"
