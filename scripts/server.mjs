import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const port = Number(process.env.PORT || 8080);

const mime = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.htm', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.mjs', 'text/javascript; charset=utf-8'],
  ['.css', 'text/css; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.jpg', 'image/jpeg'],
  ['.jpeg', 'image/jpeg'],
  ['.svg', 'image/svg+xml'],
  ['.ico', 'image/x-icon'],
  ['.txt', 'text/plain; charset=utf-8']
]);

function send(res, status, body, type = 'text/plain; charset=utf-8') {
  res.writeHead(status, {
    'Content-Type': type,
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store'
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  try {
    const requestUrl = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    let pathname = decodeURIComponent(requestUrl.pathname);
    if (pathname === '/') pathname = '/play.html';

    const fullPath = path.resolve(root, `.${pathname}`);
    if (!fullPath.startsWith(root + path.sep) && fullPath !== path.join(root, 'play.html')) {
      send(res, 403, '403 Forbidden');
      return;
    }

    if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isFile()) {
      send(res, 404, '404 Not Found');
      return;
    }

    const data = fs.readFileSync(fullPath);
    res.writeHead(200, {
      'Content-Type': mime.get(path.extname(fullPath).toLowerCase()) || 'application/octet-stream',
      'Content-Length': data.length,
      'Cache-Control': 'no-store'
    });
    res.end(data);
  } catch (error) {
    send(res, 500, `500 Server Error\n${error.message}`);
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`ExorcistGame2046: http://localhost:${port}/play.html`);
  console.log('Keep this window open. Press Ctrl+C to stop.');
});
