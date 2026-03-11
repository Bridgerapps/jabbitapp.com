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

- Reddit is a **trust surface**, not an ad slot. Treat mentions like earned relevance, not promotion.
- Mention Jabbit **only** when:
  - user explicitly asks about app/tools, or
  - tracking/logging/adherence is the actual problem being discussed, or
  - Shotsy is mentioned.
- Default ratio: **95% value / 5% plug**.
- If the comment still works after deleting the Jabbit mention, it’s probably safe. If the mention is carrying the whole comment, don’t post it.

- Preferred comparator line when Shotsy is present:
  - "I switched from Shotsy to Jabbit — more features, fuller peptide library, and lower price."

## Output requirements for generated comments

- 1 direct contribution sentence minimum.
- First 1–2 lines must answer the exact question being asked.
- Include at least one concrete context term when relevant:
  - timeline / dose / mg / week / symptom pattern / sleep / hydration.
- Avoid formulaic clarifying questions unless they add clear value.
- If thread is sensitive acute-health (e.g., shingles, ER-level concern), default to skip.
- Comments on existing high-intent threads are the default play. Do not force top-level "viral founder post" behavior unless there is a genuinely strong original post idea.
- Optimize for credibility first, traffic second.
+
+## Search + trust framing
+
+- Reddit works for us in three ways:
+  1. **Trust surface** — people believe lived experience more than polished landing pages.
+  2. **Search surface** — Reddit threads rank, so useful comments can keep paying off.
+  3. **Feedback surface** — threads reveal real objections, wording, and pain points.
+- That means the goal is not "post more." The goal is to place useful comments in the right threads, then learn from what gets replies/upvotes.
+- Prioritize threads with:
+  - specific user pain
+  - active comment velocity
+  - natural fit for tracking / adherence / side-effect logging
+  - low cringe risk for a Jabbit mention

## Automation hooks

- Pattern miner cron refreshes this style baseline every 6h.
- Comment quality gate (GPT-5.3 high thinking) must approve before posting.
- Negative-score thread blacklist auto-skips bad-fit posts.
