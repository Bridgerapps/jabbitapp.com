# UTM / Referral Conventions (Jabbit Distribution)

Goal: make every outbound link measurable and sortable by **lane → partner → touch**.

## Canonical pattern
`utm_source=<lane>_<partner>`
`utm_medium=<channel>`
`utm_campaign=<yyyymmdd>_<touch>`

### Lanes (utm_source prefix)
- `podcast` — podcast / show notes
- `creator` — creator IG/TikTok/YouTube
- `community` — forums / communities (manual posts)
- `clinic` — clinic/program outreach
- `coach` — coach outreach

### Channels (utm_medium)
- `email`
- `instagram_dm`
- `contact_form`
- `show_notes`
- `bio_link`

### Touch (utm_campaign suffix)
- `t1` — first touch
- `t2` — follow-up #1
- `t3` — follow-up #2

## Example
Podcast email to On The Pen on 2026-03-08 (touch 1):
- `utm_source=podcast_onthepen`
- `utm_medium=email`
- `utm_campaign=20260308_t1`

## Guardrails
- Keep partner slug stable (lowercase, no spaces)
- If a link is reused in multiple places, **duplicate with a new campaign** instead of reusing
