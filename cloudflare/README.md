# Cloudflare deployment

This repository deploys to the `jabbitapp-com` Worker in company account
`a829203d7d24484af6fcd3946b93712b`. The source baseline is Vercel production commit
`07d73db52beebba8d1b26dd31b1f0cfd766b842e`.

Use Node.js 22 or later. Run `npm ci`, then `npm run deploy:cloudflare` from the
repository root with an authenticated Wrangler session. Wrangler is pinned in
the lockfile. `npm run dev:cloudflare` runs the same Worker runtime locally.

Run `npm run verify:cloudflare -- https://DEPLOYMENT.workers.dev` after the build
to check published asset hashes and routing before cutover.

The build publishes versioned public assets, including the research library,
and excludes source tooling, internal reports, local state and secrets.
`vercel.json` remains the redirect/header rules source; the Worker applies its
374 exact redirects and the `/blog/:slug` redirect. Directory indexes and the
www-to-apex redirect are preserved. The original analytics handlers are bundled
behind a Workers Request/Response bridge with Node.js compatibility.

Analytics continues to use the existing external daemon. Optional environment
variable names are `ANALYTICS_BASE` and `ANALYTICS_SECRET`; store any secret using
Wrangler secrets, never in source or process arguments. The `/api/track` handler
preserves IP truncation and coarse user-agent processing. Verification must use
normal browser Origin/Referer headers because the daemon rejects requests
without an accepted origin. At the migration baseline `/api/stats` returns 500
because its secret is absent; no new statistics access is introduced.

Production is live at `https://jabbitapp.com` and the pinned Wrangler configuration
contains the apex/www Workers routes. Both hosting DNS records are proxied:
apex A `192.0.2.1`, www CNAME `jabbitapp.com`. The Worker serves every request
without an origin fallback; Vercel is not an origin dependency. HTTP redirects
to HTTPS, preserving the original canonical hostname. Do not change any email
or non-hosting records when adjusting hosting.

Rollback: use `wrangler rollback`, or restore the saved hosting DNS to Vercel
while the old project is retained. Keep the external analytics daemon and data.

The analytics daemon remains on the existing DigitalOcean Grok bot server.
`ANALYTICS_BASE` uses DNS-only `analytics-origin.jabbitapp.com:9000`, pointing
to the existing server, because Workers cannot fetch a literal IP address.
Outbound Cloudflare client-IP headers are explicitly reduced to the same
network prefix as `x-forwarded-for`. The server and retained analytics data
have not been migrated or removed.
