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

module.exports = async (req, res) => {
  const ANALYTICS_BASE = process.env.ANALYTICS_BASE || 'http://127.0.0.1:9000';
  const ANALYTICS_SECRET = loadAnalyticsSecret();

  if (!ANALYTICS_SECRET) {
    res.status(500).json({ ok: false, error: 'analytics secret missing' });
    return;
  }

  try {
    const body = req.method === 'POST' ? (req.body || {}) : (req.query || {});

    const payload = {
      event: String(body.event || 'pageview'),
      page: String(body.page || '/'),
      target: String(body.target || ''),
      ref: String(body.ref || req.headers.referer || ''),
    };

    const r = await fetch(`${ANALYTICS_BASE}/track`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-analytics-secret': ANALYTICS_SECRET,
        'user-agent': req.headers['user-agent'] || 'jabbit-proxy',
        'x-forwarded-for': req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '',
      },
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
