---
title: 'Story 21.26: Runtime statistics'
type: 'feature'
created: '2026-11-25'
status: 'done'
baseline_revision: '1eea75fcfc1949a19e336de4be3a81b2f5aa63e8'
baseline_commit: '747dd2a457ecb50371cf50291b0e01880f072d61'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-6-the-sql-tuning-track.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-31-fixed-table-statistics.md'
warnings: ['oversized']
---

<intent-contract>

## Intent

**Problem:** The classic SQL Runtime Statistics page is the only place to turn runtime statistics collection on or off, see what it collected for each statement and module, purge it, or see a query's plan with its run statistics. The `slowquery` workflow cannot read any of it.

**Approach:** Add two System Explorer lists: SQL runtime statistics, over the namespace's collected rows, with a Purge statistics page action through `SqlPort`; and Runtime statistics collection, the system-wide setting as settings rows through `ConfigPort`, set one row at a time like the SQL Shell settings. SQL query gains Plan with statistics, a run of a query the console already types as a query. `slowquery` gains the two reads and stays read-only.

## Boundaries & Constraints

**Always:**

- Each write is one operation with two callers, the screen action and the agent's confirmed proposal (AD-53), run in the confirm or action request (AD-7). The vendor gets port-built arguments only: the namespace for the purge, and for the setting the level, a whole number of minutes and the level after the stop, built into the vendor's `M:<minutes>:<level>` text by the port. No caller text reaches SQL text, code or a file (AD-21).
- The list reads one bound catalog statement over `%SYS_PTools.StatsSQLView` and never selects `UserName`, `ExeName`, `MachineName`, `IPAddress`, `Pid` or `Parameters` (AD-35, AD-36).
- A test that changes the collection setting runs in an armed class on the throwaway, reads the flag before, restores it in its own cleanup and reads it back. A test that records statistics records them in its own process only (`SetSQLStatsFlagJob`) for its own probe statements, and removes them by routine (`clearStatsSQL(ns, rtn, , 1, , 1)`). No test asserts that a store is empty.

**Never:**

- No query history, no export, no per-process or per-namespace collection flag, no metric subset (`collectFlag` stays `""`), no timestamp form of the stop (`T:`), and no agent tool for Plan with statistics.
- No collection at level 2 or 3 without a stop: a set to either always carries a stop in minutes.
- No edit to `Api/Error.cls`; new codes go in `Api/AtelierError.cls` and `Api/ConfigError.cls`. The spine stays add-only. No test or write runs on `ocupilot` or a slot instance. No probe schema whose name holds `"` (DW-2851).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | The probe's own statement run with statistics on in the fixture's process | The list and `explorer.sqlruntimestats.read` answer the same rows: one summary row and one row per module, each with routine, cursor, module, runs, average rows, global references, commands, disk wait, time, module runs and the masked statement text | Truncation reported (AD-36) |
| Settings read | Any instance | Rows `CollectionLevel`, `StopAfterMinutes`, `LevelAfterStop`, `StopsAt`, each `{Name, Value, Accepts, ReadOnly}`; `StopsAt` is read only, ISO-8601 UTC, empty while no stop is set | none |
| Turn collection on | `CollectionLevel` set to "On for all modules", no stop held | The flag's action level reads 3, `StopAfterMinutes` 50 and `LevelAfterStop` "Off" (the classic page's defaults), `StopsAt` about 50 minutes after the confirm | none |
| Change the stop | Level 2 or 3, `StopAfterMinutes` set to 120 | The level is unchanged, `StopAfterMinutes` reads 120 and `StopsAt` moves to 120 minutes after the confirm | At level 0 or 1: refused with the ruled sentence before any call |
| Turn collection off | `CollectionLevel` set to "Off" | The level reads 0, the stop rows read empty | none |
| Bad value | A level outside the four names; minutes 0, 100000, fractional or text; a level after stop other than the two names | 400 with the settings' published sentence before any call, from both callers | none |
| Purge | The namespace holds the probe's rows | Every row of the namespace is gone after confirm; another namespace's rows stay (armed) | Nothing to purge: precondition refusal before any call |
| Plan with statistics | A query over the probe table, run without its values | The plan text with each module's statistics and the note "Plan with statistics runs the statement without its values, so a filtered query can show zero rows."; the run's rows appear in the list | Not a query kind: refused before anything runs; over the console's bound: `stopped` |
| Own tables | A Plan with statistics over `OcuPilot_Kernel_State.Turn` | Refused by the console's existing self-protection check before anything runs | none |
| Changed target | Rows recorded, or the level changed, after the mint | Confirm refuses `PROPOSAL.TARGETCHANGED` and writes nothing | none |
| Gate | Missing a pair Design Notes names for the read or the write | 403 naming the pair, before any read or write | none |
| Vendor refusal | The seam answers an error status | Purge: 409 `SQL.RUNTIMESTATS.VENDOR`, the message in `detail` only; set: the settings' existing vendor refusal | none |
| Workflow | A `slowquery` turn | Its steps name `explorer.sqlruntimestats.read` and `explorer.sqlruntimestatssettings.read` and no write | none |

</intent-contract>

## Code Map

- **Classic sources (read-only):**
  - `irislib/%CSP/UI/Portal/SQL/QButtons/RuntimeStatsSettings.cls`: `SaveSQLStats` :318 calls `SetSQLStats(level, 1, "", terminate)`, with `terminate` `M:<minutes>:<reset>` for level 2 or 3 and `""` otherwise. Hours and minutes of 0 are refused for level 2 or 3 (:265), and the reset level is 0 or 1 (:145).
  - `QButtons/Utils.cls`: `GetSettingsData` :33 reads `GetSQLStatsFlag(0, "", .ptInfo)`. The default stop is 50 minutes (:43) and the default reset 0. The option texts are at :207-210 and the change notes at :219-231.
  - `QButtons/RuntimeStats.cls`: View Stats reads `ViewStatsSQL(ns)` :217 and `ViewStatsSQLDetails(curs, rtn)` :254. Purge Stats calls `clearStatsSQL(ns, , , 1, , 1)` :742. Show Plan with SQL Stats is `%SQL.Manager.ShowPlan.cls?stats=1` :465, or a background `JobShowPlan` :385.
  - `irislib/%SYS/PTools/StatsSQL.cls`: `SetSQLStats` :657, `GetSQLStatsFlag` :1309 (flag format :1250), `ViewStatsSQL` :2825 (no SQL procedure on the instance), `ViewStatsSQLDetails` :2875, and `clearStatsSQL` :3210.
  - `irislib/%SYSTEM/SQL.cls`: `Explain(.sql, qualifiers, .dynArgs, .plan)` :4312, with `{"stats":1}`.
- `src/OcuPilot/Port/ConfigPort.cls`, the settings shape to extend:
  - `PAIRS`/`WRITEPAIRS` :65-70, the per-endpoint `COMPATIBILITYPAIRS` :74 precedent, and `ENDPOINTS` :85.
  - The class-less rosters `SHELLROSTER` :150 and `TASKMAILROSTER`, plus `RosterOf` :943, `EntryLimits` :966 (kinds `boolean`, `choice`, `integer` `min:max`, `text`), `CollectRoster` :1014 (Task Mail's vendor-read branch), and `SendNode` :1107 (the write seam, whose Task Mail branch calls a vendor setter).
  - `Api/ConfigError.cls` `ACCEPTSRANGE` :70.
- `src/OcuPilot/Port/SqlPort.cls`:
  - `COMPOSEDTYPES` :66, `Invoke` :824, and `TuningInvoke` :905 (served types, gate, id shape, read or write).
  - `StatementCall`, the seam to widen; `Applied`, `SnippetForm` and `Snippet` (AD-59).
  - `Plan` :769 and `Explained` :2332 (`$SYSTEM.SQL.Explain(.tText, {"silent": 1}, , .tPlan)`), `Run` :713 (the bound through `BoundSeconds` and `Executed`), and `Classify`.
- `src/OcuPilot/Port/AtelierPort.cls` -- `CATALOGTABS`, `CatalogRows` and `CatalogQuery`, where 21.6's `Catalog.Statements` (`CATALOGSTATEMENTINDEXQUERY`, the `sqltext` kind and credential masking) is the sibling.
- `src/OcuPilot/Area/Explorer/SqlConsole.cls` -- `HandlePlan` :78 and `Prepare` :105 (the screen gate, body, bounds, then `Check`, the self-protection set).
- **Tool siblings:**
  - `Screen/Tool/SqlStatementAction.cls` and `ExplorerSqlStatementClean.cls` (id `*` only, `Holds`, `IdProblem`, `STATEFIELD`/`STATEAFTER`, `REFUSALCODE`).
  - `ConfigSettingSet.cls` and `SqlShellSettingSet.cls` (`TOOLNAME`, `DESCRIPTORCLASS`, `ENDPOINTNAME`, `CLASSICPAGES`, `CONSEQUENCECODE`, `Consequence` :146).
  - `Area/OsMgmt/ConfigSettingRules.cls` -- `WriteProblem` :148.
- **Descriptors:** `Screen/Descriptor/ExplorerSqlStatementList.cls` (list, position 20, page action `clean`), and `SqlShellSettingList.cls` / `SqlSettingList.cls` (settings rows, `config` source, row action `set`).
- **Kernel:**
  - `Kernel/EntityType.cls` `TYPES` :180 and `Kernel/Proposal/Prohibited.cls` `COVEREDTYPES` :342, each appended at the end. `sql-shell-setting` and `cached-query` are the arms' siblings.
  - `Kernel/Governance/Baseline.cls` :245-259 (SQL track) and :370-376 (settings).
  - `Kernel/Agent/Workflow.cls` `slowquery` :261-268.
- **Client:**
  - `ui/src/app/areas/system-explorer/sql-statement-list.page.ts` (the page-registered `*` action) and `sql-query.store.ts` (`SQL_PLAN_PATH` :36, plan :254) with `sql-query.page.ts`.
  - `shell/screen-action-handler.ts` (`SCREEN_ACTION_DESCRIPTORS`, `UNDRAWN_ACTIONS`, `WARNING_CONSEQUENCES`), `shell/screen-outlet.ts` `DESCRIPTOR_PAGES`, `core/screen-actions.ts`, `core/proposal-view.ts` and `core/strings.ts`.
- **Fixtures and tests to follow:** `Test/SqlTuningProbe.cls`, `SqlTuningPortFixture.cls` / `SqlTuningGateSeam.cls`, `ConfigGateSeam.cls`, `TaskMailSettingRead/Rules/Write.cls` (a vendor-setter roster), `SqlStatementRead.cls`, `SqlTuningWrite.cls` (armed), `SqlConsoleProbe.cls` (`Plan` legs :436), and `ui/browser/system-explorer-sql-statements.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:** Task 0 first, then three batches, each committed on its own. A handoff builds one batch. Strings are only the ruled set (Design Notes, "Strings, escalated"); any other sentence a person reads is `## Clarification Needed`.

**Task 0, measured on `ocupilot-ci` before code** (record in Design Notes; restore the flag and read it back; remove every probe row by routine and read back 0 for the probe's routines):

- (a) **Least-privileged pairs.** Use a principal holding `%Development:USE` plus `AtelierPort.PAIRS(ns)`. Can it read `StatsSQLView` through the catalog route, or is it refused SQLCODE -99? A refusal is a HALT `intent gap`. With `AtelierPort.WritePairs(ns)`, can it purge, and which database holds `^%sqlcq(ns,"PTools")`? Can a principal with `%Development:USE` and `%DB_IRISSYS:READ` read the flag, and does a set need `%DB_IRISSYS:WRITE`? Record `<PROTECT>`, a status, or a silent no-op.
- (b) Durations of a purge over 1,000 rows, a set, and Plan with statistics. Whether the console's alarm stops an `Explain` with statistics over the bound, and what that leaves.
- (c) A cached query prepared at level 0: does it record rows after a set to 2, before and after a purge of cached queries? A query prepared at level 2: does it stop after a set to 0?
- (d) Whether a set of the stop restarts `startHDate` at the set, and what the flag reads at expiry with `M:1:1` (one minute's wait). If not measured, `(inference)`.
- (e) Whether `SetSQLStats`, `GetSQLStatsFlag`, `clearStatsSQL` or `Explain` with `silent` writes to the current device.
- (f) Whether `Explain` with statistics runs an `INSERT`, measured on a probe table that is then dropped (the reason Plan with statistics takes a query only).

**Batch 1, server: the list, the purge and the setting.**

- `src/OcuPilot/Port/AtelierPort.cls` -- add `Catalog.RuntimeStats`. It is one `CATALOGTABS` statement over `%SYS_PTools.StatsSQLView`, `NameSpace = ?` bound, capped by `maxRows`, with one row per statement and module. Its columns are `Routine`, `Cursor`, `Module` (`%External(ModuleName)`), `Runs`, `AverageRows`, `AverageGlobalRefs`, `AverageCommands`, `AverageDiskWait`, `AverageTime` and `ModuleRuns`, averaged as `ViewStatsSQLDetails` averages (the summary row per run, a module row as stored), then `Statement:sqltext` cut and masked as `Catalog.Statements`. It never selects the user, client, process or parameter columns.
- `src/OcuPilot/Port/SqlPort.cls`:
  - Add the endpoint `RuntimeStats`, served in `Invoke` and `TuningInvoke`, with `RuntimeStats/PURGESTATS` in `COMPOSEDTYPES`.
  - Its read `STATS`, id `*` only, answers `{Namespace, Rows}`, the namespace's row count. Its write `PURGESTATS` calls `clearStatsSQL(ns, "", 0, 1, 0, 1)` through the widened `StatementCall`, in the namespace.
  - The gate is `Gate`, and the write adds `AtelierPort.WritePairs(ns)` plus any pair Task 0 (a) measures. An error status is 409 `SQL.RUNTIMESTATS.VENDOR`. Add a `SnippetForm` for the purge.
- `src/OcuPilot/Port/ConfigPort.cls` -- add the roster endpoint `SQLStats` at the end of `ENDPOINTS`, with `SQLSTATSROSTER` holding the four rows of the matrix:
  - `CollectionLevel` is a `choice` of the four ruled names stored 0 to 3. `StopAfterMinutes` is an `integer` `1:99999`. `LevelAfterStop` is a `choice` of the two ruled names stored 0 or 1. `StopsAt` is `text`, shown only.
  - `CollectRoster` reads them from `GetSQLStatsFlag(0, 0, .ptInfo)`, with the stop rows empty below level 2.
  - The endpoint's own pairs replace `PAIRS`/`WRITEPAIRS` for it (Design Notes).
  - `SendNode` gains the `SQLStats` branch: one `SetSQLStats(level, 1, "", terminate)` built from the named row's new value and the other rows' fresh values. A stop row set below level 2 is refused with the ruled sentence before the call.
- `src/OcuPilot/Api/AtelierError.cls` and `Api/ConfigError.cls` (add-only) -- `SQL.RUNTIMESTATS.VENDOR`, `SQL.RUNTIMESTATS.NOROWS`, the consequence codes `SQL.RUNTIMESTATS.PURGE` and `SQL.RUNTIMESTATS.SET`, the stop-row refusal, and their ruled sentences.
- New `Screen/Tool/ExplorerSqlRuntimeStatsPurge.cls` (`explorer.sqlruntimestats.purge`, extends `SqlStatementAction`, as `ExplorerSqlStatementClean`):
  - It reads `STATS`, with subject, state and precondition `Rows`, state after `0`, and id `*` only.
- New `Screen/Tool/ExplorerSqlRuntimeStatsSettingSet.cls` (`explorer.sqlruntimestatssettings.set`, extends `ConfigSettingSet`, as `SqlShellSettingSet`):
  - `ENDPOINTNAME` `SQLStats`, `CLASSICPAGES` `%CSP.UI.Portal.SQL.QButtons.RuntimeStatsSettings`, and `Consequence` answering `SQL.RUNTIMESTATS.SET` for every row.
- New `Screen/Descriptor/ExplorerSqlRuntimeStats.cls`:
  - List, the next free side-bar position at implement time (21 on HEAD today), namespace scope, entity `sql-runtime-stat`, id composite `["Routine", "Cursor", "Module"]`.
  - Source `{port: "atelier", endpoint: "Catalog.RuntimeStats", type: "LIST"}`, sorted by `AverageTime` descending, with page action `purge`.
  - Classic page `%CSP.UI.Portal.SQL.QButtons.RuntimeStats`, `%Development:USE`, `toolIdentifier` `explorer.sqlruntimestats`, and the ruled note.
- New `Screen/Descriptor/ExplorerSqlRuntimeStatsSettings.cls`:
  - Modeled on `SqlShellSettingList`: route `system-explorer/sql-runtime-stats-settings`, the next position after the list, instance scope, entity `sql-runtime-stats-setting`, id composite `["Name"]`.
  - Source `{port: "config", endpoint: "SQLStats", type: "LIST"}`, row action `set`, classic page `...RuntimeStatsSettings`, its pairs as Design Notes says, and `toolIdentifier` `explorer.sqlruntimestatssettings`.
- `Kernel/EntityType.cls` and `Kernel/Proposal/Prohibited.cls` (add-only, appended at the end, `tType` guards extended by prefix) -- add `sql-runtime-stat` and `sql-runtime-stats-setting`, covered as their siblings `cached-query` and `sql-shell-setting` are, with no predicate (AD-10, Design Notes).
- `Kernel/Governance/Baseline.cls` (add-only) -- `explorer.sqlruntimestats.purge` `false` and `explorer.sqlruntimestatssettings.set` `true`.
- `Kernel/Agent/Workflow.cls` -- `slowquery` gains, after the statement-index step, the ruled step reading both new reads.
- `Test/SqlTuningProbe.cls` -- `RecordStats(ns)` runs the probe's statement with `SetSQLStatsFlagJob(3)` in its own process, then restores the job flag. `RemoveStats(ns)` clears the probe's routines by name. The seam fixtures (`SqlTuningPortFixture`, `ConfigGateSeam`) take the new branches.
- New `Test/SqlRuntimeStatsRead.cls` (live-safe) covers:
  - the list against a direct bound `SELECT`, and the agent read equal to the screen read;
  - the selected columns pinned, with none of the excluded ones;
  - the settings rows' shape, and the `STATS` read;
  - the gates and every id shape.
- New `Test/SqlRuntimeStatsWrite.cls` (armed, `OCUPILOT_ALLOW_CONFIG_SETTINGS`, add-only `# classes:` entry in `scripts/ci-throwaway.sh`) covers:
  - each setting row on both callers, the defaults and the stop-row refusal;
  - the purge on both callers, nothing to purge, another namespace surviving, a changed target and the vendor refusal (seams);
  - restoring the flag read before, and reading it back.
- Update every shared-surface test under Verification, with names read from the instance: `ConfirmNamespaceRoster`, `CompositeMintSweep` and `MappingDescriptor`'s `CLASSICROSTER`.

**Batch 2, server: Plan with statistics.**

- `src/OcuPilot/Port/SqlPort.cls` -- `Plan` gains `pStats` (default 0) and `pValues`. With `pStats` 1, a kind other than `query` is refused with the ruled sentence before anything runs. `Explained` passes `{"silent":1,"stats":1}` and the values as `dynArgs`, under the console's alarm bound. The answer keeps the `plan` outcome, and a bound overrun answers `stopped` as `Run` does.
- `src/OcuPilot/Area/Explorer/SqlConsole.cls` -- `HandlePlan` reads a boolean `stats` and the values from the body and passes them on. `Check` still runs first.
- `Test/SqlConsoleProbe.cls` / new legs in `Test/SqlRuntimeStatsRead.cls`: a query's plan carries statistics, and its rows reach the list (removed by routine). A DML statement is refused with nothing run (Task 0 (f) probe table). An OcuPilot table is refused by `Check`.

**Batch 3, client.**

- New `areas/system-explorer/sql-runtime-stats.page.ts` with a spec (the `sql-statement-list.page.ts` shape), which registers Purge statistics on `*`. Add a `screen-outlet.ts` row. The settings list uses the generic list page and the `set` row action as `SqlShellSettingList` does.
- `sql-query.page.ts`, `sql-query.store.ts` and their spec -- a Plan with statistics button beside Explain plan, posting `{stats: true}` and the values, and showing the answer in the plan pane.
- `shell/screen-action-handler.ts`, `core/screen-actions.ts`, `core/proposal-view.ts` and `core/strings.ts` (add-only) -- the descriptors, the page action, the warnings, the consequence codes and the ruled strings. Regenerate the mirror and `Titles.cls` (`node tools/screen-mirror.mjs`).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- one add-only Fixed strings row for 21.26.
- New `ui/browser/system-explorer-sql-runtime-stats.browser-spec.mjs`, which refuses the live container. Each step waits for the answered signal:
  - the probe's rows show on the list;
  - the settings list shows the level;
  - Plan with statistics on SQL query shows module statistics;
  - Purge statistics asks, confirms and empties the list.

  The `after` hook removes the probe's rows and table.

**Rework 1** (orchestrator ruling 2026-11-25, veto U-164; Spec Change Log):

- [x] [Review] AC4 "with values": Plan with statistics keeps the query-only guard, runs without values, and EVERY result shows the note "Plan with statistics runs the statement without its values, so a filtered query can show zero rows." (no literal detection) -- client result pane, plus the same sentence in the model-facing tool result or description, and the `slowquery` step text where it uses the read. A test pins the client note and one pins the model-facing sentence (each with a `mutation:` line). The client posts no values.
- [x] [Review] Set consequence: ship "This applies to every namespace on the instance. A query prepared while collection was set to Off records nothing once collection is turned on, until its cached query is purged." -- measured in that direction at Task 0 (c) (prepared at level 0, set to 2: 0 rows on two runs; purged and prepared at level 2: 3 rows). Re-measure once on `ocupilot-ci` and record the line under Verification; if it measures false, ship the first sentence alone.
- [x] [Review] Security note in Design Notes: Task 0 measured the vendor needs no `%DB_IRISSYS` pair for read, set or purge; the shipped gate keeps it (stricter than the classic page, U-161).
- [x] [Review] AD-36 truncation test for the SQL runtime statistics list.
- [x] [Review] `SqlRuntimeStatsWrite`'s always-true first assertion made able to fail.
- [x] [Review] The AC6 mutation comment in the browser spec names a mutation that can run.
- [x] [Review] A changed-target test for the collection level (the level read back after a set, restored in cleanup).
- [x] [Review] A `mutation:` line for `ConfigPort.SqlStatsState`'s `pLevel >= 2` guard.

**Acceptance Criteria:**

- AC1. Given the probe's recorded statement, when the person opens SQL runtime statistics and the agent calls `explorer.sqlruntimestats.read`, then both answer the same rows, one summary and one per module, with the matrix's columns and no user, client or parameter column.
- AC2. Given the throwaway, when either caller sets the collection level, the stop or the level after the stop and confirms, then the setting reads back as sent and Runtime statistics collection shows it. A level of 2 or 3 always carries a stop, and the test restores the prior flag.
- AC3. Given rows in the namespace, when either caller purges and confirms, then the namespace's rows are gone and another namespace's stay. A second purge is refused before any call.
- AC4. Given a query on SQL query, when the person chooses Plan with statistics, then the statement runs without its values, the plan shows each module's statistics with the note "Plan with statistics runs the statement without its values, so a filtered query can show zero rows." (the model-facing result says the same), and the run's rows appear in SQL runtime statistics. A statement that is not a query is refused before anything runs.
- AC5. Given the `slowquery` workflow, when a turn follows it, then its steps name both new reads and no write tool.
- AC6. Given the throwaway, when the browser spec runs forward and in reverse with `system-explorer-sql-statements.browser-spec.mjs`, then it passes and leaves no probe table or probe statistics.

## Spec Change Log

- 2026-11-25, orchestrator rulings at the plan gate (veto U-161 for items 2, 3, 4 and 7), authoritative over the Design Notes records:
  1. **Settings shape** (record 1): decided. `ConfigPort` endpoint `SQLStats`, setting rows, no AD-51 named entry.
  2. **Setting gate** (veto U-161): read `%Development:USE` + `%DB_IRISSYS:READ`, set also `%DB_IRISSYS:WRITE`; the IRISSYS pair stays whatever Task 0 finds. Task 0 measures the classic portal's gate for `RuntimeStats` and `RuntimeStatsSettings` and their actions (resource:permission, read from the instance) and records it here; any part where this gate is looser gets the classic requirement added. A looser gate never ships.
  3. **AD-51 purge entry** (veto U-161): allowed, add-only, written by the runner. `clearStatsSQL` runs only inside the confirmed write, after the prohibited and shape checks; its namespace is the request's validated namespace, never model text; "This namespace holds no runtime statistics." refuses before any write. A test pins each.
  4. **AD-7 Plan with statistics** (veto U-161): allowed, add-only, written by the runner; a read, not a confirmed run. Query-only through the same guard SQL query uses, with a test that a non-query statement is refused before anything runs; the console's time limit applies; the AD-7 line names the recorded statistics rows as the read's only side effect.
  5. **AD-10:** decided, no new arm; the purge is not in the prohibited set.
  6. **Governance defaults:** decided. `explorer.sqlruntimestats.purge` ships `false`; `explorer.sqlruntimestatssettings.set` ships `true`.
  7. **Strings** (veto U-161): accepted as written. The list note and the set consequence ship only if measured true on `ocupilot-ci`; otherwise they are reworded to what was measured and the measurement recorded under Verification. The four level names are checked against the vendor's level semantics (0-3) in its source.

- 2026-11-25, orchestrator ruling on the implement-stage intent gap (veto U-164), rework 1: AC4 becomes "a query" run without its values, with the note "Plan with statistics runs the statement without its values, so a filtered query can show zero rows." on every result and in the model-facing result; the matrix row and AC4 read so (lead edit to the I/O matrix, the intent's wording only). Evidence: Task 0 (b) and the Batch 2 re-measurement, two runs with a literal, zero rows and zero global references. The set consequence's reworded second clause ships as measured (Task 0 (c)); the IRISSYS pair stays. epics.md's 21.26 block names no values, so it is unchanged.

## Review Triage Log

### 2026-11-25 — Review pass

- verdicts: 9 findings — high 0, medium 2, low 6, false 0, maybe-false 1
- findings:
  - `[medium]` `[intent_gap]` Values never reach the Plan with statistics run on this build (Task 0 (b) and the Batch 2 re-measurement), so AC4's "a query over the probe table, with values" and Batch 3's "posting the values" cannot hold; the client posts no values and nothing exercises the server's `pValues` path — verified at `SqlPort.Explained`, `SqlQueryState.body` and the page spec. Resolving it needs either a refusal sentence for a statement with a literal or placeholder or a note beside the result, and neither string is in the ruled set.
  - `[medium]` `[intent_gap]` A statement carrying a literal or placeholder answers zero rows and zero global references in its statistics, and no test pins either a refusal or a note — same root cause as row 1 (grouped).
  - `[low]` `[patch]` `SqlRuntimeStatsRead` pins no AD-36 truncation leg for `Catalog.RuntimeStats` (sibling `SqlStatementRead` pins one row as `200|1|1`) — not applied: the intent_gap cascade makes it moot this pass; open item for the re-dispatch.
  - `[low]` `[patch]` `SqlRuntimeStatsWrite.TestTheScreenSetsTheLevelTheStopAndTheLevelAfterIt` first assertion is always true after `OnBeforeOneTest` — not applied (cascade); open item.
  - `[low]` `[patch]` The browser spec's AC6 mutation comment names removing the `purge` row action, which `screen-mirror.mjs` refuses before a build; the spec records the `actions.register` mutation instead — not applied (cascade); open item.
  - `[maybe-false]` `[defer]` The `pLevel >= 2` guard in `ConfigPort.SqlStatsState` has no recorded mutation; it reddens only if the vendor leaves a stale stop at level 0 — settle by applying the mutation on the throwaway after setting 2 then 0.
  - `[low]` `[patch]` Matrix row "Changed target" has a named test for the purge's rows-recorded leg and none for the setting's level changing after the mint (inherits `ConfigSettingSet` confirm behavior) — not applied (cascade); open item.
  - `[low]` `[reject]` Plan with statistics route tests use the web process rather than `SetSQLStatsFlagJob` — the Explain call records its own rows and the test removes them by routine, so no collection flag is touched; no harm named.
  - `[low]` `[reject]` Governance defaults and the setting call's overridable seam are not stated in the intent — both are Spec Change Log rulings 5 and 6 and the AD-59 seam pattern.

### 2026-11-25 — Review pass (rework 1)

- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` The `pLevel >= 2` guard in `ConfigPort.SqlStatsState` has no test that can fail — the mutation was applied and stays green because the vendor reads the stop empty below level 2 on this build; pinning it needs a vendor-read seam, which adds surface for a defensive guard (recorded under Verification).
  - `[low]` `[reject]` The rewritten `read.label` of `ExplorerSqlRuntimeStats` no longer points at the settings read — the `slowquery` step names both reads and the label's 240-character limit forced the cut; no test or caller depends on the pointer.
  - `[low]` `[reject]` `TestALevelMovedSinceTheMintRefusesTheConfirm` does not check the return of its out-of-band `SetSQLStats` — the next assertion reads the state and catches a failed set.
  - `[low]` `[patch]` The doc comments of `SqlConsole.HandlePlan` and `SqlPort.Plan` said or implied the body's values reach the statistics run — both now say the instance binds none of them; reloaded, `SqlConsoleRoutes` 8/8.
  - `[low]` `[reject]` Intent audit: the plan route's own answer carries no note and no agent tool runs Plan with statistics — the ruling names the client result and the model-facing result or description (the list read's description and the `slowquery` step), and the spec forbids an agent tool for it.

## Design Notes

**Governing ADs (spine line ranges):**

- AD-7 :211-253: the writes run in the request; Plan with statistics' rows are a new shape (record 3).
- AD-10 :389-456: no new arm (below), and the console's own-table check :430 covers Plan with statistics.
- AD-6, AD-34, AD-14, AD-15, AD-16, AD-21 :611, AD-22 (keys), and AD-29 :792 (gates by the classic page plus a least-privileged probe).
- AD-35 and AD-36 :872 (one read for the list and the tool; excluded columns), AD-39, and AD-44 (classic pages).
- AD-51 :1212-1285 (record 2), AD-52, AD-53, AD-56 (the screen's set sends one row's value), AD-58, AD-59, and AD-66 :1529 (read-only workflow).

**Records for the orchestrator** (proposed, add-only; the runner writes each if allowed):

1. **The collection level takes the settings shape, so no AD-51 named entry.** Recommendation: allow.
   - It is a `ConfigPort` class-less roster endpoint, `SQLStats`, set one named row at a time. That is the precedent of Story 21.4's SQL Shell rows and Story 21.36's Task Manager mail rows, which call a vendor setter and carry no named entry.
   - It fits the one-value warning dialog (21.31's limit) and gives the list and the agent one read for free.
   - The port builds the vendor's `terminate` text from two whole numbers it has checked.
   - The alternative is a `SqlPort` action write with three declared values and an AD-51 entry, plus a new screen to show the setting. It is larger and needs a new `Screen/Read` source.
   - **Its gate:** the endpoint's pairs are the classic page's `%Development:USE` with `%DB_IRISSYS:READ` (`ConfigPort` reads in `%SYS`), and `%DB_IRISSYS:WRITE` for a set (inference: the vendor writes `^%SYS("sql","sys","SQLStats")`, measured as the node). They replace `ConfigPort`'s `%Admin_Manage` pairs for this endpoint only. If Task 0 (a) shows the vendor needs no IRISSYS pair the classic audience lacks, any extra pair is a stricter posture and a veto item.
2. **AD-51, Story 21.26's purge** (append after :1285): "Story 21.26's case: `SqlPort` answers the runtime statistics purge's fresh read through a port-composed `STATS` type, the target namespace's runtime statistics row count, and calls `%SYS.PTools.StatsSQL.clearStatsSQL` with the namespace alone, every row and no error rows." Recommendation: allow. No caller value reaches it beyond the target `*`.
3. **AD-7, Plan with statistics** (append after :252): "**Plan with statistics (Story 21.26)** is a person's read on SQL query. It runs one statement the console's classification types a query, in the request, under the console's bound, through `$SYSTEM.SQL.Explain` with statistics. Any other kind is refused before it runs. The vendor records the run in the namespace's runtime statistics (measured: one summary row and one row per module), which a purge removes. The SQL statement index row is the fifth shape's." Recommendation: allow. A confirmed run would add a proposal to what the console already runs unconfirmed.
4. **AD-10: no new arm.** Neither write reaches OcuPilot's self-protection. A purge removes diagnostic rows, as 21.6's cached-query purge is not refused. The collection setting changes what every namespace's new queries record, OcuPilot's included, at a cost the person chose with a stop.

**Decided in-stage:**

- **Placement.** Two System Explorer lists after SQL statements, at the next free positions at implement time. Purge statistics is the runtime statistics page's own action on `*`, and `set` is the settings list's row action. Plan with statistics is a button on SQL query. It has no agent tool, since Explain plan has none.
- **One list read covers View Stats and its details.** The read returns summary rows (module `INFO`) and module rows together, so `ViewStatsSQLDetails` needs no second screen.
- **Entity types (two, new):** `sql-runtime-stat` (`*` for the purge) and `sql-runtime-stats-setting`. A tool's target type is its descriptor's primary type (`Operation.TargetRefOf`).
- **Defaults follow the classic page.** A level set to 2 or 3 with no stop held takes 50 minutes and level after stop 0. A stop row set below level 2 is refused, so a level of 2 or 3 never runs without a stop.
- **Keys.** The purge is `false`: purged statistics do not come back, as 21.6's clear statistics. The set is `true`: it is reversible and always stops, as every settings list's set is. Neither is destructive.
- **Plan with statistics takes a query only.** Explain with statistics runs the statement (Task 0 (f) confirms for DML). The console runs a query unconfirmed today and confirms everything else.
- **Tests.** The armed class (whole namespace and system-wide) joins `OCUPILOT_ALLOW_CONFIG_SETTINGS` beside `SqlTuningWrite`. The list test records statistics in its own process only.
- **The set consequence, reworded to what Task 0 (c) measured.** The measure-first second clause ("Queries prepared before the change keep recording as they did until they are purged or compiled again") measured false for a set to Off: a query prepared at level 2 stopped recording at once. New sentence, verbatim: "This applies to every namespace on the instance. A query prepared while collection was set to Off records nothing once collection is turned on, until its cached query is purged." It is `SQL.RUNTIMESTATS.SET` in `AtelierError`. The list note and the purge consequence ship as ruled.
- **Security note (U-161).** Task 0 measured that the vendor needs no `%DB_IRISSYS` pair for the flag's read, the set or the purge. The shipped gate keeps `%DB_IRISSYS:READ` for the setting's read and `%DB_IRISSYS:WRITE` for its set, stricter than the classic page, as ruled.
- **Batch 1 decisions.**
  - The settings descriptor declares its `%DB_IRISSYS:READ` as an `ownPrivileges` pair, since System Explorer's area declares `%Development:USE` alone; the port's own pairs (ruling 2) gate every read and write.
  - The settings descriptor declares three suggested prompts, since the validator refuses fewer: the ruled one, and two of the list's ruled prompts ("Are runtime statistics being collected?", "Which module of a slow statement takes the most time?"). No new sentence.
  - Two of the ten column strings ruled new already exist with the same text, so the list reuses `processColumnRoutine` ("Routine") and `explorerSqlColumnAverageTime` ("Average time"); `strings.ts` holds one key for each value.
  - The purge tool names its target argument `Target`. The stop-row refusal is `CONFIG.SQLSTATS.NOSTOP`, 409, in `ConfigError`; the four `SQL.RUNTIMESTATS.*` codes are in `AtelierError`.
  - The `STATS` count reads `%SYS_PTools.StatsSQL`, the base table, in the target namespace, with one fixed statement prepared unchecked (Task 0 (a)).
  - The strings the descriptors reference are in `strings.ts` and EXPERIENCE.md's Fixed strings in Batch 1, since the Titles, string-source and `ConfigError` pins read them; Batch 3 appends the actions, consequences and refusals to that row.
  - The README's count of agent actions that ship switched off is one higher.

**Measured at plan, `ocupilot-ci`, USER, 2026-11-25** (restored and read back):

- `SetSQLStats(2, 1, "", "M:50:1")` answered `0`. The flag read `2:15:0::97775566:0`, where the fifth piece is the stop in minutes since `$H` day 0. `ptInfo("terminate")` held `mins` 50, `resetActionFlag` 1 and `start`/`stopHDate` 50 minutes apart. The SQL function `StatsSQL_GetSQLStatsFlag` answers the flag string only, so the stop rows need the method.
- A dynamic query run while the level was 2 recorded three rows at once (module `-1` and two modules).
- `Explain` with `{"silent":1,"stats":1}` ran in 0.46 s. Its plan text carries a `Stats:` block per module, it recorded six rows under `%sqlcq.USER.u<hash>.1`, and it left the job flag unchanged.
- `clearStatsSQL("USER", <routine>, , 1, , 1)` answered 3 and 6 and left 0 rows.
- `SetSQLStats(0, 1, "", 0)` answered 2 and the flag read `0:0:0::0:0` again. `ptInfo("terminate")` then read `resetActionFlag` 0 and `terminateCond` 0 where it first read empty, a stored-node residue no API clears.
- `%SYS_PTools.StatsSQL_ViewStatsSQL` is not a SQL procedure. `StatsSQL_ViewStatsSQLDetails` is. `StatsSQLView` holds the user, client, process and parameter columns.
- On `ocupilot` (read only): the flag is `0`, and `StatsSQL` and `StatsSQLView` hold 0 rows.

**Strings, escalated as one batch** (none is in EXPERIENCE.md yet). *Measure-first* clauses ship only as measured, and any correction is reported verbatim.

1. **Titles:** "SQL runtime statistics" (the classic page's name) · "Runtime statistics collection".
2. **List columns:**
   - New: "Routine" · "Cursor" · "Module" · "Runs" · "Module runs" · "Average rows" · "Average global references" · "Average commands" · "Average disk wait" · "Average time".
   - Reused: "Statement".
   - Siblings: 21.6's columns, and the classic headers "Run Count", "Avg Rows".
3. **Empty states:** "No runtime statistics are recorded in this namespace." (sibling: "No SQL statements are recorded in this namespace.").
   - Agent invitations: "purge runtime statistics" · "change runtime statistics collection" (siblings: "purge cached queries").
4. **Note on the list:** "Statistics are recorded only while collection is on, and by Plan with statistics on SQL query." *Measure-first:* Task 0 (c); the second clause was measured at plan.
5. **Setting names and choices** (the settings list's Name and Value, sent by the agent):
   - Names: "CollectionLevel" · "StopAfterMinutes" · "LevelAfterStop" · "StopsAt".
   - `CollectionLevel` choices: "Off" (0) · "Off with collection code" (1) · "On for open and close" (2) · "On for all modules" (3), from the classic option texts.
   - `LevelAfterStop` choices: "Off" · "Off with collection code".
6. **Actions:**
   - "Purge statistics" (classic "Purge Stats"; sibling: "Clean stale statements").
   - "Plan with statistics" (sibling: "Explain plan").
   - The settings list's `set` keeps its published label.
7. **Consequences:**
   - Purge: "This namespace's runtime statistics are removed. New statistics are recorded only while collection is on." (sibling: Clear statistics').
   - Set: "This applies to every namespace on the instance. Queries prepared before the change keep recording as they did until they are purged or compiled again." *Measure-first:* Task 0 (c). If (c) shows prepared queries follow the new level, the second sentence goes.
8. **Refusals:**
   - "This namespace holds no runtime statistics." (sibling: "This namespace's statement index holds no stale statements.")
   - "Collection must be on before its stop can be set." (the stop rows below level 2)
   - "Plan with statistics runs the statement, so it takes a query only." (sibling: `REASONSQLCHANGES`)
   - The vendor refusal: "The instance did not purge this namespace's runtime statistics." (sibling: "The instance did not apply this change to the statement.")
   - Value shapes reuse the settings' published sentences (`ConfigError.ACCEPTSRANGE`, "A whole number from 1 to 99999.", and its choice sentence).
9. **Suggested prompts:**
   - List: "Which statements take the longest on average?" (reused) · "Which module of a slow statement takes the most time?" · "Are runtime statistics being collected?"
   - Settings: "Is runtime statistics collection on, and when does it stop?"
10. **Command aliases:** "runtime statistics" · "sql stats" (list) and "runtime statistics settings" (settings).
11. **The `slowquery` step:** "Read the namespace's runtime statistics for the statements and modules with the highest average time, and the collection setting; when collection is off, say so and that turning it on records new runs only."

**Extend, don't copy (Rule 2/31):**

- The purge extends `SqlStatementAction`, as `ExplorerSqlStatementClean` does, through 21.6's widened seam `StatementCall`.
- The setting extends `ConfigSettingSet` and `ConfigPort`'s roster (`SendNode`, `CollectRoster`, `EntryLimits`'s `integer` kind), as `SqlShellSettingSet` and Task Mail do.
- The list is one more `CATALOGTABS` statement beside `Catalog.Statements`.
- Plan with statistics extends `SqlPort.Plan` and `Explained`.
- The fixture extends `SqlTuningProbe`.

**Integration ACs:** the two write tools consume `SqlPort` and `ConfigPort` through both callers (AC2, AC3). `slowquery` consumes both reads (AC5), and the list consumes Plan with statistics' rows (AC4).

- **Consumed-by:** 21.27 and 21.28 add their own `slowquery` reads after this step. 21.28's comparison may reuse Plan with statistics' `Explained` (inference).
- **Consumes:** Story 21.6's `SqlPort` endpoints, `SqlStatementAction`, seam and `SqlTuningProbe`; Story 21.4's `ConfigPort` roster and `ConfigSettingSet`; Story 19.6's console `Plan`, `Classify` and `Check`; and Story 20.12's workflow catalog.

**Ledger inbox:** none (`LEDGER slice 21-26-runtime-statistics` is empty). DW-2851 is a constraint, not owned.

**Contended paths (Epic 24), checked 2026-11-25** with `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp`: 0 commits on every path in the Code Map, `ci-throwaway.sh` and EXPERIENCE.md. Edits to the shared rosters stay add-only.

**Size:** 2 write tools, 2 derived read tools, 1 console action and about 30 files, planned as three batches.

## Verification

**Shared surfaces** (all `(loop)`):

- System Explorer's side bar and routes: `ExplorerDescriptor`, `Navigation`, `navigation.test.mjs`, and `screen-mirror.test.mjs`'s route rows and catalog roster.
- The tool registry: `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolRoundTrip`, `ToolWrite`, `StageTwoTools`, `DeveloperFloor`, `SurfaceCoverage` and `DraftRegistry`.
- Entity types: `Descriptor`'s count, `EntityRef`, and `Prohibited`'s covered types.
- Governance: `Governance` and `GovernanceBaseline`.
- Gates and catalog: `PortGate`, `ClassicPageGate`, `ConfigGate`, `AtelierPortCatalogTabs`, `AtelierPortCatalogTabsLive`, `SqlCredentialMask` and `EndpointCoverage`.
- The settings shape: `ConfigSettingRead`, `ConfigSettingRules`, `SqlSettingRules` and `TaskMailSettingRules`.
- The console: `SqlConsoleRoutes`, `SqlConsoleWrite` and `sql-query.page.spec.ts`.
- The workflow: `WorkflowCatalog` and `suggested-prompts.test.mjs`.
- Rosters: `ConfirmNamespaceRoster`, `CompositeMintSweep`, `MappingDescriptor`, and `ci.test.mjs` (armed rosters).

Grep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each surface; each test changed joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Each runs in its own foreground call with `timeout: 600000`, against `ocupilot-ci` only, one test call per message.

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/e21-kit/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SqlRuntimeStatsRead` -- expected: green. Then, one class per call: `SqlRuntimeStatsWrite` (armed), `SqlConsoleProbe`, `WorkflowCatalog`, `SqlStatementRead`, `SqlTuningWrite`, `Prohibited`, and every shared-surface class above.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/screen-mirror.test.mjs tools/navigation.test.mjs tools/suggested-prompts.test.mjs tools/self-protection.test.mjs tools/proposal-view.test.mjs tools/ci.test.mjs` -- expected: green.
- `(loop)` `cd ui && npm run build`, then `npm run test:components`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-sql-runtime-stats.browser-spec.mjs browser/system-explorer-sql-statements.browser-spec.mjs` -- expected: green, and green in reverse order.
- `(once)` `cd ui && npm run test:tools` -- expected: green (EXPERIENCE.md changes).
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Task 0 measurements** (Batch 1, `ocupilot-ci`, `USER`, 2026-11-25; the flag was restored to `0:0:0::0:0` and read back, and every probe row, table, class and principal was removed):

- (a) **Pairs.** Principals: PA holds `%Development:USE` and `AtelierPort.WritePairs("USER")` (`%DB_USER` READ and WRITE, `%DB_ENSLIB` and `%DB_IRISLIB` READ); PB adds `%DB_IRISSYS:READ`; PC adds `%DB_IRISSYS` READ and WRITE; PD holds `%Development:USE` with `%DB_USER:READ` and `%DB_IRISSYS:READ`.
  - `^%sqlcq("USER","PTools")` lives in the system database: `GetGlobalDest("USER","^%sqlcq")` answers the manager directory.
  - `StatsSQLView` read through `%Prepare(text, 0)`, which is how the source code API's query route prepares it (`v1.cls:691`, `v6.cls:236`): PA, PB and PD each read the probe's five rows. The same SELECT prepared with privilege checks on is refused SQLCODE -99 for all three, so the catalog read has no -99, and a read through the console's checked prepare would. The `STATS` count therefore prepares its one fixed statement unchecked.
  - `GetSQLStatsFlag` answered the flag for PA, PB, PC and PD. A purge of the probe's rows by `clearStatsSQL` removed them for PA (13 rows), PB (8) and PC (8) and read back 0 each: no `<PROTECT>`, no status, no silent no-op, and no `%DB_IRISSYS` pair needed.
  - `SetSQLStats(2, 1, "", "M:50:0")` by PA, PB, PC and PD answered 0 and the flag read `2:15:0::97775603:0` each, so a set needs neither `%DB_IRISSYS:WRITE` nor any WRITE. A principal holding only `%DB_USER:READ` was refused at sign-in ("Access Denied"), so the vendor's own lower bound is not asserted.
  - **The classic gate, read from the instance:** `RuntimeStats` and `RuntimeStatsSettings` each have `RESOURCE` `%Development:USE` and no `EDITRESOURCE`, and `PurgeStats` (`:737`) and `SaveSQLStats` (`:318`) check no resource of their own. The shipped gate asks `%Development:USE` for every read and write, `%DB_IRISSYS:READ` for the setting's read and also `%DB_IRISSYS:WRITE` for its set (ruling 2), and for the purge `WritePairs(ns)`. Each is the classic gate or stricter; none is looser. The vendor needs no `%DB_IRISSYS` pair, so those two are the ruled stricter posture.
- (b) **Durations and the alarm.** A purge of 1,234 rows ran in 0.0027 s and answered 1234; a set ran in 0.000018 s.
  - Explain with statistics took 0.02 to 0.03 s on the probe's statements. It took 0.017 s on a 4,000,000-row self join whose normal run takes 0.30 s, and 0.016 s on `SELECT Scr2126.Slow(?)...` whose normal run takes 2.03 s: its stats block read `Rows Returned: 0` and a few hundred commands. Passing `dynArgs(1)=1, dynArgs(2)=1`, or `"preparse":1` with them, left both unchanged, so on this build the values did not reach the run (inference: the run's placeholders stay unbound). Batch 2's plan with values must be re-measured before AC4 is written against it.
  - A three-way self join of 2,000 rows with no placeholder ran 21.0 s inside Explain with statistics under a 1 s `$System.Alarm`, answered status OK with its plan, and the same statement run normally under the same alarm also ran 21.0 s and returned no row. The alarm did not stop either. It left the process's job flag unchanged, the alarm cleared (`Clear` answered 1) and the next Explain working (0.02 s).
- (c) **Prepared before a set.** A cached query prepared at level 0 recorded nothing after a set to 2 (0 rows on two runs); after a purge of its table's cached queries and a prepare at level 2 it recorded 3 rows. A query prepared at level 2 recorded (3 rows, then 5 after a second run) and, after a set to 0, recorded nothing more (the run count stayed 2). **The set consequence's second clause measured differently, and is reworded (Design Notes, Decided in-stage).** The list note, "Statistics are recorded only while collection is on, and by Plan with statistics on SQL query", measured true: no row at level 0, and Explain with statistics recorded rows at level 0 (at plan time).
- (d) **The stop.** A second set of the same stop (`M:5:1`) 65 s later moved `startHDate` from `67899,59602` to `67899,59667` and `stopHDate` from `59880` to `59940`: a set restarts the start. A stop is kept to the minute: 5 minute stops fell 278 s and 273 s after the set, a 1 minute stop 86 s after. At expiry (`M:1:1`, read 130 s after the set, 44 s after the stop) the flag read `1:0:0::0:0`, the level after the stop, `ptInfo("expired")` held the old flag with `expiredHDate`, and `ptInfo("terminate")` was empty (`mins` empty, `resetActionFlag` 0, `terminateCond` 0). Whether the flip happens at the stop or at the first read after it was not separated.
- (e) **Device output.** None of `GetSQLStatsFlag`, `SetSQLStats` (levels 0 and 3), `clearStatsSQL` and `Explain` with `{"silent":1,"stats":1}` wrote a byte to the current device: a file device made current held 0 bytes after each.
- (f) **DML.** Explain refuses an `INSERT` (SQLCODE -481a, "does not support the following SQL statement type: INSERT", with and without statistics), and an `UPDATE` and a `DELETE` answered OK and changed no row (the probe table kept its five rows, none updated). No DML ran, and Plan with statistics still takes a query only, as ruled.
- **Vendor answers.** `SetSQLStats` answers the level it replaced, 0 to 3, or an error status (a string beginning `0 `): it refuses a level of 5, `x` or -1 and a stop of `Q:1:1`, `M:0:1`, `M:abc:1`, `M:-3:0` and `T:...`, accepts `M:1:7`, and accepts level 2 with a stop of 0 and no stop held. `clearStatsSQL(ns, "", 0, 1, 0, 1)` answers the rows removed (0 when none) or an error status for an unknown namespace. Called with `""` for the namespace inside the target namespace it cleared that namespace only, so `""` is not a mutation that reddens; the AC3 mutation uses `clearStatsSQLAllNS`.
- **Batch 2 re-measurement** (`ocupilot-ci`, `USER`, 2026-11-25; probe tables dropped, statistics rows removed by routine, flag read back `0:0:0::0:0`).
  - **Values do not reach the run.** On a 5-row table, `SELECT A FROM T WHERE A > ?` with `dynArgs(1)=3` answered `Rows Returned: 0`, `Global Refs: 0`, and so did `WHERE A > 3` and `WHERE B = 'x'` with no values: the instance replaces every literal and placeholder with `?` and the statistics run binds none. The same outcome held with `preparse`, and with the statement passed as an array (`sql=1`, `sql(1)=text`). A statement with no literal and no placeholder (`SELECT A FROM T`) ran honestly: 5 rows, 6 global references. `SqlPort.Plan` with `pValues` answered the same `Rows Returned: 0`.
  - **The bound.** A self join of 1,500 rows ran 16.1 s under `Executed` with no bound, answering a row; under a bound of 2 s and of 5 s it ran 14.4 s and 17.0 s and answered SQLCODE -450 `stopped`. Under the same 2 s alarm `Explain` with statistics ran 16.5 s and answered status OK with its plan text holding `ERROR #5521: SQLError: SQLCODE=-450 ... timed out due to user timeout`. So the alarm is honoured as `Run` honours it (the stop is raised by the engine when the statement ends or at its next check, and reported), and `Explained` reads the -450 from the plan text, from the status or as an `<ALARM>` exception. A 40-row five-way self join under a 2 s bound answered `stopped` from `Plan` (`SqlPortLive`). The stop arrives no sooner than `Run`'s does.
  - **A stopped or refused plan records no row.** The stopped five-way join, a refused UPDATE and a refused CREATE TABLE each left no statistics row for its tables (read by routine after the run).
- **Set consequence re-measurement** (rework 1, `ocupilot-ci`, `USER`, 2026-11-25; table dropped, rows removed by routine, flag restored to `0:0:0::0:0` and read back). A query prepared at level 0 recorded 0 rows after a set to 2 (`M:5:0`), on two runs in a fresh process; after `PurgeForTable` and a prepare at level 2 it recorded 1 row. The second sentence of the set consequence measured true and ships.
- **Rows.** `%SYS_PTools.StatsSQL` holds the current namespace's rows only, so every read runs in the target namespace. Each recorded run adds one group: a statement run twice holds one summary row and each module twice, so the list's id `[Routine, Cursor, Module]` repeats for such a statement (reported to the orchestrator for Batch 3).

**Mutations (Rule 19).** One per AC. Each is applied, observed red and reverted, the tree is confirmed identical, and the source is reloaded.

- AC1: `Catalog.RuntimeStats` drops the summary row's averaging (`RowCount` not divided by `RunCount`) -> `SqlRuntimeStatsRead.TestTheListAndTheAgentsReadAnswerTheSameRows` red, 3 assertions. It selects `UserName` -> `TestTheListSelectsNoIdentifyingColumn` red. Observed red 2026-11-25.
- AC2: `SqlStatsTarget` builds an empty stop for a level of 2 or 3 -> `SqlRuntimeStatsWrite` red, 4 of 6 tests (the defaults leg, the agent's and the refusals' among them). `ConfigSettingRules.StopRefused` answers 0 -> `TestARefusedSetChangesNothingOnEitherCaller` red. `ConfigPort.Admit` drops its `SQLStats` branch -> `SqlRuntimeStatsRead.TestTheGatesAndIdShapesRefuseBeforeAnyCall` red. Observed red 2026-11-25. (The spec named `SendNode`'s branch; the branch lives in `SqlStatsTarget` and `SendSqlStats`.)
- AC3: `PURGESTATS` passing `""` for the namespace stays green (measured, Task 0). `StatementCall` calling `clearStatsSQLAllNS` -> `SqlRuntimeStatsWrite.TestThePurgeRemovesTheNamespacesRowsOnBothCallers` red on the other namespace's surviving rows. `TuningSnippet` naming `clearStatsSQLAllNS` -> `SqlRuntimeStatsRead.TestTheCopyOutScriptsAreTheirOneVendorCall` red. Observed red 2026-11-25.
- AC4: `Explained` drops the `stats` qualifier -> `SqlRuntimeStatsRead.TestPlanWithStatisticsCarriesModuleStatisticsAndRecordsItsRows` red, 3 assertions. `Plan` skips its query-only check -> `TestPlanWithStatisticsTakesAQueryOnly` red, 4 assertions (the UPDATE and CREATE TABLE ran nothing even so, as measured). `Explained` never sets the alarm -> `SqlPortLive.TestAPlanWithStatisticsPastTheBoundIsStopped` red. `HandlePlan` passes `stats` 0 -> `SqlConsoleRoutes.TestThePlanRouteTakesStatsForAQueryOnly` red, 2 assertions. Each reverted, tree identical (`git diff` checksum), source reloaded. Observed red 2026-11-25. (Batch 2; values reaching the run is not pinned, see the Batch 2 measurement.)
- AC5: `slowquery` loses the step -> `WorkflowCatalog.TestTheSlowQueryWorkflowReadsTheStatementIndexAndWritesNothing` red. Observed red 2026-11-25.
- AC4 (client, Batch 3): `SqlQueryState.body` drops `stats: true` from Plan with statistics' body -> `sql-query.page.spec.ts` "plans with statistics" red, and, after rebuild and redeploy, the browser spec's AC4 red on the plan lacking `Stats:`. Reverted, tree identical (`git diff` checksum), rebuilt and redeployed. Observed red 2026-11-25.
- AC6: `SqlRuntimeStatsPage` drops its `actions.register` of Purge statistics -> after rebuild and redeploy the browser spec's AC1 (the bar offers Purge statistics) and AC6 (Purge statistics asks, confirms and empties the list) red. Reverted, tree identical (`git diff` checksum), rebuilt and redeployed. Observed red 2026-11-25. (The spec's first form, the descriptor losing its row action, is refused by `screen-mirror.mjs` before it can build: a list with no action may not declare `emptyAgentKey`.)
- Rework 1, each applied, observed red and reverted (tree identical, source reloaded or bundle rebuilt and redeployed), 2026-11-25:
  - Plan note, model: the list's `read.label` drops the ruled sentence -> `SqlRuntimeStatsRead.TestTheListsDescriptionToTheModelCarriesThePlanNote` red; the `slowquery` step drops it -> `WorkflowCatalog.TestTheSlowQueryWorkflowReadsTheStatementIndexAndWritesNothing` red.
  - Plan note, client: `SqlQueryPage.hasStatisticsNote` answers false -> `sql-query.page.spec.ts` "shows the ruled note..." red; `planWithStatistics` skips recording its answer -> the same test red; the template drops the `stats-note` paragraph -> after rebuild and redeploy the browser spec's AC4 red.
  - AD-36: `Screen.Read.Execute` sets `truncated` 0 -> `SqlRuntimeStatsRead.TestTheListCapsItsRowsAndReportsTheCut` red. The port's own caps (`CatalogRows`' `max` and its row loop) both disabled stays green: the shared reader trims and reports the cut.
  - The write class's first assertion: `CollectRoster` answers a level of 3 -> it goes red, with three others of the class.
  - Changed target: `ExplorerSqlRuntimeStatsSettingSet.MergeUpdate` adds no `Was` -> `SqlRuntimeStatsWrite.TestALevelMovedSinceTheMintRefusesTheConfirm` red (the confirm answered 200). The set tool carried no such guard before this test, so a level moved after the mint was not refused.
  - `ConfigPort.SqlStatsState`'s `pLevel >= 2` guard dropped -> `SqlRuntimeStatsWrite` stays green (7 of 7): after a set to 2 and then 0, and at expiry, the vendor reads the stop empty, so the guard is defensive on this build and no test can pin it.

## Auto Run Result

Status: done
Blocking condition: none

**Rework 1 summary.** The ruled note "Plan with statistics runs the statement without its values, so a filtered query can show zero rows." now shows beside every Plan with statistics result on SQL query (`sqlPlanStatisticsNote`, EXPERIENCE.md Fixed strings row, add-only), ends the list's `read.label` for the model, and ends the `slowquery` runtime statistics step. The set consequence's second sentence re-measured true and stays. The setting tool now refuses a confirm after the level moved (`MergeUpdate` adds `Was`, as `AnalyticsSettingSet`). New or changed tests: AD-36 truncation and the model-facing note in `SqlRuntimeStatsRead`, the changed-target leg and the made-able-to-fail first assertion in `SqlRuntimeStatsWrite`, the step note in `WorkflowCatalog`, `sql-query.page.spec.ts` and the browser spec's AC4. The `pLevel >= 2` mutation stayed green, so its deferred entry is closed.

**Verification.** `SqlRuntimeStatsRead` 10/10, `SqlRuntimeStatsWrite` 7/7 (armed), `WorkflowCatalog` 10/10, `ReadDescriptions` 9/9, `ReadTool` 28/28, `ToolWrite` 33/33, `ConfigSettingRules` 7/7, `ConfigSettingRead` 9/9, `npm run test:tools` 2415/2415, `npm run test:components` 3966/3966, `npm run build`, the new browser spec 4/4 and `system-explorer-sql-statements` 5/5 in both orders, `check-objectscript` and `lint-docs` clean. Mutations: Verification, "Rework 1".

**Review (rework 1).** Verification-gap and intent-alignment layers: 5 findings, 1 low patched (two doc comments on the values), 4 low rejected with reasons in the triage log, 0 deferred. Follow-up review recommended: `false` (no high patched).

**Residual risks.** Epic 24 has commits on `EXPERIENCE.md` and `strings.ts`; this story's edits there are add-only and may need a token union at merge.
