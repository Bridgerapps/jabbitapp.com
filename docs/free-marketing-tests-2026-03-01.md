# Free Marketing Tests — 2026-03-01

Goal: maximize **site visits -> App Store clicks -> installs/subscriptions** with free checks only.

Overall pass rate: **46/50 (92.0%)**

## Page checks
| Page | HTTP | TTFB(s) | Total(s) | Title | Desc | H1 | AppStore link | Schema | Noindex | Tracking |
|---|---:|---:|---:|---:|---:|:--:|:--:|:--:|:--:|:--:|
| `/` | 200 | 0.17 | 0.17 | 42 | 171 | ✅ | ✅ (7) | ✅ | ✅ | ✅ |
| `/shotsy-alternative.html` | 200 | 0.12 | 0.12 | 57 | 130 | ✅ | ✅ (2) | ❌ | ✅ | ✅ |
| `/glp1-injection-tracker.html` | 200 | 0.14 | 0.15 | 42 | 127 | ✅ | ✅ (2) | ❌ | ✅ | ✅ |
| `/zepbound-injection-tracker.html` | 200 | 0.18 | 0.18 | 61 | 133 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/guides/` | 200 | 0.12 | 0.12 | 43 | 188 | ✅ | ✅ (3) | ❌ | ✅ | ✅ |

## Action rubric
- Speed fail (TTFB>1.2s or Total>2.5s): optimize page weight and server latency.
- No App Store link: add one clear above-the-fold CTA.
- Title/Description out of range: tighten SERP copy for click-through.
- Missing schema: add structured data where relevant.
- No tracking JS: fix instrumentation before making marketing decisions.
