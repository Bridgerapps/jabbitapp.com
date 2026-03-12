# Stale ready_to_send escalation — 2026-03-12

Generated: 2026-03-12T01:08:29Z

## Situation
- ready_to_send has been stuck; oldest item: 2026-03-08T14:00:00Z (~299309s old)
- This loop is now in *send-only* mode until these are advanced (sent/closed).

## What to do (10 minutes)
1) Send the top 3 (use the pack for copy/paste)
   - pack: /home/jabbit/.openclaw/workspace/docs/send-now-pack-latest.txt
   - brief: /home/jabbit/.openclaw/workspace/docs/send-now-brief-latest.md
2) Immediately mark them sent in the ledger (commands below).

## ready_to_send (current)
- id=send-2026-03-08-onthepen-1 | when=2026-03-08T14:00:00Z | email -> dave@onthepen.com | subject=Tiny free GLP‑1 injection log resource for your listeners (non-medical)
- id=send-2026-03-08-glp1tribe-1 | when=2026-03-08T14:10:00Z | email -> hello@glp1tribe.com | subject=Free GLP‑1 routine tracker for your listeners (simple + non-medical)
- id=send-2026-03-08-glp1hub-1 | when=2026-03-08T14:20:00Z | instagram -> @glp1hub | subject=(no subject)
- id=send-2026-03-08-leggday-1 | when=2026-03-08T15:07:12Z | instagram -> @legg_day | subject=(no subject)
- id=send-2026-03-08-chickadee-1 | when=2026-03-08T15:07:12Z | contact_form -> https://chickadeeweightloss.com/contact-me/ | subject=Quick free GLP-1 routine resource for your clients (non-medical)
- id=send-2026-03-08-mynutritionstudio-1 | when=2026-03-08T15:07:12Z | email -> jenny@mynutritionstudio.com | subject=Free take-home injection log resource for GLP-1 clients (non-medical)
- id=send-2026-03-09-plussidez-1 | when=2026-03-09T14:00:00Z | email -> kim@theplussidez.com | subject=Tiny non-medical GLP-1 shot log + reminders your listeners can use

## mark-sent commands (run after you send)
scripts/manual-growth-loop/mark-sendqueue-sent.sh send-2026-03-08-onthepen-1 --yes
scripts/manual-growth-loop/mark-sendqueue-sent.sh send-2026-03-08-glp1tribe-1 --yes
scripts/manual-growth-loop/mark-sendqueue-sent.sh send-2026-03-08-glp1hub-1 --yes
scripts/manual-growth-loop/mark-sendqueue-sent.sh send-2026-03-08-leggday-1 --yes
scripts/manual-growth-loop/mark-sendqueue-sent.sh send-2026-03-08-chickadee-1 --yes
scripts/manual-growth-loop/mark-sendqueue-sent.sh send-2026-03-08-mynutritionstudio-1 --yes
scripts/manual-growth-loop/mark-sendqueue-sent.sh send-2026-03-09-plussidez-1 --yes
