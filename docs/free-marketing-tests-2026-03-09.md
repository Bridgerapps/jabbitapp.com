# Free Marketing Tests — 2026-03-09

Goal: maximize **site visits -> App Store clicks -> installs/subscriptions** with free checks only.

Overall pass rate: **46/50 (92.0%)**

## Page checks
| Page | HTTP | TTFB(s) | Total(s) | Title | Desc | H1 | AppStore link | Schema | Noindex | Tracking |
|---|---:|---:|---:|---:|---:|:--:|:--:|:--:|:--:|:--:|
| `/` | 200 | 0.51 | 0.51 | 54 | 150 | ✅ | ✅ (9) | ✅ | ✅ | ✅ |
| `/shotsy-alternative.html` | 200 | 0.28 | 0.28 | 67 | 140 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/glp1-injection-tracker.html` | 200 | 0.22 | 0.22 | 69 | 129 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/zepbound-injection-tracker.html` | 200 | 0.21 | 0.21 | 72 | 127 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/guides/` | 200 | 0.21 | 0.21 | 43 | 188 | ✅ | ✅ (4) | ✅ | ✅ | ✅ |

## Action rubric
- Speed fail (TTFB>1.2s or Total>2.5s): optimize page weight and server latency.
- No App Store link: add one clear above-the-fold CTA.
- Title/Description out of range: tighten SERP copy for click-through.
- Missing schema: add structured data where relevant.
- No tracking JS: fix instrumentation before making marketing decisions.
