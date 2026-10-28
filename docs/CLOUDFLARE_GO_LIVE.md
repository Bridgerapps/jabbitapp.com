# Go-live: jabbitapp.com and millenaut.com on Cloudflare (prepared 2026-10-28)

Nothing here is live yet. The work is on branches, in this order of dependence:

| Repo | Branch | What | Goes live |
|---|---|---|---|
| Bridgerapps/millenaut.com (private) | `main` | The new site: 40 peptide/longevity reviews, 13 peptide guides, the peptide calculator, home, about, privacy | Step 2 |
| Bridgerapps/jabbitapp.com | `cloudflare` | Worker + static assets config; moved pages removed and 301-redirected to millenaut.com; analytics moved to Cloudflare | Step 4 |
| Bridgerapps/website | `jabbitapp-cloudflare` | Privacy policy 8.5, sections 10/14/17 and the consumer health data page describe Cloudflare hosting and Web Analytics | Step 5 (same day as step 4) |
| Bridgerapps/jabbitapp.com | `ivf-pages` | IVF hub, medication pages from FDA labels, trigger-time calendar and printable IVF calendar | When Jabbit 1.1 is on the App Store |

**How sites publish (Jon, 2026-10-28): automatically from GitHub (Workers Builds).** Each site's
Cloudflare Worker is connected to its GitHub repo, and every push to `main` publishes within a couple
of minutes, whoever pushed it (Claude, Jabby or Jon). Nobody runs `wrangler deploy` by hand.

## 1. Jon: Cloudflare account setup

1. Add **jabbitapp.com** to the Bridger Apps Cloudflare account and change its nameservers at the
   registrar. Today its DNS is on Google Cloud DNS (`ns-cloud-a*.googledomains.com`). There are no MX
   records.
   - Keep the two records Cloudflare's import copies from Vercel, and set both to **DNS only** (grey
     cloud) so the site keeps running on Vercel until step 4:
     `jabbitapp.com` A `216.198.79.1` and `www` CNAME `48b986948c72fc83.vercel-dns-017.com`.
   - Keep the TXT record `google-site-verification=JiKKSW-FQn7TKD7n2r0FYm7Ol4_s3Fw6bDDXypa38zs`.
2. **millenaut.com** already uses Cloudflare nameservers (sonia/miguel). Make sure the zone is in the
   Bridger Apps account (move it if it was added under another account). On 2026-10-28 it had no A or
   CNAME records for the apex or www, which is what the first deploy needs.
3. **Connect GitHub once:** Workers & Pages → Create → Import a repository → connect GitHub. Install
   Cloudflare's GitHub app on the **Bridgerapps** organization with access to *only selected
   repositories*: `millenaut.com` and `jabbitapp.com` (add `whelpinglog` later).
4. **Web Analytics:** enable it for both sites with automatic setup (no code in the pages).
5. **Email Routing:** create `corrections@millenaut.com` forwarding to your inbox. Millenaut's about and
   editorial-standards pages list it.

## 2. Millenaut live

1. Claude: re-sync first, because Jabby may have added peptide pages to jabbitapp.com since
   2026-10-28. In the millenaut.com repo: `python3 migration/build_millenaut.py <jabbitapp checkout> .`
   then `python3 migration/build_millenaut_pages.py . research-index.json`, review, commit and push.
2. Jon: Workers & Pages → Create → Import a repository → `Bridgerapps/millenaut.com`, with:
   - **Worker name: `millenaut`.** It must match `name` in `wrangler.jsonc`, or the build fails.
   - Production branch: `main`.
   - Build command: leave empty. Deploy command: `npx wrangler deploy` (the default).
   - Root directory: leave as the repo root.
   - Builds for non-production branches: off.
   The first build publishes the site and attaches millenaut.com and www.millenaut.com (the routes in
   `wrangler.jsonc`). Watch it under the Worker's Deployments tab.
3. Check https://millenaut.com/, /research, /peptides, /peptide-reconstitution-calculator and one
   review page. In Google Search Console, add the property and submit `https://millenaut.com/sitemap.xml`.

## 3. Jabby

Pause Jabby before step 4. Point its peptide, longevity, nootropic and wellness work at
`Bridgerapps/millenaut.com`, with no Jabbit links or CTAs there. jabbitapp.com keeps GLP-1 and
obesity medicines, TRT, IVF and the app (`docs/legal-safety-wording.md`, "What belongs here"). Its
stats script read `/api/stats`, which is gone. Switch it to Cloudflare's GraphQL Analytics API
(needs an API token with Analytics read) or drop it. Pushing to `main` of either repo publishes that
site, as Vercel does today.

## 4. jabbitapp.com on Cloudflare

The site is offline for a few minutes in this step, between deleting the Vercel records and the
first Cloudflare build finishing. Pick a quiet time.

1. Claude: merge `main` into `cloudflare`, then re-run the migration so pages added since are handled:
   `python3 scripts/cloudflare/cf_migrate.py .` (safe to re-run; it also needs
   scripts/cloudflare/move_list.py). Commit, merge `cloudflare` into `main` and push.
2. Jon: in Cloudflare DNS for jabbitapp.com, delete the A record `jabbitapp.com` → `216.198.79.1` and
   the CNAME `www` → `…vercel-dns-017.com`. The deploy can't attach the domains while they exist.
3. Jon: Workers & Pages → Create → Import a repository → `Bridgerapps/jabbitapp.com`, with the same
   settings as step 2.2 but **Worker name `jabbitapp`**. The first build publishes the site and
   attaches jabbitapp.com and www.jabbitapp.com.
4. Spot checks:
   - `/` and `/research` return 200.
   - `/research/selank-anxiety-teardown.html` returns a 301 to millenaut.com.
   - `/privacy` returns a 308 to bridgerapps.com.
   - `/docs/…`, `/readme.md` and `/api/track` return 404.
5. Disconnect the Vercel project for jabbitapp.com (or remove its Git connection) so pushes stop
   deploying there too. `vercel.json` can go after that. Then resume Jabby.

## 5. Policy

Merge `jabbitapp-cloudflare` into `main` in Bridgerapps/website on the same day as step 4. If the
Jabbit 1.1 privacy changes are in a separate branch, merge both; they touch different sections.

## IVF pages

Merge `ivf-pages` when Jabbit 1.1 is live: the pages describe IVF features that the current
App Store listing (1.0.4) doesn't have, and the wording rules allow only listed features.

## If a build fails

The Worker's Deployments tab shows each build's log, and the site keeps serving the last good
version. Common causes: the Worker name doesn't match `wrangler.jsonc`, or a DNS record still exists
for a hostname in `routes`.
