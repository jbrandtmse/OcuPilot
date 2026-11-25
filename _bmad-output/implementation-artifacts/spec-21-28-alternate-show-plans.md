---
title: 'Story 21.28: Alternate show plans'
type: 'feature'
created: '2026-11-25'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-26-runtime-statistics.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-27-the-index-analyzer-and-its-advice.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic Alternate Show Plans page is the only place to list the plans the optimizer considered for a statement, read one of them, and compare chosen plans by running the statement under each. Nothing in OcuPilot offers it, and the `slowquery` workflow cannot read it.

**Approach:** SQL query gains Alternate plans: a Possible plans table for the statement (plan, cost, map type, starting map), Show plan for one row, and Compare plans for up to five chosen rows, which answers each plan's run statistics. All of it goes through `SqlPort.Plan` and the plan route. Listing runs nothing. Comparing is a read on SQL query, as Plan with statistics is (AD-7, U-161): query only, under the console's time limit, without values. An agent read, `explorer.sqlalternateplans.read`, answers the same rows. `slowquery` gains that read and stays read-only.

## Boundaries & Constraints

**Always:**

- The statement reaches the vendor whole, as an argument value. It is never concatenated into SQL or code (AD-21). Plan ids are whole numbers the port checks against a fresh list of possible plans, read in the same request before any run. The port builds the vendor's comma-separated id text itself.
- The console's order holds for every new call: the screen gate, the body's bounds, then `SqlConsole.Check` (the checked prepare plus the self-protection set). Only after that does anything reach the vendor.
- A compare takes a query only, refused before anything runs otherwise. It runs once under `SqlPort.BoundSeconds`, so an overrun answers `stopped`. The client posts no values.
- The screen and the agent read answer the same rows from one port call (AD-36). Plan text and rows reaching the model go through AD-60's sanitizer.
- Tests remove every runtime-statistics row, cached query and probe table they cause, and read each back absent.

**Never:**

- No write, no proposal, no governance key, no entity type, no descriptor and no AD-10 arm: this story changes nothing on the instance beyond the vendor's own recording (Task 0 (f)).
- No background run and no `job`. No query history and no Plan Format choice. No plan text with statistics per row: compare answers numbers.
- No edit to `Api/Error.cls`. The spine stays add-only. No test or write on `ocupilot` or a slot instance. No probe schema whose name holds `"` (DW-2851).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | A query over the probe table with conditions on two indexed fields | `{outcome: "plans", kind, plans: [{Plan, Cost, MapType, StartingMap}], truncated}`, at least two rows, nothing run. The screen and `explorer.sqlalternateplans.read` answer the same rows | More than 100 plans: cut, `truncated` true (AD-36) |
| List, DML | An `UPDATE` of the probe table | Its possible plans, and no row changes (Task 0 (h)) | none |
| Show plan | `plan` set to a listed id | `{outcome: "plan", kind, alternate, plan, truncated}`, that plan's text only | An id not listed: 400, ruled sentence, nothing else called |
| Compare | `compare` with two listed ids, a query | `{outcome: "compared", kind, plans: [{Plan, Cost, StartingMap, GlobalReferences, Commands, TotalTime, Rows}]}`, one row per id, and the ruled note on screen | Past the bound: `{outcome: "stopped", kind, seconds}` |
| Compare, not a query | `compare` on an `UPDATE` | 422 with the ruled sentence before anything runs | none |
| Bad ids | `compare` empty, more than 5 entries, repeated entries, not whole numbers, or ids not listed | 400 with the ruled sentence before any run, from both callers | none |
| Own tables | A statement over `OcuPilot_Kernel_State.Turn` | Refused by `Check` (`PROHIBITED.OCUPILOTSQL`) before any vendor call | none |
| Not prepared | A statement the caller lacks `SELECT` for, or with a syntax error | The console's `error` outcome before any vendor call | none |
| Gate | Missing the SQL query screen's pairs, or a custom resource on the classic page (record 3) | 403 naming the pair before any call | none |
| Workflow | A `slowquery` turn | Its steps name `explorer.sqlalternateplans.read` and no write | none |

</intent-contract>

## Code Map

- **Vendor sources (read-only), confirmed on `ocupilot` via `ocupilot-slot-a` doc search:**
  - `irislib/%CSP/UI/Portal/SQL/QButtons/ShowPlanAlt.cls`:
    - `RESOURCE` `%Development:USE` :8. The list is `GetPlansTable` :92-117 and the compare is `ComparePlansTable` :157-185.
    - The foreground path :348-354 and :409-415 runs `%SYS.PTools.StatsSQL:possiblePlans(query)` and `:possiblePlansStats(query, ids)`. Show Plan :443-455 opens `%SQL.Manager.ShowPlan` with `AltPlan=ID`.
    - `JobPossiblePlans` :644 and `JobComparePlans` :666 are the background form, which is not used. `PrepareShowPlan` :612 writes `^mqh($Username)` and is not called.
  - `irislib/%SYS/PTools/StatsSQL.cls`:
    - `possiblePlans` :3474. Its execute :3499 calls `ShowPlanAlt^%apiSQL(.sql,1,,,,,1,,1)`, with preparse 1. Fetch :3539 reads `%AltPlan(id,0)` for the cost, map type and starting map.
    - `possiblePlansStats(sql, ids)` :3590 takes `ids` as a comma list. Its execute :3617 runs with stats 1 and preparse 0. Fetch :3660 parses the `<stats>` block, and its locals are undefined when no block exists (Task 0 (b)).
    - Both executes call `%SQL.Manager.ShowPlan.ShowPlanSQLError` on an SQL error, which writes to the device (Task 0 (g)).
  - `irislib/%SYSTEM/SQL.cls` `Explain` :4312 takes qualifiers `alt`, `ids` ($LIST of cost ids) and `stats` (doc :4185-4191). Its deprecated wrapper is `ShowPlanAlt` :4449. `%SQL/Manager/ShowPlan.cls:114` shows one plan as `%AltPlan(AltPlan)`.
- **`src/OcuPilot/Port/SqlPort.cls`:**
  - `Plan` :796 classifies, refuses a non-query `pStats` (`RefuseFor("planstats")`), bounds, then calls `Explained` :2436, which runs `$SYSTEM.SQL.Explain` with the alarm, rollback and `stopped` reading.
  - Also relevant: `BoundSeconds` :502, `ErrorAnswer`, `Fail`, `RefuseFor` :2547, `MAXANSWER`, `OUTCOMEPLAN`/`OUTCOMESTOPPED` :379-381 and `KINDQUERY`/`KINDDML`.
- **`src/OcuPilot/Area/Explorer/SqlConsole.cls`:** `HandlePlan` :78, `Prepare` :107, `Read` (`pAllowStats`), `Body` and `Check`. The route is `Api/Router.cls` `POST /explorer/sql/plan`.
- **`Kernel/Utils.cls`:** the null-device helper that Story 21.27 hoists from `AdvisorPort.SetFlag` :334.
- **`Screen/Tool/ExplorerSqlRead.cls`:** `explorer.sqlquery.read` (`DESCRIPTORCLASS` `ExplorerSqlQuery`, `InputSchema`, `PrivilegePairs`, `ResultSchema`). Story 21.27's `ExplorerSqlAdviceRead` is the sibling subclass.
- **`Screen/Gate.cls`:** `WithClassicPages` :383 and `ClassicResource` :580.
- **`Api/AtelierError.cls`:** `SQLPLANSTATS`/`REASONSQLPLANSTATS` :413-417 is the sibling of the new codes.
- **`Kernel/Agent/Workflow.cls`** `slowquery` :261-269, after 21.26's step :265 and 21.27's.
- **Client:**
  - `ui/src/app/areas/system-explorer/sql-query.store.ts`: `SQL_PLAN_PATH` :36, `STATS_VALUE` :52, `planWithStatistics` :275 and `body` :361.
  - `sql-query.page.ts` and `.page.spec.ts`.
  - `core/strings.ts` :5551-5564 and :5749-5751. Reuse `processColumnCommands`, `processDetailsGlobalReferences`, `explorerSqlColumnRows`, `explorerSqlColumnTotalTime` and `explorerSqlPlanHeading`.
- **Tests to follow:**
  - `Test/SqlTuningProbe.cls` (`Make`/`Remove`, 21.26's `RecordStats`/`RemoveStats` by routine).
  - `Test/SqlRuntimeStatsRead.cls` (the Plan with statistics legs), `SqlPortLive` (the bound and the open-transaction legs), `SqlConsoleRoutes`, `SqlAgentRead` and `WorkflowCatalog`.
  - `ui/browser/system-explorer-sql-runtime-stats.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:** Task 0 first, then two batches, each committed on its own. A handoff builds one batch. Build after Story 21.27 is on the branch. Strings are only the ruled set (Design Notes, "Strings, escalated"). Any other sentence a person reads is `## Clarification Needed`.

**Task 0, measured on `ocupilot-ci` before code, in `USER` and `HSCUSTOM`.** Record each result under Verification. Remove every probe table, cached query, runtime-statistics row and principal, and read each back absent.

- (a) **Privilege.** Use a principal holding only the SQL query screen's pairs plus `SELECT` on the probe table:
  - Can it list, show and compare?
  - Without `SELECT`, is it stopped at the checked prepare before any vendor call?
  - Do the class queries check SQL privileges themselves?

  A pair the vendor needs beyond the screen's joins the gate. A refusal the screen's audience cannot pass is a HALT `intent gap`.
- (b) **Durations and the bound.**
  - Time listing a five-table join (worst case) and a compare of five plans against the 60 s gateway limit.
  - Does `$System.Alarm` stop plan generation, and a compare? What does a stopped compare leave and answer, including the fetch's undefined locals?
  - If listing's worst case times 1.5 reaches the limit and the alarm does not stop it, stop and report (record 1).
- (c) **One plan's text.** Does `Explain(.text, {"alt":1,"ids":$ListBuild(id),"silent":1}, , .plan)` answer only that plan, with the cost the list shows? Do the ids from `possiblePlans` and `possiblePlansStats` name the same plan (cost and starting map)?
  - If `ids` does not select, use `$SYSTEM.SQL.ShowPlanAlt(.text, 1, 0, "", "", 1, id, 1)` and join `%AltPlan(id, 1..n)`, then kill `%AltPlan`. Record which form was used.
- (d) **The probe.** Find a probe table and query with at least two possible plans. Is plan 1 the plan Explain plan shows?
- (e) **Values.** With `possiblePlansStats`' preparse 0, does a compare run a literal as written, and an unbound `?` as nothing? This fixes the compare note (string 7).
- (f) **Side effects** of a list and of a compare:
  - runtime-statistics rows by routine;
  - statement-index rows;
  - cached queries;
  - an open transaction;
  - leftover `%AltPlan` or other globals.

  Anything beyond the first three stops the stage with a report.
- (g) **Device output.** Does either class query write to the current device for a statement with an SQL error? Does the null device swallow it?
- (h) **DML.** Does listing an `UPDATE`'s plans change a row?
- (i) **Unknown ids.** What does `possiblePlansStats` answer for an id it does not list? This pins the port's pre-check.

**Batch 1, server.**

- `src/OcuPilot/Port/SqlPort.cls`:
  - `Plan` gains `pAlternates` (default 0), `pPlanId` and `pCompare` (a `%DynamicArray`). The existing classification and `error` answer stay first.
  - With `pAlternates` 1 it calls a new private `Alternates`, which runs the vendor's calls through the 21.27 null-device helper, in the namespace, under one alarm set at `BoundSeconds`. Each class query runs through `%SQL.Statement.%PrepareClassQuery("%SYS.PTools.StatsSQL", …)` with the statement text bound as its argument. Rollback and `stopped` are read as `Explained` reads them.
  - The cases:
    - Neither id: the list.
    - `pPlanId`: the list first, then that plan's text (Task 0 (c) form).
    - `pCompare`: query only (else 422 `EXPLORER.SQL.ALTCOMPARE`), the list first, every id listed (else 400 `EXPLORER.SQL.ALTPLAN`), then `possiblePlansStats` with the port-built id text.
  - The answer shapes are the matrix's. The list is capped at `ALTMAXPLANS` 100, and a compare takes 1 to `ALTMAXCOMPARE` 5 distinct ids (else 400 `EXPLORER.SQL.ALTCOUNT`).
- `src/OcuPilot/Area/Explorer/SqlConsole.cls`:
  - `Read`/`Body` accept `alternates` (boolean), `plan` (whole number) and `compare` (array of whole numbers) on the plan route only, never with `stats` true. A malformed key is the existing input refusal.
  - `HandlePlan` adds the classic page's custom resource to the gate when `alternates` is true (record 3), then passes the keys on.
- `src/OcuPilot/Api/AtelierError.cls` (add-only): `SQLALTCOMPARE`, `SQLALTPLAN` and `SQLALTCOUNT`, each with its `REASON*` ruled sentence.
- New `src/OcuPilot/Screen/Tool/ExplorerSqlAlternatePlansRead.cls` (`explorer.sqlalternateplans.read`), extending `ExplorerSqlRead` as 21.27's advice read does:
  - It takes `statement` and an optional `compare` (1 to 5 integers) and calls `SqlPort.Plan(…, pAlternates 1)`.
  - It refuses a kind other than a query as its parent does. `PrivilegePairs` unions `Gate.WithClassicPages(…, "%CSP.UI.Portal.SQL.QButtons.ShowPlanAlt")`.
  - Its description carries the ruled note.
- `src/OcuPilot/Kernel/Agent/Workflow.cls` -- `slowquery` gains the ruled step after 21.27's.
- `src/OcuPilot/Test/SqlTuningProbe.cls`:
  - `MakeAlternates(ns)` creates `OcuProbe228` with two indexed fields and rows giving two or more plans (Task 0 (d)).
  - `RemoveAlternates(ns)` removes the statistics rows by routine, purges the table's cached queries and drops the table.
- New `src/OcuPilot/Test/SqlAlternatePlansRead.cls`. It covers:
  - the list on both callers, equal, with at least two rows and the columns pinned;
  - a DML list changing no row;
  - Show plan answering one plan, with an unlisted id refused;
  - compare on both callers, one row per id with numbers, then its rows removed and read back absent;
  - the compare refusals (DML, count, repeats, unlisted), each calling nothing (the seam counts calls);
  - `Check` and the error outcome before any call;
  - the gate, including the classic page's custom resource through `ClassicResource`'s override;
  - AD-36 truncation through a seam.

  A bound leg goes in `SqlPortLive`.
- Shared surfaces (Verification): update each test that pins the read-tool roster, with the name read from the instance.

**Batch 2, client.**

- `sql-query.store.ts`, `sql-query.page.ts` and their spec:
  - An Alternate plans button beside Plan with statistics posts `{alternates: true}`.
  - The answer shows Possible plans: one row each, with a checkbox, a Show plan action and the four columns.
  - Show plan posts `{alternates: true, plan: id}` and shows the text in the plan pane.
  - Compare plans, enabled for 1 to 5 checked rows, posts `{alternates: true, compare: [ids]}` with no values. It shows Compared plans (seven columns) with the ruled note on every result.
  - Each refusal shows its ruled sentence.
- `core/strings.ts` (add-only) -- the ruled strings. Then regenerate the mirror and `Titles.cls` if the generator reads them (`node tools/screen-mirror.mjs`).
- `EXPERIENCE.md` -- one add-only Fixed strings row for 21.28.
- New `ui/browser/system-explorer-sql-alternate-plans.browser-spec.mjs`. It refuses the live container and waits on each answered signal:
  - Alternate plans lists the probe's plans;
  - Show plan shows one;
  - Compare plans with two checked rows shows two compared rows and the note.

  Its `after` hook removes the probe.

**Acceptance Criteria:**

- AC1. Given the probe's query on the throwaway, when the person chooses Alternate plans and the agent calls `explorer.sqlalternateplans.read` with the same statement, then both answer the same possible plans with the matrix's columns, and nothing ran.
- AC2. Given the listed plans, when the person chooses Show plan on one row, then that plan's text alone shows. When the person or the agent compares two listed plans, then each answers its run statistics, the ruled note shows, and the rows the run recorded are the only side effect. A compare of a statement that is not a query, or of ids not listed, is refused before anything runs.
- AC3. Given the `slowquery` workflow, when a turn follows it, then its steps name `explorer.sqlalternateplans.read` and no write tool.
- AC4. Given the throwaway, when the browser spec runs forward and in reverse with `system-explorer-sql-runtime-stats.browser-spec.mjs`, then it passes and leaves no probe table, cached query or statistics row.

## Spec Change Log

- 2026-11-25, orchestrator rulings at the plan gate (veto U-166 for items 1, 3 and 5), authoritative over the Design Notes records and Tasks where they differ:
  1. **AD-7** (veto U-166): allowed, add-only, written by the runner, the safer form. Listing and showing plans are reads that run nothing, on both callers. Comparing is a person's read on SQL query only: `explorer.sqlalternateplans.read` takes NO compare argument. Comparing stays query-only, at most five plans, under the console's time limit, without values; plan ids are checked against a fresh list before anything runs, pinned by a test.
  2. **AD-51:** decided, no named entry. The statement goes whole as a bound value and the port builds the id list (AD-21's console clause); concatenating the statement into SQL text fails review.
  3. **Gate** (veto U-166): the actions and the agent read also honour any custom resource an operator puts on `%CSP.UI.Portal.SQL.QButtons.ShowPlanAlt`. 21.26's and 21.27's console actions stay as they are; the question whether they should is a LOW ledger entry owned by burn-down, with this story's measurement as evidence.
  4. **Compare limit:** decided, five, a named constant with boundary tests at 5 and 6.
  5. **Strings** (veto U-166): accepted with these changes. The agent read's description says it lists and shows plans and runs nothing (no compare note). The `slowquery` step reads: "Read the alternate plans for the slowest query and, when another plan costs less than the one the optimizer chose, suggest the person compare the two from SQL query; a comparison runs the query once for each plan without its values." "Only the first 100 possible plans are listed." uses a named constant with an AD-36 boundary test. The empty-state sentence and the compare note ship as measured, otherwise the fallback.

## Review Triage Log

## Design Notes

**Governing ADs (spine line ranges):**

- AD-7 :211-257, with the Plan with statistics case (U-161) and 21.27's advice line (record 1).
- AD-10 :393-460 and its console clause: no new arm, since `Check` covers own tables.
- AD-21 :615-665, the console clause: the statement is the caller's own SQL, and ids are port-built.
- AD-29 :796 and AD-44 (record 3).
- AD-36 :876, AD-39 and AD-60.
- AD-51 :1216-1294: no named entry, because no write (record 2).
- AD-61, as the console's checked prepare, and AD-66 :1537.

**Records for the orchestrator** (proposed, add-only; the runner writes each one if allowed):

1. **AD-7** (after :257). Recommendation: allow.
   - Precedent: U-161 made Plan with statistics a person's read, and `explorer.sqlquery.read` already runs the agent's query in the turn job.
   - Proposed text: "**Alternate plans (Story 21.28)** are a read on SQL query and through `explorer.sqlalternateplans.read`. Listing a statement's possible plans and showing one compile plans and run nothing. Comparing chosen plans runs one statement the console types a query once per chosen plan, at most five, in the request or the turn job, under the console's time limit, through `%SYS.PTools.StatsSQL`'s `possiblePlansStats`; any other kind is refused before it runs. Its side effects are the runtime statistics rows the vendor records for each run and the fifth shape's statement-index row."
   - The last sentence is *measure-first*, Task 0 (f). The safe alternative is a person-only compare: no `compare` argument on the agent read.
2. **AD-51: no named entry.** Recommendation: allow.
   - This story adds no write, proposal, governance key or entity type. AD-51 names vendor calls for action-style writes only.
   - The vendor's arguments are the statement, passed whole as a value, and the port-built id list, recorded under AD-21's console clause by this record's adoption.
3. **Gate (AD-29, AD-44).** Recommendation: allow, as stricter than classic, never looser.
   - The route's alternates actions and the agent read require the SQL query screen's pairs, which include the classic page's `%Development:USE`. They also require the custom resource an operator assigns to `%CSP.UI.Portal.SQL.QButtons.ShowPlanAlt`, read on every call through `Gate.WithClassicPages`.
   - 21.26's and 21.27's console actions did not add their pages' custom resources. That gap stays theirs: no edit to their code.
4. **Compare limit.** Recommendation: five plans per compare, on both callers. The classic page has no limit, and every chosen plan runs the statement once more.

**Decided in-stage:**

- **Placement.** Alternate plans is a SQL query action beside Plan with statistics, because it is about one statement and the console owns it. No new screen, no descriptor and no side-bar position.
- **Vendor calls.** The class queries the classic page's foreground path runs, rather than the background `Job*` methods or a direct `ShowPlanAlt^%apiSQL` call. They are the vendor's own SQL procedure interface, and they parse `%AltPlan` the same way the classic table shows it. One plan's text uses Task 0 (c)'s measured form.
- **Listing takes a query or a DML statement**, as Explain plan does, and runs nothing (Task 0 (h)). Comparing takes a query only, as Plan with statistics does. The agent read takes a query only, as its parent does.
- **Ids are checked against a fresh list** read in the same request, so an unlisted id is refused before anything runs, whatever the vendor does with it (Task 0 (i)).
- **No plan text with statistics, no Plan Format and no history.** Compare answers numbers, as the classic Compare table does. Query history has no owner (epic context).
- **Epic context reuse.** The spine and EXPERIENCE.md are newer than `epic-21-context.md`, only by 21.26's and 21.27's add-only lines. Those were read here directly, so the context was not recompiled (the plan block's instruction).

**Strings, escalated as one batch** (none is in EXPERIENCE.md). *Measure-first* clauses ship only as measured, and any correction is reported verbatim.

1. **Action:** "Alternate plans" (classic "Alternate Show Plans"; siblings "Plan with statistics" and "Advise").
2. **Headings:** "Possible plans" (classic) and "Compared plans" (classic "Compare Possible Plans").
3. **Columns:**
   - New: "Cost" · "Map type" · "Starting map" (classic headers).
   - Reused: "Plan", "Global references", "Commands", "Total time" and "Rows".
4. **Row actions and button:** "Show plan" (classic "Show Plan") · "Compare plans" (classic "Compare Show Plans with Stats").
5. **Hint:** "Check up to five plans to compare." (classic: "You may check multiple IDs from the table below, then click the 'Compare Show Plans' button.")
6. **Empty state:** "The instance offered no plan for this statement." *Measure-first:* Task 0 (d); dropped if a preparable statement always answers one.
7. **Compare note**, on every compared result, on the model-facing result and in the step: "Compare plans runs the statement once for each plan, without its values, so a filtered query can show zero rows." (sibling: `sqlPlanStatisticsNote`). *Measure-first:* Task 0 (e). If a literal runs as written, the note becomes "Compare plans runs the statement once for each plan, without the values for its ? placeholders."
8. **Refusals:**
   - `REASONSQLALTCOMPARE`: "Compare plans runs the statement, so it takes a query only." (sibling `REASONSQLPLANSTATS`)
   - `REASONSQLALTPLAN`: "Choose a plan from this statement's possible plans."
   - `REASONSQLALTCOUNT`: "Choose from one to five possible plans to compare."
9. **Truncation:** "Only the first 100 possible plans are listed." (sibling `explorerSqlDataTreeCut`, "Only the first 1,000 are listed."). Show plan's text cut reuses whatever Explain plan shows today.
10. **The agent read's description:** "List the plans the optimizer considered for one SQL query, with their cost, map type and starting map, and optionally compare up to five of them by running the query once for each; send the plan numbers in compare. " followed by string 7. Model-facing, not shown to a person.
11. **The `slowquery` step:** "Read the alternate plans for the slowest query and, when another plan costs less than the one the optimizer chose, compare the two; say that a comparison runs the query once for each plan without its values." *Measure-first:* the last clause follows string 7.

**Extend, don't copy (Rule 2/31):**

- The port work extends `SqlPort.Plan`, and the bound reading is `Explained`'s.
- The route extends `SqlConsole.HandlePlan`/`Body`, as `stats` did.
- The agent tool extends `ExplorerSqlRead`, as 21.27's advice read does.
- The classic page's custom resource reuses `Gate.WithClassicPages`.
- The null device is 21.27's `Kernel/Utils` helper.
- The fixture extends `SqlTuningProbe`.

**Integration ACs:** SQL query and the agent read consume `SqlPort.Plan`'s alternates (AC1, AC2), and `slowquery` consumes the read (AC3).

- **Consumed-by:** none planned. 21.29 adds no workflow read.
- **Consumes:**
  - Story 21.26's Plan with statistics (bound, query-only guard, note pattern) and `RecordStats`/`RemoveStats`;
  - Story 21.27's null-device helper and advice read shape;
  - Story 19.6/19.11's console `Classify`, `Check` and `ExplorerSqlRead`;
  - Story 20.12's workflow catalog.

**Ledger inbox:** none. DW-2851 is a constraint, not owned.

**Contended paths (Epic 24), checked 2026-11-25** with `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp`:

- Commits on `strings.ts`, EXPERIENCE.md, `Test/ReadTool.cls` and `Test/SurfaceCoverage.cls`, so edits there are add-only.
- None on `SqlPort`, `SqlConsole`, `AtelierError`, `ExplorerSqlRead`, `Workflow`, `Kernel/Utils`, `SqlTuningProbe` or the system-explorer client files.

**Size:** 1 read tool, 1 route extension, no write, about 16 files, in two batches.

## Verification

**Shared surfaces** (all `(loop)`):

- The tool registry: `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolRoundTrip`, `StageTwoTools`, `DeveloperFloor`, `SurfaceCoverage`, `DraftRegistry` and `SqlAgentRead`.
- The console: `SqlConsoleRoutes`, `SqlConsoleWrite`, `SqlPortLive`, `SqlRuntimeStatsRead` (Plan's signature) and `sql-query.page.spec.ts`.
- The workflow: `WorkflowCatalog` and `suggested-prompts.test.mjs`.
- Gates: `PortGate` and `ClassicPageGate`.
- Rosters: `EndpointCoverage` (the route is unchanged; confirm) and `MappingDescriptor` `CLASSICROSTER` (unchanged: the read declares no `CLASSICPAGES`; confirm).

Grep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each surface. Each test changed joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Each runs in its own foreground call with `timeout: 600000`, against `ocupilot-ci` only, one test call per message.

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/e21-kit/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SqlAlternatePlansRead` -- expected: green. Then, one class per call, each expected green: `SqlPortLive`, `SqlConsoleRoutes`, `SqlRuntimeStatsRead`, `WorkflowCatalog`, `SqlAgentRead`, and every shared-surface class above.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/screen-mirror.test.mjs tools/suggested-prompts.test.mjs tools/self-protection.test.mjs` -- expected: green.
- `(loop)` Four steps, then the specs:
  1. `cd ui && npm run build`
  2. `npm run test:components`
  3. `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  4. `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-sql-alternate-plans.browser-spec.mjs browser/system-explorer-sql-runtime-stats.browser-spec.mjs`

  Expected: green, and green in reverse order.
- `(once)` `cd ui && npm run test:tools` -- expected: green (EXPERIENCE.md changes).
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC, each recorded here as `mutation: … -> …` when observed:**

- AC1: `Alternates` drops `MapType` or skips the cap -> `SqlAlternatePlansRead`'s list leg or truncation leg red. The agent read calls `Plan` without `pAlternates` -> the equal-on-both-callers leg red.
- AC2: `Plan` skips the compare's query-only check -> the DML compare leg red (seam counts a call). The id pre-check is removed -> the unlisted-id leg red. The store drops the note -> `sql-query.page.spec.ts` red.
- AC3: `slowquery` loses the step -> `WorkflowCatalog` red.
- AC4: the page drops Compare plans' post -> after rebuild and redeploy, the browser spec red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
