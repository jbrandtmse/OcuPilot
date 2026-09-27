---
title: 'Story 16.23: Any table, downloaded as CSV'
type: 'feature'
created: '2026-09-27'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot's data table has no way to take its rows elsewhere; an administrator copies rows by hand to get a list into a spreadsheet (owner survey 2026-09-26: IRISOperationsPortal offers a CSV download on every table).

**Approach:** Every mounted data table registers a Download CSV handler on the existing `ScreenActions` seam, as a page registers Refresh, and the command bar draws the control while the handler is registered and the screen's read has landed. The handler encodes the table's own view (its filter and sort, its declared columns under their header labels, each cell as displayed) with a small in-house encoder and saves it from a Blob in the browser. There is no server change.

## Boundaries & Constraints

**Always:**

- The file is the table's view as the table computes it (`applyView` over the store, filter then sort), with the table's declared columns in order and a header row of the table's own header labels. Nothing outside those columns is written.
- A cell is written as the table displays it (`cellView`'s text: Yes/No, a declared `emptyKey` word). The "(none)" placeholder cell is written empty, and a column still in `pendingFields` is written empty.
- Formula guard: a cell whose text starts with `=`, `+`, `-`, `@`, a tab or a carriage return gets a leading `'`. RFC 4180 quoting then applies: a field containing `"`, `,`, CR or LF is double-quoted with inner quotes doubled.
- UTF-8 with a leading BOM (written `'﻿'`, Rule 14), CRLF line ends, Blob type `text/csv;charset=utf-8`. The file is named `<slug>-<YYYYMMDD>-<HHMMSS>.csv`, where the slug is the screen label lower-cased with each run of anything outside `[a-z0-9]` turned into one `-` and trimmed (or `table` if nothing is left), and the time is the browser's local time.
- The save is an in-document anchor with `download` set to the name and `href` set to an object URL, clicked and removed; the URL is revoked on a later task. No request leaves the page and nothing navigates.
- At the cap (the read has landed and `store.truncated()`), the control is described (`aria-describedby`, the `.ocu-command-bar-reason` tooltip) by `formatCapNotice(STRINGS.tableDownloadCsvCapped, maxRows)`. The two new strings go into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change.

**Never:**

- No server route, ObjectScript, tool, governance key, descriptor or per-screen edit. No third-party CSV library or other new dependency. No lazy loading or `@defer`.
- The button never takes the `ocu-command-bar-action` class: ten browser specs enumerate that class as the screen's row actions. The command box does not list it; it is a view control like Sort (EXPERIENCE.md :601 says so).
- No new EXPERIENCE.md line: the edits are in place at :313, :601 and :650, so no later citation shifts. No `_components.scss` change: the control is `ocu-button-text`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Filtered, sorted list | Web applications, filter typed, sort Descending | The file's rows are the grid's rows in grid order, their count equals the footer's; the header is the header cells' labels | none |
| Formula text | cells `=1+1`, `+x`, `-5`, `@a`, `\tx`, `\rx`, `a=b` | `'=1+1`, `'+x`, `'-5`, `'@a`, `'\tx`, `"'\rx"`; `a=b` unchanged | none |
| Quoting | `a,b`, `say "hi"`, `l1\nl2` | `"a,b"`, `"say ""hi"""`, `"l1\nl2"` | none |
| Withheld field | row carries `Password` and other undeclared fields | absent from the file; only declared columns | none |
| Empty / pending | `''`/null cell; `emptyKey` column; pending column | empty; the `emptyKey` word; empty | none |
| Zero rows | loaded, empty state | header row only | none |
| Not yet loaded | skeleton, or a refusal before the first read | no control drawn | none |
| At the cap | Max rows 2, read truncated | description "The file holds the first 2 rows only."; the file has 2 data rows | none |
| Label with no ASCII letters | lookup gives `''` or symbols | name `table-<YYYYMMDD>-<HHMMSS>.csv` | none |

</intent-contract>

## Code Map

- `ui/src/app/shell/data-table.ts`:
  - `view` :547-557 is the rows; `columns` :559;
  - header labels are `this.lookup(column.labelKey)` :841, and a cell is `cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '', this.lookup)` :637;
  - `pendingFields` :464; `gridLabel` :788 (the screen label);
  - `ngOnInit` :722-726 (register here, remove in `destroyRef`), because `screen()` is an input; the `ScreenActions` injection is already at :471.
- `ui/src/app/core/screen-actions.ts`: `REFRESH_ACTION_ID` :29. Add `DOWNLOAD_CSV_ACTION_ID = 'download-csv'` beside it. `command-box.ts` :485-493 lists only Refresh and declared ids, so it stays untouched.
- `ui/src/app/shell/command-bar.ts`:
  - the Refresh button :304-312 and `hasRefreshAction` :648-663 are the pattern;
  - `hasContent` :587-597;
  - `matchCount` :605-617 is the "read has landed" test (`refresh.descriptor() === screen.descriptor && refresh.hasLoaded()`);
  - the reason-tooltip slot is :185-201 (`.ocu-command-bar-action-slot`, `.ocu-command-bar-reason` `role="tooltip"`, `aria-describedby`);
  - the store is `this.stores.for(screen.descriptor, screen.refreshRates)`, with `truncated()` and `maxRows()` (`screen-store.ts` :239/:464).
- `ui/src/app/core/table-model.ts`: `cellView` :86-120 (`empty` marks the placeholder), `fieldOf` :29, `formatCapNotice` :162 (`<n>`, digits grouped).
- `ui/src/app/core/strings.ts`: append before `} as const` :3102. `tableRowCapNotice` :322 cites `EXPERIENCE.md:313`. `ui/tools/strings.test.mjs` :773 pins every `/** EXPERIENCE.md:N */` citation.
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`):
  - :313 is the cap-notice Fixed strings row;
  - :601 is the command-bar row ("…sort; the auto-refresh chip…; Refresh.");
  - :650 is the data-table paragraph ("Selection, sort, filter…").
- Tests to extend:
  - `ui/src/app/shell/data-table.spec.ts`: `new ScreenActions()` :102;
  - `command-bar.spec.ts`: the Refresh tests before :1166; the reachability test at :1166 stays unchanged because it selects `.ocu-command-bar-action`.
- Browser helpers:
  - `browser/panel-spec.mjs` `signedInAt` :62 (resets remembered state, as `tools/browser-reset.mjs` requires);
  - `browser/list-spec.mjs` `ROW_SELECTOR`, `FILTER_SELECTOR`, `waitForRows`, `viewCount`;
  - the footer field `.ocu-data-table-max-rows`;
  - `panel.browser-spec.mjs` :819-842 pins Databases' bar to one line at 832px.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- make three in-place edits and add no line:
  - :313 becomes `| "Showing the first <n> rows. Narrow the filter or raise the max rows." · "Download CSV" · "The file holds the first <n> rows only." | data-table at the cap; `<n>` resolves to the max-rows cap (`:389`); the command-bar's Download CSV control on every screen built on the data-table, and its description at the cap, which repeats the cap notice's words (Story 16.23) [AMENDED 2026-09-27 - Story 16.23] |`;
  - :601 gains `Download CSV on every screen built on the data-table (a view control like sort, so the command-box does not list it);` after `sort;`;
  - :650 gains one sentence stating the Boundaries' file contract (view, columns, header, displayed text, formula guard, UTF-8, name, browser-built, cap description), ending `[AMENDED 2026-09-27, Story 16.23]`.
- `ui/src/app/core/strings.ts` -- append `tableDownloadCsv: 'Download CSV'` and `tableDownloadCsvCapped: 'The file holds the first <n> rows only.'`, each under `/** EXPERIENCE.md:313 */`.
- `ui/src/app/core/csv.ts` (new, framework-free) -- add `csvField`, `csvText(header, rows)` (BOM, CRLF), `tableCsvRows(rows, columns, lookup, pendingFields)` over `cellView`, and `csvFileName(label, date)`.
- `ui/tools/csv.test.mjs` (new) -- cover every matrix row except the browser-only ones, round-trip a quoted field through a minimal RFC 4180 parse, and include a header-only case.
- `ui/src/app/core/screen-actions.ts` -- export `DOWNLOAD_CSV_ACTION_ID` with a one-line doc: a view control the data table registers, which the command box does not list.
- `ui/src/app/shell/data-table.ts` -- in `ngOnInit`, register `DOWNLOAD_CSV_ACTION_ID` for `screen().descriptor` and remove it on destroy. The handler builds from `view()`, `columns()`, `lookup`, `pendingFields()` and `gridLabel`, then saves as in Boundaries.
- `ui/src/app/shell/command-bar.ts` -- after Refresh, draw `<span class="ocu-command-bar-action-slot"><button class="ocu-button-text ocu-command-bar-download">{{ STRINGS.tableDownloadCsv }}</button>` plus the capped reason span while at the cap. Draw it while registered and loaded, run it via `actions.run`, and add it to `hasContent`.
- `ui/src/app/shell/data-table.spec.ts`, `ui/src/app/shell/command-bar.spec.ts` -- add component tests for the ACs below. Stub `URL.createObjectURL`/`revokeObjectURL` and spy on the anchor's `click`, then read the Blob with `text()`.
- `ui/browser/csv-download.browser-spec.mjs` (new) -- save through CDP `Browser.setDownloadBehavior` to a temp directory and read the file from disk. Restore Max rows in `finally`. Never assert an exact count on a `filterToSubset` result (client-lint).

**Acceptance Criteria:**

- Given Web applications in HSCUSTOM with a filter typed and sort Descending, when Download CSV is pressed, then a file named `^web-applications-\d{8}-\d{6}\.csv$` lands on disk; it starts with the BOM; its header is the header cells' labels in order; its data-row count equals the footer's count; and its first rendered rows equal the grid's rendered rows cell for cell (the "(none)" placeholder written empty).
- Given a data table mounted in the component harness, when it is destroyed, then `actions.has(descriptor, DOWNLOAD_CSV_ACTION_ID)` goes from true to false. When it runs through `actions.run`, the Blob is its view in view order and carries no undeclared field (Rule 1 integration: the data table consumes `csv.ts`).
- Given Upcoming tasks (a page that mounts `DataTable` itself), when its read lands, then the command bar shows Download CSV. In the command-bar spec, a registered handler draws no control until the bound read has landed.
- Given Max rows set to 2 on a list whose read truncates, when the bar offers the download, then its described-by text is "The file holds the first 2 rows only." and the file holds 2 data rows. Without truncation there is no description.
- Given the formula, quoting, withheld and empty rows of the matrix, when encoded, then the output is exactly as the matrix states.
- Given this change, when `npm run test:tools` runs, then the two new keys resolve to literals of EXPERIENCE.md :313, and no existing citation moved.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- **AD-5:** one registration in the shared table reaches every table screen with no per-screen edit (list pages, Databases, Upcoming, Task history, Audit).
- **AD-19:** the store owns the view, and the table only reads it.
- **AD-20 and AD-43:** no API call, and no re-read.
- **AD-11 rule 4 and AD-47:** a same-document Blob download issues no request to any host. The CSP (`StaticHandler.cls` :350) has no directive that governs a `download` anchor (inference); the browser AC settles it.
- **AD-24, AD-35 and AD-48:** only declared columns are written. The error log's variables are not a data-table screen (`error-log.page.ts` draws its own grid).
- **AD-36:** the cap description reads `truncated()`.
- **Conventions and Stack:** no new dependency, and non-ASCII characters as escapes.

**Why the command bar and `ScreenActions`:** EXPERIENCE.md :601 makes the command bar the table's toolbar ("view options, sort and search"). `ScreenActions` is how a page already hands the bar a control only it can run (Refresh, DW-260). The table owns the view, so it is what registers.

**Truncation words:** the AC asks for a sentence about the file "in the words the table already uses". The new line repeats the cap notice's "the first <n> rows" and is formatted by the same `formatCapNotice`.

**Consumes:** `applyView`, `cellView`, `formatCapNotice`, `ScreenActions`. **Consumed-by:** `csv.ts` by `DataTable` in this story. Every later data-table screen inherits it, 16.9's hub among them if it is built on the table (inference).

**Ledger:** the inbox is empty. The preamble's DW-118 is declined because it was resolved by 15.6.

**Contention:** Epic 14 changes no file this story edits except the shared-append ones. Its `strings.ts` hunks are :163, :216 and :552, and this story appends at the tail. Its EXPERIENCE.md hunks are at base :266-292, :332-339 and :646 (the panel Header row). This story's in-place lines map to base :313, :591 and :640. Epic 23 has no source diff.

## Verification

**Commands** (the `ui` ones from `ui/`; browser runs export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`):

- (loop) `node --test tools/csv.test.mjs tools/strings.test.mjs tools/table-model.test.mjs`, then `npm run test:tools` -- expected: green.
- (loop) `npm run test:components` -- expected: green. This covers data-table, command-bar, command-box, list-page and the pages that mount `DataTable`.
- (loop) `npm run build` -- expected: every prebuild checker passes. Report the initial bundle against the 2004kB warning (re-base under DW-1166 if it is crossed), and stop and ask at 3800kB.
- (loop) `bash scripts/lint-docs.sh` -- expected: clean on EXPERIENCE.md and this spec.
- (loop) redeploy (`docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`), then run `node --test --test-concurrency=1` on `browser/csv-download.browser-spec.mjs` and these existing specs the new control could break:
  - `data-table`, `data-table-columns`, `column-widths`;
  - `account-and-filter`, `panel` (Databases' one-line bar), `screen-height`;
  - `databases`, `audit`, `tasks`;
  - `a11y-structural-invariants` (the DW-1337 walk, 1280 and 720 px, light and dark, with no new baseline key).
  Expected: green.
- No ObjectScript change, so there is no ObjectScript sweep. The full browser suite runs in CI, not locally.

**Mutations** (Rule 19: one line per AC, recorded when the pinning test is written):

- mutation: build from `store.data()` instead of `view()` → the browser AC1 and the data-table spec go red.
- mutation: skip the remover `register` returned, on destroy → the data-table spec goes red.
- mutation: drop the loaded condition → the command-bar spec goes red.
- mutation: omit `aria-describedby` at the cap → the command-bar spec and the browser spec go red.
- mutation: drop `-` from the guard set → `csv.test.mjs` goes red.
- mutation: write `Object.keys(row)` instead of the columns → `csv.test.mjs` goes red.
- mutation: change the `tableDownloadCsvCapped` value → `strings.test.mjs` goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only (halt after planning). The design is client-only: the data table registers `download-csv` on `ScreenActions`, and the command bar draws Download CSV. There is no ObjectScript change. EXPERIENCE.md is edited in place with no new line. The ledger inbox is empty, and DW-118 is declined (resolved by 15.6).
