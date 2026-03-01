module.exports = async (_req, res) => {
  const ANALYTICS_BASE = process.env.ANALYTICS_BASE || 'http://138.197.74.40:9000';
  const ANALYTICS_SECRET = process.env.ANALYTICS_SECRET || '';

  if (!ANALYTICS_SECRET) {
    res.status(500).json({ ok: false, error: 'analytics secret missing' });
    return;
  }

  try {
    const r = await fetch(`${ANALYTICS_BASE}/stats?secret=${encodeURIComponent(ANALYTICS_SECRET)}`);
    const txt = await r.text();
    if (!r.ok) {
      res.status(502).json({ ok: false, error: 'upstream', detail: txt.slice(0, 240) });
      return;
    }

    let parsed;
    try { parsed = JSON.parse(txt); } catch { parsed = { raw: txt }; }
    res.setHeader('cache-control', 'no-store');
    res.status(200).json(parsed);
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
};
