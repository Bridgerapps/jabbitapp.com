# Free Marketing Tests — 2026-03-10

Goal: maximize **site visits -> App Store clicks -> installs/subscriptions** with free checks only.

Overall pass rate: **46/50 (92.0%)**

## Page checks
| Page | HTTP | TTFB(s) | Total(s) | Title | Desc | H1 | AppStore link | Schema | Noindex | Tracking |
|---|---:|---:|---:|---:|---:|:--:|:--:|:--:|:--:|:--:|
| `/` | 200 | 0.39 | 0.39 | 54 | 150 | ✅ | ✅ (9) | ✅ | ✅ | ✅ |
| `/shotsy-alternative.html` | 200 | 0.36 | 0.36 | 67 | 140 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/glp1-injection-tracker.html` | 200 | 0.24 | 0.24 | 69 | 129 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/zepbound-injection-tracker.html` | 200 | 0.26 | 0.26 | 72 | 127 | ✅ | ✅ (2) | ✅ | ✅ | ✅ |
| `/guides/` | 200 | 0.29 | 0.29 | 43 | 188 | ✅ | ✅ (4) | ✅ | ✅ | ✅ |

## Action rubric
- Speed fail (TTFB>1.2s or Total>2.5s): optimize page weight and server latency.
- No App Store link: add one clear above-the-fold CTA.
- Title/Description out of range: tighten SERP copy for click-through.
- Missing schema: add structured data where relevant.
- No tracking JS: fix instrumentation before making marketing decisions.
