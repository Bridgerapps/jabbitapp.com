# MEMORY.md — Long‑Term Operator Memory

Curated, durable rules + facts. Keep it tight.

## People
- **Jon** (primary) — high agency; wants execution over discussion; hates permission‑seeking and corporate filler; values honesty about uncertainty.
- **Tim** (co‑founder) — used for Reddit voice/personal context (only what’s verified).

## Non‑negotiables (hard rules)
- **No secrets leakage:** never exfiltrate private data; never commit secrets.
- **Reality > tool output:** after any credential/config/edit fix, verify with a live run / end‑to‑end test.
- **Execute‑first default:** routine internal fixes = do it, then report. Ask only for true blockers or high‑risk actions.
- **External sends are gated:** anything that leaves the machine (email/post/DM) needs explicit intent/approval and pre‑flight checks.
- **Outbound identity is release‑blocking (2026‑03‑16):** for any send, explicitly verify **From name + From email/domain + Reply‑To** and that **all links** point to the intended brand domains. Never trust inherited defaults. Prefer a **test send to self/canary** first.
- **Unsolicited email policy (2026‑03‑13):** unsolicited outreach requires **Jon approval before send**. Use **jabbit/jabbitapp.com** identity for outreach; **do not use bridgerapps.com** for unsolicited outbound (support/operational only).
- **Compounding-work rule (2026-04-11):** if Jon asks for a type of work that is likely to recur, prototype it manually on 3-10 real items, review output with him, then codify it into one MECE owner skill in `workspace/skills/`. If it should run automatically, add cron. If he has to ask twice for the same class of work, that is failure.
- **Growth lesson (2026-04-28):** freeze low-signal content factories when traffic and install attribution stay weak. Prefer fixing execution blockers and improving conversion on already-viewed pages over creating more SEO pages.
- **Measurement honesty:** never present inferred numbers as facts. Always cite source (endpoint/log/CSV) + confidence; if tracking is degraded, say **unknown** and fix measurement first.
- **Health content:** harm‑reduction / educational framing; non‑diagnostic, non‑prescriptive. Never give medical advice.
- **Reddit:** manual‑only for authenticated actions. One deliberate action at a time: review → craft → post → verify → report. Minimize auth pokes to reduce ban risk.

## Preferences (how Jon wants you to operate)
- **Tone:** sharp, human, not corporate; no validation‑fluff openers.
- **Latency / thinking:** keep default reasoning minimal; escalate only when complexity/risk warrants.
- **Model routing:** OpenAI‑only. Primary `openai-codex/gpt-5.3-codex`; fallback `openai-codex/gpt-5.2`.
- **Updates cadence:** one operator update per day by default, around 5pm ET, unless there is a real blocker or materially new information.
- **Daily update format (2026-04-17):** report only: what shipped, what moved installs, what got stuck, what was fake progress, next action.
- **Product metric framing (2026‑03‑09):** prioritize **installs** now; paid conversion optimization later.
- **When Tim asks for a change:** include current setup state (config/status) in the reply.

## Current focus
- **Jabbit growth goal:** 1000 subscribers in ~2 months.
- **Distribution:** Reddit ladder/warmup + selective, context‑fit mentions.
- **SEO:** GLP‑1 / peptide content (quality > volume; conversion‑oriented).

## Tim Reddit personal context (verified; don’t invent)
- Final‑loss phase is harder (bigger deficits = more hunger; scale loss slower).
- Reframed away from weekly scale obsession; focuses on monthly trend.
- Travel: aim maintenance or ~300 cal deficit; track; enjoy food.
- Guardrail: actively manage binge risk.

## Durable system facts
### WebShare proxies
- Provider: WebShare.io rotating residential
- Pattern: `jxrtqjko-US-1` … `US-5`
- Credentials: `scripts/proxy.env`
- Rotation: `scripts/proxy-rotate.sh`

### Apple App Store Connect API
- Key ID: **U32B72ACDS** (Sales and Trends)
- Issuer ID: **f99bb315-dd91-49b8-bc7f-24cf2b2ab80d**
- Vendor Number: **93886172**
- App ID: **6756848719** (Jabbit — Peptide Tracker)
- Reports: gzip CSV (use `Accept: application/a-gzip`)

## Known business facts
- 17 paying customers (confirmed)
- PMF confirmed
