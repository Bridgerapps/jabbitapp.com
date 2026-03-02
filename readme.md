# Reddit/Auth + Growth Automation README

## Purpose

This setup balances:
1. Protecting Reddit accounts from bot-like auth patterns
2. Keeping opportunity discovery running
3. Preserving growth execution (Reddit + X + SEO + reporting)

---

## Current Reddit Mode (Safe Mode)

- **Automated Reddit discovery:** ON (no-auth only)
- **Automated Reddit posting/upvoting:** OFF
- **Manual posting:** ON (human-in-the-loop)

Why: prior restrictions were likely caused by aggregate authenticated activity over time.

---

## Account + Auth Identity

- Active runtime Reddit username: `longevitymax`
- Session cookie path: `/home/jabbit/.openclaw/workspace/.reddit-session`
- Runtime config: `/home/jabbit/.openclaw/workspace/scripts/reddit.env`

Current state: username/cookie mismatch has been fixed.

---

## Proxy Split (Critical)

Configured in `/home/jabbit/.openclaw/workspace/scripts/proxy.env`:

- Discovery proxy user: `jxrtqjko-US-5`
- Auth proxy user: `jxrtqjko-US-4`

Discovery and auth traffic must remain split.

---

## Discovery Guardrails

Automated discovery jobs should enforce:

- `REDDIT_DISCOVERY_USE_COOKIE=false`
- `REDDIT_DISCOVERY_COOKIE_FALLBACK=false`

This prevents silent fallback into authenticated cookie reads.

---

## Reddit Jobs

### Enabled

1. **reddit-opportunity-surface-noauth-4h**
   - no-auth discovery/review only
   - no posting
   - jittered timing

2. **reddit-comment-engagement-report-noauth**
   - no-auth engagement tracking for `u/PoodPound`
   - tracks recent comments window (last 96h)
   - announces only when score changes are detected

### Disabled (auth risk / posting loops)

- reddit-account-health-hourly
- reddit-smart-review-8h
- reddit-daily-metrics-summary
- reddit-direct-comment-8h
- reddit-residential-warmup
- reddit-high-value-comment-daily
- reddit-shotsy-watch-3h
- reddit-upvoted-pattern-miner-6h
- reddit-upvote-poodpound-comments-daily

---

## PoodPound Workflow

- Posting: manual
- Drafting: assistant-generated, context-checked
- Engagement tracking: automated no-auth
- Auto-upvoting: disabled (requires authenticated `/api/vote`)

---

## Reddit Comment Quality Rules (Active)

- Read post body + top comments first
- Answer OP’s exact question in first 1–2 lines
- Match thread direction; don’t pivot away
- Conversational tone (experienced member, not lecturer)
- Avoid filler openers
- No made-up personal details
- Ask Tim for missing personal context before using first-person claims
- Target ~1–2 natural Jabbit mentions/day (never forced)

---

## Opportunity Strategy

Use two filters together:

1. **Visibility filter:** medium-karma + high-comment posts
2. **Jabbit-fit filter:** threads where tracking/dosing/adherence/side-effect workflow is naturally relevant

Skip high-engagement threads that are off-strategy for Jabbit.

---

## Late API Clarification

- Late API is useful for X/Twitter workflows
- It is not a replacement for Reddit no-auth reading/discovery
- It does not eliminate Reddit trust/rate-limit constraints

---

## Recovery Checklist (if auth risk reappears)

1. Disable all Reddit auth jobs immediately
2. Verify `REDDIT_USERNAME` matches cookie account
3. Enforce no-cookie/no-fallback discovery
4. Pause automated Reddit posting/upvoting
5. Continue with manual posting + no-auth tracking only

---

## Notes

This README reflects the current conservative operating posture after account-restriction signals. Keep behavior human-paced and avoid re-enabling multiple auth automations at once.
