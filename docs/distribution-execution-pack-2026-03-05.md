# Distribution Execution Pack — 2026-03-05 (next 24h)

Goal for the next 24 hours: drive *high-intent* store visits (not vanity traffic) and learn which channels convert.

**Rules of engagement (so we don’t get banned / ignored):**
- Lead with the answer to the question/post prompt. *Tool mention is optional and last.*
- No “check out my app” as the opener.
- One link max per post/comment; prefer linking to a helpful resource page on **jabbitapp.com** that then routes to the stores.
- If a community forbids promo: don’t post; instead comment with zero links and offer to DM details.

---

## Tracking plan (tie every action to app-store click events)

### 1) Use a single redirect endpoint
Create one canonical outbound URL on your site that immediately redirects to the correct store:
- `https://jabbitapp.com/go` (or `/download`)

On that page/endpoint, capture an event **before redirect**:
- Event name: `store_click`
- Properties:
  - `channel` (e.g. `reddit`, `indiehackers`, `yc_wip`, `alternativeto`)
  - `community` (e.g. `r/ADHD`, `IndieHackers`)
  - `post_type` (`comment`, `post`, `directory_listing`)
  - `campaign` (short slug, unique per action below)
  - `content_id` (optional: internal ID, or the permalink)
  - `dest` (`ios`, `android`, `web`)

This gives you channel→store-click attribution even if app stores don’t pass referrers reliably.

### 2) Add store-native campaign parameters (where available)
- **iOS (App Store):** use App Store Connect campaign links so installs can be attributed by campaign (e.g. `?ct=<campaign>&pt=<partner>` or Apple’s campaign link builder values).
- **Android (Google Play):** append `referrer` via `utm_source`, `utm_campaign`, etc. (Play Install Referrer). Example:
  - `https://play.google.com/store/apps/details?id=<id>&referrer=utm_source%3Dreddit%26utm_campaign%3Dg1_r_adhd_comment`

Your `/go` redirect should generate the right store URL based on user agent and pass through campaign fields.

### 3) A simple scoreboard for the next 24h
For each action below, track:
- Views / impressions (if available)
- Clicks: count of `store_click` with matching `campaign`
- Installs: from App Store Connect / Play Console for the same campaign
- Conversion rate: installs ÷ clicks

**Decision rule after 24h:** double down on the top 2 campaigns by *installs per click*, not upvotes.

---

## The 12 actions (do these in priority order)

### 1) Reddit comment: r/ADHD — “How do you stop forgetting tasks / appointments?”
**Why:** massive ongoing pain; high intent for “reminder + habit + planning” tools.
- **Action:** Find a recent (last 24–72h) thread asking *exactly* about forgetting tasks, consistency, or “systems that actually stick.” Leave one thoughtful comment.
- **Campaign:** `g1_r_adhd_comment_forgetting`
- **Link:** only if allowed; otherwise offer to share your setup.

**Draft copy (comment):**
> The thing that helped me most was **reducing the number of places a task can live** and making the “capture step” frictionless.
> 
> Practically: I keep one inbox for *everything*, then I do a 2-minute daily pass where I only decide: (1) do it today, (2) schedule it, or (3) delete it. If the capture step takes more than ~5 seconds, I just won’t do it consistently.
> 
> If you want, I can share the exact flow + prompts I use (it’s basically a “brain-dump → one inbox → small daily sort”).
> 
> (I built a tiny app around this approach; if links are okay here it’s: https://jabbitapp.com/go?channel=reddit&community=r_adhd&campaign=g1_r_adhd_comment_forgetting)

---

### 2) Reddit comment: r/productivity — “Best simple system for tasks that don’t get done?”
**Why:** audience is already shopping for systems.
- **Action:** Reply to a thread where OP is overwhelmed by tools / asks for something simple.
- **Campaign:** `g2_r_productivity_comment_simple`

**Draft copy (comment):**
> If you’re bouncing between apps/systems, the fix usually isn’t a new feature — it’s **one consistent loop**.
> 
> A simple loop that works: capture everything in one place → once per day pick *3 outcomes* → everything else becomes “not today.” Most overwhelm is just an unbounded task list pretending it’s a plan.
> 
> If you tell me what you’re currently using (Notes/Todoist/Trello/etc.) I can suggest a lightweight version that doesn’t require a full rebuild.
> 
> (If you want a pre-baked “capture + daily 3” flow, that’s what we built into Jabbit: https://jabbitapp.com/go?channel=reddit&community=r_productivity&campaign=g2_r_productivity_comment_simple)

---

### 3) Reddit comment: r/iosapps (or r/iOS) — “Looking for a lightweight to-do / reminder app”
**Why:** direct iOS buyers.
- **Action:** Search for “looking for app” threads; answer with criteria + 2–3 options; include Jabbit as one option if rules permit.
- **Campaign:** `g3_r_iosapps_comment_recs`

**Draft copy (comment):**
> If you want *lightweight*, I’d pick based on what you actually need:
> - If it’s mostly **time-based reminders** → Reminders is honestly hard to beat.
> - If you want **quick capture + simple daily plan** → look for something with an “inbox” and minimal setup.
> 
> If you share your main pain (forgetting? planning? too many tasks?), I can recommend the right style.
> 
> If you want to try a minimal “inbox → daily 3” approach, Jabbit is built for that: https://jabbitapp.com/go?channel=reddit&community=r_iosapps&campaign=g3_r_iosapps_comment_recs

---

### 4) Founder community post: Indie Hackers — “What growth channel surprised you for a consumer app?”
**Why:** founders give actionable distribution tactics + credibility.
- **Action:** Post a question thread (not a promo) asking for specific channels that worked and what the hook was.
- **Campaign:** `g4_indiehackers_post_channel_surprises`

**Draft copy (post):**
> For those who’ve grown a small consumer app from ~0 → first few hundred users: **which channel surprised you most**, and what was the *actual hook* that made it work?
> 
> I’m specifically looking for stories like “we tried X, it flopped, then Y unexpectedly worked because ___.”
> 
> Context: we’re testing organic distribution right now and I’m trying to pick 1–2 channels to go deep on instead of spraying links everywhere.

---

### 5) Founder community post: YC WIP / StartupSchool forum — “How are you tracking organic attribution to app-store installs?”
**Why:** gets you both tactics + signals you’re serious; can later follow up with learnings.
- **Action:** Ask for best practice on store attribution + redirect tracking.
- **Campaign:** `g5_yc_wip_post_attribution`

**Draft copy (post):**
> For people doing organic distribution (Reddit / communities / directories): how are you **tying a post → app-store page visit → install** in a way you actually trust?
> 
> Are you using a website redirect with UTMs, App Store Connect campaign links, Play referrer, or something like Branch?
> 
> I’m trying to keep it lightweight (no heavy paid stack) but still be able to answer “which community post drove installs?”

---

### 6) App directory listing: AlternativeTo (and/or similar) — create/claim and publish
**Why:** long-tail intent; evergreen traffic.
- **Action:** Create a clean listing with 5 screenshots, 1-paragraph positioning, and 3 tags.
- **Campaign:** `g6_directory_alternativeto_listing`

**Draft copy (listing description):**
> **Jabbit** is a lightweight task and planning app built around one simple loop: **capture fast → pick today’s outcomes → stop carrying an endless list in your head**.
> 
> It’s for people who want less setup than “full productivity systems,” but still need a reliable way to get tasks out of their brain and into a daily plan.
> 
> Typical use cases:
> - quick brain-dump inbox
> - daily “top outcomes” planning
> - gentle nudges to keep momentum
> 
> Download: https://jabbitapp.com/go?channel=directory&community=alternativeto&campaign=g6_directory_alternativeto_listing

---

## Actions 7–12 (still concrete; no drafted copy needed)

### 7) Reddit: r/getdisciplined — comment on a “can’t stick to routines” thread
- **Action:** Provide one practical routine (2-minute nightly reset + pick 3 for tomorrow). No link unless asked.
- **Campaign:** `g7_r_getdisciplined_comment_routine`

### 8) Reddit: r/Entrepreneur (or r/startups) — comment on “how do you manage tasks as a founder?”
- **Action:** Share a founder-friendly system (single inbox + weekly review). Offer to share template.
- **Campaign:** `g8_r_entrepreneur_comment_founder_tasks`

### 9) Founder community: Indie Hackers — comment on 5 threads where people mention overwhelm / productivity
- **Action:** Leave helpful replies (no link). DM only if invited.
- **Campaign:** `g9_indiehackers_5_comments`

### 10) App directory: Product Hunt “Ship” (or upcoming) page / profile hygiene
- **Action:** Update tagline, first comment, makers, and add clean store links via `/go`.
- **Campaign:** `g10_producthunt_profile_hygiene`

### 11) App directory: SaaSHub (or comparable directory you already appear in)
- **Action:** Ensure consistent positioning, screenshots, and `/go` link with campaign.
- **Campaign:** `g11_directory_saashub_listing`

### 12) Write 1 short “learning follow-up” post in a founder community (24h later)
- **Action:** After executing, post what you learned (which posts got clicks, what messaging worked). This builds trust and future engagement.
- **Campaign:** `g12_followup_learnings`

---

## Execution checklist (fast)

- [ ] Before posting anywhere: read the community rules; confirm promo/link policy.
- [ ] For Reddit: sort by “new”, pick threads <72h old, answer the actual question.
- [ ] Use a unique `campaign` slug for every single link.
- [ ] Log every post/comment URL into a simple sheet with campaign + time.
- [ ] At the end of the day: export store campaign performance and compare to `store_click` counts.

---

## Top 3 actions to do first (highest expected ROI)
1) **r/ADHD comment** (high pain, high engagement; keep it helpful-first)
2) **r/productivity comment** (buyers already “in-market”)
3) **AlternativeTo listing** (evergreen intent + backlink + searchable)
