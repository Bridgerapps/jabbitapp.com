# Go-live: jabbitapp.com and millenaut.com on Cloudflare (prepared 2026-10-28)

Nothing here is live yet. The work is on branches, in this order of dependence:

| Repo | Branch | What | Goes live |
|---|---|---|---|
| Bridgerapps/millenaut.com (private) | `main` | The new site: 40 peptide/longevity reviews, 13 peptide guides, the peptide calculator, home, about, privacy | Step 2 |
| Bridgerapps/jabbitapp.com | `cloudflare` | Worker + static assets config; moved pages removed and 301-redirected to millenaut.com; analytics moved to Cloudflare | Step 4 |
| Bridgerapps/website | `jabbitapp-cloudflare` | Privacy policy 8.5, sections 10/14/17 and the consumer health data page describe Cloudflare hosting and Web Analytics | Step 5 (same day as step 4) |
| Bridgerapps/jabbitapp.com | `ivf-pages` | IVF hub, medication pages from FDA labels, trigger-time calendar and printable IVF calendar | When Jabbit 1.1 is on the App Store |

## 1. Jon: Cloudflare account setup

1. Add **jabbitapp.com** to the Bridger Apps Cloudflare account and change its nameservers at the
   registrar. Today its DNS is on Google Cloud DNS (`ns-cloud-a*.googledomains.com`). There are no MX
   records. Keep the TXT record `google-site-verification=JiKKSW-FQn7TKD7n2r0FYm7Ol4_s3Fw6bDDXypa38zs`
   (Cloudflare's import scan copies it). Don't recreate the Vercel A record (216.198.79.1); step 4
   replaces it.
2. **millenaut.com** already uses Cloudflare nameservers (sonia/miguel). Make sure the zone is in the
   Bridger Apps account (move it if it was added under another account).
3. Deploy access, pick one:
   - **Workers Builds (recommended):** in Workers & Pages, create each Worker from its GitHub repo
     (`Bridgerapps/millenaut.com` → `main`; `Bridgerapps/jabbitapp.com` → `main`). Every push then
     deploys, which keeps Jabby's publishing flow working.
   - Or run `npx wrangler login` once on this Mac so Claude can run `npx wrangler deploy`.
4. **Web Analytics:** enable it for both sites with automatic setup (no code in the pages).
5. **Email Routing:** create `corrections@millenaut.com` forwarding to your inbox. Millenaut's about and
   editorial-standards pages list it.

## 2. Millenaut live

1. Re-sync first: Jabby may have added peptide pages to jabbitapp.com since 2026-10-28. In the
   millenaut.com repo: `python3 migration/build_millenaut.py <jabbitapp checkout> .` then
   `python3 migration/build_millenaut_pages.py . research-index.json`, review, and commit.
2. Deploy (Workers Builds or `npx wrangler deploy`), then add the custom domains if the routes in
   `wrangler.jsonc` didn't create them.
3. Check https://millenaut.com/, /research, /peptides, /peptide-reconstitution-calculator and one
   review page. In Google Search Console, add the property and submit `https://millenaut.com/sitemap.xml`.

## 3. Jabby

Pause Jabby before step 4. Point its peptide, longevity, nootropic and wellness work at
`Bridgerapps/millenaut.com`, with no Jabbit links or CTAs there. jabbitapp.com keeps GLP-1 and
obesity medicines, TRT, IVF and the app (`docs/legal-safety-wording.md`, "What belongs here"). Its
stats script read `/api/stats`, which is gone. Switch it to Cloudflare's GraphQL Analytics API
(needs an API token with Analytics read) or drop it.

## 4. jabbitapp.com on Cloudflare

1. Merge `main` into `cloudflare`, then re-run the migration so pages added since are handled:
   `python3 scripts/cloudflare/cf_migrate.py .` (safe to
   re-run; it also needs scripts/cloudflare/move_list.py). Commit and merge `cloudflare` into `main`.
2. Deploy the `jabbitapp` Worker (Workers Builds or `npx wrangler deploy`). Add the custom domains
   jabbitapp.com and www.jabbitapp.com.
3. Spot checks:
   - `/` and `/research` return 200.
   - `/research/selank-anxiety-teardown.html` returns a 301 to millenaut.com.
   - `/privacy` returns a 308 to bridgerapps.com.
   - `/docs/…` and `/api/track` return 404.
4. When traffic is on Cloudflare, disconnect the Vercel project for jabbitapp.com.
   `vercel.json` can go after that.

## 5. Policy

Merge `jabbitapp-cloudflare` into `main` in Bridgerapps/website on the same day as step 4. If the
Jabbit 1.1 privacy changes are in a separate branch, merge both; they touch different sections.

## IVF pages

Merge `ivf-pages` when Jabbit 1.1 is live: the pages describe IVF features that the current
App Store listing (1.0.4) doesn't have, and the wording rules allow only listed features.
