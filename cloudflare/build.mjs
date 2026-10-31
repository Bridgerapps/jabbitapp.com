import { execFileSync } from 'node:child_process';
import { mkdir, rm, copyFile, writeFile } from 'node:fs/promises';
import { dirname, extname } from 'node:path';

const blocked = new Set(['node_modules', 'data', 'output', 'scripts', 'docs', '_includes', 'cloudflare', 'api', 'jabbitapp.com']);
const extensions = new Set(['.html', '.css', '.js', '.png', '.jpg', '.jpeg', '.webp', '.svg', '.ico', '.woff', '.woff2', '.pdf', '.mp4', '.webm', '.xml', '.txt', '.webmanifest']);
const files = execFileSync('git', ['ls-files', '-z'], { encoding: 'utf8' }).split('\0').filter(p =>
  p && !p.split('/').some(part => part.startsWith('.')) && !blocked.has(p.split('/')[0]) && extensions.has(extname(p)));
await rm('dist', { recursive: true, force: true });
for (const file of files) {
  await mkdir(dirname(`dist/${file}`), { recursive: true });
  await copyFile(file, `dist/${file}`);
}
await writeFile('cloudflare/assets.json', JSON.stringify(files));
console.log(`Prepared ${files.length} public assets.`);
