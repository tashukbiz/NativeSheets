# Content plan

The intent-to-URL map for the Native Sheets site. Every published page below
exists in the content registry (`src/site/content/`), and the registry is what
generates listings, metadata, related links and the sitemap.

## Research basis

No keyword research tool was available during this build. **All demand below is
a hypothesis**, derived from the questions the product itself answers and the
phrasing of the problems it solves. No search volumes, difficulty scores or
rankings are claimed, because none were measured. Product facts, by contrast,
are verified: their sources are listed in [SITE-BRIEF.md](SITE-BRIEF.md).

Revisit this file once real Search Console data exists, and let observed queries
choose the next articles rather than a publishing quota.

## Published set

### 1. The free browser tool

| Field | Value |
| --- | --- |
| Cluster | Opening an .xlsx file without software: "open xlsx online", "view excel file without excel", "xlsx viewer" |
| Intent and audience | Someone has a workbook and no spreadsheet application, or does not trust the sender enough to open it in one. They want to see the contents now. |
| Primary URL | `/viewer/` |
| Page type | Tool |
| Distinct value | A working client-side reader: every sheet, cell values, the formula behind a cell, CSV export. Nothing is uploaded. |
| Product fit | The natural first contact. Readers who then need to edit are told about the macOS app, with its actual access conditions. |
| Next action | Use the tool; then the guides, or the app. |
| Evidence | Behaviour verified against a real workbook in a browser; limits stated on the page itself. |
| State | Published 17 September 2026 |

### 2. How to open and edit an .xlsx file on a Mac without Excel

| Field | Value |
| --- | --- |
| Cluster | "open xlsx on mac without excel", "edit excel file mac free", "excel alternative macos" |
| Intent and audience | A Mac user without a Microsoft 365 subscription who needs to read or change a workbook. |
| Primary URL | `/blog/open-xlsx-on-mac-without-excel/` |
| Page type | Tutorial with a comparison |
| Distinct value | A four-option comparison that answers what each option does to the file, not just whether it opens it. Quick Look and the browser viewer are offered as the read-only answers they are. |
| Product fit | Native Sheets is one of the four options, presented with its real constraint (build from source). Alternatives are named honestly. |
| Next action | The viewer, or the round-trip feature page. |
| Evidence | Product facts from the app repository. Behaviour of other applications is described in terms of the save strategy they use, and the article shows the reader how to check their own tools rather than asking them to trust a claim. |
| State | Published 17 September 2026 |

### 3. Why charts and pivot tables disappear when you edit someone else's workbook

| Field | Value |
| --- | --- |
| Cluster | "excel lost charts after saving", "xlsx pivot table disappeared", "what is inside an xlsx file" |
| Intent and audience | Someone who already lost something in a round trip, or who has to hand a file back and does not want to. |
| Primary URL | `/blog/keep-charts-when-editing-xlsx/` |
| Page type | Use case, with a worked diagnostic |
| Distinct value | Explains the actual package structure, why model-and-serialise saves drop parts, and gives a runnable `unzip`/`diff` procedure to test any tool the reader already uses. |
| Product fit | Native Sheets' preservation is the direct answer, stated with its limitation: preserved is not editable. |
| Next action | The round-trip feature page, or the viewer to compare two files. |
| Evidence | `ARCHITECTURE.md` round-trip section; the sample-workbook measurements and the openpyxl cross-check. |
| State | Published 17 September 2026 |

### 4. Will my formulas work?

| Field | Value |
| --- | --- |
| Cluster | "does it support vlookup", "spreadsheet app formula support", "xlsx editor formulas" |
| Intent and audience | Someone deciding whether the app can replace their current tool for a specific workbook. A constraint question, not a how-to. |
| Primary URL | `/blog/will-my-formulas-work/` |
| Page type | Reference and decision |
| Distinct value | The complete list of all 91 evaluated functions, by area, plus what is missing and what happens to a formula the engine cannot evaluate. Includes the repository's own opt-in command for testing a specific workbook. |
| Product fit | Deliberately tells some readers the answer is no. |
| Evidence | The function list was extracted from the evaluator's dispatch in the app source, not from the README's summary. |
| State | Published 17 September 2026 |

### 5 and 6. Feature pages

| URL | Cluster | Distinct value |
| --- | --- | --- |
| `/features/round-trip-fidelity/` | Round-trip loss | The part-by-part table of what is regenerated versus copied, with the measurements and the command to reproduce them |
| `/features/formulas/` | Formula support | The recalculation model: precedents at parse time, topological order, cycle detection, reference shifting, with a worked example |

Each feature page owns the mechanics of one capability; the articles own the
reader's question. They link to each other rather than repeating.

## Scope exception

`CONTENT-SEO.md` sets a default of three complete articles plus one to three
feature pages. That default is met exactly: three articles, two feature pages,
and one tool page. No fourth article was written, and the **quality exception**
is the reason: the remaining honest topics either repeat one of the four above
or need facts that do not exist yet (see deferred, below). Publishing a thin
fifth page would not help a reader.

## Deferred topics, and what each needs first

| Topic | Blocked on |
| --- | --- |
| "Native Sheets vs LibreOffice Calc vs Numbers", a real comparison | Current version numbers and re-tested round-trip behaviour for each, on a dated test workbook. A comparison that is not re-verified becomes wrong quietly. |
| "How to install Native Sheets", a download walkthrough | A signed, notarised build or a store listing. Today the honest instruction is one build command, which already fits inside the existing pages. |
| "Keyboard shortcuts reference" | Worth writing, but it duplicates what the app's own menus show, and there is no way for a reader to try it before building the app. |
| Release notes or product updates | There is no release history to write about: the repository has no tagged versions. |
| "Reading .xls (the old format)" | The product does not support it. The page would exist only to catch a query. |

## Maintenance

- Update `src/site/product.ts` whenever the app's capabilities or limits change;
  the home page, feature pages and schema all read from it.
- Re-extract the function list when the evaluator changes, and set
  `dateModified` on `/blog/will-my-formulas-work/` when it does.
- `dateModified` means a real content change, never a rebuild.
- Renaming a slug requires a host-level redirect and an update to every internal
  link; the validator will catch the broken references, not the missing redirect.
