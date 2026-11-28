---
title: 'Story 21.6: The SQL tuning track'
type: 'feature'
created: '2026-11-15'
status: 'done'
baseline_revision: '53619019bf2635717f16ab8ca38d45c8af15585c'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      ConfigPort.PurgeCachedQueries's no-qualifier default (the all-namespace purge Story 21.4's setting writes owe) is pinned by no test, and its all-namespace effect was not observed on the throwaway.
    evidence: |-
      The ConfigGateSeam override replaces the whole method, so no test runs the production fallback. Measured on ocupilot-ci 2026-11-22: a purge of {"allNamespace":1} run in HSCUSTOM or USER removed only that namespace's probe cached queries, and the other namespace's stayed for 30 s, the same as {} (inference: this build's all-namespace purge does not reach the other namespace's probe queries; settle it by reading PurgeAllNamespaces^%SYS.SQLSRV or purging with a second namespace's non-probe queries).
    location: >-
      src/OcuPilot/Port/ConfigPort.cls PurgeCachedQueries
    severity: medium
---

<intent-contract>

## Intent

**Problem:** System Explorer reads a table's SQL statements and cached queries but cannot show the namespace's statement index or act on it. Freezing or unfreezing a plan, clearing a statement's statistics or plan error, cleaning stale statements and purging cached queries all still need the classic SQL page, and the `slowquery` workflow cannot read the index.

**Approach:** Add a namespace-wide SQL statements list over the statement index, extending `AtelierPort`'s per-table statement query. Its rows carry each statement's details, and its actions are freeze, unfreeze, clear statistics, clear plan error and clean stale. Add purges for one cached query, a table's cached queries and the namespace's, which reuse Story 21.4's `ConfigPort.PurgeCachedQueries` with a qualifiers argument. Every write goes through `SqlPort`, as AD-51's Story 21.6 case and AD-10's tuning-track arm say. `slowquery` gains the statement index read and stays read-only.

## Boundaries & Constraints

**Always:**

- Every write is one operation reached by two callers, the screen action and the agent's confirmed proposal (AD-53). It runs in the confirm request, the vendor call is made with the hash or target alone, and nothing is ever concatenated into SQL (AD-21).
- The four statement writes on a statement any of whose relations lies in an `OcuPilot` schema are refused `PROHIBITED.OCUPILOTSQL` from either caller, before any write. The relations are read at the write, and a failed read refuses. A purge is never refused by this arm.
- Every test that freezes, clears or purges creates its own probe table and statements, restores what it changed through the same path that changed it, and purges its probe table's cached queries before it drops the table. It never asserts that a store is empty.

**Never:**

- No index rebuild, tune table, runtime statistics, index analyzer, alternate plans or troubleshooting report. Those are Stories 21.25 to 21.29.
- No export or import of frozen plans, no check-frozen action, and no statement plan text in a row.
- No write tool in `slowquery`.
- No new AD text. No test runs on `ocupilot` or a slot instance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | The namespace's statement index, a probe statement among it | The person's list and `explorer.sqlstatements.read` answer the same capped rows. Each row carries its hash, text (credentials masked), tables, plan state, new plan, plan error, timestamp, version, executions, times, row count and locations | Truncation is reported (AD-36) |
| Freeze | An unfrozen probe statement | The plan state reads `Frozen/Explicit` after confirm. Read-back `nothingSent` | Already frozen: precondition refusal before any write |
| Unfreeze | A frozen probe statement | Reads `Unfrozen` after confirm | Not frozen: precondition refusal |
| Clear statistics | A probe statement with executions | Its executions read blank after confirm. Its plan state is unchanged | none |
| Clear plan error | A probe statement with a plan error the test set | Its plan error reads blank after confirm | No plan error: precondition refusal |
| Clean stale | The namespace's index holding the test's own stale statement | That statement is gone after confirm, and a statement that still has a location stays | Nothing stale: precondition refusal |
| Purge one query | A probe cached query on the Cached queries tab | That class is gone after confirm, and the table's other cached query stays | Absent class: 404 `PORT.NOTFOUND` |
| Purge a table's | Two probe cached queries on a probe table | Both are gone. Another table's cached query stays | Unknown table: 404, as the tab's own read |
| Purge the namespace's | A probe cached query in the namespace | It is gone after confirm (armed) | none |
| Own statement | A statement over `OcuPilot_Kernel_State` | Freeze, unfreeze, clear statistics and clear plan error are refused `PROHIBITED.OCUPILOTSQL` from both callers, and the statement is unchanged | A failed relations read refuses |
| Changed target | The statement was frozen after the proposal was minted | Confirm refuses `PROPOSAL.TARGETCHANGED`, and nothing is written | none |
| Gate | A caller without `%Development:USE`, or, for a write, without WRITE on the namespace's routines database | 403 naming the pair, before any read or write | none |
| Hostile id | A hash with a character outside base64, over 64 characters, or empty | 400 `PORT.VALIDATION`, before any statement | none |
| Vendor refusal | The vendor answers an error status, for example a freeze over an external table | 409 `SQL.STATEMENT.VENDOR`, the vendor's message in `detail` only, never logged | none |
| Workflow | A `slowquery` turn | The workflow names `explorer.sqlstatements.read` among its reads and names no write | none |

</intent-contract>

## Code Map

- **Classic sources (read-only):**
  - `irislib/%CSP/UI/Portal/Dialog/SQLStatementDetails.cls`: freeze :354, unfreeze :397, clear statistics :444, clear plan error :624, all `%Development`.
  - `irislib/%CSP/UI/Portal/SQL/Home.cls`: statement index :1059-1071 (`%SQL.Manager.Catalog:StatementIndexAll`), clean stale :1115-1119, purge :3740-3761.
  - `irislib/%SYSTEM/SQL/Statement.cls` and `irislib/%SYSTEM/SQL.cls:1870`.
- `src/OcuPilot/Port/AtelierPort.cls` -- the read to extend:
  - `CATALOGSTATEMENTSQUERY` :218 and `CATALOGSTATEMENTSCOLUMNS` :261 (with the `sqltext` kind);
  - endpoints :107-150; `CATALOGTABS` :154;
  - `CatalogRows` :1294 (the `tKind = ""` branch binds the system flag; the new endpoint binds none), `CatalogQuery` :1390, `CatalogRelation` :1445 and `CatalogResolve`;
  - `Pairs` :755, `NamespacePairs` :767, `WritePairs` :788.
- `src/OcuPilot/Port/SqlPort.cls` -- the port to extend: header :1-41 ("one endpoint", to update), `COMPOSEDTYPES` :54, `Invoke` :658 (served test :665, `sql` id check :670), `SnippetForm` :736, `Snippet` :748, `Gate` :779, `Refuse`/`Fail` :1211/:1222, `Literal` :1232.
- `src/OcuPilot/Port/ConfigPort.cls` -- `PurgeAfterSet` :912 and `PurgeSteps` :937 (Story 21.4's callers, unchanged), `PurgeCachedQueries` :946. The seam is `Test/ConfigGateSeam.cls:218`.
- **Tool siblings:**
  - `Screen/Tool/Write.cls` (`DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `STATEFIELD` :75, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CLASSICPAGES` :124, `SCREENACTIONS` :167, `READANSWERS` :201);
  - `TaskResume.cls` (precondition and `StateDiff` :173);
  - `DatabaseAction.cls` (abstract action family);
  - `DdlMappingDelete.cls` (`CONSEQUENCECODE` :37, `Consequence` :86).
- **Kernel:**
  - `Kernel/Proposal/Operation.cls` (`TargetRefOf` :67 -- the target type is the descriptor's primary type; `ReadTarget` :352, `ApplyAt` :473);
  - `Mint.cls` (`StateDiff` :247, no-body :264-267);
  - `Prohibited.cls` (`COVEREDTYPES` :282, `OCUPILOTSQL` :861/:866, `Prohibits` :1515, branch list :1526, target read :1631, `SqlStatement` :2818, `IsOcuPilotCode` :2957, `ReviewedFewOnly` :4518, `Target` :5638);
  - `Kernel/EntityType.cls` `TYPES` :138, `Kernel/EntityRef.cls` `IDRULES` :59;
  - `Kernel/Governance/Baseline.cls` explorer keys :204-219;
  - `Kernel/Agent/Workflow.cls` `slowquery` :261-267.
- **Screen:**
  - `Screen/Read.cls:574` already dispatches any `atelier` endpoint, so it needs no change;
  - `Screen/Descriptor/ExplorerSqlCachedQueries.cls`, `ExplorerDocDbList.cls` (a `list` with row actions), `InteropItemQueueTab.cls` (a tab with a row action);
  - `Api/Router.cls:147-150`, the generic screen action route, so no route row is added.
- **Client:**
  - `ui/src/app/areas/os-management/backup-task-list.page.ts` (page-registered actions with `startFor`);
  - `shell/screen-action-handler.ts` (`SCREEN_ACTION_DESCRIPTORS` :70, `UNDRAWN_ACTIONS` :462, `WARNING_CONSEQUENCES` :814, `startFor` :1332);
  - `shell/screen-outlet.ts` (`DESCRIPTOR_PAGES` :165), `shell/detail-page.ts`, `shell/list-page.ts`;
  - `core/screen-actions.ts` (:104, :120, :170), `core/proposal-view.ts` (:152-413, :474).
- **Fixtures and tests to follow:**
  - `Test/ExplorerSqlProbe.cls` (`Make`/`Remove`, the browser spec's fixture model);
  - `Test/SqlSettingWrite.cls` (an armed purge test that counts only its own class);
  - `ui/browser/system-explorer-sql.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:**

**Task 0** runs on `ocupilot-ci` before any code (Design Notes). A measured need for a pair beyond `AtelierPort.WritePairs`, or a vendor call that cannot be made without device output, is a HALT `intent gap` naming it.

**Batch 1, server.** Commit when its `(loop)` commands are green.

- `src/OcuPilot/Port/AtelierPort.cls` -- add `Catalog.Statements`: no criterion, `CATALOGSTATEMENTINDEXQUERY` bound `NULL, NULL` and capped by `maxRows`, and its column map `Hash`, `Statement:sqltext`, `Tables`, `PlanState`, `NewPlan:flag`, `PlanError`, `PlanSaved` (`Timestamp`), `PlanVersion` (`Version`), then the tab's statistics columns `Executions` to `Commands` as `number`, then `FirstSeen` and `Location`. Its `CatalogRows` branch binds no table. Tables are `LIST(DISTINCT r.Relation)`. The text is cut as the tab cuts it. It reads the information schema only, and selects no user, client or call stack -- the namespace-wide list the slow-query workflow and the new screen read.
- `src/OcuPilot/Port/ConfigPort.cls` and `src/OcuPilot/Test/ConfigGateSeam.cls` -- `PurgeCachedQueries(pQualifiers As %DynamicObject = "")`: `""` means `{"allNamespace":1}`. The seam records the qualifiers' JSON in `^||OcuPilotConfigPurgeQualifiers` -- one purge, two callers (Rule 2/31).
- `src/OcuPilot/Port/SqlPort.cls` -- add endpoints `Statements` and `CachedQueries`, served in `Invoke` and listed in `COMPOSEDTYPES` (AD-51's Story 21.6 case):
  - `Statements` `STATEMENT` reads a hash's row (`{Hash, PlanState, NewPlan, PlanError, Executions, AverageTime, Tables}`, 404 when absent) or, for the id `*`, `{Statements, Stale}`. The new endpoints take their id from the `id` key. `IDVALUE`'s `sql` check stays on `Sql` and `SqlData`.
  - The writes are `FREEZE`, `UNFREEZE`, `CLEARSTATISTICS`, `CLEARERROR` (`UpdateSQLIndex^%SYS.SQLSRV(hash,"")`) and `CLEAN`.
  - `CachedQueries` `PURGE` reads `{Target, Kind, CachedQueries}` for three ids:
    - `*`, the namespace's;
    - a table, resolved through the caller's own information schema as `BrowsePlan` resolves one, 404 otherwise;
    - one class `%sqlcq.<the target namespace>.cls<n>`, 404 when absent, and 400 for another namespace's.
    The count is the distinct `%sqlcq.` locations in `STATEMENT_LOCATIONS` for the target, the table's joined through `STATEMENT_RELATIONS` on `CatalogRelation`. Task 0 (c) confirms that a purge leaves it 0.
  - `PURGEQUERIES` builds the qualifiers from the target alone (`{}`, `{"table":[..]}`, `{"class":[..]}`) and calls `ConfigPort.PurgeCachedQueries` in the namespace.
  - Reads pass `Gate`; writes also pass `AtelierPort.WritePairs`. The hash shape is `^[A-Za-z0-9+/=]{1,64}$`, else 400 `PORT.VALIDATION`. The namespace is switched by save and restore, with the restore first in each `Catch`.
  - The five statement calls go through one overridable seam, `StatementCall(pType, pHash)`, which a fixture subclass overrides to feed an error status. Production overrides none. A vendor error status is 409 `SQL.STATEMENT.VENDOR`, its message in `detail` and never logged.
  - `SnippetForm` and `Snippet` render each write as its one vendor call (AD-59).
- `src/OcuPilot/Api/AtelierError.cls` -- `SQL.STATEMENT.VENDOR`, its ruled sentence, the four precondition sentences and the consequence codes `SQL.STATEMENT.FREEZE`, `.UNFREEZE`, `.CLEARSTATISTICS`, `.CLEARERROR`, `.CLEAN` and `SQL.CACHEDQUERY.PURGE` (add-only).
- `src/OcuPilot/Screen/Tool/SqlStatementAction.cls` (new, abstract) -- `PORTCLASS` `SqlPort`, `READTYPE` `STATEMENT`, `SENDSBODY` 0, `FINGERPRINTSUBJECT` `PlanState,NewPlan,PlanError`, `CLASSICPAGES` `%CSP.UI.Portal.SQL.Home`, `WRITERESOURCE` `%Development`. `StateDiff` gives one state row from the fresh read and refuses an unmet precondition with its sentence.
- Its subclasses (new): `ExplorerSqlStatementFreeze` (`explorer.sqlstatements.freeze`, precondition `PlanState` unfrozen), `ExplorerSqlStatementUnfreeze` (`explorer.sqlstatements.unfreeze`, frozen), `ExplorerSqlStatementClearStatistics` (`explorer.sqlstatements.clearstatistics`, state row `Executions`), `ExplorerSqlStatementClearError` (`explorer.sqlstatements.clearerror`, `PlanError` set), and `ExplorerSqlStatementClean` (`explorer.sqlstatements.clean`, id `*` only, subject and precondition `Stale`). Each declares `DESCRIPTORCLASS` `ExplorerSqlStatementList` and `CONSEQUENCECODE`. Each id other than a hash, or other than `*` for clean, is refused at `ArgumentProblem`.
- `src/OcuPilot/Screen/Tool/SqlCachedQueryPurge.cls` (new, abstract) -- `READTYPE` `PURGE`, `WRITETYPE` `PURGEQUERIES`, subject `CachedQueries`, and the state row `CachedQueries` -> `0`. Its subclasses: `ExplorerSqlCachedQueryPurge` (`explorer.sqlcachedqueries.purge`, id one class), `ExplorerSqlCachedQueryPurgeTable` (`explorer.sqlcachedqueries.purgetable`, id `Schema.Table`) and `ExplorerSqlCachedQueryPurgeNamespace` (`explorer.sqlcachedqueries.purgenamespace`, id `*`). Each declares `DESCRIPTORCLASS` `ExplorerSqlCachedQueries`, and an id whose shape is not the tool's is refused at `ArgumentProblem`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only) -- `statement-index-entry` and `cached-query` join `COVEREDTYPES`, the `TYPE*` parameters and the branch list at `:1526`. The four statement tools on a `statement-index-entry` read `STATEMENT` through the generic target read (`:1631`, the tool's port), then refuse `OCUPILOTSQL` when any `Tables` entry's schema `IsOcuPilotCode`; a failed or absent read refuses. Clean and the purges have no predicate. Add the `PermittedChangeFields` entries the `ReviewedFewOnly` fall-through needs (`:4518`, as the lock arm does).
- `src/OcuPilot/Kernel/EntityType.cls` -- the two types and their doc lines. Neither has an `IDRULES` row.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only) -- the eight keys, valued as Design Notes says.
- `src/OcuPilot/Screen/Descriptor/ExplorerSqlStatementList.cls` (new, modeled on `ExplorerDocDbList`) -- route `system-explorer/sql-statements`, the position Design Notes names, archetype `list`, entity `statement-index-entry`, scope `namespace`, id `Hash`, source `{port: "atelier", endpoint: "Catalog.Statements", type: "LIST"}`, `toolIdentifier` `explorer.sqlstatements`, `classicPage` `%CSP.UI.Portal.SQL.Home`, `%Development:USE`, the note `explorerSqlStatementsNote`, and row actions `freeze`, `unfreeze`, `clear-statistics`, `clear-error` and `clean`. No refresh.
- `src/OcuPilot/Screen/Descriptor/ExplorerSqlCachedQueries.cls` -- `entityType` `cached-query`, and row actions `purge`, `purge-table` and `purge-namespace`. A purge row's id is its `CachedQuery`, keyed as `InteropItemQueueTab` keys its abort rows.
- `src/OcuPilot/Kernel/Agent/Workflow.cls` -- `slowquery` gains, after its first step, the read step whose text Design Notes escalates, reading `explorer.sqlstatements.read`.
- `src/OcuPilot/Test/SqlTuningProbe.cls` (new fixture) -- `Make(ns)` and `Remove(ns)`. It makes the probe table `OcuProbe216.T<n>`, its second table, two cached queries on the first and one on the second, a stale statement (a prepared query whose cached query it purged, Task 0 (b)) and a plan error (Task 0 (d)). The browser spec refuses the live container, as it does for `ExplorerSqlProbe`. `Remove` unfreezes and clears the plan error through the same vendor calls, purges both tables' cached queries, then drops them.
- Tests (new):
  - `src/OcuPilot/Test/SqlStatementRead.cls` (live-safe) -- the list against a direct bound `SELECT`, the agent read equal to the screen read, credential masking, the `STATEMENT` and `PURGE` shapes, not found, every hostile id, and the gates.
  - `src/OcuPilot/Test/SqlStatementWrite.cls` (live-safe) -- the four statement writes on both callers, preconditions, target changed, the vendor refusal (seam), and the own-statement refusal on both callers before any write.
  - `src/OcuPilot/Test/SqlCachedQueryPurge.cls` (live-safe) -- one query and a table's, on both callers, others surviving, each id shape refused on the wrong tool.
  - `src/OcuPilot/Test/SqlTuningWrite.cls` (armed) -- the namespace purge and clean on both callers, each asserting on its own probe objects.
  Each class calls `SqlTuningProbe.Remove` in `OnAfterOneTest`.
- `scripts/ci-throwaway.sh` -- a new `# classes: SqlTuningWrite` line under `OCUPILOT_ALLOW_CONFIG_SETTINGS` (add-only).
- Every shared-surface test under Verification is updated to the new shape.

**Batch 2, client.** Commit when its `(loop)` commands are green.

- `ui/src/app/areas/system-explorer/sql-statement-list.page.ts` and `sql-cached-queries.page.ts`, each with a spec (new) -- `BackupTaskListPage`'s shape. The first wraps `ListPage` and registers Clean stale on `*`. The second wraps `DetailPage` and registers purge-table on the route's table and purge-namespace on `*`. Both use `handler.startFor`. `shell/screen-outlet.ts` gets two `DESCRIPTOR_PAGES` rows.
- `shell/screen-action-handler.ts` (add-only) -- both descriptors join `SCREEN_ACTION_DESCRIPTORS`, the three page actions join `UNDRAWN_ACTIONS`, and each action's warning goes in `WARNING_CONSEQUENCES`. `core/screen-actions.ts` gets the labels. `core/proposal-view.ts` gets the consequence codes. `core/strings.ts` gets the ruled strings. `core/screens.generated.ts` and `Screen/Titles.cls` are regenerated (`node tools/screen-mirror.mjs`).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings (add-only).
- `ui/browser/system-explorer-sql-statements.browser-spec.mjs` (new) -- `SqlTuningProbe` before and after. Each step waits for the answered signal. The list shows the probe statement; Freeze asks and confirms, and the row reads `Frozen/Explicit`; Unfreeze restores it through the same action; Clear plan error removes the fixture's error; on the probe table's Cached queries tab, Purge removes one row and the other stays. An own statement's Freeze shows the refusal sentence and changes nothing. The `after` hook purges the probe tables' cached queries before dropping them (the Story 21.24 lesson).

**Acceptance Criteria:**

- AC1. Given a namespace holding the probe statement, when the person opens SQL statements and the agent calls `explorer.sqlstatements.read`, then both answer the same capped rows. The probe's row carries its hash, masked text, tables, plan state, new plan, plan error, plan time, version and statistics.
- AC2. Given the probe statement, when the person or the agent freezes it and then unfreezes it, then each is confirmed before it runs, the row reads `Frozen/Explicit` and then `Unfrozen`, and a second freeze is refused before any write.
- AC3. Given the probe's statistics, its plan error and a stale probe statement, when clear statistics, clear plan error and clean are confirmed, then the statistics and the error read blank, the stale statement is gone, and a statement with a location stays.
- AC4. Given probe cached queries on two tables, when one query, one table's or the namespace's queries are purged and confirmed, then exactly the target's queries are gone, and the screen re-reads on the change event.
- AC5. Given a statement over `OcuPilot_Kernel_State`, when either caller freezes, unfreezes, clears its statistics or clears its plan error, then it is refused `PROHIBITED.OCUPILOTSQL` with its published sentence before any write, and a purge of that table's queries is not refused.
- AC6. Given the `slowquery` workflow, when a turn follows it, then its steps name `explorer.sqlstatements.read` and no write tool, and it is still offered on the SQL query screen alone.
- AC7. Given the throwaway, when the browser spec runs forward and in reverse with any other spec file, then it passes, and it leaves no frozen plan, plan error or probe cached query behind.

### Review Findings

- [x] [Review][HIGH] DW-2844, ruled in-story (Spec Change Log, second 2026-11-22 entry; veto U-144): the parallel-plan Freeze refusal on its own branch, Freeze's description refusal sentence, Clean's description sentence and Clean's consequence sentence, each verbatim as ruled; pinned (parallel-plan probe if the throwaway can make one, otherwise at the seam, said which), with a `mutation:` line; every consumer of the changed codes and strings grepped and run. Closed in rework 1: see `## Auto Run Result`.

Code review, 2026-11-22 (four layers, full-opus). Each entry: severity, fix-risk, footprint in-story.

- [x] [Review][Patch] high, fix-risk low: `SqlPort.Applied` called `StatementCall`, an OcuPilot method, while switched to the target namespace, against AD-16 and AD-61 rule 4 (it worked only because the call stays inside loaded routines). `StatementCall` now takes the namespace and switches around the vendor call alone [src/OcuPilot/Port/SqlPort.cls StatementCall, Applied; Test/SqlTuningPortFixture.cls]
- [x] [Review][Patch] medium, fix-risk low: the 404 of an absent hash or cached-query class stated the table sentence. It now states the ruled sentences (U-143), in `AtelierError`, `strings.ts`, the `self-protection.test.mjs` pin and EXPERIENCE.md. The hash sentence drops "that this account can see": a principal refused SELECT on the probe table (-99) read the statement and its relations, on `ocupilot-ci` [src/OcuPilot/Port/SqlPort.cls StatementRead, PurgeTarget]
- [x] [Review][Patch] medium, fix-risk low: the stale count counted frozen statements that no class holds, which the vendor's clean keeps (measured on `ocupilot-ci`), so a clean could leave `Stale` above 0 and the "nothing stale" refusal never fire. `STALECOUNTQUERY` leaves out frozen plans, and the clean's description says so [src/OcuPilot/Port/SqlPort.cls STALECOUNTQUERY; Screen/Tool/ExplorerSqlStatementClean.cls]
- [x] [Review][Patch] medium, fix-risk low: the screen's Clear statistics assertion could not fail, because `SetStatistics` wrote the statistics in the test's namespace, not the probe's. It now takes the namespace, and the test asserts that the statistics read 3 before the screen's clear [src/OcuPilot/Test/SqlTuningProbe.cls SetStatistics; Test/SqlStatementWrite.cls]
- [x] [Review][Patch] medium, fix-risk low: the own-statement test's clear-statistics case expected blank statistics, so "unchanged" could not fail and depended on the instance's statistics schedule. `RemoveOwn` clears the statistics, and that case sets them first [src/OcuPilot/Test/SqlStatementWrite.cls; Test/SqlTuningProbe.cls RemoveOwn]
- [x] [Review][Patch] low: no test read the copy-out script of the tuning writes (AD-59). `SqlStatementRead.TestEachWritesScriptIsItsOneVendorCall` reads all eight [src/OcuPilot/Test/SqlStatementRead.cls]
- [x] [Review][Patch] low: the gate test's refused purge never checked the table's cached query. It now does [src/OcuPilot/Test/SqlStatementRead.cls]
- [x] [Review][Patch] low: the statement-index guard was narrowed to `SQL_MANAGER.STATEMENTINDEX` and missed the class-query form. It now checks both [src/OcuPilot/Test/AtelierPortCatalogTabs.cls]
- [x] [Review][Patch] low: `WRITERESOURCE`'s comment said every vendor call checks `%Development`, which clean and the plan-error update do not [src/OcuPilot/Screen/Tool/SqlStatementAction.cls]
- [x] [Review][Patch] low: stale prose in tests: `DeveloperFloor`'s write list and message omitted the eight writes, and `ExplorerDescriptor` had a typo [src/OcuPilot/Test/DeveloperFloor.cls; Test/ExplorerDescriptor.cls]
- [x] [Review][Defer] low: two ruled strings claim more than the instance does. Freeze refuses an Unfrozen/Parallel plan as "already frozen", and Clean's consequence omits that frozen statements stay — deferred: DW-2844, decision-pending, a string ruling
- [x] [Review][Defer] low: the failed purge (500) and the vendor refusal (409) are pinned at the port only — deferred: DW-2845, wontfix-accepted

Rejected:

- medium, by-design: the three page actions need a selected row, so an empty Cached queries tab offers no purge. The Spec Change Log accepts it (the backup task list's precedent), and no AC or EXPERIENCE.md row asks for a purge from an empty tab.
- medium, by-design: the armed clean test asserts that `USER`'s index holds nothing stale. The matrix's "Nothing stale" row needs that state, the test's own namespace-wide clean makes it, and the class is armed.
- low, by-design: a 404 relations read is not judged, and another failed read is an error status, which refuses the write. The fingerprint re-read closes a vanished target (Batch 1 decision).
- low, wontfix-theoretical: a statement with no recorded relation, or one held by OcuPilot's code that reads no OcuPilot table, passes the arm. AD-10 keys on `STATEMENT_RELATIONS`. It becomes real if such a statement is shown to change OcuPilot's behavior once frozen.
- low, wontfix-theoretical: a namespace whose name differs from its `%sqlcq` package piece, the bare prefix in the namespace count, a snippet with no namespace key, `PurgeCachedQueries` with a namespace and no qualifiers, a non-object fresh read reaching `StateDiff`, and a purge-table start with no table. Each is unreachable from today's callers.
- low, wontfix-accepted: the table script names the caller's spelling (the purge accepts either case, Task 0 (c)); the 21.6 keys in `strings.ts` carry no EXPERIENCE.md line references; the browser spec's tests share one probe in file order. Reopen if a copied script fails, if the references check covers every key, or if a test run alone goes red.
- low, by-design: the namespace-wide counts are fingerprinted (AD-51's Story 21.6 case), and the clean and plan-error update return no status (Task 0 (d)).
- false: the exact-hash compare cannot be shown to matter. On `ocupilot-slot-a` (read-only), a lowercased hash matched no row, so `Hash` compares exactly.

## Spec Change Log

- 2026-11-22, orchestrator ruling on the implement stage's strings outside the ruled list (code review applies it):
  - Accepted as written: the two empty-state invitation fragments "freeze a statement's plan" and "purge cached queries" (EXPERIENCE.md Fixed-strings row, add-only), the 400's reuse of the generic field-shape sentence, and the eight tool DESCRIPTIONs with their id-shape messages. Each description's factual claims are checked against the instance or source (freeze holds the plan across index and statistics changes until unfrozen; clear statistics leaves the plan unchanged; clean removes only statements no class or routine still holds; `%sqlcq.USER.cls12` is the form the read's CachedQuery column reports); a claim that measures false is corrected in its own sentence.
  - The 404 for an absent id gets its own sentences, not the table sentence: a statement hash "This namespace holds no SQL statement with that hash that this account can see." (the "that this account can see" clause only if the read filters statements by visibility; dropped if not), and a cached-query class "This namespace holds no cached query by that name." Both join EXPERIENCE.md beside the table sentence, add-only.
  - Page actions only on a selected row are accepted (the backup task list's precedent); the agent still offers all three without one.
- 2026-11-22, orchestrator ruling on DW-2844 (in-story, veto U-144), after the code review:
  - Freeze refuses a plan in the Unfrozen/Parallel state on its own branch keyed on the plan state, verbatim "This statement's plan uses parallel processing and cannot be frozen."; "This statement's plan is already frozen." stays for a frozen plan only. Cite the vendor source or the classic dialog's disable condition for the state; pin the branch on a parallel-plan probe if the throwaway can make one, otherwise at the seam, and say which.
  - Freeze's DESCRIPTION refusal sentence becomes, verbatim, "A statement whose plan is already frozen is refused, and so is one whose plan uses parallel processing, and so is a statement over OcuPilot's own tables."
  - Clean's DESCRIPTION gains "A statement whose plan is frozen stays." (measured at review). Clean's consequence sentence becomes "Removes every statement in this namespace's index that no class or routine still holds. A statement whose plan is frozen stays.", keeping any further content the current sentence carries.
  - The table-statistics half of Freeze's claim stays labeled (inference); the sentence is the vendor's documented behavior.

## Review Triage Log

### 2026-11-22 — Review pass

- verdicts: 17 findings — high 0, medium 4, low 10, false 3, maybe-false 0
- findings:
  - `medium` `defer` `ConfigPort.PurgeCachedQueries`'s no-qualifier default is run by no test (the seam replaces the method) — a pin cannot be made falsifiable here: on the throwaway a purge with `{"allNamespace": 1}` run in `HSCUSTOM` or `USER` removed only that namespace's probe cached queries, and another namespace's stayed for 30 s, the same as `{}` (inference: this build's all-namespace purge does not reach the other namespace's probe queries). Pre-existing behavior of Story 21.4's caller; deferred.
  - `medium` `patch` The namespace purge's `{}` scope is never asserted against another namespace — `SqlTuningWrite.TestAnotherNamespacesCachedQueriesSurviveTheNamespacePurge` makes a probe in `HSCUSTOM` and asserts it survives the purge of `USER`; mutation: `Applied` drops the namespace argument -> red.
  - `medium` `patch` Clean stale statements is never shown drawn in the shell — the browser spec's AC1 test now selects the probe row and asserts the command bar offers Freeze plan, Clear statistics and Clean stale statements; mutation: the `DESCRIPTOR_PAGES` row removed -> that test red.
  - `medium` `patch` The clean precondition is refused only inside a conditional assertion — the guard is now an unconditional assertion that the clean left nothing stale, then the screen's and the agent's refusals; mutation: `Holds` admits an empty index -> both red.
  - `low` `patch` AC1 to AC6 carry no `mutation:` result line — the lines are written under `## Verification`, from the observed reds.
  - `low` `patch` AC7's reverse-order run is not recorded — the new spec and `system-explorer-sql.browser-spec.mjs` ran in both orders, each as its own call, green (recorded under Auto Run Result).
  - `low` `reject` A live-safe test leaves the own-table statement's index entry and cached query — only an armed, namespace-wide Clean removes a statement-index entry, and the entry is OcuPilot's own table's; wontfix-accepted, reopen_if the entry is seen to hold a plan state or error after the class runs.
  - `low` `reject` `SqlTuningProbe.SetStatistics` writes the statistics node directly — Task 0 (e) measured that the instance writes statistics on its own schedule and no supported call records them; accepted.
  - `low` `patch` A doc comment in `AtelierPortCatalogTabs` sits above the wrong parameter — moved above `VENDORPROCEDURE`.
  - `low` `reject` The list read assumes the probe falls in the first 1,000 statements of `USER` (inference) — the namespace holds a handful of statements; no reachable failure.
  - `false` `reject` Three unarmed classes change state on probe objects — the spec's live-safe classification and Boundaries ("creates its own probe table and statements, restores what it changed") are met; only the armed class acts namespace-wide.
  - `false` `reject` Clear statistics and clean ship disabled for the agent — the spec's Keys ruling.
  - `false` `reject` The list query is a new sibling rather than the per-table query widened — the spec's Design Notes ("extend, don't copy") name `CATALOGSTATEMENTINDEXQUERY`.
  - `low` `reject` A 404 read of the target is not judged by the own-statement arm, and another failed read is an error status — a refused target-changed confirm closes the race; the Batch 1 decision.
  - `low` `reject` The purge half of AC5 is pinned through `Prohibited.Prohibits` rather than the two callers — the purge tools carry no predicate by design.
  - `low` `reject` The browser spec's AC2 has no second-freeze step — `SqlStatementWrite` pins it on both callers.
  - `low` `reject` The browser spec purges one query; the table and namespace purges are pinned by `SqlCachedQueryPurge` and `SqlTuningWrite` — the three buttons' labels are asserted on the tab.

### 2026-11-22 — Review pass (rework 1, DW-2844 only; the diff is this pass's, not the story's)

- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0; the intent-alignment layer reported no divergence
- findings:
  - `low` `patch` The probe's plan-flag reset in `Remove` has no pin — the new test calls `Remove` and asserts the statement reads `Unfrozen`; mutation: the reset skipped -> red.
  - `low` `patch` No `mutation:` line for the parallel branch or the roster row — written under `## Verification`, each observed red.
  - `low` `reject` Freeze's description omits the external-table refusal the classic dialog also applies — the description is the ruled sentence verbatim, and any freeze the instance refuses answers 409 `SQL.STATEMENT.VENDOR` (pinned by `TestTheInstancesRefusalIsAnsweredWithItsMessageInDetailAlone` with a seam message; the external-table case itself is unmeasured (inference)); wontfix-accepted, reopen_if a freeze over an external table is shown to succeed or to answer anything but that 409.
  - `low` `patch` The Design Notes' string list kept the superseded Clean sentence — replaced in place, and the parallel refusal added to the refusal row.

## Design Notes

**Governing ADs:** AD-51 (its Story 21.6 case: `STATEMENT` and `PURGE` types, the hash or target alone), AD-10 (the tuning-track arm, `PROHIBITED.OCUPILOTSQL`), AD-53, AD-6 and AD-34 (one operation, fingerprint, per-target lock), AD-58 (read-back `nothingSent`), AD-14 (change event), AD-15, AD-21 (bound SQL, no caller path), AD-16 (namespace save and restore), AD-29 and AD-61 (gates), AD-36 (one capped read for screen and tool), AD-5 and AD-44 (descriptor, `%CSP.UI.Portal.SQL.Home`), AD-13 (a hash holds `/`, `+` and `=`), AD-22 (keys), AD-39 (vendor message in the answer only), AD-59 (copy-out script), AD-66 (`slowquery` reads only).

**Runner ruling at the plan halt (2026-11-16, unattended):** split as proposed (decide; 5 of 6 children: 21.25 to 21.29 in `epics.md`). This story keeps the statement index and the cached-query purge. Records (c1) and (c2) need an owner answer and are asked of the orchestrator; the re-plan for the narrowed story waits for it. EX-45 and EX-43 are ledgered for the epic-close sheet.

**Owner answer U-76 (2026-11-16, "A: allow both (Recommended)"):** records (c1) and (c2) are written into the spine as proposed. The re-plan for the narrowed story builds the statement actions and the purges.

**Leaf inventory:** the ten leaves probed on 2026-11-15 are in this spec at commit `26d6bdc39`. Stories 21.25 to 21.29 own the rest.

**Measured read-only on `ocupilot` (`ocupilot-slot-a`, `HSCUSTOM`, 2026-11-15):**

- 988 statements, none frozen and none with a plan error. 592 have no `STATEMENT_LOCATIONS` row. The longest hash is 32 characters.
- Relations are stored upper case (`OCUPILOT_KERNEL_STATE.AGENT`), as `AtelierPort.CatalogRelation` builds them.
- There are 411 `%sqlcq.HSCUSTOM.*` classes and 377 distinct cached-query locations. `%SQL.Manager.Catalog:CachedQueryInfo`'s `Routine` is the class name (`%sqlcq.HSCUSTOM.cls1`), which the Cached queries tab shows as `CachedQuery`.
- `INFORMATION_SCHEMA.STATEMENTS` answers `Hash`, `Frozen`, `FrozenDifferent`, `Error`, `Timestamp`, `Version`, the `Stat*` columns and `Statement`, beside the user, client and call-stack columns, which are never selected.
- The vendor calls are in `irislib/%SYSTEM/SQL/Statement.cls`. `FreezeStatement(hash)` :161, `UnfreezeStatement(hash)` :214 and `ClearStatement(hash)` :63 (statistics) each check `%Development:USE` themselves. `Clean()` :9 checks nothing and calls `CleanSQLIndex^%SYS.SQLSRV(0,1)`. The classic dialog clears a plan error with `UpdateSQLIndex^%SYS.SQLSRV(hash,"")` (`SQLStatementDetails.cls:624-634`). `$SYSTEM.SQL.PurgeQueries` takes `{}` (current namespace), `{"table":[..]}` or `{"class":[..]}` (`SQL.cls:1870-1895`).

**Decided in-stage:**

- **Placement.** The SQL statements list takes the next free System Explorer side-bar position on feature at implement time: 16 if Story 21.5's Globals list (15) has merged, else 15.
  - Its row actions are freeze, unfreeze, clear statistics and clear plan error, which the shell's handler draws.
  - Clean stale is its page's own action on target `*`, undrawn by the handler and registered by the page, as `BackupTaskListPage` registers Freeze writes on `SYSTEM`.
  - The Cached queries tab gains Purge as a row action. Its page's own actions are purge-table (target: the tab's table) and purge-namespace (target `*`), since the classic SQL page offers the namespace purge from any of its pages.
  - The SQL tables list and the per-table Statements tab are unchanged.
- **Entity types (two, new).** A tool's target type is its descriptor's primary type (`Operation.TargetRefOf`), so each screen carries the type its tools write.
  - `statement-index-entry` is one statement in a namespace's index, keyed by its hash and kept exactly, with no `IDRULES` row. `sql-statement` is already a running statement. The id `*` names the whole index, which is clean's target.
  - `cached-query` has three exact id shapes: `*` (the namespace's), `Schema.Table` (a table's) and `%sqlcq.<NS>.cls<n>` (one query). The purge port reads the shape, so the qualifiers come from the target alone.
  - The Cached queries tab's `entityType` moves from `class` to `cached-query`. Otherwise a purge would be judged by the class arm, which runs `Code()` on the id and would refuse a purge of OcuPilot's tables, which AD-10 permits.
- **No route carries a hash.** The list has no detail route, a screen action's id travels in the JSON body, and a proposal's in its arguments. AD-13's codec is not exercised by `+` or `=` (whether its server encode escapes them is unverified).
- **Clean's fresh read.** AD-51's case lists `Clean` among the hash-alone calls, but `Clean` takes nothing. This plan reads its target `*` as the namespace's index. Its `STATEMENT` read answers `{Statements, Stale}`, with `Stale` (the statements with no location, per Task 0 (b)) as its subject and precondition. Flagged below for the gate.
- **The refusal sentence is `OCUPILOTSQLREASON`, reused.** One code carries one sentence (`Prohibited.ReasonFor`). No new refusal string.
- **Keys.** `true` for freeze, unfreeze, clear plan error and the three purges. `false` for clear statistics and clean, because statistics and stale entries do not come back (the key governs the agent only, AD-22). None is destructive (no typed name): a purge costs a re-prepare, and the others change no data.
- **Statement text** is a `sqltext` field, credential-masked like the tab's. The `Plan` and `JSONPlan` columns are not read. The console's Plan answers a statement the person runs, and Story 21.28 owns plan comparison.
- **The purge seam.** `ConfigPort.PurgeCachedQueries(pQualifiers As %DynamicObject = "")`, where `""` means `{"allNamespace":1}`. Story 21.4's caller passes nothing and keeps its behavior. `ConfigGateSeam`'s override takes the same argument and records it. `SqlPort` calls it inside the target namespace, after its own gate.
- **The write pairs** are `AtelierPort.WritePairs(ns)`, `%Development:USE` with READ on the code databases and WRITE on the routines database, which a compile already needs. Task 0 (a) confirms them. A need beyond them is a HALT.
- **The armed class** `SqlTuningWrite` (namespace purge and clean, which act on a whole namespace) joins `OCUPILOT_ALLOW_CONFIG_SETTINGS` with a new `# classes:` line, add-only, beside `SqlSettingWrite`, which already purges every namespace.

**Strings, escalated for the spec gate's ruling** (none is in `EXPERIENCE.md` or a spec yet):

- Reused, with no new string: the list title "SQL statements", the columns "Statement", "Plan state", "New plan", "Executions" and the times, the note `explorerSqlStatementsNote`, and the tab title "Cached queries".
- New columns: "Statement hash" · "Tables" · "Plan error" · "Plan saved" · "Plan version".
- Empty state: "No SQL statements are recorded in this namespace."
- Actions: "Freeze plan" · "Unfreeze plan" · "Clear statistics" · "Clear plan error" · "Clean stale statements" · "Purge" (one query) · "Purge this table's cached queries" · "Purge all cached queries in this namespace".
- Consequences (dialog and card):
  - Freeze: "This statement keeps its current plan until it is unfrozen, even when its indices or table statistics change."
  - Unfreeze: "This statement takes the plan the optimizer chooses the next time it is prepared."
  - Clear statistics: "This statement's run statistics are removed, and counting starts again at its next run."
  - Clear plan error: "The plan error is removed from the statement index. The plan itself is unchanged."
  - Clean: "Removes every statement in this namespace's index that no class or routine still holds. A statement whose plan is frozen stays."
  - Purge: "The purged queries are prepared again the next time each one runs."
- Precondition refusals: "This statement's plan is already frozen." · "This statement's plan uses parallel processing and cannot be frozen." · "This statement's plan is not frozen." · "This statement has no plan error." · "This namespace's statement index holds no stale statements."
- Vendor refusal `SQL.STATEMENT.VENDOR`: "The instance did not apply this change to the statement."
- Three suggested prompts for the list: "Which statements take the longest on average?" · "Is any plan frozen, and does a newer plan exist?" · "Which statements have a plan error?". Command aliases: "statement index" · "frozen plans".
- The `slowquery` step's text: "Read the namespace's statement index for statements with a high average time, a frozen plan that differs from the current one, or a plan error."

**Flagged for the gate (no AD text changed):** the clean-target reading above. If the gate rules otherwise, clean leaves this story, and the rest stands.

**Extend, don't copy (Rule 2/31):**

- The list query extends `AtelierPort.CATALOGSTATEMENTSQUERY`'s columns. The new `CATALOGSTATEMENTINDEXQUERY` binds `(? IS NULL OR s.Hash = ?)`, and `SqlPort`'s `STATEMENT` read uses that same text with the hash bound.
- The tools extend a new abstract `SqlStatementAction`, modeled on `DatabaseAction` with `TaskResume`'s precondition and state row. `SqlCachedQueryPurge` follows it.
- The arm follows `Prohibited.SqlStatement`'s relation test (`IsOcuPilotCode` on each relation's schema), reading `STATEMENT` through the tool's port as the target-reading arms do.
- The purge reuses `ConfigPort.PurgeCachedQueries`. `CatalogRelation` builds the table's relation key.

**Integration ACs:** `SqlPort`'s two new endpoints are consumed in this story by the eight tools through both callers (AC2 to AC5), and the list read by `slowquery` (AC6).

- **Consumed-by:** 21.25 (index rebuild and tune table, on `SqlPort`); 21.26, 21.27 and 21.28 (each adds its own `slowquery` read).
- **Consumes:** Story 19.6's `SqlPort`, Story 19.14's Cached queries tab, Story 21.4's purge seam and Story 20.12's workflow catalog.

**Ledger inbox:** none (`LEDGER slice 21-6-the-sql-tuning-track` is empty). DW-2610 (a cached query class with no index row survives a purge) stays with burndown. The purge sentence above claims only the queries purged.

**Contended paths (Epic 24, slot B), checked 2026-11-15** with `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp` and the merge-base diff:

- Real changes on `EXPERIENCE.md`, `scripts/ci-throwaway.sh`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Read.cls`, `Test/ReadTool.cls`, `ToolEmit.cls`, `ToolRoundTrip.cls`, `core/proposal-view.ts`, `screen-actions.ts`, `screens.generated.ts`, `strings.ts`, `shell/screen-action-handler.ts` and `screen-outlet.ts`. This story's edits there are add-only rows.
- `ConfigPort.cls`, `ConfigGateSeam.cls` and `EntityType.cls` show only a merge of feature, with no diff. `SqlPort.cls`, `AtelierPort.cls`, `Workflow.cls`, `WorkflowCatalog.cls`, `suggested-prompts.test.mjs` and the `ExplorerSql*` descriptors are untouched.
- Epic 24's worktree also holds uncommitted count edits to `ReadTool`, `ToolEmit` and `ToolRoundTrip`, so expect a union at the merge.

**Re-validated at implement, 2026-11-22** (775 commits on HEAD since the plan's base `09c93d033`; no clause of an AC, a ruled string, a code, an AD or the batch plan changed):

- Line numbers in the Code Map have moved and are to be re-found by name: `AtelierPort` (`CATALOGSTATEMENTSQUERY` :228, `CATALOGSTATEMENTSCOLUMNS` :271, `CatalogRows` :1354, `CatalogQuery` :1450, `CatalogResolve` :1474, `CatalogRelation` :1505, `Pairs` :800, `NamespacePairs` :812, `WritePairs` :833), `ConfigPort` (`PurgeAfterSet` :1192, `PurgeSteps` :1217, `PurgeCachedQueries` :1226, still without an argument), `ConfigGateSeam.PurgeCachedQueries` :269, `Prohibited` (`COVEREDTYPES` :320, `OCUPILOTSQL` :1007, `Prohibits` :1747 and its branch list after it). `SqlPort`, `Workflow` and the `ExplorerSql*` descriptors are unchanged since the plan.
- **Placement.** Story 21.5's Globals list is position 15, and Epics 21 and 24 have since taken 16 (`ExplorerNamespaceDiff`), 17 (`ExplorerUnitTests`), 18 (`ExplorerCommand`) and 19 (`ExplorerClassMethod`). The SQL statements list takes the next free position, 20, which is the spec's own rule ("the next free position at implement time").
- `OCUPILOT_ALLOW_CONFIG_SETTINGS`'s `# classes:` line is at `scripts/ci-throwaway.sh:1002` and now lists thirteen classes after `SqlSettingWrite`. `SqlTuningWrite` is added to it. Epic 24's `ConfirmNamespaceRoster` is in HEAD.
- Epic 24 has no commit on any path this story edits for the server classes listed in its footprint check (`git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp` over `SqlPort`, `AtelierPort`, `ConfigPort`, `EntityType`, `Baseline`, `Prohibited`, `Workflow`, `AtelierError`: empty). Its uncommitted edits to `EntityType`, `Baseline` and `Prohibited` stay add-only here.
- The spine's AD-10 and AD-51 entries for Story 21.6 are as the plan cites them (spine :411 and :1267).

**Task 0, measured by the implement stage on `ocupilot-ci` before code** (each restored; record results here; until then each is an inference):

- (a) As a principal holding only `AtelierPort.WritePairs`, freeze, unfreeze, clear statistics, clear plan error, clean and each purge succeed. The same principal without the routines database's WRITE is refused (`<PROTECT>` or a status). Record which.
  - **Measured on `ocupilot-ci`, 2026-11-22.** A user holding one role of exactly the five `WritePairs('HSCUSTOM')` pairs (`%Development:USE`, READ on `%DB_HSCUSTOM`, `%DB_ENSLIB`, `%DB_HSLIB` and `%DB_IRISLIB`, WRITE on `%DB_HSCUSTOM`) froze, unfroze, set and cleared a plan error, cleaned and purged by table, class and namespace, each with its effect read back. The same user without WRITE on `%DB_HSCUSTOM` is refused by neither: the freeze, the unfreeze and the error update answer OK and change nothing, while a purge still takes effect. The pair is therefore the port's gate, and the read-back is what shows a silent no-op. No pair beyond `WritePairs` is needed.
- (b) A probe statement whose cached query is purged has no location, and `Clean()` removes it. Whether `Clean()` removes any statement that still has a location. Its duration on `HSCUSTOM`. Whether `Clean()` or any of the calls writes to the current device (a write would reach the REST answer; if so, the port redirects output).
  - **Measured.** Purging one statement's class leaves its row with no location, and `Clean()` removed it. `Clean()` removed exactly the statements with no location in the namespace (878 to 154, the 724 that had none) and no statement that still had one. It ran in 0.014 s on `HSCUSTOM`. With the current device redirected to a file, `Clean()` wrote 0 bytes. A freeze or unfreeze can drop the statement's location (inference: the vendor purges the cached query when the plan changes); `Clean()` clears the whole namespace's stale rows, not only the caller's.
- (c) `PurgeQueries({"table":["Schema.Table"]})` with the SQL name removes that table's cached queries only, and `{"class":["%sqlcq.<NS>.cls<n>"]}` removes that class only. Whether the table name must be the internal form.
  - **Measured.** `{"table":["OcuProbe216.T1"]}` and `{"table":["OCUPROBE216.T1"]}` each removed all of that table's cached queries and left the other table's; `{"class":["%sqlcq.HSCUSTOM.cls109"]}` removed that class and its statement's location only; `{}` purged the namespace's. After each purge the count of `%sqlcq.` locations for the target read 0. The SQL name works as typed or in upper case; a table whose name holds a dot was not measured (SQL refuses to create one). A cached-query class is not visible to `%Dictionary` and a purge deletes it; its count is read from `STATEMENT_LOCATIONS`, where a location reads `<class>.1`.
- (d) `UpdateSQLIndex^%SYS.SQLSRV(hash, "probe")` sets `Error`, and `UpdateSQLIndex^%SYS.SQLSRV(hash, "")` clears it. That is the plan-error fixture.
  - **Measured.** Both read as stated, from `INFORMATION_SCHEMA.STATEMENTS.Error`. On an absent hash the call answers OK and changes nothing.
- (e) Freeze then unfreeze leaves `Frozen` 0. After `ClearStatement` the `Stat*` columns read empty or 0. Record which, since the read-back row says "blank".
  - **Measured.** `Frozen` reads 1 after a freeze and 0 after the unfreeze. After `ClearStatement` the `Stat*` columns read empty (blank), not 0, and the statement's `stat` node of the statement index is gone. A statement run in a probe session, in a job and over the Atelier route recorded no statistics within the measured forty minutes (inference: the instance writes them on a later schedule), so `SqlTuningProbe` writes the node the instance writes (`SetStatistics`) to give a statement its three runs.

**Decided at implement, 2026-11-22 (Batch 1):**

- Each statement tool's subject and read name `Namespace`, and each purge tool's too, so a confirm reaches the namespace its proposal read (`ConfirmNamespaceRoster`); a tool declares `PRECONDITIONFIELD` (the plan state, the plan error, the stale count or the cached-query count) because the registry refuses a subject without one.
- The tools declare no `CLASSICPAGES`: the descriptor's own classic page already adds its custom resource, and `ToolEmit` holds the pairs to the screen's plus WRITE as an argument pair (`ExplorerSave.CodeWritePairs`).
- `ConfigPort.PurgeCachedQueries` takes a second, optional argument, the namespace it runs in, switched by save and restore around the vendor call alone: OcuPilot's classes are not visible from another namespace, so `SqlPort` cannot call it from inside one.
- The id arguments are `Hash` (the statement tools, `*` for the clean), `CachedQuery`, `Table` and `Target` (`*`).
- A statement the own-statement arm finds absent (404) is not judged: the fingerprint re-read closes the proposal. Any other failed read is an error status, and a read that answers no table list is refused `PROHIBITED.OCUPILOTSQL`.
- `PermittedChangeFields` needs no entry: the state row's label is the tool's `STATEFIELD`, which the sweep skips, so both new types pass the reviewed-few sweep with nothing changed.
- Strings not in the ruled list, taken from existing sentences or written as plain fragments, are listed for the gate in the stage report: the 404 reason for an absent statement or cached-query class (the table sentence), the 400 reason for a hostile id (the generic field-shape sentence), the two empty-state invitations the generator requires of a write-capable list (`explorerSqlStatementListEmptyAgent`, `explorerSqlCachedQueriesEmptyAgent`) and the tools' descriptions and id-shape messages, which only the agent reads.

## Verification

**Shared surfaces, all `(loop)`:**

- System Explorer's side bar and routes: `ExplorerDescriptor` (`:23`, `:44`, `:59-62`, `:161-171`, `:485`), `Navigation`, `ui/tools/navigation.test.mjs:379-398`, and `screen-mirror.test.mjs`'s route rows and catalog roster (`:3180-3200`).
- The tool registry: `ReadTool` (`:93` count, `:94`, `:112`, `:370`), `ReadDescriptions` (`:39`, `:279`), `ToolEmit`, `ToolRoundTrip` (`REFUSEEMPTY` `:102`), `ToolWrite` (`:1326` count), `StageTwoTools` (`Elsewhere`), `DeveloperFloor` (`:42`, `:45`, `:52`), `SurfaceCoverage`, `DraftRegistry` (`SnippetForm` per write type), and `Prohibited`'s composed settable counts (`:438-458`).
- Entity types: `Descriptor:1836` (count), `EntityRef`, and `Prohibited`'s covered-types literal.
- Governance: `Governance:33`, `GovernanceBaseline:15`.
- Gates: `PortGate:29`, `ClassicPageGate`, `SqlPort` (test, `:162-189`).
- The catalog read: `AtelierPortCatalogTabs`, `AtelierPortCatalogTabsLive`, `SqlCredentialMask` (`:155`).
- The purge seam: `ConfigGateSeam`, `SqlSettingRules`, `SqlSettingWrite`.
- The workflow: `WorkflowCatalog` (`:117`), `screen-mirror.test.mjs:916`, `suggested-prompts.test.mjs`.
- The tab's entity type: `system-explorer-sql.browser-spec.mjs`.
- The armed roster: `ci.test.mjs`.

The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each surface, and every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Each runs in its own foreground call with `timeout: 600000`, against `ocupilot-ci` only, and never two test calls in one message. Nothing runs on `ocupilot` or a slot instance.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SqlStatementRead`, one class per call. Then `SqlStatementWrite`, `SqlCachedQueryPurge`, `SqlTuningWrite` (armed), `SqlSettingRules`, `SqlSettingWrite`, `Prohibited`, `PortGate`, `WorkflowCatalog`, `AtelierPortCatalogTabs`, `SqlCredentialMask`, and every shared-surface class above -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/screen-mirror.test.mjs tools/navigation.test.mjs tools/suggested-prompts.test.mjs tools/self-protection.test.mjs tools/proposal-view.test.mjs tools/ci.test.mjs` -- expected: green.
- `(loop)` `cd ui && npm run build`, then `npm run test:components`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-sql-statements.browser-spec.mjs browser/system-explorer-sql.browser-spec.mjs` -- expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep, one class per call, then `smoke.sh --container ocupilot-ci` and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19).** One per AC. Each is applied, observed red and reverted. The tree is then identical by `git status --short` and `git diff --stat`, and the reverted source is reloaded.

- AC1: `CATALOGSTATEMENTINDEXQUERY` drops `s.Error` -> `SqlStatementRead` red. The descriptor drops `Hash` from its fields -> `screen-mirror.test.mjs` red.
- AC2: `FREEZE` calls `UnfreezeStatement` -> `SqlStatementWrite` red. The freeze precondition admits a frozen plan -> its refusal test red.
- AC3: `CLEARSTATISTICS` is a no-op -> `SqlStatementWrite` red. `CLEAN` is a no-op -> `SqlTuningWrite` red.
- AC4: the purge builds `{}` for a table target -> `SqlCachedQueryPurge` red on the other table's surviving query.
- AC5: the arm skips the relations read -> `SqlStatementWrite`'s own-statement test red on both callers. A failed relations read answers permitted -> `Prohibited` red.
- AC6: `slowquery` loses its statement index read -> `WorkflowCatalog` red.
- Observed (Batch 1, each applied on `ocupilot-ci`, reverted, tracked diff identical, source reloaded) and recorded as `mutation:` lines:
  - mutation: AC1, `CATALOGSTATEMENTINDEXQUERY` drops `s.Error AS PLAN_ERROR` -> `SqlStatementRead` red; the descriptor drops `Hash` from its fields -> `screen-mirror.test.mjs` red.
  - mutation: AC2, `FREEZE` calls `UnfreezeStatement` -> `SqlStatementWrite` red; the freeze precondition admits a frozen plan -> its refusal assertions red.
  - mutation: AC3, `CLEARSTATISTICS` a no-op -> `SqlStatementWrite` red; `CLEAN` a no-op -> `SqlTuningWrite` red; `ExplorerSqlStatementClean.Holds` admits an index with nothing stale -> `SqlTuningWrite`'s two refusal assertions red.
  - mutation: AC4, the table target builds `{}` -> `SqlCachedQueryPurge` red; `SqlPort.Applied` calls `PurgeCachedQueries` without the target namespace -> `SqlTuningWrite`'s purge assertions red.
  - mutation: AC5, the arm skips the relations read -> `SqlStatementWrite`'s own-statement test red on both callers; a failed arm-own read answers permitted -> `Prohibited` red (once the test fails only the arm's own read).
  - mutation: AC6, `slowquery` loses the step -> `WorkflowCatalog` red.
  - mutation: AC7 (browser, after rebuild and redeploy), `ExplorerSqlStatementList`'s `DESCRIPTOR_PAGES` row removed -> `system-explorer-sql-statements.browser-spec.mjs`'s AC1 test red on the Clean stale statements button; reverted, rebuilt and redeployed.
- AC7: the list's Freeze row action is removed from the descriptor -> `system-explorer-sql-statements.browser-spec.mjs` red, after rebuild and redeploy.
  - mutation: removed `freeze` from `ExplorerSqlStatementList`'s `rowActions`, regenerated the mirror, rebuilt and redeployed -> the spec's AC2 and AC5 tests red on the wait for the Freeze plan button (the other three green). Reverted, mirror regenerated, rebuilt, redeployed and the source reloaded into `ocupilot-ci` (`LOADERRORS=0`); `git status --short` and the diff identical to before; the spec green again.
- Batch 2's client pins (each applied, observed red, reverted): the pages' `actions.register` calls dropped -> `sql-statement-list.page.spec.ts` and `sql-cached-queries.page.spec.ts` red (2 and 3 tests); the clean sent on another target and the table purge on the namespace target -> both pages' request tests red; `freeze` dropped from `WARNING_CONSEQUENCES` -> the list page's warning tests red; two returns swapped in `consequenceSentence`'s SQL branches -> `proposal-view.test.mjs` red; one character of `sqlStatementRefusalAlreadyFrozen` changed -> `self-protection.test.mjs`'s `ATELIER_REFUSALS` test red.

- Observed at code review (2026-11-22, each applied on `ocupilot-ci`, reverted, tree identical, source reloaded):
  - mutation: follow-up, `SqlTuningWrite` green twice (runs 966, 967). `SqlPort.Applied` purges without the target namespace -> the other-namespace survival test red. `ExplorerSqlStatementClean.Holds` admits an empty index -> both clean refusals red. The browser spec ran green forward and reverse with `system-explorer-sql.browser-spec.mjs`. With the page's clean registration removed, rebuilt and redeployed -> AC1 red alone.
  - mutation: AC3, `STALECOUNTQUERY` counts frozen plans -> `SqlTuningWrite.TestAFrozenStatementNoClassHoldsIsNotStale` red. `CLEARSTATISTICS` a no-op -> `SqlStatementWrite`'s agent and screen assertions red.
  - mutation: AC5, the arm skips clear statistics -> the own-statement test's verdict and both unchanged-state assertions red.
  - mutation: the hash 404 states the table sentence -> `SqlStatementRead` red. One word of `sqlStatementNotFoundReason` changed -> `self-protection.test.mjs` red. `TuningSnippet` renders `UnfreezeStatement` for `FREEZE` -> `SqlStatementRead`'s script test red.

- Observed at rework 1 (2026-11-22, each applied on `ocupilot-ci`, reverted, tree identical, source reloaded):
  - mutation: DW-2844, `ExplorerSqlStatementFreeze.RefusalCode` answers `REFUSALCODE` for every plan -> `SqlStatementWrite.TestAParallelPlanIsRefusedItsOwnSentenceOnBothCallers` red on both sentence assertions (run 1015).
  - mutation: DW-2844, `SqlTuningProbe.Remove` skips the plan-flag reset -> the same test's last assertion red (run 1025).
  - mutation: DW-2844, one word added to `REASONSTATEMENTPARALLEL` -> `self-protection.test.mjs`'s `ATELIER_REFUSALS` test red naming the pair.

**Runner ruling at the spec gate (2026-11-16):** validated. AD-51's Story 21.6 entry is corrected at its origin: `Clean` takes no argument and cleans the namespace's stale entries (the gate's reading of the escalation). The escalated strings and in-stage decisions are kept (veto U-83).

## Auto Run Result

Status: done
Blocking condition: none

**Implemented (2026-11-22).** Task 0's five measurements are recorded in Design Notes. Batch 1 (commit `595d8a352`): `Catalog.Statements`, `SqlPort`'s `Statements` and `CachedQueries` endpoints, eight tools, the own-statement arm, the eight keys, two entity types, the `slowquery` step, the fixture and four test classes, the rosters. Batch 2 (commit `ccab7839b`): the two pages, handler, labels, consequence codes, ruled strings, refusal pins, the Fixed-strings row, and the browser spec. The finalize commit carries the review patches below.

**Review.** 17 findings: 4 medium (3 patched, 1 deferred), 10 low (4 patched, 6 closed), 3 false; the patches are in `## Review Triage Log`. `followup_review_recommended: true`: the three patched mediums (the other-namespace purge probe and the unconditional clean refusal in `SqlTuningWrite`, the Clean button assertion) ran once each on `ocupilot-ci`, and CI's fresh shards are their first fresh-environment run.

**Verified.** Every Batch 1 and Batch 2 `(loop)` and `(once)` line ran green on `ocupilot-ci` (LOADERRORS=0; the classes and node suites in the Batch reports; `npm run test:tools` 2401, `npm run test:components` 3882; both browser specs, forward and in reverse order; `check-objectscript` 0 problems; `lint-docs` clean; initial bundle 2.25 MB). Each Rule 19 mutation is recorded under `## Verification`. The full ObjectScript sweep, the smoke and the fresh check are the runner's.

**For the gate (veto window, strings not in the ruled list).** (1) Two empty-state invitation fragments the descriptor generator requires of a write-capable list: "freeze a statement's plan" and "purge cached queries" (`explorerSqlStatementListEmptyAgent`, `explorerSqlCachedQueriesEmptyAgent`), written into the Fixed-strings row. (2) The 404 reason for an absent statement hash or cached-query class reuses the table sentence ("This namespace holds no table by that name that this account can see."), and the 400 reason for a malformed id reuses the generic field-shape sentence. (3) The eight tools' agent-facing `DESCRIPTION` lines and id-shape messages.

**Residual risks.** The three page actions (clean, purge this table's, purge the namespace's) register under row-action ids, so the command bar draws them only after a row is selected (`BackupTaskListPage`'s behavior; an empty Cached queries tab offers no purge). `ConfigPort.PurgeCachedQueries` gained an optional namespace argument (SqlPort cannot reach OcuPilot's classes from another namespace). The all-namespace purge default is deferred (see `deferred:`).

**Rework 1 (DW-2844, 2026-11-22).** Closed the `[Review][HIGH]` item.

- Changed: Freeze refuses a plan in the `Unfrozen/Parallel` state with its own code `SQL.STATEMENT.PARALLEL` (`AtelierError`), through a new `RefusalCode` hook on `SqlStatementAction` that `ExplorerSqlStatementFreeze` overrides; the already-frozen sentence stays for every other refused plan. Source for the state: the classic dialog's disable condition and button title (`SQLStatementDetails.cls:111`, `:650`, `:739`). Freeze's description and Clean's consequence carry the ruled sentences, in `AtelierError`, `strings.ts` (new key `sqlStatementRefusalParallel`) and the EXPERIENCE.md Fixed-strings row, the replaced sentence in place and the new one added; the `self-protection.test.mjs` roster gains the pair.
- Pinned at the instance's own index, not at a seam, not on an optimizer-made plan: `%PARALLEL` over 8,192 rows read `Unfrozen` on `ocupilot-ci` (probe objects removed, read back absent), so `SqlTuningProbe.SetPlanFlag` writes the plan-state flag into the statement index and `TestAParallelPlanIsRefusedItsOwnSentenceOnBothCallers` drives the real tool and the real fresh read through both callers. The mutation lines are under `## Verification`.
- Verified on `ocupilot-ci`: reload `LOADERRORS=0`; `SqlStatementWrite` (7), `SqlTuningWrite` (4), `SqlStatementRead` (5), `ToolEmit` (11), `ToolRoundTrip` (2), `ConfirmNamespaceRoster` (3) and `SqlCachedQueryPurge` (4) green, one class per call; `npm run test:tools` 2402 and `npm run test:components` 3882 green; `system-explorer-sql-statements.browser-spec.mjs` 5 of 5 after rebuild and redeploy; `check-objectscript` 0 problems, `lint-docs` clean. `ExplorerSqlStatementFreeze` got its final form (a literal code parameter, since a tool cannot name `AtelierError`) after the browser spec and the first runs of `ToolEmit`, `ToolRoundTrip`, `ConfirmNamespaceRoster` and `SqlCachedQueryPurge`; the first three and `SqlStatementWrite`, `SqlTuningWrite` and `SqlStatementRead` were rerun on it, `SqlCachedQueryPurge` and the browser spec were not.
- Review: 4 findings, all low (3 patched, 1 closed `wontfix-accepted`), in `## Review Triage Log`. `followup_review_recommended: false`: no `high` beyond the item was patched.
