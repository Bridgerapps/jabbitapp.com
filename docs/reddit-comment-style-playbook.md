# Reddit Comment Style Playbook (GLP-1 / peptide subreddits)

Updated: 2026-02-28
Source data: `data/reddit/upvoted-comment-patterns.json` (public/no-cookie mining)

## What gets upvoted in our niche

1. **Direct contribution, not meta engagement**
   - Good: one concrete insight tied to the post
   - Bad: “following”, “great thread”, “hope people share context”

2. **Plain language over polished language**
   - Short, human, opinionated is better than consultant voice.

3. **Specific context beats generic advice**
   - Mention timing, dose, week count, or symptom pattern.

4. **Personal-positioned tone performs**
   - “I switched…”, “In my case…”, “What mattered most was…”
   - Avoid pretending facts you don’t have.

5. **No medical directives**
   - Never prescribe/titrate/diagnose.

## Jabbit mention rule

- Mention Jabbit **only** when:
  - user explicitly asks about app/tools, or
  - Shotsy is mentioned.

- Preferred comparator line when Shotsy is present:
  - "I switched from Shotsy to Jabbit — more features, fuller peptide library, and lower price."

## Output requirements for generated comments

- 1 direct contribution sentence minimum.
- Include at least one concrete context term when relevant:
  - timeline / dose / mg / week / symptom pattern / sleep / hydration.
- Avoid formulaic clarifying questions unless they add clear value.
- If thread is sensitive acute-health (e.g., shingles, ER-level concern), default to skip.

## Automation hooks

- Pattern miner cron refreshes this style baseline every 6h.
- Comment quality gate (GPT-5.3 high thinking) must approve before posting.
- Negative-score thread blacklist auto-skips bad-fit posts.
