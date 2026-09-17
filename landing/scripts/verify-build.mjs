/**
 * Rendered-output verifier.
 *
 * Expectations are derived from the build itself, never hardcoded: the sitemap
 * is generated from the content registry, and the exported HTML files are the
 * routes that actually exist. Any disagreement between the two, in either
 * direction, is a failure.
 */
import { readFile, readdir, stat } from "node:fs/promises";
import { join, relative, resolve, sep } from "node:path";

const root = resolve(process.cwd(), process.argv[2] ?? "out");
const failures = [];
const notes = [];

function check(condition, message) {
  if (!condition) failures.push(message);
}

async function htmlFiles(directory = root) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "_next") continue;
      files.push(...(await htmlFiles(path)));
    } else if (entry.name.endsWith(".html")) {
      files.push(path);
    }
  }
  return files;
}

function routeOf(file) {
  const relativePath = relative(root, file).split(sep).join("/");
  if (relativePath === "index.html") return "/";
  if (relativePath === "404.html") return "/404.html";
  return `/${relativePath.replace(/index\.html$/, "")}`;
}

const text = (html, pattern) => html.match(pattern)?.[1] ?? null;
const all = (html, pattern) => [...html.matchAll(pattern)].map((match) => match[1]);

/**
 * The public prefix a host serves the build under. GitHub project pages serve
 * from a sub-path, so file routes and public routes are not the same strings.
 */
async function detectBasePath() {
  const home = await readFile(join(root, "index.html"), "utf8").catch(() => "");
  const canonical = text(home, /<link rel="canonical" href="([^"]+)"/);
  if (!canonical) return "";
  const path = new URL(canonical).pathname;
  return path === "/" ? "" : path.replace(/\/$/, "");
}

async function main() {
  const files = await htmlFiles();
  check(files.length > 0, "The build produced no HTML files. Run the build first.");
  if (files.length === 0) return report();

  const basePath = await detectBasePath();
  const publicRoute = (route) => `${basePath}${route}`;
  const fileRoute = (publicPath) =>
    basePath && publicPath.startsWith(`${basePath}/`) ? publicPath.slice(basePath.length) : publicPath;
  if (basePath) notes.push(`build is served under the base path ${basePath}`);

  const sitemapPath = join(root, "sitemap.xml");
  const sitemap = await readFile(sitemapPath, "utf8").catch(() => null);
  check(sitemap !== null, "sitemap.xml is missing from the build.");
  const robots = await readFile(join(root, "robots.txt"), "utf8").catch(() => null);
  check(robots !== null, "robots.txt is missing from the build.");

  const sitemapUrls = sitemap ? all(sitemap, /<loc>([^<]+)<\/loc>/g) : [];
  const origins = new Set(sitemapUrls.map((url) => new URL(url).origin));
  check(origins.size <= 1, `The sitemap mixes origins: ${[...origins].join(", ")}`);
  const origin = [...origins][0] ?? null;

  const sitemapRoutes = new Set(sitemapUrls.map((url) => new URL(url).pathname));
  const indexableRoutes = new Set();
  const titles = new Map();
  const descriptions = new Map();
  const internalTargets = new Set();
  const incomingLinks = new Map();

  for (const file of files) {
    const route = routeOf(file);
    const html = await readFile(file, "utf8");
    const label = `${route}`;

    // S02: substantive copy, one H1, unique title and description.
    const h1s = all(html, /<h1[^>]*>([\s\S]*?)<\/h1>/g);
    check(h1s.length === 1, `${label}: expected exactly one H1, found ${h1s.length}.`);

    const title = text(html, /<title>([^<]*)<\/title>/);
    check(Boolean(title && title.trim()), `${label}: missing a title.`);
    const description = text(html, /<meta name="description" content="([^"]*)"/);
    check(Boolean(description && description.trim()), `${label}: missing a meta description.`);

    check(/<html lang="[a-z]{2}(-[A-Z]{2})?"/.test(html), `${label}: missing a document language.`);

    const bodyText = html
      .replace(/<script[\s\S]*?<\/script>/g, " ")
      .replace(/<style[\s\S]*?<\/style>/g, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    check(
      bodyText.split(" ").length > 120,
      `${label}: initial HTML has only ${bodyText.split(" ").length} words of copy.`,
    );

    const noindex = /<meta name="robots" content="[^"]*noindex/.test(html);
    const canonical = text(html, /<link rel="canonical" href="([^"]+)"/);
    const canonicalCount = all(html, /<link rel="canonical" href="([^"]+)"/g).length;

    if (!noindex) {
      indexableRoutes.add(route);
      // Uniqueness only matters for pages that can be indexed; the 404 template
      // is exported under several paths on purpose.
      if (title) {
        check(!titles.has(title), `${label}: title duplicates ${titles.get(title)}.`);
        titles.set(title, label);
      }
      if (description) {
        check(
          !descriptions.has(description),
          `${label}: meta description duplicates ${descriptions.get(description)}.`,
        );
        descriptions.set(description, label);
      }
      check(canonicalCount === 1, `${label}: expected one canonical, found ${canonicalCount}.`);
      // S03: canonical, og:url and sitemap agree on origin and slash policy.
      if (canonical) {
        const canonicalUrl = new URL(canonical);
        check(
          canonicalUrl.pathname === publicRoute(route),
          `${label}: canonical path ${canonicalUrl.pathname} does not match its route.`,
        );
        if (origin) {
          check(
            canonicalUrl.origin === origin,
            `${label}: canonical origin ${canonicalUrl.origin} differs from the sitemap origin.`,
          );
        }
        check(!canonical.includes("?"), `${label}: canonical carries a query string.`);
      }
      const ogUrl = text(html, /<meta property="og:url" content="([^"]+)"/);
      check(ogUrl === canonical, `${label}: og:url and canonical disagree.`);
      const ogImage = text(html, /<meta property="og:image" content="([^"]+)"/);
      check(Boolean(ogImage), `${label}: missing og:image.`);
      if (ogImage) {
        const assetPath = new URL(ogImage).pathname;
        check(
          !assetPath.endsWith("/"),
          `${label}: og:image path ${assetPath} has a route-style trailing slash.`,
        );
        const exists = await stat(join(root, fileRoute(assetPath))).then(
          (info) => info.isFile(),
          () => false,
        );
        check(exists, `${label}: og:image ${assetPath} is not in the build.`);
      }
      check(
        /<meta name="twitter:card" content="summary_large_image"/.test(html),
        `${label}: missing the social card type.`,
      );
    }

    // S05: JSON-LD parses and carries no unresolved placeholders.
    for (const block of all(
      html,
      /<script type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/g,
    )) {
      try {
        const parsed = JSON.parse(block);
        const serialized = JSON.stringify(parsed);
        check(
          !/"(TODO|TBD|example\.com|lorem)/i.test(serialized),
          `${label}: JSON-LD contains a placeholder value.`,
        );
        if (origin) {
          for (const url of serialized.match(/https?:\/\/[^"]+/g) ?? []) {
            check(
              new URL(url).origin === origin || !url.includes(new URL(origin).hostname),
              `${label}: JSON-LD URL ${url} uses an unexpected origin.`,
            );
          }
        }
      } catch (error) {
        failures.push(`${label}: JSON-LD does not parse (${error.message}).`);
      }
    }

    // C07: no placeholder copy or dead anchors in rendered output.
    check(
      !/(lorem ipsum|TODO:|FIXME|example\.com|Your Company|\bTBD\b)/i.test(bodyText),
      `${label}: rendered copy contains a placeholder.`,
    );
    check(!/href="#"/.test(html), `${label}: contains an empty href="#" link.`);

    // S04: internal links resolve, and anchors point at real ids.
    const ids = new Set(all(html, /\sid="([^"]+)"/g));
    for (const target of all(html, /href="([^"]+)"/g)) {
      if (target.startsWith("http") || target.startsWith("mailto:")) continue;
      if (target.startsWith("#")) {
        check(ids.has(target.slice(1)), `${label}: fragment ${target} has no matching id.`);
        continue;
      }
      const [publicPath, fragment] = target.split("#");
      const path = fileRoute(publicPath);
      internalTargets.add(path);
      if (path !== route) {
        incomingLinks.set(path, (incomingLinks.get(path) ?? 0) + 1);
      }
      if (fragment) notes.push(`${label} links to ${path}#${fragment}`);
    }
  }

  // S01: the sitemap and the build agree, in both directions.
  for (const route of sitemapRoutes) {
    check(
      indexableRoutes.has(fileRoute(route)),
      `Sitemap lists ${route}, which is not an indexable page in the build.`,
    );
  }
  for (const route of indexableRoutes) {
    check(
      sitemapRoutes.has(publicRoute(route)),
      `Indexable route ${route} is missing from the sitemap.`,
    );
  }

  // S04: every indexable route is reachable from another page.
  for (const route of indexableRoutes) {
    if (route === "/") continue;
    check(
      (incomingLinks.get(route) ?? 0) > 0,
      `Route ${route} has no incoming internal link, so it is orphaned.`,
    );
  }

  // Internal link targets must exist in the build.
  for (const target of internalTargets) {
    if (!target.startsWith("/")) continue;
    const asRoute = target.endsWith("/") ? join(root, target, "index.html") : join(root, target);
    const exists = await stat(asRoute).then(
      (info) => info.isFile(),
      () => false,
    );
    check(exists, `Internal link target ${target} does not exist in the build.`);
  }

  // W04: no live ad or analytics request can be baked into a default build.
  for (const file of files) {
    const html = await readFile(file, "utf8");
    const route = routeOf(file);
    check(
      !html.includes("pagead2.googlesyndication.com"),
      `${route}: an advertising script is present in static HTML.`,
    );
    check(
      !html.includes("googletagmanager.com"),
      `${route}: a measurement script is present in static HTML.`,
    );
  }

  check(
    files.some((file) => routeOf(file) === "/404.html"),
    "The build has no 404.html, so unknown paths cannot return a real 404.",
  );

  if (robots) {
    const production = !robots.includes("Disallow: /\n") || robots.includes("Allow: /");
    notes.push(
      production
        ? "robots.txt allows crawling: this build used a production origin."
        : "robots.txt disallows crawling: this is a preview build, which is expected locally.",
    );
  }

  report({ files: files.length, indexable: indexableRoutes.size, sitemap: sitemapRoutes.size });
}

function report(summary) {
  if (summary) {
    console.log(
      `Pages: ${summary.files}, indexable: ${summary.indexable}, sitemap entries: ${summary.sitemap}`,
    );
  }
  for (const note of notes.filter((note) => !note.includes(" links to "))) console.log(`note: ${note}`);
  if (failures.length === 0) {
    console.log("All rendered discovery checks passed.");
    return;
  }
  console.error(`\n${failures.length} check(s) failed:`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exitCode = 1;
}

await main();
