---
title: 'Story 19.7: The data browser - tree, grid, filter and sort'
type: 'feature'
created: '2026-10-04'
status: 'done'
baseline_revision: '53d93157d80390560027b7a6c19f65ff50411115'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer lists a table's schema but not its rows, so a developer still opens the classic Open Table page. Atelier's `action/query` would read them, but it prepares with SQL privilege checks off (AD-61 rule 7, DW-1963), so it cannot carry a statement shaped by a person's choices.

**Approach:** A new listed screen, Data browser, shows a schema tree, read through the SQL catalog's own declared reads (Story 19.5), and a grid ported from iris-table-editor. The grid shows a table's or view's columns, with their key, one bounded page of rows formatted by kind, per-column wildcard filters, a tri-state single-column sort, and pagination. The instance composes each read in `Port/SqlPort` from the caller's own privilege-filtered catalog rows. It prepares the read with privilege checks on, as the signed-in user. Every value is bound. The rows reach the screen only.

## Boundaries & Constraints

**Always:**

- **Order:** the screen gate first, then the body's shape, then the self-protection pre-check, then `SqlPort.Gate` (AD-29, AD-61 rule 1), and only then a statement.
  - The screen gate is the descriptor's pairs, plus the custom resources assigned to both classic Open Table pages (AD-44).
  - The pre-check refuses the requested name before any statement runs.
- **Resolve from the caller's catalog.** A table and its columns resolve through the caller's own privilege-filtered `INFORMATION_SCHEMA.TABLES` and `COLUMNS` rows, sent as fixed statements with bound values.
  - A table or view the caller cannot see answers 404 `EXPLORER.DATA.NOTFOUND`.
  - A filter or sort column must equal a resolved column exactly, and must not be of kind `stream` or `binary`.
- **No caller text reaches a statement.**
  - Identifiers are emitted only in the catalog's spelling, as delimited identifiers with `"` doubled.
  - Filter values, the offset and the fetch count are bound as `?`.
  - The sort direction is one of `ASC` and `DESC`.
- **Statement shape:**
  - `SELECT <cols> FROM "<schema>"."<name>" [WHERE …] [ORDER BY …] OFFSET ? ROWS FETCH NEXT ? ROWS ONLY`, fetching the page size plus one row.
  - `SELECT COUNT(*)` with the same WHERE and values.
  - Each statement runs through `SqlPort.Executed`: `%Prepare(text, 1)`, statement type 1, ODBC select mode, the namespace switched and restored around it, and the statement released there.
- **Bounds:**
  - Page size is 50, 100 (the default), 250 or 500. The offset runs from 0 to 99,999,999.
  - A cell is cut at 1,000 characters, ending in U+2026, with `truncated`. An answer is cut at 1,000,000 characters by whole rows, with `more`.
  - One alarm budget of `BoundSeconds()` is shared by every statement of one request. The page past it answers `stopped`. A count past it, refused or failing answers `total: null`.
- **Rows are screen-only.**
  - The descriptor declares no read and no context field, and adds no tool and no governance key.
  - Rows, SQLCODE and SQL messages never reach screen context, a tool result, the ledger, an audit payload or a log line (AD-36, AD-39 drafts).
- **Self-protection.** `Prohibited.SqlStatement` is called on the requested name before any statement, and on the composed text plus the resolved tables (a view's recorded base tables included) before any row is read.
- **The ported grid** draws `--ocu-*` tokens only and follows the portal's grid pattern: `role="grid"`, one Tab stop, `aria-activedescendant`.
- **Harvest.** Ported code keeps the harvest's call sites, never its names (CLAUDE.md, Conventions). The MIT notice for iris-table-editor ships in the served notices file and in `ATTRIBUTIONS.md`.

**Never:**

- A statement through `AtelierPort` or `action/query`, `%Prepare(…, 0)`, `%ExecDirectNoPriv`, or a value concatenated into SQL.
- A read tool, a declared read, context fields, a write, editing, staging, CSV export, multi-table tabs, a filter panel, or a page-size choice outside the four sizes. Editing, staging and export are Story 19.8's.
- The harvest's `--ite-*` tokens, its Atelier services, its Basic-auth transport, or its plaintext-password session (`sessionManager.ts:57,216,223`).
- A new third-party library or `@angular/cdk/tree`, or an edit to `Api/Error.cls`, `Prohibited.cls` or `SqlPort.Classify`.

## I/O & Edge-Case Matrix

Rows are measured on probe tables in `USER` (Design Notes › Measured). The request is `POST /explorer/sql/data?ns=USER`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open | `{schema, table}` for a 40-row table with no declared key | `columns` with `kind`, rows 1-40, `total` 40, `more` false, `key` [] | None |
| Page | `offset` 5, `size` 50 | rows from the sixth | None |
| Key | a single PRIMARY KEY, a composite one (A, B), an IDENTITY column | `key` [Code]; [A, B]; [Id2]; unsorted pages ordered by the key | None |
| Wildcards | Name `n3*`; Name `n%` | n3 and n30-n39; only a value equal to `n%` | None |
| Date filter | Born `2026-10*` | the row whose Born is 2026-10-01 (it matches the ODBC form) | None |
| Sort | Num desc, then cleared | 40 first; then key order, or the instance's order when the table has no key | None |
| NULL / empty | Name NULL; Name `''` | `null` shows "NULL", muted; `""` shows blank | None |
| Stream / binary | a LONGVARCHAR column; a VARBINARY column | its first 1,000 characters (cut ending U+2026); `0x…` hex | Filter or sort on either: 400 |
| Column grant | a principal granted `SELECT(Name)` on a two-column table | `columns` [Name], rows, `total` null | None |
| View grant | a principal granted only a view of rows Num > 30 | the view: its 10 rows; the base table: 404 | Banner |
| Stale plan, held open | a plan naming an ungranted column, its text held open by `_SYSTEM` | `outcome: error`, SQLCODE -99, no row | Status line |
| Own tables | as `%All` in the install namespace: a table in `OcuPilot_Kernel_State`; a view over `Proposal` | 403 `PROHIBITED.OCUPILOTSQL`: the table before any statement, the view before any row | Banner |
| Bad input | an unknown key; `size` 70; `offset` -1; a filter of 1,001 characters; direction `up`; a filter on an unlisted column | 400 `EXPLORER.DATA.INPUT` | Banner |
| Long read | a page past the bound | `outcome: stopped`, `seconds` | Status line |
| Gate | no `%Development:USE`; no READ on the code database; a custom resource on either Open Table page | 403 `AUTH.NOPRIVILEGE` naming the pair, before any statement. The router's namespace gate answers `NS.DENIED` first for a namespace the caller cannot read. | Banner |

</intent-contract>

## Code Map

- **The port** (`src/OcuPilot/Port/SqlPort.cls`, reuse, never fork). The new methods call its private members from inside the class:
  - `Gate` :577-592 and `BoundSeconds` :164;
  - `Executed` :798-915: the prepare :807, positional binding :816-824, the alarm :825, the fetch loop with cuts :840-875, the release :892;
  - `Prepared` :696-781: the statement index's relations plus `VIEW_TABLE_USAGE`;
  - `Fail`, `Refuse` and `Deny` :997-1022.
  - Pure helpers stay public, as `KindOf` and `InputProblem` (:175, :220) are.
  - `Run` :360-408 is not reused for the grid. Its `Classify` fails closed on an unindexed text (:312-315), and every `LIKE … ESCAPE` on a string column is unindexed (measured).
- **Handler pattern** (`src/OcuPilot/Area/Explorer/SqlConsole.cls`):
  - `Read` :126-141: the gate, `Kernel.Utils.ReadRequestBody`, `Kernel.Scope.Current()`;
  - `Check` :151-176: the call to `Prohibited.SqlStatement`;
  - `Gate` :226-233 and `RenderFault` :243-249.
- **Self-protection:** `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, `SqlStatement` :2015-2053 (rules a-c), `OCUPILOTSQL` :483. Read only, never edited.
- **Classic pages:** `src/OcuPilot/Screen/Gate.cls`, `RequiredPairs` :214, `WithClassicPages` :239, `EvaluateRequired` :292 and `Kernel.Denial.Envelope`.
- **Router** (`src/OcuPilot/Api/Router.cls`): the UrlMap tail is :231-236 and the thin wrappers end at :1734. The `/explorer/sql/data` route shares no `:param` family with its neighbours.
- **Error codes:** `src/OcuPilot/Api/AtelierError.cls`. The pattern is one code/reason parameter pair per code; the last line is :180.
- **Descriptor templates:**
  - `src/OcuPilot/Screen/Descriptor/ExplorerSqlQuery.cls` (a listed `form-page` with no read);
  - `ExplorerCompare.cls` (no tool);
  - the tree's three reads: `ExplorerSqlSchemas` (fields Schema, Tables, Views; criterion `system`), `ExplorerSqlTables` and `ExplorerSqlViews` (criteria `system` and `schema`), served by `AtelierPort` :166-218.
- **Server tests to follow:**
  - `src/OcuPilot/Test/SqlConsoleProbe.cls`: `Make` :65, `Hold`/`Release` :201-233, `EnsurePrincipals` :281, `ProbeAs`/`RunAs` :378-445, `Armed` :59;
  - `SqlPortLive.cls`, setup :46-61; `SqlPortFixture.cls` (`BoundSeconds` 2); `SqlConsoleRoutes.cls`, `Post` :53;
  - `ExplorerDescriptor.cls`, `TestSqlQueryKeysTheClassicSqlPage` :264-289;
  - `ClassicPageGate.cls`, `TestAnAssignedPageGatesTheSqlConsole` :361-399.
- **Client:**
  - `ui/src/app/areas/system-explorer/sql-query.store.ts`: a framework-free state (:231-574), `requestJson` POST (:489-511), `refusalText` :195;
  - `sql-query.page.ts`: `HELD` WeakMap :24-32, signal mirror :235-256, `role="status"` :139;
  - `ui/src/app/core/screen-read.ts`, `createScreenRead` :206-231 (precedent: `os-management/database-details.page.ts:459`);
  - `ui/src/app/core/api.ts`, `requestJson` :328-385;
  - `ui/src/app/shell/screen-outlet.ts`, imports :72-78 and `DESCRIPTOR_PAGES` :139-222;
  - `ui/src/app/shell/data-table.ts`, the APG grid markup :250-350 and keys :1064-1125, with `ui/src/app/core/table-model.ts`, `moveActive` :175-196, to mirror rather than reuse (it sorts held rows only).
- **Styles and tokens** (`ui/src/styles/_components.scss`):
  - data-table rules :2306-2508 (frame, header, cell, numeric :2411, selected :2482, focus :2504) and `@mixin ocu-focus-ring` :42;
  - console rules :7482-7492; the file ends at :8017;
  - tokens: `--ocu-surface-container-lowest`, `-low`, `-high`, `--ocu-on-surface(-variant)`, `--ocu-outline(-variant)`, `--ocu-secondary-container`, `--ocu-focus-ring`, `--ocu-row-height`, `--ocu-type-code-family` (`_tokens.scss`, `_metrics.scss`, `_typography.scss`);
  - lint: `ui/tools/client-lint.mjs`, `checkHardcodedColors` :101-125.
- **Budgets:**
  - `ui/angular.json` :51-57 (2704kB) and `ui/tools/angular-json.test.mjs` :467-485.
  - `ui/tools/strings.test.mjs` :581-584 bounds Fixed strings at 2,500. 2,382 are used today, measured with the test's own extractor.
- **Client tests to follow:** `sql-query.page.spec.ts` (`mount` :81-144, `settle` :55) and `ui/browser/system-explorer-sql-query.browser-spec.mjs` (`runIris`, `signedInAt`, structural passes :91-113).
- **Harvest** (`/Users/jbrandt/git/iris-table-editor` at v0.2.3, commit 29971a9, read-only). Lines in `packages/`:
  - `LICENSE:1,3`: MIT, "Copyright (c) 2026 InterSystems Community".
  - `core/src/utils/SqlBuilder.ts:30-47` (identifier), :107-167 (filter rules; wildcards :140-148; the literal-`%` defect :153-154), :177-201 (ORDER BY).
  - `core/src/utils/DataTypeFormatter.ts:43-67` (a UTC date shift), :75-90 (precision loss past 2^53).
  - `webview/src/grid.js`:
    - :262-313 `formatCellValue` (dispatch by kind; NULL :289);
    - :3364-3552 `handleCellKeydown` (read-only keys :3424-3515), :3266-3302 `selectCell`, :3559-3571 `getVisibleRowCount`, :3664-3670 header Enter/Space;
    - :3685-3808 `renderFilterRow`, :3815-3843 `applyFilter`, :3887-3905 `clearAllFilters`, :3961-3999 `handleColumnSort` (a defect: `renderLoading` is undefined, :3987);
    - :4277-4530 pagination; :6003-6014 Ctrl+PageUp/PageDown (a defect: Alt+arrows fire twice with :3438-3450).
  - `webview/src/grid-styles.css`, read-only rules only: :234-389 (header, sort, filter row), :866-881 and :944-999 (rows, cells, null), :1586-1726 (empty states, pagination).
  - `webview/src/main.js:329-382,773-869` (the schema tree).
  - Staging is Story 19.8's: `grid.js:46-47`, :1933-2004.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** (`ocupilot-a2-ci`, before code; probe schema `OcuProbe197`, removed after). Record the results in Design Notes.
  - (a) Read the `INFORMATION_SCHEMA.COLUMNS.DATA_TYPE` spelling for each DDL type: CHAR, VARCHAR, LONGVARCHAR, BINARY, VARBINARY, LONGVARBINARY, BIT, TINYINT, SMALLINT, INTEGER, BIGINT, NUMERIC, DECIMAL, DOUBLE, DATE, TIME, TIMESTAMP and POSIXTIME. Fix `KINDS` from what the instance answers.
  - (b) Measure `SUBSTRING("<col>", 1, 500)` on a VARBINARY and a LONGVARBINARY column through `Executed`. If it fails, select a binary column as `NULL` and show "NULL", and record that here.
- [x] `src/OcuPilot/Port/SqlPort.cls`. Add-only, except `Executed`, which gains the two raw fields `more` and `cut`; its `truncated` and its answer to its callers are unchanged.
  - `more`: a fetched row was not kept, past `pMaxRows` or dropped by the answer cut.
  - `cut`: a cell was cut.
  - Public pure helpers:
    - `KindOfType(dataType)` over `KINDS`: number, boolean, date, time, timestamp, stream, binary, else text.
    - `Quoted(name)`.
    - `LikeValue(text)`: escape `\`, `%` and `_` with `\`, then map `*` to `%` and `?` to `_`.
    - `BrowseRequest(body, .request)`: the closed keys `schema`, `table`, `filters`, `sort`, `offset` and `size`, with Design Notes › Wire's bounds.
    - `Composed(plan)`: the page and count texts with their values in order.
  - `BrowsePlan(ns, request, .plan, .http, .fault)`:
    - `Gate`;
    - resolve exactly one `TABLES` row (else 404 `EXPLORER.DATA.NOTFOUND`, unlogged);
    - read `COLUMNS` in ordinal order;
    - detect the key: the first PRIMARY KEY constraint's `KEY_COLUMN_USAGE` columns, else the `IS_IDENTITY` column, else a column named `ID`, and none unless every key column is listed;
    - check each filter and sort column (else 400);
    - for a view, read `Prepared(ns, "SELECT <listed columns> FROM <view>")`'s tables, failing closed (500 logged) when the text is unindexed;
    - compose.
    - Every statement goes through `Executed` with the remaining budget, the budget's start kept in the plan.
  - `BrowseRun(ns, plan, .answer, .http, .fault)`:
    - run the page, then the count with what remains;
    - map each cell: `""` becomes `null`, `$Char(0)` becomes `""`, and a binary cell becomes `0x` plus upper-case hex of at most 499 bytes, with U+2026 and `truncated` when 500 came back.
    - Answer shapes are in Design Notes › Wire.
- [x] `src/OcuPilot/Area/Explorer/SqlData.cls` (new), `HandleBrowse`. In order:
  - the gate: `EvaluateRequired(WithClassicPages(RequiredPairs(descriptor), "%cspapp.exp.utilsqlopenview"))`;
  - `ReadRequestBody`, then `SqlPort.BrowseRequest` (400 `EXPLORER.DATA.INPUT`);
  - the pre-check `Prohibited.SqlStatement("", $LB(schema_"."_table), 1, …)`;
  - `BrowsePlan`, then `Prohibited.SqlStatement(plan page text, plan tables, 1, …)` (403 `FORBIDDEN` with `ReasonFor`);
  - `BrowseRun`, then `Api.Response.JSON`.
  - Faults render as `SqlConsole.RenderFault` does.
- [x] `src/OcuPilot/Api/Router.cls`, add-only: `<Route Url="/explorer/sql/data" Method="POST" Call="ExplorerSqlData"/>` at the UrlMap tail, and one thin wrapper at the class end.
- [x] `src/OcuPilot/Screen/Descriptor/ExplorerSqlData.cls` (new). It declares:
  - route `system-explorer/sql-data`, label `explorerSqlDataLabel`, side bar 11, `form-page`, no refresh;
  - privileges `[%Development:USE]`, entity `class`, scope `namespace`, id `none`;
  - no action, context fields `[]`;
  - aliases `data browser`, `open table`, `browse table` and `table rows`;
  - three prompts in `webAppPromptGroupCode`;
  - `classicPage` `%cspapp.exp.utilsqlopen`, no exemption, `toolIdentifier` `explorer.sqldata`.
- [x] `src/OcuPilot/Api/AtelierError.cls`, add-only: `DATAINPUT` (`EXPLORER.DATA.INPUT`, 400) and `DATANOTFOUND` (`EXPLORER.DATA.NOTFOUND`, 404), with Design Notes › Strings' reasons.
- [x] `ui/src/app/core/data-browser-model.ts` (new, framework-free). Pure rules, ported with call sites kept and names changed:
  - `nextSort`: none, then asc, then desc, then none; a new column starts at asc.
  - `moveCell`: arrows without wrap, Home and End, Ctrl/Cmd+Home and End, PageUp and PageDown by the visible rows, the header row included.
  - Offset paging: first, previous (`max(0, offset - size)`), next (`offset` plus the rows kept), last (`floor((total - 1) / size) * size`, only while `total` is known), go to page (1 to N).
  - `cellView(kind, value)`, `columnTrack(kind)`, `isFilterable(kind)` and the status-line text.
- [x] `ui/src/app/areas/system-explorer/data-browser.store.ts` (new, framework-free, one per `ScreenStore`):
  - tree state, read through `createScreenRead` for `explorer.sqlschemas` (`system=no`), and for `explorer.sqltables` and `explorer.sqlviews` on expand (`schema=<name>`);
  - the open table, filters, sort, offset, size and answer;
  - the refusal, as `refusalText` writes it;
  - a request generation counter that drops stale answers;
  - posts through `requestJson`, scoped to the namespace.
- [x] `ui/src/app/areas/system-explorer/data-browser-tree.ts` (new): an APG tree with one Tab stop and `aria-activedescendant`.
  - Schemas whose Tables or Views flag is set.
  - On expand, tables, then views marked "View".
  - Keys: Up, Down, Home, End, Right (expand or first child), Left (collapse or parent), Enter and Space (open).
  - A truncation line for a read cut at its cap, and an empty-schema line.
- [x] `ui/src/app/areas/system-explorer/data-browser-grid.ts` (new):
  - the filter row as `role="group"` "Column filters", one input per filterable column; Enter applies it and Escape clears it and applies, each returning to the first page;
  - the grid: `role="grid"`, `tabindex="0"`, `aria-activedescendant` on the active cell;
  - header cells `role="columnheader"`, with `aria-sort` on the sorted one and a key marker;
  - Enter, Space or a click on a header cycles the sort; Ctrl/Cmd+PageDown and PageUp change page;
  - `aria-rowcount` is `total + 1`, else -1, and `aria-rowindex` is `offset + i + 2`;
  - cells are a single line with an ellipsis.
- [x] `ui/src/app/areas/system-explorer/data-browser.page.ts` (new):
  - the tree and grid split, stacked at the narrow breakpoint, with an empty state until a table opens;
  - a heading for the open table, Refresh (`actionRefresh`), Clear filters and the filter hint;
  - First, Previous, a Page input "of N", Next and Last, with Last disabled while `total` is null; Rows per page;
  - a `role="status"` line and a `role="alert"` refusal.
- [x] `ui/src/app/shell/screen-outlet.ts`: add-only import and `DESCRIPTOR_PAGES` entry. Regenerate `ui/src/app/core/screens.generated.ts` with `node tools/screen-mirror.mjs`.
- [x] `ui/src/app/core/strings.ts`: keys at the end, each annotated with the new Fixed-strings row's EXPERIENCE.md line. `ui/src/styles/_components.scss`: add-only `ocu-data-browser*` rules on tokens, reusing the `ocu-data-table-*` classes.
- [x] EXPERIENCE.md:
  - :159 in place: add 19.7 to the story list, append `· Data browser`, and add "Data browser opens a table's or a view's rows".
  - A Fixed-strings row after :597.
  - A `### data-browser` paragraph after the `data-table` section: the grid's keys, the tree's keys, filter semantics, offset pagination, and screen-only rows.
  - Move every line citation the suites hold (`npm run test:tools`).
- [x] Harvest notice:
  - `ATTRIBUTIONS.md`: a "Harvested code" row with iris-table-editor's MIT copyright line and full text.
  - `ui/licenses/iris-table-editor.txt` (new) holds that notice.
  - `ui/tools/licenses.mjs` appends every `ui/licenses/*.txt` to the shipped `3rdpartylicenses.txt`.
  - A source header in each ported file names the harvest file it ports.
- [x] **Server tests (new):**
  - `src/OcuPilot/Test/SqlBrowse.cls` (pure): `Quoted`, `LikeValue` (every metacharacter), `KindOfType` over `KINDS`, every `BrowseRequest` refusal, `Composed` (texts and value order), and the cell mapping.
  - `src/OcuPilot/Test/SqlBrowseProbe.cls` (fixture):
    - schema `OcuProbe197` in `USER`: a 40-row keyless table with every kind of column; a single-key, a composite-key and an identity table; a two-column table; a view of rows Num > 30; a slow-function view for the bound;
    - principals `OcuProbe197User` (table grants plus `SELECT(Name)`) and `OcuProbe197View` (the view alone), each with `SqlConsoleProbe.EnsurePrincipals`' role pairs, created only where `SqlConsoleProbe.Armed()` reads 1;
    - it declares no arming variable of its own, so `ci-throwaway.sh`'s roster is unchanged;
    - `ProbeAs` for `BrowsePlan` and `BrowseRun` legs.
  - `src/OcuPilot/Test/SqlBrowseLive.cls`: every matrix row at the port, including the held-open stale-plan seam through `SqlConsoleProbe.Hold`, and the bound through `SqlPortFixture`.
  - `src/OcuPilot/Test/SqlDataRoutes.cls` (HTTP): input, gate, not found, own tables, a success shape, and a view.
- [x] **Server rosters:**
  - `Test/ExplorerDescriptor.cls`: append to `DESCRIPTORS` :20, "twenty-eight" :17 becomes "twenty-nine", append to the side-bar order :40, and add `TestDataBrowserKeysTheClassicOpenTablePage` modeled on :264-289, asserting `NormalizePage("/csp/sys/exp/UtilSqlOpen.csp")`.
  - `Test/DeveloperFloor.cls`: append to `SCREENS` :34.
  - `Test/DeveloperFloorRoutes.cls`: add `POST /explorer/sql/data` to `tOthers` :87.
  - `Test/EndpointCoverage.cls`: a probe row before :248.
  - `Test/SurfaceCoverage.cls`: a screen row after :171.
  - `Test/ClassicPageGate.cls`: `TestAnAssignedPageGatesTheDataBrowser`, covering each Open Table page, the lacking and the holding principal, and the route.
- [x] **Client tests:**
  - `ui/tools/data-browser-model.test.mjs` (new).
  - A token check (in that file): every `var(--…)` in the `ocu-data-browser` rules is `--ocu-`, and no `--ite-` appears anywhere under `ui/src`.
  - `ui/tools/licenses.test.mjs` (new).
  - `data-browser.page.spec.ts` and `data-browser-grid.spec.ts` (vitest and jsdom).
  - `ui/browser/system-explorer-data-browser.browser-spec.mjs` (new).
- [x] **Client rosters:**
  - `ui/tools/navigation.test.mjs`: the route after `system-explorer/sql-query` :298, and the message :308.
  - `ui/browser/system-explorer.browser-spec.mjs`: the eleventh label :136, and the message.
  - `ui/tools/self-protection.test.mjs`: `ATELIER_REFUSALS` :508-537 gains the two reasons.
- [x] `ui/angular.json` and `ui/tools/angular-json.test.mjs`: re-base `maximumWarning` to the measured build (DW-1166). Stop and ask above 3,800 kB.

- [x] DW-2025 (routed to this story at its spec gate; fixed on its own head f02883e2, merged forward at ca221d2e, before implement): a console statement the statement index does not record (`LIKE ... ESCAPE` on a string column) is answered by name, a 422 the console explains, or classified another way and run; never a 500 (`SqlPort.cls:312`). Pin it with a test and a `mutation:` line.

**Acceptance Criteria:**

- **AC1 (tree):**
  - Given probe tables and a view in `USER`, when Data browser opens, then the tree lists the non-system schemas holding tables or views.
  - When a schema expands, its tables and its views, marked as views, are read through the SQL tables and SQL views reads.
  - Opening one shows its grid.
  - Keyboard follows the APG tree.
- **AC2 (columns and key):**
  - Given tables with a single, a composite and an identity key, and one with none, when each opens, then every header names its column, the key columns are marked, and an unsorted page is ordered by the key.
  - A column-only grantee sees only its granted columns.
- **AC3 (paged grid and formatting):**
  - Given a table, when it opens, then the first 100 rows show, formatted by kind:
    - NULL distinct from an empty value;
    - numbers right-aligned in tabular figures;
    - dates, times and timestamps in the instance's ODBC form;
    - BIT as the existing yes and no words;
    - a stream's first 1,000 characters;
    - binary as `0x` hex.
  - First, Previous, Next, Last, go-to-page and Rows per page move by offset, and the status reads "Rows a–b of n".
  - With an unknown total it reads "Rows a–b", and Last is disabled.
- **AC4 (filter):**
  - Given the filter row, when a value is applied, then the whole value must match: `*` stands for any run of characters and `?` for one. `%`, `_` and `\` match themselves.
  - Date, time and timestamp columns match their ODBC form.
  - Applying returns to the first page, and Escape clears.
  - A stream or binary column offers no filter, and the route refuses one.
- **AC5 (sort):**
  - Given a header, when it is activated three times, then the sort goes ascending, descending, then none; each change returns to the first page and sets `aria-sort`.
  - A sort ties on the key, so the same rows never straddle two pages.
- **AC6 (the read checks the caller's privileges):**
  - Given purpose-built principals, when they browse:
    - an ungranted table or view answers 404;
    - a column grant shows only its columns, without a -99;
    - a view-only grantee reads only the view's rows and is answered 404 on the base table;
    - a plan naming an ungranted column answers SQLCODE -99 with no row, also while another account holds that text prepared.
  - No identifier is emitted that the caller's catalog did not answer, and every value is bound.
- **AC7 (self-protection):** Given a `%All` caller in OcuPilot's install namespace, when it opens a table in an `OcuPilot` schema, then it is refused 403 `PROHIBITED.OCUPILOTSQL` before any statement. A view over OcuPilot's tables is refused before any row is read.
- **AC8 (bounds):**
  - Given a wide or slow table, when it is read:
    - a cell is cut at 1,000 characters, ending in U+2026;
    - the answer stays under 1,000,000 characters, with `more`;
    - a page past the bound answers `stopped`;
    - the count shares the budget.
  - The rows, SQLCODE and messages reach no screen context, tool, ledger or log line.
- **AC9 (classic parity, AD-44):**
  - Given the descriptor, when it is read, then it declares `%cspapp.exp.utilsqlopen`, and a custom resource on that page gates the screen and the route.
  - A custom resource on `%cspapp.exp.utilsqlopenview` gates the route.
  - A `%Developer` opens Data browser in `USER`.
- **AC10 (tokens):**
  - Given the ported grid and tree, when they render in light and dark, then they draw only `--ocu-*` tokens: no `--ite-*` and no literal color.
  - The structural walk passes in three passes: wide light, narrow light and wide dark.
- **AC11 (Integration, Rule 1):** Given a table that SQL query (Story 19.6) creates and fills in `USER` on the real instance, when Data browser opens it from the tree, which reads it through Story 19.5's SQL tables read, then its rows show.

## Spec Change Log

- 2026-10-04, lead (spec gate): the spine carries the drafts (AD-61's data browser case, AD-21, AD-36, AD-39, AD-7, AD-10, AD-44, AD-8); epics.md Story 19.7's first criterion now names `Port/SqlPort` (Rule 5). Rows stay screen-only (AD-3, AD-36). The plan's `deferred:` console defect is filed as DW-2025 and routed here as a task. Contended edits: EXPERIENCE.md :159 in place, `angular.json` and its test under the re-measure rule, the spine; the rest add-only.

## Review Triage Log

### 2026-10-04 — Review pass

- verdicts: 21 findings — high 0, medium 11, low 7, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` Nothing pins that the count gets only what the page left of the one budget (AC8) — added `Test/SqlBrowseFixture.cls` (records each `Executed` bound) and `SqlBrowseLive.TestTheCountTakesWhatRemainsOfTheBudget`; mutation recorded.
  - `[medium]` `[patch]` `more` on an answer cut at 1,000,000 characters is unpinned — added the probe's `Wide` table and `SqlBrowseLive.TestAnAnswerCutBySizeSaysMore`; mutation recorded.
  - `[medium]` `[patch]` The store's Next "past the rows kept" is unpinned (the test page was exactly full) — added the page-spec case with a 37-row page; mutation recorded.
  - `[medium]` `[patch]` Sort and filter "return to the first page" were asserted only from the first page — the sort and filter cases now page to offset 100 first; mutation recorded.
  - `[medium]` `[patch]` The stale-answer generation counter has no test — added a held-request page-spec case; mutation recorded.
  - `[medium]` `[patch]` The view fail-closed branch (base tables unrecorded) is never exercised — `SqlBrowseFixture.Prepared` answers unindexed on demand; `SqlBrowseLive.TestAViewWhoseTablesAreUnrecordedFailsClosed`; mutation recorded.
  - `[medium]` `[patch]` Nothing checks a request resolves to the catalog's spelling (AC6) — added `SqlBrowseLive.TestARequestResolvesToTheCatalogsSpelling`; mutation recorded.
  - `[low]` `[patch]` Clear filters is clicked by no test — added the page-spec case, from the second page.
  - `[medium]` `[patch]` The route's gate-before-body order is unobserved — `SqlDataRoutes.TestTheGateAndAnUnknownTable` posts a bad body as the principal lacking `%Development:USE` and expects 403; mutation recorded.
  - `[false]` `[reject]` `DeveloperFloorRoutes` skips roster POST routes, so the entry only removes the route from the sweep — the roster lists routes the principal passes; left out, the sweep would expect a refusal the developer does not get, and `SqlDataRoutes.TestAViewOnlyGranteeReadsTheView` pins the 200.
  - `[false]` `[reject]` Navigation and the side bar weigh only the table page's resource — the intent's clause sits in the route's order list and AC9 has the view page gate the route alone; the spec names the limit.
  - `[low]` `[reject]` The view base-table lookup and the stale-plan re-prepare run outside `Executed`'s alarm — both only prepare (a one-table select, or a text that just failed to prepare); bounding them needs new guards for a delay no one meets.
  - `[low]` `[reject]` `Remaining` rounds up, so the last statement may overrun the bound by under a second — the alarm counts whole seconds; rounding down would stop a page that has most of a second left.
  - `[medium]` `[patch]` `CatalogRows` logged the instance's SQLCODE, against the intent and `Fail`'s own contract — the log line now names only "not prepared", "cut" or "refused".
  - `[low]` `[reject]` A cut binary cell is 1,001 characters (`0x`, 998 hex digits, U+2026) — the spec's task fixes 499 bytes; the one extra character harms no one.
  - `[low]` `[reject]` The `ID` key fallback is untested and would mark a view's `ID` column — the spec's task specifies that fallback; class tables answer a primary key on `ID` through the key query.
  - `[medium]` `[patch]` Matrix rows observed only at the port, not at the route the matrix names — `SqlDataRoutes.TestCellsAndAColumnGrantOverTheWire` pins NULL as JSON `null`, empty as `""`, and a column grant's one column with `total: null` over HTTP; mutation recorded.
  - `[low]` `[reject]` Banner and status-line paths are tested only in jsdom — jsdom renders the same template, and the browser spec already reads the real route's status line; a real-browser refusal adds principals for no new rendering path.
  - `[false]` `[reject]` The router's `NS.DENIED` precedence is untested here — it is the router's gate in front of every handler, pinned by `Test/Routing.cls` and `Test/Wire.cls`.
  - `[low]` `[patch]` `SqlDataRoutes`' header said bad input is refused before any statement, but an unlisted or stream column is refused after the catalog reads — header corrected.
  - `[medium]` `[patch]` A column grant on a view answered -99 instead of rows (measured on `ocupilot-a2-ci`; it was the implement pass's `deferred:` item) — `BrowsePlan` reads a view's base tables from a select of its listed columns; the deferred item is removed, the task line corrected in place, and `TestTheReadChecksTheCallersPrivileges` gains the view column-grant leg; mutation recorded.

## Design Notes

**Decisions (for the spec gate):**

- **The read path is `SqlPort`'s, not Atelier's.**
  - `BrowsePlan` and `BrowseRun` are new `SqlPort` entry points over its own `Gate`, `Executed` and `Prepared`.
  - Not `Run`: a composed text is not caller SQL, and `Classify` fails closed on every unindexed text.
  - Self-protection stays in the handler, as the console's does, between the plan and the run.
- **The rows stay on the screen** (settled from the spine).
  - AD-3 emits any field without a reviewed classification as secret. An arbitrary table's columns carry no classification, so none may reach the model.
  - AD-36 already keeps console rows and journal-record values screen-only, for this reason (patient data, no schema).
  - Story 19.11 decides whether the agent gains row access, and owns the sanitizer path (AD-60).
- **Paging is by explicit offset.**
  - AD-36 allows an explicit cursor, and Story 18.19 already pages by offset.
  - `OFFSET ? ROWS FETCH NEXT ? ROWS ONLY` replaces the harvest's `%VID` subquery: it is faster (measured) and needs no `TOP`.
  - The next offset is the rows kept, so an answer cut never skips rows.
- **Classic pages.** Open Table is `%cspapp.exp.utilsqlopen`, Hidden, a `%CSP.Util.AutoPage`.
  - It declares no `RESOURCE`. `OnPage` honors only a custom resource on its own class (`irissys/%CSP/Util/AutoPage.cls:210`).
  - SQL Home links to it, and to `utilsqlopenview` for views (`irissys/%CSP/UI/Portal/SQL/Home.cls:91-93`).
  - So the screen declares `%Development:USE`, as SQL Home does, and the route unions both pages' custom resources.
  - Named limit: navigation weighs the table page's resource alone.
- **The harvest:**
  - **Lifted:** the SqlBuilder rules, moved to ObjectScript (R7 and R8 fixed); `formatCellValue`'s dispatch by kind; the model shapes, as `columns` and `{rows, offset, size, more, total}`.
  - **Ported:** keyboard navigation, re-expressed on `aria-activedescendant` with one Tab stop; the filter row with its tri-state sort.
  - **Story 19.8's:** the third algorithm, staging with primary-key reconciliation and stale-index recovery.
  - **Not lifted:** `DataTypeFormatter`'s display functions (a UTC date shift, precision loss past 2^53); its parsers come with Story 19.8's editors.
  - **Not carried:** blur-apply, the filter panel, the boolean filter select, Ctrl+F, F5 and Alt+arrows.
  - **License:** MIT, compatible.
  - Once ported, the grid is project-owned code, not a dependency (Rule 5).
- **Size:** one pass, no split. The server adds two port methods, a handler and a descriptor; the client adds a page, a store, two components and a pure model. Story 19.6 carried more in one pass.

**Measured on `ocupilot-a2-ci`, 2026-10-04.** Probe schema `OcuProbe197`, class `OcuProbe197.Probe`, and principals `OcuProbe197U` and `OcuProbe197V` were created, removed, and checked gone. The principals held `%Development:U`, `%DB_HSCUSTOM:R` and `%DB_USER:RW`. Statement-index rows remain.

- **Catalog:**
  - `TABLES` and `COLUMNS` are filtered per principal. A column grant lists only its columns.
  - `TABLE_CONSTRAINTS` and `KEY_COLUMN_USAGE` gave `Keyed` [Code], `Pair` [A, B] and `Ident` [Id2]. Ident's IDENTITY column also reads `IS_IDENTITY` YES.
  - A keyless DDL table lists no `ID` column.
  - `VIEW_TABLE_USAGE` answered the view-only grantee no row, while the statement index of `SELECT … FROM <view>` recorded the base table.
- **Privileges:**
  - With a column grant, `SELECT Name` read rows, while `Name, Secret`, `COUNT(*)` and `ID` each answered -99.
  - The view-only grantee read the view's 10 rows and its `COUNT(*)`; the base table answered -99.
  - With `_SYSTEM` holding the `OFFSET … FETCH` page text, the count text and the two-column text, each answered the principal -99 with no row.
- **Shape:**
  - `OFFSET ? ROWS FETCH NEXT ? ROWS ONLY` and `LIMIT ? OFFSET ?` both run, bound, as type 1. `TOP` with `OFFSET` is refused (-386).
  - On 100,000 rows: offset 99,900 took 0.15 s against `%VID`'s 0.24 s, and `COUNT(*)` 0.016 s (0.046 s filtered).
  - Any `LIKE … ESCAPE` on a VARCHAR column compiles a cached query with no statement-index row (see `deferred:`).
- **Values (ODBC mode):**
  - NULL reads `""` and an empty string `$Char(0)`.
  - A LONGVARCHAR reads as its stream's OID text; `SUBSTRING(col, 1, 1001)` reads its text.
  - `LIKE` on DATE, TIME and TIMESTAMP (PosixTime) matches the logical value, so ODBC text matches nothing, while `%ODBCOUT(col) LIKE` matches.
  - `LIKE` matched INTEGER, NUMERIC (`12.5%` matched 12.50) and BIT, and was case-insensitive on VARCHAR.

**Task 0, measured on `ocupilot-a2-ci`, 2026-10-04** (probe tables in `OcuProbe197`, dropped and checked gone):

- (a) `INFORMATION_SCHEMA.COLUMNS.DATA_TYPE`, lower case: CHAR and VARCHAR read `varchar`; LONGVARCHAR `longvarchar`; BINARY and VARBINARY `varbinary`; LONGVARBINARY `longvarbinary`; BIT `bit`; TINYINT, SMALLINT, INTEGER and BIGINT their own names; NUMERIC and DECIMAL `numeric`; DOUBLE `double`; DATE, TIME and TIMESTAMP their own names; POSIXTIME `timestamp`. Also MONEY `numeric`, FLOAT and REAL `double`, DATETIME `timestamp`, TEXT and CLOB `longvarchar`, IMAGE and BLOB `longvarbinary`, UNIQUEIDENTIFIER `guid`, VECTOR `varchar`. `KINDS` names the thirteen spellings the DDL types answer; `guid` and `varchar` are text.
- (b) `SUBSTRING("col", 1, 500)` on a VARBINARY and a LONGVARBINARY column, prepared with privilege checks on in ODBC mode, reads the raw bytes, 500 of the long value; so a binary column is selected that way, never as `NULL`.
- In ODBC mode a NUMERIC(10,2) cell reads `1.5`, not `1.50`.

**Wire.** The request is `POST /explorer/sql/data?ns=<NS>`, with the body `{schema, table, filters?, sort?, offset?, size?}`:

- `schema` and `table` are 1 to 128 characters, with no control character.
- `filters` maps a column name to a value of 1 to 1,000 characters, at most 100 entries.
- `sort` is `{column, direction: asc|desc}`.
- `offset` is an integer from 0 to 99,999,999 (default 0), and `size` is 50, 100, 250 or 500 (default 100).

The answer is one of three shapes, each carrying `table: {schema, name, type: table|view}`, `columns: [{name, type, kind, nullable, key}]` and `key: [names]`:

- `{outcome: rows, rows, offset, size, more, total|null, truncated}`;
- `{outcome: stopped, seconds}`;
- `{outcome: error, sqlcode, message}`.

The select list names each resolved column in ordinal order; a stream column is `SUBSTRING("col", 1, 1001) AS "col"` and a binary one `SUBSTRING("col", 1, 500) AS "col"` (Task 0 (b)). The filter expression is `"col" LIKE ? ESCAPE '\'`, or `%ODBCOUT("col") LIKE ? ESCAPE '\'` for the date, time and timestamp kinds. The ORDER BY is the sort column and direction, then the key columns ascending; with no sort it is the key columns, or nothing.

**Strings.** One Fixed-strings row after :597. Estimate: 30 literals against 118 of headroom under the 2,500 bound, so no raise is needed. Epic 18's pending rows share that headroom at merge.

- Labels:
  - "Data browser", "Tables and views";
  - "Filter <column>", "Clear filters";
  - "First page", "Previous page", "Next page", "Last page", "Page", "of <n>", "Rows per page";
  - "NULL", "Key column".
- Lines:
  - "Pick a table or view in the tree to see its rows."
  - "This schema holds no table or view this account can see."
  - "Only the first 1,000 are listed."
  - "Filters match the whole value: * stands for any run of characters and ? for one character."
  - "Rows <first>–<last> of <total>" and "Rows <first>–<last>"
  - "No rows." and "No rows match the filters."
  - "Sorted by <column>, ascending.", "Sorted by <column>, descending." and "Sort cleared."
  - "Enter a page from 1 to <n>."
- Reasons:
  - INPUT: "Name a table or view as the tree shows it; filters of up to 1,000 characters on its listed columns that are not streams or binary; a sort on one such column, ascending or descending; an offset from 0; and a page size of 50, 100, 250 or 500."
  - NOTFOUND: "This namespace holds no table or view by that name that this account can see."
- Prompts: "How do I filter rows with * and ? here?" · "Why does this table show fewer columns than its class defines?" · "Which column is this table's key, and how is it found?"
- Reused: `actionRefresh`, `tableStatusYes` and `tableStatusNo`, `viewMenuLabel` (the tree's "View" marker), `explorerSqlStopped` and `explorerSqlCode`.

**Spine amendments (draft, for the lead's gate):**

- **AD-61**, after Story 19.15's case:

  > **Story 19.7's case, the data browser** [AMENDED 2026-10-04, Story 19.7 spec gate, Rule 20]. `SqlPort.BrowsePlan` and `BrowseRun` read a table's or a view's rows through rule 1's gate, as the signed-in user. They prepare port-composed statements with `%Prepare(text, 1)` in the target namespace, never through `Classify`.
  >
  > - The table and its columns resolve through the caller's own privilege-filtered `INFORMATION_SCHEMA.TABLES` and `COLUMNS`.
  > - A statement is a SELECT with an `OFFSET`/`FETCH` page, plus its `COUNT(*)`, under one alarm budget of `BoundSeconds`.
  >
  > Measured on `ocupilot-a2-ci`: a column grant lists and reads only its columns; a view-only grantee reads only the view; and a text another account held open still answered -99.

- **AD-21**, a case:

  > **The data browser's statement is composed by the port** (Story 19.7): every identifier comes from the caller's catalog rows, delimited with `"` doubled; the filter values, the offset and the fetch count are bound; and the direction is one of two words.

- **AD-36:**

  > A data browser page (Story 19.7) is a screen-only payload. It is never a declared read, a tool's view or screen context, because an arbitrary table's columns carry no reviewed classification (AD-3). It is bounded by its page size (50 to 500), 1,000 characters a cell and 1,000,000 in all, and paged by an explicit offset.

- **AD-39**, the sixth exception: append "and a data browser page's rows, SQLCODE and message (Story 19.7)".
- **AD-7**, the fifth shape: append "and each distinct composed data-browser statement (Story 19.7), whose values are bound, never in its text".
- **AD-10**, the SQL arm: append "a data browser read of a table in an `OcuPilot` schema, refused before any statement, or of a view over one, refused before any row (Story 19.7)".
- **AD-44:** "Story 19.7: Data browser declares `%cspapp.exp.utilsqlopen` (Hidden, spelled as `NormalizePage` answers, measured), and its route unions `%cspapp.exp.utilsqlopenview`'s custom resource."
- **AD-8:** "Story 19.7: the data browser declares no pair beyond its screen's; its SQL privileges are the instance's at prepare (measured)."

**AC amendment (Rule 5, apply-and-report, for epics.md Story 19.7's first criterion):** "**Then** it works against the SQL port (`Port/SqlPort`, AD-61's SQL case), the schema tree through the Atelier port's catalog reads [AMENDED 2026-10-04, Story 19.7 spec gate, Rule 5: was 'against the Atelier port'; `action/query` cannot carry rows (AD-61 rule 7)]."

**Integration ACs:** AC11.

**Consumes:**

- Story 19.5's `explorer.sqlschemas`, `explorer.sqltables` and `explorer.sqlviews` reads;
- `SqlPort.Gate`, `Executed`, `Prepared` and `BoundSeconds` (Story 19.6);
- `Prohibited.SqlStatement`, `Screen.Gate.WithClassicPages`, `createScreenRead` and `requestJson`;
- SQL query (Story 19.6) for AC11.

**Consumed-by:**

- Story 19.8: the grid, the store's filter, sort and offset state, the `columns` and `key` shapes for primary-key reconciliation, and the rule that writes run through `SqlPort`.
- Story 19.11: whether page rows ever reach the model.

**ADs:** AD-3, AD-5, AD-7, AD-8, AD-9, AD-10, AD-11, AD-12, AD-13, AD-16, AD-19, AD-21, AD-22, AD-24, AD-29, AD-36, AD-39, AD-43, AD-44, AD-47, AD-60, AD-61.

**Footprint (Rule 11).** Checked 2026-10-04 against `.worktrees/epic-18` at `68867b96b302e48ccde1a3754b4e35532ff38652`, committed and `status -s`.

- **Contended, add-only:**
  - `Api/Router.cls` (tail);
  - `Test/EndpointCoverage.cls`, and `Test/SurfaceCoverage.cls` and `Test/ClassicPageGate.cls` (union-at-merge);
  - `screen-outlet.ts`, `strings.ts` (end), `_components.scss` (end);
  - `self-protection.test.mjs`;
  - `navigation.test.mjs` (one element; its message line is edited in place);
  - `screens.generated.ts` (regenerated);
  - EXPERIENCE.md's new row and paragraph.
- **Contended, not add-only (lead approval):**
  - EXPERIENCE.md :159;
  - `ui/angular.json` with `angular-json.test.mjs`;
  - the spine.
- **Not contended:**
  - `Port/SqlPort.cls` (`Executed`'s two raw fields are in place) and `Api/AtelierError.cls`;
  - `Test/ExplorerDescriptor.cls`, `DeveloperFloor.cls` and `DeveloperFloorRoutes.cls`;
  - `ui/browser/system-explorer.browser-spec.mjs`, `ui/tools/licenses.mjs` and `ATTRIBUTIONS.md`;
  - every new file;
  - epics.md's Story 19.7 block (this epic's).
- Untouched: `scripts/ci-throwaway.sh`, because the fixture reuses `SqlConsoleProbe.Armed()`.

**Ledger inbox:** this story owns no entry. No read tool is added, so there is no DW-1001 occurrence.

## Verification

Load source into `ocupilot-a2-ci` and never restart it: `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)` in `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`. Run one test-runner call at a time, wait for each, and never re-submit after a client-side timeout. Remove every `OcuProbe197*` object and principal after the run.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call, for:
  - `SqlBrowse`, `SqlBrowseLive`, `SqlDataRoutes`, `SqlPort`, `SqlPortLive`;
  - `ExplorerDescriptor`, `ClassicPageGate`, `DeveloperFloor`, `DeveloperFloorRoutes`, `EndpointCoverage`, `SurfaceCoverage`.
  - Expected green.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts'` (loop): expected green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for `system-explorer-data-browser.browser-spec.mjs`, `system-explorer.browser-spec.mjs` and `a11y-structural-invariants.browser-spec.mjs`. Expected green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete): expected green apart from the known `WireSecurityRead` (DW-1554) and `Retention` (DW-1929) residue.

**Planned mutations (Rule 19)**, one per AC:

- AC1: the store issues no views read → `data-browser.page.spec.ts`, "expanding a schema lists its tables and views".
- AC2: `BrowsePlan` skips the constraint query → `SqlBrowseLive`'s composite-key leg.
- AC3: `BrowseRun` maps `$Char(0)` to `null` → `SqlBrowseLive`'s NULL-versus-empty leg.
- AC4: `LikeValue` stops escaping `%` → `SqlBrowse`'s literal-`%` leg and the live `n%` leg.
- AC5: `nextSort` returns asc after desc → `data-browser-model.test.mjs`'s tri-state case.
- AC6: `Executed`'s `%Prepare(pText, 1)` becomes 0 → `SqlBrowseLive`'s held-open stale-plan leg.
- AC7: the handler's pre-check is dropped → `SqlDataRoutes`'s own-table leg.
- AC8: `BrowseRun` passes bound 0 → `SqlBrowseLive`'s stopped leg, through `SqlPortFixture`.
- AC9: the descriptor's `classicPage` becomes `""` → `ExplorerDescriptor`. The view-page union is dropped → `ClassicPageGate`'s view-page leg.
- AC10: `color: var(--ite-fg)` in the new rules → the token check.
- AC11: `BrowseRun` answers no rows → the browser spec's created-table leg.

**Mutations run (Rule 19)**, each reverted and the tree checked byte-identical:

- mutation: AC1, the store's tree loop drops the views read -> `data-browser.page.spec.ts` "expanding a schema lists its tables and views" (and the APG keys case) red.
- mutation: AC2, `BrowsePlan` skips `BROWSEKEYQUERY` -> `SqlBrowseLive.TestTheKeyIsFoundAndOrdersAnUnsortedPage` (Keyed and Pair legs) and `TestTheSortAndItsClearing` red.
- mutation: AC3, `CellOf` answers `$Char(0)` as NULL -> `SqlBrowseLive.TestNullEmptyStreamAndBinaryCells` and `SqlBrowse.TestTheCellMapping` red.
- mutation: AC4, `LikeValue` stops escaping `%` -> `SqlBrowse.TestLikeValueEscapesThenMapsTheWildcards` and `TestComposedNamesBindsAndOrders`, and `SqlBrowseLive.TestFiltersMatchTheWholeValue`'s `n%` leg red.
- mutation: AC5, `nextSort` answers ascending after descending -> `data-browser-model.test.mjs` tri-state case red.
- mutation: AC6, `Executed`'s `%Prepare(pText, 1)` becomes 0 -> `SqlBrowseLive.TestAStalePlanHeldOpenIsStillRefused` and the column-grant leg of `TestTheReadChecksTheCallersPrivileges` red.
- mutation: AC7, `HandleBrowse` drops the check on the requested name -> `SqlDataRoutes.TestOcuPilotsOwnTablesAreRefused`'s unknown-table-in-an-OcuPilot-schema leg red.
- mutation: AC8, `BrowseRun` runs the page with bound 0 -> `SqlBrowseLive.TestThePageAndTheCountShareTheBound` red, through `SqlPortFixture`.
- mutation: AC9, the descriptor's `classicPage` becomes `""` -> `ExplorerDescriptor.TestDataBrowserKeysTheClassicOpenTablePage` red; `SqlData.Gate` drops the view page -> `ClassicPageGate.TestAnAssignedPageGatesTheDataBrowser`'s view-page leg red.
- mutation: AC10, `color: var(--ite-fg)` in `.ocu-data-browser-null` -> the token check in `data-browser-model.test.mjs` red.
- mutation: AC11, `BrowseRun` answers its rows empty -> `system-explorer-data-browser.browser-spec.mjs` AC11 (and AC1-AC5) red.
- mutation: DW-2025's case, `BrowseRun` classifies the page first -> `SqlBrowseLive.TestAnUnrecordedFilterStillAnswersRows` red; `shipLicenses` drops the append -> `licenses.test.mjs` red.
- mutation: AC2/AC6, `BrowsePlan` keeps the request's schema and name -> `SqlBrowseLive.TestARequestResolvesToTheCatalogsSpelling` red.
- mutation: AC6, `BrowsePlan` reads a view's base tables from `SELECT COUNT(*)` -> `SqlBrowseLive.TestTheReadChecksTheCallersPrivileges`'s view column-grant leg red (-99).
- mutation: AC7, `BrowsePlan` carries on with the view alone when its tables are unrecorded -> `SqlBrowseLive.TestAViewWhoseTablesAreUnrecordedFailsClosed` red, through `SqlBrowseFixture`.
- mutation: AC8, `BrowseRun` gives the count a fresh bound -> `SqlBrowseLive.TestTheCountTakesWhatRemainsOfTheBudget` red; `Executed`'s answer cut stops setting `more` -> `SqlBrowseLive.TestAnAnswerCutBySizeSaysMore` red.
- mutation: AC3, `BrowseRun` answers a NULL cell as `""` -> `SqlDataRoutes.TestCellsAndAColumnGrantOverTheWire` red.
- mutation: Order, `HandleBrowse` reads the body before the gate -> `SqlDataRoutes.TestTheGateAndAnUnknownTable`'s bad-body leg red.
- mutation: AC3/AC4/AC5, in `data-browser.store.ts`: `nextPage` steps by the page size -> "Next after a page cut short" red; `cycleSort` and `applyFilter` keep the offset -> the sort and filter cases red (each now taken from the second page); `clearFilters` keeps the offset -> "Clear filters" red; the generation check is dropped -> "an answer to an older request is dropped" red.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Data browser ships as a listed System Explorer screen (side bar 11): a schema tree over Story 19.5's three catalog reads beside a grid ported from iris-table-editor, reading one page at a time through `POST /explorer/sql/data`, which `SqlPort.BrowsePlan` and `BrowseRun` serve from the caller's own catalog with every value bound and privilege checks on. Rows stay on the screen.

**Files.**

- `src/OcuPilot/Port/SqlPort.cls`: `KINDS`, `KindOfType`, `Quoted`, `LikeValue`, `BrowseRequest`, `Composed`, `CellOf`, `BrowsePlan`, `BrowseRun` and private helpers; `Executed` gains `more` and `cut`.
- `src/OcuPilot/Area/Explorer/SqlData.cls` (new): the route's handler, in the spec's order.
- `src/OcuPilot/Screen/Descriptor/ExplorerSqlData.cls` (new): the screen's declaration.
- `src/OcuPilot/Api/Router.cls`, `Api/AtelierError.cls`: the route and its two codes.
- `src/OcuPilot/Test/SqlBrowse.cls`, `SqlBrowseLive.cls`, `SqlBrowseProbe.cls`, `SqlBrowseFixture.cls`, `SqlDataRoutes.cls` (new); roster edits in `ExplorerDescriptor`, `ClassicPageGate`, `DeveloperFloor`, `DeveloperFloorRoutes`, `EndpointCoverage`, `SurfaceCoverage`.
- `ui/src/app/core/data-browser-model.ts`, `areas/system-explorer/data-browser.{store,page}.ts`, `data-browser-{tree,grid}.ts` (new); the outlet entry, `screens.generated.ts`, 31 strings, `ocu-data-browser*` styles.
- `ui/tools/licenses.mjs`, `ui/licenses/iris-table-editor.txt`, `ATTRIBUTIONS.md`: the MIT notice shipped and recorded.
- Client tests: `data-browser-model.test.mjs`, `licenses.test.mjs`, two vitest specs, `system-explorer-data-browser.browser-spec.mjs`; roster edits in `navigation.test.mjs`, `self-protection.test.mjs`, `build-output.test.mjs`, `system-explorer.browser-spec.mjs`.
- `ui/angular.json` and `angular-json.test.mjs`: `maximumWarning` re-based to 2745kB (measured 2,744,433 bytes).
- EXPERIENCE.md: :159 in place, the Fixed-strings row at :598, the `### data-browser` paragraph.

**Review.** 21 findings (two layers): 13 patched (11 medium, 2 low), 8 rejected (3 false, 5 low), none deferred; reasons are in the triage log. One defect found by the sweep, not the layers: `SqlData`'s doc comment spelled a self-protection code, which `Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode` refuses; reworded, re-run green (run 4993).

**Follow-up review: recommended** (11 medium patched). Unverified risk: the view base-table lookup now prepares a select of every listed column; it is measured on the probe's views (a column grant, a view-only grant, a view over OcuPilot's table) and not on a view listing a stream or binary column.

**Verification.**

- `check-objectscript` 0 problems; its harness OK.
- Targeted classes, one per call, green: `SqlBrowse` 6, `SqlBrowseLive` 15, `SqlDataRoutes` 6, `SqlPort` 11, `SqlPortLive` 14, `ExplorerDescriptor` 15, `ClassicPageGate` 8, `DeveloperFloor` 10, `DeveloperFloorRoutes` 1, `EndpointCoverage` 2, `SurfaceCoverage` 4.
- `npm test`: 1,791 tools tests and 174 component files (2,306 tests) green; `lint-docs` clean.
- Browser, on the rebuilt and redeployed bundle: data browser 2/2, `system-explorer` 4/4, structural walk 12/12.
- Full ObjectScript sweep, 24 shards run one at a time, every class once: 445 classes, 3,627 tests. Reds not caused by this story: `MappingCodeGlobals` (the `^oddPKG("OCUPILOT")` residue Stories 19.6 and 19.15 recorded), `WireSecurityRead` (DW-1554), and seven journal and license classes this throwaway is not armed for.
- Every mutation in `## Verification` applied, red observed, reverted; the tree hash matched before and after; no `OcuProbe197` object or principal is left on `ocupilot-a2-ci`.

**Residual risks.** The bundle line and the Fixed-strings count (about 2,413 of 2,500) meet Epic 18's at merge and need re-measuring there. `TestThePageAndTheCountShareTheBound` and `TestTheCountTakesWhatRemainsOfTheBudget` depend on timing (a 0.005 s-per-row view; a Keyed page under half a second).
