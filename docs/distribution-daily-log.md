# Distribution Daily Log

Purpose: make distribution execution binary and reviewable, the same way the Reddit checklist does.

## Daily rule
Each day must end with one of two states:
- **executed**: at least one real send/follow-up happened
- **skipped**: no send happened, with explicit reason

No silent days.

## Runtime state file
Use local runtime state at:
- `data/status/distribution-daily-check.json`

Keep it untracked. It is operating state, not durable documentation.

## What to log
- date
- executed (true/false)
- channel (email / contact_form / instagram / other)
- target
- leadId / queueId
- action_type (`initial_send` / `followup` / `skip`)
- why_this_target
- outcome
- next_followup_due_utc
- skip_reason (if skipped)
- notes

## Daily loop
1. Read `docs/mission-board.md`
2. Read `data/status/manual-growth-loop-ledger.json`
3. Identify the highest-leverage `ready_to_send` or due follow-up
4. Either:
   - execute it and log it
   - or explicitly skip with reason and next revisit time

## Failure conditions
Treat these as failures:
- generating a new send brief while backlog already exists
- ending the day without a logged execute-or-skip state
- choosing new leads over clearing ready-to-send queue

## Success criteria
A good day:
- one real send or follow-up executed and logged

A valid skipped day:
- explicit skip reason logged
- next revisit time set
- queue state still visible in the mission board / summary
