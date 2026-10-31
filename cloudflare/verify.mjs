import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const base = process.argv[2];
if (!base) throw new Error('Usage: node cloudflare/verify.mjs https://DEPLOYMENT.workers.dev');
const files = JSON.parse(readFileSync(new URL('./assets.json', import.meta.url)));
const config = JSON.parse(readFileSync('vercel.json'));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
let checked = 0;
for (const file of files) {
  if (config.redirects.some(rule => rule.source === `/${file}`)) continue;
  const response = await fetch(new URL(`/${file}`, base), { redirect: 'manual' });
  if (response.status !== 200) throw new Error(`${file}: HTTP ${response.status}`);
  if (hash(Buffer.from(await response.arrayBuffer())) !== hash(readFileSync(`dist/${file}`))) throw new Error(`${file}: content mismatch`);
  checked++;
}
let redirectCount = 0;
for (const rule of config.redirects) {
  const source = rule.source.replace(':slug', 'hosting-verification');
  const destination = rule.destination.replace(':slug', 'hosting-verification');
  const url = new URL(source, base);
  url.searchParams.set('hosting_check', '1');
  const response = await fetch(url, { redirect: 'manual' });
  const expected = new URL(destination, base);
  expected.searchParams.set('hosting_check', '1');
  if (response.status !== 308 || response.headers.get('location') !== expected.href) throw new Error(`Redirect mismatch: ${source}`);
  redirectCount++;
}
for (const path of ['/.git/config', '/.env', '/package.json', '/cloudflare/worker.mjs', '/scripts/appstore.env', '/data/seo/page-tracker.json']) {
  const response = await fetch(new URL(path, base), { redirect: 'manual' });
  if (response.status !== 404) throw new Error(`Source/private path returned ${response.status}: ${path}`);
}
console.log(`Verified ${checked} public assets, ${redirectCount} redirects and private-path exclusions at ${base}`);
