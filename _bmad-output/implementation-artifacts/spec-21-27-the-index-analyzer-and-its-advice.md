---
title: 'Story 21.27: The index analyzer and its advice'
type: 'feature'
created: '2026-11-25'
status: 'done'
baseline_revision: '23762d9606527ff542274e0d939ba0e17b3b0c6e'
baseline_commit: '23762d9606527ff542274e0d939ba0e17b3b0c6e'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-26-runtime-statistics.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-25-index-rebuild-and-tune-table.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The SQL query screen does not show that the advice list was cut at its cap.
    evidence: |-
      `SqlPort.Advised` sets `advice.truncated` when 200 findings or 20 tables are reached and the agent's schema declares it; `sql-answer.ts` and `sql-query.page.ts` carry no member for it. A note needs a person-facing string that no one has ruled.
    location: >-
      ui/src/app/core/sql-answer.ts
    severity: low
---

<intent-contract>

## Intent

**Problem:** The classic SQL Index Analyzer page is the only place to gather a namespace's SQL statements, run its five index reports (index usage, table scans, temporary indices, missing join indices, outlier indices), read their results, and purge them. Nothing in OcuPilot advises on one statement's plan, and the `slowquery` workflow can read neither.

**Approach:** Add a System Explorer list, SQL index analyzer, over the namespace's report rows, with three page actions through `SqlPort`: Gather statements, Run report and Purge analysis. Add Advise on SQL query, and an agent read with the same answer: the statement's plan plus findings computed on the instance from that plan and the tables' indices. This is the MCP suite's `SqlAdvisor` with its SQL rebound (AD-21). `slowquery` gains both reads and stays read-only.

## Boundaries & Constraints

**Always:**

- Each write is one operation with two callers, the screen's page action and the agent's confirmed proposal (AD-53), and runs in the confirm or action request (AD-7, the 21.25 precedent). The vendor gets port-built arguments only: the request's validated namespace, one of five fixed report labels, and the three skip flags as 0 or 1. No caller text reaches SQL text, code or a file (AD-21).
- The advice never concatenates: the statement reaches `$SYSTEM.SQL.Explain` as a value through `SqlPort.Explained`. The two dictionary reads, a table's class and its indices, are fixed statements with bound `?` values. Advice composes no SQL text: no suggested DDL.
- Every finding sentence is composed on the instance from the ruled templates. The screen shows it and the model reads it, word for word (AD-36). Plan text reaching the model goes through AD-60's sanitizer.
- Tests that gather, run or purge sit in an armed class on the throwaway and remove what they created, reading it back absent. No test asserts that a store is empty, except the purge's own AC on its armed namespace.

**Never:**

- No background run and no `job`. No per-report purge. No schema argument to a write: the schema only filters the list.
- No "View Runtime Statistics" link (21.26 owns it), no Plan Format choice, and no agent tool that runs a report outside a confirmed proposal.
- No advice for a statement the instance does not type as a query.
- No edit to `Api/Error.cls`, and the spine stays add-only. No test or write on `ocupilot` or a slot instance. No probe schema whose name holds `"` (DW-2851).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | Probe statements gathered and one report run (armed) | The list and `explorer.sqlindexanalysis.read` answer the same rows. Each row has report, schema, table, index, usage count, statement type, class or routine, module, index fields, data fields, index needed, match, outlier field, extent size, block count and the masked statement text. Join and outlier rows with an exact match are not listed, as on the classic page | Truncation reported (AD-36) |
| Gather | Either caller, flags as sent | The namespace's gathered statements and every report's rows are replaced, as the classic Gather does. The `ANALYSIS` read shows the new statement count | none |
| Run report | `Report` one of the five, flags as sent, statements gathered | That report's rows read back for the probe's table. Other reports' rows stay or go as Task 0 (c) measured, and the consequence says which | No statements gathered: precondition refusal before any call (Task 0 (d)) |
| Purge | Rows or statements present | Both stores of the namespace read 0 after the confirm. Another namespace's rows stay | Nothing to purge: precondition refusal before any call |
| Bad value | A `Report` outside the five; a flag not `true` or `false` | 400 with the ruled sentence before any call, from both callers | none |
| Changed target | Gathered or run after the mint | Confirm refuses `PROPOSAL.TARGETCHANGED` and calls nothing | none |
| Advise | A query over the probe table with a condition on an unindexed field, an unused index, never tuned | Plan text plus findings Full table scan, Missing index (High), Table not tuned and Unused index, each with its table, sentence and plan excerpt. The screen and `explorer.sqladvice.read` answer the same | Unrecognized plan: no findings, with the ruled note |
| Advise, not a query | An `UPDATE` | Refused with the ruled sentence before anything is prepared | none |
| Own tables | A statement or report over an `OcuPilot` table | Advise refused by the console's `Check` before anything runs. Reports are not refused (AD-10, Design Notes) | none |
| Gate | Missing a pair the Design Notes name | 403 naming the pair, before any read or call | none |
| Vendor refusal | The seam answers an error status | 409 `SQL.INDEXANALYSIS.VENDOR`, with the message in `detail` only | none |
| Workflow | A `slowquery` turn | Its steps name `explorer.sqlindexanalysis.read` and `explorer.sqladvice.read` and no write | none |

</intent-contract>

## Code Map

- **Classic and vendor sources (read-only):**
  - `irislib/%CSP/UI/Portal/SQL/QButtons/IndexAnalyzer.cls`:
    - `RESOURCE` `%Development:USE` :9, with no `EDITRESOURCE`.
    - Checkboxes :113-147, defaults 1 :776. Buttons :154-161.
    - `PrepareAnalysis` :723-740 runs `job indexUsage^%SYS.PTools2(1,1,0,skipSys,skipIDkeys,skipIns,0)`, and the other four run `(1,0,skipSys,skipIns,0)`.
    - Gather :681-693 calls `clearSQLStatements` and `clearSQLAnalysisDB`, then `getAllSQLStmts(1,skipSys,skipIns,0,0)`.
    - The purges :505-523 and :792-812. Results are `%ResultSet("%SYS.PTools.UtilSQLAnalysis:"_query).Execute(schema)` :748. A checkbox change clears the analysis :297.
  - `irislib/%SYS/PTools/UtilSQLAnalysis.cls`:
    - Signatures: `indexUsage` :178, `tableScans` :323, `tempIndices` :478, `joinIndices` :703, `outlierIndices` :985, `getAllSQLStmts` :1149, `clearSQLStatements` :1834 and `clearSQLAnalysisDB` :1902.
    - Report queries :196, :341, :496, :733 and :1015. `countSQLStmtTypes` :3161 and `PT_getIndexFlagInfo` :785.
    - Every public wrapper writes `<pre>` HTML when `%request` is an object (doc-read). The routine's own source is not on the instance.
  - `irislib/%SYS/PTools/UtilSQLAnalysisDB.cls`: `IdKey (OptionName, Counter)` :204, with `OptionName` one of `IU,TS,TI,JI,OI` :56. Storage is `^%sqlcq($NAMESPACE,"PTools","util","SQLAnlsys",…)` :300. `SQLPointer` points to `UtilSQLStatements` :71. The flags :111-121 and :176-186 run 0 No Match to 4 Exact.
  - Harvest source: `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/SqlAdvisor.cls`:
    - `RunExplain` :197 concatenates `"EXPLAIN "_pQuery`, which is the AD-21 defect.
    - `ExtractTables` :227, `ResolveClassForTable` :276 and `IndexRowsForClass` :299 are already bound.
    - The heuristics are `packages/iris-dev-mcp/src/tools/sqlAdvisor.ts` `analyzeAdviceData` :268. Its regexes `FULL_SCAN_RE`, `PREDICATE_RE`, `STALE_STATS_RE` and `TEMP_FILE_RE` and its rules move to ObjectScript, renamed. The DDL text is dropped.
- **`src/OcuPilot/Port/SqlPort.cls`:**
  - `COMPOSEDTYPES` :69 and the endpoint constants :74-151, where `ENDPOINTRUNTIMESTATS` :74 is the newest sibling.
  - `Invoke` :861, `TuningInvoke` :942 (served types, namespace, `Gate` :2104, id shape and dispatch), and `StatementWrite` :1087 with its 409 mapping :1095.
  - `StatsCount` :1122 is an unchecked `%Prepare` count. The seam `StatementCall` :1157 is overridden in `Test/SqlTuningPortFixture.cls:6`.
  - `Applied` :1191, `ValueProblem` :1447, `SnippetForm` :2054, `Snippet` :2070 and `TuningSnippet` :2007.
  - `Plan` :796, `Explained` :2436 and `Classify`.
- **`src/OcuPilot/Port/AtelierPort.cls`:** `ENDPOINTCATALOGRUNTIMESTATS` :171 and `CATALOGRUNTIMESTATSQUERY` :257 / `…COLUMNS` :309 (kinds `sqltext|flag|number|plain|qualified`). A new list registers in four places: `IsCatalog` :1334, `CatalogStatement` :1354, `CatalogColumns` :1361 and the binding in `CatalogRows` :1440. `CATALOGMAX` :335.
- **`src/OcuPilot/Port/AdvisorPort.cls` `SetFlag` :334** -- the null-device pattern (with `BackupPort` :632 and `LogSourcePort` :3263).
- **`src/OcuPilot/Area/Explorer/SqlConsole.cls`** -- `HandlePlan` :79, `Prepare` :107 (`pAllowStats`), `Body` :200 and `Check` :156. The route is `Api/Router.cls:244` `POST /explorer/sql/plan`.
- **Tool siblings:**
  - `Screen/Tool/SqlStatementAction.cls` (abstract base), `ExplorerSqlRuntimeStatsPurge.cls` (61 lines, the `*` purge template) and `ExplorerSqlStatementClean.cls`.
  - `SqlTableTuneAction` carries the value machinery: `VALUENAMES`, `REQUIREDVALUES`, `VALUEDESCRIPTIONS`, `ValueType`, `InputSchema` :57, `PortQuery` :89, `ArgumentProblem` :109 and `ScreenActionDelta` :136.
  - `ExplorerSqlSchemaTune` (`SCREENVALUES`) and `ExplorerSqlRead.cls`, the agent's query read (Story 19.11).
- **Descriptors:** `Screen/Descriptor/ExplorerSqlRuntimeStats.cls` (position 21, page action, `paging:"cap"`). Position 23 is the next free one.
- **Kernel** (Epic 24 has commits on the first three: add-only):
  - `Kernel/EntityType.cls` `TYPES` :184, last `sql-runtime-stats-setting`.
  - `Kernel/Proposal/Prohibited.cls` `COVEREDTYPES` :348 and the `tType` guard :1816, where the runtime-stat types sit at its head.
  - `Kernel/Governance/Baseline.cls` :245-262.
  - `Kernel/Agent/Workflow.cls` `slowquery` :261-270, with 21.26's step at :265.
- **Errors:** `Api/AtelierError.cls` codes and `REASON*` :404-426, and `SqlReasonFor` :505 (runtime-stats rows :533-536).
- **Client** (Epic 24 has commits on `screen-action-handler.ts`, `strings.ts`, `screen-outlet.ts` and EXPERIENCE.md: add-only):
  - `ui/src/app/areas/system-explorer/sql-runtime-stats.page.ts` and its spec, the page-action template.
  - `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :104 and `shell/screen-action-handler.ts` (:70, :358-364, :621, :1120, `startFor` :1704).
  - `core/screen-actions.ts` :177, `core/proposal-view.ts` :498 and :642, and `core/strings.ts` :5539.
  - `sql-query.page.ts`/`.store.ts`: the plan pane :139 and :326, and the Plan with statistics button and note.
- **Tests to follow:**
  - `Test/SqlTuningProbe.cls` (`Make`/`Remove`, `HashOf`) and `SqlRuntimeStatsRead`/`Write` (armed `OCUPILOT_ALLOW_CONFIG_SETTINGS`).
  - `SqlConsoleRoutes`, `SqlAgentRead`, `SqlPortLive` and `WorkflowCatalog` :145.
  - `scripts/ci-throwaway.sh` :1010-1031 (`# classes:` :1030) and `ui/browser/system-explorer-sql-runtime-stats.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:** Task 0 first, then three batches, each committed on its own. A handoff builds one batch. Strings are only the ruled set (Design Notes, "Strings, escalated"); any other sentence a person reads is `## Clarification Needed`.

**Task 0, measured on `ocupilot-ci` before code, in `USER` and `HSCUSTOM`.** Record each result under Verification. Purge what you created and read it back absent. Remove every probe table and principal.

- (a) **Least-privileged pairs.** Use a principal holding `%Development:USE` plus `AtelierPort.WritePairs(ns)`. Check that it can do each of these, recording `<PROTECT>`, a status or a silent no-op:
  - read both tables through the catalog route's unchecked prepare;
  - gather, run each report and purge;
  - read `%Dictionary.CompiledClass` and `CompiledIndex` with bound values.

  Record which database holds `^%sqlcq(ns,"PTools","util")`. A pair the vendor needs beyond these joins the gate. A refused read is a HALT `intent gap`.
- (b) **Durations.** Time a gather, with the skips at 1 and at 0, and each report, against the 60 s gateway bound.
- (c) **Clear scope.** Does a report's `clearData` remove other reports' rows? Does a gather's? This fixes the Run consequence's wording.
- (d) **No statements gathered.** Does each report answer rows when no statements are gathered? Is `indexUsage`'s self-gather real? This fixes the Run precondition: a refusal only for the reports that need statements.
- (e) **Device output.** Does each `%SYS.PTools.UtilSQLAnalysis` method used (display 0) write to the current device inside a request? Does the null device swallow all of it?
- (f) **Concurrency.** Does the vendor lock `^%sqlcq(ns,"PTools","util","SQLAnlsys")` while running? What do two concurrent runs leave? If they corrupt or interleave, the port takes that lock with timeout 0 and refuses with the ruled sentence (string 8, measure-first).
- (g) **Side effects.** Do a gather or `indexUsage` add statement-index rows or cached queries (the AD-7 line's wording)? Does Explain for advice add any?
- (h) **Plan markers on this build.** Capture plans that show each marker: `Read master map … looping on`, the `Test the … condition on` predicate lines, `Warning:` / `Table … is not tuned.`, the temp-file lines, and index-map reads. Save them as the heuristics' unit fixtures.
- (i) `PT_getIndexFlagInfo`'s texts for flags 0-3, to check the ruled Match names against the vendor's meaning.

**Batch 1, server: the analyzer.**

- `src/OcuPilot/Port/AtelierPort.cls` -- add `Catalog.IndexAnalysis`:
  - One fixed statement over `%SYS_PTools.UtilSQLAnalysisDB`, left-joined on `SQLPointer` to `%SYS_PTools.UtilSQLStatements`, capped by `maxRows`.
  - The report code and the match flag are mapped to the ruled names inside the fixed text, and rows with flag 4 are excluded for `JI`/`OI`.
  - Columns as in the matrix, plus `Counter`. The statement is `sqltext`, cut and masked.
  - It runs in the target namespace, registered in the four places.
- `src/OcuPilot/Port/SqlPort.cls`:
  - Add the endpoint `IndexAnalysis`, served by `Invoke` and `TuningInvoke`, with `IndexAnalysis/GATHER`, `/RUNREPORT` and `/PURGEANALYSIS` in `COMPOSEDTYPES`.
  - The read `ANALYSIS`, id `*` only, answers `{Namespace, Statements, IndexUsage, TableScans, TempIndices, JoinIndices, OutlierIndices, Rows}` through one unchecked count statement.
  - The writes go through the widened `StatementCall`, in the namespace, under the null device:
    - `GATHER` runs `clearSQLStatements` and `clearSQLAnalysisDB` for the namespace, then `getAllSQLStmts(1, skipSys, skipIns, 0, 0)`.
    - `RUNREPORT` calls the label `Report` names, with the classic page's arguments.
    - `PURGEANALYSIS` runs both clears.
  - `ValueProblem` gains `Report` (the five codes `IU|TS|TI|JI|OI`) and the three booleans. An error status answers 409 `SQL.INDEXANALYSIS.VENDOR`, and `SnippetForm` covers the three writes.
- `src/OcuPilot/Kernel/Utils.cls` -- one helper that runs a vendor call under the null device, as `AdvisorPort.SetFlag` does, used only by `SqlPort` (Rule 2: the three existing copies are left to the burn-down).
- `Screen/Tool/SqlStatementAction.cls` -- hoist `SqlTableTuneAction`'s value machinery (`VALUENAMES` and friends, `InputSchema`, `PortQuery`, `ArgumentProblem`, `ScreenActionDelta`) so it applies wherever `VALUENAMES` is non-empty. `SqlTableTuneAction` keeps working unchanged: `ToolWrite` and `ToolRoundTrip` stay green.
- New `Screen/Tool/ExplorerSqlIndexAnalysisGather.cls`, `…Run.cls` and `…Purge.cls` (`explorer.sqlindexanalysis.gather`, `.run` and `.purge`):
  - They extend `SqlStatementAction` as `ExplorerSqlRuntimeStatsPurge` does: `READTYPE "ANALYSIS"`, `IdArgument "Target"`, id `*` only, and `CLASSICPAGES` `%CSP.UI.Portal.SQL.QButtons.IndexAnalyzer`.
  - The values are: gather `SkipSystem` and `SkipInserts`; run `Report`, `SkipSystem`, `SkipInserts` and `SkipIdKeys`, each flag defaulting to true.
  - Precondition and state: gather none; run `Statements` (only where Task 0 (d) requires it); purge `Statements + Rows`.
- New `Screen/Descriptor/ExplorerSqlIndexAnalysis.cls`:
  - List at position 23, route `system-explorer/sql-index-analysis`, namespace scope, entity `sql-index-analysis`, id composite `["Report","Counter"]`.
  - Source `{port: "atelier", endpoint: "Catalog.IndexAnalysis", type: "LIST"}`, `paging:"cap"`, and page actions `gather`, `run` and `purge` with `SCREENVALUES`.
  - Classic page `…QButtons.IndexAnalyzer`, `%Development:USE`, `toolIdentifier` `explorer.sqlindexanalysis`, and the ruled note, prompts and aliases.
- `Kernel/EntityType.cls` and `Kernel/Proposal/Prohibited.cls` (add-only, at the end; `tType` guards extended by prefix) -- `sql-index-analysis`, covered as `sql-runtime-stat` is, with no predicate.
- `Kernel/Governance/Baseline.cls` (add-only) -- the three keys as ruled (Design Notes record 4).
- `Api/AtelierError.cls` (add-only) -- `SQL.INDEXANALYSIS.VENDOR`, `.NOROWS`, `.NOSTATEMENTS`, `.REPORT`, `.BUSY` (only if Task 0 (f) needs it), and the consequence codes `.GATHER`, `.RUN` and `.PURGE`, each with its ruled sentence.
- `Kernel/Agent/Workflow.cls` -- `slowquery` gains the ruled step after :265.
- `Test/SqlTuningProbe.cls` -- `MakeAnalysis(ns)` creates a probe class with a method whose embedded SQL scans `OcuProbe227` with an unindexed condition. `RemoveAnalysis(ns)` purges and removes it.
- New `Test/SqlIndexAnalysisRead.cls` (live-safe):
  - the declared shape, and the columns pinned with the statement masked;
  - the `ANALYSIS` read;
  - the gates and every id and value shape on both callers;
  - copy-out snippets;
  - AD-36 truncation through a seam.
- New `Test/SqlIndexAnalysisWrite.cls` (armed, `OCUPILOT_ALLOW_CONFIG_SETTINGS`, add-only `# classes:` entry):
  - gather and each report on both callers, with the list equal to the agent read and to a direct bound `SELECT`;
  - the run precondition and the purge on both callers;
  - nothing to purge, another namespace surviving, a changed target, and the vendor refusal (seams);
  - that the mint calls nothing.

**Batch 2, server: the advice.**

- New `src/OcuPilot/Port/SqlAdvice.cls` holds the heuristics, ported from `analyzeAdviceData` with no IRIS call: `Findings(pPlan, pIndexes) -> %DynamicArray` and `Recognized(pPlan)`.
  - The kinds are `fullscan`, `missingindex`, `nottuned`, `tempfile` and `unusedindex`, with the source's confidences.
  - System schemas and IDKEY/primary-key indices are excluded as in the source.
  - Each finding is `{Kind, Confidence, Table, Fields, Index, Detail, Recommendation, Excerpt}`, and `Detail`/`Recommendation` come from the ruled templates.
- `src/OcuPilot/Port/SqlPort.cls`:
  - `Plan` gains `pAdvise` (default 0). With 1, a kind other than `query` is refused with the ruled sentence before anything is prepared.
  - `Explained` (no statistics) runs, then the tables come from the plan's `Read master map`/`Read index map` lines.
  - Each table resolves through the bound fixed `ADVICECLASSQUERY` and `ADVICEINDEXQUERY`, and the answer gains `advice: {recognized, tables, findings}`.
- `src/OcuPilot/Area/Explorer/SqlConsole.cls` -- `HandlePlan` reads a boolean `advise` from the body. `Check` runs first.
- New `Screen/Tool/ExplorerSqlAdviceRead.cls` (`explorer.sqladvice.read`, extends `ExplorerSqlRead`) -- takes `Statement` and calls `SqlPort.Plan(…, pAdvise 1)`. Its description carries the ruled advice note.
- New `Test/SqlAdviceRead.cls`:
  - `SqlAdvice.Findings` over the Task 0 (h) fixtures, one leg per kind plus the unrecognized and the nothing-found cases;
  - live, the probe table on both callers answering the matrix's four findings, the same on both;
  - an `UPDATE` refused and an OcuPilot table refused by `Check`, with nothing prepared;
  - the dictionary reads bound (an identifier holding `'` resolves nothing and raises nothing).

**Batch 3, client.**

- New `areas/system-explorer/sql-index-analysis.page.ts` with a spec, in the `sql-runtime-stats.page.ts` shape. It registers Gather statements, Run report and Purge analysis on `*`, and the run's dialog offers the five report names and the three flags. It gets a `screen-outlet.ts` row.
- `sql-query.page.ts`, `sql-query.store.ts` and their spec -- an Advise button beside Plan with statistics posting `{advise: true}`. The findings show under the plan, one row each (finding, confidence, table, sentence, recommendation), with the ruled note and empty state.
- `shell/screen-action-handler.ts`, `core/screen-actions.ts`, `core/proposal-view.ts` and `core/strings.ts` (add-only) -- the descriptor, the page actions, the consequences and the ruled strings. Regenerate the mirror and `Titles.cls` (`node tools/screen-mirror.mjs`).
- `EXPERIENCE.md` -- one add-only Fixed strings row for 21.27.
- New `ui/browser/system-explorer-sql-index-analysis.browser-spec.mjs`, which refuses the live container and waits for each answered signal:
  - Gather statements and Run report Table scan ask, confirm and list the probe's row;
  - Advise on SQL query shows Missing index for the probe's condition;
  - Purge analysis empties the list.

  The `after` hook purges and removes the probe.

**Review patches (pass 1):** test and comment fixes only, no product code unless a patch needs a seam.

- P1. `Test/SqlIndexAnalysisWrite.cls` (armed): observe the skip flags' mapping to the vendor's positional arguments. `AnalysisCall` (`SqlPort.cls`) maps `SkipSystem`, `SkipInserts` and `SkipIdKeys` into `getAllSQLStmts(1,sys,ins,0,0)` and `indexUsage(1,1,0,sys,idk,ins,0)` and the other four reports' vectors; every live leg sends all true. Add (a) a live pair on the probe: a probe method holding an embedded `INSERT`, gather with `SkipInserts` false reads more statements than with true, and Index usage with `SkipIdKeys` false reads more probe rows than with true (`SkipSystem` false takes 45 s, so it is covered by (b)); (b) a recording seam on the vendor call (`AnalysisVendor` or the smallest equivalent already there) asserting the exact argument vector for gather and each of the five reports with one flag false at a time, including `SkipSystem` false without running it. Rule 19: mutation `swap tInserts and tIdKeys` and `swap tSystem and tInserts` -> the new legs red.
- P2. `ui/browser/system-explorer-sql-index-analysis.browser-spec.mjs`: each test creates its own precondition (gather, or seed) and passes alone (`--test-name-pattern`) and in any order. Rebuild and redeploy before reading any result.
- P3. Rule 19 for the bound dictionary reads: splice a name into the class read's text, observe `SqlAdviceRead`'s quote legs red, revert, record the `mutation:` line under Verification.
- P4. `Test/SqlIndexAnalysisRead.cls`: assert `ReasonFor` of the GATHER, GATHERSYSTEM, RUN and PURGE codes equals each ruled sentence literally (the sentences as `AtelierError` carries them), replacing the `[` containment check. Mutation: drop the GATHER row -> red.
- P5. `sql-index-analysis.page.spec.ts` refused-send leg: stub a reason that differs from the client constant and assert the dialog shows the stub.
- P6. `Test/SqlIndexAnalysisWrite.cls` header: remove the claim no assertion makes.

**Acceptance Criteria:**

- AC1. Given the probe's gathered statements and a report run on the throwaway, when the person opens SQL index analyzer and the agent calls `explorer.sqlindexanalysis.read`, then both answer the same rows with the matrix's columns.
- AC2. Given the throwaway, when either caller gathers, runs each of the five reports or purges and confirms, then the vendor's store reads back as the matrix says. A refused value, an unmet precondition or a changed target calls nothing.
- AC3. Given a query on SQL query, when the person chooses Advise and the agent calls `explorer.sqladvice.read` with the same statement, then both answer the plan and the same findings, each with its ruled sentences and plan excerpt. A statement that is not a query is refused before anything is prepared, and no SQL text is composed from the statement.
- AC4. Given the `slowquery` workflow, when a turn follows it, then its steps name both new reads and no write tool.
- AC5. Given the throwaway, when the browser spec runs forward and in reverse with `system-explorer-sql-runtime-stats.browser-spec.mjs`, then it passes and leaves no probe class, table or analysis rows.

### Review Findings

Code review 2026-11-26 (first review, full story, four layers, full-opus). Patches are uncommitted in the worktree.

- [x] [Review][Patch] Gather with system classes: the ruled "can take longer than the page waits" sentence (U-170 (1)) [src/OcuPilot/Api/AtelierError.cls:471, ui/src/app/core/strings.ts, EXPERIENCE.md:639, Test/SqlIndexAnalysisRead.cls:91, Screen/Tool/ExplorerSqlIndexAnalysisGather.cls:12]
- [x] [Review][Patch] DW-2882: SQL query shows "Only the first 200 findings, from at most 20 tables, are shown." when `advice.truncated`; `self-protection.test.mjs` holds both numbers to `SqlAdvice` `MAXFINDINGS`/`MAXTABLES`; `SqlAdviceRead` pins the 200/201 findings boundary [ui/src/app/core/sql-answer.ts, ui/src/app/areas/system-explorer/sql-query.page.ts]. The 20-table cut does surface as `advice.truncated`, so both halves ship.
- [x] [Review][Patch] The port's `advice.truncated` was only ever observed false: `SqlPort.AdvisorClass` seam, `Test/SqlAdviceOneTable` (cap 1) and `SqlAdviceRead.TestTheAdviceSaysWhenItsTablesAreCut` (2 tables, no cut; cap 1, cut) [src/OcuPilot/Port/SqlPort.cls]
- [x] [Review][Patch] An error status from the vendor's own method never reached a test: fixture fail switch `^||OcuPilotSqlTuningVendorFail`, and the vendor-refusal test asserts 409 VENDOR with the message in `detail` and no later call, for each write [Test/SqlTuningPortFixture.cls, Test/SqlIndexAnalysisWrite.cls]; its unreachable raised-call mutation claim replaced.
- [x] [Review][Patch] An alias holding an underscore (`(A_1)`, measured on this build) dropped the table from the advice: `MAPPATTERN`/`SCANPATTERN` take `\w+` [src/OcuPilot/Port/SqlAdvice.cls:55-58]
- [x] [Review][Patch] A gathering whose answer the page stopped waiting for (measured: HSCUSTOM with system classes, 504 at 60.1 s) left the dialog open with no sentence: the dialog now closes on a send with no sentence [ui/src/app/areas/system-explorer/sql-index-analysis.page.ts]
- [x] [Review][Patch] `SqlIndexAnalysisWrite` compared the port's namespace-wide read with probe-table counts (not self-contained): `AnalysisCounts(ns, 1)` counts every table [Test/SqlTuningProbe.cls, Test/SqlIndexAnalysisWrite.cls:179,191]
- [x] [Review][Patch] The run proposal's changed-target leg could not fail: the out-of-band index usage run includes IDKEY indices, which the proposal skips [Test/SqlIndexAnalysisWrite.cls RunOutOfBand]
- [x] [Review][Patch] The null-device test now asserts the caller's mnemonic space after a raised call [Test/SqlIndexAnalysisRead.cls]
- [x] [Review][Patch] A failed busy test could leave the lock holder job running: `OnAfterOneTest` releases it before the kill; a header claim no assertion made is removed [Test/SqlIndexAnalysisWrite.cls]
- [x] [Review][Patch] Two doc claims corrected at the code: Advise's typing prepare records a statement-index row (measured), and the store comment no longer says "before anything is prepared" [Screen/Tool/ExplorerSqlAdviceRead.cls:1-4, sql-query.store.ts:319]
- [x] [Review][Defer] AD-7's Story 21.27 clause ends "it writes nothing (measured)", but an Advise of a new statement adds its `INFORMATION_SCHEMA.STATEMENTS` row (measured 2026-11-26) [ARCHITECTURE-SPINE.md:256] — deferred: an AD amendment, DW-2883 `escalated`
- [x] [Review][Defer] A join's conditions are attributed to every scanned table [Port/SqlAdvice.cls Findings] — deferred: DW-2884 `wontfix-accepted`, harvest parity
- [x] [Review][Defer] Dictionary names are class-side, plan names SQL-side [Port/SqlPort.cls:311] — deferred: DW-2885 `wontfix-accepted` (inference)
- [x] [Review][Defer] A report run in OcuPilot during a classic-page gathering is not refused [Port/SqlPort.cls AnalysisLocked] — deferred: DW-2886 `wontfix-accepted` (inference)

Rejected:

- false: `%EXACT(Name)` read as a field named `%EXACT` -- this build's plan shows the bare field (`Test the = condition on Description`, measured).
- by ruling: the joined Gather consequence (U-170 (1)); the second invitation (U-170 (2)); the SkipSystem-off sentence's "the list shows the result" promise is the ruled text.
- spec-bound: the screen's findings show no per-finding excerpt (Batch 3 names the columns; the full plan is shown above them); AC3's "before anything is prepared" wording (the fix edits the spec; Review pass 1 recorded the residual).
- low: findings for tables past `MAXTABLES` still name them; the copy-out script takes no lock; no 403 leg for Advise (the gate is `ExplorerSqlRead`'s, pinned there); `Indexed` gates per table; the browser spec's `fresh()` asserts the store it just purged; no test reads AD-60's sanitizer output for advice (shared mechanism); no Advise side-effect test (measured instead, above); the browser Gather test's empty-list check; extra mutation lines for non-AC legs.

## Spec Change Log

- 2026-11-25, orchestrator rulings at the plan gate (veto U-165 for items 1, 2, 5, 6 and 7), authoritative over the Design Notes records:
  1. **AD-51 case** (veto U-165): allowed, add-only, written by the runner. The `UtilSQLAnalysis` calls run only inside the confirmed write, after the prohibited and shape checks; the namespace is the request's; `Report` comes from the declared five-value choice, validated before any call; the flags are coerced to 0 or 1. The null device is restored on every exit, the error and catch paths included, pinned by a test that a raised call leaves the device as it was.
  2. **AD-7** (veto U-165, U-169): allowed, add-only, written by the runner. Gather, Run report and Purge analysis run in their confirm or action request under the existing named gateway limit, as Story 24.16's writes do; no background-run kind is built (none exists for writes). Measured at Task 0: Gather on HSCUSTOM with system classes 45.5-46.3 s (x1.5 over the 60 s limit), without them 2.6-3.0 s; each report 7.7-8.8 s. Gather conditions (U-169): (a) the Gather dialog defaults "Skip system classes and routines" to on; the classic dialog's own default is recorded under Verification, and this spec says where ours differs; (b) when the box is off, the Gather consequence adds "Gathering system classes and routines takes longer than the page waits; the list shows the result when it finishes." (measure-first; reuse 24.16's person-facing sentence for its named limit instead if one exists, and cite it); (c) measured once on `ocupilot-ci`: with the gateway giving up first (limit forced low, or an equivalent measured probe), the server-side gather finishes, the list reads the new statements afterwards, and a second Gather or Run during it refuses with the `.BUSY` refusal; if the server-side gather is killed with the connection, HALT `blocked` and report; (d) the agent proposal path has the same default and sentence. Gather rewrites the namespace's class dependency data (`^oddDEP` in its code database), as the classic Gather does; its consequence ends "...and rebuilds its class dependency data." (measure-first: say only what was measured). Advice's only side effect is the statement-index row a new statement's typing prepare records (measured at code review, DW-2883).
  3. **AD-10:** decided, no new arm; Advise keeps the console's own-table `Check`.
  4. **Governance:** decided. `explorer.sqlindexanalysis.gather` `true`, `.run` `true`, `.purge` `false`.
  5. **Gate** (veto U-165): reads `%Development:USE`; writes `AtelierPort.WritePairs(ns)` plus any pair Task 0 (a) measures from the instance; never looser than the classic page, whose measured gate is recorded here.
  6. **In-stage decisions** (veto U-165): one Purge analysis removes both statements and results, and its consequence says so; no suggested DDL (no AC of this story or its epics.md block requires DDL or CREATE INDEX text, checked 2026-11-25); Advise on SQL query, query-only on both callers.
  7. **Strings** (veto U-165): accepted. The match values, the report-staleness note, the run consequence (fallback as written) and "Gather this namespace's statements before running this report." ship only as measured, otherwise reworded to what was measured; "An index analysis is already running in this namespace." ships only if Task 0 (f) shows concurrent runs collide. In the advice sentences `%1`-style values are filled only with names read from the plan or the dictionary, never with model text.
  8. **Null-device helper:** hoisted from `AdvisorPort.SetFlag` into `Kernel/Utils` as a behavior-keeping refactor, add-only (new helper, call site switched); `AdvisorPort`'s own tests rerun green before the push, in the same code head.

## Review Triage Log

### 2026-11-25 -- Review pass 1

- verdicts: 13 findings -- high 0, medium 2, low 7, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` verification-gap: the skip flags' mapping to the vendor's positional arguments (`AnalysisCall`) is never observed with a false flag -- every live leg sends all true, so a permutation is invisible. Patch P1.
  - `[medium]` `[patch]` verification-gap, and intent audit item 3: the browser spec's Run report and second Gather tests rely on the earlier tests' rows and on declaration order. Patch P2.
  - `[low]` `[patch]` verification-gap: no observed `mutation:` line for the bound dictionary reads (`Indexed`/`UncheckedRows`). Patch P3.
  - `[low]` `[patch]` verification-gap: `ReasonFor(GATHERSYSTEM) [ ReasonFor(GATHER)` passes when the GATHER row is absent. Patch P4.
  - `[low]` `[patch]` verification-gap: the page spec's refused-send leg stubs and asserts the same client constant. Patch P5.
  - `[low]` `[patch]` verification-gap: the `SqlIndexAnalysisWrite` header claims a leg no assertion makes. Patch P6.
  - `[low]` `[defer]` verification-gap: `advice.truncated` is not shown by the screen. The cap (200 findings, 20 tables) is not reachable by a plan of ordinary size, and a note needs a person-facing string no one has ruled. Recorded in `deferred:`.
  - `[low]` `[reject]` intent audit item 1: Purge analysis is a row action, so a namespace holding only gathered statements cannot be purged from the screen until a report row exists. Reachable in two steps (run a report, select its row); the fix adds a third screen-level slot to the shell beyond a direct correction, and Batch 3b chose it. Residual risk.
  - `[low]` `[reject]` intent audit item 4: the advice refusal runs after `Classify`, which prepares the statement. The instance types a statement only by preparing it, and the intent requires that typing; nothing is run or explained. Residual risk.
  - `[false]` `[reject]` intent audit item 2: no run of `system-explorer-sql-runtime-stats.browser-spec.mjs` is shown. Batch 3 and 3b each ran it forward and in reverse with the new spec (Verification).
  - `[false]` `[reject]` intent audit item 5: tests sit below the screen. The browser spec drives the screens and the unit classes drive both callers, as the matrix asks.
  - `[false]` `[reject]` intent audit item 6: advice is an independent reimplementation. The intent says SQL rebound from the MCP suite's advisor, which `SqlAdvice` is.
  - `[false]` `[reject]` intent audit item 7: gate pairs unchecked. `ClassicPageGate` and `PortGate` pin them.

## Design Notes

**Governing ADs (spine line ranges):**

- AD-7 :211-255, with the 21.25 case :246 and 24.16's: the writes run in the request (record 2).
- AD-10 :391-458, with the SQL arm :417 (no new arm, record 3).
- AD-21 :613-662, the console clause and the 21.31 rebind precedent: the advice's rebind.
- AD-29 :794 and AD-44, the classic page's resource.
- AD-36 :874 (one read for the list and the tool), AD-39 and AD-60.
- AD-51 :1214-1290, with the 21.6/21.25/21.31/21.26 cases (record 1), plus AD-52, AD-53, AD-56, AD-58 and AD-59.
- AD-66 :1533, the read-only workflow.

**Records for the orchestrator** (proposed, add-only; the runner writes each one if allowed):

1. **AD-51, Story 21.27's case** (after :1289). Recommendation: allow. Proposed text: "Story 21.27's case: `SqlPort` answers the index analyzer tools' fresh read through a port-composed `ANALYSIS` type, the target namespace's gathered statement count and each report's row count. It calls `%SYS.PTools.UtilSQLAnalysis` `clearSQLStatements` and `clearSQLAnalysisDB` with the namespace alone, `getAllSQLStmts`, and the one report the declared `Report` names (`indexUsage`, `tableScans`, `tempIndices`, `joinIndices` or `outlierIndices`), with the declared `SkipSystem`, `SkipInserts` and `SkipIdKeys` as 0 or 1 and display off, under the null device. Each call runs only inside the confirmed write, after the prohibited and shape checks. Its namespace is the request's validated namespace, never model text. No value reaches SQL text, code or a file."
2. **AD-7** (after :254). Recommendation: allow.
   - The precedent is 21.25's rebuild and 24.16's purge: the work runs in the request, the classic page's background job is not used, and the gateway timeout is a named limit.
   - Not a background run: the three existing kinds are reads, and a run that writes would be the first mutating kind.
   - Not a read like Plan with statistics: a gather and a report replace results other people read, so the agent may only propose them.
   - Proposed text: "**A gathering of SQL statements, an index analyzer report and an analysis purge (Story 21.27)** run in their confirm or action request, as an index rebuild does; the classic page's `job` is not used. One that outlasts the Web Gateway's response timeout runs to its end in that request's process, and its answer is lost (named limit). **The advice (Story 21.27)** is a read: one `$SYSTEM.SQL.Explain` of a statement the console types a query, which runs nothing, plus two bound dictionary reads; its only side effect is the fifth shape's statement-index row." The last clause is *measure-first*, Task 0 (g).
3. **AD-10: no new arm.** Recommendation: allow.
   - A report writes only the vendor's diagnostic rows, and gathering reads OcuPilot's statements without changing them. AD-46 makes OcuPilot's own records deliberately visible.
   - Advise inherits the console's own-table `Check`.
4. **Governance keys.** Recommendation: `explorer.sqlindexanalysis.gather` `true`, `.run` `true`, `.purge` `true`.
   - Every result comes back by gathering and running again, and none touches data, code or the optimizer. That matches 21.6's cached-query purge (`true`), not 21.26's statistics purge (`false`, the workload must run again).
   - The safe alternative is `.purge` `false`.
5. **Gate.** Every read and write requires `%Development:USE`, which is the classic page's `RESOURCE`. Writes add `AtelierPort.WritePairs(ns)`, and any pair Task 0 (a) measures as needed joins too. That is the classic page's gate or stricter, never looser.

**Decided in-stage:**

- **Placement.** One list at position 23 holds all five reports, with a Report column. One page action runs any report, so the Report choice is a declared value. The schema is a list filter, not a write argument. Advise is a button on SQL query, next to Plan with statistics, because the advice is about one statement and the console already owns the statement. The agent gets a read tool over the same `Plan` call.
- **One purge.** The classic page's two purges, statements and stats data, become one: Purge analysis. Reports point at gathered statements, and a gather already clears both.
- **The three flags** are declared booleans, defaulting to true as on the classic page. `SkipIdKeys` applies to Index usage only. Its value is accepted and ignored for the other reports, as the classic page ignores it.
- **The advice is query-only on both callers.** `explorer.sqlquery.read` refuses other kinds, and so does Plan with statistics. The agent's tool extends `ExplorerSqlRead` (Story 19.11).
- **No suggested DDL.** OcuPilot composes no SQL text from identifiers outside the data browser's case. A missing-index finding names the table and fields instead.
- **The not-tuned recommendation points at the table's Tune table action** (Story 21.25), not a vendor call.
- **Entity type** `sql-index-analysis` (new). The write target is `*`, and a tool's target type is its descriptor's primary type.
- **Tests.** The armed class joins `OCUPILOT_ALLOW_CONFIG_SETTINGS`, as `SqlRuntimeStatsWrite` did. The probe's SQL lives in a probe class so `getAllSQLStmts` finds it.
- **Screen reachability (Batch 3b, orchestrator ruling, in-stage).**
  - Gather statements is the descriptor's `primaryAction`, also still declared in `rowActions` and drawn once, as Databases' Check integrity is.
  - Run report is screen-level under the page's own id `SQL_INDEX_ANALYSIS_RUN_ACTION_ID` (`core/screen-actions.ts`, its label entry, a dedicated command-bar slot, the command box's declared entry and the page's `actions.register`), as Backup tasks' Freeze writes is. The dialog still sends the declared `run`.
  - Purge analysis stays a declared row action, reachable when a row exists: a purge acts on stored rows, and the instance refuses one with nothing recorded, so a slot without rows is a shell change for no gain (the simpler of the two).
  - The shipped label strings are reused and no new sentence is added.
- **Epic context reuse.** The spine and EXPERIENCE.md are newer than `epic-21-context.md` only by 21.26's add-only lines. Those were read here directly, so the context was not recompiled (the plan block's instruction).

**Strings, escalated as one batch** (none is in EXPERIENCE.md). *Measure-first* clauses ship only as measured, and any correction is reported verbatim.

1. **Title:** "SQL index analyzer" (from the classic "SQL Index Analyzer").
2. **List columns.**
   - New: "Report" · "Usage count" · "Statement type" · "Class or routine" · "Map type" · "Index fields" · "Data fields" · "Index needed" · "Match" · "Outlier field" · "Block count".
   - Reused: "Schema", "Table", "Index", "Module", "Extent size" and "Statement".
   - Siblings: the classic headers "Usage Count", "Class/Routine Name" and "Block Count".
3. **Values.**
   - Report: "Index usage" · "Table scan" · "Temporary index" · "Missing join index" · "Outlier index" (the classic buttons).
   - Match: "No match" · "Partial" · "Contains" · "Leading". *Measure-first:* Task 0 (i).
4. **Empty state:** "No index analysis is recorded in this namespace." (sibling: "No runtime statistics are recorded in this namespace.").
   - Agent invitations: "gather SQL statements for analysis" · "run an index analyzer report".
5. **Note on the list:** "Reports read the statements last gathered in this namespace. Gather them again after the code changes." *Measure-first:* Task 0 (d).
6. **Actions:** "Gather statements" · "Run report" · "Purge analysis" · "Advise" (siblings: "Purge statistics", "Plan with statistics").
   - Dialog fields: "Skip system classes and routines" · "Skip INSERT statements" · "Skip IDKEY indices (Index usage only)" (from the classic captions).
7. **Consequences:**
   - Gather: "This namespace's gathered statements and every report's results are replaced by a new gathering of its cached queries, class methods, class queries and routines."
   - Run: "This report's earlier results in this namespace are replaced." *Measure-first:* Task 0 (c). If a run clears every report, it becomes "Every report's earlier results in this namespace are replaced."
   - Purge: "This namespace's gathered statements and every report's results are removed. Gather statements again before running a report."
8. **Refusals:**
   - "This namespace holds no index analysis." (sibling: "This namespace holds no runtime statistics.")
   - "Gather this namespace's statements before running this report." *Measure-first:* Task 0 (d).
   - "Choose Index usage, Table scan, Temporary index, Missing join index or Outlier index."
   - "An index analysis is already running in this namespace." Only if Task 0 (f) needs it.
   - "The instance did not complete this index analysis." (sibling: "The instance did not purge this namespace's runtime statistics.")
   - "Advice reads a query's plan, so it takes a query only." (sibling: "Plan with statistics runs the statement, so it takes a query only.")
9. **Advice.** `%1` is the table, `%2` the fields, `%3` the index.
   - Findings: "Full table scan" · "Missing index" · "Table not tuned" · "Temporary file" · "Unused index".
   - Confidence: "High" · "Medium" · "Low". Column headers reuse "Table", plus the new "Finding", "Confidence" and "Recommendation".
   - Full table scan: "The plan reads every row of %1 and tests a condition on each one." / "Check whether an index on the condition's fields would let the plan skip this scan."
   - Missing index: "No index on %1 starts with %2, which the statement's conditions test." / "Consider an index on %1 that starts with %2, then explain the plan again."
   - Table not tuned: "The plan reports that %1 has not been tuned, so the optimizer has no statistics for it." / "Tune the table so the optimizer can choose a better plan."
   - Temporary file: "The plan builds a temporary file, as a GROUP BY, an ORDER BY or a join can need." / "Check whether an index could serve the grouping, ordering or join so the plan needs no temporary file."
   - Unused index: "This statement's plan does not use the index %3 on %1." / "Check that no other statement uses it before you remove it."
   - Note: "Advice is read from this one plan and its tables' indices. Check it against the real workload."
   - Empty: "OcuPilot found nothing to advise for this plan."
   - Unrecognized: "OcuPilot did not recognize this plan's format, so it offers no advice."
10. **Suggested prompts:** "Which indices are never used?" · "Which queries scan a whole table?" · "Which queries need an index for a join?"
11. **Command aliases:** "index analyzer" · "index analysis".
12. **The `slowquery` step:** "Read the namespace's index analysis for table scans, temporary indices and missing join or outlier indices on the tables the slow statements use, and read the advice for the slowest query; when no analysis is recorded, say so and that a person can gather statements and run a report on SQL index analyzer."

**Extend, don't copy (Rule 2/31):**

- The writes extend `SqlStatementAction` as `ExplorerSqlRuntimeStatsPurge` does, through the widened `StatementCall`. Values come from the hoisted `SqlTableTuneAction` machinery.
- The list is one more catalog statement beside `Catalog.RuntimeStats`.
- The advice extends `SqlPort.Plan`/`Explained` and `SqlConsole.HandlePlan`, and the agent tool extends `ExplorerSqlRead`. `SqlAdvice` is a harvest (renamed) with no OcuPilot sibling.
- The null-device helper is a fourth use of `AdvisorPort.SetFlag`'s pattern, hoisted once into `Kernel/Utils`. Unifying the three older copies is out of this story's footprint.
- The fixture extends `SqlTuningProbe`.

**Integration ACs:** the three write tools consume `SqlPort` through both callers (AC2), the list consumes the writes' rows (AC1), and `slowquery` consumes both reads (AC4).

- **Consumed-by:** 21.28 adds its `slowquery` read after this story's step, and may reuse `SqlAdvice` on its alternate plans (inference).
- **Consumes:** Story 21.6's `SqlPort`, `SqlStatementAction`, seam and `SqlTuningProbe`; Story 21.25's value machinery and Tune table; Story 21.26's endpoint shape and step; Story 19.6/19.11's console `Plan`, `Classify`, `Check` and `ExplorerSqlRead`; and Story 20.12's workflow catalog.

**Ledger inbox:** none. DW-2851 is a constraint, not owned.

**Contended paths (Epic 24), checked 2026-11-25:** there are commits on `EntityType`, `Prohibited`, `Baseline`, `screen-action-handler.ts`, `strings.ts`, `screen-outlet.ts`, EXPERIENCE.md, `ci-throwaway.sh`, `ConfirmNamespaceRoster` and `MappingDescriptor`, so edits there are add-only. There are none on `SqlPort`, `AtelierPort`, `AtelierError`, `Workflow` or `CompositeMintSweep`.

**Size:** 3 write tools, 2 read tools (1 derived), 1 console action and about 32 files, planned as three batches.

## Verification

**Shared surfaces** (all `(loop)`):

- System Explorer's side bar and routes: `ExplorerDescriptor`, `Navigation`, `navigation.test.mjs`, and `screen-mirror.test.mjs`'s route rows and catalog roster.
- The tool registry: `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolRoundTrip`, `ToolWrite`, `StageTwoTools`, `DeveloperFloor`, `SurfaceCoverage`, `DraftRegistry` and `SqlAgentRead`.
- Entity types: `Descriptor`'s count, `EntityRef`, and `Prohibited`'s covered types.
- Governance: `Governance` and `GovernanceBaseline`.
- Gates and catalog: `PortGate`, `ClassicPageGate`, `AtelierPortCatalogTabs`, `AtelierPortCatalogTabsLive`, `SqlCredentialMask` and `EndpointCoverage`.
- The hoisted value machinery: `SqlTuningWrite`, `SqlTableTune*` and `SqlTableSet*` classes.
- The console: `SqlConsoleRoutes`, `SqlConsoleWrite`, `SqlPortLive` and `sql-query.page.spec.ts`.
- The workflow: `WorkflowCatalog` and `suggested-prompts.test.mjs`.
- Rosters: `ConfirmNamespaceRoster`, `CompositeMintSweep`, `MappingDescriptor` `CLASSICROSTER` (the three tools declare `CLASSICPAGES`), and `ci.test.mjs` (armed rosters). Names are read from the instance.

Grep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each surface. Each test changed joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Each runs in its own foreground call with `timeout: 600000`, against `ocupilot-ci` only, one test call per message.

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/e21-kit/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SqlIndexAnalysisRead` -- expected: green. Then, one class per call, each expected green: `SqlIndexAnalysisWrite` (armed), `SqlAdviceRead`, `SqlConsoleRoutes`, `WorkflowCatalog`, `SqlRuntimeStatsRead`, `SqlTuningWrite`, `Prohibited`, and every shared-surface class above.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/screen-mirror.test.mjs tools/navigation.test.mjs tools/suggested-prompts.test.mjs tools/self-protection.test.mjs tools/proposal-view.test.mjs tools/ci.test.mjs` -- expected: green.
- `(loop)` Four steps, then the specs:
  1. `cd ui && npm run build`
  2. `npm run test:components`
  3. `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  4. `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-sql-index-analysis.browser-spec.mjs browser/system-explorer-sql-runtime-stats.browser-spec.mjs`

  Expected: green, and green in reverse order.
- `(once)` `cd ui && npm run test:tools` -- expected: green (EXPERIENCE.md changes).
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Task 0 results (measured on ocupilot-ci)** -- 2026-11-25, IRIS 2026.2 build 221U, `USER` and `HSCUSTOM`; every line observed unless marked (inference). Probe schema, users, roles and rows are removed and read back absent (statement index cleaned with `$SYSTEM.SQL.Statement.Clean()`).

- **Gate.** The classic page's compiled `RESOURCE` is `%Development:USE`, with no `EDITRESOURCE`.
- **(a) Pairs.** A principal holding `%Development:USE` and `WritePairs(ns)` (USER: `%DB_USER` RW, `%DB_ENSLIB` R, `%DB_IRISLIB` R; HSCUSTOM adds `%DB_HSCUSTOM` RW, `%DB_HSLIB` R) gathered, ran all five reports and purged in both namespaces with no `<PROTECT>`, status error or no-op, and read both tables and `%Dictionary.CompiledClass`/`CompiledIndex` (bound `?`) through an unchecked `%Prepare(text, 0)`.
  - The same reads through a checked prepare answer SQLCODE -99, and so does Explain on a table the principal holds no SQL privilege on (as the console).
  - `^%sqlcq(ns,"PTools","util")` lives in database `IRISLOCALDATA` (`%DB_IRISLOCALDATA`, public Read). A principal holding `%Development:USE` and READ pairs only (USER) ran the same seven calls; its direct `Set` of `^%sqlcq` and `^oddDEP` raised `<PROTECT>`, so the vendor writes under its own elevation.
  - No pair beyond `%Development:USE` + `WritePairs(ns)` is needed; the WRITE pair is policy, not a vendor demand. A principal without `%Development` could not open a session, so that arm is unmeasured.
- **(b) Durations (HSCUSTOM, 1,130 statements gathered).** Gather `SkipSystem` false 45.5 / 45.7 / 46.3 s (x1.5 = 68-69 s, over 60 s); `SkipSystem` true 2.6-3.0 s; USER `SkipSystem` false 24-25 s.
  - Each report 7.7-8.8 s (x1.5 = 13 s). A report on an empty store with `SkipSystem` false 53.7 s (x1.5 = 81 s, over 60 s). Purge under 0.01 s.
  - `SkipInserts` does not move gather time (46.3 s with it true, 2.7 s with `SkipSystem` true).
- **(c) Clear scope.** A report's `clearData` removes only its own report's rows (a second Table scan left Index usage, Missing join index and Outlier rows). `getAllSQLStmts` clears no analysis rows and `clearSQLStatements` clears none either; only `clearSQLAnalysisDB` does, so Gather must call both clears as the classic page does.
- **(d) Empty store.** All five reports answer rows with no statements gathered (`getSQLStmts` 0): each gathers statements itself with its own skip flags and leaves them stored (USER 0 -> 19 statements; HSCUSTOM `SkipSystem` false 0 -> 1,130, `SkipSystem` true 0 -> 69). The self-gather is real for all five, not only `indexUsage`; the vendor never refuses.
  - Index usage with `SkipSystem` false returns an error status (`SQLCODE=100 ... Failed to UPDATE ... UtilSQLAnalysisDB`) in both namespaces and leaves partial rows; with `SkipSystem` true it is clean. That is the real 409 `SQL.INDEXANALYSIS.VENDOR` path.
- **(e) Device output.** With `%request` an object, `getAllSQLStmts` and each of the five reports (display 0) write 43 bytes (`<pre style="font-family: 'Courier New'; ">`) to the current device; both clears write nothing; with `%request` not an object nothing is written. The null device swallowed all of it (0 bytes captured), self-gather and error paths included.
- **(f) Concurrency.** A report holds `^%sqlcq(ns,"PTools","util","SQLAnlsys")` for its whole run (held from t=0 to 7.5 s); Gather holds nothing (free for all 45.7 s).
  - Two concurrent reports: the second waits 5 s, then returns an error status ("database lock could not be acquired"), and the first finishes intact (303 rows). Two concurrent gathers serialize (2.6 s and 5.2 s) and leave 69 statements.
  - A Gather started during a running report wiped its input: the report ended OK 1.5 s into an 8 s run with 0 rows. Purge during a report not observed (inference: same).
- **(g) Side effects.** Gather, the five reports, and Explain add no statement-index rows and no cached queries (counts constant); Explain of two new statements plus the dictionary reads wrote nothing at all (zero journal records, USER and HSCUSTOM), so Advise has no side effect, and the AD-7 clause "its only side effect is the fifth shape's statement-index row" is unsupported.
  - **Loud: Gather writes beyond the vendor's result stores.** Journal records (process-attributed) show it kills and sets `^oddDEP` (class dependency data) in the namespace's code database on every gather: USER `SkipSystem` true 542 kills + 1,084 sets; `SkipSystem` false 107,329 + 214,658. The reports write only `^%sqlcq` PTools nodes.
- **(h) Plan fixtures.** Ten captured plans (verbatim, CR LF lines) with an index of markers are in `.coordination/e21-kit/21-27/impl/plans/` (README.txt): full scan with `Read master map ... looping on` and `Test the ... condition on`, `Warning:` / `Table ... is not tuned.` (and the plural `Tables ... and ... are not tuned.`), index map reads, temp-file lines and the tuned counterparts. An unrecognized plan is not captured.
- **(i) Match flags (`PT_getIndexFlagInfo`, join and outlier alike).** 0 No Match, 1 Partial Match, 2 Contains Match, 3 Leading Match, 4 Exact Match; 5 answers empty. The ruled names (No match, Partial, Contains, Leading) are flags 0-3, with 4 excluded.
- **Re-dispatch measurements (2026-11-25).**
  - Classic dialog default: "Skip system classes and routines" is checked on a first open (`IndexAnalyzer.cls` :777 `$lb(1,1,1,"")` and :277 `setValue(1)`), as are the other two, so ours (all three on) does not differ; the classic page remembers the last choice per user and namespace, ours does not.
  - Gateway gives up first (USER, `SkipSystem` false, a probe page behind the web gateway, client dropped at 5 s): the server-side gather ran to its end (29.2 s), `^ZZProbe227("end")` was set after the client had gone, and the statements read 55 at 8 s and 705 afterwards (before: 0). The gather is not killed with the connection. The `.BUSY` half (a second Gather or Run during it) is measured on the real endpoint after Batch 1 (below). Probe classes and globals removed and read back absent (statements 0).: the vendor never refuses, so the refusal is OcuPilot's, on `Statements`, for all five reports (recommendation: it keeps a report from self-gathering, 81 s worst case); "Gather this namespace's statements before running this report." ships as an instruction. Run consequence (c): "This report's earlier results in this namespace are replaced." ships as ruled. `BUSY` (f): needed; the port takes the lock with timeout 0 around Gather, Run and Purge. Match names (i): ship as ruled. In the request (b): Gather, reports and Purge all run in their request under the named gateway limit (Spec Change Log item 2, veto U-169). Advise writes nothing (g). Gather also rewrites `^oddDEP` in the namespace's code database; its consequence says so (Spec Change Log item 2).

**Batch 1 results (2026-11-25, `ocupilot-ci`; every line observed unless marked (inference)).**

- **24.16's sentence.** No person-facing sentence for the Web Gateway's named limit exists in `AtelierError`, `InteropError` or `strings.ts` (searched for "longer than", "page waits", "gateway" and "outlasts"), so the ruled sentence ships as ruled.
- **Gather's sentence, as written.** The ruled consequence is combined with the ruled ending into one grammatical sentence: "A new gathering of this namespace's cached queries, class methods, class queries and routines replaces its gathered statements and every report's results, and rebuilds its class dependency data." (`SQL.INDEXANALYSIS.GATHER`). With `SkipSystem` false the code is `SQL.INDEXANALYSIS.GATHERSYSTEM`: the same sentence and "Gathering system classes and routines takes longer than the page waits; the list shows the result when it finishes." The Batch 1 wording is the lead's to veto.
- **Concurrency (ruling item 2 (c)).** A gather with `SkipSystem` false in `USER` ran 27.8 s in a job calling the port (an equivalent probe for a client that went away), and was not killed: the statements read 44 at 4 s and 716 afterwards (0 before). During it a second Gather, Run and Purge each answered 409 `SQL.INDEXANALYSIS.BUSY` with nothing called; after it all three answered 200. `Report` and each flag are judged before the lock is taken.
- **Defaults.** An absent flag is sent as 1 and a flag sent `false` as 0, read from the call the seam recorded (`GATHER|{"SkipSystem":1,"SkipInserts":1}`). The Gather dialog's default is Batch 3's.
- **Null device.** `Kernel/Utils.CallWithNullDevice` holds the pattern `AdvisorPort.SetFlag` had; `SetFlag` calls it, and `AdvisorWrite` (the instance's own call, 5/5) and `AdvisorRead` (9/9) are green. A call that raises answers its status and leaves the device, mnemonic space, namespace and the null device's open state as they were (`SqlIndexAnalysisRead`).
- **Placement and wording.** `explorerSqlIndexAnalysisEmptyAgent` carries the first ruled invitation, "gather SQL statements for analysis"; the descriptor takes one invitation, so "run an index analyzer report" has no place yet. The `slowquery` step ships with the ruled sentence and the index analysis read; Batch 2 adds `explorer.sqladvice.read` to its reads.
- **Shape.** Three tools extend a new `SqlIndexAnalysisAction` over `SqlStatementAction`, which now carries the value machinery `SqlTableTuneAction` had (that class keeps its two parameters). Each tool's `FINGERPRINTSUBJECT` names its values, since the stored payload keeps only the subject's members. The `ANALYSIS` read answers the four values as `null`.
- **Loop.** `LOADERRORS=0`. `SqlIndexAnalysisRead` 7/7, `SqlIndexAnalysisWrite` 9/9 (armed; the probe class, table and both namespaces' analysis read back absent), and green after the roster edits: `ExplorerDescriptor` 17, `Descriptor` 60, `Governance` 14, `GovernanceBaseline` 5, `ReadTool` 28, `ToolWrite` 33, `ToolRoundTrip` 2, `ClassicPageGate` 9, `MappingDescriptor` 6, `ConfirmNamespaceRoster` 3, `CompositeMintSweep` 5, `SurfaceCoverage` 4, `DraftRegistry` 9, `StageTwoTools` 4, `ReadDescriptions` 9, `Prohibited` 22, `WorkflowCatalog` 10, `EntityRef` 9, `EndpointCoverage` 2, `RemovalRowsSweep` 7, `ToolDispatch` 19, `ClaimReach` 2, `Navigation` 14, `PortGate` 4, `DeveloperFloor` 10, `SqlCredentialMask` 4, `AtelierPortCatalogTabs` and `AtelierPortCatalogTabsLive` 8 each, `SqlConsoleRoutes` 8, `SqlPortLive` 16, `SqlAgentRead` 7, `SqlTuningWrite` 4, `SqlStatementRead` 5, `SqlStatementWrite` 7, `SqlTableTune` 13, `SqlTableFixedStats` 11, `SqlTableFixedStatsCard` 4, `SqlTableOutlierValues` 4, `SqlTableRead` 7, `SqlIndexRebuild` 10, `SqlCachedQueryPurge` 4, `SqlRuntimeStatsRead` 10, `SqlRuntimeStatsWrite` 8. `check-objectscript` and `lint-docs` clean; `screen-mirror --check`, `classic-links`, `client-lint`, `field-lists --check` and `ipm-manifest --check` clean; the six `node --test` files 395/395; `npm run test:tools` 2415/2415 once the README's count and clause were updated; `npm run test:components` 3966/3966.

**Mutations (Rule 19), one per AC, each recorded here as `mutation: … -> …` when observed:**

- AC1: `Catalog.IndexAnalysis` drops the `sqltext` kind, or keeps flag-4 rows -> `SqlIndexAnalysisWrite`'s list leg red.
- AC2: `RUNREPORT` calls `tableScans` for every `Report` -> the per-report leg red. The purge tool's `Holds` drops its precondition -> the nothing-to-purge leg red.
- AC3: `Plan` with `pAdvise` skips the query-only check -> the `UPDATE` leg red. `SqlAdvice` drops the leading-field comparison -> the missing-index fixture leg red.
- AC4: `slowquery` loses the step -> `WorkflowCatalog` red.
- AC5: the page drops its `actions.register` of Run report -> after rebuild and redeploy, the browser spec red.
- Batch 1, each applied on `ocupilot-ci`, observed red, reverted (md5 of the touched files equal to before) and the source reloaded, 2026-11-25:
  - AC1: mutation: `CATALOGINDEXANALYSISQUERY` lists every join row (`JoinIndexFlag < 4` dropped) -> `SqlIndexAnalysisWrite.TestTheListAndTheAgentsReadAnswerTheSameRows` red on the row count and the join count, and `SqlIndexAnalysisRead.TestTheListsStatementAndRowMapAreFixed` red.
  - AC1: mutation: the row map drops `sqltext` from the statement -> `SqlIndexAnalysisRead.TestTheListMapsTheVendorsRowsAndKeepsToTheCap` and `TestTheListsStatementAndRowMapAreFixed` red, and `SqlCredentialMask.TestAPlantedStatementIsMaskedInTheCatalogTabs` red on `Catalog.IndexAnalysis`.
  - AC2: mutation: `AnalysisCall` runs `tableScans` for `IU` -> `SqlIndexAnalysisWrite.TestTheScreenGathersAndRunsEachReport` and `TestTheAgentGathersAndRunsEachReportAndAnAbsentFlagIsTrue` red.
  - AC2: mutation: the purge tool's `Holds` answers 1 -> `SqlIndexAnalysisWrite.TestAPurgeRemovesTheNamespacesAnalysisOnBothCallers` red on both nothing-to-purge assertions.
  - AC2: mutation: `AnalysisCall` leaves a purge's report rows (skips `clearSQLAnalysisDB`) -> the purge test red on the rows read back.
  - AC2: mutation: the base `FINGERPRINTSUBJECT` drops the row counts -> `TestAChangedTargetRefusesTheConfirmAndTheMintCallsNothing` red on the purge's confirm (answered 200).
  - AC2, ruling 1 (`.BUSY`): mutation: `AnalysisLocked` takes no lock -> `TestABusyNamespaceRefusesEachWriteWithNothingCalled` red on all three writes. mutation: `AnalysisWrite` never releases the lock -> the purge, vendor-refusal and class-level legs red.
  - AC2, ruling 1 (values before any call): mutation: `AnalysisValues` sends a report unchecked -> `SqlIndexAnalysisRead.TestTheGatesAndShapesRefuseBeforeAnyCall` red on four reports and on "no call". mutation: `SqlIndexAnalysisAction.ValueProblem` answers `""` -> `TestBothCallersRefuseABadValueBeforeAnythingIsStored` red.
  - AC2, ruling 1 (device on every exit): mutation: `CallWithNullDevice` returns from its `Catch` without restoring -> `TestAVendorCallUnderTheNullDeviceLeavesTheProcessAsItWasFound` red (the run's own output is lost, as the process stays on the null device).
  - Gather's consequence: mutation: `ExplorerSqlIndexAnalysisGather.Consequence` ignores `SkipSystem` -> `TestTheScreenAndTheToolsDeclareTheirShape` red.
  - AC4 (Batch 1 half): mutation: `slowquery` loses the index analysis step -> `WorkflowCatalog.TestTheSlowQueryWorkflowReadsTheStatementIndexAndWritesNothing` red.

**Batch 2 results (2026-11-25, `ocupilot-ci`; every line observed unless marked (inference)).**

- **Shape.** `Port/SqlAdvice` holds the heuristics with no call to the instance (`Recognized`, `Tables`, `Findings`). `SqlPort.Plan` gained `pAdvise`, `Advised`, the public gated `Indexed` and `UncheckedRows`, and `ADVICECLASSQUERY` and `ADVICEINDEXQUERY` bind every value with `?`. `SqlConsole` reads a boolean `advise` on the plan route alone. `ExplorerSqlAdviceRead` extends `ExplorerSqlRead` and takes `statement`, so SQL query's context lists it. The ten captured plans are embedded in `SqlAdviceRead` as `$ListBuild` lines joined by CR LF and compared byte for byte with the captured files (all ten equal).
- **Decided in-stage, none a person-facing string.**
  - The refusal of a statement that is not a query (`EXPLORER.SQL.ADVICE`, string 8) runs after `Classify`, as Plan with statistics' does: the classification prepares the statement, and nothing is explained or run.
  - Advise with `stats` is refused as `EXPLORER.SQL.INPUT` on the route and the port.
  - An index with no field (the extent index, `DDLBEIndex`) is never called unused, and a system-schema table is not called not tuned.
  - The not-tuned line is read wherever it stands in the plan's warnings, because a web process's plan adds an NLS collation line before it.
  - `Kind` and `Confidence` are the lower-case codes; an unused index's excerpt is the plan's map-read lines. The advice answer also carries `truncated` (AD-36).
- **Gaps (inference).** A condition is attributed to every scanned table of the plan, as the harvest source does, so a join can name a table for a field of another. A table the dictionary holds no class for gets no index finding. The plan text reaches the model through AD-60's sanitizer as every tool result does; no test of this story reads the sanitizer's output.
- **Loop.** `LOADERRORS=0`. `SqlAdviceRead` 10/10; green after the roster edits: `ReadTool` 28, `ReadDescriptions` 9, `SurfaceCoverage` 4, `ToolEmit` 11, `ToolRoundTrip` 2, `StageTwoTools` 4, `DeveloperFloor` 10, `EndpointCoverage` 2, `ToolDispatch` 19, `ExplorerDescriptor` 17, `WorkflowCatalog` 10, `SqlConsoleRoutes` 8, `SqlConsoleWrite` 6, `SqlPortLive` 16, `SqlAgentRead` 7, `SqlCredentialMask` 4, `DraftRegistry` 9, `ConfirmNamespaceRoster` 3, `CompositeMintSweep` 5, `MappingDescriptor` 6, `ClassicPageGate` 9, `ToolWrite` 33, `RemovalRowsSweep` 7, `GovernanceBaseline` 5, `Navigation` 14, `Descriptor` 60, `Prohibited` 22, `ClaimReach` 2, `PortGate` 4 (a `<table>` row for `SqlAdvice`), `SqlIndexAnalysisRead` 7, `SqlIndexAnalysisWrite` 9, `SqlRuntimeStatsRead` 10, `SqlTuningWrite` 4. `check-objectscript` 0 problems; the six `node --test` files 395/395; `npm run test:tools` 2415/2415; `screen-mirror`, `field-lists` and `ipm-manifest` `--check` clean.
- Batch 2, each applied on `ocupilot-ci`, observed red, reverted (md5 of `SqlAdvice`, `SqlPort`, `SqlConsole` and `Workflow` equal to before) and the source reloaded:
  - AC3: mutation: `Plan` skips the query-only check for `pAdvise` -> `SqlAdviceRead.TestAStatementThatIsNotAQueryAndOwnTablesAreRefused` red on the agent, route and port legs.
  - AC3: mutation: `SqlAdvice.Findings` drops the leading-field comparison -> `TestTheLeadingFieldDecidesWhetherAnIndexIsMissing` red on the first leg. mutation: `Leading` takes the last field of an index -> the same test red on its first two legs.
  - AC3: mutation: a missing index is high for every condition set -> `TestTheConfidenceOfAMissingIndexFollowsItsConditions` red on the range, mixed and two-field legs.
  - AC3: mutation: the temporary-file pattern drops `(?: once)?` and the warning pattern reads only `Table` -> `TestTemporaryFilesAndJoinsAreRead` red on the join leg, the plural leg and the once leg.
  - AC3: mutation: `Filled` fills `%1` from the fields -> `TestAFullScanComesWithMissingIndexNotTunedAndUnusedIndex` red on every sentence. mutation: `Recognized` answers 1 -> `TestPlansWithNothingToAdviseOnAndPlansItDoesNotRecognize` red. mutation: `Add` never cuts -> `TestSystemTablesAreNeverAdvisedAnIndexAndTheFindingsAreCapped` red.
  - AC3: mutation: `Advised` answers no findings -> `TestTheProbeTableAnswersTheSameFindingsOnBothCallers` red. mutation: `SqlConsole.Body` refuses the `advise` key -> the same test's route leg and the two route refusals red. mutation: `Indexed` reads system schemas -> `TestTheDictionaryReadsBindTheNamesTheyAreGiven` red on its system leg. mutation: the tool's description loses the ruled note -> `TestTheToolDeclaresItsShape` red.
  - AC4: mutation: `slowquery` loses the advice read from its step -> `WorkflowCatalog.TestTheSlowQueryWorkflowReadsTheStatementIndexAndWritesNothing` red on the index analysis and advice step.

**Batch 3 results (2026-11-25, `ocupilot-ci`; every line observed unless marked (inference)).**

- **Shape.** `SqlIndexAnalysisPage` registers Gather statements, Run report and Purge analysis on `*`. Purge analysis uses the handler's warning (`WARNING_CONSEQUENCES`). Gather statements and Run report open the page's own `SqlIndexAnalysisDialog`, which states the consequence, asks for the report (Run) and the boxes, each on at open, and sends the values as `'true'`/`'false'` through `sendFor`; the handler's one-value warning dialog cannot ask for two or four values. A gathering with "Skip system classes and routines" off shows the `GATHERSYSTEM` sentence. A refusal stays in the dialog as the server's sentence. Advise posts `{statement, advise: true}` to the plan route; the findings come back inside the plan answer and show under the plan, one row each, with the finding and its sentence in the first cell (no column header for the sentence is ruled).
- **Strings.** Only the ruled set. The consequence and refusal sentences are copies of `AtelierError`'s and are pinned equal to them by `self-protection.test.mjs`, with the card codes pinned in `proposal-view.test.mjs`. High and Low confidence and the Recommendation header reuse `taskPriorityHigh`, `taskPriorityLow` and `securityAdvisorColumnRecommendation`, since every value in `strings.ts` is unique. The ten advice sentence templates are composed on the instance and have no client copy, so they are not in the new EXPERIENCE.md Fixed strings row, which `strings.test.mjs` would refuse (each literal must exist in `strings.ts`). The row's addition moved one citation: `taskCreate`'s now reads `EXPERIENCE.md:679`.
- **Unplaced.** The second agent invitation, "run an index analyzer report", has no home: the descriptor takes one empty-state invitation (Batch 1 placed "gather SQL statements for analysis").
- **Reachability.** Gather statements is the descriptor's primary action and Run report a screen-level action, so both start from an empty list (Batch 3b results). `SqlTuningProbe.SeedAnalysis` only gives Purge analysis a row to select.
- **Client consumers grepped** for the changed answer shape and the new keys across `ui/browser`, `ui/tools` and `ui/src`: `sql-answer.ts` (the proposal card's `sqlOutcomeLines`, `agent-sql.browser-spec.mjs` ran green), `sql-query` (`system-explorer-sql-query.browser-spec.mjs` ran green), and the shell tables `SCREEN_ACTION_DESCRIPTORS`, `UNDRAWN_ACTIONS`, `WARNING_CONSEQUENCES`.
- **Loop.** `LOADERRORS=0` after the probe helper. `SqlIndexAnalysisWrite` 9/9. `npm run build` clean (initial total 2.31 MB, under the 2,500 kB warning). `npm run test:components` 3979/3979 (13 new). `npm run test:tools` 2415/2415. The six `node --test` files 395/395. `check-objectscript` 0 problems, `lint-docs` clean, `screen-mirror` regenerated with no change. Browser: `system-explorer-sql-index-analysis` 5/5, `system-explorer-sql-runtime-stats` 4/4, run in both orders; `system-explorer-sql-query` 3/3 and `agent-sql` 2/2. The index analyzer spec's `after` read back no gathered statement and no row of any report.
- Batch 3, each applied, observed red, reverted (md5 of the touched files equal to before, `git diff --stat` unchanged) and the bundle rebuilt and redeployed:
  - AC5: mutation: `SqlIndexAnalysisPage` drops its `actions.register` of Run report -> after rebuild and redeploy, the browser spec red: AC1 (the bar offers no Run report) and AC2 (the wait for the button times out).
  - AC3, client: mutation: `SqlQueryState.body` drops the `advise` branch -> `sql-query.page.spec.ts` "advises" red on the posted body.
  - AC3, client: mutation: `adviceOf` reads `detail` for `Detail` -> the same test red on the finding's first cell.
  - AC1, AC2, client: mutation: the dialog sends `'IU'` for every report -> `sql-index-analysis.page.spec.ts` "a report run asks for the report and the three choices" red on the posted values.

**Batch 3b results (2026-11-25, `ocupilot-ci`; every line observed unless marked (inference)).** Closes Batch 3's reachability risk.

- **Shape.**
  - `ExplorerSqlIndexAnalysis` declares `primaryAction` `gather`, still in `rowActions`, and the bar draws it once, with no row selected.
  - Run report is `SQL_INDEX_ANALYSIS_RUN_ACTION_ID` (`index-analysis-run`): its `ACTION_LABELS` entry, the command bar's dedicated slot (`ocu-command-bar-index-analysis-run`, listed in `UNSTYLED_CLASS_HOOKS` as the Backup tasks' two are), the command box's declared entry and the page's `actions.register`. The dialog still sends the declared `run`, so the server and the tools are unchanged.
  - Purge analysis stays a row action (Design Notes, "Screen reachability"). No new sentence; the mirror regenerated with one changed line and `Titles.cls` unchanged.
- **Browser spec.**
  - It no longer seeds the namespace. `MakeAnalysis` leaves it with no analysis, `before` asserts that, and the tests reach Gather statements and Run report from the empty list: empty-list reachability, Gather from the empty list, Run report Index usage then Table scan, Advise, a second Gather replacing the reports, and Purge.
  - `SeedAnalysis` stays for Purge analysis alone, which needs a row to select. The `after` hook still removes the probe class and table and asserts the statements and the five reports' rows read back 0.
- **Loop.** `LOADERRORS=0`. `npm run build` clean. `npm run test:components` 3982/3982 (3 new). `npm run test:tools` 2415/2415. The six `node --test` files 395/395. `check-objectscript` 0 problems, `lint-docs` clean, `screen-mirror --check` up to date. `ExplorerDescriptor` 17, `Descriptor` 60, `ClassicPageGate` 9, `Navigation` 14, `MappingDescriptor` 6, `SqlIndexAnalysisRead` 7, `SqlIndexAnalysisWrite` 9 (armed). Browser: `system-explorer-sql-index-analysis` 6/6 and `system-explorer-sql-runtime-stats` 4/4 in both orders, `backup` 3/3 and `account-and-filter` 4/4 (the command bar's other slots).
- Batch 3b, each applied, observed red, reverted (md5 of the touched file equal to before, `git status --short` and `git diff --stat` unchanged):
  - AC5: mutation: `SqlIndexAnalysisPage` drops its `actions.register` of Run report -> after rebuild and redeploy, the browser spec red: AC1 (Run report is not offered), and the Run and second Gather tests (their wait times out); the bundle was rebuilt and redeployed after the revert and the spec read green.
  - AC5, client: mutation: the command bar's template drops the index analysis slot (`@if (false)`) -> `command-bar.spec.ts` "Story 21.27: with nothing selected the bar offers Gather statements as the primary" red.
  - AC5, client: mutation: the mirror's `primaryAction` for the screen is empty -> `sql-index-analysis.page.spec.ts` "offers Gather statements as the primary action and Run report at screen level" red. A descriptor with no primary draws Gather statements as a row action held by "Select a row first", which the spec's AC1 reads as `aria-disabled` (not run in the browser: a hand-edited mirror fails the build's own `--check`).
  - AC5, client: mutation: `actionCandidates` never lists the index analysis line -> `command-box.spec.ts` "Story 21.27: SQL index analyzer's Run report is listed at screen level and runs on a click" red.

### Review patches pass 1 results

- P1 done. `SqlTuningPortFixture.AnalysisVendor` records `method(arguments)` while `^||OcuPilotSqlTuningVendorArmed` is set (else the production call); `SqlIndexAnalysisWrite` adds `TestEachSkipFlagReachesItsPositionOfTheVendorCall` (gather and the five reports, each flag false in turn, `SkipSystem` false without running) and `TestAFlagSentFalseChangesWhatTheInstanceReads` (the probe class gains an `Add` method holding an `INSERT`; gather 30 statements skipping inserts, more including them; Index usage more probe rows with `SkipIdKeys` false). No product code changed. Class 11/11 green.
  - mutation: `AnalysisCall` swaps the `tInserts` and `tIdKeys` keys -> both new tests red (recording: SkipInserts and SkipIdKeys legs; live: both comparisons 30 then 30, 3 then 3). mutation: swaps `tSystem` and `tInserts` -> recording test red (SkipSystem and SkipInserts legs). Each reverted (md5 of `SqlPort.cls` equal to before), reloaded, green.
- P2 done. The browser spec's `fresh()` and `seed(run)` give each test its own start; every test passes alone (`--test-name-pattern`), the file passes whole, and `system-explorer-sql-runtime-stats` then this spec as separate runs and the two in one run pass. `SeedAnalysis` takes an optional `pRun` (default 1, behavior unchanged).
  - mutation: the Run report test starts from `fresh()` instead of `seed(false)` -> that test alone red (the run is refused with nothing gathered). Reverted.
- P3 done. mutation: `Indexed` splices the schema and table into the class read's text instead of binding them -> `SqlAdviceRead.TestTheDictionaryReadsBindTheNamesTheyAreGiven` red on the three quote legs. Reverted (md5 equal), reloaded, class 10/10 green.
- P4 done. `SqlIndexAnalysisRead` compares `ReasonFor` of GATHER, GATHERSYSTEM, RUN and PURGE with the ruled sentences literally. mutation: `AtelierError.SqlReasonFor` drops the GATHER row -> "the gather's sentence is the ruled one" alone red. Reverted (md5 equal); class 7/7 green.
- P5 done. The refused-send test stubs a sentence no client string holds and asserts the dialog shows it. mutation: the page sets a client sentence on a refusal -> that test red. Reverted (md5 equal); file 11/11 green.
- P6 done. The `SqlIndexAnalysisWrite` header no longer claims a value outside its shape, and now names the skip flag mapping.

### Code review results (2026-11-26, `ocupilot-ci`)

- **Follow-up flag, live leg.** One full gather with `SkipSystem` false through the screen route on HSCUSTOM: the Web Gateway answered 504 at 60.1 s, the server-side gather ran on (statements 820 at 61 s, 1,249 at about 110 s, then steady; 0 before), against 69 with `SkipSystem` true (Task 0 (b)), so the vendor received the flag as 0. A purge then answered 200 (the lock was free) and the namespace read back 0. No 45 s leg was added to the suite; the recording seam stays the pin.
- **Advise's side effect.** An Advise of a new statement added its row to USER's `INFORMATION_SCHEMA.STATEMENTS` (the typing prepare Plan shares); DW-2883.
- mutation: `SqlAdvice.MAXTABLES` 20 -> 21 -> `self-protection.test.mjs` "advice-cut note names the advice's own two caps" red. Reverted.
- mutation: `adviceOf` answers `truncated: false` -> `sql-query.page.spec.ts` "says when the instance cut the advice at its caps" red. Reverted.
- mutation: `SqlPort.Advised` answers `truncated` from the findings' cut alone -> `SqlAdviceRead.TestTheAdviceSaysWhenItsTablesAreCut` red. mutation: the alias patterns back to `[A-Za-z0-9]+` -> `TestTemporaryFilesAndJoinsAreRead` red on the underscore leg. Both reverted (diff equal to the patch), reloaded.
- mutation: `AnalysisCall` makes the gather's third call whatever the second answered -> `SqlIndexAnalysisWrite.TestTheInstancesRefusalIsTheVendorRefusalAndTheLockIsReleased` red on the gather's vendor status legs. Reverted, reloaded.
- mutation: `SqlIndexAnalysisPage.onSubmit` keeps the dialog open on a send with no sentence -> `sql-index-analysis.page.spec.ts` "closes the dialog when the page stops waiting" red. Reverted.
- Not falsifiable here: dropping `CallWithNullDevice`'s mnemonic restore left the mnemonic assertion green (inference: `Use` of a device keeps the mnemonic it was opened with), so the assertion pins the property and no mutation line is claimed.
- **Loop on HEAD plus the patches.** `LOADERRORS=0`. Green, one class per call: `SqlAdviceRead` 11, `SqlIndexAnalysisRead` 7, `SqlIndexAnalysisWrite` 11 (armed), `PortGate` 4, `AdvisorRead` 9, `AdvisorWrite` 5, `SqlConsoleRoutes` 8, `SqlPortLive` 16, `WorkflowCatalog` 10, `ConfirmNamespaceRoster` 3, `CompositeMintSweep` 5, `MappingDescriptor` 6, `ClassicPageGate` 9, `SurfaceCoverage` 4, `ToolWrite` 33, `ReadTool` 28, `DraftRegistry` 9, `ToolEmit` 11, `ToolRoundTrip` 2, `StageTwoTools` 4, `RemovalRowsSweep` 7, `EndpointCoverage` 2, `ToolDispatch` 19, `GovernanceBaseline` 5, `Navigation` 14, `Descriptor` 60, `Prohibited` 24, `ClaimReach` 2, `ReadDescriptions` 9. `npm run test:tools` 2417/2417; `npm run build` clean (initial 2.32 MB); `npm run test:components` 343 files green; `check-objectscript` 0 problems; `lint-docs` clean. Browser, after rebuild and redeploy: `system-explorer-sql-index-analysis` with `system-explorer-sql-runtime-stats` 10/10 forward and 10/10 reversed; `system-explorer-sql-query` 3/3.

## Auto Run Result

Status: done
Blocking condition: none

This pass (re-dispatch after the Task 0 rulings, baseline 23762d9606527ff542274e0d939ba0e17b3b0c6e):

- **Implemented.** The two new measurements (the classic dialog's default; the gather finishing after the gateway gave up, with the `.BUSY` half on the real endpoint) are under Verification. Batch 1 (analyzer list, Gather, Run report and Purge analysis under the namespace lock, null-device helper in `Kernel/Utils`, three tools, descriptor, entity type, governance, rosters), Batch 2 (`SqlAdvice`, `Plan` with advise on both callers, `explorer.sqladvice.read`, `slowquery` step naming both reads), Batch 3 (the page, the dialog, Advise on SQL query, strings, browser spec) and Batch 3b (Gather statements as the primary action, Run report as a screen-level action) are committed as 519defe98, e25a5b351, f67156f5d and 0d0bb32fd; review patches P1-P6 ride the finalize commit.
- **Review.** Pass 1, 13 findings (Review Triage Log): patched 2 medium and 4 low (test and comment fixes), deferred 1 low (`advice.truncated` not shown), rejected 2 low and 4 false, each with its reason in the log.
- **Verification.** On `ocupilot-ci`: `LOADERRORS=0`; `SqlIndexAnalysisWrite` 11, `SqlIndexAnalysisRead` 7, `SqlAdviceRead` 10, `AdvisorWrite` 5, `AdvisorRead` 9, `ConfirmNamespaceRoster` 3, `PortGate` 4, `SqlTuningWrite` 4, `SqlConsoleRoutes` 8, `WorkflowCatalog` 10, `SqlRuntimeStatsRead` 10, `Prohibited` 22, all green; `npm run build` clean, `test:components` 3982, `test:tools` 2415, the six node files 395, `check-objectscript` 0 problems; browser `system-explorer-sql-index-analysis` 6 and `system-explorer-sql-runtime-stats` 4, both orders. The runner owns the full sweep, the smoke and the fresh check.
- **Follow-up review recommended: true.** Two medium findings were patched. The unverified risk: `SkipSystem` false reaches the vendor's first positional argument only through the recording seam, never against the vendor, because that gather takes 45 s.
- **Residual risks.** Purge analysis is a row action, so a namespace holding only gathered statements is purged after a report row exists. The advice refusal for a non-query runs after the console's typing prepare. The second agent invitation, "run an index analyzer report", has no place in the descriptor. The Gather consequence is one joined sentence (Batch 1 results).

The Task 0 gaps of the first pass closed at the Spec Change Log's ruling item 2 (veto U-169).
