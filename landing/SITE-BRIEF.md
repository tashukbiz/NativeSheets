# Site brief: Native Sheets

Resolved decisions, evidence, assumptions and launch blockers for the landing
site in this directory. Written against the landing specification pack
(`SPEC.md`, `CONTENT-SEO.md`, `MONETIZATION.md`, `ACCEPTANCE.md`).

## Profile and primary action

| Decision | Value | Source |
| --- | --- | --- |
| Profile | `ad-supported-web` | Given in the build prompt |
| Primary action | Open a workbook in the browser viewer (`/viewer/`) | Profile requirement: a working free browser experience |
| Secondary action | Read the guides, then build the macOS app from source | The app has no store listing or signed download |
| Audience | Adults working with spreadsheet files on macOS | Inferred from the product; recorded because it gates ad activation |
| Language | English (en-US) | Prompt |
| Hosting | GitHub Pages, static export | Prompt |

The macOS app cannot be the primary call to action: it has no installable
artifact today. The browser viewer is a real tool that does useful work with no
install, which is exactly what this profile asks for, so the site leads with it
and treats the app as the thing you graduate to.

## Product facts and where they came from

Every product claim on the site is traceable to the app repository at
`../native-sheets`. They live in one place, [`src/site/product.ts`](src/site/product.ts),
and are rendered from there on every page.

| Fact | Evidence |
| --- | --- |
| macOS 14 or later, Swift 6 toolchain (Xcode 16+) | `native-sheets/README.md`, `Package.swift` (`platforms: [.macOS(.v14)]`), `Resources/Info.plist` (`LSMinimumSystemVersion 14.0`) |
| Free, no third-party dependencies | `README.md`, `ARCHITECTURE.md` |
| Round-trip fidelity: only modelled parts are rewritten | `ARCHITECTURE.md`, "Round-trip fidelity" |
| 91 evaluated function names, listed in full | Extracted from `Sources/XLSXKit/Formula/FormulaFunctions.swift` and `FormulaFunctionsText.swift` (91 unique dispatched names) |
| Array formulas, `INDIRECT`, `OFFSET`, defined names not evaluated | `README.md`, "Limits" |
| Benchmarks (open 0.09 s, save 0.11 s, recalculate 0.41 s, 20,739/20,739 cells, 4,530/4,530 formulas, openpyxl cross-check) | `README.md`, "Measured on the sample workbook" |
| Not displayed or editable: charts, images, pivot tables, conditional formatting; no find and replace, sorting, filtering or comments | `README.md`, "Limits" |
| Build command `./Scripts/make_app.sh`, producing `XLSX Editor.app` | `Scripts/make_app.sh` |

Nothing about prices, ratings, download counts, reviews, awards or release dates
is published, because none of it exists.

## Assumptions recorded

1. **The product is called Native Sheets.** The prompt says so. The repository
   still calls it "XLSX Editor" (`Info.plist`, `Package.swift`, the built bundle
   name). The site uses Native Sheets throughout and states plainly, where it
   matters, that the built bundle carries the old working title. Renaming the
   app is out of scope for this task.
2. **Availability is "source-available", not "released".** There is no store
   listing and no signed, notarised download in the repository, so the site
   never offers a download button and says why.
3. **The operator is the repository account `tashuk`.** That is the only
   verified identity (git author on this repository, and the support address
   given in the prompt). No company, legal entity or postal address is claimed.
4. **The browser viewer is new work, built for this site.** It reuses no code
   from the Swift app: it is an independent client-side reader
   (`src/lib/zip.ts`, `src/lib/xlsx.ts`). Its limits are stated on its own page
   rather than implied by the app's capabilities.
5. **No dark mode.** The specification says not to add one unless it can be
   verified across every page and state. It was not, so the site is light only.
6. **The illustration on the home page is a drawing, not a screenshot**, and its
   caption says so. There is no authentic screenshot of a build in the
   repository to use.

## Configuration

All integration configuration is centralised in
[`src/site/config.ts`](src/site/config.ts) and read from environment variables at
build time. Every one of them is unset by default, which disables the feature.

| Variable | Default | Effect when unset |
| --- | --- | --- |
| `NEXT_PUBLIC_SITE_ORIGIN` | unset | Falls back to `http://localhost:4173`; the build is marked non-production and `robots.txt` disallows crawling |
| `NEXT_PUBLIC_BASE_PATH` | empty | Site is served from the domain root |
| `NEXT_PUBLIC_GA_MEASUREMENT_ID` | unset | No measurement script, no requests, no analytics-only banner |
| `NEXT_PUBLIC_AD_STATE` | `disabled` | No ad markup, no ad requests |
| `NEXT_PUBLIC_ADSENSE_CLIENT` | unset | Ads cannot enter `live` |
| `NEXT_PUBLIC_ADSENSE_SLOT_ARTICLE` / `_TOOL` | unset | The corresponding slot cannot request |

## Launch blockers

These are external inputs that this implementation cannot supply. The site is
complete and verified locally without them, but it is not launch-ready until
they are resolved.

1. **Production domain.** Recorded as TBD in the prompt. Until
   `NEXT_PUBLIC_SITE_ORIGIN` is a real HTTPS origin, the build is marked as a
   preview: `robots.txt` disallows crawling and every page carries `noindex`.
   This is deliberate, so an unfinished preview cannot be indexed.
2. **GitHub Pages target.** A project site needs `NEXT_PUBLIC_BASE_PATH` set to
   the repository name; a user site or custom domain needs it empty. Both shapes
   are implemented and both have been verified, but which one applies is not
   known yet.
3. **Operator identity for policy pages.** The privacy and terms pages currently
   identify an individual by account name and an email address. If the site is
   published in a jurisdiction that requires a fuller operator disclosure, that
   information has to come from the owner; it will not be invented here.
4. **Advertising activation.** Everything in `MONETIZATION.md` section 5 is
   outstanding: a publisher account, site approval, real publisher and slot IDs,
   a certified CMP for EEA/UK/Swiss personalised ads, and an `ads.txt` seller
   record supplied by the account. No `ads.txt` is shipped, because inventing or
   copying a seller record would be worse than having none. Ads stay `disabled`.
5. **Measurement property.** No Google Analytics property exists for this site.
   Until one does, measurement is off and the consent banner does not appear,
   because there is nothing to ask permission for.
6. **Search console verification.** No property has been created or verified, and
   no verification token is present. Sitemap submission is an external task.

## Deliberate non-goals

No authentication, CMS, comments, newsletter, localisation or backend. No
`ads.txt` until a real seller record exists. No store badges, no waitlist form
(a non-functional signup would be worse than none), and no `llms.txt`: it is
optional and would be one more file to keep in sync with the content registry.
