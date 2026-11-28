---
title: 'Story 21.29: Troubleshooting reports'
type: 'feature'
created: '2026-11-25'
status: 'done'
baseline_revision: '9cb4fe007aa5767c1ad8de61c100a5ee06b561fa'
baseline_commit: '9cb4fe007aa5767c1ad8de61c100a5ee06b561fa'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-27-the-index-analyzer-and-its-advice.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-26-runtime-statistics.md'
warnings: ['oversized']
deferred:
  - summary: 'SqlPort repeats ResourceTransferPort''s file-transfer shape (server-or-local text, resolve, temp file), a fifth copy beside LocalePort, InteropPort and AnalyticsPort'
    evidence: 'ResourceTransferPort.ImportText/Export are Private and bound to ResourceFileError codes; unifying them is outside this story''s footprint'
    location: 'src/OcuPilot/Port/SqlPort.cls, src/OcuPilot/Port/ResourceTransferPort.cls'
    severity: low
  - summary: 'The list''s Status fallback branch (a row with an empty plan shows the instance''s own status text) has no test, since Save refuses non-queries and only a row saved outside this story has an empty plan'
    evidence: 'Atelier catalog CATALOGSQLREPORTSQUERY CASE WHEN QueryPlan IS NULL; SqlReportRead and SqlReportWrite assert only Planned. A test needs a row saved through the vendor''s InsertQuery with an INSERT (Task 0 (c): empty plan stream).'
    location: 'src/OcuPilot/Port/AtelierPort.cls, src/OcuPilot/Test/SqlReportRead.cls'
    severity: low
---

<intent-contract>

## Intent

**Problem:** The classic Generate Report and Import Report pages are the only place to save a slow query for an InterSystems support case, write the case's troubleshooting report file, and load a report into a namespace. OcuPilot offers none of them.

**Approach:** A System Explorer list, SQL troubleshooting reports, over the namespace's saved queries, with four writes through `SqlPort`, each reached by the screen and by a confirmed agent proposal (AD-53): Save query (`InsertQuery`), Delete (`ClearRow`), Generate report (`WriteAllToFile`, to a server file named by root and relative name or to this browser) and Import report (`ConsumeReport`). Import and the classic page's mail link are owner-gated and planned as their own batches, so either can be parked alone.

## Boundaries & Constraints

**Always:**

- The statement reaches the vendor whole, as a value, after the console's order: the screen gate, the body's bounds, then `SqlConsole.Check` (checked prepare plus `PROHIBITED.OCUPILOTSQL`). Saving runs the statement, so it takes a query only, refused before any vendor call. The case number is a whole number the port validates. No caller text reaches SQL text, code or a path (AD-21).
- Files follow AD-21's sixth case as Stories 21.15 and 21.19 do. Generate writes to a temporary file OcuPilot names, then copies it to a `PathPort`-resolved overwriting `file` (overwrite a constant) or answers it to the screen. Import reads a `PathPort` `source` or the screen's local text, and the vendor gets only a temporary file OcuPilot writes from the reviewed text and deletes on every path.
- Every write runs in its confirm or action request (AD-7). If Task 0 (b) measures a worst case that, times 1.5, reaches the 60 s gateway limit, the implement stage stops and reports, because Story 24.16's background-run form is then the orchestrator's call. Writes run under the null device helper Story 21.27 hoists into `Kernel/Utils`, in the request's namespace (AD-16), and each reads its target back (AD-58).
- Tests remove every saved row, file, probe class, probe table and cached query they cause, and read each back absent.

**Never:**

- No `slowquery` step (21.29 adds no workflow read). No `job` and no classic `JobSaveQuery`, no Plan Format choice, no "include results" option (the vendor ignores it), no plan Details pane.
- No clear-by-case-number or clear-all (`ClearData`): Delete removes one row by id.
- Nothing sent from the server to a mail system. The mail link (Batch 3) and Import (Batch 4) are built only on the owner's word (Design Notes, "Owner-gated").
- No edit to `Api/Error.cls`. The spine stays add-only. No test or write on `ocupilot` or a slot instance. No probe schema whose name holds `"` (DW-2851).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | A probe query saved for case 2291 | The list and `explorer.sqlreports.read` answer the same rows: ID, case number, saved at, status, delimited identifiers, schema, masked statement. Rows are the ones the vendor's row-level security shows the caller (Task 0 (e)) | Truncation reported (AD-36) |
| Save | Either caller, a query over the probe table, case 2291 | One new row for 2291 in the vendor's `SavedQueries` and the list, status planned | Past `SqlPort.BoundSeconds`: `stopped`, and no row left (Task 0 (c)) |
| Save, not a query | An `UPDATE` | 422 ruled sentence, nothing called (the seam counts calls) | none |
| Save, own tables | A query over `OcuPilot_Kernel_State.Turn` | Refused by `Check` (`PROHIBITED.OCUPILOTSQL`) before any vendor call | none |
| Bad case number | Empty, non-digits, `0`, over 9 digits | 400 ruled sentence from both callers, nothing called | none |
| Delete | A listed row | The row is gone from `SavedQueries`. Other rows stay | Gone after the mint: confirm refuses `PROPOSAL.TARGETCHANGED` |
| Generate, server file | Case 2291, an allowed root and relative name | The file holds every row saved for 2291 in the namespace, read back through `%XML.Reader` into the vendor's class without saving | `PATH.ROOT`/`PATH.NAME`/missing directory refused before any call. No row for the case: precondition refusal |
| Generate, this browser | Case 2291, screen only | The report text answered for the browser to save as `WRC2291.xml` | Over `MAXIMPORTCHARACTERS`: server file only, ruled sentence |
| Mail (gated B) | A generated report | Per the owner's ruling. Never a server send | none |
| Import (gated A) | A file Generate wrote for the probe, the probe class removed | The review lists the file's case numbers, statements, classes and routines. After confirm the probe class reads back compiled | Changed after review: 409 ruled sentence. An `OcuPilot` document: `PROHIBITED.OCUPILOTCODE` before any vendor call. Not a report: 409 shape sentence |
| Gate | Missing a pair the Design Notes name, or a custom resource on the classic page | 403 naming the pair before any read or call | none |
| Vendor refusal | The seam answers an error status | 409 with the message in `detail` only (AD-39) | none |

</intent-contract>

## Code Map

- **Classic and vendor sources (read-only), confirmed on `ocupilot` via `ocupilot-slot-a`:**
  - `irislib/%SQL/Manager/QButtons/Base.cls`:
    - `%Persistent`, `ROWLEVELSECURITY` 1, `%SecurityPolicy` :60 (the inserting user, `%All`, `%Developer`). Storage `^IRIS.QButtons.BaseD` :314.
    - `FetchPlan` :71 runs `ShowPlan^%apiSQL` with stats under its own null device. `BuildClassList` :147 and `FetchClassDef` :129 export every class the statement references.
    - `InsertQuery(query, wrcnum, includeresults, debug, planFormat)` :172, `ClearRow(id)` :204, `WriteAllToFile(wrcnum, .filename)` :225, `ConsumeReport(filename, qspec, loadcode, NameSpace)` :232 and query `SavedQueries` :323.
    - Each public method delegates to the `%SYS.PTools` routine, whose source is not on the instance (doc list in `%SYS` and `HSCUSTOM` shows only its `.inc` files). So Task 0 measures its behavior.
  - `irislib/%CSP/UI/Portal/SQL/QButtons/ReportGenerator.cls`: `RESOURCE` `%Development` :20, `SaveClick` :455 (`InsertQuery`), `ClearClick` :424, the case-number check :412 (digits only), and the background `JobSaveQuery` :543, which is not used.
  - `irislib/%CSP/UI/Portal/Dialog/SQLReportGenerator.cls`: `%Development:USE` :16. The default name `WRC<n>.xml` in `TempDir` :147, overwrite confirm :180, `WriteToFile` :199, and the client `mailto:support@intersystems.com` :191.
  - `irislib/%CSP/UI/Portal/SQL/QButtons/ReportLoader.cls` (`%Development` :20) and `ReportLoaderOutput.cls`, which calls `ConsumeReport(filename,"ckd",1,namespace)` on every action. Its `ShowDetails` uses `ReadAllFromFile^%SYS.PTools` and is never called.
- **`src/OcuPilot/Port/SqlPort.cls`:**
  - The sibling endpoint is `RuntimeStats` (`ENDPOINTRUNTIMESTATS`, `STATSCOUNTQUERY`, `COMPOSEDTYPES`), and 21.27's `IndexAnalysis` follows it.
  - `Invoke` :861, `TuningInvoke` :942, `Gate` :2104, `StatementCall` :1157 (the seam `Test/SqlTuningPortFixture.cls` overrides), `Applied` :1191 and `ValueProblem` :1447.
  - The console's pieces: `Classify` :642 (the `GUARD` read), `BoundSeconds` :502, and `Explained` :2436 with its alarm and `stopped` reading.
- **File siblings:**
  - `src/OcuPilot/Port/ResourceTransferPort.cls`: `Locate` :183 (`PathPort.Resolve`, `KINDFILE`/`KINDSOURCE`, `EXPORTOVERWRITES`), `ExportFile` :203, `Export` :243 (deletes its own file on failure), `ImportText` :342 (server or local, `MAXIMPORTCHARACTERS`), `Review`, `TextDigest` :539, `TransferFile` :592 and `WriteTransferFile` :626.
  - `AtelierPort.ReadText` :2375. `Port/PathPort.cls`.
- **Tool siblings:**
  - `Screen/Tool/ExplorerSqlRun.cls` (`READSVALUES`, `GUARD`, statement as a declared value) and `ExplorerSqlRunMint.cls` (the console's checks before a mint).
  - `SqlStatementAction.cls` (with 21.27's hoisted value machinery) and `ExplorerSqlRuntimeStatsPurge.cls` (the `*` page-action template).
  - `ExplorerImport.cls` (destructive, `import`/`import-local` `SCREENVALUES`, reviewed `documents`, `OCUPILOTCODE`, routines-database WRITE as an argument pair) and `ResourceImport.cls`.
- **Catalog:** `Port/AtelierPort.cls` `ENDPOINTCATALOGRUNTIMESTATS` :171 / `CATALOGRUNTIMESTATSQUERY` :257. A list registers in `IsCatalog` :1334, `CatalogStatement` :1354, `CatalogColumns` :1361 and `CatalogRows` :1440. The statement column is kind `sqltext` (cut and masked).
- **Kernel** (Epic 24 has commits on all three: add-only, appended at the end):
  - `Kernel/EntityType.cls` `TYPES`.
  - `Kernel/Proposal/Prohibited.cls` `COVEREDTYPES` :348, the `tType` guard :1816 and `OCUPILOTCODE` :1025 with its 19.13 import clause.
  - `Kernel/Governance/Baseline.cls` :245-262.
- **Errors:** `Api/AtelierError.cls` codes and `REASON*` :404-426, and `SqlReasonFor` :505.
- **Descriptor:** `Screen/Descriptor/ExplorerSqlRuntimeStats.cls` (page action, `paging:"cap"`). Take the next free side-bar position at implement time (21.27 takes 23).
- **Client** (Epic 24 has commits on `screen-action-handler.ts`, `strings.ts`, `screen-outlet.ts`, `screen-actions.ts`, `proposal-view.ts` and EXPERIENCE.md: add-only):
  - `ui/src/app/areas/system-explorer/sql-runtime-stats.page.ts` and its spec (the page template).
  - `explorer-export-dialog.ts` and `explorer-import-dialog.ts` (server file, this browser, a file on this computer).
  - `core/strings.ts` :4670-4690 (`explorerTransferServer`, `explorerTransferBrowser`, `explorerTransferLocal`) and :9105-9150 (locale and resource transfer).
- **Tests to follow:**
  - `Test/SqlTuningProbe.cls`, `SqlRuntimeStatsRead`, `ResourceTransferRead` and `ExplorerTransfer`.
  - `ui/browser/system-explorer-sql-runtime-stats.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:** Task 0 first, then four batches, each committed on its own. A handoff builds one batch. Build after Story 21.27 is on the branch (its null-device helper and value machinery). Batches 3 and 4 wait for the owner's ruling. Strings are only the ruled set (Design Notes, "Strings, escalated"). Any other sentence a person reads is `## Clarification Needed`.

**Dispatch state (written by the stage lead; each handoff does exactly the pass named here, edits no ruled text, commits nothing):** Task 0 is done (measurements under `## Verification`, `### Task 0 measurements`). The two intent gaps are ruled (Spec Change Log, 2026-11-27). Batch 1 is committed (server: list, save, delete, generate; Save runs unbounded in its request and the port deletes any row left after an error status). **Current pass: Batch 2 only** (client; extend the one EXPERIENCE.md row Batch 1 appended for 21.29 rather than adding a second; the descriptor's strings are already in `strings.ts`). Batch 3 is empty and Batch 4 is not built.

**Task 0, measured on `ocupilot-ci` before code, in `USER` and `HSCUSTOM`.** Record each result under Verification. Remove every row, file, class, table and principal you create, and read each back absent.

- (a) **Privilege.** Use a principal holding `%Development:USE`, `SELECT` on the probe table and `AtelierPort.WritePairs(ns)`. Can it save, list, delete, generate and import, recording `<PROTECT>`, a status or a silent no-op? Which database holds `^IRIS.QButtons.BaseD`, `^IRIS.QButtons.BaseS`, and the routines an import compiles (a `%` routine would land in IRISSYS)? A pair the vendor needs beyond these joins the gate. Record the classic pages' custom resources.
- (b) **Durations.** Time Save for the probe and for a five-table join, Generate for 1 and 20 rows, and Import of that report. Compare each worst case times 1.5 with the 60 s gateway limit (the 21.27 ruling). Does `$System.Alarm` stop `InsertQuery`?
- (c) **What Save does.**
  - Does it run the statement? Does it run DML? Does an unbound `?` run as nothing?
  - What does a row hold (plan, class definitions, INT code), and what status does a planned row show?
  - What does a stopped save leave?
  - Does it write to the current device?
  - Its side effects: runtime-statistics rows, statement-index rows, cached queries.
- (d) **Generate.** Does `WriteAllToFile` change `filename` (an extension added), write rows of other users, or change any row? Is the file valid XML that `%XML.Reader` correlates to `%SQL.Manager.QButtons.Base`? How large is it?
- (e) **Row-level security.** What does the list show a principal who did not insert the row, with and without `%Developer`? Can `ClearRow` delete a row the caller cannot see?
- (f) **Import.**
  - What does `ConsumeReport` load: classes, routines (by name), a `QButtons` row, globals?
  - Does it replace an existing class of the same name? Does it write to the device?
  - Can the port list the file's documents without loading them (`$System.OBJ.LoadStream` with list-only, or the `ClassDefXml`/`QueryIntCode` streams read through `%XML.Reader`)?
  - What does it do with a file that is not a report?
  - Anything written outside the target namespace stops the stage with a report.
- (g) **Case number.** The vendor's accepted range (`%Integer`) and what a non-number does.

**Batch 1, server: list, save, delete and generate.**

- `src/OcuPilot/Port/AtelierPort.cls` -- add `Catalog.SqlReports`: one fixed statement over `%SQL_Manager_QButtons.Base` (`SavedQueries`' columns) in the target namespace, run as the caller, capped by `maxRows`, and registered in the four places.
- `src/OcuPilot/Port/SqlPort.cls`:
  - Add the endpoint `Reports`, served by `Invoke` and `TuningInvoke`. `COMPOSEDTYPES` gains `Reports/SAVEQUERY`, `/DELETEQUERY` and `/GENERATE`.
  - Fresh reads:
    - `CASE`: `{Namespace, WRCNumber, Saved}` with id `*`, composed from the values (`READSVALUES`), plus the statement's `GUARD` for Save.
    - `SAVEDQUERY`: one row by id; absent answers 404.
  - The writes go through the widened `StatementCall`, under the null device:
    - `SAVEQUERY` refuses a kind other than `query` (`EXPLORER.SQLREPORT.QUERYONLY`) before any call, then runs `InsertQuery(statement, wrc, 0, 0)` under `BoundSeconds`. A stop answers `stopped` and removes any row it left (Task 0 (c)).
    - `DELETEQUERY` runs `ClearRow(id)`.
    - `GENERATE` refuses a case with no row, then writes to a `%File.TempFilename("xml")` file. It copies that file to the resolved `root`/`path` (the `ResourceTransferPort.Locate` shape, overwrite a constant, missing directory refused) or answers the text for the browser (screen only, capped at `MAXIMPORTCHARACTERS`). The temporary file is deleted on every path.
  - `ValueProblem` gains `WRCNumber` (1 to 9 digits, not 0); `root` and `path` are `PathPort`'s to refuse. Vendor errors answer 409 `EXPLORER.SQLREPORT.VENDOR`, and `SnippetForm` covers the writes.
- New tools in `Screen/Tool/`:
  - `ExplorerSqlReportSave.cls` (`explorer.sqlreports.save`): values `Statement`, `WRCNumber`, with the mint running `ExplorerSqlRunMint`'s console checks.
  - `ExplorerSqlReportDelete.cls` (`.delete`): row target, `READTYPE` `SAVEDQUERY`.
  - `ExplorerSqlReportGenerate.cls` (`.generate`): `*` target, values `WRCNumber`, `root`, `path`. Browser output is a screen action only, never in the schema.
  - Each extends `SqlStatementAction` as `ExplorerSqlRuntimeStatsPurge` does and declares `CLASSICPAGES` (`…QButtons.ReportGenerator`, the generate dialog for `.generate`).
- New `Screen/Descriptor/ExplorerSqlReports.cls`: a list at the next free position, route `system-explorer/sql-reports`, namespace scope, and entity `sql-saved-query` with id `ID`. Its source is `{port: "atelier", endpoint: "Catalog.SqlReports", type: "LIST"}`, with `paging:"cap"`, page actions `save` and `generate`, a row action `delete`, classic page `…QButtons.ReportGenerator`, `%Development:USE`, `toolIdentifier` `explorer.sqlreports`, and the ruled note, prompts and aliases.
- `Kernel/EntityType.cls`, `Kernel/Proposal/Prohibited.cls` (add-only, appended at the end of `TYPES`, `COVEREDTYPES` and the `tType` guard): `sql-saved-query`, covered with no predicate.
- `Kernel/Governance/Baseline.cls` (add-only): the keys as ruled (record 5).
- `Api/AtelierError.cls` (add-only): the codes of string 8 and the consequence codes of string 6.
- `Test/SqlTuningProbe.cls`: `MakeReport(ns)` creates `OcuProbe229` with rows and a query over it. `RemoveReport(ns)` removes its saved rows by id, its cached queries, any report file and the table.
- New `Test/SqlReportRead.cls` (live-safe): the declared shape, columns pinned and the statement masked, gates and every value shape on both callers, copy-out snippets, and AD-36 truncation through a seam.
- New `Test/SqlReportWrite.cls`: save, delete and generate on both callers, each read back through the vendor's `SavedQueries` and the list.
  - Generate to a server file and to the screen, parsed back with every saved statement present.
  - The refusals, each calling nothing.
  - A changed target and a vendor refusal through seams.
  - The null device restored after a raised call.
  - It is armed (`OCUPILOT_ALLOW_CONFIG_SETTINGS`, add-only `# classes:` line) only if Task 0 shows a write beyond the test's own rows and files.

**Batch 2, client.**

- New `areas/system-explorer/sql-reports.page.ts` with a spec, in the `sql-runtime-stats.page.ts` shape, plus a `screen-outlet.ts` row:
  - Save query opens a dialog with the case number and the statement.
  - Generate report reuses `explorer-export-dialog.ts`' server-file or this-browser choice and saves `WRC<n>.xml`.
  - Delete is a row action.
- `shell/screen-action-handler.ts`, `core/screen-actions.ts`, `core/proposal-view.ts` and `core/strings.ts` (add-only): the ruled strings. Regenerate the mirror and `Titles.cls` (`node tools/screen-mirror.mjs`).
- `EXPERIENCE.md`: one add-only Fixed strings row for 21.29.
- New `ui/browser/system-explorer-sql-reports.browser-spec.mjs`. It refuses the live container and waits on each answered signal:
  - Save query asks, confirms and lists the probe's row.
  - Generate report to this browser downloads `WRC<n>.xml` holding the statement.
  - Delete empties the probe's rows.

  Its `after` hook calls `RemoveReport`.

**Batch 3 is empty** (B1, Spec Change Log): no mail action; `sql-reports.page.spec.ts` asserts its absence (AC4).

**Batch 4 is not built in this story** (split to Story 21.41, parked U-184; Task 0 (f) measured Import writing outside the target namespace). The items below stay as the record for 21.41's option B and are not worked here.

- `SqlPort`:
  - `Reports/IMPORT` and the fresh read `REPORTFILE`, on the `ResourceTransferPort` model.
  - The text comes from a `source` or local text, and the review lists case numbers, statements, `documents` (classes and routines, Task 0 (f)) and a digest. Nothing is loaded.
  - At the write: the kernel's `OCUPILOTCODE` import clause on `documents`, then the digest check, then `ConsumeReport(<temp file OcuPilot wrote from the reviewed text>, "ckd", 1, <request namespace>)` under the null device, with the temporary file deleted on every path.
  - Each reviewed class is read back compiled.
- New `Screen/Tool/ExplorerSqlReportImport.cls` (`.import`), on `ExplorerImport`'s shape: `DESTRUCTIVE` 1, `import`/`import-local` values, `PRECONDITIONFIELD` `documents`, the routines database's WRITE as an argument pair, and `CLASSICPAGES` `…QButtons.ReportLoader`.
- `Kernel/Proposal/Prohibited.cls` (add-only): route the tool's reviewed `documents` through the existing import clause. No new arm.
- The client import dialog reuses `explorer-import-dialog.ts`.
- New `Test/SqlReportImport.cls`:
  - generate for the probe, delete the probe class, import, and read it back compiled;
  - a report holding an `OcuPilot` document refused before any vendor call;
  - a changed file refused;
  - a file that is not a report refused;
  - the local-text form;
  - everything removed and read back absent.

  It gets one browser-spec leg.

**Acceptance Criteria:**

- AC1. Given the probe's query on the throwaway, when either caller saves it for a support case number and confirms, then the vendor's `SavedQueries`, the list and `explorer.sqlreports.read` answer the same new row. A statement that is not a query, a statement over OcuPilot's tables and a malformed case number are each refused before any vendor call.
- AC2. Given a saved row, when either caller deletes it and confirms, then `SavedQueries` no longer answers it and every other row stays. A row gone after the mint refuses the confirm.
- AC3. Given rows saved for a case number, when either caller generates the report to an allowed server file, or the person to this browser, then the file holds every row of that case in the namespace and parses back into the vendor's class. A refused root or name, a missing directory and a case with no row call nothing.
- AC4. Given a generated report, the page offers no mail action, and the server sends nothing.
- AC5. Moved to Story 21.41 (split 2026-11-27, orchestrator ruling; parked U-184).
- AC6. Given the throwaway, when the browser spec runs forward and in reverse with `system-explorer-sql-runtime-stats.browser-spec.mjs`, then it passes and leaves no saved row, report file, probe table or cached query.

## Spec Change Log

- 2026-11-25, orchestrator rulings at the plan gate (veto U-167), authoritative over the Design Notes records and Tasks where they differ. Neither A nor B is an `owner_only` match (epics.md asks only that the reports round-trip); both are veto.
  - **B, mail: B1.** No mail action; OcuPilot names no vendor address and starts no message to a vendor. AC4 restated (no mail action; the server sends nothing), its leg asserts the absence. Batch 3 is empty; no mail string ships.
  - **A, Import: A2.** A person's action on the screen only: governance key `false`, no agent proposal or agent path. Routines-database write permission required; a report holding an OcuPilot document refused. AC5 restated for the screen alone. **Batch 4 is built only if Task 0 (f) measures every write Import makes inside the target namespace.** If any routine or global lands outside it, IRISSYS included, Batch 4 is not built: the implement stage reports the measurement (`blocked`, intent gap) and Batches 1-2 stand.
  1. **AD-7** (veto U-167): allowed, add-only, written by the runner, conditional on each write's worst case x1.5 under the 60 s gateway limit, otherwise implement stops and reports. Save is query-only, without values, under the console time limit, leaves no row if stopped (measure-first); its consequence says it runs without values.
  2. **AD-51** (veto U-167): allowed, add-only: statement whole as a value; case number a validated whole number of at most 9 digits; OcuPilot-named temp files; Import refused if the file changed after review. A test pins each.
  3. **AD-10:** decided, no new arm; Save takes the console's own-table check; Import refuses OcuPilot's own code.
  4. **AD-21** (veto U-167): allowed, add-only. Generate writes only inside an allowed directory and refuses a missing one; the overwrite is stated in the Generate consequence the person confirms; the vendor receives only temp files.
  5. **Governance:** decided. save `true`, delete `false`, generate `true`, import `false`.
  6. **Gate** (veto U-167): `%Development:USE`; writes add `AtelierPort.WritePairs(ns)`; server-file Generate and Import add `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`; every action honours a custom resource on the classic pages.
  7. **Strings** (veto U-167): accepted without any mail string. The list note on who sees a saved query ships only as measured, with role names read from the instance. The Import consequence is kept verbatim if measured; "without asking" must be true of the vendor call.
  8. The fifth copy of the file-transfer code is ledgered LOW at harvest; the other four are not refactored here.

- 2026-11-27, orchestrator rulings on the Task 0 intent gap (veto U-183; split and park U-184), authoritative:
  1. **Import:** U-167's condition fired (every real import writes routines to IRISLOCALDATA; a crafted `%zz` routine wrote into IRISSYS). Batch 4 is not built here; AC5 and Batch 4 move to Story 21.41, parked for the owner (A: no Import; B: allow-list of classes, `.ext` and `%sqlcq.<ns>.QButtons.WRC*` routines parsed before any vendor call, `%DB_IRISLOCALDATA:WRITE` in the gate, null device, report-shape check). This story keeps AC1-AC4 and Batches 1-2.
  2. **Save** (veto U-183): runs in its request with no alarm bound (measured 0.01-0.20 s; the named gateway limit is the backstop), query-only. After any error status the port deletes the row the vendor left; tests for the compile-error and negative-case-number paths: the row is absent afterwards and the error still reaches the person. AD-7's 21.29 line: "leaves no row after an error".
  3. Accepted: "Planned" read from a non-empty plan; Save's side effects (runtime-statistics rows, statement-index rows, one cached query) named in AD-7's 21.29 line; the list note worded to what was measured (the saving user and holders of the roles read from the instance see a row; `%Development:USE` alone sees none of another person's rows); the case number stays a 1-9 digit whole number.

## Review Triage Log

### 2026-11-26 — Review pass

- verdicts: 13 findings — high 0, medium 3, low 10, false 0, maybe-false 0 (the last three rows are descriptive observations, not defects)
- findings:
  - `[medium]` `[patch]` The 3,000,000-character cap on Generate to this browser has no test — a tiny-cap fixture leg now asserts 422 TOOLONG, no lines and the temp file gone; the guard mutation reddens it.
  - `[medium]` `[patch]` Server-file Generate's added gate pairs have no test — `SqlReportRead` now asserts the pairs with and without `root`; dropping `FilePairs` reddens it.
  - `[medium]` `[patch]` The unruled 404 sentence for a gone saved query — replaced by the ruled "No query is saved for this support case in this namespace."; the old sentence is deleted.
  - `[low]` `[patch]` Cached-query cleanup is not read back — both after-checks assert the probe schema's cached-query count is 0 (a guard; `DROP TABLE` already clears them, so no mutation reddens it).
  - `[low]` `[patch]` An expected value built from the actual statement kind — the kinds are pinned literally (`dml`, `dml`, `ddl`), read from the instance.
  - `[low]` `[patch]` Mutation lines missing for the gone-row, refused-root/name/directory and null-device legs — each mutation applied, observed red, reverted and recorded; the gone-row leg's named mutation reddened every write test, so its comment now names the one that isolates it.
  - `[low]` `[defer]` Status fallback branch untested — only a row saved outside this story has an empty plan; frontmatter `deferred:`.
  - `[low]` `[reject]` Save's success path answers 500 and leaves rows if another user saves under the same case between the two reads — unlikely in one request window, and a fix would delete another person's row or add a guard branch.
  - `[low]` `[reject]` Generate's reworded consequence ("every query you can see") — it is the measured correction (Task 0 (d), (e)); recorded verbatim under Auto Run Result.
  - `[low]` `[reject]` A failed Delete answers 500, not 409 — no ruled sentence exists for it and the vendor's `ClearRow` answers 1 or 0 for a row the caller can see; adding a sentence is an escalation, not a patch.
  - `[low]` `[reject]` Intent audit: Save is unbounded where the matrix row says `stopped` — the 2026-11-27 ruling replaces that half; descriptive.
  - `[low]` `[reject]` Intent audit: the `%XML.Reader` read-back is in the test class, not the product — the matrix's read-back is a test assertion; descriptive.
  - `[low]` `[reject]` Intent audit: the list relies on the vendor's row-level security — the matrix says so; descriptive.

## Design Notes

**Governing ADs (spine line ranges):**

- AD-7 :211-259, with the 21.25, 21.26, 21.27 and 24.16 cases (record 1).
- AD-10 :395-462: `OCUPILOTSQL` through `Check`, and `OCUPILOTCODE`'s 19.13 import clause (record 3).
- AD-21 :617-667: the sixth case and its 21.15/21.19 consumers. This is the AD that governs server file writes (record 4).
- AD-29 :798, AD-44 :1041, AD-36 :878, AD-39 and AD-60.
- AD-51 :1218-1296, with the 21.6/21.25/21.26/21.27 cases (record 2), plus AD-52, AD-53, AD-56, AD-58 and AD-59.
- AD-66 :1539: no workflow change.

**Owner-gated, for the orchestrator.** Each part below is its own batch, so either can be parked alone. Batches 1 and 2 do not depend on them.

- **A. Import compiles code from a file** (Batch 4, AC5). The classic Import Report loads a report file and compiles the class definitions and code it carries into the namespace, replacing any class or routine of the same name, with only `%Development:USE`. Options:
  1. Ship it, stricter than classic. The gate adds the routines database's WRITE (as Explorer import does) and the classic page's custom resource. Its governance key ships `false` and it is destructive. A report holding OcuPilot code is refused. The agent may propose it from a server file only, and a person confirms.
  2. As 1, but a person's action only: no agent tool.
  3. Do not ship it. Import Report stays a classic-portal page.

  **Recommendation: 2.** Importing a report is a support engineer's step, usually into an empty namespace. Nothing an agent diagnoses needs it, and a code import with no agent path is the smaller surface. *Measure-first:* Task 0 (f) says what it writes and whether any routine lands in IRISSYS. A write outside the target namespace returns this question to the owner before Batch 4.
- **B. The classic page mails InterSystems support** (Batch 3, AC4). After a report is written, the classic dialog shows "Mail to", a client `mailto:support@intersystems.com` link whose subject names the case. The server sends nothing, and mail programs generally ignore the link's attachment (inference). Options:
  1. No mail action. The result names the server file, or the browser saves the file, and the person sends it as they choose.
  2. A mail action addressed to InterSystems support, as on the classic page.
  3. A mail action with the subject filled and no recipient.

  **Recommendation: 1.** OcuPilot then names no vendor address and starts no message to a vendor. Saving to this browser already puts the file where a person can attach it. With option 1, AC4 closes by the ruling and Batch 3 is empty.

**Records for the orchestrator** (proposed, add-only; the runner writes each one if allowed):

1. **AD-7** (after :257). Recommendation: allow.
   - Proposed text: "**Troubleshooting reports (Story 21.29)** are confirmed writes in their confirm or action request; the classic page's background job is not used. Saving a query runs one statement the console types a query, without its values, through `%SQL.Manager.QButtons.Base` `InsertQuery`, under the console's time limit, and an overrun leaves no saved row. Generating a report writes the case's saved queries to a temporary file OcuPilot names. Importing a report loads and compiles the code it carries into the request's namespace. Each runs in the request only when its measured worst case times 1.5 is under the Web Gateway's response timeout (measured at the story's Task 0); otherwise it uses Story 24.16's background-run form. Saving's side effects beyond its row are the runtime statistics rows and the fifth shape's statement-index row (measured at the story's Task 0)."
   - The last sentence is *measure-first*, Task 0 (c).
2. **AD-51, Story 21.29's case** (after :1295). Recommendation: allow. Proposed text: "Story 21.29's case: `SqlPort` answers the troubleshooting report tools' fresh reads through port-composed `CASE` (the case number's saved row count, with the statement's `GUARD` for a save), `SAVEDQUERY` (one saved row) and `REPORTFILE` (the reviewed file's case numbers, statements, documents and digest) types. It calls `%SQL.Manager.QButtons.Base` `InsertQuery` with the statement whole as a value, the declared `WRCNumber` validated as a whole number, and constants for its other arguments; `ClearRow` with the target id alone; `WriteAllToFile` with the case number and a temporary file OcuPilot names, copied to the declared `root` and `path` resolved through `PathPort` as an overwriting `file` or answered to the screen; and `ConsumeReport` with a temporary file OcuPilot writes from the reviewed text, the constant flags `ckd`, and the request's validated namespace, refused when the file no longer yields the reviewed digest. Each call runs under the null device, only inside the confirmed write, after the prohibited and shape checks."
3. **AD-10: no new arm.** Recommendation: allow.
   - Save inherits the console's `Check`, so no saved row references OcuPilot's tables through OcuPilot.
   - Import is judged by `OCUPILOTCODE`'s existing import clause on the reviewed documents.
   - Generate only reads. AD-10 refuses no export.
4. **AD-21, Story 21.29's consumers of the sixth case** (add-only). "Story 21.29's consumers: the report's generate is an overwriting `file` consumer whose overwrite is a constant, and it refuses a name whose directory does not exist; the import's file is a `source`; local text is a screen value. The vendor receives only a temporary file OcuPilot names." Recommendation: allow.
5. **Governance keys** (recommendation):
   - `explorer.sqlreports.save` `true`: a row, undone by Delete.
   - `.delete` `false`: as 21.27's purge was ruled.
   - `.generate` `true`: every export ships `true`.
   - `.import` `false`: as `explorer.classes.import`.
6. **Gate.** Recommendation: allow, as classic or stricter.
   - Reads take `%Development:USE` (the classic pages' `RESOURCE`).
   - Writes add `AtelierPort.WritePairs(ns)` and any pair Task 0 (a) measures.
   - Generate to a server file and import from one add PathPort's pairs (`%Admin_FileSystemAccess:USE`, `%DB_IRISSYS:READ`). The classic dialog writes any server path with `%Development:USE` alone.
   - Every action honours a custom resource on the classic pages through `Gate.WithClassicPages` (the 21.28 ruling).

**Decided in-stage:**

- **Placement.** One list, SQL troubleshooting reports, holds every saved query of the namespace, with a case-number column. Save query and Generate report are page actions, and Delete is a row action. Save is not on SQL query: the classic flow collects several queries under one case before generating.
- **Delete by row only.** `ClearData` (by case, or every row when the case is empty) is not offered, so no write reaches rows by a pattern.
- **Constants.** `includeresults` 0 (the vendor documents it as having no effect), `debug` 0, `planFormat` the vendor default (`FetchPlan` ignores it), and `ConsumeReport`'s flags `ckd` as on the classic page.
- **Generate overwrites**, as the 21.15 and 21.19 exports do: the classic dialog overwrites after a confirm, and the proposal card states it.
- **No Details pane.** The classic Details link shows the stored plan, and SQL query's Explain plan shows the current one.
- **Tool names** `explorer.sqlreports.*`, entity type `sql-saved-query` (a tool's target type is its descriptor's primary type).
- **Epic context reuse.** The spine and EXPERIENCE.md are newer than `epic-21-context.md` only by 21.26-21.28's add-only lines, read here directly (the plan block's instruction).

**Strings, escalated as one batch** (none is in EXPERIENCE.md). *Measure-first* clauses ship only as measured, and any correction is reported verbatim.

1. **Title:** "SQL troubleshooting reports" (classic "Generate Report", help "Generate SQL Troubleshooting Report"; siblings "SQL runtime statistics", "SQL index analyzer").
2. **Columns:**
   - New: "Support case (WRC)" · "Saved" · "Status" · "Delimited identifiers" (classic "WRC Number", "Time Inserted (GMT)", "Status", "Delim. Ident.").
   - Reused: "ID", "Schema" and "Statement".
   - Status values: "Planned" for a row whose plan was built, else the instance's own message. *Measure-first:* Task 0 (c).
3. **Empty state:** "No query is saved for a troubleshooting report in this namespace." (sibling "No runtime statistics are recorded in this namespace.")
   - Agent invitation: "save a query for a troubleshooting report".
4. **Note on the list:** "A saved query is listed for the person who saved it and for holders of %All or %Developer." *Measure-first:* Task 0 (e).
5. **Actions and dialogs:**
   - Actions: "Save query" · "Generate report" · "Import report" (classic) · "Delete" (reused).
   - Field "Support case (WRC)", with help "The case number InterSystems support gave you, digits only."
   - "Statement" reused. The transfer choices reuse `explorerTransferServer`, `explorerTransferBrowser` and `explorerTransferLocal`.
   - Dialog titles: "Save query for a troubleshooting report" · "Generate report for support case <wrc>" · "Import a troubleshooting report".
6. **Consequences:**
   - Save: "Saving runs the statement once, without its values, to record its plan and statistics, then stores the statement, its plan, the definitions of the classes it reads and its compiled code under this support case." *Measure-first:* Task 0 (c).
   - Delete: "This saved query is removed from its support case's report. Save it again to restore it."
   - Generate: "The report holds every query saved for this support case in this namespace, with its plan, the definitions of the classes it reads and its compiled code. A file already at this name is replaced." (sibling 24.10). *Measure-first:* Task 0 (d).
   - Import (gated A): "Importing loads and compiles the class definitions and code this report holds into this namespace, replacing any class or routine with the same name, without asking. This cannot be undone." (siblings `explorerImportReplaces`, `localeImportConsequence`). *Measure-first:* Task 0 (f).
7. **Status lines:**
   - "Saved the query for support case <wrc>." · "Deleted the saved query."
   - "Exported the report for support case <wrc> to <path>." · "Saved the report for support case <wrc> as <file>." (siblings `localeExportDone`, `localeExportSaved`)
   - Gated A: "Imported <classes> classes and <routines> routines."
   - The stop reuses `explorerSqlStopped`/`…One`, plus " Nothing was saved."
8. **Refusals:**
   - "Saving a query runs it, so it takes a query only." (sibling `REASONSQLPLANSTATS`)
   - "A support case number is a whole number of up to 9 digits."
   - "No query is saved for this support case in this namespace."
   - "This report is longer than 3,000,000 characters, so it can be generated to a server file only."
   - "The instance did not save this query." · "The instance did not write this report." · Gated A: "The instance did not import this report." (sibling "The instance did not purge…")
   - Gated A: "This file is not a troubleshooting report." · "The file changed after the import was reviewed, so nothing was imported. Review the import again." · "A report file holds at most 3,000,000 characters, and this one holds more." (siblings `localeRefusal*`). Own code reuses `PROHIBITED.OCUPILOTCODE`'s published sentence.
9. **Suggested prompts:** "Which queries are saved for a support case?" · "Which saved queries failed to plan?" · "When was each support case's query saved?"
10. **Command aliases:** "troubleshooting report" · "report generator" · "WRC report".
11. **Mail (gated B, only if option 2 or 3):** action "Mail to InterSystems support" (option 2) or "Write an email" (option 3), with the note "Your mail program opens a new message. Attach the report file yourself."

**Extend, don't copy (Rule 2/31):**

- The endpoint extends `SqlPort` beside `RuntimeStats`/`IndexAnalysis`, through `StatementCall`, `ValueProblem` and `Classify`'s `GUARD`. The list is one more catalog statement.
- Save's mint reuses `ExplorerSqlRunMint`'s console checks. The tools extend `SqlStatementAction`, and Import follows `ExplorerImport`.
- **The file handling is a reasoned copy.** `ResourceTransferPort.ImportText`/`Export` are `Private` and bound to `ResourceFileError` codes, so `SqlPort` repeats their roughly 40 lines of shape: it calls `PathPort.Resolve` and `AtelierPort.ReadText` directly. Unifying the copies is recorded in the frontmatter `deferred:` list for the lead's harvest.
- The null device is 21.27's `Kernel/Utils` helper. The client dialogs are 19.13's. The fixture extends `SqlTuningProbe`.

**Integration ACs:** the list consumes the writes' rows (AC1, AC2), and Import consumes Generate's file (AC5).

- **Consumed-by:** none planned.
- **Consumes:** Story 21.6's `SqlPort`, `SqlStatementAction`, seam and probe; Story 21.27's null-device helper and value machinery; Story 19.6/19.11's `Classify`, `Check` and `ExplorerSqlRunMint`; Story 18.1's `PathPort`; Stories 19.13, 21.15 and 21.19's transfer shape and dialogs.

**Ledger inbox:** none. DW-2851 is a constraint, not owned.

**Contended paths (Epic 24), checked 2026-11-25** with `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp`:

- Commits on `EntityType`, `Prohibited`, `Baseline`, `screen-action-handler.ts`, `strings.ts`, `screen-outlet.ts`, `screen-actions.ts`, `proposal-view.ts`, EXPERIENCE.md, `ci-throwaway.sh`, `MappingDescriptor` and `ConfirmNamespaceRoster`. Edits there are add-only.
- None on `SqlPort`, `AtelierPort`, `AtelierError`, `PathPort`, `ResourceTransferPort`, `ExplorerImport`, `SqlStatementAction`, `SqlTuningProbe`, `CompositeMintSweep` or the two transfer dialogs.

**Size:** 4 write tools (1 gated), 1 derived read, 1 list, about 30 files, in four batches (2 gated).

## Verification

**Shared surfaces** (all `(loop)`):

- The tool registry: `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolRoundTrip`, `StageTwoTools`, `DeveloperFloor`, `SurfaceCoverage`, `DraftRegistry`, `CompositeMintSweep` and `ConfirmNamespaceRoster`.
- The descriptor roster: `MappingDescriptor` `CLASSICROSTER`, since the tools declare `CLASSICPAGES`, plus `EndpointCoverage` and `screen-mirror.test.mjs`.
- Entity types and the prohibited set: `Prohibited` and the `EntityType` tests.
- Governance: `Baseline`.
- The side bar: `suggested-prompts.test.mjs`.
- Gates: `PortGate` and `ClassicPageGate`.

Grep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each surface, and derive any order-sensitive roster from the instance. Each test changed joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Each runs in its own foreground call with `timeout: 600000`, against `ocupilot-ci` only, one test call per message.

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/e21-kit/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SqlReportRead` -- expected: green. Then, one class per call, each expected green: `SqlReportWrite`, `SqlReportImport` (Batch 4), `SqlRuntimeStatsRead`, `ResourceTransferRead`, and every shared-surface class above.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/screen-mirror.test.mjs tools/suggested-prompts.test.mjs tools/self-protection.test.mjs` -- expected: green.
- `(loop)` Four steps, then the specs:
  1. `cd ui && npm run build`
  2. `npm run test:components`
  3. `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  4. `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-sql-reports.browser-spec.mjs browser/system-explorer-sql-runtime-stats.browser-spec.mjs`

  Expected: green, and green in reverse order.
- `(once)` `cd ui && npm run test:tools` -- expected: green (EXPERIENCE.md changes).
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC, each recorded here as `mutation: … -> …` when observed:**

- AC1: `SAVEQUERY` skips the query-only check -> `SqlReportWrite`'s DML leg red (the seam counts a call). The catalog drops `WRCNumber` -> `SqlReportRead`'s columns leg red.
  - mutation: `SqlPort.ReportWrite` kind check replaced by `If 0` -> `SqlReportRead.TestAStatementThatIsNotAQueryOrIsOcuPilotsOwnIsRefused` red (three direct-write 422 legs); reverted, green (run 1032).
  - mutation: `AtelierPort.CATALOGSQLREPORTSCOLUMNS` drops `WRCNumber` -> `SqlReportRead.TestTheListCapsItsRowsAndReportsTheCut` red (row case/status leg, run 1029); reverted, green.
  - mutation (the 2026-11-27 ruling, save after an error status): `SqlPort.ReportWrite` skips the removal of rows the failed call left -> `SqlReportWrite.TestASaveThatEndsInAnErrorStatusLeavesNoRowAndTheErrorReachesTheCaller` red on both its legs, compile error and negative case number (run 1026); reverted, green.
- AC2: `DELETEQUERY` calls `ClearRow` with another id -> `SqlReportWrite`'s other-rows-stay leg red.
  - mutation: `SqlPort.ReportCall` clears `pId + 1` -> `SqlReportWrite` red on the delete legs (3 tests, run 1027); reverted, green (run 1031).
  - mutation: `SqlPort.ReportRow` answers a gone row with the reviewed fields instead of 404 -> `SqlReportWrite.TestARowGoneAfterTheMintRefusesTheConfirm` red ("500 INTERNAL" for the confirm, run 1044); reverted. Dropping `ID` from `ExplorerSqlReportDelete`'s `FINGERPRINTSUBJECT` reddens every write test, so it proves nothing about this leg and the test's doc comment names the `ReportRow` mutation instead.
- AC3: `GENERATE` skips the no-row precondition -> the no-row leg red (the seam counts a call). The store drops the browser branch -> `sql-reports.page.spec.ts` red.
  - mutation: `SqlPort.ReportGenerate` no-row refusal replaced by `If 0` -> `SqlReportWrite.TestTheGenerateRefusalsCallNothing` red (the refusal leg and the no-call leg, run 1028); reverted, green. The store half is Batch 2's.
  - mutation: `SqlPort.ReportGenerate` skips the directory check (`If 0`) -> `SqlReportWrite.TestTheGenerateRefusalsCallNothing` red on its missing-directory legs (run 1038); reverted.
  - mutation: `SqlPort.ReportGenerate` ignores the `PathPort.Resolve` error status -> `SqlReportWrite.TestTheGenerateRefusalsCallNothing` red on its PATH.ROOT and PATH.NAME legs (run 1039); reverted.
  - mutation: `SqlPort.ReportGenerate` skips the `MAXREPORTCHARACTERS` check (`If 0`) -> `SqlReportWrite.TestAReportLongerThanTheCapIsRefusedForTheBrowserAndNothingIsLeft` red on the 422 and no-lines assertions (run 1037); reverted.
  - mutation: `OcuPilot.Screen.Tool.ExplorerSqlReportGenerate.ArgumentPairs` drops `FilePairs` -> `SqlReportRead.TestAServerFileAddsThePathPairsAndABrowserReportAddsNone` red on the server-file leg (run 1045); reverted.
  - mutation: `OcuPilot.Kernel.Utils.CallWithNullDevice` restores the namespace only when the call answered OK -> `SqlReportWrite.TestTheDeviceAndTheNamespaceAreRestoredAfterARaisedCall` red (run 1042); reverted. Skipping the restore on every path ends the run at its first test, so it does not isolate this leg.
  - mutation (client): `SqlReportsPage.onGenerate` saves the file only `if (sent && file === '')` -> `sql-reports.page.spec.ts` "generates to this browser..." red; reverted, green (12/12).
- AC4: the page offers a mail action -> its spec leg (asserting the absence) red.
  - mutation: the descriptor gains a `mail` row action -> `SqlReportWrite.TestThePageOffersNoMailAction` red (run 1030); reverted, green. The page spec leg is Batch 2's.
  - mutation (client): `sql-reports.page.ts`'s template gains `<a href="mailto:someone@example.org">` -> `sql-reports.page.spec.ts` "offers no mail action, no mail link and no string that mails anyone (AC4)" red; reverted, green.
- AC5: the write skips the `OCUPILOTCODE` check -> `SqlReportImport`'s own-code leg red, with the seam counting a call.
- AC6: the page drops Save query's post -> after rebuild and redeploy, the browser spec red.
  - mutation (client): `SqlReportsPage.onSave` sends nothing (`sent` is false) -> after `npm run build` and the copy into `ocupilot-ci`, `system-explorer-sql-reports.browser-spec.mjs` AC1 red (the dialog never closes, `TimeoutError` at `dialogClosed`, 64 s); reverted, rebuilt and redeployed, 4/4 green. The new spec then the runtime statistics spec, and the runtime statistics spec then the new spec, each 4/4 green and each leaving no saved row, probe table or cached query.

### Task 0 measurements

Measured 2026-11-26 on `ocupilot-ci` (IRIS 2026.2 build 221U), in `USER` and `HSCUSTOM`; every line observed unless marked (inference). The probe was schema `OcuProbe229` (`T`, join tables `J1` to `J5`, `NP` with no grant) and two SQL functions in a scratch class, one counting its calls and one hanging 0.5 s; no product source changed. Both stores held 0 saved rows at the start. Removed and read back absent: saved rows and the `^IRIS.QButtons.*` globals (both namespaces), tables and classes, cached queries, runtime-statistics rows (`StatsRowCount` 0), statement-index rows naming the probe (after `Statement.Clean()` and a purge of the DDL statements' cached classes), the 233 imported `%sqlcq.<ns>.QButtons.WRC*` routines, the crafted `%` routine in IRISSYS, six principals with their roles, report files (one relative-name file landed in `mgr/user`) and the scratch class. `Statement.Clean()` also dropped other stale index rows of the two namespaces.

- **(a) Privilege and gate.**
  - The classic pages' compiled `RESOURCE`: `ReportGenerator` `%Development`, the generate dialog `%Development:USE`, `ReportLoader` `%Development`, `ReportLoaderOutput` none. No page has an `EDITRESOURCE` or a custom resource on this build.
  - The principal held `%Development:USE`, `WritePairs(ns)` (USER: `%DB_USER` RW, `%DB_ENSLIB` R, `%DB_IRISLIB` R; HSCUSTOM adds `%DB_HSCUSTOM` RW and `%DB_HSLIB` R) and SELECT on the probe table, in both namespaces. No `<PROTECT>` anywhere.
    - Save, Generate and delete of its own row answered OK. Generate wrote a server file without `%Admin_FileSystemAccess` or `%DB_IRISSYS`, which the principal lacked.
    - List: the vendor's `SavedQueries` and an unchecked prepare answer; a checked prepare of `%SQL_Manager_QButtons.Base` answers SQLCODE -99.
    - Save over a table the principal has no SELECT on (`NP`, and `T` once an import replaced the class and its grants) answers the error status -99, "User ... is not privileged for the operation", with no row left. Save therefore needs the SQL SELECT privilege on the statement's tables, as Plan does; it is not a resource pair.
    - Import loads the class under the namespace's WRITE pair. The compiled-query routine is skipped with the device text "Item '%sqlcq.<ns>.QButtons.WRC<n><id>.INT' is mapped from a database that you do not have write permission on. Will skip this item." and the status is OK. A `%Developer` role holder in HSCUSTOM skips it the same way. A `%`-named routine in a crafted report is skipped likewise without `%DB_IRISSYS:WRITE`. A full import therefore needs `%DB_IRISLOCALDATA:WRITE`, which the gate does not name (it joins the gate if Import is built), and the routine's presence is read back.
  - Databases: `^IRIS.QButtons.BaseD`, `BaseS` and `BaseI` sit in the namespace's own default globals database (`mgr/user`, `mgr/HSCUSTOM`). An imported class lands in the target namespace's code database. A report's routine `%sqlcq.<ns>.QButtons.WRC<case><n>` maps to IRISLOCALDATA (`GetRoutineDest`), and any other `%` routine name maps to IRISSYS (`mgr/`).
- **(b) Durations** (x1.5 against the 60 s gateway limit, `BoundSeconds` 50).
  - Save of a probe query: 0.01 to 0.10 s in both namespaces (20 saves 0.58 s, 190 saves 5.7 s); a five-table equi-join 0.20 s (x1.5 = 0.3 s); DML and DDL statements 0.01 to 0.04 s. A statement that runs long takes as long as it runs: 8 rows of a 0.5 s function took 4.06 to 4.12 s.
  - **`$System.Alarm` does not stop `InsertQuery`.** With a 2 s alarm the 4.06 s save finished OK with its row saved and all 8 calls made; with 1 s, outside any `Try`, 4.10 s and sc 1. The same alarm stops a plain `%Execute` of the statement at 1.00 s (SQLCODE -149, `<ALARM>`). Killing the process at 2.5 s leaves no row (and `$System.Process.Terminate` answered 1), but leaves 1 statement-index row, 4 statistics rows and 2 cached queries.
  - Generate: 1 row 0.00 s (15,167 bytes), 20 rows 0.00 s (302,277 bytes), 190 rows 0.04 s (2,870,147 bytes, just under `MAXIMPORTCHARACTERS`).
  - Import: 1 row 0.05 s (0.25 s over an existing class), 20 rows 0.81 to 0.82 s, 190 rows 7.92 s (x1.5 = 11.9 s). Every measured Generate and Import is far under 60 s; Save's worst case is the statement's own and has no cap.
- **(c) What Save does.**
  - It runs a `SELECT` once: the counting function was called 2 times for 2 rows. An unbound `?` runs nothing (0 calls), and the row still holds the plan. `UPDATE`, `INSERT`, `DELETE` and `CREATE TABLE` are saved and not run: the table kept 20 rows and no `zz`, `999` or `DDLX`. A syntax error or an empty text answers an error status with no row.
  - A row holds the statement, the plan as text (0.5 to 5.4 KB) and as an array (44 lines for the probe), the class definitions of the classes the statement reads (5.3 KB) and its INT code (2 to 4 KB), `ClassList`, the schema `SQLUser`, delimited identifiers 1, the saving user, the job number, the vendor version, and `QueryCompileStatus` 1. Status is 1 for every row measured, including the `INSERT` and `CREATE` rows, whose plan stream is empty and class list empty: "Planned" has to be read from a non-empty plan, and a `CASE WHEN QueryPlan IS NULL` over the table answers it. `TimeInserted` is `yyyy-mm-dd hh:mm:ssAM` or `PM` in UTC (12-hour), so it does not sort by time across noon (inference).
  - It writes no byte to the current device, even with `%request` an object (0 bytes in every run), except when the vendor's compile fails: a five-table `SUM` over a cross join answered the error status "Error compiling routine %sqlcq.<ns>.QButtons.WRC<case><n> ... <UNDEFINED>hybtfForNonDistinct+10^%qaqcpre" (a vendor fault on that shape, twice) with 107 bytes on the device, **and the row was saved**. A negative case number (`-5`) answers `<INVALID OREF>QueryIntCodeCreate+5^%SYS.PTools` and also leaves its row. A stop by kill leaves none.
  - Side effects of one save of a new statement (HSCUSTOM, counts before to after): runtime-statistics rows +4 to +6 (8 to 14 on a fresh statement, +5 on the same one again); statement-index rows +3 (the statement, `DECLARE QRS CURSOR ...` and `DECLARE PTGS<job number> CURSOR ...`, whose name carries the saving process's job number, so each new process adds one); cached queries +1. The journal of one save in `USER` also shows `^oddDEP` kills and sets (class dependency data of the probe table and ten system classes, about 100 records), `^rINDEXSQL`, `^PTools.SQLStats`, and `^%SYS("sql","statement id")` in IRISSYS, which any prepare writes.
- **(d) Generate.**
  - `WriteAllToFile` leaves `filename` as given (no extension added; `/tmp/x` stays `/tmp/x`) and changes no row (28 nodes and the same checksum before and after). A relative name wrote into the database directory (`mgr/user`) and the check by name found nothing, so the port never passes one. A missing directory answers the error status "Cannot open file ...". An existing file is overwritten without a word.
  - A case with no row, a non-numeric case and an empty case answer OK and write a 50-byte report with no rows. The port's precondition (`CASE` row count) is therefore its own.
  - It holds only the rows the caller sees (see (e)). The file is `<QButtons><QButton>...`, with the plan, the plan array and two CDATA exports (`ClassDefXml`, `QueryIntCode`); `%XML.Reader` with `Correlate("QButton", "%SQL.Manager.QButtons.Base")` read 1, 2 and 20 rows into the vendor class unsaved (`%Id()` empty) and 0 rows from the empty report. About 15 KB per row; 190 rows are 2.87 MB.
- **(e) Row-level security.** A principal that did not insert the row and holds no `%Developer` role saw 0 rows through `SavedQueries` and an unchecked SQL read, in both namespaces, and its Generate wrote the empty 50-byte report. A principal holding the `%Developer` role saw every row and generated the full 15,167-byte report. `ClearRow` by the first principal on a row it cannot see answered 1 and the row stayed (a silent no-op); by the `%Developer` holder it removed the row. The vendor's policy returns the inserting user, `%All` and `%Developer`; a `%Development:USE` holder is not among them (`irisowner`, with `%All`, saw every row).
- **(f) Import.**
  - It loaded the report's class definitions (`OcuProbe229.T.cls`, `.ext`) and compiled them, loaded the INT code as the routine `%sqlcq.<ns>.QButtons.WRC<case><n>` (compiled to OBJ), and **inserted every row of the report into `%SQL.Manager.QButtons.Base` of the namespace** (the list grows by one row per report row). The journal shows writes to the target namespace's database only for those rows and the class's compile (`^oddDEF`, `^oddCOM`, `^oddDEP`, `^rINDEXCLASS`, `^rMAP`, `^rINDEXEXT`, `^ISC.Src.Jrn`); the routine write is not journaled (IRISLOCALDATA).
  - It replaced an existing class: a column `Z` added by `ALTER TABLE` was gone after the import while the table's 2 rows stayed. Importing twice inserts the rows twice.
  - It wrote 535 bytes (1 row), 10,738 to 10,900 bytes (20 rows) and 102,372 bytes (190 rows) to the current device, with or without `%request`, so the null device is needed. It left no file in `mgr/Temp`.
  - The file's documents can be listed without loading them: parse with `%XML.Reader` and call `$SYSTEM.OBJ.LoadStream(<stream>, "/nodisplay", .err, .list, 1)` on `ClassDefXml` and on `QueryIntCode` (`OcuProbe229.T.cls`, `OcuProbe229.T.ext`, `%sqlcq.USER.QButtons.WRC23008.INT`).
  - **Writes outside the target namespace.** (i) Every import of a real report writes its `%sqlcq.<ns>.QButtons.WRC<case><n>` routines to IRISLOCALDATA, not the namespace's own database. (ii) A report whose routine was renamed `%zzocu2129probe` (crafted from a real one) wrote `^ROUTINE`, `^rINDEX` and `^rOBJ` for it into IRISSYS (`mgr`) as `irisowner`; a principal without `%DB_IRISSYS:WRITE` was skipped. The vendor checks nothing of the document's name.
  - A file that is not a report: plain text answers the error status "SAX XML Parser Error: invalid document structure"; a missing file answers an error; **any other XML (`<hello/>`) and an empty report answer OK and do nothing**, so "not a report" is the port's own parse (no `QButton` element).
- **(g) Case number.** `WRCNumber` is `%Integer`, required. Refused with an error status and no row: `abc`, `12ab`, empty. Accepted and stored as read: `0`, `007` (7), `1.5` (stored 1), `1E3` (1000), `+7`, `-0` (0), `999999999`, `1000000000`, 20 digits unchanged, and `9223372036854775808` (stored `...810`). `-5` and a leading space answer `<INVALID OREF>QueryIntCodeCreate+5^%SYS.PTools`, and `-5` leaves its row. Generate matches a case only by its stored number: `1.5` finds no row of case 1. The ruled check (1 to 9 digits, not 0, digits only) is stricter than the vendor's.

**Results against the rulings (for the lead).**

- **A2, Import.** Under the Spec Change Log's own test, Batch 4 is not built: every real import writes routines to IRISLOCALDATA, outside the target namespace's database, and a crafted report writes IRISSYS ((f)). Whether IRISLOCALDATA counts as the target namespace is the lead's call; if it does, a refusal before the vendor call of any document that is not a class, `.ext` or a `%sqlcq.<ns>.QButtons.WRC*` routine bounds the IRISSYS case, and `%DB_IRISLOCALDATA:WRITE` joins the gate.
- **Item 1, Save "under the console time limit".** `$System.Alarm` cannot stop `InsertQuery` (b), so a Save of a long statement runs to its end whatever `BoundSeconds` says, and the answer is lost past the gateway limit, as Gather's is. A kill from a child job leaves no row but leaves statistics, a statement-index row and cached queries. No worst case reaches 60 s on the probe, so this is not the AD-7 stop condition; the unboundedness is an intent gap against "stopped, and no row left".
- **Item 1, "leaves no row if stopped".** A vendor error does not mean no row: a compile failure and a negative case number answered an error status and left a row (c). The port reads the rows back and removes the one it made, or refuses the case number first.
- **Strings 2, 4, 6.** "Planned" is the plan stream, not the status (c). The Save consequence "runs the statement once, without its values" holds for a query; the AD-7 side-effect sentence needs "runtime statistics rows, statement-index rows and a cached query" (c). The list note is true as "for the person who saved it and for holders of the `%Developer` role" (and `%All`), and holders of `%Development:USE` alone see none of another person's rows (e).

## Auto Run Result

Status: done
Blocking condition: none

This pass built Batches 1 and 2 under the 2026-11-27 rulings. Batch 3 is empty and Batch 4 (Import, AC5) moved to Story 21.41. Commits: Batch 1 `e379a35b1`, Batch 2 `921963704`, and the review patches in the finalize commit.

- **Batch 1 (server).**
  - `Catalog.SqlReports` list in `AtelierPort`.
  - `SqlPort` `Reports` endpoint: the `CASE` and `SAVEDQUERY` reads and the `SAVEQUERY`, `DELETEQUERY` and `GENERATE` writes.
    - Save runs in its request with no alarm bound, query-only, and deletes any row the vendor left after an error status.
    - Generate writes through an OcuPilot-named temp file to a `PathPort`-resolved overwriting file or answers lines for the screen.
  - Tools `explorer.sqlreports.save`, `.delete` and `.generate` (abstract `SqlReportAction`), the descriptor `ExplorerSqlReports` at side-bar position 24, entity type `sql-saved-query`, governance keys save `true`, delete `false`, generate `true`, new codes in `AtelierError`.
  - Test classes `SqlReportRead` (8) and `SqlReportWrite` (12), the probe fixtures, and the roster classes.
- **Batch 2 (client).** `sql-reports.page.ts` with its save dialog and spec, the ruled strings, one EXPERIENCE.md Fixed strings row, and `system-explorer-sql-reports.browser-spec.mjs`. The page offers no mail action; the page spec and the browser spec assert the absence.
- **Review.** 13 findings: 6 patched (3 medium, 3 low), 1 deferred, 6 rejected with reasons in `## Review Triage Log`. Follow-up review recommended: `false` (three medium patches, all test additions each shown red by a mutation).
- **Verification.** `LOADERRORS=0`; `SqlReportRead`, `SqlReportWrite` and every roster class green on `ocupilot-ci`; `npm run test:tools` 2430, `npm run test:components` 4136; `npm run build` under the 2500 kB budget (2.36 MB initial); the new browser spec and `system-explorer-sql-runtime-stats.browser-spec.mjs` 4/4 each, in both orders; `check-objectscript.py` and `lint-docs.sh` clean. Not run here: the `(once)` full ObjectScript sweep and `smoke.sh` (runner-owned).

**For the runner (strings and decisions).**

- **Corrected string, verbatim.** The Generate consequence reads "The report holds every query you can see that is saved for this support case in this namespace, with its plan, the definitions of the classes it reads and its compiled code. A file already at this name is replaced." The ruled text said "every query saved"; Task 0 (d) and (e) show Generate holds only the rows the caller can see.
- **No new sentence ships.** The 404 for a gone saved query reuses "No query is saved for this support case in this namespace."
- **Stop sentence not shipped** (Save has no alarm bound). No Import or mail string ships.
- **Decided in-stage.** A failed Delete answers the internal 500 (no ruled sentence exists for it). The `CASE` read with an empty case number answers `Saved` 0 so the kernel's target read does not turn every screen action into a 500; the writes still refuse an empty or malformed case number with 400. The fresh reads use checked prepares (U-174), so a principal with `%Development:USE` but no SQL SELECT on `%SQL_Manager_QButtons.Base` is refused 403 `SQL.SELECT.PRIVILEGE` on Save, Delete and Generate while the list still shows rows. Generate's agent mint does not resolve the file; a bad root, name or directory is refused at the confirm, before any vendor call.
- **Contended files, add-only.** `Prohibited.cls`, `EntityType.cls`, `Baseline.cls`, `strings.ts`, `proposal-view.ts`, `screen-actions.ts`, `screen-action-handler.ts`, `screen-outlet.ts`, EXPERIENCE.md and `README.md` (one disabled-action count and one clause). `Test/Prohibited.cls` also changed one tripwire assertion: the last covered type is now `sql-saved-query`.
- **Residual.** A Save in the browser spec leaves runtime-statistics and statement-index rows for the probe statement (Task 0 (c)); `RemoveReport` does not remove them. A subagent wrote one test class through a Python heredoc against Rule Zero; the result was read back and is correct.
