# Growth Experiments Tracker

_Last updated: 2026-02-27_

## Active Experiments

| Experiment | Status | Data | Next Action |
|------------|--------|------|-------------|
| GLP-1 SEO pages (63 pages) | 🟢 Running | 63 pages deployed | Monitor traffic |
| Reddit residential warmup | 🟡 Building | Day 7, karma ~1 | Day 8 starts commenting tomorrow |
| Reddit comment templates | 🟢 Ready | 6 templates created | Start commenting Day 8 |
| Reddit backup script | 🟢 New | Created | Add to cron |
| Twitter posting | 🔴 Blocked | Need API key | **RESOLVED: 2 options**<br>1. API: Get key from twitterapi.io (free credits)<br>2. Browser: Use OpenClaw browser relay | Awaiting setup |

## Twitter Blocker Resolution

**Option 1 - API (recommended for automation):**
```bash
# Sign up at https://twitterapi.io/ (free credits)
export TWITTER_API_KEY="your-key-here"
./scripts/twitter-api-io-post.sh "Hello world"
```

**Option 2 - Browser (no API key needed):**
1. Open Twitter in Chrome
2. Use OpenClaw browser relay to attach the tab
3. Post manually or automate via browser tool

**Once resolved, update:**
```bash
export TWITTER_API_KEY="your-key"
```
| Email outreach | 🟢 Running | 17 customers | Expand to leads |

## Completed/Cancelled

| Experiment | Status | Notes |
|------------|--------|-------|
| Replicate AI features | 🔴 Failed | Token issues, disabled |
| Resend API | 🟢 Fixed | Working since Feb 24 |

## Reddit Warmup Schedule (Day 7 of 30)

- **Day 1-7:** Only upvote (passive engagement)
- **Day 8+:** Can comment on relevant posts
- **Day 14+:** Can mention product naturally
- **Day 21+:** Can share links

Current: Day 7 - upvoting only. ** Tomorrow (Day 8) we can start commenting. **

## What's Working

1. **SEO content** - 62 pages live, Google indexing
2. **Email already working** - 17 paying customers
3. **Site health** - 200 OK, fast

## What Needs Attention

1. **Twitter** - Needs API key from twitterapi.io
2. **Reddit** - Slow karma building (expected, needs time)
3. **Analytics** - Need to verify conversion tracking

## Quick Wins to Try

1. [ ] Start commenting on Reddit (Day 8) - tomorrow!
2. [ ] Test TwitterAPI.io with free credits
3. [ ] A/B test CTA on landing pages
4. [ ] Add more GLP-1 comparison pages

## Metrics to Watch

- Daily site visitors (Vercel analytics)
- Reddit karma (should increase faster after Day 8)
- Email signup rate
- App store downloads (if available)
