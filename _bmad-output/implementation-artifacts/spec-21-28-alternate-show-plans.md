---
title: 'Story 21.28: Alternate show plans'
type: 'feature'
created: '2026-11-25'
status: 'done'
baseline_revision: '59243ea80bcfd513b4bf83fbbddfd080b8e09c41'
baseline_commit: '59243ea80bcfd513b4bf83fbbddfd080b8e09c41'
review_loop_iteration: 0
followup_review_recommended: true
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

**Handoff scope (edited between handoffs): HANDOFFS 1 AND 2 (Batch 1) ARE DONE, GREEN AND COMMITTED; do not redo them. HANDOFF 3 = Batch 2, the client, and nothing else: its block is the last in this paragraph. What follows until that block is Batch 1's record: the Spec Change Log entries of 2026-11-26 (all three) win over the Batch bullets and Design Notes wherever they differ, and the Batch 1 bullets are read through them: the agent read takes NO `compare` argument, the compare is one `possiblePlansStats` call per id with no alarm, the compare text is the statement's own parameterized text with `%NOPARALLEL`, and the class queries are prepared checked. Build, in this order:**

1. **`OcuPilot.Port.SqlAlternateScan`** (new, pure: no instance access, no state). `Count(pText, ...)` returns the table and condition counts by the addendum's "Counting" rule: tokenize, drop comments, string literals and delimited identifiers; TABLES = FROM keywords + commas at the same depth up to the next clause keyword + JOIN keywords + one per UPDATE or INSERT INTO target; CONDITIONS = WHERE, ON, AND, OR, `&`, `!`, HAVING + one per column of each USING. It takes the view texts as an argument so it stays pure: each view relation adds the same two counts over its own `ViewQuery`, and tables is the larger of that sum and the relation count. A second method inserts `%NOPARALLEL ` after each FROM token that opens a FROM clause, SQL-aware (never a text replace): not after a FROM inside SUBSTRING, TRIM or EXTRACT, not after DELETE's FROM (a syntax error there), nothing inside a comment, string literal or delimited identifier (a quoted identifier named `from`), and a subquery's FROM is covered. One more method answers whether counted conditions are fewer than tables minus one (the cross-product rule). New test class `OcuPilot.Test.SqlAlternateScan` (pure, no instance state): boundary tests at 4 and 5 for tables and for conditions, comma, JOIN, USING, aliases of one table, `&` and `!`, the view-expansion case (a view whose own text repeats one table), every `%NOPARALLEL` case above, and the cross-product boundary. If the scanner cannot count a shape reliably, HALT `blocked` naming it.
2. **`Api/AtelierError.cls`** (add-only; `Api/Error.cls` is frozen): `SQLALTCOMPARE` (422), `SQLALTPLAN` (400) and `SQLALTCOUNT` (400) with the ruled sentences of Design Notes string 8; `SQLALTBOUND` (422) "Alternate plans take a statement with at most %1 tables and %2 conditions."; `SQLALTJOIN` (422) "Compare plans takes a statement that joins each table by a condition."; and the 403 "Reading this needs the SQL EXECUTE privilege on %1." as a sibling of the SELECT privilege refusal, `%1` the procedure the port called. Each with its `REASON*`, reachable through `SqlPort.RefuseFor` as the siblings are; fill `%1`/`%2` the way the sibling refusals that carry parameters do.
3. **`Port/SqlPort.cls`**: `ALTMAXPLANS` 100, `ALTMAXCOMPARE` 5, `ALTMAXTABLES` 4 and `ALTMAXCONDITIONS` 4 as named parameters. `Plan` gains `pAlternates` (default 0), `pPlanId` and `pCompare` (a `%DynamicArray`) after `pAdvise`; `pAlternates` with `pStats` or `pAdvise`, `pPlanId` with `pCompare`, and either of those two without `pAlternates` are the input refusal. After `Classify` and the existing `error` answer and `noplan` answers, with `pAlternates` set, in this order and each before anything reaches the vendor: the bound (scan the statement, with the view texts of the guard's relations read through `CheckedRows` on `%Dictionary.CompiledClass.ViewQuery`; over `ALTMAXTABLES` or `ALTMAXCONDITIONS` is 422 `SQLALTBOUND`); for a compare, query only (422 `SQLALTCOMPARE`), one to `ALTMAXCOMPARE` distinct whole numbers (400 `SQLALTCOUNT`), the cross-product rule (422 `SQLALTJOIN`). Then a new private `Alternates`: the list is `%SYS.PTools.StatsSQL:possiblePlans` on the caller's statement text, the class query prepared through `%SQL.Statement.%PrepareClassQuery` (checked), run through `Kernel/Utils.CallWithNullDevice`-style null-device handling, in the namespace, switched region calling vendor classes only, the result set closed and `%AltPlan` killed afterwards, no alarm (it does not stop plan generation, Verification (b)); a -99 on the procedure is the 403 EXECUTE refusal. The cases: neither id answers `{outcome: "plans", kind, plans: [{Plan, Cost, MapType, StartingMap}], truncated}` cut at `ALTMAXPLANS`; `pPlanId` checks the id against that fresh list (400 `SQLALTPLAN` if unlisted) then answers `{outcome: "plan", kind, alternate, plan, truncated}` from `$SYSTEM.SQL.Explain` with `{"alt":1,"ids":"<plain id text>","silent":1}` (plan text cut at `MAXANSWER`); `pCompare` checks every id against the fresh list, then takes the statement's own parameterized text from `$SYSTEM.SQL.Explain(.text, {"silent":1})` as the addendum describes (the lines after `SQL:` up to the blank line, `/*#OPTIONS ... */` removed, lines joined by one space), inserts `%NOPARALLEL`, and calls `possiblePlansStats` once per id with the port-built id text (the result set closed and `%AltPlan` killed before the next call), the statement without values, answering `{outcome: "compared", kind, plans: [{Plan, Cost, StartingMap, GlobalReferences, Commands, TotalTime, Rows}]}` (cost and starting map from the list). The compare measures its own elapsed seconds and, once they reach `BoundSeconds()` after a run, answers `{outcome: "stopped", kind, seconds}` with no rows and runs no further id; it sets no alarm (Task 0 (j)). A compare text the instance does not prepare, and any SQLCODE below 0, is the console's `error` outcome (`ErrorAnswer`). Roll back any transaction a run leaves open as `Explained` does. Doc comments state the contract only.
4. **`Test/SqlTuningProbe.cls`**: `MakeAlternates(ns)` and `RemoveAlternates(ns)` as the Batch 1 bullet says (table `OcuProbe228`, two indexed fields, rows giving two or more plans; removal covers the statistics rows by routine, the statement-index rows and cached queries the compare adds, and the table, read back absent).
5. **`Test/SqlAlternatePlansRead.cls`** (new, port-level legs only in this handoff; the caller legs are Handoff 2's): the list (at least two rows, the four columns), a DML list changing no row, Show plan one plan with an unlisted id refused, a compare of two listed ids answering one row per id with numbers and its rows removed and read back absent, each compare refusal (DML, count 0/6, repeats, not whole, unlisted, cross product) and the bound refusal calling nothing (a seam counts vendor calls), `Check`/the `error` outcome before any call, the `ALTMAXPLANS` boundary (100 not cut, 101 cut) through a seam, `ALTMAXCOMPARE` at 5 and 6, a stopped compare through a seam that lowers `BoundSeconds`, and the EXECUTE refusal if it is cheap. A bound leg that needs a long run goes in `SqlPortLive` only if it is cheap. Record under Verification the jobs busy before, during and after a compare of a parallel-capable statement (0 busy after).

**HANDOFF 2 (Batch 1b), the callers and the rosters. Do not touch `ui/src`, `strings.ts` or EXPERIENCE.md (Batch 2).**

1. **`Area/Explorer/SqlConsole.cls`:** `Read`/`Body` accept `alternates` (boolean), `plan` (whole number) and `compare` (array of whole numbers) on the plan route only; a malformed key, `alternates` with `stats` or `advise`, `plan` with `compare`, or either without `alternates` is the existing input refusal. `HandlePlan` adds the classic page's custom resource to the gate when `alternates` is true, through `Gate.WithClassicPages(..., "%CSP.UI.Portal.SQL.QButtons.ShowPlanAlt")` as the Design Notes record 3 says, then passes the keys on to `SqlPort.Plan`. The console's order holds: the screen gate, the body's bounds, then `Check`, then the port.
2. **`Screen/Tool/ExplorerSqlAlternatePlansRead.cls`** (new, `explorer.sqlalternateplans.read`), extending `ExplorerSqlRead` as `ExplorerSqlAdviceRead` does: arguments `statement` and an optional whole-number `plan`, NO `compare` argument and no values; it calls `SqlPort.Plan(..., pAlternates 1)` (with `pPlanId` when `plan` is sent); a kind other than a query is refused as its parent does; `PrivilegePairs` unions `Gate.WithClassicPages(..., "%CSP.UI.Portal.SQL.QButtons.ShowPlanAlt")` and declares no `CLASSICPAGES`. The description (model-facing, decided in-stage): "List the plans the optimizer considered for one SQL query, with their cost, map type and starting map, or show one of them by its plan number. This lists and shows plans and runs nothing." Plan text and rows reaching the model go through AD-60's sanitizer as the sibling's do; the answer is the same rows the screen route answers (AD-36).
3. **`Kernel/Agent/Workflow.cls` `slowquery`:** a step after 21.27's, naming `explorer.sqlalternateplans.read` and no write, with this text verbatim: "Read the alternate plans for the slowest query and, when another plan costs less than the one the optimizer chose, suggest the person compare the two from SQL query; a comparison runs the query once for each plan without its values."
4. **Rosters,** each updated in this handoff with names and counts read from the instance (never recalled), one class per run, and each proven load-bearing as the rules say: `ConfirmNamespaceRoster`, `CompositeMintSweep`, `MappingDescriptor` (CLASSICROSTER only if a tool declares CLASSICPAGES: confirm it does not), `ClassicPageGate`, `SurfaceCoverage`, `ToolWrite`, `ReadTool`, `DraftRegistry`, `ToolEmit`, `ToolRoundTrip`, `StageTwoTools`, `RemovalRowsSweep`, `EndpointCoverage` (the route is unchanged: confirm), `ToolDispatch`, `GovernanceBaseline` (confirm no new key), `Navigation`, `Descriptor`, `Prohibited`, `ClaimReach`, `ReadDescriptions`, `WorkflowCatalog`, `SqlConsoleRoutes`, `SqlPortLive`, `SqlAgentRead`, `SqlAdviceRead` and `SqlRuntimeStatsRead`, plus every `ui/tools` test and `ui/src` spec that pins one of these surfaces (grep `ui/browser`, `ui/tools`, `ui/src` and `src/OcuPilot/Test` for the tool name's neighbours, e.g. `explorer.sqlquery.advise`/`sqladvice`, and run each one found). A class that needs no change is named under Verification as confirmed.
5. **Caller legs in `Test/SqlAlternatePlansRead.cls`** (or `SqlAlternatePlansRoutes` if it passes 500 lines): the route and the agent read answer the same rows (the list, and one plan) for the probe, nothing run; the agent read has no compare; a non-query agent read is refused as its parent does; `Check` refuses `OcuPilot_Kernel_State.Turn` (`PROHIBITED.OCUPILOTSQL`) and an unprepared statement answers the `error` outcome, each before any vendor call (the seam counts); the gate: a principal missing the SQL query screen's pairs is 403 naming the pair, and a custom resource on the classic page (through `ClassicResource`'s override) refuses the route's alternates actions and the agent read while `stats`/`advise` posts stay as 21.26/21.27 left them; the route posts a compare through `SqlConsole` and answers `compared` with one row per id, rows removed and read back absent.
6. **Measure (k), record one Verification line:** after a compare's client gives up (a `curl --max-time` shorter than the compare, against the throwaway's route with `_SYSTEM`/`SYS`), does the server job finish, and is the compare's statistics still readable afterwards (the runtime-statistics rows by routine the compare recorded, `%SYS_PTools.StatsSQL`, i.e. what the Runtime statistics screen reads)? This fixes the compare note's ending (round-2 ruling: "the result is lost if it does" holds only if nothing can be read back). Remove everything the run recorded and read it back absent.

Record each measurement as a short Verification line.

**HANDOFF 3 (Batch 2), the client: the "Batch 2, client" bullets below, read through these rulings. The server is finished: do not edit `src/OcuPilot` except what a generator rewrites (`Titles.cls`, only through its tool).**

- The route's bodies are `{alternates: true}` (list), `{alternates: true, plan: id}` (Show plan) and `{alternates: true, compare: [ids]}` (Compare plans, no values, one to five checked rows; the button is disabled outside that, and the page never posts a compare the server would refuse by count). Answers: `plans` (Possible plans table: a checkbox, the Plan, Cost, Map type and Starting map columns, a Show plan action per row; the hint under the table), `plan` (the text in the plan pane, the existing pane), `compared` (Compared plans, seven columns, the compare note on every compared result and on no other) and `stopped`/`error`/refusals as the store already shows them for Plan with statistics. A refusal shows the server's own sentence, as the siblings do. Truncated plans show the ruled sentence "Only the first 100 possible plans are listed." from a named constant with an AD-36 boundary test (the sibling pattern is `explorerSqlDataTreeCut`). The empty-state string 6 is not shipped.
- **The ruled strings, verbatim, add-only in `core/strings.ts`** (reuse `explorerSqlPlanHeading`, `processDetailsGlobalReferences`, `processColumnCommands`, `explorerSqlColumnTotalTime`, `explorerSqlColumnRows`): "Alternate plans" (the action), "Possible plans", "Compared plans", "Cost", "Map type", "Starting map", "Show plan", "Compare plans", "Check up to five plans to compare." and the compare note: "Compare plans runs the statement once for each plan, without its values, so a filtered query can show zero rows. Comparing can take longer than the page waits; what each run recorded stays on Runtime statistics." (the ending is the round-2 measure-first result, Verification (k): the answer is lost with the connection but the run's statistics stay readable on Runtime statistics; decided in-stage, reported). "Runtime statistics" is the screen's existing name: reuse its string.
- `EXPERIENCE.md`: ONE add-only Fixed strings row for 21.28 listing exactly these strings and the 21.28 refusals' reasons are server-side and need no row beyond what the siblings' rows do; then `cd ui && npm run test:tools`. Then regenerate the mirror and `Titles.cls` only if the generator reads the new strings (`node tools/screen-mirror.mjs`).
- The page reads the compare-note from one place (the store or the strings) and the page spec asserts it beside every compared result and beside no other (mutation: the store drops the note).
- New `ui/browser/system-explorer-sql-alternate-plans.browser-spec.mjs` (refuses the live container, waits on each answered signal as the sibling spec `system-explorer-sql-runtime-stats.browser-spec.mjs` does, probe from `SqlTuningProbe.MakeAlternates`/`RemoveAlternates` through whatever route the sibling uses to make its probe): Alternate plans lists the probe's plans; Show plan shows one; Compare plans with two checked rows shows two compared rows and the note. Its `after` hook removes the probe and everything the run recorded (statistics rows, statement-index rows, cached queries) and the test reads each back absent.
- **REVIEW PATCHES (Handoff 4, the only work left; Batches 1 and 2 are committed; server and tests only, no `ui/` edit):**
  - P1: `SqlPort.PlansVendor` hand-rolls what `Kernel/Utils.CallWithNullDevice` does. Route it through that helper (Rule 2/31): the vendor call becomes its own class method answering `{rows, code, message}` as a `%DynamicObject`, the helper wraps it in the null device and the namespace, and the `TRollback` to the starting `$TLevel` and the `Kill %AltPlan` stay on every path. Add a test in `SqlAlternatePlansRead` that calls it through the fixture for a success and for an SQLCODE error and asserts `$IO` with its mnemonic space, `$NAMESPACE`, `$TLevel`, `DeviceIsOpen` of the null device and `%AltPlan` as before the call.
  - P2: `AlternateState`'s cached-query and statement-index pieces are never asserted above 0 after a compare, so the `0|0|0|0` read-back cannot fail for them. Assert pieces 2 and 4 are above 0 after a compare in `SqlAlternatePlansRead`, `SqlAlternatePlansRoutes` and the browser spec's compare test (measure first; if a piece reads 0 after a real compare, fix the count's key, not the assertion).
  - P3: the compared row's `Cost` and `StartingMap` come from the list and the tests compare them with the list. Replace those two assertions with one that reads the vendor's own statistics row for each compared id through the fixture (the compare's own text, the same call `Compared` makes) and asserts its cost (numeric equality) and starting map equal the list's for that id.
  - P4: record observed `mutation:` lines under Verification (revert each by Edit, confirm the tree byte-identical, reload): AC1, `Alternates` drops `MapType` from a plan row; AC2, `Explained` drops the `alt`/`ids` qualifiers (the shown plan holds more than one plan); AC4, `RemoveAlternates` skips the cached-query purge (the `0|0|0|0` read goes red); P3, `Compared` runs the id plus one (the cost assertion goes red).
- Verify in the order of the spec's `(loop)` lines: `npm run build`, `npm run test:components`, `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then the two browser specs together forward, one file per call, and in reverse order, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`. Grep `ui/browser`, `ui/tools`, `ui/src` and `src/OcuPilot/Test` for every key or code you change in place and run each consumer found. Write the AC4 and AC2-client `mutation:` lines (the page drops Compare plans' post; the store drops the note), applying each after a rebuild and redeploy.

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

- 2026-11-26, orchestrator rulings on the Task 0 intent gap (veto U-178, U-166 addendum), authoritative over the plan-gate rulings where they differ:
  1. **Bound.** Before anything reaches the vendor, listing, showing and comparing refuse a statement over a measured bound, tables and conditions as named constants, derived from Task 0 with the 1.5x rule (worst case x1.5 under 60 s for list and show, and for a five-plan compare), tested at the boundary. Refusal: "Alternate plans take a statement with at most %1 tables and %2 conditions." **Parallel:** every compare run uses the vendor's no-parallel form (`%NOPARALLEL` in the FROM clause or the documented equivalent, read from `irislib/` or the docs); measured on `ocupilot-ci` that a parallel-capable statement then starts no workers (job count before, during, after). If no such form holds, HALT and report (compare would refuse statements whose listed plan is parallel, with one more string, ruled first).
  2. **Privilege.** The checked form (U-174): a -99 on the `%SYS_PTools` procedures answers 403 "Reading this needs the SQL EXECUTE privilege on %1." (`%1` = the procedure, from the port's own fixed call). Measured -99 and success after the grant go in the security note; the armed class `SqlSelectPrivilege` covers it if cheap. `%ResultSet` unchecked is rejected.
  3. **Ids.** Compare runs the listing's own parameterized text (literals replaced by `?`) without values, so a listed id always names the plan it ran; measured on the skewed-column case that ids and costs match between list and compare. The compare note stays "Compare plans runs the statement once for each plan, without its values, so a filtered query can show zero rows."; string 11 follows it.
  4. Plain id text (not `$ListBuild`) for showing one plan: decided.
  5. Side effects: a compare adds runtime-statistics rows, one statement-index row and one cached query (measured); the AD-7 21.28 line names all three.
  6. The empty-state sentence ships only if a test shows CALL or SET OPTION can reach the list; otherwise it is omitted.
  7. DW-2874: evidence recorded; no change here.

- 2026-11-26, runner decisions at the re-dispatch, from the Task 0 addendum under Verification (small, inside the rulings above; authoritative over the Batch bullets where they differ):
  1. **Constants.** `ALTMAXTABLES` 4 and `ALTMAXCONDITIONS` 4 on `SqlPort`, counted by a pure scanner class (its own test class pins the boundary at 4 and 5 for each count, and the view-expansion case: a view whose own text repeats one table is refused). The refusal is the ruled sentence with the two constants as `%1` and `%2`, a 422 with a new `AtelierError` code (add-only), answered before anything reaches the vendor, from the screen route and the agent read alike.
  2. **Compare text.** The compare runs the statement's own parameterized text, taken from `$SYSTEM.SQL.Explain` with `silent` as the addendum describes, with `%NOPARALLEL` after each FROM token. If the instance does not prepare that text, the answer is the console's `error` outcome with the instance's SQLCODE and message (no new sentence). The id pre-check lists the caller's statement through `possiblePlans`, as for show.
  3. **One run at a time.** The compare calls `possiblePlansStats` once per chosen id (the port closes each result set and kills `%AltPlan` first), each under an alarm of the seconds left of `BoundSeconds`, and answers `stopped` as soon as the alarm fired in a run or the seconds are spent, with no partial rows. Task 0 (j), measured before any code and recorded under Verification: a single-id compare under a short alarm on a long-running statement, whether the instance aborts that run, what it answers, and how the port reads the alarm. If a single-id run is not stopped by the alarm, HALT `blocked` as an intent gap.
  4. **Show one plan** uses `Explain` with the plain id text (ruling 4) after the list; the list is `possiblePlans` on the caller's text.
  5. **Empty state.** `Plan` answers `noplan` for CALL and SET OPTION before the list is reached, and every query or DML statement measured answered at least one plan: string 6 is not shipped.
  6. **Privilege.** `possiblePlans` and `possiblePlansStats` are prepared as checked class queries (`%PrepareClassQuery`); a -99 is the 403 EXECUTE refusal of ruling 2.

- 2026-11-26, orchestrator ruling on the compare time limit (round 2; veto U-166/U-178, no new inbox item per the orchestrator), authoritative:
  - Compare stays a person's action on SQL query, in its request under the named gateway limit (21.27 Gather precedent); "stopped" is an after-the-fact answer only, as measured.
  - `%NOPARALLEL` is inserted SQL-aware, through the console's own tokenizer or parser, never a text replace; tests: FROM inside SUBSTRING, TRIM and EXTRACT, a subquery FROM, and a quoted identifier named from; 0 workers busy after a compare is recorded.
  - The 4-table/4-condition bound applies to Compare too.
  - Compare also refuses a statement whose counted conditions are fewer than its tables minus one (a cross product): "Compare plans takes a statement that joins each table by a condition.", tested at the boundary. If the scanner cannot count it reliably, HALT and report instead of building it.
  - Compare note: "Compare plans runs the statement once for each plan, without its values, so a filtered query can show zero rows. Comparing can take longer than the page waits; the result is lost if it does." Measure-first on the ending: if a finished compare's result can be read back afterwards, say that instead.
  - List, show and the scanner land as measured (4 tables, 4 conditions; list worst 27.6 s, show 14.7 s).

## Review Triage Log

### 2026-11-26 — Review pass

- verdicts: 15 findings — high 0, medium 2, low 5, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` `PlansVendor` copies `Kernel/Utils.CallWithNullDevice` and its device, namespace, transaction and `%AltPlan` restore is asserted nowhere — now routed through the helper (`PlansCall`), with a test for `$IO`, namespace, `$TLevel`, the null device and `%AltPlan`.
  - `[medium]` `[patch]` `AlternateState`'s cached-query and statement-index pieces are never asserted above 0 after a compare, so the `0|0|0|0` read-back cannot fail for them — pieces 2 to 4 are asserted above 0 after a compare in both test classes and the browser spec.
  - `[low]` `[patch]` Compared-row `Cost` and `StartingMap` tests compare a value with its own source — replaced by the vendor's own statistics row for the id, cost by numeric equality.
  - `[low]` `[patch]` Mutation lines missing for AC1 columns, AC2 text-alone and AC4 clean-up — recorded under Verification; the cached-query purge is not load-bearing (`DROP TABLE` removes the table's cached queries) and the statement-index clean-up is.
  - `[low]` `[reject]` Cross-product guard is a count, not a join test — the round-2 ruling states the rule as the count and tests it at the boundary; a filter-only multi-table statement passes (residual risk under Auto Run Result).
  - `[false]` `[reject]` Spec text (AC2, Code Map, Auto Run Result) is inconsistent with the rulings — the fix edits the spec, which the rulings govern; the Auto Run Result is rewritten at finalize.
  - `[low]` `[reject]` Browser spec test titles say AC4 for the compare test — cosmetic; the sibling spec labels its tests the same way.
  - `[false]` `[reject]` Compare runs a rewritten statement, not the whole text — ruled (2026-11-26 rulings 3 and runner decision 2): the statement's own parameterized text, so a listed id names the plan it ran.
  - `[false]` `[reject]` Compare calls the statistics query once per id, never a comma-joined list — ruled (runner decision 3); the port still builds the id text.
  - `[false]` `[reject]` The gate adds the classic page's custom resource — ruled (plan-gate ruling 3, veto U-166).
  - `[false]` `[reject]` The bound check reads view text from the dictionary before refusing — it runs after the checked prepare, as the console's order requires, and before anything reaches the plan queries.
  - `[false]` `[reject]` The bound, the cross-product refusal and the EXECUTE refusal go beyond the intent — each is a ruled addition (2026-11-26 rulings 1, 2 and the round-2 ruling).
  - `[low]` `[reject]` The new test classes call themselves "Live-safe" and are not armed — the same pattern as `SqlRuntimeStatsRead`; they remove every row they cause, and no stage runs them off the throwaway.
  - `[false]` `[reject]` A compare answers `stopped` only after the fact — ruled (round-2 compare ruling).
  - `[false]` `[reject]` No explicit sanitizer call is visible — the agent read inherits `ExplorerSqlRead`, and every tool result passes AD-60's sanitizer.

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

### Task 0 measurements

Measured 2026-11-26 on `ocupilot-ci` (IRIS 2026.2 build 221U), `USER` (the throwaway's `HSCUSTOM` holds no probe), by scratch classes that are deleted. Every line is observed unless marked (inference). Read back absent afterwards: the probe tables and schema, their cached queries and statement-index rows (`$SYSTEM.SQL.Statement.Clean()`), 250 runtime-statistics rows (by routine), the principal, its role, its grants and the custom resource, and each custom page resource set for DW-2874.

- **Probe.** `OcuProbe228.T` (A, B, C, D; indexes on B and C; 3,000 rows; tuned) answers 5 plans for `B = 5 AND C = 'c5'`: ids 1-2 `Multi Index` (cost 1303.2, 2123.8; starting map `OcuProbe228.T`), ids 3-5 `master map ` (starting map `OcuProbe228.T.IDKEY`). The list's `Cost` prints one decimal (`20200.0`); the plan text prints `Cost: 20200`.
- **(a) Privilege.** Principal `%Development:USE`, `%DB_USER`, `%DB_ENSLIB` and `%DB_IRISLIB` READ, no WRITE pair, no `%DB_IRISSYS`.
  - Without SELECT, `%Prepare(text, 1)` answers SQLCODE -99 before any vendor call.
  - **`%SQL.Statement.%PrepareClassQuery` is refused -99 for this principal even with SELECT**, until SQL EXECUTE is granted on `%SYS_PTools.PT_possiblePlans` and `PT_possiblePlansStats`. Granted, list (5) and compare (2) answer. The classic page's form, `%ResultSet.%New("%SYS.PTools.StatsSQL:possiblePlans")` then `Execute`, needs no EXECUTE grant.
  - With SELECT and the `%ResultSet` form the principal lists (5), shows (`Explain` with `alt` and `ids`, 452 characters) and compares (ids 1 and 2: 15 rows each, statistics present). Compare recorded 5 runtime-statistics rows for it with no WRITE pair, and no `<PROTECT>` occurred. No pair beyond `%Development:USE` and the namespace's READ pairs is needed.
  - Without SELECT the `%ResultSet` class queries do not refuse: the list answers its 5 plans, and the compare answers rows with blank statistics. They check no table privilege, so the checked prepare must stay first.
- **(b) Durations and the bound.**
  - List, five tables (200 rows each, two indexes each), predicates in the order the probe added them: 4 predicates 2.0 s (56 plans); 5 predicates 12.4 s (302); 6 predicates 16.3-16.8 s (326); 7 predicates 17.1 s (233); 8 predicates 51.6 s (393); 9 and 10 predicates (all pairs) still running at 100 s and killed. Four tables, all six pairs: 34.8 s (397 plans). A plain `Explain` or prepare of the 10-predicate statement: 0.1 s.
  - Show one plan (`Explain` with `ids`), 6-predicate join: 8.7 s, because every plan is still generated.
  - Compare of five plans, five-table join: ids 1-5 23.9 s, ids 52-56 20.2 s (each run 1.5-3.1 s); the probe table 0.1 s.
  - **`$System.Alarm` does not stop plan generation:** alarms of 1, 4 and 8 s on the 326-plan list returned at 16.4, 17.1 and 16.9 s with 325 plans (one fewer), no `<ALARM>` reached the caller; a 5 s alarm on the 10-predicate list did not stop it by 100 s.
  - **It does not stop a compare:** a 5 s alarm on the five-plan compare returned at 20.3 s (24 s without): the vendor trapped it, ended only the plan run in progress and ran the other four. A parallel-capable statement (a three-way self-join of the probe, 3 s alarm) returned at 20.1 and 23.2 s and left 14-16 `startWork^%SYS.WorkQueueMgr` worker jobs at about 100% CPU after the request; I killed them. The same statement with no alarm ran past 100 s.
  - **A stopped compare answers** SQLCODE 0 and no error status, with every row present and the aborted plan's `GlobalRef`, `Commands`, `TotalTime` and `RowsReturned` blank (the fetch's undefined locals read as `""`, never `<UNDEFINED>`). The statistics are the vendor's strings: `commands` `1,368`, `rows` `400,000`, `time` `0.000049`.
  - Listing's worst case times 1.5 reaches the 60 s limit (8 predicates, 51.6 s x 1.5 = 77 s) and the alarm does not stop it: **the rule in (b) applies and the stage stops (record 1).**
- **(c) One plan's text.**
  - `"ids": $ListBuild(id)` is refused: SQLCODE -481a, "does not support the following SQL statement type: SELECT". `"ids": "2"` (plain text, a whole number) answers that plan only (692 characters, `Cost: 2123.8`), and `"1,3"` answers two. An id that is not listed, `0` and `1;DROP` answer the same -481a. The deprecated `ShowPlanAlt(.sql, 1, 0, "", "", 1, id, 1)` also takes the plain id and leaves `%AltPlan`. Form used: `Explain` with the plain id text.
  - The list and `Explain` both literal-replace the statement (the plan's SQL line shows `?`). `possiblePlansStats` does not (preparse 0), so for a statement with a literal the ids can name different plans. On the probe, and for every `?` statement tried, id, cost and starting map agree. With `X = 'common'` on a skewed column the list's id 1 is cost 23213.6 `Multi Index` and the compare's id 1 is cost 26600.0 `master map` on `IDKEY`; with `X = 'rare40'` the compare answers 4 plans with costs 2365.7, 3175.0, 26600.0, 27409.0 against the list's six, ids 3 and 4 blank.
- **(d) The probe.** Plan 1 equals the `Explain` plan from the `Cost:` line on (the `/*#OPTIONS*/` comment on the SQL line is the only difference) for seven statements: two indexed conditions, one, `COUNT(*)`, `ORDER BY`, an `UPDATE`, a `DELETE` and a three-table join.
- **(e) Values.** With preparse 0 a literal runs as written: `B = 5 AND C = 'c5'` compare rows 15 (a direct `COUNT` reads 15). An unbound `?` runs as nothing: rows 0, global references 0-1. A statement holding a literal therefore does not show zero rows.
- **(f) Side effects.**
  - Listing and showing change no runtime-statistics row, statement-index row or cached query (78, 655 and 288 before and after), no global name, and leave `$TLevel` 0.
  - Comparing three plans of a new statement text adds 8 runtime-statistics rows, 1 statement-index row and 1 cached query; nothing else (no other global name; `$TLevel` 0).
  - `%AltPlan` is cleared when the result set closes. While a list's result set is open, the next `possiblePlansStats` still sees its entries: ids `1,2` answered 5 rows. The port closes each result set and kills `%AltPlan` before the next call.
- **(g) Device output.** For a statement with an SQL error both class queries write about 4.5 KB of HTML (4,531 and 4,488 bytes) to the current device and answer SQLCODE 0 with 0 rows; for a good statement 0 bytes. The null device swallowed it (nothing reached the terminal). `Explain` with `silent` writes 0 bytes in every case.
- **(h) DML.** Listing an `UPDATE` (4 plans), a `DELETE` (6), an `INSERT ... VALUES` (1) and an `INSERT ... SELECT` (5) changed no row (3,000 before and after, no `D = 'zz'` row) and no statistics, statement-index or cached-query row.
- **(i) Unknown ids.** `possiblePlansStats` answers no row and no error for an id it does not list (`9` gives 0 rows, `1,9` gives 1, `1,1` gives 1, a leading comma is accepted). An empty `ids` runs every plan (5 rows). The port's pre-check and its refusal of an empty list are required.
- **Empty list.** Eleven preparable statements of kind query or DML (including `SELECT 1` and `WHERE 1=0`) each answered at least one plan. A `CALL` and a `SET OPTION` answered none. String 6 is reachable only if those kinds reach the list.
- **Caller locals.** The vendor routines clobber an unprotected caller's local variables when called from a terminal session (a `For` loop stopped after one pass); every probe call ran inside a class method.
- **DW-2874: the classic pages' custom resource on 21.26's and 21.27's console actions.** A custom resource was assigned to `RuntimeStats`, `RuntimeStatsSettings`, `IndexAnalyzer` and `ShowPlanAlt`; a principal with `%Development:USE` that did not hold it was refused 403 on `GET /screens/explorer.sqlruntimestats/read` and `explorer.sqlindexanalysis/read` (failed pair `OcuP228Custom:USE`), and the purge, gather, run, purge-analysis and settings tools' `PrivilegePairs` gained that pair. `POST /explorer/sql/plan` with `stats: true` still answered 200 and with `advise: true` passed the gate (it then answered the SELECT refusal on `%Dictionary.CompiledClass`); `ExplorerSqlAdviceRead` and `ExplorerSqlRead` listed `%Development:USE` alone. Plan with statistics and Advise therefore do not honour their classic pages' resource; the lists and the writes do. No change to either story.

### Task 0 addendum (re-dispatch 2026-11-26)

Measured on `ocupilot-ci`, `USER`, by scratch classes and tables that are removed and read back absent (schema, views, cached queries, 314 runtime-statistics rows by routine, workers the probe grew). Observed unless marked (inference).

- **Bound derivation.** About 1,100 list calls, each in its own process under a 100 s kill, over chain, star, ring, dense, both-column, indexed-filter, OR, comma, JOIN and self-join shapes on tables of 3 to 12 indexes (200 rows each). Slowest list within T tables and C conditions (seconds, plans):

  | T \ C | 3 | 4 | 5 | 6 | 7 | 8 |
  | --- | --- | --- | --- | --- | --- | --- |
  | 2 | 4.5 | 9.9 | 12.9 | 26.3 | 26.6 | 55.1 |
  | 3 | 9.9 | 22.6 | 42.3 | 45.7 | 45.7 | 80.7 |
  | 4 | 13.7 | **27.6 (407)** | 52.2 | 70.6 | 71.7 | 80.7 |
  | 5 | 16.7 | 45.4 | 59.3 | 70.6 | 71.7 | 80.7 |

  A single table was 0.1 to 0.2 s with 12 conditions. Chosen bound: **at most 4 tables and 4 conditions** (27.6 s x 1.5 = 41 s). Show one plan on the worst statement: 14.1 to 14.7 s. The search was adversarial but not exhaustive (no tables above 12 indexes, no composite or bitmap indexes, no production-size statistics).
- **Compare is not bounded by the counts.** It runs the statement per plan, so its time follows the data: a 4-table, 4-condition join answered in 45.5 s on one fixture, and a three-table cross join with no condition was still running at 100 s. A five-plan compare of the worst 4/4 statement on small tables: 14.8 to 22.9 s.
- **Counting.** The statement index counts aliases of one table once (a four-alias self-join: 1 relation) and lists a view with its base tables, not how often the view's own text repeats one (`VS`, a view of four aliases of one table: 2 relations, list 53.6 s). `&` is AND and `!` is OR (a statement with `&` only listed 446 plans in 42.6 s). The rule below was run over 1,094 generated statements with known counts: 1,091 equal, 0 over, 3 under (generator shortfalls).
  - Tokenize the statement and drop comments, string literals and delimited identifiers.
  - TABLES = FROM keywords + commas at the same depth up to the next clause keyword + JOIN keywords + one per UPDATE or INSERT INTO target.
  - CONDITIONS = WHERE, ON, AND, OR, `&`, `!`, HAVING + one per column of each USING.
  - A view relation adds the same two counts over its `%Dictionary.CompiledClass.ViewQuery`. Tables is the larger of that sum and the relation count.
  - `BETWEEN ... AND` and a derived table overcount by one, which is safe.
  - (inference) a query or DML statement the statement index does not hold is already refused 422 by `Classify` before the count, so no unindexed text reaches it.
- **The compare's own text.** `ShowPlanAlt^%apiSQL` is called with preparse 1 by the list and preparse 0 by the compare. With a literal, the compare's ids name other plans than the list's (skewed column: list id 1 cost 16702.0 `IxX`; compare of the literal text id 1 cost 18600.0 `IDKEY`). Taking the text from `$SYSTEM.SQL.Explain(.text, {"silent":1})` (the lines after `SQL:` up to the blank line, `/*#OPTIONS ... */` removed, lines joined by one space; 0.01 to 0.02 s even where the list takes 22 s) and comparing that text gives the list's ids, costs and starting maps for `'common'`, `'rare40'`, `'it''s'`, non-ASCII, 40 literals and `TOP ?`; its `?` run as nothing (rows 0).
- **No-parallel form.** The documented form is the keyword `%NOPARALLEL` as the first token after FROM; one covers every table of that FROM clause, and it is a syntax error elsewhere. There is no per-process or per-statement option (`AutoParallel` is instance configuration, `possiblePlansStats` takes `(sql, ids)` only). A three-way self-join of the 3,000-row probe, compare of ids 1 to 5: 16 `startWork^%SYS.WorkQueueMgr` workers busy at 68 to 98% CPU (a pool of 2 grew to 20 idle workers afterwards) and 2.2 s; with `%NOPARALLEL` after each FROM: 2 workers present all through (the baseline), 0 busy, 52.3 s. A two-way self-join: 0 busy with and without. List signatures (ids, costs, starting maps) are identical with and without the keyword for a 3-way join, a skewed column, a subquery, a derived table, a view and a UNION. The keyword breaks `DELETE FROM` (-1) and a FROM inside `SUBSTRING`, `TRIM` or `EXTRACT` (-12, -28). The plan text says `Call Module-A in parallel on each subrange` for 50 of 50 plans without the keyword and 0 of 50 with it.

### Task 0 (j): one id under the alarm (re-dispatch 2026-11-26)

Measured on `ocupilot-ci`, `USER`, by scratch classes that are deleted. The statement is a three-way self-join of the 3,000-row probe with `%NOPARALLEL` after FROM (50 plans, listing 0.9 s), compared with `possiblePlansStats` and one id, the alarm set before the call and cleared after. Every line is observed unless marked (inference). Read back absent afterwards: the probe tables and schema, the 100 runtime-statistics rows the runs recorded (by routine), the scratch classes and their files in the container, and `$TLevel` stayed 0 throughout.

- **Total time follows the alarm plus a whole run.** Alarm 3, 6, 10, 20 s: 29.6-30.1, 32.7, 36.7 and 46.8 s, each answering every statistic complete (`TimeSpent` 26.1-26.7 s). Alarm 60 s, which never fires: 52.7 s with the same `TimeSpent`. So the instance executes the statement twice (inference: 2 x 26 s), and an alarm that fires in the first execution ends it, is swallowed, and the second runs to the end.
- **An alarm in the second execution stops it:** alarm 40 s returned at 40.0 s with SQLCODE 0, no `<ALARM>` reaching the caller and every statistic blank.
- **`$SYSTEM.SQL.Explain` with `alt`, `ids` and `stats` behaves the same:** 52.5 s with alarm 60, 29.7 s with alarm 3 and 36.9 s with alarm 10, the plan carrying no stopped marker.
- Consequence: a single-id run whose own time exceeds the bound (50 s here, `BoundSeconds`) ends after the bound plus the whole run, and the alarm reports nothing, so the port cannot answer `stopped` in time.
- **Rule 3 of the 2026-11-26 runner decisions applies: a single-id run is not stopped by the alarm.**

### Handoff 1 (server core), measured on `ocupilot-ci`

- **Workers.** A compare of ids 1 to 3 of the three-way self-join of the 3,000-row probe through `SqlPort.Plan` took 10.9 s and answered numbers for each id; `startWork^%SYS.WorkQueueMgr` processes before, during (sampled every 0.2 s) and after: 53, 53, 53, none above 50% CPU. The same statement's own text without the keyword, through the vendor query for ids 1 to 5, answered no row for ids 1 and 2 and blank statistics for ids 3 to 5 in 0.7 s and also started no worker here, so this probe does not show the keyword's effect; the Task 0 addendum's 16 busy workers without it and 0 with it stand.
- **View text.** `%Dictionary.CompiledClass` compares `SqlSchemaName` and `SqlTableName` case-sensitively (`'OCUPROBE228'` found nothing, `UPPER()` found the view), and the statement index names relations in upper case, so `ALTVIEWQUERY` compares `UPPER()` of both.
- **EXECUTE.** `SqlSelectPrivilege`'s new leg, as a real principal holding SELECT on the five tables: with no EXECUTE, list and compare answer 403 `SQL.EXECUTE.PRIVILEGE` naming `%SYS_PTools.PT_possiblePlans`; granted on it alone, the list answers one plan and the compare answers 403 naming `%SYS_PTools.PT_possiblePlansStats`, nothing run. The status of `%PrepareClassQuery` maps to SQLCODE -99 as Task 0 (a) measured.
- **Read back absent.** `AlternateState` reads `0|0|0|0` (tables, cached queries, statistics rows, statement index rows) after every `SqlAlternatePlansRead` test, a compare included; the scratch classes and probe tables of these measurements are removed.
- `mutation: ALTMAXPLANS 101 -> the 101 leg of TestTheListAndACompareAreCappedAtTheirBoundaries red; Alternates without the query-only check -> the UPDATE leg of TestEveryCompareRefusalCallsNothing red; without the unlisted-plan check -> the unlisted leg red (reverted by Edit, files compared equal to the saved copy, reloaded); Walk without the function-FROM test -> TestNoParallelFollowsEachFromClauseAndNothingElse and the count leg red (same).`

### Handoff 2 (callers and rosters), measured on `ocupilot-ci`

- **Built.** `SqlConsole` takes `alternates`, `plan` and `compare` on the plan route and gates alternates on the classic page's custom resource after the screen gate and the body's shape; `ExplorerSqlAlternatePlansRead` (`statement` and `plan` only); the `slowquery` step, verbatim; `SqlAlternatePlansRoutes` holds the caller legs (6 tests, `SqlAlternatePlansRead` stays at 10); `SqlAlternateTool` is its counting seam.
- **Rosters changed, each red before its row was added and green after:** `ReadTool` (645, name list), `ToolEmit` (a branch for the tool's pairs), `ToolRoundTrip` (`TOOL.ARGUMENTS`), `DeveloperFloor` (112), `ExplorerDescriptor` (43 reads, the screen's tool list), `PortGate` (`SqlAlternateScan` as a table row), `WorkflowCatalog` (a leg for the step), `SqlConsoleRoutes` (the no-`%Development:USE` alternates leg), `ClassicPageGate` (`TestAnAssignedPageGatesAlternatePlans`, route and agent legs).
- **Confirmed unchanged, green:** `SurfaceCoverage`, `DraftRegistry`, `StageTwoTools`, `ReadDescriptions`, `ToolWrite`, `ConfirmNamespaceRoster`, `CompositeMintSweep`, `MappingDescriptor` (no `CLASSICPAGES`), `RemovalRowsSweep`, `EndpointCoverage` (the route is unchanged), `ToolDispatch`, `GovernanceBaseline` (no new key), `Navigation`, `Descriptor`, `Prohibited`, `ClaimReach`, `SqlPortLive`, `SqlAgentRead`, `SqlAdviceRead`, `SqlRuntimeStatsRead`, `SqlPort`, `SqlConsoleWrite`, `SqlBackgroundRoutes`, `SqlIndexAnalysisRead`, `SqlSelectPrivilege`; `screen-mirror.test`, `suggested-prompts.test`, `self-protection.test`, `ci.test` and `ci-shards.test` green, `screen-mirror --check` up to date.
- **(k) A compare whose client gives up.** A three-way self-join of the 3,000-row probe, compare of plans 1 to 3 through the route: 43.5 s to 45.0 s and 15 runtime-statistics rows recorded. With `curl --max-time 5` (exit 28, no answer): the rows read 23 before it, 23 at +8 s, 33 at +31 s, then 38 from +63 s to +127 s, which is the 15 a finished compare records (a second uninterrupted compare then added 15 more). The server job finished all three plans after the client left, the statistics stayed readable in `%SYS_PTools.StatsSQL` (what Runtime statistics reads), and the answer itself was lost with the connection. Everything the run recorded was removed and `AlternateState` read `0|0|0|0`.
- `mutation: View calls Plan without alternates -> TestTheRouteAndTheAgentReadAnswerTheSamePlansAndNothingRuns red; View without its Mutating check -> TestTheAgentReadTakesNoCompareAndRefusesWhatIsNotAQuery red (the UPDATE leg and the nothing-reached leg); InputSchema declares compare -> the same test's compare leg and TestTheToolDeclaresItsShapeAndItsPairs red; HandlePlan passes alternates 0 -> the route's list, compare and plan legs red; Body accepts a plan with a compare -> the malformed-body leg red; GateAlternates skipped in Read and PrivilegePairs without the page -> TestAnAssignedPageGatesAlternatePlans red on its route and agent legs; the slowquery step reworded -> WorkflowCatalog red (each reverted by Edit, files compared equal to the saved copy where saved, reloaded, green).`

### Handoff 3 (client), measured on `ocupilot-ci`

- **Built.** SQL query's Alternate plans, Show plan and Compare plans (`sql-query.store.ts`, `.page.ts`, `core/sql-answer.ts`), the ten ruled strings add-only in `strings.ts`, one add-only EXPERIENCE.md Fixed strings row, `self-protection.test.mjs` pinning the 100 and the 5 to `SqlPort`'s `ALTMAXPLANS` and `ALTMAXCOMPARE`, and `browser/system-explorer-sql-alternate-plans.browser-spec.mjs`. Compare plans' note shows on `compared` results only (a `stopped` or `error` answer carries none). `screen-mirror --check` was up to date (the generator reads none of the new strings), so `Titles.cls` is unchanged. Forced edits: `taskCreate`'s citation `:682` to `:683` (the new row moved it), and `.ocu-sql-query-form .ocu-criteria-controls { flex-wrap: wrap }` in `_components.scss`, because the sixth button put Run 66 px past its column at 720 px in `system-explorer-sql-query.browser-spec.mjs`.
- **Loop.** `npm run build` clean (initial 2.33 MB). `test:components` 349 files, 4092 tests. `test:tools` 2421/2421. `check-objectscript` 0 problems, `lint-docs` clean. Browser after rebuild and redeploy: `system-explorer-sql-alternate-plans` 3/3 then `system-explorer-sql-runtime-stats` 4/4, and in reverse, each green; `system-explorer-sql-query` 3/3, `system-explorer-sql-index-analysis` 6/6 and `agent-sql` 2/2. The new spec's `after` read `AlternateState` back `0|0|0|0`.
- `mutation: the page drops Compare plans' post (onCompare without comparePlans) -> after rebuild and redeploy the browser spec's AC4 red (the compared-row wait timed out); the store drops the note (comparedAnswer answers false) -> sql-query.page.spec.ts "shows the ruled note beside every compared result and beside no other result" red, and after rebuild and redeploy the browser spec's AC4 red on the compare-note wait; MAX_COMPARED_PLANS 6 -> self-protection.test.mjs Story 21.28 test red (each reverted by Edit, rebuilt and redeployed, green).`

### Handoff 4 (review patches P1 to P4), measured on `ocupilot-ci`

- **Built.** P1: `PlansVendor` runs `PlansCall` (new, answers `{rows, code, message}`) through `CallWithNullDevice` with namespace `""`, and `PlansCall` switches to the caller's namespace itself, because `OcuPilot.Port.SqlPort` is not visible in every namespace the helper would switch to; it restores the namespace, kills `%AltPlan` and rolls back to its starting `$TLevel` on every path. Fixture gains `VendorRead` (a public pass-through, since `PlansVendor` is private). P2: `AlternateState` pieces 2, 3 and 4 are asserted above 0 after a compare in `SqlAlternatePlansRead`, `SqlAlternatePlansRoutes` and the browser spec's AC4 (all read above 0 on first measure; no key changed). P3: the cost and starting map are asserted against the vendor's own statistics row for the id each compare call named. New test `TestThePlansReadLeavesTheProcessAsItFoundIt` (success and SQLCODE -400 legs).
- **Run.** `SqlAlternatePlansRead` 11/11, `SqlAlternatePlansRoutes` 6/6, `SqlAlternateScan` 7/7, `SqlPortLive` 16/16, `SqlRuntimeStatsRead` 10/10, `SqlConsoleRoutes` 8/8, `SqlSelectPrivilege` 5/5, browser spec 3/3 after rebuild and redeploy, `check-objectscript` 0 problems.
- `mutation: Alternates drops MapType -> TestTheListAnswers... red (four columns, map type); Explained drops alt/ids -> TestShowPlanAnswersOnePlansText... red ("not the plan the statement would run"; the one-plan-text assertion stayed green because the chosen plan is also one plan); Compared runs id + 1 -> TestACompareRunsEach... red (the vendor-row cost and starting map, the call-id and the numbers legs) and the cap test's vendor-strings leg red; PlansCall without Kill %AltPlan -> TestThePlansReadLeaves... red on its error leg only (the success leg's query leaves none); RemoveAlternates without its two PurgeQueries -> the 0|0|0|0 read stayed GREEN (DROP TABLE removes the table's cached queries), and without Statement.Clean -> every test red on the 0|0|0|0 read (the statement-index piece), so the purge is not load-bearing and the Clean is (each reverted by Edit, files compared equal to the saved copies, reloaded, green).`

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** SQL query gains Alternate plans. The list, Show plan and Compare plans (one to five listed ids, one `possiblePlansStats` run per id) go through `SqlPort.Plan` and the plan route. `explorer.sqlalternateplans.read` lists and shows plans and runs nothing, and `slowquery` names it. A statement over four tables or four conditions is refused before anything reaches the vendor, a compare also refuses a statement whose counted conditions are fewer than its tables minus one, and a compare answers `stopped` only after the fact. Committed in two batches (server `a2fa037b7`, client `b270555be`) and the review patches in the finalize commit.

**Files.**

- Server: `Port/SqlAlternateScan.cls` (new, the counts and the token-aware `%NOPARALLEL`), `Port/SqlPort.cls`, `Api/AtelierError.cls`, `Area/Explorer/SqlConsole.cls`, `Screen/Tool/ExplorerSqlAlternatePlansRead.cls` (new), `Kernel/Agent/Workflow.cls`.
- Client: `sql-query.store.ts`, `sql-query.page.ts`, `core/sql-answer.ts`, `core/strings.ts`, EXPERIENCE.md, `_components.scss` (the form's controls wrap), `self-protection.test.mjs`, and the new `system-explorer-sql-alternate-plans.browser-spec.mjs`.
- Tests: `SqlAlternateScan`, `SqlAlternatePlansRead`, `SqlAlternatePlansRoutes` (new, with `SqlAlternateFixture` and `SqlAlternateTool`), `SqlTuningProbe`, `SqlSelectPrivilege`, and the rosters `ReadTool`, `DeveloperFloor`, `ExplorerDescriptor`, `PortGate`, `ToolEmit`, `ToolRoundTrip`, `WorkflowCatalog`, `SqlConsoleRoutes`, `ClassicPageGate`.

**Decided in-stage** (small, inside the rulings):

- The compare note's ending, from Verification (k): "Comparing can take longer than the page waits; what each run recorded stays on Runtime statistics." The answer is lost with the connection, but the run's statistics rows stay readable.
- The agent read's description: "List the plans the optimizer considered for one SQL query, with their cost, map type and starting map, or show one of them by its plan number. This lists and shows plans and runs nothing."
- The compare's elapsed seconds count from its first statistics run, after the list. The note shows on `compared` results only.
- `PlansCall` switches to the caller's namespace itself, because the switched region may call vendor classes only.

**Review.** 15 findings: 2 medium and 2 low patched (the null-device copy routed through the helper, the read-back made able to fail, the compare's own statistics row checked, the mutation lines recorded), 11 rejected with their reasons in the Review Triage Log. Nothing deferred.

**Verification.** Every class and spec the batches touched is green on `ocupilot-ci`, one per call: `SqlAlternateScan` 7, `SqlAlternatePlansRead` 11, `SqlAlternatePlansRoutes` 6, `SqlPortLive` 16, `SqlConsoleRoutes` 8, `SqlRuntimeStatsRead` 10, `SqlSelectPrivilege` 5, `SqlAdviceRead` 11, `SqlAgentRead` 7 and the roster classes. `npm run test:components` 4092, `npm run test:tools` 2421, `npm run build` clean (2.33 MB initial), `check-objectscript` and `lint-docs` clean, and the alternate-plans and runtime-statistics browser specs pass forward and in reverse. The full ObjectScript sweep and the full browser suite are the runner's and CI's.

**Residual risks.**

- The cross-product refusal counts conditions, so a filter-only multi-table statement such as `FROM a, b WHERE a.x = 1` passes it and its compare can run long (an unjoined three-way join passed 100 s). The page's wait is the only limit, and the rows are kept on Runtime statistics.
- The worker-control measurement in Handoff 1 was inconclusive on its own probe; the Task 0 addendum's 16 busy workers without `%NOPARALLEL` and 0 with it stand.
- `SqlAlternatePlansRoutes`, `SqlAlternateTool` and the new browser spec are not in `ui/tools/ci-timings.json`; the merge-time refresh adds them. `ReadTool`, `ToolRoundTrip`, `DeveloperFloor`, `ExplorerDescriptor`, `strings.ts` and EXPERIENCE.md carry count literals and rows Epic 24 also changes, so they need a union at the merge.
- The cached-query purge in `RemoveAlternates` is redundant after the table drop; the statement-index clean-up is what the read-back needs.

**Follow-up review recommended: true.** Two medium findings were patched on this first pass. The unverified risk is `PlansCall`'s restore of the device, namespace, transaction and `%AltPlan` on a raise, which the new test covers only for a success and an SQLCODE error.
