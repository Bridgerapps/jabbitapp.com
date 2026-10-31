const fs = require('fs');
const net = require('net');

// Visitors' full IP addresses and browser strings never leave this function. The analytics
// daemon gets the network part of the address (IPv4 /24, IPv6 /48), a coarse device and
// browser label, and page addresses without query strings. The privacy policy
// (bridgerapps.com/jabbit/privacy/, section 8.5) describes exactly this, so keep them in step.
function truncateIp(raw) {
  let ip = String(raw || '').split(',')[0].trim();
  if (ip.startsWith('::ffff:') && net.isIPv4(ip.slice(7))) ip = ip.slice(7);
  if (net.isIPv4(ip)) return ip.replace(/\.\d+$/, '.0');
  if (!net.isIPv6(ip)) return '';
  const [head, tail = ''] = ip.split('::');
  const left = head ? head.split(':') : [];
  const right = tail ? tail.split(':') : [];
  const groups = ip.includes('::')
    ? [...left, ...Array(Math.max(0, 8 - left.length - right.length)).fill('0'), ...right]
    : left;
  return `${groups.slice(0, 3).join(':')}::`;
}

function coarseUserAgent(ua) {
  ua = String(ua || '');
  // Crawlers keep their name so the daemon can still filter them out; they are not people.
  if (/bot|crawl|spider|slurp|preview|monitor|curl|wget|python|headless/i.test(ua)) return ua.slice(0, 120);
  const device = /iPhone|iPod/.test(ua) ? 'iPhone' : /iPad/.test(ua) ? 'iPad' : /Android/.test(ua) ? 'Android'
    : /Macintosh/.test(ua) ? 'Mac' : /Windows/.test(ua) ? 'Windows' : /Linux|CrOS/.test(ua) ? 'Linux' : 'Other';
  const browser = /Edg\//.test(ua) ? 'Edge' : /Firefox|FxiOS/.test(ua) ? 'Firefox'
    : /Chrome|CriOS/.test(ua) ? 'Chrome' : /Safari/.test(ua) ? 'Safari' : 'Other';
  return `Mozilla/5.0 (${device}) ${browser}`;
}

function stripQuery(url) {
  try { const u = new URL(url); return (u.origin + u.pathname).slice(0, 240); } catch { return ''; }
}

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
      page: String(body.page || '/').split(/[?#]/)[0].slice(0, 240),
      target: String(body.target || ''),
      ref: stripQuery(String(body.ref || '')),
    };
    for (const k of ['utm_source', 'utm_medium', 'utm_campaign']) {
      const v = String(body[k] || '').replace(/[^A-Za-z0-9._-]/g, '').slice(0, 60);
      if (v) payload[k] = v;
    }

    const headers = {
      'content-type': 'application/json',
      'user-agent': req.headers['user-agent'] ? coarseUserAgent(req.headers['user-agent']) : 'jabbit-proxy',
      'x-forwarded-for': truncateIp(req.headers['x-forwarded-for'] || req.socket?.remoteAddress),
    };
    // Keep Cloudflare subrequest IP headers as coarse as the analytics payload.
    // Same-zone Worker fetches derive CF-Connecting-IP from x-real-ip.
    const networkIp = headers['x-forwarded-for'] || '0.0.0.0';
    headers['x-real-ip'] = networkIp;
    headers['cf-connecting-ip'] = networkIp;
    headers['cf-connecting-ipv6'] = networkIp.includes(':') ? networkIp : '';
    if (ANALYTICS_SECRET) {
      headers['x-analytics-secret'] = ANALYTICS_SECRET;
    }
    if (req.headers.origin) headers.origin = req.headers.origin;
    if (req.headers.referer) headers.referer = stripQuery(req.headers.referer);

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
