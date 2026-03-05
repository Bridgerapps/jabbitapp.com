# Free ad credit activation playbook (Apple Ads $100 new-account promo)

Date: 2026-03-05 (UTC)
Owner: Jon

This is the **exact, boring** setup flow that reliably unlocks the **$100 Apple Ads promo credit** for first-time Apple Ads accounts (when eligible), plus a **strict “first launch” campaign template** designed to keep spend tiny and controlled.

> Source of truth: Apple Ads Help — Promo Credit + Billing docs
> - Promo Credit: https://ads.apple.com/app-store/help/billing/0032-apple-ads-promo-credit
> - Set Payment Method: https://ads.apple.com/app-store/help/get-started/0030-set-your-payment-method
> - Promo Terms: https://ads.apple.com/promo-terms

---

## 0) Eligibility (30 seconds)

You should expect the $100 credit **only if all of these are true**:

- You’re a **developer / registered account holder** on **App Store Connect**.
- You have **at least one app available for sale** on the App Store (in a supported country/region).
- You create an Apple Ads account for **Ads on the App Store** and add a **valid payment method**.
- You **link the Apple Ads top-level account** to App Store Connect.
  - Important: **Linking a campaign group instead of the top-level account won’t apply the credit.**
  - Apple’s own phrasing: find your top-level account by clicking your username in the upper-right corner of any dashboard.

If you’re set to a currency other than USD, Apple converts the $100 credit at their daily rate.

---

## 1) Activation checklist (exact steps + what you should see)

### Step A — Create / access the correct Apple Ads account
1. Go to https://ads.apple.com/ and choose **Ads on the App Store**.
2. Sign in with the Apple ID that should own billing.
3. Confirm you’re in the **correct account context** (top-right username menu).

**Verification (expected):** you can reach a dashboard and open **Account Settings** from the username menu.

---

### Step B — Add a *valid* payment method (this is the trigger)
Apple is explicit: **“You’ll see [the $100 credit] at the top of the Billing page when you add a payment method.”**

1. Click your **account name / username** (top-right) → **Settings**.
2. Go to **Billing** tab → **Payment Method**.
3. Add a valid card.

**Valid payment methods (common US setup):** Visa, Mastercard (including Apple Card), American Express. 

**Do NOT use:** prepaid cards, gift cards (even if Visa/MC/Amex branded), PayPal/Venmo/digital wallets.

**Verification (expected):**
- Billing page shows your card details.
- You should see **a promo credit banner/line at the top of Billing** *if eligible*.

If your card gets declined: Apple may pause campaigns and retry within 48 hours; once authorized, ads become eligible again.

---

### Step C — Link Apple Ads to App Store Connect (top-level account)
This is the most common failure mode.

1. In Apple Ads: open **Account Settings**.
2. Find the setting to **link App Store Connect** (wording may vary).
3. Ensure you’re linking from the **top-level account**, not a campaign group.
   - Quick sanity check: click username (top-right) and confirm you’re at the **highest** account scope.

**Verification (expected):** App Store Connect appears as linked in settings.

---

### Step D — Confirm the credit actually applied (don’t guess)
1. Go to **Account Settings → Billing**.
2. Look for **Promo Credit** section **below your payment method details**.
3. Confirm you see:
   - **“Last applied credit” date** (Apple says this date appears in the Promo Credit section)

**Verification (expected):**
- Promo Credit section shows a date for “last applied credit” (or similar).

---

### Step E — Track remaining balance (invoice math)
Apple does not show a live “remaining credit” counter everywhere.

To check usage:
1. **Account Settings → Billing**
2. **Invoices** section
3. Open an invoice and note **how much promo credit was used**
4. Remaining = initial credit − applied amounts (manual subtraction)

**Verification (expected):** invoice line items show a promo credit amount applied.

---

## 2) Troubleshooting (fast diagnosis)

### “I added my card but don’t see the credit”
Most likely causes:
- Not eligible (no app for sale / not registered account holder on App Store Connect).
- You added a payment method but **did not link App Store Connect**.
- You linked **a campaign group**, not the **top-level account**.

Quick fix order:
1) Confirm app is live (for sale). 2) Confirm ASC link. 3) Confirm you are at top-level account scope. 4) Re-check Billing.

### “Credit exists but spending is charging my card”
Normal if:
- You exceeded the promo credit amount.
- Credit hasn’t applied to that transaction yet.

Apple says: if total cost exceeds credit, you pay the remainder. **You’re not notified when credits are exhausted.**

---

## 3) First launch campaign template (strict + safe)

Goal: turn on a **tiny** campaign to test intent keywords, keep CPA controlled, and avoid accidental broad spend.

### Guardrails (non-negotiable)
- **Daily cap:** $10/day for first 48 hours.
- **Max CPT (tap bid):** start low (e.g., $0.50–$1.50 depending on category). Increase only if impressions are near-zero.
- **One country/region at a time:** start with your #1 market (usually US).
- **Search Match:** OFF for day 1 (prevents surprise query expansion). Add later if you want.
- **No competitor conquesting** in first run.

### Campaign structure (simple + debuggable)
Create **1 campaign** with **2 ad groups**:

**Ad Group 1 — Brand (Exact)**
- Match type: **Exact**
- Keywords:
  - `jabbit`
  - common misspellings
  - `jabbit app`
- Bid: low, but enough to always show.

**Ad Group 2 — High-intent Non-brand (Exact/Phrase)**
- Match types: start with **Exact**, then add **Phrase** for the winners.
- Keyword themes (pick 5–15 to start):
  - “video journal / video diary”
  - “1 second a day video”
  - “daily recap video”
  - “memory recap / daily memories”
  - “family video journal”

### Brand safety / relevance
- Only target keywords where the user intent is clearly aligned with what Jabbit actually does.
- If the product is not a fit for the query, **do not bid**.

### Stop-loss rules (so spend can’t run away)
Check twice per day for first 2 days.

Pause keyword if any of these hit:
- **Spend ≥ $5** with **0 installs** (or whatever your primary conversion is), OR
- **TTR (tap-through rate) < 2%** after ≥ 200 impressions, OR
- **CPT spikes** above your comfort level and you’re not seeing downstream conversion.

Scale only when:
- You have at least **3–5 installs** from a keyword and the CPA is acceptable.

---

## 4) “Under-10-minutes” copy/paste checklist (Jon version)

Paste this into a note and just execute.

```
APPLE ADS $100 CREDIT — 10-MIN CHECKLIST

[ ] 1) Open https://ads.apple.com/ → Ads on the App Store → sign in
[ ] 2) Top-right username menu → confirm you’re at TOP-LEVEL account (not a campaign group)
[ ] 3) Username → Settings → Billing → Payment Method
      - Add VALID card (Visa/MC/Amex). NO prepaid/gift cards/PayPal.
[ ] 4) On Billing page, look for promo credit indicator (top of Billing)
[ ] 5) Link App Store Connect (from TOP-LEVEL account)
[ ] 6) Verify credit applied:
      Settings → Billing → Promo Credit section → confirm “last applied credit” date
[ ] 7) Create FIRST TEST campaign (strict):
      - Daily cap: $10
      - One country: US
      - Search Match: OFF
      - Ad Group A: Brand exact (jabbit, jabbit app)
      - Ad Group B: High-intent non-brand exact (5–15 keywords)
[ ] 8) Set low bids (start ~$0.50–$1.50 CPT)
[ ] 9) Launch
[ ] 10) Twice/day checks for 48h:
       - Pause any keyword with ≥$5 spend and 0 installs
       - Pause if TTR <2% after 200 impressions
       - Don’t add competitors yet

VERIFY BALANCE (optional):
[ ] Settings → Billing → Invoices → open invoice → note promo credit used → subtract from $100
```

---

## 5) Quick reference: what screens/sections you should see

- **Username menu (top-right):** access to **Settings**.
- **Settings → Billing tab:**
  - **Payment Method** section (card details)
  - **Promo Credit** section **below payment method** (shows “last applied credit” date)
  - **Invoices** section (open invoice to see promo credit usage)

---

## 6) Notes (small print worth remembering)

- Promo credit is **one-time**, **non-transferable**, not cash.
- Apple can revoke/modify promos; promos can expire.
- Apple will **not notify** you when credits are exhausted — you must monitor invoices/spend.
