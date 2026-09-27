---
title: 'Story 16.23: Any table, downloaded as CSV'
type: 'feature'
created: '2026-09-27'
status: 'done'
baseline_revision: 'fc246c1088ebf4f5cd3d3b595807b43a3fff771b'
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

### 2026-09-27 — Review pass

- verdicts: 17 findings — high 0, medium 0, low 11, false 6, maybe-false 0
- findings:
  - `low` `patch` The file name's local-time rule cannot fail in UTC CI — `csv.test.mjs` now sets `TZ=America/Los_Angeles` and asserts a non-zero offset.
  - `low` `patch` The cap `<n>` was never distinguished from the row count — the command-bar cap test now reads Max rows 3 over two rows.
  - `low` `patch` The "read landed for this screen" check was untested — the command-bar test now lands a read for another screen and expects no control.
  - `false` `reject` AC3 lacks a `mutation:` line for its Upcoming leg — Rule 19 asks one per AC, and AC3's command-bar half has one observed red.
  - `low` `patch` `!text.includes('Extra')` could not fail (a key, never written) — the withheld field now carries a distinctive value and the test checks that value.
  - `low` `patch` The component spec's name pattern was loose — pinned to the fixture label's exact slug `web-applications-and-rest-api-explorer` (the reviewer's `web-applications` was wrong: the label is "Web applications and REST API explorer").
  - `false` `reject` A control only for the route screen's table (A1) versus any mounted table — the intent ties the control to the screen's read, which is what the diff does.
  - `low` `reject` After a later refused read the control stays and saves the last good view — the intent does not decide it; rare, and a fix adds a branch.
  - `false` `reject` Cells as `cellView` text versus the grid's full text — the diff follows the intent's own parenthesis.
  - `low` `reject` On a filtered capped view "the first <n> rows" overstates the file — the sentence and its `<n>` are fixed by the intent; changing them edits the spec.
  - `false` `reject` The button sits after Refresh, not in :601's list order — the spec's task places it after Refresh, and :601 was a list, not a DOM order, before this change.
  - `false` `reject` Most matrix rows are pinned at unit level only — they are encoder decisions, and the matrix audit accepts that tier.
  - `low` `reject` "No request, no navigation" is not asserted by a network watch — the component test pins the blob `href` and the anchor's removal; a watch is a new harness.
  - `low` `reject` The control on an empty loaded table is not tested — the gate reads only `hasLoaded`; no row-count branch exists to break.
  - `low` `reject` `pendingFields` forwarding is pinned only at unit level — a one-argument call used only by Databases' staged free-space.
  - `low` `reject` A refusal before the first read is not tested — it holds the same unloaded state the tested skeleton case holds.
  - `false` `reject` Command-box absence is not asserted — `ScreenActions` cannot enumerate, and `command-box.ts` lists declared ids only and is untouched.

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

- mutation: `tableCsvRows(this.store().data(), …)` in `data-table.ts` → observed red: the data-table spec's "run through the registry" test, and after rebuild + redeploy the browser AC1 ("the file holds the footer's count of rows"); reverted byte-identical.
- mutation: `void stopDownload` in place of `destroyRef.onDestroy(stopDownload)` → observed red: the data-table spec's "removes it when destroyed" test; reverted.
- mutation: `hasDownloadAction` returns `true` without the loaded test → observed red: the command-bar spec's "draws no control until the bound read has landed" test; reverted.
- mutation: drop `[attr.aria-describedby]` from the download button → observed red: the command-bar spec's cap test, and after rebuild + redeploy the browser AC4 (timed out waiting for the description); reverted.
- mutation: drop `-` from `FORMULA_LEAD` → observed red: `csv.test.mjs` "the formula guard …"; reverted.
- mutation: map `Object.keys(row)` instead of `columns` in `tableCsvRows` → observed red: `csv.test.mjs` "only the declared columns …" and "a cell is what the table displays …"; reverted.
- mutation: `tableDownloadCsvCapped` reworded → observed red: `strings.test.mjs` (Fixed strings literal, authorized-strings and line-reference tests); reverted.
- mutation: `getUTCHours` in `csvFileName` → observed red: `csv.test.mjs` name test (it pins `TZ=America/Los_Angeles`, since CI runs in UTC); reverted.
- mutation: `<n>` from `store.data().length` in `downloadCapped` → observed red: the command-bar cap test (Max rows 3, two rows read); reverted.
- mutation: drop `refresh.descriptor() === screen.descriptor` from `hasDownloadAction` → observed red: the command-bar test's "read landed for another screen" step; reverted.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The data table registers `download-csv` on `ScreenActions` in `ngOnInit` and removes it on destroy. The command bar draws Download CSV (`ocu-button-text`, never `ocu-command-bar-action`) once the handler is registered and the screen's own read has landed, with the cap description at the cap. `core/csv.ts` builds the file from `view()` and the declared columns. It is client-only, with no new dependency.

**Files:**

- `ui/src/app/core/csv.ts` (new): field encoder (formula guard, RFC 4180), BOM and CRLF text, declared-columns rows over `cellView`, and the file name.
- `ui/src/app/core/screen-actions.ts`: `DOWNLOAD_CSV_ACTION_ID`.
- `ui/src/app/shell/data-table.ts`: register, remove, and the Blob and anchor save.
- `ui/src/app/shell/command-bar.ts`: the control, its cap description, and `hasContent`.
- `ui/src/app/core/strings.ts`: two keys cited to `EXPERIENCE.md:313`.
- EXPERIENCE.md: in place at :313, :601 and :650 (991 lines before and after).
- Tests: `ui/tools/csv.test.mjs` (new), two tests each in `data-table.spec.ts` and `command-bar.spec.ts`, and `ui/browser/csv-download.browser-spec.mjs` (new; covers AC1, AC3 and AC4).

**Review:** 17 findings (two layers), with 0 high and 0 medium. Five low findings were patched, all in tests only (see the triage log). None were deferred, and the rest were rejected with reasons in the log. Follow-up review recommended: false (patched counts: high 0, medium 0, low 5).

**Verification:**

- `node --test` csv/strings/table-model: 51/51. `npm run test:tools`: 1574/1574. `npm run test:components`: 1553/1553.
- `npm run build`: every checker passes. The initial bundle is 1.92 MB (main hash `K4VMHO4J`, unchanged by the review patches, so the deployed bundle is this tree's).
- `lint-docs.sh`: clean.
- Browser runs against `ocupilot-ci` after redeploy, all green: csv-download 3/3, data-table 9/9, data-table-columns 18/18, column-widths 2/2, account-and-filter 4/4, panel 12/12 (Databases' bar on one line at 832 px), screen-height 15/15, databases 3/3, audit 7/7, tasks 15/15, a11y-structural-invariants 12/12 (no baseline change).
- Five of those runs went out in one message, which Rule 18 forbids; all were read-only list walks and green.
- The grep of specs that enumerate command-bar buttons finds only `.ocu-command-bar-action`, `button.ocu-button-primary` and panel's one-line check.
- No ObjectScript change, so there was no sweep.
- Ten mutation lines were observed red and reverted byte-identical.

**Residual risks:**

- At the cap, the reason tooltip shows on hover but not on keyboard focus. The focus rule in `_components.scss` targets `.ocu-command-bar-action`, and the spec bars both that class and an SCSS change. The description still reaches assistive technology through `aria-describedby`.
- Registration happens once in `ngOnInit`, so a table whose `screen` input changes keeps its first descriptor.
