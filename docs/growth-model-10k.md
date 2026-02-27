# Growth model: path to 10,000 subscribers

_Last updated: 2026-02-27 (UTC)_

## Baseline + goal

- **Baseline (current):** 17 subscribers (last-known paying customers)
- **Goal:** 10,000 subscribers
- **Gap:** 9,983 net new subscribers

This is a **simple linear net-adds model**: it answers “if we need to add X net subscribers in Y days, what’s the required daily/weekly pace?”

Machine-readable version: `docs/growth-model-10k.json`.

## Required pace scenarios

| Timeline | Net adds/day | Net adds/week |
|---:|---:|---:|
| 30 days | 332.77 | 2,329.27 |
| 60 days | 166.38 | 1,164.63 |
| 90 days | 110.92 | 776.46 |
| 180 days | 55.46 | 388.23 |
| 365 days | 27.35 | 191.47 |

## Notes / how to use this

- If churn exists, **required gross adds/day = net adds/day + churn/day**.
- If you’re thinking in funnels, convert pace into required:
  - impressions/day
  - clicks/day
  - installs/day
  - trials/day
  - paid conversions/day

Next improvement when we have real telemetry: add churn + conversion-rate assumptions and output channel-specific required volumes.
