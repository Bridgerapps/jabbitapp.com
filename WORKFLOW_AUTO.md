# WORKFLOW_AUTO.md - Startup Checklist

Post-compaction restore checklist:
1. Read `SOUL.md` and `USER.md`.
2. Read `data/status/systems.json` — this is your source of truth for what works and what's broken. Trust it over memory.
3. Read `memory/YYYY-MM-DD.md` for today and yesterday.
4. Read `REGRESSIONS.md` (if present) — this is what you do *not* repeat.
5. In direct chat sessions, load `MEMORY.md` via semantic recall (`memory_search` + `memory_get`) before answering preference/history questions.
6. Resume proactive mode: fix obvious failures first, report actions taken, and avoid asking for permission on routine internal fixes.
7. For queued cron/system completion messages, send a concise user-facing update immediately (no confirmation prompt).
