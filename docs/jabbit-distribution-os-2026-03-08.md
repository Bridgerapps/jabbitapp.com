# Jabbit Distribution OS

_Date: 2026-03-08_

## Goal

Build a distribution machine that repeatedly:
1. finds real demand surfaces
2. packages Jabbit-native messages for each surface
3. measures response quality
4. reallocates effort toward what moves installs/subscriptions

This is **beyond SEO**. SEO is one endpoint, not the operating system.

---

## North Star

**Primary KPI:** paid installs / subscriptions

## Steering Metrics

Use these to make weekly allocation decisions before subscription data fully settles:
- App Store click-throughs from owned/controlled surfaces
- Landing page conversion rate to store click
- Branded search lift
- Community engagement quality (replies/saves/profile visits)
- Partner response rate
- Content hold/CTR/share rate on feed channels
- Install proxy events by endpoint/theme/hook

## Anti-Vanity Rule

Do not optimize for impressions alone.
Every asset should have:
- endpoint
- audience
- theme
- hook
- CTA
- metric
- next review date

---

# 1. Distribution Endpoints

## A. Search Capture
**Job:** capture active demand close to install

**Surfaces**
- Google organic
- App Store search/browse support pages
- AI answer surfaces over time
- YouTube search
- Reddit internal search
- comparison/review surfaces

**Best assets**
- comparison pages
- best-X pages
- use-case pages
- calculators/tools
- FAQ/problem-resolution pages

**Primary metric**
- store click rate
- install proxy rate

**Why it matters**
High intent. Users are already solution-seeking.

---

## B. Community Response
**Job:** capture + learn from real user pain inside trusted conversations

**Surfaces**
- Reddit
- disease/condition communities
- Facebook groups
- Discord/Slack communities
- niche forums

**Best assets**
- direct answers
- workflow screenshots
- checklists/templates
- comparison comments
- natural product mentions only when native to the thread

**Primary metric**
- engagement quality
- attributed clicks where possible
- branded search lift
- theme resonance

**Why it matters**
High trust and high learning density.

**Rule**
Manual/authenticated execution only for Reddit.

---

## C. Feed / Awareness Engine
**Job:** create demand and category awareness

**Surfaces**
- TikTok
- Instagram Reels
- YouTube Shorts
- X

**Best assets**
- workflow demos
- mistakes content
- before/after tracking systems
- strong opinion hooks
- “notes app is the wrong tool” style frames

**Primary metric**
- hold rate
- saves/shares
- profile visits
- click-throughs

**Why it matters**
Fastest path to awareness outside search/community.

---

## D. Partnership Distribution
**Job:** borrow trust and reach

**Surfaces**
- creators
- clinics
- coaches
- newsletters
- podcasts
- reviewer ecosystems

**Best assets**
- partner landing pages
- co-branded checklists
- creator kits
- partner demos
- referral links

**Primary metric**
- response rate
- placements
- partner-sourced installs

**Why it matters**
Potential step-function growth vs purely linear grind.

---

## E. Product-Led Distribution
**Job:** turn current users into acquisition nodes

**Surfaces**
- invite/share flows
- exports
- accountability workflows
- coach/provider handoffs
- shareable progress/checklists

**Best assets/features**
- invite flows
- shared logs/routines
- progress snapshots
- onboarding prompts to refer/share

**Primary metric**
- share rate
- invite rate
- installs per share
- retention of referred users

**Why it matters**
Best long-term compounding if product hooks are real.

---

# 2. Source-of-Truth Insight Backlog

All channels should draw from the same source insight pool.

## Inputs
- Reddit questions
- competitor reviews
- own reviews
- support issues
- search console queries
- landing-page dropoffs
- creator comments
- onboarding confusion
- partner feedback

## Theme taxonomy
Each captured insight should be tagged with:
- audience segment
- user moment
- problem type
- emotional driver
- current workaround
- endpoint fit
- install proximity

## Initial Jabbit theme buckets
1. forgetting dose timing
2. tracking in scattered notes/apps
3. side-effect logging confusion
4. dose change uncertainty
5. wanting accountability/consistency
6. travel/routine disruption
7. wanting a cleaner system than spreadsheets
8. starting GLP-1 and not knowing what to track

---

# 3. Content Pipeline

## Pipeline model
**One insight -> many endpoint-native assets**

Example theme: “Notes app breaks down fast for GLP-1 tracking”

Outputs:
- comparison page: Jabbit vs Notes
- Reddit response angle
- TikTok/Reel script
- X post/thread variant
- App Store screenshot copy concept
- creator talking point
- onboarding copy emphasis
- partner checklist lead magnet

## Pipeline stages
1. collect signal
2. distill theme
3. generate asset bundle
4. deploy by endpoint
5. review performance
6. update playbook/taxonomy

## Channel-native rule
Do not copy/paste the same content everywhere.
Each endpoint needs native packaging.

---

# 4. Asset Taxonomy

Every asset gets a compact ID row.

Suggested fields:
- asset_id
- date
- endpoint
- audience
- theme
- hook_type
- CTA_type
- owner
- status (draft/live/reviewed/killed)
- primary metric
- secondary metric
- notes

Example:
- `2026-03-08-reddit-notes-vs-tracker-01`
- endpoint: community
- theme: scattered tracking
- hook: “notes app fails after week 2”
- CTA: soft mention
- metric: reply depth / profile clicks

---

# 5. Weekly Operating Cadence

## Monday: insight + allocation
Review:
- installs/subscriptions
- install proxies
- landing page stats
- community wins/losses
- outreach results
- feed content metrics

Output:
- top 3 themes of the week
- top 2 endpoints to push harder
- 1 endpoint to deprioritize
- 10-20 asset briefs

## Tuesday-Thursday: production + deployment
Ship:
- BOFU pages
- community responses
- short-form tests
- partner outreach
- instrumentation fixes

## Daily: quick review
Questions:
- what got engagement?
- what got clicks?
- what got installs or install proxies?
- what theme is outperforming?
- what should be killed now instead of next week?

## Friday: synthesis
Produce:
- do more
- stop
- test next
- channel allocation changes

---

# 6. 30-Day Execution Plan

## Week 1: control system
- define endpoint taxonomy
- define asset taxonomy
- create scorecard
- identify top 3 themes
- normalize UTM/source/link naming
- map current pages/content to endpoint/theme gaps

## Week 2: core lane launch
Launch 3 lanes:
1. BOFU comparison pages
2. community response engine
3. feed proof engine

Shippables:
- 3-5 comparison/use-case pages
- daily community opportunity queue
- 10-15 short-form concepts, 3-5 shipped

## Week 3: partner lane
- build partner kit
- build co-branded LP template
- prepare creator demo pack
- send first serious outreach batch

## Week 4: prune + intensify
- cut weak hooks
- double down on top 2 performing themes
- add second-round experiments around winning endpoints
- decide next product-led distribution experiment

---

# 7. ACP / Claude Code Worker Structure

## Worker 1 — Insight Miner
Owns:
- question/review mining
- theme extraction
- weekly insight memo

## Worker 2 — Search/CRO Builder
Owns:
- comparison pages
- use-case LPs
- CTA tests
- instrumentation improvements

## Worker 3 — Feed Content Producer
Owns:
- script backlog
- hook variations
- creator-ready clips/briefs

## Worker 4 — Community Operator Support
Owns:
- opportunity queue
- draft responses
- mention/no-mention guidance
- resonance tracking

## Worker 5 — Analytics / Attribution
Owns:
- scorecards
- tagging rules
- install proxy reporting
- weekly “do more/stop/test next”

## Worker 6 — Partner Ops
Owns:
- target list
- outreach packages
- partner landing pages
- attribution links

---

# 8. Decision Rules

## Double down when:
- endpoint shows strong install proximity and fast learning
- hook repeats across multiple assets
- partner/channel response is meaningfully above baseline

## Kill when:
- repeated weak CTR/engagement/conversion after 2-3 serious attempts
- channel requires too much manual effort for too little signal
- message gets attention but no install movement

## Watch-outs
- vanity metrics
- repeating the same outreach pack forever
- treating “content” as a blob instead of endpoint-native assets
- creating too many lanes at once

---

# 9. What Jon Can Do Best

These are the highest-leverage human contributions.

## A. Distribution taste / channel selection
You should make the call on:
- which 2-3 endpoints deserve the most force this week
- which angles feel native vs cringe
- what is worth publicly attaching your name to

## B. Voice + truth source
You are best positioned to provide:
- founder opinions
- product convictions
- blunt takes on what alternatives get wrong
- customer language that is real, not AI-smoothed

## C. Human-network leverage
You should personally do or approve:
- creator/partner relationship intros
- podcast/newsletter outreach where founder identity matters
- any cold/warm outreach that benefits from status/trust

## D. Fast reaction to signal
When we see a strong signal, the best thing you can do is:
- push more weight behind it immediately
- record why it seemed to work
- help sharpen the claim/hook/offer

## E. Product truth
You should keep answering:
- what Jabbit actually does best
- what users love most
- what we should *not* promise

---

# 10. Immediate Next Moves

1. Stand up a working scorecard doc/table with endpoint + theme + metric.
2. Create the first 20-item insight backlog from reviews/questions/community/search data.
3. Prioritize 3 lanes only for this cycle:
   - BOFU/comparison
   - community response
   - feed proof engine
4. Build a partner kit skeleton in parallel.
5. Review every Friday with: **do more / stop / test next**.

---

# 11. Blunt Summary

We do not just need more content.
We need a system that turns user pain into endpoint-native assets, routes them into real distribution surfaces, and reallocates effort based on install-linked feedback.

That is the job now.
