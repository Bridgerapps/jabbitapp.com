# Reddit Daily Execution Checklist

Purpose: make Reddit execution too small and concrete to stall.

## Why the previous setup failed

1. **We optimized for safety, then forgot to replace convenience with discipline.**
   - Auth automation was correctly disabled to protect the account.
   - But the manual path never got a hard daily checklist, so execution became optional.

2. **We built opportunity generation and drafting, not a shipping loop.**
   - We had playbooks, review queues, templates, and monitoring.
   - We did not have a strict "post 1 good comment, then log outcome" operating rule.

3. **We let artifacts masquerade as traction.**
   - More docs, more queues, more nudges.
   - Not enough real in-thread actions.

4. **We lacked a closed feedback loop.**
   - No simple daily scorecard: posted? score after 24h? reply? natural Jabbit mention? lesson?

5. **Telemetry went stale, so the system lost honesty.**
   - When visibility is stale, it becomes easier to assume progress instead of verify it.

## Daily rule

- **Default target: 1 manual Reddit comment/day.**
- Quality beats volume. If no thread clears the bar, post **0** and explicitly log why.
- One clean comment on a high-intent thread is better than 5 filler comments.

## The daily loop (10–15 min)

### 1) Find one real thread
Thread must have all of:
- exact user problem is clear
- natural fit for tracking / adherence / side-effect logging / routine management
- active enough to matter (fresh or still receiving replies)
- low cringe risk for product mention

Avoid:
- acute medical-risk threads
- threads where product mention would feel opportunistic
- broad generic threads with no concrete problem

### 2) Read before writing
Before drafting, read:
- post title
- post body
- top comments

Rules:
- answer the exact question first
- match the thread direction
- stay conversational
- harm reduction only; never medical advice

### 3) Draft the comment
Checklist:
- first 1–2 lines answer the real question
- includes at least one concrete detail (timing, dose, week count, symptom pattern, hydration, sleep, routine)
- useful even if the Jabbit mention is deleted
- no clinician voice
- no hard sell

### 4) Decide whether Jabbit belongs
Only mention Jabbit if one of these is true:
- they asked about apps/tools
- tracking/logging/adherence is the real issue
- Shotsy is mentioned

Rule:
- **95% value / 5% plug**
- if the mention carries the whole comment, cut it

### 5) Post manually
- one comment
- no batching
- no automation
- use the **verified endpoint only**, and use it sparingly
- do not do extra auth checks, retries, or side actions unless genuinely needed
- verify the comment is actually live

Auth-path rule:
- treat every authenticated Reddit action as expensive trust-wise
- every part of the Reddit workflow that can run **without auth and without home IP** must run that way
- discovery, reading, thread selection, drafting, scoring, and review should stay unauthenticated whenever possible
- auth posting should be a single deliberate action, not a session full of poking around
- if the verified endpoint is flaky, stop; don’t hammer it

### 6) Log the result immediately (forcing function)
Do **not** leave this ambiguous.

Preferred (safe) path:
- If posted: `scripts/reddit-daily-check-set.sh post --subreddit r/<sub> --thread_url "https://..." --jabbit_mentioned false --why "..." --followup_due_utc "..."`
- If skipping: `scripts/reddit-daily-check-set.sh skip --reason "..." --followup_due_utc "..."`

(These write `data/status/reddit-daily-check.json` so dashboards can surface **posted vs explicit skip** instead of silently implying zero.)

## 24h follow-up

Check once, then log:
- score
- replies
- whether the Jabbit mention felt natural in hindsight
- what pattern to reuse or avoid

## Success criteria

A good day is:
- 1 high-quality manual comment posted and logged

A great day is:
- 1 comment posted
- earns replies/upvotes
- teaches us something about message/fit

## Failure conditions

Treat these as failures:
- creating opportunity docs without posting
- drafting multiple comments without choosing one
- forcing a Jabbit mention into a weak-fit thread
- calling Reddit a strategy when telemetry is stale

## Operator note

Reddit is not a content factory. It is a trust surface.
The win condition is not "more Reddit activity."
The win condition is:
- say something useful
- in the right thread
- from a credible voice
- then learn from the reaction
