---
title: 'Story 21.6: The SQL tuning track'
type: 'feature'
created: '2026-11-15'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The story asks for seven classic SQL performance leaves (EX-44, EX-46 to EX-52) plus the slow-query workflow's screens. Probed on slot A's `ocupilot`, that is about 9 reads and 20 writes across five backing shapes. Four of the shapes run a vendor background job, two run the person's statement, one compiles code from a server file, and at least two AD records are needed before any write can be built. That is far past one implement pass.

**Approach:** Split into six stories inside Epic 21. This story keeps the statement index with frozen plans and the cached-query purge. Each child is re-planned on its own once the runner rules the split and the AD records below.

## Boundaries & Constraints

**Always:** Each leaf joins System Explorer's SQL slice (Story 19.6's console, Story 19.14's catalog tabs) through one descriptor and one port. Every write is a confirmed proposal reached by both callers (AD-53). Every new destructive key ships disabled. Each leaf names its classic page and backing class from the instance.

**Never:** Nothing is implemented in this pass. No AD is amended in-stage. Nothing runs on `ocupilot-ci`. No leaf moves to the exclusion register without the owner. The `slowquery` workflow gains no write: the MCP prompt it was harvested from "recommends a fix — never auto-applies one".

## I/O & Edge-Case Matrix

To be written by the re-plan for the narrowed story, from the inventory in Design Notes.

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AtelierPort.cls` -- `CATALOGSTATEMENTSQUERY` (:218, column map :261) and `CATALOGTABS` (:154): the per-table statement read a namespace-wide statement index extends (`STATEMENTS` joined to `STATEMENT_RELATIONS` and `STATEMENT_LOCATIONS`; plan state from `Frozen`). The cached-query and index reads (:200, :210) go through `CatalogQuery` (:1390).
- `src/OcuPilot/Port/SqlPort.cls` -- endpoints `Sql` (`GUARD`, `RUN`) and `SqlData` (`PLAN`, `RUN`) (:42-61), `Invoke` (:658, 501 for any other pair), `NamespacePairs` (:779-795), `Classify` (:455), `Plan()` (:604, the console's explain). TUNE TABLE (52), FREEZE PLANS (63), UNFREEZE PLANS (64), PURGE (65) and BUILD INDEX (66) are already kind `ddl` by the vendor's type table: a person's or the agent's confirmed console Run can issue them today (inference; not run).
- `src/OcuPilot/Port/ConfigPort.cls:777` -- Story 21.4's `PurgeCachedQueries()`, `$SYSTEM.SQL.PurgeQueries({"allNamespace":1})`, gated by the System Configuration pairs and overridden by `Test/ConfigGateSeam.cls:119`. `PurgeQueries` also takes `table` and `class` and, with no qualifier, purges the current namespace (`irislib/%SYSTEM/SQL.cls:1870-1895`).
- `src/OcuPilot/Screen/Descriptor/ExplorerSqlTableStatements.cls`, `ExplorerSqlCachedQueries.cls`, `ExplorerSqlIndices.cls` -- the table tabs (positions 9, 8, 3 of `system-explorer/sql-tables`), `%Development:USE`, classic page `%CSP.UI.Portal.SQL.Home`, `rowActions: []`.
- `src/OcuPilot/Screen/Tool/DatabaseAction.cls` and `TaskResume.cls` -- the bodyless action-write family a freeze, unfreeze and clear-statistics family follows (`READTYPE` `STATE`, `SENDSBODY` 0, `PRECONDITIONFIELD`).
- `src/OcuPilot/Kernel/Agent/Workflow.cls:261-267` -- the `slowquery` entry: four read steps, no write. `Test/WorkflowCatalog.cls:117` pins "names no write tool"; `ui/tools/suggested-prompts.test.mjs:82,111-114` pins its one offering screen, `ExplorerSqlQuery`.
- `src/OcuPilot/Port/HarvestPort.cls:76` and `Port/DevToolPort.cls` -- the seam and its newest read-only caller; `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/SqlAdvisor.cls` (`BuildAdviceData` :120, `RunExplain` :192, `IndexRowsForClass` :293) is the unharvested advice body. It builds its SQL by concatenation.
- Classic sources: `irislib/%CSP/UI/Portal/Dialog/SQLStatementDetails.cls` (freeze :366, unfreeze :405, clear statistics :452, check frozen :613, clear error :629), `irislib/%CSP/UI/Portal/SQL/Home.cls` (actions menu :408-425, purge :3740-3761, rebuild :3676-3690, statement index :1059-1071, clean stale :1115-1119).

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/epics.md` -- runner: rule the split and the AD records in Design Notes, insert the children's story blocks, and reset this spec to `draft` for re-plan -- the story is too large for one pass, and the kept part needs two AD records first.

**Acceptance Criteria:**

- Given the runner's ruling, when each child is re-planned, then every leaf below has exactly one owner or a closing disposition, and the workflow criterion is carried by each story that adds a slow-query read.

## Design Notes

**Governing ADs:** AD-5, AD-7 (vendor background jobs; the statement-index shape), AD-10 (self-protection over OcuPilot's own statements, tables and code), AD-21 (no caller path; no concatenated SQL), AD-23 (harvest seam), AD-29, AD-36, AD-44, AD-51 (action writes; named entries), AD-52, AD-53, AD-58, AD-66 (the workflow).

**(a) Leaf inventory.** Probed read-only on `ocupilot` (`ocupilot-slot-a`), 2026-11-15: resources from `%Dictionary.CompiledParameter` in `%SYS`; `%SQL.Manager.Catalog` and `%SQL.Manager.API` (hidden) through `%Dictionary.MethodDefinition`; counts by `SELECT` in `HSCUSTOM`. No page has a custom resource (`%SYS.Portal.Resources.%GetCustomResourceList` empty).

| Leaf | Classic page (resource) | Backing (verified) | Writes, and what the vendor call takes | Background |
|---|---|---|---|---|
| EX-44 Statement index | `SQL.Home` Statements tab (`%Development`) | `%SQL.Manager.Catalog:StatementIndexAll(filter, maxrows)` | read; clean stale (`$SYSTEM.SQL.Statement.Clean()`) takes nothing | no |
| EX-44 Statement details, frozen plans | `Dialog.SQLStatementDetails` (`%Development`) | `Catalog.GetStatementInfo(hash)`; `$SYSTEM.SQL.Statement` `FreezeStatement`, `UnfreezeStatement`, `ClearStatement`; `UpdateSQLIndex^%SYS.SQLSRV(hash,"")` | freeze, unfreeze, clear statistics, clear error: the hash alone; check frozen may store a flag (inference) | no |
| EX-47 Purge cached queries | `SQL.Home` Actions (`%Development`) | `$SYSTEM.SQL.PurgeQueries` with no qualifier, `table` or `class` | the namespace, a table or one cached query: the target alone | no |
| EX-47 Rebuild indices | `SQL.Home` Actions, Indices tab | `RunTask("RebuildIndices")` → `%SQL.Manager.API.RebuildIndices(class, indices)` | a table resolved to its class, optionally one index; takes an extent lock | yes |
| EX-46 Tune table, tune schema | `SQL.TuneTable`, `Dialog.SQLTuneTables` (`%Development`) | `RunTask("TuneTable")` → `$SYSTEM.SQL.TuneTable`; `ClearTableStats`; `Catalog.SetTableExtentSize`, `SetFieldSelectivity`, `SetMapBlockCount`; `TuneSchema` | the table or schema, plus caller values (extent size, selectivity, outlier, block count, keep-class flag) and, for a schema, a server log-file path; keep-class rewrites the class definition | tune: yes |
| EX-48 Runtime statistics | `QButtons.RuntimeStats`, `RuntimeStatsSettings` (`%Development:USE`) | `$SYSTEM.SQL.SetSQLStats(level, 1, "", terminate)` (system-wide); `%SYS.PTools.StatsSQL:ViewStatsSQL`, `ViewStatsSQLDetails`, `clearStatsSQL` | a system-wide collection level and timeout; a namespace purge; plan-with-stats runs the query | plan: optional |
| EX-49 Index analyzer, advice | `QButtons.IndexAnalyzer` (`%Development:USE`) | `job getAllSQLStmts`, `indexUsage`, `tableScans`, `tempIndices`, `joinIndices`, `outlierIndices` `^%SYS.PTools2`; results in `^%sqlcq($NAMESPACE,"PTools","util")`; reads `%SYS.PTools.UtilSQLAnalysis`; advice: harvest `SqlAdvisor` | each report writes per-namespace result rows; inputs are a schema and three flags | yes |
| EX-50 Alternate show plans | `QButtons.ShowPlanAlt` (`%Development:USE`) | `JobPossiblePlans`; `JobComparePlans` → `ShowPlanAlt^%apiSQL`; `StatsSQL:possiblePlansStats` | the comparison runs the person's statement once per chosen plan (`showstats` 1) | yes |
| EX-51 Generate troubleshooting report | `QButtons.ReportGenerator` (`%Development`) | `%SQL.Manager.QButtons.Base.InsertQuery`, `WriteAllToFile(WRC, file)` | runs the query, stores a row (and optionally results) in `^IRIS.QButtons.BaseD`, writes XML at a caller's server path; the page offers a client `mailto:` to InterSystems support, the server sends nothing | optional |
| EX-52 Import troubleshooting report | `QButtons.ReportLoader` (`%Development`) | `Base.ConsumeReport(file, "ckd", 1, ns)` | a server file path; it loads and compiles the class and INT code the XML carries | no |

Measured: `HSCUSTOM` 974 statements, none frozen, 337 touching 20 relations in `OCUPILOT_KERNEL_STATE` (OcuPilot's own tables, 21 classes); `USER` 25. 402 cached-query classes. 1,485 base tables. `GetSQLStatsFlag()` reads off; `%SYS_PTools.StatsSQL`, the analyzer's two result tables and `QButtons.Base` hold 0 rows. Not in this story's list, and left with no owner here: export/import of frozen plans (EX-45) and query history (EX-43).

**(b) Proposed children.** Six, this story included; numbers by Rule 17's highest-number rule (21.24 is the highest).

| Story | Leaves | Workflow criterion | Size | Needs first |
|---|---|---|---|---|
| **21.6** Statement index and cached-query purge | EX-44 (index, details, freeze, unfreeze, clear statistics, clear error, clean stale), EX-47 purge (namespace, table, one query) | adds the statement index and details reads | 2 reads, about 7 writes | AD records (c1), (c2) |
| **21.25** Index rebuild and tune table | EX-47 rebuild, EX-46 | none (writes only) | about 7 writes | background-job record (c3); AD-51 entry for caller values; the (c2) arm widened to tables and classes |
| **21.26** Runtime statistics | EX-48 | adds the statistics read | 2 reads, 2 writes | AD-51 entry or settings shape for the system-wide level (re-plan) |
| **21.27** Index analyzer and advice | EX-49 | adds the analyzer and advice reads | 6 reports, 1 harvested body | (c3); the advisor's concatenated SQL rewritten bound (AD-21) |
| **21.28** Alternate show plans | EX-50 | adds the plan comparison | 2 reads that run a statement | whether a run per plan is a read (AD-7) or a confirmed run (re-plan) |
| **21.29** Troubleshooting reports | EX-51, EX-52 | none | 2 to 3 writes | owner: the import compiles code from a file; the `mailto:` to the vendor |

The second criterion is split verbatim across 21.6, 21.26, 21.27 and 21.28: each adds its own read to `slowquery`'s steps, and the workflow stays read-only, so `WorkflowCatalog:117` stands.

**(c) AD records the kept part and its children need** (proposed text; the runner writes them at the spec gate):

1. **AD-51 named entry for this story (needed by 21.6):** "Story 21.6's case: `SqlPort` answers the statement tools' fresh read through a port-composed `STATEMENT` type, the statement-index row of the target hash in the target namespace (its plan state, frozen-differs flag and plan error; statistics are not in the subject), and calls `$SYSTEM.SQL.Statement` `FreezeStatement`, `UnfreezeStatement`, `ClearStatement`, `Clean` and the clear-error update with the hash alone; it builds `$SYSTEM.SQL.PurgeQueries`' qualifiers from the purge tools' target alone (none for the namespace, `table` for a table, `class` for one cached query) and answers their fresh read through a port-composed `PURGE` type, the target's cached-query count."
2. **AD-10 arm (needed by 21.6, widened by 21.25 and 21.29):** "OcuPilot's own statements, through the SQL tuning track: freezing, unfreezing or clearing the statistics or plan error of a statement any of whose `STATEMENT_RELATIONS` lies in an `OcuPilot` schema, read at the write (a failed read refuses), is refused `PROHIBITED.OCUPILOTSQL` from either caller. A cached-query purge is not refused: it costs a re-prepare, as Story 21.4's all-namespace purge does." The children would add rebuilding indices of, or tuning, a table in an `OcuPilot` schema (21.25; keep-class rewrites OcuPilot's own class definitions, the `OCUPILOTCODE` family) and importing a report that carries an `OcuPilot` document (21.29, `PROHIBITED.OCUPILOTCODE`).
3. **Background work (21.25, 21.27, 21.28):** the classic page hands rebuild, tune and the analyzer to `%CSP.UI.System.BackgroundTask.RunTask`, a detached `Job`. AD-7 says the write runs in the confirm request; the precedent is the admin API's async task rows (Story 18.4, `AdminPort.cls:76-78`). Each child's plan decides between a synchronous call in the confirm and an AD-7 named case, measured first.

**Decided in-stage:**

- The workflow gains reads only, as above.
- The kept part groups by backing shape: the hash-keyed statement actions and the target-keyed purges share one port and one fresh-read pattern; rebuild joins tune because both are table maintenance through a background job.
- The purge reuses Story 21.4's seam by giving `ConfigPort.PurgeCachedQueries` a qualifiers argument that defaults to `{"allNamespace":1}`, called from the SQL slice's own gate; the 21.4 caller and its test seam are unchanged (Rule 2/31).
- The namespace-wide statement index extends `AtelierPort`'s per-table statement query rather than adding a `%SQL.Manager.Catalog` read beside it (Rule 2/31).

**Strings, escalated for the spec gate's ruling** (the re-plan lists them in full): a listed screen title for the statement index, a statement details title, the actions "Freeze plan", "Unfreeze plan", "Clear statistics", "Clear plan error", "Clean stale statements", "Purge cached queries", their consequence and empty-state sentences, and the refusal sentence for arm (c2). Reused: "SQL statements", "Cached queries", "Plan state", "Statement", the statistics note.

**Integration ACs:** no service is introduced in this pass. **Consumed-by:** 21.25 to 21.28 extend this story's port endpoint and the workflow entry. **Consumes:** Story 19.6's `SqlPort`, Story 19.14's catalog tabs, Story 21.4's purge seam, Story 20.12's workflow catalog.

**Ledger inbox:** none (`LEDGER slice 21-6-the-sql-tuning-track` empty).

**Contended paths (Epic 24 on slot B).** `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp` shows no commit on `SqlPort.cls`, `AtelierPort.cls`, `ConfigPort.cls`, `HarvestPort.cls`, `Workflow.cls`, `Kernel/EntityType.cls`, `Screen/Titles.cls`, the `ExplorerSql*` descriptors, `WorkflowCatalog.cls` or `suggested-prompts.test.mjs`. It has commits on `Kernel/Governance/Baseline.cls` (2), `Kernel/Proposal/Prohibited.cls` (2), `Screen/Tool` (3, its own new files), `shell/screen-outlet.ts`, `shell/screen-action-handler.ts`, `core/screen-actions.ts`, `core/proposal-view.ts`, `core/strings.ts`, `core/screens.generated.ts`, `EXPERIENCE.md` (2 each) and `scripts/ci-throwaway.sh` (3), so edits there are add-only rows. Its worktree also has uncommitted edits to `Test/ReadTool.cls`, `ToolEmit.cls` and `ToolRoundTrip.cls`, whose count literals this story's tools also change (a union at integrate forward). System Explorer's side bar holds Epic 24's code-metrics and document-hashes (13, 14) and will hold Story 21.5's Globals list, so the statement index's position is chosen at re-plan from both branches. `OCU-1-epic22` has no remote branch and its worktree is clean.

## Verification

**Shared surfaces:** none in this pass. For the re-plan of the kept part, all `(loop)`: System Explorer's route roster and positions (`Navigation`, `ui/tools/navigation.test.mjs:350-395`, `Descriptor:175-176`, `ExplorerDescriptor:23,62,161-171,340-357`, `screen-mirror.test.mjs:247-254,997-1049`), the tool registry (`ReadTool:93-94`, `ReadDescriptions:39,279`, `ToolEmit`, `ToolRoundTrip`, `ToolWrite`, `StageTwoTools:180,196`, `DeveloperFloor`, `SurfaceCoverage:182,449`), entity types (`Descriptor:1834`, `Prohibited`'s covered types), governance (`Governance:33`, `GovernanceBaseline:15`), `EndpointCoverage:257-267`, `PortGate:29`, `ClassicPageGate:409-420`, `SqlPort:21`, the workflow pins (`WorkflowCatalog`, `screen-mirror.test.mjs:916`, `suggested-prompts.test.mjs`), and `ConfigGateSeam` with `SqlSettingWrite` for the widened purge seam.
*Every test added or changed passes on a fresh environment, in either order.*

**Runner ruling at the plan halt (2026-11-16, unattended):** split as proposed (decide; 5 of 6 children: 21.25 to 21.29 in `epics.md`). This story keeps the statement index and the cached-query purge. Records (c1) and (c2) need an owner answer and are asked of the orchestrator; the re-plan for the narrowed story waits for it. EX-45 and EX-43 are ledgered for the epic-close sheet.

**Owner answer U-76 (2026-11-16, "A: allow both (Recommended)"):** records (c1) and (c2) are written into the spine as proposed. The re-plan for the narrowed story builds the statement actions and the purges.

## Auto Run Result

Status: blocked
Blocking condition: intent gap: too large -- split 21.6 into six stories (21.6 statement index and cached-query purge; 21.25 index rebuild and tune table; 21.26 runtime statistics; 21.27 index analyzer and advice; 21.28 alternate show plans; 21.29 troubleshooting reports, owner-gated: the import compiles code from a file and the page mails the vendor); the kept part also needs an AD-51 named entry and an AD-10 arm for OcuPilot's own statements, with proposed text in Design Notes (c1, c2); 10 leaves inventoried on ocupilot; workflow stays read-only and its criterion is split across 21.6, 21.26, 21.27 and 21.28.
