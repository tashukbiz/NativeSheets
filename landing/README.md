# Native Sheets landing site

The public website and blog for Native Sheets, plus a working client-side XLSX
viewer. Next.js App Router, static export, no backend.

```bash
pnpm install
pnpm dev            # http://localhost:3000
```

## Commands

| Command | What it does |
| --- | --- |
| `pnpm dev` | Development server |
| `pnpm build` | Renders the share card, then exports the static site to `out/` |
| `pnpm preview` | Serves `out/` at http://localhost:4173 with real 404s |
| `pnpm typecheck` | `tsc --noEmit` |
| `pnpm lint` | ESLint |
| `pnpm test` | Unit tests: content registry, consent and ad gating, the XLSX parser |
| `pnpm verify` | Rendered discovery checks against `out/` |
| `pnpm content:validate` | Validates the content registry on its own, with a readable report |
| `pnpm check` | typecheck, lint, test, build, verify |

`pnpm verify` derives its expectations from the build: the sitemap is generated
from the content registry, the HTML files are the routes that exist, and any
disagreement between the two, in either direction, fails. It checks canonicals,
social metadata, JSON-LD, internal links, fragments, orphan routes, placeholder
copy, and that no provider script is baked into static HTML.

## Configuration

Everything is an environment variable read at build time. Each one is unset by
default, and unset means the feature is off.

| Variable | Example | Notes |
| --- | --- | --- |
| `NEXT_PUBLIC_SITE_ORIGIN` | `https://example.org` | Must be HTTPS. Without it the build is a preview: every page gets `noindex` and `robots.txt` disallows crawling |
| `NEXT_PUBLIC_BASE_PATH` | `/xlsx-editor` | Only for a GitHub *project* site. Empty for a user site or custom domain |
| `NEXT_PUBLIC_GA_MEASUREMENT_ID` | `G-XXXXXXX` | Enables measurement *and* the consent banner. Unset means neither |
| `NEXT_PUBLIC_AD_STATE` | `disabled` \| `preview` \| `pending-review` \| `live` | Defaults to `disabled` |
| `NEXT_PUBLIC_ADSENSE_CLIENT` | `ca-pub-…` | Required before `live` can request anything |
| `NEXT_PUBLIC_ADSENSE_SLOT_ARTICLE` | numeric slot id | Per-placement slot |
| `NEXT_PUBLIC_ADSENSE_SLOT_TOOL` | numeric slot id | Per-placement slot |

A production build:

```bash
NEXT_PUBLIC_SITE_ORIGIN=https://your-domain.example pnpm build && pnpm verify
```

## Deploying to GitHub Pages

Nothing deploys automatically; this repository has no workflow that publishes.
To publish manually, build with the right origin and base path and upload `out/`.

- **User or organisation site, or a custom domain:** leave `NEXT_PUBLIC_BASE_PATH`
  empty. Add a `public/CNAME` file containing the domain if you use one.
- **Project site** (`https://user.github.io/repo/`): set
  `NEXT_PUBLIC_BASE_PATH=/repo` and `NEXT_PUBLIC_SITE_ORIGIN=https://user.github.io`.

`public/.nojekyll` is already present; without it GitHub Pages will not serve the
`_next` directory. GitHub Pages serves `404.html` with a real 404 status, which
is what `out/404.html` is for.

## Adding content

All content is typed records under `src/site/content/`. There is no CMS and no
markdown loader: a record holds its own body as a list of blocks, so the
validator can see it.

1. Add a file under `src/site/content/articles/` (or `features/`), exporting one
   `ContentRecord`.
2. Register it in the array in `src/site/content/index.ts`.
3. `pnpm content:validate`.

The registry validates on import, so a broken record fails the build rather than
rendering a fallback. It rejects a missing or too-short body, a duplicate id or
route, a non-URL-safe slug, publication without a date, an invalid or
out-of-order date, a duplicate heading anchor, an unknown author, a link to a
draft, and a record related to itself.

Records with `status: "draft"` never appear in listings, schema or the sitemap.

Dates: set `datePublished` once. Set `dateModified` only when the content
actually changes, never on a rebuild.

## Measurement

Measurement is Google Analytics 4, loaded only after permission, with automatic
page views turned off so the one manual `page_view` per navigation cannot be
duplicated. Page type is derived from the route in `pageTypeOf`, so no page can
declare a second one.

| Event | When |
| --- | --- |
| `page_view` | Once per navigation, after consent. Path only, query and fragment stripped |
| `tool_start` | First meaningful viewer action: a file is chosen |
| `tool_complete` | `workbook_opened`, `read_failed` or `csv_exported` |
| `related_content_click` | Reserved; not yet wired to a placement |

File names, sheet names and cell values never enter an event. `sanitizePath` is
unit-tested against query strings, fragments and tokens.

Setup, when a property exists: create the GA4 property, set its timezone, set
`NEXT_PUBLIC_GA_MEASUREMENT_ID`, rebuild, and confirm in a browser that no
request is made before a choice. Report the first 28-day window only once real
data exists.

## Advertising

Ads are `disabled` by default and the state is configuration, not something
inferred from an ID being present. `preview` renders labelled placeholder space
and makes no request. `pending-review` renders nothing. `live` requires a real
publisher ID (`ca-pub-` plus 16 digits) and a real numeric slot ID; a placeholder
value cannot turn ads on, and there is a test that proves it.

Eligible routes are articles, feature pages and the viewer. The home page,
about, privacy, terms and error pages are excluded, and so is every index page.
Slots sit at a content boundary after the first section, never inside the
viewer's controls.

Before switching to `live`, work through section 5 of the monetization
specification: publisher account and site approval, ownership verification over
HTTPS, real IDs, a root `ads.txt` with the seller record the account gives you,
a certified CMP for personalised ads in the EEA, UK and Switzerland, the audience
classification, and a visual check with ads filled, empty, slow and blocked. None
of that is done; see [SITE-BRIEF.md](SITE-BRIEF.md) for the current blockers.

## Layout

```
src/site/         configuration, product facts, content registry, URL/schema helpers
src/components/   shell, article layout, consent, ads, the viewer
src/lib/          the client-side ZIP reader and XLSX parser
src/app/          routes, sitemap, robots
scripts/          share card, preview server, build verifier, content validator
tests/            node:test suites
```

Two rules hold the site together: every public fact comes from `src/site/` and
nothing else, and every URL comes from `src/site/urls.ts` and nothing else.
