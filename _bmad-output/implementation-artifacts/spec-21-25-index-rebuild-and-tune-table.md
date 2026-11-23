---
title: 'Story 21.25: Index rebuild and tune table'
type: 'feature'
created: '2026-11-16'
status: 'in-progress'
baseline_revision: 'b8283da29229ddfb140e5303a9e7e7d04814a9a8'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-6-the-sql-tuning-track.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer shows a table's indices, fields and extent size, but cannot rebuild an index, collect a table's statistics, clear or fix them, or tune a schema. All of that still needs the classic SQL page and its Tune Table window, which hand the work to a detached background job.

**Approach:** Add the classic page's table maintenance as confirmed writes through `SqlPort`, extending Story 21.6's endpoints and its abstract statement action. The writes are rebuild one index or all of a table's, collect statistics, clear fixed statistics, tune a schema, and set the extent size, a field's selectivity and a map's size. Each runs in its confirm or action request, never in a job. A new Field statistics tab is the read the selectivity edit acts on.

## Boundaries & Constraints

**Always:**

- Every write is one operation reached by two callers, the screen action and the agent's confirmed proposal (AD-53). It runs synchronously in the confirm or action request (AD-7). The vendor call takes the target and the tool's declared, shape-checked values alone, and nothing is concatenated into SQL or code (AD-21).
- A write on a table in an `OcuPilot` schema, or whose class name begins with `OcuPilot` in any case, or a schema tune of an `OcuPilot` schema, is refused from either caller before any write. The table is resolved at the write, and a failed resolve refuses.
- Every test makes its own probe schema and tables through Story 21.6's fixture, restores any statistic it changed through the same port call that changed it, and purges its probe tables' cached queries before it drops them (the Story 21.24 lesson). No test asserts that a store is empty.

**Never:**

- No background job, no `%CSP.UI.System.BackgroundTask`, no log file and no caller path. No `RecompileCQ`, `SamplePercent` or histogram edit. No `ClearValues` on a single table's tune; the classic table page sends 0.
- No map-status toggle and no drop item. Neither is in this story's split assignment.
- No new AD text in this stage. No test or write runs on `ocupilot` or a slot instance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Rebuild one | A probe index whose global the test killed | When the confirm answers, a query through that index returns all of the probe's rows. Read-back `nothingSent` | The table's data map: precondition refusal |
| Rebuild all | Two probe indices, both killed | Both answer all rows when the confirm answers | none |
| Collect statistics | A probe table of N rows (N under 1,000) | `ExtentSize` reads N | none |
| Keep class up to date | Collect with `KeepClassUpToDate` 1 | The probe class's storage `ExtentSize` reads N | none |
| Clear fixed statistics | A probe whose fixed extent size the test set | `HasFixedStats` reads 0 | None fixed: precondition refusal |
| Tune schema | A probe schema of two tables | Both tables' `ExtentSize` read their row counts | none |
| Set extent size | `ExtentSize` 5000 | Reads 5000; read-back holds it | Negative, fractional, empty or over 10^12: 400 `PORT.VALIDATION` |
| Set selectivity | A probe field, `Selectivity` `2.5%` | Its fixed selectivity reads `2.5%` | A shape outside Design Notes': 400 |
| Set map size | A probe map, `SizeMB` 3 | Its fixed size reads 3 | Negative or fractional: 400 |
| Own table | `OcuPilot_Kernel_State.Turn`, and the schema `OcuPilot_Kernel_State` | Every write is refused with the AD-10 code from both callers, and nothing changes | A failed resolve refuses |
| Changed target | Statistics collected after the proposal was minted | Confirm refuses `PROPOSAL.TARGETCHANGED` and writes nothing | none |
| Gate | A caller without `%Development:USE` or `AtelierPort.WritePairs` | 403 naming the pair, before any read or write | none |
| Hostile id | A table not shaped `Schema.Table`, over 257 characters, or not visible to the caller; an absent index or field | 400 `PORT.VALIDATION` or 404 `PORT.NOTFOUND`, before any write | none |
| Vendor refusal | The seam returns an error status | 409 `SQL.TABLE.VENDOR`, the vendor message in `detail` only, never logged | none |

</intent-contract>

## Code Map

- **Classic sources (read-only):**
  - `irislib/%CSP/UI/Portal/SQL/Home.cls`: Rebuild menu :422, the Indices tab's per-index rebuild :551-559 (a `Data` row is disabled), `RebuildIndices` :3676-3693 (a collection child table rebuilds its parent class).
  - `irislib/%CSP/UI/Portal/SQL/TuneTable.cls` (`%Development`): `SaveData` :582, `SaveMap` :591, `ClearStats` :599, `SetSelValues` :609 (Tune), `SaveTableSize` :642, field statistics query :752-757, map query :760-765.
  - `irislib/%CSP/UI/Portal/Dialog/SQLTuneTables.cls` (`%Development`): schema, Keep class up to date, Clear values, and a log file this story does not offer.
  - `irislib/%CSP/UI/System/BackgroundTask.cls:884-891` and `irislib/%CSP/UI/SQL/SQLPane.cls:466-518`: what the job runs. `TuneTable(Schema.Table,1,0,.msg,keep,clear)` and `TuneSchema(schema,1,display,.err,keep,clear,log)`.
  - `irislib/%SYSTEM/SQL.cls:4541,4599` (`TuneSchema`, `TuneTable`); `irislib/%SYSTEM/SQL/Stats/Table.cls:111-117` (`GatherTableStats` writes to the device when no log file is named), `:240` `ClearTableStats`.
- `src/OcuPilot/Port/SqlPort.cls` -- extended after Story 21.6 lands: its `Invoke` served-endpoint test, `COMPOSEDTYPES`, `Gate`, the `StatementCall` seam, `SnippetForm`/`Snippet`, and `Refuse`/`Fail`.
- `src/OcuPilot/Port/AtelierPort.cls` -- `CATALOGTABS` :154, `CATALOGINDICESQUERY` :200, `CATALOGINDICESCOLUMNS` :249, `CatalogRows` :1294, `CatalogQuery` :1390, `CatalogRelation` :1445, `CatalogResolve`, `WritePairs` :788.
- **Tool siblings:** Story 21.6's `Screen/Tool/SqlStatementAction.cls` (to extend); `LocalDatabaseExpand.cls:29` (`SCREENVALUES` carrying one value); `ExplorerCompile.cls:20` (boolean values); `Write.cls` parameters as 21.6's Code Map lists them.
- **Kernel:** `Kernel/Proposal/Prohibited.cls` (`COVEREDTYPES` :282, `OCUPILOTSQL` :861/:866, the code roster :1127, `ReasonFor` :1164, branch list :1526, target read :1631, `IsOcuPilotCode` :2957, `ReviewedFewOnly` :4518); `Kernel/EntityType.cls` `TYPES` :138; `Kernel/Governance/Baseline.cls`.
- **Screens:** `Screen/Descriptor/ExplorerSqlTable.cls` (Info tab, position 1), `ExplorerSqlIndices.cls` (position 3), `ExplorerSqlSchema.cls`, and Story 21.6's `ExplorerSqlCachedQueries.cls` change (the entity-type precedent). The table group holds positions 1 to 9.
- **Client:** Story 21.6's `sql-cached-queries.page.ts` (page actions through `startFor`); `areas/os-management/database-editor.page.ts` (a value collected for a `SCREENVALUES` action); `shell/screen-action-handler.ts` (`SCREEN_ACTION_DESCRIPTORS`, `UNDRAWN_ACTIONS`, `WARNING_CONSEQUENCES`); `shell/screen-outlet.ts` (`DESCRIPTOR_PAGES`); `core/screen-actions.ts`, `core/proposal-view.ts`, `core/strings.ts`.
- **Fixtures and tests to follow:** Story 21.6's `Test/SqlTuningProbe.cls` and `Test/SqlStatementWrite.cls`; `ui/browser/system-explorer-sql.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:**

Story 21.6 is `done` and merged. **Task 0 is done** (Design Notes, "Task 0 results"); **Batch 3 is not built here** (Spec Change Log, 2026-11-22: it is Story 21.31's). The implement stage builds Batches 1, 2 and 4, and a handoff builds one batch at a time. Where a Batch 1 or 2 bullet below names Batch 3 (`FIELDSTATS`, `SETEXTENT`, `sql-field`, set-extent-size, set-selectivity, set-map-size), skip that part. Strings are the Spec Change Log's ruled and corrected ones; any other user-facing sentence stops with `## Clarification Needed`. Codes go in `Api/AtelierError.cls` (`Api/Error.cls` is frozen). `ConfirmNamespaceRoster` (Epic 24's roster over every registered write tool) is one of the rosters to update: each new namespace-scoped write tool's confirm names the mint's namespace, or is exempted in that roster with a reason.

**Handoff scope now: Batch 2 only (tune).** Batch 1 is committed (888433da8) and closed; its rework paragraph below is history, not work. Build Batch 2's bullets and nothing of Batch 3 or 4, leaving the work uncommitted, with these rules that Batch 1 established:

- Strings are only the ruled and corrected set (Spec Change Log, Design Notes "Strings, escalated"): the Field statistics tab's label, its eight column words, its empty state and suggested prompts, the actions "Collect statistics", "Clear fixed statistics" and "Tune all tables", the values "Keep class up to date" and "Clear values", the consequences as corrected, "This table has no fixed statistics." and the vendor and own-table sentences already published in Batch 1. A write-capable descriptor must declare `"emptyNextKey": ""` and a non-empty `emptyAgentKey` (the mirror and `Registry.TableProblem` enforce it): the Info tab already has `explorerSqlTableMaintenanceEmptyAgent`, and the Schema tab uses the ruled phrase "tune table" verbatim under one new key `explorerSqlSchemaTuneEmptyAgent`. The ruled command aliases "tune table" and "table statistics" go on the descriptors that carry the actions. No other sentence: a state-row word, a new refusal or a new label is a `## Clarification Needed`. Tune and Clear fixed statistics declare no state row (`SqlTableAction.StateDiff` already answers none).
- The Field statistics tab is a read: `entityType` `class` (as the Fields tab), no row action, `emptyNextKey` `tableReadOnlyEmptyNext`; its descriptor is `ExplorerSqlFieldStatistics`, its roster rows join `ExplorerDescriptor` and the mirror, and its read is `Catalog.FieldStatistics` bound as Design Notes (h) measured, equal for the tab and the agent (AC1).
- `TUNE` collects with `KeepClassUpToDate` from the declared value and `ClearValues` 0; `CLEARSTATS` is `ClearTableStats`; `TUNESCHEMA` takes both declared booleans and a non-empty message array is the vendor refusal (409 `SQL.TABLE.VENDOR`). Extend the `TableCall` seam, as Batch 1 did. The `TABLESTATS` read's `ExtentSize` is the collected size unless `HasFixed` (Design Notes, Task 0 clause 4). `SqlTableTune` pins: after Collect statistics the extent size reads the probe's row count (under 1,000 rows); the `KeepClassUpToDate` value reaches the seam as declared, both ways; the class's compiled state and storage `ExtentSize` are unchanged and `IsUpToDate` stays 1; Clear fixed statistics leaves `HasFixed` 0 and refuses a table with none; the probe-schema tune sets both tables' extent sizes; the changed-target and own-table (table and schema) refusals hold for both callers before any write; every statistic a test sets is cleared through the same tool.
- Keys: collect statistics `true`; clear fixed statistics and tune all tables `false`. Rosters, including `ConfirmNamespaceRoster`, updated in this batch, names read from the instance, one class per run. The Rule 19 mutations for AC1, AC3 and AC5 are applied and recorded.

Closed history, Batch 1 rework: three sentences a person would see are outside the ruled set and EXPERIENCE.md before this story, so they are removed, not decided:

1. The absent-index answer. Delete `REASONINDEXNOTFOUND` (`Api/AtelierError.cls`), `sqlIndexNotFoundReason` (`ui/src/app/core/strings.ts`), its entry in the `ui/tools/self-protection.test.mjs` roster, and its words in the Batch 1 row of EXPERIENCE.md's Fixed strings (and the sentence in that row explaining it). An index (map) name that this table does not hold is now 400 `PORT.VALIDATION` with the existing `REASONPORTFIELDSHAPE`, from `SqlPort.TableTarget`; a table that resolves to no class stays 404 with `REASONCATALOGNOTFOUND`. Update `Test/SqlTableRead.cls` and every other test that asserted the 404.
2. The two empty-state invitations. A write-capable descriptor must declare `"emptyNextKey": ""` and a non-empty `emptyAgentKey` (the mirror and `Registry.TableProblem` enforce it), so both tabs need one. The invitation is the already ruled phrase "rebuild indices" (the 21.25 command alias in Design Notes, "Strings, escalated"), used verbatim and nowhere reworded. Items 1 and 3 and the deletion of the two invented invitations (`explorerSqlTableEmptyAgent` "rebuild its indices", `explorerSqlIndicesEmptyAgent` "rebuild an index") are DONE. What is left: add ONE strings.ts key, `explorerSqlTableMaintenanceEmptyAgent: 'rebuild indices'`, used as `emptyAgentKey` by both `ExplorerSqlTable` and `ExplorerSqlIndices` (with `"emptyNextKey": ""`, as already declared in the Batch 1 edit), and list the words "rebuild indices" in the Batch 1 row of EXPERIENCE.md's Fixed strings, in the sentence that says what the row's strings are for, replacing the text about the deleted invitations, with the same line count so the `EXPERIENCE.md:NNN` cites do not shift. Also add the alias `rebuild indices` to the `commandAliases` of `ExplorerSqlTable` if the descriptor's alias rules allow it without a new string; otherwise skip the alias. Fix every test the change reddens.
3. The state-row words "Rebuilt" (`ExplorerSqlIndexRebuild`) and "All indices rebuilt" (`ExplorerSqlTableRebuildIndices`). Give both tools no state row: `SqlTableAction` overrides `StateDiff` to return the precondition refusal when `Holds` is false and otherwise an empty `pRows`, and the two tools declare no `STATEAFTER`. The card then shows its consequence sentence alone. If the proposal, the mint, the client card or a test cannot carry a write with no state row, stop with `## Clarification Needed` naming what refuses, and change nothing further.

After the three changes: regenerate the mirror (`cd ui && node tools/screen-mirror.mjs`), `npm run test:tools` (EXPERIENCE.md changed), `npm run test:components`, `npm run build`, and run, one at a time, `SqlTableRead`, `SqlIndexRebuild`, `Prohibited`, `ExplorerDescriptor`, `Descriptor`, `ClassicPageGate`, `ToolRoundTrip`, `SurfaceCoverage`, `ReadDescriptions`, `ExplorerCatalog`, `ToolEmit`, `DraftRegistry` and `SqlStatementWrite`, after `reload.sh`. Re-apply the mutations whose tests changed (the not-found and state-row ones) and keep their `mutation:` lines true. The earlier Batch 1 scope text follows for reference: it includes every existing test and roster the batch changes (search the test trees for each shared surface under Verification, and update them), the batch's own `(loop)` commands, and the Rule 19 mutations of the ACs the batch pins (applied, observed red, reverted, tree confirmed identical, source reloaded into `ocupilot-ci`), recorded as `mutation:` lines under Verification. Leave the work uncommitted; the agent that spawned the handoff commits at the batch boundary.

**Batch 1, rebuild (server).** Commit when its `(loop)` commands are green.

- `src/OcuPilot/Port/SqlPort.cls` -- add endpoint `Tables`, served in `Invoke`, with the port-composed reads `TABLESTATS` (`{Table, Class, ExtentSize, StatsKind, CollectedAt, HasFixed}`, from `%SQL.Manager.Catalog` `GetCurrentTableExtentSize`, `HasFixedStats` and `DisplayExtentDBStats`) and `INDEX` (`{Table, Index, Map, Type}`, the one `Catalog.Indices` row). The table resolves through the caller's own information schema, as `AtelierPort.CatalogResolve` does; otherwise 404. Writes `REBUILD` and `REBUILDALL` call `%SQL.Manager.API.RebuildIndices(class, $ListBuild(index) or "")`, the class being the collection parent's where the classic page uses it. Reads pass `Gate`; writes also pass `AtelierPort.WritePairs`. Every vendor call goes through 21.6's seam, widened to `TableCall(pType, pTarget, pValues)`. A vendor error status is 409 `SQL.TABLE.VENDOR`.
- `src/OcuPilot/Api/AtelierError.cls` (add-only) -- `SQL.TABLE.VENDOR`, the precondition sentences, and the consequence codes `SQL.TABLE.REBUILD`, `.REBUILDALL`, `.TUNE`, `.CLEARSTATISTICS`, `.TUNESCHEMA`, `.SETEXTENTSIZE`, `.SETSELECTIVITY` and `.SETMAPSIZE`.
- `src/OcuPilot/Screen/Tool/SqlTableAction.cls` (new, abstract, extends 21.6's `SqlStatementAction`) -- overrides `READTYPE` `TABLESTATS`, the subject `ExtentSize,StatsKind,CollectedAt,HasFixed`, `CLASSICPAGES` `%CSP.UI.Portal.SQL.Home,%CSP.UI.Portal.SQL.TuneTable`, and `ArgumentProblem` for the `Schema.Table` shape.
- `ExplorerSqlIndexRebuild` (`explorer.sqlindices.rebuild`, `READTYPE` `INDEX`, precondition: `Type` does not contain `Data`) and `ExplorerSqlTableRebuildIndices` (`explorer.sqltable.rebuildindices`) (new).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only) -- `sql-table` and `sql-index` join `COVEREDTYPES`, the `TYPE*` parameters and the branch list. Each resolves the target table through `TABLESTATS` or `INDEX` (the tool's port) and refuses with the AD-10 code when the schema or the class `IsOcuPilotCode`. An absent or failed read refuses. Add the code to the roster at :1127 and `ReasonFor` if the owner rules a new code.
- `src/OcuPilot/Kernel/EntityType.cls` -- `sql-table` (id `Schema.Table`, exact) and `sql-index` (composite `Table`, `Map`), no `IDRULES` row.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only) -- the batch's keys as Design Notes values them.
- `ExplorerSqlTable.cls` -- `entityType` `sql-table`; page actions `rebuild-indices` (and, in later batches, `tune`, `clear-statistics`, `set-extent-size`). `ExplorerSqlIndices.cls` -- `entityType` `sql-index`, `id` composite `Table`, `Map`, and row actions `rebuild` and, in Batch 3, `set-map-size`.
- `src/OcuPilot/Test/SqlTuningProbe.cls` (Story 21.6's fixture, extended) -- `Table(ns, rows, indices)` makes `OcuProbe225.T<n>` with two indices and the rows, and `KillIndex(ns, table, index)` kills one index's global so a rebuild is observable. `Remove` purges the probe tables' cached queries, then drops them and their schema.
- `src/OcuPilot/Test/SqlTableRead.cls` (new, live-safe) -- `TABLESTATS` and `INDEX` shapes, not found, every hostile id, and the gates.
- `src/OcuPilot/Test/SqlIndexRebuild.cls` (new, live-safe) -- both rebuilds on both callers, the data-map refusal, the own-table refusal on both callers before any write, target changed, and the vendor refusal through the seam.

**Batch 2, tune (server).**

- `SqlPort.cls` -- writes `TUNE` (`$SYSTEM.SQL.TuneTable(table,1,0,.msg,keep,0)`), `CLEARSTATS` (`$SYSTEM.SQL.Stats.Table.ClearTableStats(table)`) and `TUNESCHEMA` (`$SYSTEM.SQL.TuneSchema(schema,1,0,.err,keep,clear,"")`), and the read `SCHEMA` (`{Schema, Tables}`, the count of base tables the caller sees). A non-empty `msg` or `err` is the vendor refusal.
- `AtelierPort.cls` -- add `Catalog.FieldStatistics` to `CATALOGTABS`, its statement being `TuneTable.cls:756`'s field query with the table bound as `CatalogResolve` binds it, and columns `Field`, `Selectivity`, `OutlierValue`, `OutlierSelectivity`, `AverageFieldSize`, `FixedSelectivity`, `FixedOutlierValue`, `FixedOutlierSelectivity` and `FixedAverageFieldSize`.
- Tools (new): `ExplorerSqlTableTune` (`explorer.sqltable.tune`, `SCREENVALUES` `tune=KeepClassUpToDate`), `ExplorerSqlTableClearStatistics` (`explorer.sqltable.clearstatistics`, precondition `HasFixed`), `ExplorerSqlSchemaTune` (`explorer.sqlschematables.tune`, `READTYPE` `SCHEMA`, `SCREENVALUES` `tune=KeepClassUpToDate:ClearValues`).
- `Prohibited.cls` and `EntityType.cls` -- `sql-schema` (id: the schema name, exact), refused when the name `IsOcuPilotCode`. `ExplorerSqlSchema.cls` -- `entityType` `sql-schema`, page action `tune`.
- `src/OcuPilot/Screen/Descriptor/ExplorerSqlFieldStatistics.cls` (new, modeled on `ExplorerSqlIndices`) -- tab position 10, route `system-explorer/sql-tables/field-statistics`, `entityType` `sql-field` (Batch 3), source `Catalog.FieldStatistics`, `toolIdentifier` `explorer.sqlfieldstatistics`, `classicPage` `%CSP.UI.Portal.SQL.TuneTable`.
- `src/OcuPilot/Test/SqlTableTune.cls` (new, live-safe) -- collect, keep class up to date, clear and the probe-schema tune on both callers, with both refusals, and the tab read against a direct bound `SELECT` and equal to the agent read.

**Batch 3, fixed statistics (server; the split candidate in Design Notes).**

- `SqlPort.cls` -- the read `FIELDSTATS` (one `Catalog.FieldStatistics` row) and writes `SETEXTENT` (`%SQL.Manager.Catalog.SetTableExtentSize`), `SETSELECTIVITY` (`SetFieldSelectivity`) and `SETMAPSIZE` (`SetMapBlockCount`), each passing `KeepClassUpToDate` 0. Values pass the shapes in Design Notes before any call.
- Tools (new): `ExplorerSqlTableSetExtentSize` (`explorer.sqltable.setextentsize`, `ExtentSize`), `ExplorerSqlFieldSetSelectivity` (`explorer.sqlfieldstatistics.setselectivity`, `Selectivity`, `OutlierSelectivity`, `OutlierValue`, `AverageFieldSize`), `ExplorerSqlIndexSetMapSize` (`explorer.sqlindices.setmapsize`, `SizeMB`). Each state row shows the old and new value.
- `Prohibited.cls` and `EntityType.cls` -- `sql-field` (composite `Table`, `Field`).
- `src/OcuPilot/Test/SqlTableFixedStats.cls` (new, live-safe) -- the three round trips on both callers, every shape refusal, the own-table refusal, and each value restored through the same tool.

**Batch 4, client.**

- `ui/src/app/areas/system-explorer/sql-table.page.ts` and `sql-schema.page.ts`, each with a spec (new) -- 21.6's `sql-cached-queries.page.ts` shape. The first registers rebuild-indices, tune, clear-statistics and set-extent-size on the route's table. The second registers tune on the route's schema. Values are collected as `database-editor.page.ts` collects `InitialSize`. `shell/screen-outlet.ts` gets the `DESCRIPTOR_PAGES` rows.
- `shell/screen-action-handler.ts` (add-only) -- the four descriptors join `SCREEN_ACTION_DESCRIPTORS`, page actions join `UNDRAWN_ACTIONS`, and each consequence goes in `WARNING_CONSEQUENCES`. `core/screen-actions.ts`, `core/proposal-view.ts` and `core/strings.ts` get the labels, codes and ruled strings. `core/screens.generated.ts` and `Screen/Titles.cls` are regenerated (`node tools/screen-mirror.mjs`).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings (add-only).
- `ui/browser/system-explorer-sql-tuning.browser-spec.mjs` (new) -- the fixture before and after, each step waiting for the answered signal. Rebuild one index on the Indices tab, and its rows answer again. Collect statistics on the Info tab, and the extent size reads the probe's rows. Set selectivity on the Field statistics tab. Clear fixed statistics restores the probe. An own table's Collect statistics shows the refusal sentence and changes nothing. The `after` hook purges the probe tables' cached queries before dropping them.
- Every shared-surface test under Verification is updated to the new shape.

**Acceptance Criteria:**

- AC1. Given a probe table, when the person opens its Field statistics tab and the agent calls `explorer.sqlfieldstatistics.read`, then both answer the same capped rows, each with the collected and fixed selectivity, outlier and average size.
- AC2. Given probe indices whose globals the test killed, when either caller rebuilds one index or all of them and confirms, then by the time the confirm answers, a query through each rebuilt index returns every probe row.
- AC3. Given a probe table and a probe schema, when either caller collects statistics, with and without keeping the class up to date, clears the fixed statistics, or tunes the schema, then the extent sizes read the row counts by the time the confirm answers. The class keeps or does not keep them as asked, and the fixed statistics are gone.
- AC4. Given a probe table, when either caller sets its extent size, a field's selectivity or a map's size, then each reads back as sent. A value outside its shape is refused before any write.
- AC5. Given a table or schema in an `OcuPilot` schema, when either caller attempts any of the eight writes, then each is refused with its published sentence before any write, and the table's statistics, class and indices are unchanged.
- AC6. Given the throwaway, when the browser spec runs forward and in reverse with any other spec file, then it passes and leaves no probe schema, table, statistic or cached query behind.

## Spec Change Log

- 2026-11-22, orchestrator ruling at the start of implement (veto U-146); authoritative over the Design Notes where they differ:
  - **Scope after the split:** Batch 3 (fixed statistics) is Story 21.31's (split 2026-11-16); this story builds Batches 1, 2 and 4. Check which batch holds Clear fixed statistics: if it belonged to the old Batch 3, it moves to 21.31 with its precondition "This table has no fixed statistics." and its key; say which here.
  - **Strings:** accepted as written (the 21.25 set under "Strings, escalated"; 21.31's set is ruled at its own plan). The AD-10 sentence stands as U-84 answered it.
  - **Measure first (Task 0, `ocupilot-ci`), keep each clause only if it holds, otherwise correct it in its own sentence and report the corrected text verbatim:** (1) rebuild "The table is locked while it runs": name the lock flag the port passes to the vendor's index build and measure whether a second process's write waits; (2) rebuild "queries that use the index may miss rows until it ends" (expected false: the vendor marks an index being built as not selectable): measure with a query during a build on a probe table large enough to observe; (3) collect statistics "The table's cached queries are purged, so their plans may change": measure whether the vendor's gather purges them by default or only under the option the port passes; (4) "Keep class up to date": measure whether it marks the class out of date (needing a compile) or recompiles it, and if either, the consequence says so.
  - **Entity types:** `sql-table`, `sql-index` and `sql-schema` (`sql-field` is 21.31's), add-only in EntityType TYPES and Prohibited COVEREDTYPES, checked item by item, plus the mirror. Before building, list every consumer of the Info, Indices and Schema tabs' primary type (navigation, screen-permission and screen-access rows, the agent's entity references, preferences, the mirror, browser specs). A stored row keyed on the old `class` type is named, its upgrade behavior stated, and pinned by a test.
  - **Keys:** collect statistics `true`; rebuild index, rebuild all, clear fixed statistics (if it stays) and tune all tables `false`; add-only in Baseline.cls.
- 2026-11-22, implement stage, after Task 0 (apply and report; all measured on `ocupilot-ci`, see Design Notes "Task 0 results"):
  - **Scope applied:** Batches 1, 2 and 4 only. Clear fixed statistics sat in Batch 2 and stays in 21.25 (key `false`). Batch 3 moves whole to 21.31: `SETEXTENT`, `SETSELECTIVITY`, `SETMAPSIZE`, `FIELDSTATS`, the three setter tools, `sql-field`, `SqlTableFixedStats`, the set-extent-size page action, the Set selectivity and Set map size row actions, the shape refusals and the matrix rows and AC4 that name them. The Field statistics tab (a read) stays here with `entityType` `class` (as the Fields tab) and no row action.
  - **Strings (measured corrections, verbatim):** Rebuild index: "This index is emptied and built again from the table's rows. The table is locked against changes while it runs." Rebuild all indices: "Every index of this table is emptied and built again from its rows. The table is locked against changes while it runs." Collect statistics: "The table's extent size and each field's selectivity are measured from its current rows. Some of the table's cached queries may be purged, so their plans may change." Keep class up to date: "The class is not recompiled and is not marked out of date." Every other 21.25 string stands as ruled.
  - **Matrix and AC3, restated to the measured observable (intent unchanged):** `Collect statistics` reads the collected extent size N (the port's `ExtentSize` is the collected size, or the fixed size when `HasFixed`). `Keep class up to date` does not change the class's storage `ExtentSize` or its compiled state on this build, so the pass-through of `KeepClassUpToDate` is pinned at the seam and the class is pinned unchanged and up to date.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-7 (the write runs in the confirm request, never a detached process; the cube build's named limit), AD-10 (self-protection, OcuPilot's own tables), AD-51 (action-style writes; a named entry for values a caller chooses), AD-52 and AD-53 (one operation through one port, two callers), AD-6 and AD-34 (fingerprint, single transition), AD-56 (a screen action accepts only its declared values), AD-58 (read-back), AD-14 (change event), AD-15, AD-21 (bound SQL, no caller path), AD-16 (namespace save and restore), AD-29 and AD-61 (gates), AD-36 (one read for screen and tool), AD-5 and AD-44 (descriptors and classic pages), AD-22 (keys), AD-39 (vendor message in the answer only), AD-59 (copy-out).

**AD records for the owner** (proposed text; the runner writes each into the spine at the spec gate if allowed):

1. **AD-51, Story 21.25's case (needed: the vendor calls carry values a caller chooses).** "Story 21.25's case: `SqlPort` answers the table tools' fresh read through port-composed `TABLESTATS`, `INDEX`, `FIELDSTATS` and `SCHEMA` types, read in the target namespace for the table or schema its target names, resolved through the caller's own information schema. It calls `%SQL.Manager.API.RebuildIndices` with the table's class and the target index or none. It calls `$SYSTEM.SQL.TuneTable`, `$SYSTEM.SQL.TuneSchema` and `$SYSTEM.SQL.Stats.Table.ClearTableStats` with display off and no log file, taking the tune tools' declared `KeepClassUpToDate` and `ClearValues` booleans. It builds `%SQL.Manager.Catalog` `SetTableExtentSize`, `SetFieldSelectivity` and `SetMapBlockCount` from the declared `ExtentSize`, `Selectivity`, `OutlierSelectivity`, `OutlierValue`, `AverageFieldSize` and `SizeMB`, each refused before the call when it is outside its declared shape. No value reaches a file name, SQL text or code." Recommendation: allow.
2. **AD-10, OcuPilot's own tables (needed: the SQL tuning track arm covers statements only).** Append to the arm: "Rebuilding the indices of, tuning, clearing the fixed statistics of, or setting the extent size, a field's selectivity or a map's size on a table whose schema lies in an `OcuPilot` schema or whose class name begins with `OcuPilot` in any case, or tuning an `OcuPilot` schema, is refused from either caller, read at the write (a failed resolve refuses). A rebuild would lock OcuPilot's protected tables for its length (AD-9), and keeping the class up to date rewrites OcuPilot's own class definitions (`OCUPILOTCODE`'s family) [Story 21.25]." Code: recommended a new `PROHIBITED.OCUPILOTTABLE`, with the sentence escalated below, because `OCUPILOTSQLREASON` begins "This statement" and these writes have none. The alternative is `PROHIBITED.OCUPILOTSQL` with its existing sentence, which adds no string. Recommendation: allow, with the new code.
3. **AD-7, rebuild and tune run in the request (needed: the classic page runs them in a detached job, which this rule's Prevents names).** Append after the cube build's paragraph: "**An index rebuild, a table or schema tune and a fixed-statistics change (Story 21.25)** run in their confirm or action request, as a cube build does; the classic page's `%CSP.UI.System.BackgroundTask` job is not used. A rebuild holds the table's extent lock while it runs. One that outlasts the Web Gateway's response timeout runs to its end in that request's process, and its answer is lost (named limit)." Recommendation: allow. The alternative, a job, contradicts the Rule. A schema tune is the likeliest to reach the limit (inference).

**Measured read-only on `ocupilot` (`ocupilot-slot-a`, `HSCUSTOM`, 2026-11-16):**

- The confirm's bound: `OcuPilot.Install.Installer.GatewayResponseTimeout` answers `Server_Response_Timeout` 60, from the live Gateway registry.
- `%SQL.Manager.API` is hidden. Its source, read with `GetTextAsString`, makes `RebuildIndices(classname, indices)` call `$classmethod(classname, "%BuildIndices", indices, 1, 1)`: it purges the index first and takes the extent lock.
- The `%SQL.Manager.Catalog` signatures are from `%Dictionary.CompiledMethod`: `SetTableExtentSize(pSchema, pTablename, pExtentSize, pKeepClassUpToDate=0)`, `SetFieldSelectivity(…, pSelectivity, pKeepClassUpToDate=0, pOutlierSelectivity, pOutlierValue, pAverageFieldSize, pHistogram)`, `SetMapBlockCount(…, pMapName, pBlockCount, pKeepClassUpToDate=0)`, `HasFixedStats`, `GetCurrentTableExtentSize`, `GetCollectedTableExtentSize` and `DisplayExtentDBStats`. `FieldCurrentSelectivity`, `CollectedFieldSelectivity`, `MapBlockCount` and `CollectedMapBlockCount` are SQL procedures.
- A count and a full id scan of five small tables each took at most 0.051 s. The largest storage `ExtentSize` values on the instance (up to 157,814,027) are vendor-declared fixed statistics, not rows. The prepares recorded statement-index rows (AD-7's fifth shape).
- **Not measurable read-only:** a rebuild or a tune writes index globals and statistics, so whether each fits the bound for a small probe is Task 0 (a). Until then: a probe of under 1,000 rows rebuilds and tunes in well under a second (inference), and `TuneTable` reads an extent that small whole (`SQL.cls:4533`).

**Task 0, measured by the implement stage on `ocupilot-ci` before code** (each restored; record results here; until then each is an inference):

- (a) The duration of one-index and all-index rebuilds and a tune on probe tables of 1,000 and 100,000 rows, and of a three-table schema tune. Halt if a 1,000-row probe takes over 10 s.
- (b) Whether `TuneTable` and `TuneSchema` with display 0, `RebuildIndices`, `ClearTableStats` and the three `Catalog` setters write to the current device. If one does, the port redirects output.
- (c) Whether a principal holding only `AtelierPort.WritePairs` can do each write. Which databases each one writes: the statistics storage, the class definition under `KeepClassUpToDate`, and index globals. A missing pair should read `<PROTECT>` or a status; record which, and map it to 403.
- (d) What a rebuild does when another process holds a row lock on the table: whether it waits, and for how long, or errors.
- (e) Whether `TuneTable` purges the table's cached queries, which the tune consequence states.
- (f) Whether `SetMapBlockCount`'s value is in MB, as the classic field says. Which selectivity shapes it accepts. Whether an `OutlierValue` holding quotes and parentheses is stored as data and never run.
- (g) After `ClearTableStats`, the values of `HasFixedStats` and `StatsKind`.
- (h) Whether the `CollectedFieldSelectivity` and `FieldCurrentSelectivity` join runs through the Atelier query route with bound values.

**Re-validated at implement, 2026-11-22 (HEAD b8283da29):** drift is mechanical; no AC, ruled string, code or AD reading changes.

- Story 21.6 has landed. `SqlPort` (2,895 lines) serves `Statements` and `CachedQueries` through `TuningInvoke` (a private method called from `Invoke`'s first branch), with `Gate(ns, ., ., pWrite)`, `Applied`, `StatementCall(pType, pHash, pNamespace)` (the seam), `PurgeTarget` (resolves `Schema.Table` through `AtelierPort`'s `CATALOGRESOLVEQUERY`, 404 and 400 as this story needs), `SnippetForm`/`Snippet` and `COMPOSEDTYPES`. `SqlStatementAction` is the abstract base (parameters `READTYPE`, `READANSWERS`, `FINGERPRINTSUBJECT`, `PRECONDITIONFIELD`, `REFUSALCODE`, `STATEAFTER`, `CONSEQUENCECODE`, `IDDESCRIPTION`; methods `IdArgument`, `IdParam`, `Endpoint`, `Holds`, `RefusalCode`, `StateDiff`). `SqlTuningProbe` (schema `OcuProbe216`) is the fixture to extend. `TableCall` is added beside `StatementCall`, not in place of it (21.6's tests override `StatementCall`).
- `Prohibited.cls` is 7,284 lines (plan: 4,518), `COVEREDTYPES` ends `...statement-index-entry,cached-query` and `EntityType.TYPES` ends the same; the type branch list is the long `If` near line 1766 and the arm precedent is `OCUPILOTSQL` (3566-3640). `Baseline.cls`, `ExplorerDescriptor.cls`, the mirror and the rosters are as the plan names them, with counts moved by about twenty stories.
- Descriptors: `ExplorerSqlTable`, `ExplorerSqlIndices` and `ExplorerSqlSchema` declare `entityType` `class`; `ExplorerSqlCachedQueries` (`cached-query`) is the precedent. Rows for the Field statistics tab join `ExplorerDescriptor`'s roster (the plan's "positions 1 to 9" are now 1 to 9 plus this tab at 10).
- **Consumers of the three tabs' primary type `class`:** server, `Test/ExplorerDescriptor.cls` (roster rows lines 61-62), `Test/ExplorerCatalog.cls`, `Test/Descriptor.cls`, `Test/ReadTool.cls`, `ReadDescriptions`, `ToolRoundTrip`, `StageTwoTools`, `DeveloperFloor`, `SurfaceCoverage`, and `Kernel/Agent/Workflow.cls:263` (a suggested workflow that names `explorer.sqltablestatements.read` and `explorer.sqlcachedqueries.read`, unaffected). Client, `core/navigation.ts` (the entity's list and create screens are found by `screen.entityType === type`, lines 595-602, 660, 708), `core/citations.ts:93-99`, `core/screens.generated.ts` (the mirror, regenerated), `tools/screen-mirror.test.mjs`, `tools/navigation.test.mjs`, `tools/name-links.test.mjs`, `shell/list-page.spec.ts` and `browser/system-explorer-sql.browser-spec.mjs`.
- **Stored rows keyed on `class` for these tabs:** none are written, since the three tabs had no write before this story and a read stores nothing keyed on its tab. A conversation's stored citation `class:<Schema.Table>` keeps resolving as it does today (to the class screen), is not rewritten and is not migrated; the new types add navigation targets and remove none. A test pins that a stored `class` reference is still accepted by the navigation resolver after the change.

**Task 0 results, measured on `ocupilot-ci` (HSCUSTOM, schema `OcuProbe225`, 2026-11-22; every probe table, user, role and class removed and read back absent; the statement index keeps 22 relation rows for the dropped probe tables, as 21.6's fixture leaves its own):**

- (a) Durations (`$ZH`, seconds): one-index rebuild, all-index rebuild, `TuneTable` and a three-table `TuneSchema`: 1,000 rows 0.002, 0.003, 0.017 and 0.046; 100,000 rows 0.066, 0.094 and 0.076; 2,000,000 rows 1.315, 1.948 and 0.084. No probe approaches 10 s. A rebuild of 2,000,000 rows fits the gateway's 60 s bound with a factor of about 30.
- (b) None of `RebuildIndices`, `TuneTable`, `TuneSchema` (display 0, no log file), `ClearTableStats`, `SetTableExtentSize`, `SetMapBlockCount` or `SetFieldSelectivity` wrote anything to the current device. `TuneTable`'s message and return are empty on success. No output redirect is needed.
- (c) A principal holding `%Development:USE` and `%DB_HSCUSTOM:RW` ran all of them. With `%DB_HSCUSTOM:R` every write threw `<PROTECT>` (not a status): index globals (`^rINDEXEXT`), the tune log `^IRIS.Tune.TTLog` and class storage `^oddEXTR`. The port's `Applied` catches a throw as an unexpected failure, so it maps to the port's failure answer, which is the gate's backstop. A principal without `%Development` could not hold a session to test (inference: the gate's `%Development:USE` requirement stands on the page's own resource). A namespace whose globals database differs from its routines database is not on this instance (inference: such a namespace's write would hit `<PROTECT>` on the globals database, caught the same way).
- (d) A rebuild whose table has a row locked by another process waits 10 s for the extent lock, then answers the error status "ERROR #5798: Failed to lock extent for exclusive access: '<class>'" (measured at 3.5 s for a 4 s hold and 10.0 s for a 40 s hold). That status is the 409 `SQL.TABLE.VENDOR`.
- (e) `TuneTable` purges some of the table's cached queries, not all and not none (one of three, one of six, one of one and one of two in separate runs; a tune with keep 1 purged none of two in one run and one of six in another). `TuneSchema` purged one of six with keep 0 and with keep 1. The sentence says "Some ... may be purged".
- (g) After `ClearTableStats`: `HasFixedStats` 0, the storage `ExtentSize` removed, `GetCurrentTableExtentSize` reads the default 100000, and `GetCollectedTableExtentSize` still reads the collected size. A tune with `ClearValues` 0 leaves a fixed size in place (777 stayed after a tune with and without keep). The collected size is exact for 1,000 rows and an estimate above that (100,328 and 100,302 for 100,000 rows).
- (h) The classic field-statistics join (`%SQL_Manager.FieldCurrentSelectivity` left-joined to `CollectedFieldSelectivity`, schema and table bound as `?`) prepares and runs with bound values and the schema and table in either case, answering a row per field (collected selectivity as text such as `0.1000%`, `1` for a unique field, fixed columns empty when none).
- (f) is Batch 3's, so it moves to 21.31.
- **Clause 1** (rebuild locks the table): holds for changes only. `RebuildIndices` calls `%BuildIndices(indices, 1, 1)`, purge first and lock the extent. A second process's insert waited 1.9 s for a 2.0 s build of 2,000,000 rows; queries ran at their normal speed throughout.
- **Clause 2** (queries may miss rows): false. Twenty-one pairs of `COUNT` queries (`WHERE B = 'v7'` while `IdxB` rebuilt, and `WHERE A > 0`) during an index rebuild of 2,000,000 rows answered 40,000 and 2,000,001 every time, at normal speed; whether the plans used the index being built was not read (inference: they did not).
- **Clause 3** (collect purges cached queries): partly. See (e).
- **Clause 4** (keep class up to date): it neither recompiled the class nor marked it out of date (compiled timestamp unchanged, `IsUpToDate` 1) and changed no storage value on a table with or without fixed values; collected values live in `%ExtentMgr.TableStatsInfo`, whose `DisplayExtentDBStats` returns it as an object and an id. `GetCurrentTableExtentSize` ignores them (it reads the class's own or 100000), so the port's `ExtentSize` is the collected size unless `HasFixedStats`, and its `StatsKind` is `fixed`, `collected` or `none` from `HasFixedStats` and the stats object.

**Decided in-stage:**

- **Placement.** Rebuild all, collect statistics, clear fixed statistics and set extent size are page actions on the table's Info tab, where the extent size already shows. Rebuild one and set map size are row actions on the Indices tab. Set selectivity is a row action on the new Field statistics tab (position 10). Tune schema is a page action on the schema's Tables tab. No side-bar entry changes.
- **Entity types (four, new):** `sql-table`, `sql-index`, `sql-field` and `sql-schema`. A tool's target type is its descriptor's primary type (`Operation.TargetRefOf`), so the Info, Indices and Schema tabs move from `class`. Otherwise the class arm would judge `Schema.Table` as a class name, as 21.6 found for the Cached queries tab.
- **Calls.** Tune uses the classic page's own call, `TuneTable` with display 0, not `GatherTableStats`, which writes to the device when no log file is named. The fixed-statistics setters pass `KeepClassUpToDate` 0: the classic page offers the box, but a person who wants the class updated collects statistics with it. `FixTableStats` before a setter follows the classic page: it runs when `StatsKind` is collected.
- **Value shapes.** `ExtentSize` is an integer from 0 to 10^12. `Selectivity` and `OutlierSelectivity` are `1`, or a percentage over 0 and up to 99.999, written with `%`. `AverageFieldSize` is a non-negative integer. `OutlierValue` is at most 128 characters with no control character. `SizeMB` is a non-negative integer. `KeepClassUpToDate` and `ClearValues` are booleans.
- **Keys.** `true` for collect statistics. `false` for the rest: a rebuild locks the table, and the fixed values override what the optimizer measures. None is destructive (no typed name): a rebuild rebuilds from the rows and loses no data.
- **The gate** is `%Development:USE` with `AtelierPort.WritePairs`, as 21.6's writes use, with the vendor's own check as a lower bound (AD-29). Task 0 (c) confirms it.
- **The 21.24 lesson.** Each test reverses a value through the same tool that set it, and drops only its own probe after purging that probe's cached queries.

**Scope (size rule):** 8 write tools, 1 read tool and about 30 files. They are planned as four batches, each committed on its own. Recommended to the runner: split Batch 3 into a sibling story, "Fixed table statistics". It needs only its own `SqlPort` types and the `sql-field` type. Splitting would move part of the catalog row's "extent size, selectivity edit" out of this story, which is the runner's ruling, not this stage's.

**Flagged, no owner:** EX-47's "drop item" and the Indices tab's map-status toggle (`Home.cls:549`) are in neither this story nor 21.6.

**Strings, escalated for the spec gate's ruling** (none is in `EXPERIENCE.md` or a spec yet):

- Tab: "Field statistics". Columns: "Selectivity" · "Outlier value" · "Outlier selectivity" · "Average field size" · "Fixed selectivity" · "Fixed outlier value" · "Fixed outlier selectivity" · "Fixed average field size". Reused: "Field", "Map", "Index", "Extent size".
- Empty state: "No field statistics are recorded for this table."
- Actions: "Rebuild index" · "Rebuild all indices" · "Collect statistics" · "Clear fixed statistics" · "Tune all tables" · "Set extent size" · "Set selectivity" · "Set map size". Values: "Keep class up to date" · "Clear values" · "Extent size" · "Selectivity" · "Outlier selectivity" · "Outlier value" · "Average field size" · "Map size (MB)".
- Consequences:
  - Rebuild index: "This index is emptied and built again from the table's rows. The table is locked while it runs, and queries that use the index may miss rows until it ends."
  - Rebuild all indices: "Every index of this table is emptied and built again from its rows. The table is locked while it runs, and queries may miss rows until it ends."
  - Collect statistics: "The table's extent size and each field's selectivity are measured from its current rows. The table's cached queries are purged, so their plans may change."
  - Keep class up to date (with the box): "The class definition is updated with the measured values."
  - Clear fixed statistics: "The fixed statistics saved for this table are removed. The optimizer uses collected statistics, or none."
  - Tune all tables: "Every table in this schema is measured as Collect statistics measures one."
  - Set extent size, selectivity, map size: "The optimizer uses this value for the table until statistics are collected again."
- Precondition refusals: "This is the table's data map, which has no index to rebuild." · "This table has no fixed statistics."
- Shape refusals: "Enter a whole number from 0 to 1,000,000,000,000." · "Enter 1, or a percentage over 0% and up to 99.999%." · "Enter a whole number, 0 or more." · "Enter at most 128 characters."
- Vendor refusal `SQL.TABLE.VENDOR`: "The instance did not apply this change to the table."
- The AD-10 code's sentence, if a new code is ruled: "This table is one of OcuPilot's own, so OcuPilot does not rebuild or tune it."
- Three suggested prompts for the Field statistics tab: "Which fields have fixed selectivity?" · "Do the collected and fixed values differ?" · "Which field has an outlier value?". Command aliases: "tune table" · "rebuild indices" · "table statistics".

**Extend, don't copy (Rule 2/31):** `SqlTableAction` extends 21.6's `SqlStatementAction`, overriding its read type, subject and pages. The vendor seam is 21.6's `StatementCall`, widened to `TableCall` with one more argument, not a second seam. The fixture extends 21.6's `SqlTuningProbe`. The arm follows 21.6's statement arm (`IsOcuPilotCode` on the resolved schema) and adds the class name. The field statistics read is one more `CATALOGTABS` statement. The value actions follow `LocalDatabaseExpand` and `ExplorerCompile`.

**Integration ACs:** `SqlPort`'s `Tables` endpoint is consumed in this story by the eight tools through both callers (AC2 to AC5), and the new tab's read by the agent (AC1).

- **Consumed-by:** none beyond this story. Story 21.27's advice may name a rebuild as the fix it recommends (inference).
- **Consumes:** Story 21.6's `SqlPort` endpoints, `SqlStatementAction`, vendor seam and `SqlTuningProbe`; Story 19.14's table tabs; `AtelierPort`'s catalog read and `WritePairs`.

**Ledger inbox:** none (`LEDGER slice 21-25-index-rebuild-and-tune-table` is empty).

**Contended paths (Epic 24, slot B), checked 2026-11-16** with `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp -- <path>` and the merge-base diff:

- No commit touches `SqlPort.cls`, `AtelierPort.cls`, `AtelierError.cls`, `EntityRef.cls`, `ExplorerSqlIndices.cls`, `ExplorerSqlTable.cls`, `ExplorerSqlSchema.cls`, `ExplorerDescriptor.cls`, `EndpointCoverage.cls`, `areas/system-explorer` or `system-explorer-sql.browser-spec.mjs`.
- Real changes exist on `Prohibited.cls` (2), `Baseline.cls` (2), `Screen/Read.cls` (2, not edited here), `Screen/Tool` (5, its own new files), `ReadTool` (3), `ToolEmit`, `ToolRoundTrip` (3), `ToolWrite` (2), `Descriptor` (2), `SurfaceCoverage` (2), `screen-action-handler.ts`, `screen-outlet.ts`, `screen-actions.ts`, `proposal-view.ts`, `strings.ts`, `screens.generated.ts`, `EXPERIENCE.md` (2 each) and `ci-throwaway.sh` (5, not edited here). `EntityType.cls` and `Titles.cls` show one commit each, with no diff from the merge base. This story's edits there are add-only rows, except count literals.
- Epic 24's worktree also holds uncommitted edits to `ReadTool`, `ToolRoundTrip`, `Descriptor`, `ExplorerDescriptor`, `SurfaceCoverage`, `StageTwoTools`, `DeveloperFloor` and `Titles.cls`. Their count literals meet this story's at integrate forward as a union.
- `OCU-1-epic22` has no remote branch and no worktree.

## Verification

**Shared surfaces, all `(loop)`:**

- The table tab group: `ExplorerDescriptor`, `screen-mirror.test.mjs`'s route rows and catalog roster, and `system-explorer-sql.browser-spec.mjs` (tab strip, and the Info, Indices and Schema tabs' entity types).
- The tool registry: `ReadTool` (count), `ReadDescriptions`, `ToolEmit`, `ToolRoundTrip`, `ToolWrite` (count), `StageTwoTools`, `DeveloperFloor`, `SurfaceCoverage`, `DraftRegistry` (`SnippetForm` per write type), and `Prohibited`'s composed settable counts.
- Entity types: `Descriptor` (count), `EntityRef`, `Prohibited`'s covered-types literal, and `ui/tools/self-protection.test.mjs` if a code is added.
- Governance: `Governance`, `GovernanceBaseline`. Gates: `PortGate`, `ClassicPageGate`, the `SqlPort` test. The catalog read: `AtelierPortCatalogTabs`, `AtelierPortCatalogTabsLive`, `EndpointCoverage`.
- Story 21.6's classes touched by the widened seam and fixture: `SqlStatementWrite`, `SqlCachedQueryPurge`, `SqlStatementRead`.
- Prompts and strings: `suggested-prompts.test.mjs`, `proposal-view.test.mjs`.

The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each surface, and every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Each runs in its own foreground call with `timeout: 600000`, against `ocupilot-ci` only, and never two test calls in one message. Nothing runs on `ocupilot` or a slot instance.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SqlTableRead`, one class per call. Then `SqlIndexRebuild`, `SqlTableTune`, `SqlTableFixedStats`, `SqlStatementWrite`, `SqlCachedQueryPurge`, `SqlStatementRead`, `Prohibited`, `PortGate`, `AtelierPortCatalogTabs`, and every shared-surface class above -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/screen-mirror.test.mjs tools/suggested-prompts.test.mjs tools/self-protection.test.mjs tools/proposal-view.test.mjs` -- expected: green.
- `(loop)` `cd ui && npm run build`, then `npm run test:components`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-sql-tuning.browser-spec.mjs browser/system-explorer-sql.browser-spec.mjs` -- expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep, one class per call, then `smoke.sh --container ocupilot-ci` and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19).** One per AC. Each is applied, observed red and reverted. The tree is then identical by `git status --short` and `git diff --stat`, and the reverted source is reloaded.

- AC1: `Catalog.FieldStatistics` drops the fixed selectivity column -> `SqlTableTune`'s tab test red.
- AC2: `REBUILD` passes `""` for the index list on a one-index target, and `REBUILDALL` is a no-op -> `SqlIndexRebuild` red on the untouched index and on the killed ones.
- AC3: `TUNE` ignores `KeepClassUpToDate` -> `SqlTableTune` red on the class's storage. `CLEARSTATS` is a no-op -> red on `HasFixedStats`.
- AC4: `SETEXTENT` sends the old value -> `SqlTableFixedStats` red on read-back.
- AC5: the arm skips the class-name test -> the own-class probe red on both callers. A failed resolve answers permitted -> `Prohibited` red.
- AC6: the Indices tab loses its `rebuild` row action -> `system-explorer-sql-tuning.browser-spec.mjs` red, after rebuild and redeploy.
- Observed (Batch 1, each applied on `ocupilot-ci`, reverted, `git diff` hash and the untracked tool files' hashes identical, source reloaded) and recorded as `mutation:` lines:
  - mutation: AC2, `SqlPort.TableCall` passes an empty index list for `REBUILD` -> `SqlIndexRebuild.TestOneIndexIsRebuiltOnBothCallers` red on the named index and the untouched one (run 938).
  - mutation: AC2, `TableCall` is a no-op for `REBUILDALL` -> `SqlIndexRebuild.TestEveryIndexIsRebuiltOnBothCallers` red on both callers (run 939).
  - mutation: AC2, `TableFacts` answers the map name as the build argument -> `SqlIndexRebuild.TestAnIndexWhoseMapNameDiffersFromItsBuildNameIsRebuilt` red (the bitmap extent map `%%DDLBEIndex` builds as `DDLBEIndex`; run 940).
  - mutation: AC2, `ExplorerSqlIndexRebuild.Holds` admits a data map -> `SqlIndexRebuild.TestTheDataMapIsRefusedBeforeAnyWrite` red on both callers (run 946).
  - mutation: AC2, the table tool's `FINGERPRINTSUBJECT` and `PRECONDITIONFIELD` shrunk to `Namespace` -> `SqlIndexRebuild.TestATableWhoseStatisticsChangedAfterTheProposalIsRefusedTargetChanged` red (run 947).
  - mutation: AC2, `SqlPort.TableWrite` puts the instance's message in the reason -> `SqlIndexRebuild.TestTheInstancesRefusalIsAnsweredWithItsMessageInDetailAlone` red for both writes (run 950).
  - mutation: AC2, `ExplorerSqlIndexRebuild` declares `DESTRUCTIVE` 1 -> `SqlIndexRebuild.TestTheToolsDeclareTheirWritePath` red (run 949).
  - mutation: AC5, `Prohibited.TableEntry` skips the class-name test -> `Prohibited.TestATableIsRefusedForItsSchemaOrItsClassAndForAFailedRead` red on both class cases (run 944); a failed read answers permitted -> the same test red on the missing and the failed read (run 945); the whole refusal skipped -> `SqlIndexRebuild.TestATableOfOcuPilotsOwnIsRefusedOnBothCallers` red on both callers and the vendor-call count (run 948).
  - mutation: AC2 reads, `SqlPort.TableTarget` answers a row for an absent map instead of 400 -> `SqlTableRead.TestAbsentAndHostileIdsAreRefusedBeforeAnyCall` red (run 972); `TableFacts` reads the collected size for a fixed table -> `TestTheTableStatisticsAreRead` red (run 942); `AtelierPort.CatalogRows` stops naming the table on an index row -> `TestTheIndicesRowsNameTheirTable` red (run 943); `TableSnippet` renders an empty index list for `REBUILD` -> `TestEachRebuildsScriptIsItsOneVendorCall` red (run 951); `TablesInvoke` gates a write as a read -> `TestTheGatesRefuseBeforeAnyReadOrWrite` red (run 952); the indices tab's id drops `Map` -> `TestTheTabsDeclareTheirShape` red (run 953).
  - mutation: AC2, `SqlTableAction.StateDiff` answers one state row -> `SqlIndexRebuild.TestTheToolsDeclareTheirWritePath` red, so the card carries no state row (run 973).
  - mutation: strings, one character of `sqlTableRefusalDataMap` changed -> `self-protection.test.mjs`'s `ATELIER_REFUSALS` test red.
  - Observed (Batch 2, each applied on `ocupilot-ci`, reverted, the file's `git diff` hash identical, source reloaded) and recorded as `mutation:` lines:
  - mutation: AC1, `AtelierPort.CATALOGFIELDSTATISTICSCOLUMNS` drops `FixedSelectivity` -> `SqlTableTune.TestTheFieldStatisticsTabAndTheAgentsReadAnswerTheDirectRows` red on every field (run 1026).
  - mutation: AC3, `SqlPort.TableWrite` hands the seam `0` for the `TUNE` value -> `SqlTableTune.TestTheClassUpToDateValueReachesTheInstanceAsDeclared` red on the `1` call (run 1027); `TableCall` makes no call for `CLEARSTATS` -> `TestFixedStatisticsAreClearedOnBothCallersAndATableWithNoneIsRefused` red on both callers (run 1028); `TableCall` passes `0` for `ClearValues` -> `TestASchemasTablesAreTunedOnBothCallers` red on the cleared leg (run 1029).
  - mutation: AC5, `SqlTableAction.RefusedBeforeState` answers 0 -> `SqlTableTune.TestATableAndASchemaOfOcuPilotsOwnAreRefusedOnBothCallers` red on both callers' clear-statistics (run 1030); `Prohibited.TableEntry` judges no schema name -> `Prohibited.TestASchemaIsRefusedForItsNameAndForAFailedRead` red (run 1031).

**Owner answer U-84 (2026-11-16, "A"):** the three records are written into the spine as proposed, with the new `PROHIBITED.OCUPILOTTABLE` code and its escalated sentence. Implementation waits for Story 21.6's merge.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none (implements after Story 21.6 merges)

First plan. The spec is otherwise complete for development once the three records are ruled. Escalated for the gate: the strings, the four entity types, the keys, and the recommended split of Batch 3. Task 0's eight write measurements wait for the implement stage on `ocupilot-ci`, since `ocupilot` is read-only and a rebuild or tune writes.
