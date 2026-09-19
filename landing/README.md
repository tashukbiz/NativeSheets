# Landing site

The website for Native Sheets. Next.js App Router, static export, no backend.

Published to GitHub Pages at https://tashukbiz.github.io/nativesheets/ by `.github/workflows/pages.yml` on every push to `main`.

```bash
pnpm install
pnpm dev
```

## Commands

| Command | Action |
| --- | --- |
| `pnpm dev` | Development server |
| `pnpm build` | Exports the static site to `out/` |
| `pnpm preview` | Serves `out/` at http://localhost:4173 |
| `pnpm check` | Typecheck, lint, test, build and verify |

`pnpm verify` compares the sitemap against the exported HTML files. It checks canonicals, social metadata, JSON-LD, internal links, orphan routes and placeholder text. Any disagreement fails the build.

## Configuration

Build-time environment variables. Each one is off when unset.

| Variable | Effect |
| --- | --- |
| `NEXT_PUBLIC_SITE_ORIGIN` | Public origin. Must be HTTPS. Without it, every page gets `noindex` |
| `NEXT_PUBLIC_BASE_PATH` | Sub-path for a project site. `/nativesheets` here |
| `NEXT_PUBLIC_GA_MEASUREMENT_ID` | Enables analytics and the consent banner |
| `NEXT_PUBLIC_AD_STATE` | `disabled`, `preview`, `pending-review` or `live` |
| `NEXT_PUBLIC_ADSENSE_CLIENT` | Publisher ID. Required for `live` |
| `NEXT_PUBLIC_ADSENSE_SLOT_ARTICLE` | Slot ID for article pages |
| `NEXT_PUBLIC_ADSENSE_SLOT_TOOL` | Slot ID for the viewer page |

## Content

Content is typed records under `src/site/content/`. There is no CMS.

1. Add a file under `src/site/content/articles/` or `features/`. Export one `ContentRecord`.
2. Register it in `src/site/content/index.ts`.
3. Run `pnpm content:validate`.

The registry validates on import. A broken record fails the build. Records with `status: "draft"` do not appear in listings or the sitemap.

## Ads

Ads are `disabled`. To enable them you need an approved AdSense account, a real publisher ID, real slot IDs, a root `ads.txt`, and a certified CMP for the EEA, UK and Switzerland.

Eligible routes are articles, feature pages and the viewer. The home page, about, privacy, terms and error pages carry no ad slots.

## Layout

```
src/site/         configuration, product facts, content registry
src/components/   shell, article layout, consent, ads, viewer
src/lib/          client-side ZIP reader and XLSX parser
src/app/          routes, sitemap, robots
scripts/          share card, preview server, verifier, validator
tests/            node:test suites
```

Two rules: every public fact comes from `src/site/`, and every URL comes from `src/site/urls.ts`.
