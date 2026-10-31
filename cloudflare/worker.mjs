import config from '../vercel.json';
import files from './assets.json';
import track from '../api/track.js';
import stats from '../api/stats.js';

const assets = new Set(files.map(p => `/${p}`));
const redirects = new Map(config.redirects.filter(r => !r.source.includes(':')).map(r => [r.source, r]));

async function api(handler, request) {
  const url = new URL(request.url);
  let body = {};
  if (request.method === 'POST') {
    try {
      body = request.headers.get('content-type')?.includes('application/json')
        ? await request.json() : Object.fromEntries(new URLSearchParams(await request.text()));
    } catch { return Response.json({ ok: false, error: 'invalid body' }, { status: 400 }); }
  }
  let status = 200;
  const headers = new Headers({ 'cache-control': 'no-store' });
  let result;
  const res = {
    status(code) { status = code; return res; },
    setHeader(key, value) { headers.set(key, value); return res; },
    json(value) { result = value; return res; }
  };
  const inputHeaders = Object.fromEntries(request.headers);
  inputHeaders['x-forwarded-for'] = request.headers.get('cf-connecting-ip') || '';
  await handler({ method: request.method, body, query: Object.fromEntries(url.searchParams), headers: inputHeaders }, res);
  return Response.json(result, { status, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.hostname === 'www.jabbitapp.com' || (url.hostname === 'jabbitapp.com' && url.protocol === 'http:')) {
      url.hostname = 'jabbitapp.com';
      url.protocol = 'https:';
      return Response.redirect(url, 308);
    }
    const path = url.pathname;
    const redirect = redirects.get(path) || (path.match(/^\/blog\/([^/]+)$/) ? { destination: `/${path.split('/')[2]}.html`, permanent: true } : null);
    if (redirect) {
      const target = new URL(redirect.destination, url);
      for (const [key, value] of url.searchParams) if (!target.searchParams.has(key)) target.searchParams.append(key, value);
      return Response.redirect(target, redirect.permanent ? 308 : 307);
    }
    if (path === '/api/track' || path === '/api/stats') return api(path === '/api/track' ? track : stats, request);
    if (path !== '/' && path.endsWith('/')) {
      url.pathname = path.slice(0, -1);
      return Response.redirect(url, 308);
    }
    let assetPath = path;
    if (!assets.has(assetPath)) assetPath = `${path.replace(/\/$/, '')}/index.html`;
    const exists = assets.has(assetPath);
    url.pathname = exists ? assetPath : '/404.html';
    const asset = await env.ASSETS.fetch(new Request(url, request));
    const headers = new Headers(asset.headers);
    for (const rule of config.headers) {
      if (new RegExp(`^${rule.source}$`).test(path)) for (const h of rule.headers) headers.set(h.key, h.value);
    }
    return new Response(asset.body, { status: exists ? asset.status : 404, headers });
  }
};
