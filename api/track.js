const fs = require('fs');

function loadAnalyticsSecret() {
  if (process.env.ANALYTICS_SECRET) return String(process.env.ANALYTICS_SECRET);

  // Host fallback: analytics service + cron status script use /home/jabbit/analytics/.env
  // which may not be exported into the function runtime.
  try {
    const p = '/home/jabbit/analytics/.env';
    if (!fs.existsSync(p)) return '';
    const raw = fs.readFileSync(p, 'utf8');
    const m = raw.match(/^ANALYTICS_SECRET=(.*)$/m);
    return m ? String(m[1]).trim() : '';
  } catch {
    return '';
  }
}

async function chooseAnalyticsBase() {
  // Prefer explicitly configured base.
  if (process.env.ANALYTICS_BASE) return String(process.env.ANALYTICS_BASE);

  // If we're running on the same host as the analytics daemon, localhost is fastest.
  // Otherwise (e.g. Vercel/edge/serverless), localhost won't work — fall back to the public endpoint.
  const localhost = 'http://127.0.0.1:9000';
  try {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 800);
    const r = await fetch(`${localhost}/health`, { signal: ac.signal });
    clearTimeout(t);
    const j = await r.json().catch(() => null);
    if (r.ok && j && j.ok === true) return localhost;
  } catch (_) {}

  // NOTE: If this IP changes, set ANALYTICS_BASE in the deployment environment.
  return 'http://138.197.74.40:9000';
}

module.exports = async (req, res) => {
  const ANALYTICS_BASE = await chooseAnalyticsBase();
  const ANALYTICS_SECRET = loadAnalyticsSecret();
  const upstreamPath = ANALYTICS_SECRET ? '/track' : '/track-public';

  try {
    const body = req.method === 'POST' ? (req.body || {}) : (req.query || {});

    const payload = {
      event: String(body.event || 'pageview'),
      page: String(body.page || '/'),
      target: String(body.target || ''),
      ref: String(body.ref || req.headers.referer || ''),
    };

    const headers = {
      'content-type': 'application/json',
      'user-agent': req.headers['user-agent'] || 'jabbit-proxy',
      'x-forwarded-for': req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '',
    };
    if (ANALYTICS_SECRET) {
      headers['x-analytics-secret'] = ANALYTICS_SECRET;
    }
    if (req.headers.origin) headers.origin = req.headers.origin;
    if (req.headers.referer) headers.referer = req.headers.referer;

    const r = await fetch(`${ANALYTICS_BASE}${upstreamPath}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!r.ok) {
      const t = await r.text();
      res.status(502).json({ ok: false, error: 'upstream', detail: t.slice(0, 200) });
      return;
    }

    const out = await r.json().catch(() => ({ ok: true }));
    res.setHeader('cache-control', 'no-store');
    res.status(200).json({ ok: true, upstream: out });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
};
