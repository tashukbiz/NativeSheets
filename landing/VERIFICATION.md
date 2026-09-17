# Verification

Checks from the landing acceptance specification, run against this
implementation on **17 September 2026**.

- **Completion state: Implementation verified.** The local site works, every
  applicable local check passes, and the external inputs it still needs are
  listed in [SITE-BRIEF.md](SITE-BRIEF.md).
- **Not launch-ready:** the production domain is unresolved, so the build is
  deliberately marked as a preview (`noindex` everywhere, `robots.txt`
  disallowing crawling).
- **Ads not active**, and not submitted for review. State is `disabled`.

Preview location: `out/`, served at `http://localhost:4173` with
`pnpm preview`. Screenshots and browser measurements were taken live in the
session that produced this file, against that server; they are described below
rather than committed as image files.

Commands used:

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build && pnpm verify
```

## Shared implementation checks

| ID | Result | Evidence |
| --- | --- | --- |
| C01 | PASS | [SITE-BRIEF.md](SITE-BRIEF.md) records the profile, audience, primary action, every product fact with its source in the app repository, six assumptions and six launch blockers |
| C02 | PASS | `pnpm install` from the committed `pnpm-lock.yaml`; `pnpm typecheck` clean, `pnpm lint` clean, `pnpm build` exports 16 routes, `pnpm test` 36 passing |
| C03 | PASS | Walked home → `/blog/` → `/blog/will-my-formulas-work/` → `/viewer/` → opened a workbook, in the browser. Contact (`/about/`), privacy and terms all reachable from the footer of every page |
| C04 | PASS | Three articles, two feature pages, one tool page, all with real bodies, worked examples and dated authorship. Scope exception and deferred topics recorded in [CONTENT-PLAN.md](CONTENT-PLAN.md) |
| C05 | PASS | All ten page templates inspected at 360, 768, 1200 and 1440 px. Consent banner and preference panel inspected in a build with measurement configured |
| C06 | PASS | See the accessibility section below |
| C07 | PASS | `pnpm verify` scans rendered output for placeholder copy, dummy domains, `href="#"`, unresolved JSON-LD values and missing assets; all clean |
| C08 | PASS | See the integration-failure section below |

### Accessibility (C06)

| Check | Result |
| --- | --- |
| Skip link | PASS. First Tab on any page reveals "Skip to content", which moves focus to `#main` |
| One H1, no skipped heading levels | PASS. Scripted audit of the rendered DOM: exactly one H1 per page, no level jumps |
| Visible focus | PASS. `:focus-visible` outline, 3 px, offset 2 px, on every interactive element |
| Contrast, WCAG 2.2 AA | PASS. Scripted audit computing the real rendered foreground/background ratio for every text node on all ten templates: zero failures. One real failure was found and fixed during this run (`--ink-faint` at 4.41:1 on the surface background, darkened to clear 4.5:1) |
| Touch targets | PASS. Every button, CTA and sheet tab measured at 375 px: none below 44 px high |
| Reflow, no horizontal overflow | PASS. At 360 px, every template has `scrollWidth` at or below the viewport. Wide tables and the workbook grid scroll inside their own containers |
| Reduced motion | PASS by construction. There is no animation or transition on the site; the `prefers-reduced-motion` block is a guard, not a fix |
| Labelled controls | PASS. The file input has a real `<label>`; consent checkboxes are wrapped in labels; the ad slot and grid carry `aria-label` |

## Rendered discovery checks

`pnpm verify` derives expectations from the build rather than a hardcoded list:
the sitemap is generated from the content registry, the exported HTML files are
the routes that exist, and disagreement in either direction fails.

Result on the default build: **15 pages, 12 indexable, 12 sitemap entries, all
checks passed.**

| ID | Result | Evidence |
| --- | --- | --- |
| S01 | PASS | Every sitemap URL resolves to an indexable page in the build and every indexable page appears in the sitemap. Drafts cannot leak: they are excluded from `generateStaticParams`, listings and the sitemap, and there is a test for it |
| S02 | PASS | Per page: exactly one H1, a non-empty unique title and description, a document language, one canonical, more than 120 words of copy in the initial HTML |
| S03 | PASS | Canonical, `og:url` and sitemap URL agree on origin and the trailing-slash policy on every page. Asset URLs carry no route slash and resolve in the build. Verified in three configurations: preview origin, production origin, and production origin with a `/xlsx-editor` base path |
| S04 | PASS | Every internal link target exists in the build, every `#fragment` matches a real id, and every indexable route except the home page has at least one incoming internal link |
| S05 | PASS | Every JSON-LD block parses; values are escaped against `</` so a string cannot end the script element; no invented offers, prices, ratings or reviews are emitted |
| S06 | PASS | Sitemap `lastmod` comes from content dates only, and is omitted where there is no date. The preview build carries `noindex` and a disallowing `robots.txt`; a build with an HTTPS origin does not inherit either, confirmed by rebuilding with `NEXT_PUBLIC_SITE_ORIGIN` set |
| S07 | PASS | The registry validates on import, so a bad record fails the build. Nine negative tests cover missing body, duplicate route, invalid date, publication without a date, unknown related id, link to a draft, and self-reference |

**JavaScript disabled:** PASS. The initial HTML of `/viewer/` contains the full
explanation, instructions, limits and privacy text, plus a `<noscript>` block
that states the viewer itself needs JavaScript and points to the macOS app.
Navigation and all article content are plain server-rendered HTML.

**Unknown routes:** PASS. `curl` against the preview server returns `404` for
`/nope/` and serves the built `404.html`, which lists real recovery links.
GitHub Pages serves `404.html` with a 404 status.

## Ad-supported-web behaviour

| ID | Result | Evidence |
| --- | --- | --- |
| W01 | PASS | Opened a real workbook in the browser: two sheets read, cell values, dates formatted from the style's number format, formula text shown for `=B2*C2` and `=SUM(D2:D4)`, sheet switching, CSV export with correct quoting, and "Close workbook" to restart. A CSV file produced the error "This file is not a ZIP archive, so it is not an .xlsx workbook" with a working "Try another file" recovery. A non-workbook ZIP produced a distinct message. An empty sheet reads as empty, not as an error |
| W02 | PASS | No install, payment, account or consent is involved. With no purposes configured there is no banner at all, and the viewer works identically before and after any choice, including after a withdrawal |
| W03 | PASS | Tool inputs never enter measurement. Opened a file named `confidential-salaries-2026.xlsx` with measurement granted: the transmitted events contain only `tool_id`, `placement`, `outcome` and the profile. Asserted that neither the file name nor a cell value appears anywhere in the payloads. `sanitizePath` strips query strings, fragments and tokens, with unit tests |
| W04 | PASS | `disabled` and `pending-review` render nothing and request nothing. `preview` renders a labelled deterministic placeholder and makes no request, confirmed in a browser. `live` cannot request with a missing or placeholder publisher ID or slot ID; four placeholder shapes are covered by tests |
| W05 | PASS | One `AdSlot` abstraction with a stable placement id, reserved responsive space (100 px minimum, 250 px from 768 px up), a visible "Advertisement" label and an `aria-label`, dashed border to separate it from content, placed at a content boundary after the first section and never inside the viewer's controls. Initialised at most once per mount via a ref guard. Eligible routes are articles, feature pages and `/viewer/` only; home, about, privacy, terms and all index pages are excluded, with tests |
| W06 | PASS (simulated) | Blocked and unfilled states were simulated locally: with ads not permitted, the slot renders reserved space and the page is unaffected; the initialisation call is wrapped so a blocked provider cannot throw into the page. CLS measured at 0 on the home page, an article and the viewer. **No test requested or clicked a live ad, and none can:** `live` requires real IDs that do not exist |
| W07 | Externally pending | Nothing is submitted or approved. The full activation checklist is in README.md and the blockers in SITE-BRIEF.md. No `ads.txt` is shipped, because the seller record must come from a real account |

**Viewer performance.** A 24,000-cell workbook (2,000 rows by 12 columns,
124.5 KB) parsed and rendered in **139 ms** from the file-change event to the
grid being on screen. A 2,500-row sheet correctly showed 2,000 rows and the
documented truncation notice.

## Consent and measurement

Verified in a browser against a build with `NEXT_PUBLIC_GA_MEASUREMENT_ID` and
`NEXT_PUBLIC_AD_STATE=preview` set, and against the default build.

| State | Expected | Result |
| --- | --- | --- |
| No analytics ID (default build) | No requests, no banner | PASS. No banner, no cookies, no local storage keys, no ad slots, and the footer reads "No optional tracking" |
| No choice made | No measurement, no ad requests | PASS. Banner shown; `window.gtag` undefined; zero provider scripts in the document |
| Rejection | Nothing loads | PASS. Choice stored as both purposes denied; no provider script; banner dismissed |
| Analytics accepted, ads denied | Measurement may run, ads stay off | PASS. The GA script loads, `send_page_view: false` is configured, and the ad slot stays a preview placeholder with no ad script |
| Withdrawal | Requests stop, reachable identifiers cleared | PASS. Reopened the panel from the footer, chose "Reject all": stored decision flipped to denied and a seeded `_ga` cookie was removed. The viewer kept working with its workbook still open |
| Storage blocked | Usable site, no inferred permission, no crash | PASS. With `localStorage` throwing on both read and write, the banner still appeared (permission was not inferred), accepting did not throw, the choice applied for the session, and the page stayed usable |
| Client navigation / repeated mount | No duplicate page views | PASS after a fix. The first run produced **two** `page_view` events per view, because both the layout and each page rendered an analytics component. Analytics is now mounted once in the layout and derives the page type from the route. Re-verified: one event per navigation across article → index → article, with correct page types, and a regression test covers the mapping |
| Sensitive URL or input | Nothing personal transmitted | PASS. See W03 |
| Privacy signal | Treated as refusal | Implemented: `navigator.globalPrivacyControl === true` is read at hydration and fixes both purposes to denied without asking. **NOT RUN in a browser:** the preview browser does not send the signal, so the code path is verified by reading it, not by observing it |

Rejecting is as easy as accepting: "Reject", "Choose" and "Accept" are the same
kind of button, in that order, with nothing preselected in the detail panel.

## Integration failure behaviour (C08)

| Simulation | Result |
| --- | --- |
| No configuration at all | PASS. This is the default build: every integration off, site fully usable |
| Provider script blocked | PASS. The slot initialisation is inside a `try`; measurement calls no-op when `window.gtag` is absent |
| Storage unavailable | PASS. Both read and write are guarded; verified in a browser |
| Failed external request | PASS by construction. The site makes no third-party request in its default state: a resource audit of a loaded article recorded **zero** cross-origin requests |
| Decompression unsupported | PASS. The parser checks for `DecompressionStream` and reports a readable message naming what is needed, rather than throwing |

## Performance

Lab measurements from the preview server, which serves uncompressed responses.

| Metric | Home | Article | Viewer |
| --- | --- | --- | --- |
| CLS | 0 | 0 | 0 |
| Cross-origin requests | 0 | 0 | 0 |
| Transfer, uncompressed | 538 KB | 520 KB | 523 KB |
| `DOMContentLoaded` | — | 44 ms | — |

- **LCP and INP: NOT RUN.** The preview browser does not expose paint timing or
  event timing, so neither could be measured here. They are not reported as
  passing. Measure them on the real host once a domain exists.
- **Field Core Web Vitals: NOT RUN, and cannot be run from a local build.** No
  field data exists for a site that is not published.
- The transfer figures are the Next.js App Router runtime, served without
  compression by the local preview server. A real host serves these compressed;
  that figure has not been measured. There are no images on any page except the
  inline SVG illustration and the social card, which is metadata only.

## Not run, and why

| Check | Reason |
| --- | --- |
| Live host checks (HTTPS, status codes, redirects, content types, caching) | Nothing is deployed. Deployment was not requested |
| Search property verification and sitemap submission | No property exists; no account was accessed |
| Real CMP integration | No CMP is configured; a certified one is an activation blocker |
| Live ad rendering, fill, and filled/slow-ad layout | Requires an approved account. No test may request or click a live ad |
| Cross-browser check beyond the preview browser | Only one engine was available in this session. The viewer depends on `DecompressionStream`, which is current-browser-only, and degrades with a readable message where it is absent |

## Fixes made during verification

Three real defects were found by these checks and fixed, not documented around:

1. **Duplicate `page_view` events** on every page, from two analytics component
   instances. Analytics is now mounted once and derives page type from the
   route. Regression test added.
2. **Base path applied twice** to every internal link, found by the verifier's
   internal-link check when building for a GitHub project site. `next/link`
   already prefixes the base path; the URL helper no longer does.
3. **Invisible header CTA text**, from a navigation colour rule overriding the
   button's own. Found by looking at a screenshot, not by any automated check.

One contrast failure (`--ink-faint` at 4.41:1 on the surface background) was
also found and fixed, as recorded under C06.
