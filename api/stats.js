const fs = require('fs');

function loadAnalyticsSecret() {
  if (process.env.ANALYTICS_SECRET) return String(process.env.ANALYTICS_SECRET);
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

module.exports = async (_req, res) => {
  const ANALYTICS_BASE = process.env.ANALYTICS_BASE || 'http://127.0.0.1:9000';
  const ANALYTICS_SECRET = loadAnalyticsSecret();

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
