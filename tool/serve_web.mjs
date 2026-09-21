// Static server for build/web so progress can be viewed at http://localhost:5500.
// Usage: flutter build web && node tool/serve_web.mjs [port]
// It serves files from disk on every request, so rebuilding + refreshing is enough.
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(fileURLToPath(new URL('.', import.meta.url)), '..', 'build', 'web');
// 8080 is taken by a local Apache (XAMPP) on this machine.
const port = Number(process.argv[2] ?? 5500);
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.css': 'text/css', '.png': 'image/png', '.ico': 'image/x-icon',
  '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.svg': 'image/svg+xml',
  '.bin': 'application/octet-stream', '.frag': 'application/octet-stream',
};

createServer(async (req, res) => {
  const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let file = normalize(join(root, urlPath));
  if (!file.startsWith(normalize(root))) { res.writeHead(403).end(); return; }
  try {
    if ((await stat(file)).isDirectory()) file = join(file, 'index.html');
  } catch {
    file = join(root, 'index.html'); // SPA fallback
  }
  try {
    const body = await readFile(file);
    res.writeHead(200, {
      'content-type': types[extname(file)] ?? 'application/octet-stream',
      'cache-control': 'no-store',
    });
    res.end(body);
  } catch {
    res.writeHead(404).end('build/web not found: run "flutter build web" first');
  }
}).listen(port, '127.0.0.1', () => console.log(`Serving ${root} at http://localhost:${port}`));
