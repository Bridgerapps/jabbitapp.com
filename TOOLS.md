# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

## Outbound email guardrails (local)

- **Unsolicited outreach:** requires **Jon approval before sending**.
- **Brand identity:** use **jabbit/jabbitapp.com** identity for outreach. **Do not use bridgerapps.com** for unsolicited outbound.
- **Pre‑flight (release‑blocking):** verify **From name + From email/domain + Reply‑To** and that all links are on intended brand domains.
- Prefer **test send to self** (or tiny canary) before any list send.

## Tool quirks to remember

- `edit` is **exact‑match**: it can fail if the file shifted. After edits, **verify with a read/grep**.
- For large rewrites, prefer `write` (single overwrite) over many fragile `edit` calls.

## Reddit Comment Drafting Rule (Tim)

- Match the **exact question in the post first** before adding broader context.
- First 1-2 lines should directly answer what OP asked.
- Read the post body (not just title) before drafting.
- Review top comments to match conversation context before drafting.
- If commenters are converging on one angle, align with that thread and add value there (don’t pivot to a different topic).
- Avoid generic “blanket” advice when OP asked a narrow question.
- Tone: write like an experienced community member, not a lecturer.
- Prefer conversational paragraphs over list formatting.
- At most one short bullet list when truly useful; otherwise no lists.
- Avoid filler openers (e.g., "Totally fair question") unless they add real value.
- Then add concise personal context only if relevant.
- Keep comments practical and human-sounding.
- If full post/top comments are unavailable, ask for pasted content rather than guessing.
- Never claim a first-person experience unless Tim explicitly gave that fact.
- When uncertain, ask Tim for a detail instead of filling gaps with assumptions/speculation.
- Engagement learning loop: when a top-upvoted comment pattern is observed, extract the tactic and run it by Tim for approval before reusing it.
- Do not default to “ask your provider/doctor” in every health comment; reserve that for serious-risk scenarios.
- For routine questions, prioritize practical self-management suggestions first; mention provider escalation only as a fallback trigger.
- Personal-experience loop: when a draft would benefit from Tim-specific history not yet known, ask Tim targeted follow-up questions and store verified details for future drafts.
