/**
 * Static preview server for the exported site.
 *
 * It mirrors GitHub Pages closely enough to check the things that matter: a
 * directory resolves to its index.html, an unknown path returns a real 404 with
 * the built 404.html, and nothing is rewritten to the homepage.
 */
import { createServer } from "node:http";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";

const root = resolve(process.cwd(), process.argv[2] ?? "out");
const port = Number(process.env.PORT ?? 4173);

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".xml": "application/xml; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".webmanifest": "application/manifest+json",
};

async function resolveFile(pathname) {
  const clean = normalize(decodeURIComponent(pathname)).replace(/^(\.\.[/\\])+/, "");
  const candidates = clean.endsWith("/")
    ? [join(root, clean, "index.html")]
    : [join(root, clean), join(root, `${clean}.html`), join(root, clean, "index.html")];
  for (const candidate of candidates) {
    if (!candidate.startsWith(root)) continue;
    try {
      const info = await stat(candidate);
      if (info.isFile()) return candidate;
    } catch {
      // Try the next candidate.
    }
  }
  return null;
}

createServer(async (request, response) => {
  const url = new URL(request.url ?? "/", "http://localhost");
  const file = await resolveFile(url.pathname);

  if (file) {
    response.writeHead(200, {
      "content-type": types[extname(file)] ?? "application/octet-stream",
      "cache-control": "no-store",
    });
    createReadStream(file).pipe(response);
    return;
  }

  const notFound = await resolveFile("/404.html");
  response.writeHead(404, { "content-type": "text/html; charset=utf-8" });
  if (notFound) createReadStream(notFound).pipe(response);
  else response.end("404");
}).listen(port, () => {
  console.log(`Serving ${root} at http://localhost:${port}`);
});
