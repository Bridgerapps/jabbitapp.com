# Free Marketing Tests — 2026-03-08

Goal: maximize **site visits -> App Store clicks -> installs/subscriptions** with free checks only.

Overall pass rate: **46/50 (92.0%)**

## Page checks
| Page | HTTP | TTFB(s) | Total(s) | Title | Desc | H1 | AppStore link | Schema | Noindex | Tracking |
|---|---:|---:|---:|---:|---:|:--:|:--:|:--:|:--:|:--:|
| `/` | 200 | 0.28 | 0.28 | 54 | 150 | ✅ | ✅ (9) | ✅ | ✅ | ✅ |
| `/shotsy-alternative.html` | 200 | 0.31 | 0.31 | 67 | 140 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/glp1-injection-tracker.html` | 200 | 0.26 | 0.26 | 69 | 129 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/zepbound-injection-tracker.html` | 200 | 0.25 | 0.26 | 72 | 127 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/guides/` | 200 | 0.28 | 0.28 | 43 | 188 | ✅ | ✅ (4) | ✅ | ✅ | ✅ |

## Action rubric
- Speed fail (TTFB>1.2s or Total>2.5s): optimize page weight and server latency.
- No App Store link: add one clear above-the-fold CTA.
- Title/Description out of range: tighten SERP copy for click-through.
- Missing schema: add structured data where relevant.
- No tracking JS: fix instrumentation before making marketing decisions.
