---
title: 'Story 19.8: The data browser - editing, staging and export'
type: 'feature'
created: '2026-10-04'
status: 'done'
review_loop_iteration: 0
baseline_revision: 'bd62b225557c7b23289f3e23c3ceb2ad58974d50'
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-7-the-data-browser-tree-grid-filter-and-sort.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Data browser (Story 19.7) shows a table's rows but cannot change one, so a developer still edits rows with hand-written SQL. Atelier's `action/query` would run that SQL with privilege checks off (AD-61 rule 7), and iris-table-editor's grid saves each cell the moment it is typed, with no confirmation and a `rowsAffected` hard-coded to 1.

**Approach:** The grid becomes an editor. A person edits cells with an editor for each kind, inserts, duplicates and deletes rows, and every change is staged and keyed by the row's primary key. Save asks for confirmation once, then sends the staged rows through one unadvertised write tool, `explorer.sqldata.save` (AD-53). `Port/SqlPort` composes one guarded UPDATE, INSERT or DELETE per row from the caller's own catalog rows. Each statement is prepared with privilege checks on, as the signed-in user, with every value bound, and the instance's own row count decides each row's outcome. A row that fails rolls back on the screen. CSV export, the shortcut help, go-to-row and multi-table tabs move to a new Story 19.16 (Design Notes › Intent gap).

## Boundaries & Constraints

**Always:**

- **Order** (the shipped `Api/ScreenAction.Run`, unchanged):
  1. the screen's pairs;
  2. the target's hold on `(class, <ns>, sql)` (AD-34), the same key as the console's runs;
  3. the fresh read, which answers an empty plan after the port's gate;
  4. the declared values, shape and bounds;
  5. the prohibited set: the table's delimited name as text, then the resolved table or a view's base tables (`Prohibited.SqlRun`, reused unedited);
  6. the save.
- **Resolve from the caller's catalog.** The table, its columns and its key resolve exactly as `SqlPort.BrowsePlan` resolves them (reuse, never fork).
  - A view, a table with no key, or a key the caller cannot list makes the table read-only. A save to one is refused 409 `EXPLORER.DATA.READONLY` before any write.
  - A column is **editable** when it is listed, is not a key column, is neither identity nor generated (`IS_IDENTITY`, `IS_GENERATED`), and is neither `stream` nor `binary`.
  - A column is **insertable** on the same terms, except that key columns may be set.
  - A cut cell is never editable.
- **One statement per staged row, composed by the port** (AD-21). Identifiers come from the catalog, delimited with `"` doubled. Keys, new values and the values read are bound. Composition rules:
  - UPDATE: `UPDATE "S"."T" SET "c" = ?, … WHERE "k" = ? AND … AND <guard>`. The guard has one term per changed column:
    - `%EXACT("c") = ?` for a `text` column;
    - `"c" IS NULL` when the value read was NULL;
    - `"c" = ?` otherwise.
  - INSERT: `INSERT INTO "S"."T" ("c", …) VALUES (?, …)`.
  - DELETE: `DELETE FROM "S"."T" WHERE "k" = ? AND …`.
  - A value of `null` binds `""` (SQL NULL). A value of `""` binds `$Char(0)` (an empty string).
  - Each statement goes through `SqlPort.Executed`: `%Prepare(text, 1)`, ODBC select mode, the expected statement type (INSERT 2, UPDATE 3, DELETE 4), the namespace switched and restored, and the statement released.
- **Each row's outcome is the instance's.**
  - `saved` when `%ROWCOUNT` ≥ 1.
  - `changed` when an UPDATE matched no row; `gone` when a DELETE matched none.
  - `refused` when the prepare answers -99.
  - `error` for any other SQLCODE, carrying it and its message.
  - `stopped` for the row the alarm interrupts, which `Executed` rolls back.
  - `skipped` for every row after it.
  - Rows run in order. Each is its own statement, with no surrounding transaction.
- **Bounds.**
  - A save carries 1 to 100 staged rows. `changes` is at most 1,000,000 characters, each value at most 32,767 characters, and each column is named once per member.
  - One alarm budget of `BoundSeconds()` covers the plan and every row.
  - The grid stages nothing past 100 rows, and says so.
- **Values are screen-only** (AD-36, AD-39). Row values, keys, SQLCODEs and SQL messages reach the screen's answer and nothing else. They never reach a log line, the ledger, an audit payload, screen context, a tool result or stored state.
- **The tool.** `ADVERTISED` 0, and its baseline key ships `false`. It is action-style (AD-51): `SENDSBODY` 0, fresh read `PLAN`, write `RUN`, `DESTRUCTIVE` 1.
  - Its pairs are its screen's `RequiredPairs`. That set includes the Open Table page's custom resource and nothing beyond it (AD-8).
  - It declares no `CLASSICPAGES`.
- **The grid** keeps 19.7's APG pattern: one Tab stop and `aria-activedescendant`. An editor takes focus and gives it back to the grid. Styling uses `--ocu-*` tokens only.
- **Harvest** (iris-table-editor, MIT, read-only). Call sites are kept, never names. The parsers are ported with their defects fixed (Design Notes › Harvest).

**Never:**

- A save through `AtelierPort`, `action/query`, `SqlPort.Run`/`Classify`, `%Prepare(…, 0)` or `%ExecDirectNoPriv`. Never a value concatenated into SQL, and never a key sent as an id segment.
- A write to a view, a keyless table, a key, identity, generated, stream or binary column, or a cut cell.
- An advertised tool, an enabled key, a proposal, a ledger row or an agent marker for a person's save.
- An edit to `Kernel/Proposal/Prohibited.cls`, `Kernel/EntityType.cls`, `Kernel/EntityRef.cls`, `Api/Error.cls` or `Api/Router.cls`.
- CSV export, the shortcut help dialog, go-to-row, multi-table tabs, a calendar picker, a new third-party library, or the harvest's immediate per-cell save, its `Number()` conversion, its `new Date()` fallback or its plaintext-password session.

## I/O & Edge-Case Matrix

Rows were measured on `ocupilot-a2-ci` probe tables in `USER` (Design Notes › Measured). The request is `POST /api/ocupilot/screens/explorer.sqldata/action?ns=USER`, with `{action: "save", id: "sql", values: {schema, table, changes}}`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Update | `Edit` row `a`: Name `abc`→`abd`, original `abc` | `saved`, rowCount 1 | None |
| Every kind | one row changing Num, Dbl, Born, Stamp, Tm, Flag and Pt, with originals as the page read them | `saved` 1: each ODBC original compares equal | None |
| Concurrent change | original `abc`; the row now holds `ABC` (case only) or `x` | `changed`, rowCount 0, nothing written | Status cell |
| NULL / empty | Name → `null`; Note → `""`; original NULL | stored NULL; stored empty; guard `IS NULL` | None |
| Insert, delete | insert `{Code z, Name zed}`; delete key `b`, twice | `saved` 1; `saved` 1, then `gone` | None |
| Instance refusal | insert a duplicate Code; Num past its precision | `error` SQLCODE -120; `error` -105 | Status cell |
| Column grant | `SELECT` + `UPDATE(Name)`: a Name-only row; a row also changing Num | `saved`; `refused` (the whole row) | Status cell |
| Insert grant | `SELECT` + `INSERT(Code, Name)`: insert Code and Name; insert with Num; any delete | `saved`; `refused`; `refused` | Status cell |
| Read only | `SELECT` only: an update, an insert and a delete | `refused` each | Status cell |
| Held open | the composed text held prepared by `_SYSTEM`, for a principal without the grant | `refused` (-99) | Status cell |
| Not writable | a view; a keyless table; a column grant without the key column | 409 `EXPLORER.DATA.READONLY`, nothing run | Banner |
| Own tables | `%All` in the install namespace: a row of `OcuPilot_Kernel_State.Proposal`; an unknown table in an `OcuPilot` schema; a view over `Proposal` | 403 `PROHIBITED.OCUPILOTSQL`. The first two are refused before any statement (the unknown table answers 403, not 404); the view before any write | Banner |
| Bad changes | a key, identity, generated or stream column among values; a key member missing or extra; `original` names unequal to `values` | 400 `EXPLORER.DATA.CHANGES`, nothing run | Banner |
| Bad shape | an unknown `op`; 0 or 101 changes; a value of 32,768 characters; `changes` over 1,000,000 characters or not JSON | 400 `TOOL.ARGUMENTS`, before the read | Banner |
| Bound | four slow rows (a `HANG 1` trigger) under `SqlPortFixture` (2 s) | first rows `saved`; the interrupted row `stopped` and unchanged; the rest `skipped` | Status line |
| Gate | no `%Development:USE`; a custom resource on `%cspapp.exp.utilsqlopen` | 403 `AUTH.NOPRIVILEGE` naming the pair, before any read | Banner |

</intent-contract>

## Code Map

- **Port** (`src/OcuPilot/Port/SqlPort.cls`, not contended; reuse its private members from inside the class):
  - `ENDPOINTSQL`/`TYPEGUARD`/`TYPERUN`/`COMPOSEDTYPES` :36-47; the query keys :51-61, with `IDVALUE` `sql` :57; `MAXVALUE` 32767 :71, `MAXANSWER` :79.
  - `Invoke` :548-594 refuses any endpoint but `Sql` (:556). The new endpoint routes here.
  - `SnippetForm` :616 and `Snippet` :627-650 (AD-59) answer only for `Sql/RUN`.
  - `Gate` :657; `Executed` :885-1009, whose raw answer carries `rowCount` from `%ROWCOUNT` (:918-920), `stopped`, `rolledBack` and `changed` (set by a failed prepare or a type mismatch, :897-902); `PrepareProblem` :1760; `Remaining` :1717.
  - `BROWSECOLUMNSQUERY` :214 reads no `IS_GENERATED`. `BrowseName` :1177, `BrowseRequest` :1196, `BrowsePlan` :1412-1581: the key at :1491-1502; the plan shape is `{namespace, start, bound, table{schema,name,type}, columns[{name,type,kind,nullable,key}], key, tables, …}`.
  - `BrowseRun` :1600-1703 reports `truncated` for the whole answer only; `CellOf` :1363 sets the cell's cut flag at :1659.
- **Tool template:** `src/OcuPilot/Screen/Tool/ExplorerSqlRun.cls`, read in full (210 lines): `ADVERTISED` 0, `SCREENVALUES`, `READTYPE`/`WRITETYPE`, `READANSWERS`, `FINGERPRINTSUBJECT`, `PrivilegePairs` :91, `ScreenActionDelta` :121-160, `PortQuery` :165, `StateDiff` :178, `WriteOutput` :203. The base `Screen/Tool/Write.cls` holds the parameters :30-217 and checks `FINGERPRINTSUBJECT` against `READANSWERS` (`Registry.FingerprintSubjectProblem`).
- **Route:** `src/OcuPilot/Api/ScreenAction.cls`:
  - `Run` :220-387 takes the hold (:262), reads fresh with payload `""` (:274), applies `ScreenActionDelta` (:289), builds the `Body` projection (:434-468), runs `Gate` with the prohibited set (:331) and then `Apply` (:346). `ReadBack.Of` gives an `action` verdict for `SENDSBODY` 0 (`Kernel/Proposal/ReadBack.cls:117,218`). It answers `{action, target, readBack, output}`.
  - `Values` :480-530: every declared value must be a non-empty string; there is no length cap.
  - The route is `/screens/:screen/action` (`Router.cls:142`). `explorer.sqldata` already resolves to the descriptor.
- **Prohibited set, reused unedited** (`src/OcuPilot/Kernel/Proposal/Prohibited.cls`, contended):
  - The class/routine arm :1098-1108 sends every tool whose `WRITETYPE` is `RUN` to `SqlRun` :2072-2112. `SqlRun` checks the payload's `statement` with `SqlStatement` first, then reads through the tool's `READTYPE`/`PortQuery` and judges `Tables`, `RecordsTables` and `DefaultSchema`. A guard read answered 4xx is not judged there.
  - `SqlStatement` :2041-2064.
- **Handler and descriptor (19.7):** `src/OcuPilot/Area/Explorer/SqlData.cls` (`Gate` :74-82 unions the view page; unchanged). In `src/OcuPilot/Screen/Descriptor/ExplorerSqlData.cls`, `rowActions` is `[]` at :36; the console's `ExplorerSqlQuery.cls:38` declares `run`.
- **Codes:** `src/OcuPilot/Api/AtelierError.cls`. Each code is a code/reason pair; the last pair is `DATANOTFOUND` :197-199, and the class closes at :201.
- **Governance:** `src/OcuPilot/Kernel/Governance/Baseline.cls`, explorer keys :158-168 (`sqlquery.run` false :167). Contended; union at merge.
- **Server tests to follow:**
  - `Test/SqlConsoleProbe.cls`: `Armed` :59, `EnsurePrincipals` :281-314, `Grant` :317-331, `Hold`/`Release` :201-232, `ProbeAs`/`RunAs` :378-443.
  - `Test/SqlBrowseProbe.cls` (`Make` :85-168, principals :213-253); `Test/SqlBrowseLive.cls` setup :45-60; `Test/SqlPortFixture.cls`.
  - `Test/SqlDataRoutes.cls` (19.7's HTTP test).
- **Server rosters** (anchors from the plan read; recheck counts at edit time):
  - `Test/ExplorerDescriptor.cls`: the baseline string :165, the actions `$Case` :170, the data browser expectation :308 and its doc :294-298.
  - `Test/DeveloperFloor.cls`: `TOOLS` :37, `HELDWRITES` :43, "thirty-three" at :9-10, `TestTheToolsTheDeveloperHoldsAreTheDeclaredThirtyThree` :460, and the messages :483-484.
  - `Test/GovernanceBaseline.cls`: `DISABLED` :15 and the message :71. `Test/Governance.cls`: `EXPLORERDISABLED` :33.
  - `Test/ReadTool.cls`: :93 (251 tools, 149 write tools) and :94 (sorted names).
  - `Test/ToolRoundTrip.cls`: `REFUSEEMPTY` :68.
  - `Test/SurfaceCoverage.cls`: tool rows :322-324.
  - `Test/ToolEmit.cls`: the `explorer.sqlquery.run` case at :240.
  - `Test/Prohibited.cls`: the settable-count `$Case` :428, driven by `SqlPort.COMPOSEDTYPES`.
  - `Test/DraftRegistry.cls` :128-167, driven by `SnippetForm`.
- **Client** (`ui/src/app/`):
  - `core/data-browser-model.ts` (229 lines): `cellView` :167, `moveCell` :74, `filterValue` :180 (BIT Yes/No).
  - `areas/system-explorer/data-browser.store.ts` (527 lines): state :176-211, `openObject` :355, `refresh` :366, `read` :472-496 with its `generation` :205, and `forget` :499. Every page change re-reads and replaces `answer`.
  - `data-browser.page.ts` (466 lines): template :65-153, actions :90-93, status line :142 and `statusLine` :340, `onOpen` :371.
  - `data-browser-grid.ts` (369 lines): template :87-173, cells :156-166, `rowViews` :267-285, `onGridKeydown` :330-351. Body Enter is unused today.
- **Confirmed-run pattern (19.6):**
  - `sql-query.store.ts` `proceed` :371-399: `sender.sendFor(descriptor, 'run', 'sql', values, sink, scope)`, then `lastOutput()`.
  - `sql-query.page.ts` dialog :210-217; `shell/warning-dialog.ts` inputs :92-107.
  - `shell/screen-action-handler.ts` `send` :1128-1199 publishes the change event and `sendFor` :1210. The data browser has no read, so a `class` event does not re-read its grid; the page re-reads itself.
- **Unsaved work:** `core/form-dirty.ts` (`setDirty` :60, `requestLeave` :78); `app.routes.ts:24` already guards every `form-page` route, the data browser's included; the leave dialog to copy is `source-editor.page.ts:111-113`. The namespace switch does not ask `FormDirty`.
- **DW-2028 source:** `shell/data-table.ts`. The code is inline and private, so it is ported, not imported:
  - `CellTooltip` :171-184 and the markup :458-468 (`aria-hidden`);
  - the focus path `afterActiveCellMoved`/`updateFocusTooltip` :1290-1318;
  - the pointer path :1325-1373, then show, place and hide :1379-1417 (through `OverlayStack`);
  - `bodyCellOf`/`cutText` :1911-1925 and `tooltipDelayMs` :1936-1941;
  - the dismissal listeners :760-782.
  - Styles: `ui/src/styles/_components.scss:6290-6311` (`.ocu-data-table-tooltip`), reused as they are.
  - Pinned by `shell/data-table.spec.ts:1188,1223` and `ui/browser/data-table-columns.browser-spec.mjs:530-746`.
- **Client tests to follow:**
  - `data-browser-grid.spec.ts` (`mount` :34-54, `press` :60);
  - `data-browser.page.spec.ts` (`mount` :110-175; it has no `ScreenActionHandler` stub yet; copy the sql-query spec's);
  - `ui/tools/data-browser-model.test.mjs`;
  - `ui/browser/system-explorer-data-browser.browser-spec.mjs` (`removeProbe` :48-56, `runConfirmed` :190-199).
- **Strings, styles and the outlet:**
  - `core/strings.ts`: data browser keys :5177-5241, `} as const` :5306.
  - `_components.scss`: `ocu-data-browser*` :8019-8260, end :8299.
  - `shell/screen-outlet.ts:230`: unchanged.
- **Budgets:**
  - `ui/tools/strings.test.mjs:581-584` bounds Fixed strings at 2,500, and 2,444 are used (measured).
  - `ui/angular.json:51-57` `maximumWarning` 2780kB, pinned by `ui/tools/angular-json.test.mjs:483`, with about 0.8 kB headroom (inference).
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`): the side-bar line :159, the closed dialog set :173, the Data browser Fixed-strings row :598 (the table's last row), and `### data-browser` :667-677.
- **Harvest** (`/Users/jbrandt/git/iris-table-editor`, v0.2.3, commit 29971a9, read-only):
  - `packages/core/src/utils/DataTypeFormatter.ts`: `parseUserTimeInput` :98-154, `parseUserDateInput` :172-230, `parseUserTimestampInput` :250-300, `parseNumericInput` :320-338.
  - `packages/webview/src/grid.js`:
    - edit entry `handleCellKeydown` :3364-3552 (F2 :3404, Enter :3415, Backspace :3530, printable :3538-3549);
    - `handleEditInputKeydown` :3059-3149 (undo :3060-3074);
    - `enterEditMode`/`exitEditMode` :1474-1833;
    - boolean toggle :378-438;
    - add, duplicate and save row :2590-2727;
    - reconciliation `handleSaveCellResult` :1933-2004, keyed by `` `${pk}:${column}` `` :1767;
    - rollback :1865-1903.
  - `packages/core/src/services/QueryExecutor.ts:184,203`: the UPDATE and the hard-coded `rowsAffected: 1`.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** (`ocupilot-a2-ci`, before code; probe schema `OcuProbe198`, removed after). Record the results in Design Notes.
  - (a) A class-defined `%Persistent` table with no declared key: confirm that `COLUMNS` lists `ID`, read its `IS_IDENTITY`/`IS_GENERATED`, and check that `UPDATE … WHERE "ID" = ?` saves.
  - (b) A `HANG 1` trigger table under `SqlPortFixture`: confirm the `stopped`/`skipped` split, and that the interrupted row reads unchanged.
- [x] `src/OcuPilot/Port/SqlPort.cls`. Add-only, except for the four in-place edits listed.
  - `ENDPOINTDATA` `SqlData` and `TYPEPLAN` `PLAN`. `COMPOSEDTYPES` becomes `Sql/RUN,SqlData/RUN`.
  - Query keys `schema`, `table` and `changes`. Bounds `MAXCHANGES` 100 and `MAXCHANGESTEXT` 1,000,000.
  - In place:
    - `BROWSECOLUMNSQUERY` also selects `IS_GENERATED`. Each plan column gains `identity` and `generated` booleans, which 19.7's answer ignores.
    - `Invoke` routes `SqlData/PLAN` and `SqlData/RUN`.
    - `SnippetForm` and `Snippet` render `SqlData/RUN`: each change's composed text with `?`, each value as a `"<column>"` placeholder, and never a row value.
    - `BrowseRun` answers `cuts`, the `[row, column]` pairs of cut cells.
  - Public pure helpers:
    - `SaveChanges(text, .changes, .problem)`: shape and bounds, each refusal a sentence.
    - `ChangeProblem(plan, changes)`: the column rules against the plan.
    - `SaveComposed(plan, change)`: the text, its statement type and its values in order.
    - `Editable(column)` and `Insertable(column)`.
  - `SavePlan(ns, query, .answer, .http, .fault)`. With no schema it answers the empty plan after `Gate`. Otherwise it reuses `BrowsePlan` for `{schema, table}` and answers `{Namespace, Kind: table|view|"", Tables, RecordsTables: true, DefaultSchema, statement, schema, table, changes}`, with the last four `null`.
  - `Save(ns, query, .answer, .http, .fault)`, in this order:
    1. `Gate`;
    2. `SaveChanges`, else 400 `TOOL.ARGUMENTS`;
    3. `BrowsePlan`: 404 `EXPLORER.DATA.NOTFOUND`; 409 `EXPLORER.DATA.READONLY` for a view or an empty key;
    4. `ChangeProblem`, else 400 `EXPLORER.DATA.CHANGES`;
    5. each change through `Executed` with what remains of the budget, its outcome mapped per Boundaries.
  - It answers `{outcome: "saved", results: [{index, outcome, rowCount?, sqlcode?, message?, seconds?}], saved, failed}`.
  - It logs nothing of a value, a key, a SQLCODE or a message. A per-row failure is an answer, never a `Fail`.
- [x] `src/OcuPilot/Screen/Tool/ExplorerSqlDataSave.cls` (new), modeled on `ExplorerSqlRun.cls`:
  - `TOOLNAME` `explorer.sqldata.save`, `DESCRIPTORCLASS` `ExplorerSqlData`, `ADVERTISED` 0, `PORTCLASS` `SqlPort`.
  - `SCREENACTIONS` `save` and `SCREENVALUES` `save=schema:table:changes`.
  - `READTYPE` `PLAN`, `WRITETYPE` `RUN`, `SENDSBODY` 0, `DESTRUCTIVE` 1, `CHANGEACTION` `updated`.
  - `STATEFIELD` and `PRECONDITIONFIELD` `Kind`.
  - `READANSWERS` `Namespace,Kind,Tables,RecordsTables,DefaultSchema,statement,schema,table,changes`; `FINGERPRINTSUBJECT` `Namespace,Kind,Tables,statement,schema,table,changes`; `IDARGUMENT` `Target`.
  - `Endpoint` → `ENDPOINTDATA`; `IdParam` → `IDKEY`; `PrivilegePairs` → `Gate.RequiredPairs(DESCRIPTORCLASS)`.
  - `SettableFields`: statement, schema, table and changes.
  - `ScreenActionDelta`: the schema and table checked as `BrowseRequest` checks them, then `SaveChanges`. It sets `statement` to `Quoted(schema)_"."_Quoted(table)`, the text the prohibited set judges first.
  - `PortQuery`, `StateDiff` (Kind and Tables) and `WriteOutput` (passes `{outcome…}` through).
- [x] `src/OcuPilot/Screen/Descriptor/ExplorerSqlData.cls`, in place: `rowActions` `[{"id":"save","selfProtection":""}]`. Regenerate `ui/src/app/core/screens.generated.ts` with `node tools/screen-mirror.mjs`.
- [x] `src/OcuPilot/Api/AtelierError.cls`, add-only:
  - `DATACHANGES` (`EXPLORER.DATA.CHANGES`, 400);
  - `DATAREADONLY` (`EXPLORER.DATA.READONLY`, 409);
  - reasons in Design Notes › Strings.
- [x] `src/OcuPilot/Kernel/Governance/Baseline.cls`, add-only after :168: `explorer.sqldata.save` false (approved by=merge_gate: it stands under AD-22's "through 2026-10-04" if 19.8 merges to feature on 2026-10-04 PDT, and otherwise waits for the owner's ruling on keys after that date).
- [x] `ui/src/app/core/data-browser-model.ts`, add-only. Pure rules, ported with call sites kept and names changed:
  - `parseCellInput(column, text)` answers `{value}` or `{problem}`:
    - integer types: digits with an optional sign;
    - numeric and double: a decimal, with an exponent only for double. The text is sent as typed, never through `Number()`.
    - dates: `YYYY-M-D`, `D-M-YYYY` and `M/D/YYYY` (`D/M/YYYY` when the first number is over 12), with the day held to its month and no `new Date()` fallback;
    - times: `H:MM[:SS[.f]]` with an optional AM/PM;
    - timestamps: a date and a time, the fraction kept;
    - text as typed.
  - `nextBoolean(value, nullable)`: NULL → 1 → 0, then → NULL when nullable, else → 1.
  - `rowKey(key, row)`: canonical JSON of the key values in key order.
  - `editable(column)`, `insertable(column)`, `isCut(cuts, r, c)`.
  - `StagedChanges` (framework-free): updates keyed by `rowKey`, holding the original and the new value per column; inserts by a client id; deletes by `rowKey`. Its members:
    - `stage`, which refuses the 101st row;
    - `unstage`, used when a committed value equals the value read;
    - `toggleDelete`, `addRow`, `duplicate`, `discard` and `count`;
    - `overlay(page)`, which shows staged values on rows that match by key;
    - `toWire()`, which records each sent index's key;
    - `applyResults(results)`, which drops saved rows, rolls failed rows back to the values read and keeps each outcome by key.
- [x] `ui/src/app/areas/system-explorer/data-browser.store.ts`:
  - Hold one `StagedChanges`. It survives paging, sort, filter and refresh, and is cleared on `openObject` and `forget`; `forget` announces the discard.
  - Mark `FormDirty` while anything is staged.
  - `save()` calls `sendFor(descriptor, 'save', 'sql', {schema, table, changes}, sink, scope)`. On success it applies `lastOutput()` by key and then re-reads the page. A refusal goes to `refusal` and nothing is applied.
- [x] `ui/src/app/areas/system-explorer/data-browser-grid.ts`:
  - **Editor keys:** F2 or Enter opens the editor at the end of the value; a printable key opens it with that character; Backspace opens it empty. Delete stages NULL on a nullable column.
  - **BIT:** Enter, Space and F2 toggle the value instead of opening an editor.
  - **In the editor:**
    - Escape cancels.
    - Ctrl/Cmd+Z restores the value the editor opened with.
    - Enter and Shift+Enter commit and move down and up; Tab and Shift+Tab commit and move right and left, without wrapping.
    - Blur commits.
    - An invalid value keeps the editor open with `aria-invalid` and its hint linked by `aria-describedby`.
  - **Rows:** staged values marked, new rows at the top, and a leading status cell when the table is editable.
  - **DW-2028:** the cut-cell tooltip on pointer and on the active cell, hidden while an editor is open.
- [x] `ui/src/app/areas/system-explorer/data-browser.page.ts`:
  - Actions: Add row, Duplicate row, Delete row / Restore row, Save changes (n) and Discard changes.
  - The read-only line.
  - The warning dialog, whose verb and consequence carry the counts and the table.
  - The leave dialog when opening another table while changes are staged.
  - Announcements on the status line.
- [x] `ui/src/app/core/strings.ts` (end) and `ui/src/styles/_components.scss` (end): add-only keys, and `ocu-data-browser-*` rules for the editor, the staged and deleted marks and the status cell, on tokens.
- [x] EXPERIENCE.md:
  - :159 in place: add 19.8, and "and edits a table's rows".
  - :173 in place: add "save the data browser's staged changes (Data browser, Story 19.8)".
  - A Fixed-strings row after :598.
  - Paragraphs in `### data-browser`: editing keys, staging and its cap, the save and its outcomes, and rollback.
  - Move the citations (`npm run test:tools`).
- [x] `ui/tools/strings.test.mjs` :581-584: raise the bound to 2,600 (approved by=merge_gate, under the second-to-land rule; Design Notes › Strings).
- [x] **DW-2028 (owned):** port `data-table.ts`'s cut-cell tooltip into `data-browser-grid.ts`, call sites kept. `data-table.ts` is untouched. Pinned by the AC13 grid spec and browser leg.
- [x] **Server tests (new):**
  - `src/OcuPilot/Test/SqlSave.cls` (pure): every `SaveChanges` refusal, every `ChangeProblem` rule, `SaveComposed` (texts, the guard per kind, NULL as `IS NULL`, `null`/`""` binding, value order), `Editable`/`Insertable`, and the outcome mapping.
  - `src/OcuPilot/Test/SqlSaveProbe.cls` (fixture, `OcuProbe198` in `USER`):
    - tables: `Edit` (PK `Code`, every kind), `Pair` (composite PK), `Ident` (identity), `Comp` (generated and rowversion, keyless), `Slow` (a `HANG 1` trigger), and a view;
    - principals `OcuProbe198Up` (SELECT, UPDATE), `OcuProbe198Col` (SELECT, `UPDATE(Name)`), `OcuProbe198Ins` (SELECT, `INSERT(Code,Name)`) and `OcuProbe198Ro` (SELECT), each with `SqlConsoleProbe.EnsurePrincipals`' role pairs, created only where `SqlConsoleProbe.Armed()` reads 1;
    - no arming variable of its own.
  - `src/OcuPilot/Test/SqlSaveLive.cls`: every matrix row at the port. This covers the held-open text through `SqlConsoleProbe.Hold`, the bound through `SqlPortFixture`, and a failed save that logs nothing of the request.
  - `src/OcuPilot/Test/SqlDataSaveRoutes.cls` (HTTP):
    - the order (pairs before values, values before the prohibited set);
    - `TOOL.ARGUMENTS`, `EXPLORER.DATA.CHANGES` and `READONLY`;
    - own tables, including the unknown `OcuPilot` table answering 403;
    - a success answer `{action: updated, target {class, USER, sql}, readBack verdict action, output}`;
    - a custom resource on the Open Table page.
- [x] **Server rosters** (Code Map anchors):
  - `ExplorerDescriptor`: the baseline row, the actions arm `ExplorerSqlData:"|save|"`, :308 and its doc.
  - `DeveloperFloor`: append to `TOOLS` and `HELDWRITES`; thirty-three becomes thirty-four, the method renamed.
  - `GovernanceBaseline` `DISABLED` and its message; `Governance` `EXPLORERDISABLED`.
  - `ReadTool`: 252, "fifty-two", 150 write tools, 19.8 in the story list, and the name sorted in.
  - `ToolRoundTrip` `REFUSEEMPTY` `explorer.sqldata.save:TOOL.ARGUMENTS`.
  - `SurfaceCoverage`: a tool row → `SqlSave.TestTheToolDeclaresItsWritePath`.
  - `ToolEmit`: the same-shape case. `Prohibited` :428: `"explorer.sqldata.save": 4`.
- [x] **Client tests:**
  - `ui/tools/data-browser-model.test.mjs`: the parsers (each accepted and refused form, 2^53+1 kept as typed, `2026-02-31` refused, fractions kept) and `StagedChanges` (key reconciliation after a page change, the cap, `applyResults` by key after the page moved).
  - `data-browser-grid.spec.ts`: the editor keys, undo, cut cells closed, and the tooltip.
  - `data-browser.page.spec.ts`: the actions, the dialog's Proceed and Cancel, a mixed answer's rollback, the re-read, `FormDirty`, the leave dialog and the namespace discard.
  - A new `ui/browser/system-explorer-data-browser-edit.browser-spec.mjs`: real-instance edit, save and reconcile; the tooltip's geometry; AC14.
- [x] **Client rosters:** `ui/tools/self-protection.test.mjs` `ATELIER_REFUSALS` gains the two reasons.
- [x] `ui/angular.json` and `ui/tools/angular-json.test.mjs`: re-base `maximumWarning` to the measured build (DW-1166). Stop and ask above 3,800 kB.

**Acceptance Criteria:**

- **AC1 (editors):** Given `Edit` open in Data browser, when each kind is edited, then:
  - a valid entry stages the instance's form: a number exactly as typed; a date, time or timestamp in ODBC form with its fraction kept; BIT toggled.
  - An invalid entry stays in the editor, marked invalid with its hint, and stages nothing.
  - Key, identity, generated, stream, binary and cut cells never open an editor.
  - Delete stages NULL only on a nullable column.
- **AC2 (edit-mode undo):** Given an open editor, when Ctrl/Cmd+Z is pressed, then the editor shows the value it opened with and stays open. Escape closes it without staging, and committing the value read unstages the cell.
- **AC3 (rows):**
  - Given an editable table, when Add row, Duplicate row and Delete row are used, then:
    - a new row appears at the top;
    - a duplicate copies the row except its identity, generated, stream, binary and cut cells, with key columns left empty;
    - Delete marks a row and Restore unmarks it, while Delete removes a new row.
  - The 101st staged row is refused with its sentence.
- **AC4 (a confirmed write):**
  - Given staged rows, when Save is pressed, then the warning dialog names the table and how many rows change, are added and are deleted.
  - Cancel sends nothing.
  - Proceed sends one `save` action through `explorer.sqldata.save`, which no provider tool list, dispatch lookup or screen context's `tools` carries.
  - Each outcome comes from the instance's row count: an UPDATE matching nothing reads `changed`, never `saved`.
- **AC5 (optimistic, rolled back):** Given a save in which one row is `saved`, one hits a duplicate key, one is refused -99 and one changed concurrently, when it answers, then:
  - the saved row leaves staging, and the page re-reads;
  - each failed row returns to the values read (an insert removed, a delete restored), and its status cell names the outcome;
  - the status line summarizes.
- **AC6 (key reconciliation):**
  - Given changes staged on page 1, when the person pages, sorts, filters or refreshes and returns, then each staged value shows on the row with the same key.
  - A save answer applied after the page has moved marks rows by key, never by position.
- **AC7 (the caller's privileges):** Given the four principals, when each saves, then each row is `saved` or `refused` exactly as the matrix's grant rows say, also while `_SYSTEM` holds the composed text prepared.
- **AC8 (concurrency):** Given a row changed after it was read, when an UPDATE of that column is saved, then no row changes and the outcome is `changed`, also for a case-only change. A NULL read is guarded with `IS NULL`, and a DELETE of a removed row reads `gone`.
- **AC9 (self-protection, not writable):**
  - Given a `%All` caller in the install namespace, when it saves to an `OcuPilot` table or to an unknown name in an `OcuPilot` schema, then it is answered 403 `PROHIBITED.OCUPILOTSQL` before any statement.
  - A view over OcuPilot's tables is refused 403 before any write.
  - Any other view, a keyless table and a column grant without the key are answered 409 `EXPLORER.DATA.READONLY`, and the grid offers no editor there.
- **AC10 (bounds, screen-only):**
  - Given the bounds, when they are passed, then the matrix's 400s answer.
  - A row past the budget is `stopped` and unchanged, and later rows are `skipped`.
  - No value, key, SQLCODE or message reaches a log line, the ledger, an audit payload, screen context or a tool.
  - A person's save writes no ledger row and no marker.
- **AC11 (unsaved work):** Given staged changes, then:
  - leaving the route asks;
  - opening another table from the tree asks with the same leave dialog;
  - a namespace switch discards them and says so;
  - paging, sorting, filtering and refreshing keep them.
- **AC12 (accessibility, as the portal):**
  - Given the grid, when a cell is edited, then focus moves into the editor and back to the grid on its cell.
  - The status line announces editing, the staged count, undo, discard and the save summary, and each status cell reads its state as text.
  - The structural walk passes in three passes: wide light, narrow light and wide dark.
- **AC13 (DW-2028):** Given a cut cell, when the pointer rests on it or it becomes the active cell while the grid has focus, then the data table's tooltip shows its text. Escape, scroll, a pointer press or opening an editor hides it.
- **AC14 (Integration, Rule 1):** Given a table SQL query (Story 19.6) created in `USER` on the real instance, when Data browser changes a value and saves, then SQL query's SELECT on that table returns the new value.

## Spec Change Log

- 2026-10-04, lead (spec gate): the split is approved (Story 19.16 `19-16-the-data-browser-export-shortcuts-go-to-row-and-tabs` takes criterion 3; epics.md, story_order and the tracker amended); the baseline key, the Fixed-strings bound of 2,600, EXPERIENCE.md :159 and :173, and the bundle re-base are approved by=merge_gate; the spine carries the drafted amendments (AD-61's save case, AD-21, AD-36, AD-39, AD-7, AD-10, AD-8, AD-44, AD-13, AD-51, AD-53's fourth unadvertised tool and named gap sixteen).

## Review Triage Log

### 2026-10-04 — Review pass

- verdicts: 19 findings — high 0, medium 8, low 6, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` A failed insert's removal is untested on the client (AC5's duplicate key) — added page spec "a failed insert is removed…": an insert answered `error` -119 leaves no New row; mutation recorded.
  - `[medium]` `[patch]` The error, stopped and skipped Change-cell texts are unasserted — the same case asserts "SQLCODE -105: <message>" and "Not run: the save stopped first." twice; mutation recorded.
  - `[medium]` `[patch]` `identity`, `generated` and `cuts` from the wire are untested through the store — added page spec "a generated, an identity or a cut cell opens no editor…" on an answer carrying them; two mutations recorded.
  - `[medium]` `[patch]` A keyless table's read-only state is untested on the client (AC9) — added a keyless leg to the view case; mutation recorded.
  - `[medium]` `[patch]` The tooltip's uncut cell and scroll dismissal are untested (AC13) — extended the edit browser spec's AC13 leg; two mutations recorded, each rebuilt and copied in.
  - `[medium]` `[patch]` The cap's sentence is unasserted (AC3) — added page spec "the 101st staged row is refused with its sentence"; mutation recorded.
  - `[low]` `[reject]` A save whose plan runs out of budget is untested — the catalog plan rarely exhausts `BoundSeconds()`, and pinning it needs a new port seam, more than a direct correction.
  - `[low]` `[reject]` AC10's no-ledger and no-marker assertions have no positive control — `Ledger.Name` holds the canonical tool name, so the count can fail; AC10 carries its demonstrated mutation, and minting nothing for a screen action is the kernel's contract.
  - `[medium]` `[reject]` A failed insert disappears with its reason, only the summary counting it, and "Already removed." cannot show after the re-read — AC5 says a failed insert is removed and a delete restored; showing the reason needs an AC5 amendment (Auto Run Result, for the lead).
  - `[low]` `[patch]` `discard` left `savingValue` set, so leaving the page during a save left editing off when it opened again — `discard` clears it; page-spec case and mutation recorded.
  - `[low]` `[reject]` An empty new row is counted but never sent — uncommon, and the fix needs a design choice for the cap, the dirty flag and the label, more than a direct correction (Auto Run Result).
  - `[medium]` `[reject]` A failed insert has no Status cell, though the matrix's Instance refusal and Insert grant rows name one — same root as the failed-insert row above: AC5's "(an insert removed …)" settles inserts.
  - `[low]` `[reject]` The matrix reads SQLCODE -120 for a duplicate insert; the tests pin -119 — the instance reads -119 "uniqueness check upon INSERT" and -120 "upon UPDATE" (`$SYSTEM.SQL.Functions.SQLCODE` on `ocupilot-a2-ci`); the code carries the instance's code, and the matrix row is the lead's to amend.
  - `[false]` `[reject]` Most matrix rows are tested at the port, not on the route — the route reaches the same `SqlPort.Invoke("SqlData","RUN")` through `Operation.Apply`, `SqlDataSaveRoutes` pins the route's gates and a mixed save, and the Tasks assign the split.
  - `[false]` `[reject]` The Bound test cannot prove the stopped row's rollback — `SqlPortLive` pins `Executed` undoing a DML statement stopped at the bound, and the save's observable, the row unchanged, holds.
  - `[false]` `[reject]` Cut cells are blocked only in the grid — a cut text value carries its truncation, so the `%EXACT` guard on it matches no row and nothing is written.
  - `[low]` `[reject]` Empty new rows are counted but never sent — same root as the empty-row row above.
  - `[false]` `[reject]` The key fallback could key a table whose primary key is hidden by a visible identity column — an identity column is unique, so no row is mis-targeted, and the resolution is `BrowsePlan`'s, reused as the intent requires.
  - `[false]` `[reject]` Additions the intent does not name — each is the spec's: DW-2028 with AC13, AC11's leave dialog, `cuts` and `IS_GENERATED` (Tasks), the EXPERIENCE.md edits and the two budgets (approved by=merge_gate); the snippet renders a script no proposal shows.

## Design Notes

**Intent gap: split (approved by=merge_gate 2026-10-04; epics.md carries Story 19.16).** The story is three criteria wide. Criteria 1 and 2 alone are larger than Story 19.7: a write tool, two port entry points, editors, staging with key reconciliation, rollback, a confirm path and the unsaved-work handling. Criterion 3 needs:

- two new dialogs in the closed set (shortcut help, go-to-row);
- a tab model that holds per-table state, staged changes included, with a dirty prompt on close;
- an export.

**Recommended:**

- **19.8 (this spec):** criteria 1 and 2, the announcements editing needs, and DW-2028.
  - epics.md, 19.8's first criterion, Then: "it works, with an optimistic update rolled back on failure, and its ARIA announcements match the rest of the portal".
  - The third criterion is marked `[SPLIT to 19.16 2026-10-04]`.
- **19.16 (new, `N.<M+1>`):** `19-16-the-data-browser-export-shortcuts-go-to-row-and-tabs`, with criterion 3 verbatim. Its plan settles:
  - CSV of the page as shown (at most 500 rows, cells as displayed, cut cells cut, staged values marked or excluded), through `core/csv.ts` (BOM, CRLF, the formula prefix), never reading beyond the visible page, so AD-36's bound holds with no new read (recommendation);
  - shortcuts for the row actions, Save, export, go-to-row and tabs, avoiding browser-reserved chords (Ctrl+N, Ctrl+Shift+N), with their help dialog;
  - go-to-row by absolute row number, computing the offset (the harvest's is page-relative);
  - tabs whose per-tab staged changes survive a switch and are asked about on close.

**Product decisions, settled from the spine (for the gate):**

- **Only a person's Save writes rows.** AD-3 classifies no column of an arbitrary table, AD-36 keeps rows screen-only, and a proposal would store row values in its arguments, its diff and the ledger. So the tool is AD-53's unadvertised case and mints nothing. Whether the agent ever proposes a row change is Story 19.11's, beside whether rows reach the model.
- **Identity and lock.** The target is `(class, <ns>, sql)`, the console's (AD-13). A row's key travels as a bound value, never as an id segment, so AD-13's composite rule has no subject. A grid save and a console run in one namespace serialize under AD-34's hold (10 s), and `EntityType`/`EntityRef` are untouched.
- **Fingerprint and diff.** These are the action-style write's (AD-51):
  - the fresh read is a port-composed `PLAN` (the empty plan on a screen action);
  - the subject is projected from the payload and is never stored, because a screen action mints no proposal;
  - the per-row guard in each UPDATE is what stands for "state moved under the review";
  - the read-back says `action` (AD-58), and the page re-reads its rows itself (AD-14).
- **Self-protection** is `Prohibited.SqlRun`, reached through `WRITETYPE` `RUN` on a `class` target. It needs no edit to the contended `Prohibited.cls`.
  - The payload's `statement` is the table's delimited name. The text rule (a) refuses an `OcuPilot` name before any statement. It over-refuses a user table whose name contains `ocupilot`, as the console does.
  - The plan's tables then meet rule (b), a view's base tables included.
- **Snippet (AD-59)** renders statements with placeholders and never a value. It exists for `DraftRegistry`, since no proposal is ever drafted.
- **Audit.** No vendor event records a save with the stock event set: every `%System/%SQL/*` event read `Enabled` No on `ocupilot-a2-ci`, 2026-10-04. So this is AD-53's named gap, the sixteenth on this branch (renumbered against Epic 18's at merge).
- **Rows one by one, no batch transaction.** The criterion asks for each row's rollback and "every save answers its outcome per row". A batch transaction would turn one stale row into a refusal of every row. Each statement is atomic.
- **Read-only:** views, keyless tables, keys, identity and generated columns, streams, binaries and cut cells. Editing a key would move the row out from under its own reconciliation.
- **Baseline key.** `explorer.sqldata.save` ships `false`, as 19.3's and 19.6's unadvertised keys do; a person's own Save is never asked governance (AD-22). AD-22 gives the owner the call after 2026-10-04, so the lead confirms with the owner before the implement commit lands (`pending`).

**Measured on `ocupilot-a2-ci`, 2026-10-04.** Probe class `OcuProbe198.Probe`, tables `OcuProbe198.Edit` and `.Comp`, and principal `OcuProbe198U` (role `%Development:U`, `%DB_USER:RW`, `%DB_HSCUSTOM:R`) were created, removed and checked gone. Statement-index rows remain.

- **Grants.** Each statement was prepared with `%Prepare(text, 1)` in ODBC mode.
  - SELECT only: every UPDATE, INSERT and DELETE answered -99.
  - SELECT + UPDATE: guarded UPDATEs saved with rowCount 1.
  - UPDATE without SELECT: -99, even `SET … WHERE "Code" = ?`.
  - SELECT + `UPDATE(Name)`: a Name UPDATE ran; one setting Num, or Name and Num together, answered -99.
  - SELECT + INSERT + DELETE: both ran; a DELETE of a missing key gave SQLCODE 100 and rowCount 0.
  - SELECT + `INSERT(Code,Name)`: that INSERT ran; one adding Num, and any DELETE, answered -99.
- **Held open:** with `%All` holding the guarded UPDATE and the DELETE prepared, the principal was still answered -99 for each.
- **Guard:**
  - Originals read in ODBC form compared equal: NUMERIC `1.5`, DOUBLE `.10000000000000000556`, DATE, TIMESTAMP, TIME, BIT, POSIXTIME `… 12:34:56.123456` and `%EXACT` text.
  - An empty string bound as `$Char(0)` and NULL bound as `""`.
  - After `abc` → `ABC`, a plain `=` guard matched and wrote (a lost update), while `%EXACT` matched nothing.
  - A guard on a value another session had changed matched nothing (SQLCODE 100).
- **Refusals:** a NUMERIC past its precision answered -105, `2026-02-31` -146, a 61-character value in VARCHAR(50) -105, and a duplicate key on INSERT -119 (the instance's -120 is the same check upon UPDATE). The messages quote the values, so they stay screen-only.
- **Types and catalog:** statement types are INSERT 2, UPDATE 3 and DELETE 4. `COLUMNS` reads `IS_GENERATED` YES for a computed and a ROWVERSION column and `IS_IDENTITY` YES for an identity column. `IS_UPDATABLE` reads YES for every column and decides nothing.
- **Cost:** 100 guarded UPDATEs, each prepared and run, took 0.014 to 0.017 s.

**Task 0, measured on `ocupilot-a2-ci`, 2026-10-04.** Probe class `OcuProbe198.Plain` and table `OcuProbe198.Slow` were created, removed and checked gone.

- (a) A `%Persistent` class with no declared key: `COLUMNS` lists `ID` (BIGINT, not nullable, `IS_IDENTITY` YES, `IS_GENERATED` NO), and the key query answers `ID` (`RowIDField_As_PKey`). `UPDATE … SET "Name" = ? WHERE "ID" = ? AND %EXACT("Name") = ?` prepared with `%Prepare(text, 1)` as statement type 3 and saved with rowCount 1. Run again with the old guard, it answered SQLCODE 100 and rowCount 0. So such a table is keyed by `ID` and saves, and `ID` is never a value.
- (b) A `BEFORE UPDATE` trigger that runs `HANG 1`, four UPDATEs under one 2 s budget, as the save loop runs them: row 1 saved in 1.0 s. Row 2 ran on the 1 s left and answered SQLCODE -415 with `$ZE` `<ALARM>` at `$TLEVEL` 0, so it is `stopped`. Rows 3 and 4 were `skipped`, and row 2 read its old value afterwards.

**Harvest** (iris-table-editor; MIT notice already shipped by 19.7):

- **Lifted:**
  - the edit entry keys and the editor's commit/cancel keys;
  - edit-mode undo, which restores the value captured at entry;
  - the boolean toggle;
  - duplicate, with key columns emptied;
  - the four parsers, with their defects fixed: no `Number()`, no comma stripping, no `new Date()` fallback, impossible dates refused, fractions kept.
- **Re-expressed:** staging and reconciliation. The harvest saves each cell at once and reconciles a reply by row index unless the index is out of range (`grid.js:1950`). Here every change is keyed by the row's key and every outcome is applied by key.
- **Not carried:**
  - `rowsAffected: 1` (`QueryExecutor.ts:203`);
  - Delete writing `''`;
  - editing of identity and computed columns;
  - the calendar picker and the toasts;
  - Ctrl+Shift+N, which the browser reserves (Delete stages NULL instead);
  - the plaintext-password session.

**Wire.** `changes` is JSON array text. Each member is one of:

- `{op: "update", key: {<k>: v}, original: {<c>: v|null}, values: {<c>: v|null}}`
- `{op: "insert", values: {<c>: v|null}}`
- `{op: "delete", key: {<k>: v}}`

Values are strings in the form the page read them, or `null`. The answer, which reaches the screen only, is `output`: `{outcome: "saved", results: [{index, outcome, rowCount?, sqlcode?, message?, seconds?}], saved, failed}`.

**Strings.** About 40 literals, one Fixed-strings row after :598:

- Labels: "Add row", "Duplicate row", "Delete row", "Restore row", "Save changes (<n>)", "Discard changes", "New", "Changed", "Deleted", "Saved", "Change".
- Dialog: "Save changes to <table>?" and "<u> rows change, <i> are added and <d> are deleted in <table>, and this cannot be undone from OcuPilot."
- Lines:
  - "Editing <column>." and "<n> changes waiting to be saved."
  - "Change undone." and "<n> changes discarded."
  - "Saved <a> of <n> changes; <b> rolled back."
  - "Rows here are read-only: a view, or a table without a key this account can see, is not changed here."
  - "A save carries at most 100 rows; save or discard some first."
  - "Changes were discarded because the namespace changed."
  - "This column cannot be NULL." and "This cell cannot be edited here."
  - The outcomes: "Not saved: the row changed or was removed after it was read.", "Not saved: this account may not make this change.", "Already removed." and "Not run: the save stopped first."
  - The hints: "Enter a whole number.", "Enter a number.", "Enter a date such as 2026-10-04.", "Enter a time such as 14:30:00." and "Enter a date and time such as 2026-10-04 14:30:00."
- Reasons:
  - CHANGES: "Name each row's key, and change only listed columns that are not keys, identities, computed, streams or binary."
  - READONLY: "This is a view, or a table without a key this account can see, so its rows are not changed here."
- Reused: `explorerSqlCode`, `explorerSqlStopped`, `tableStatusYes`/`No`, `formLeaveWithoutSaving`, and the null word.
- **Budget:** 2,444 + about 40 against 2,500, while Epic 18's 18.21 rows share the headroom at merge. Raising the bound to 2,600 is recommended; it is a contended edit, so the lead decides.

**Spine amendments (draft, for the lead's gate):**

- **AD-61**, after Story 19.7's case:

  > **Story 19.8's case, the data browser's save** [AMENDED 2026-10-04, Story 19.8 spec gate, Rule 20]. `SqlPort.Save` (declared by `explorer.sqldata.save`, AD-52) resolves the table as `BrowsePlan` does and composes one statement per staged row: an UPDATE targeted by the row's key and guarded by the value read for each column it changes (`%EXACT` for text, `IS NULL` for a NULL), an INSERT, or a DELETE by key. Each is prepared with `%Prepare(text, 1)` as the signed-in user with every value bound, and runs on its own under one alarm budget of `BoundSeconds`. Each row's outcome comes from the instance's own row count. A view, a table without a key the caller can list, and a key, identity, generated, stream or binary column are never written. Measured on `ocupilot-a2-ci`: table and column UPDATE, table and column INSERT, and DELETE grants each admitted exactly their statements, and -99 refused the rest; UPDATE without SELECT was refused; a text another account held open still answered -99; a guard whose value had changed since the read, case only included, changed no row.

- **AD-21:** "The data browser's save is composed by the port too (Story 19.8): identifiers from the caller's catalog rows; keys, new values and the values read bound."
- **AD-36:** "A data browser save's per-row outcomes are a screen-only payload too (Story 19.8); a save carries at most 100 rows and 1,000,000 characters."
- **AD-39**, the sixth exception: append "and a data browser save's per-row SQLCODE and message (Story 19.8)".
- **AD-7**, the fifth shape: "each distinct composed data-browser statement (Stories 19.7 and 19.8)".
- **AD-10**, the SQL arm: "A data browser save is judged by the same rules: its table's delimited name before any statement, then its resolved table, or a view's base tables, before any write (Story 19.8)."
- **AD-53:**
  - The unadvertised named case's fourth: `explorer.sqldata.save`. Only a person's Save writes rows, because a row's values never reach the model (AD-36). Its key ships disabled, and Story 19.11 decides whether the agent ever proposes a row change.
  - Named gap sixteen: Data browser's Save (no vendor event with the stock event set, measured).
- **AD-51:** "Story 19.8's case: `SqlPort` builds the save's statements from the tool's declared screen values and answers its fresh read through a port-composed `PLAN` type."
- **AD-13:** "Story 19.8: the data browser's save targets the literal `sql` under `class`, as the console's; a row's key is a bound value, never an id."
- **AD-8:** "Story 19.8: the data browser's save declares no pair beyond its screen's; its SQL privileges are the instance's at prepare (measured)."
- **AD-44:** "Story 19.8: the save declares no `CLASSICPAGES`; the classic Open Table pages change no row (inference)."
- **Deferred:** CSV export, the shortcut help, go-to-row and multi-table tabs, to Story 19.16, if the split is approved.

**Integration ACs:** AC14.

**Consumes:**

- Story 19.7's grid, store, `columns`/`key` shapes and `BrowsePlan`;
- `SqlPort.Gate`/`Executed`/`BoundSeconds` (19.6) and `Prohibited.SqlRun`;
- `Api.ScreenAction`, `ScreenActionHandler.sendFor`, `warning-dialog` and `FormDirty`;
- SQL query (19.6) for AC14.

**Consumed-by:**

- Story 19.16: the staged state per tab, export of the shown page, and the shortcuts for these actions.
- Story 19.11: whether the agent may propose a row change, using this tool and its guard.

**ADs:** AD-3, AD-5, AD-6, AD-7, AD-8, AD-9, AD-10, AD-11, AD-12, AD-13, AD-14, AD-15, AD-16, AD-19, AD-21, AD-22, AD-24, AD-29, AD-34, AD-36, AD-39, AD-44, AD-47, AD-51, AD-52, AD-53, AD-55, AD-56, AD-58, AD-59, AD-60, AD-61.

**Footprint (Rule 11).** Checked 2026-10-04 against `.worktrees/epic-18` at `b8c6c71af31d21e4c019e12fbbd2cf6220ba064e`, committed and `status -s` (18.21 in progress).

- **Contended, add-only:**
  - `Kernel/Governance/Baseline.cls`, and `Test/GovernanceBaseline`, `Governance`, `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage` and `Prohibited` (one `$Case` arm), all under union-at-merge;
  - `strings.ts` (end) and `_components.scss` (end);
  - `self-protection.test.mjs`;
  - EXPERIENCE.md's new row and paragraphs;
  - `screens.generated.ts` (regenerated).
- **Contended, not add-only (lead approval):**
  - EXPERIENCE.md :159 and :173 (union by hand);
  - `ui/angular.json` with `angular-json.test.mjs`;
  - `strings.test.mjs`'s bound;
  - the spine.
- **Not edited, though contended:** `Prohibited.cls`, `EntityType.cls`, `EntityRef.cls`, `Router.cls`, `screen-actions.ts`, `screen-action-handler.ts`, `screen-outlet.ts`.
- **Not contended:**
  - `Port/SqlPort.cls` (four in-place edits named in Tasks), `Api/AtelierError.cls` and `Screen/Descriptor/ExplorerSqlData.cls` (`rowActions` in place);
  - `Test/ExplorerDescriptor`, `DeveloperFloor`, `ToolEmit` and `DraftRegistry`;
  - the data browser's client files and specs, `data-browser-model.test.mjs`, and every new file;
  - epics.md's Story 19.8 block.
- `scripts/ci-throwaway.sh`: no edit; the fixture reuses `SqlConsoleProbe.Armed()`.

**Ledger inbox:** DW-2028 is planned as a task, pinned by AC13 (grid spec plus browser leg). No read tool is added, so there is no DW-1001 occurrence.

## Verification

Load source into `ocupilot-a2-ci` and never restart it: `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)` in `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`. Run one test-runner call at a time, wait for each, and never re-submit after a client-side timeout. Remove every `OcuProbe198*` object and principal after the run. Never touch `ocupilot-ci` or `ocupilot`.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call, expected green, for:
  - `SqlSave`, `SqlSaveLive`, `SqlDataSaveRoutes`;
  - `SqlBrowse`, `SqlBrowseLive`, `SqlDataRoutes`, `SqlPort`, `SqlPortLive`;
  - `ExplorerDescriptor`, `DeveloperFloor`, `GovernanceBaseline`, `Governance`, `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `ToolEmit`, `Prohibited`, `DraftRegistry`.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts'` (loop): expected green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for:
  - `system-explorer-data-browser-edit.browser-spec.mjs`;
  - `system-explorer-data-browser.browser-spec.mjs`;
  - `a11y-structural-invariants.browser-spec.mjs`.
  - Expected green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete): expected green apart from the known residue (`MappingCodeGlobals`, `WireSecurityRead` DW-1554, and the classes this throwaway is not armed for).

**Planned mutations (Rule 19)**, one per AC:

- AC1: `parseCellInput` passes an integer through `Number()` → `data-browser-model.test.mjs`, the 2^53+1 case.
- AC2: the editor's Ctrl+Z restores the empty string → `data-browser-grid.spec.ts`, the undo case.
- AC3: `duplicate` copies key columns → the model's duplicate case.
- AC4: `Save` answers `saved` whenever SQLCODE ≥ 0 → `SqlSaveLive`, the concurrent-change leg.
- AC5: `applyResults` keeps failed rows staged → `data-browser.page.spec.ts`, the mixed-answer case.
- AC6: `applyResults` applies by result index into the current page → the model's "after the page moved" case.
- AC7: `Executed`'s `%Prepare(pText, 1)` becomes 0 → `SqlSaveLive`'s read-only principal leg and its held-open leg.
- AC8: `SaveComposed` uses `=` for text → `SqlSaveLive`, the case-only leg.
- AC9: `ScreenActionDelta` leaves `statement` empty → `SqlDataSaveRoutes`, the unknown-`OcuPilot`-table leg answers 404, not 403.
- AC10: `Save` passes bound 0 → `SqlSaveLive`'s stopped/skipped leg. `Save` calls `Fail` with a row's message → its logs-nothing leg.
- AC11: the store's `forget` keeps the staged changes → the page spec's namespace case.
- AC12: the editor keeps focus after commit → the grid spec's focus case.
- AC13: the grid drops its tooltip → the browser spec's tooltip leg and the grid spec's pointer case.
- AC14: `Save` answers `saved` without running → the browser spec's AC14 leg.

**Mutations run (Rule 19)**, each reverted and the tree checked byte-identical; server ones recompiled on `ocupilot-a2-ci`, the client tooltip one rebuilt and copied in:

- mutation: AC1, `parseCellInput` passes a whole number through `Number()` -> `data-browser-model.test.mjs` "a number is staged exactly as typed" red.
- mutation: AC2, the editor's Ctrl/Cmd+Z restores `''` -> `data-browser-grid.spec.ts` "in the editor Ctrl/Cmd+Z restores the value it opened with" red.
- mutation: AC3, `duplicate` copies key columns -> the model's duplicate case red.
- mutation: AC4, `SaveOutcome` answers `saved` whenever SQLCODE >= 0 -> `SqlSaveLive.TestAnUpdateSavesAndAChangedValueIsNot`, `TestAnInsertAndADeleteTwice` and `TestNullIsGuardedAndStoredBesideEmpty` red (run 5452), and the edit browser spec's AC1/AC4/AC5/AC12 leg red; `saved` at row count 0 -> `SqlSave.TestTheOutcomeIsTheInstances` red (run 5462).
- mutation: AC5, `applyResults` drops only saved rows from staging -> `data-browser.page.spec.ts` mixed-answer case red.
- mutation: AC6, `overlay` takes staged values by place on the page -> the model's "a staged value shows on the row with the same key" red; `overlay` takes outcomes by place -> "its answer applies by key after the page moved" red.
- mutation: AC7, `Executed`'s `%Prepare(pText, 1)` becomes 0 -> `SqlSaveLive.TestAHeldTextIsStillRefused` and `TestEachGrantDecidesItsRows` red (run 5454).
- mutation: AC8, `SaveComposed` guards text with `=` -> `SqlSaveLive.TestAnUpdateSavesAndAChangedValueIsNot` red (run 5453), `SqlSave.TestSaveComposedTheThreeStatements` and `TestTheScriptRendersNoValue` red (run 5461).
- mutation: AC9, `ScreenActionDelta` leaves `statement` out -> `SqlDataSaveRoutes.TestOcuPilotsOwnTablesAreRefused`'s unknown-table leg red (run 5457); `ScreenActionDelta` ignores `SaveChanges`' refusal -> `TestThePairsComeBeforeTheValuesAndTheValuesBeforeTheSet` red (run 5464); `Save` drops the key check -> `SqlSaveLive.TestATableThatCannotBeWrittenIsRefused` red (run 5463); `Insertable` admits a generated column -> `SqlSave.TestChangeProblemHoldsTheColumnRules` and `TestEditableAndInsertable` red (run 5459).
- mutation: AC10, `Save` passes bound 0 -> `SqlSaveLive.TestTheBudgetStopsARowAndSkipsTheRest` red (run 5455); `SaveOutcome` calls `Fail` with a row's message -> `TestAFailedSaveLogsNothingOfTheRequest` red (run 5456); `SaveChanges` accepts 101 changes -> `SqlSave.TestSaveChangesRefusesEachShape` red (run 5458); `ADVERTISED` 1 -> `SqlSave.TestTheToolDeclaresItsWritePath` red (run 5460).
- mutation: AC11, the store's `forget` drops nothing -> the page spec's "a namespace switch discards what is staged and says so" red.
- mutation: AC12, `commit` leaves focus in the editor -> the grid spec's editor case red.
- mutation: AC13, `tooltipShown` answers false -> the grid spec's tooltip case and the edit browser spec's AC13 leg red.
- mutation: AC14, `Save` answers `saved` without running -> the edit browser spec's AC14 (and AC1) leg red.
- mutation: AC1, AC3 (the wire), `frameOf` drops `generated` -> page spec "a generated, an identity or a cut cell opens no editor" red; `answerOf` drops `cuts` -> the same case red.
- mutation: AC3, `afterStaging` ignores a refused staging -> page spec "the 101st staged row is refused with its sentence" red.
- mutation: AC5, AC10, `applyResults` removes a sent insert only when it saved -> page spec "a failed insert is removed" red; `outcomeText` drops an error's message -> the same case red.
- mutation: AC9 (client), `writable` drops its key check -> page spec's view and keyless case red.
- mutation: AC13, `cutText` answers every cell's text -> the edit browser spec's AC13 leg red at the uncut cell; both scroll hides dropped -> the same leg red at the scroll (each rebuilt and copied in).
- mutation: `discard` leaves `savingValue` set -> page spec "leaving the page while a save is on its way" red.

## Auto Run Result

Status: done
Blocking condition: none

**Plan pass.** Read the spine, the epic context, specs 19.6 and 19.7, the harvest (through a subagent) and the server and client code. Probed `ocupilot-a2-ci` (Design Notes › Measured), then removed the probe class, tables and principal and checked them gone. The tree held only the lead's write-ahead lines for this spawn (`cycle-log-epic-19.md`, `sprint-status.yaml`). This pass wrote nothing else and committed nothing.

**Implement pass.** Data browser edits a table's rows: type-specific editors with edit-mode undo, Add, Duplicate and Delete row, staging keyed by each row's key across paging, sort, filter and refresh, one confirmed Save through the unadvertised `explorer.sqldata.save`, one guarded statement per row composed by `SqlPort.Save` and prepared as the signed-in user, each outcome from the instance's row count, failed rows rolled back on screen, the leave and namespace-discard handling, and DW-2028's cut-cell tooltip.

- Files:
  - `src/OcuPilot/Port/SqlPort.cls`: the save's endpoint, plan, shape and column rules, composition and outcomes; `IS_GENERATED`, `identity`/`generated` columns and `cuts` on the page answer.
  - `src/OcuPilot/Screen/Tool/ExplorerSqlDataSave.cls` (new): the unadvertised action-style write.
  - `ExplorerSqlData.cls` (the `save` row action), `AtelierError.cls` (two codes), `Baseline.cls` (key `false`), `screens.generated.ts`.
  - Tests (new): `SqlSave`, `SqlSaveProbe`, `SqlSaveLive`, `SqlDataSaveRoutes`; rosters: `ExplorerDescriptor`, `DeveloperFloor`, `Governance`, `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `ToolEmit`, `Prohibited`, `ToolWrite`, and `SqlBrowseLive`/`SqlDataRoutes` for the new answer fields.
  - Client: `data-browser-model.ts` (parsers, `StagedChanges`), the store, grid and page, `core/tooltip-timing.ts` (new: an area screen arms no timer, refresh.test.mjs's AD-43 scan), strings and styles at their ends, and the specs and `system-explorer-data-browser-edit.browser-spec.mjs` (new).
  - EXPERIENCE.md (:159, :173, the Fixed-strings row, the editing paragraphs), `strings.test.mjs` (2,600), `angular.json` with `angular-json.test.mjs` (2812kB, measured 2,811,686 bytes).
- Review: verification-gap and intent-alignment (no other layer is configured); 19 findings, 7 patched (6 medium test gaps, 1 low `discard` fix), 12 rejected with their reasons in the triage log, 0 deferred. The full sweep then reddened `ToolWrite`'s count of writes behind another port, now thirteen (run 5941 green).
- Verification on `ocupilot-a2-ci`: `check-objectscript` 0 problems and its harness 146 OK; the 18 targeted classes green one at a time (runs 5468-5485); `npm run test:tools` 1803 pass; `npm test` 1803 and 2373 pass; `lint-docs` 0 issues; the edit, data-browser and a11y structural browser specs 3/3, 2/2 and 12/12 on the rebuilt bundle. Full sweep, 453 classes and 3,667 tests: red only for the classes this throwaway is not armed for (`EcpDataServerStatus`, `EcpDataServerWrite`, `EcpWriteGate`, `Journal*` four, `License*` two, `PathPortInstance`), `MappingCodeGlobals` and `WireSecurityRead` (DW-1554), `Retention` (its one-day probe definition finds entries other suites wrote on this two-day-old throwaway before this story ran, oldest 2026-10-03T18:12Z; red again alone, run 5939) and `ToolWrite` (fixed above). Probe objects, principals and the page resource checked gone.
- For the lead:
  - The matrix's Instance refusal row reads -120; the instance answers -119 for a duplicate INSERT and -120 upon UPDATE. Design Notes › Measured is corrected; the intent row is yours to amend.
  - AC5 removes a failed insert, so its SQLCODE and message reach only the summary count; keeping the row with its reason would amend AC5.
  - An untouched new row counts in Save changes (<n>) and the dialog but is never sent (low).
  - The baseline key's `false` stands under AD-22's dating only if 19.8 merges on 2026-10-04 PDT.
- Follow-up review recommended: true (6 medium patched, 0 high). The unverified risk: the six tests this review added were mutation-checked but not reviewed by an independent layer, and AC13's scroll leg dispatches a synthetic `scroll` event.
