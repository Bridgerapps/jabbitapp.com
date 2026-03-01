module.exports = async (req, res) => {
  const ANALYTICS_BASE = process.env.ANALYTICS_BASE || 'http://138.197.74.40:9000';
  const ANALYTICS_SECRET = process.env.ANALYTICS_SECRET || '';

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
