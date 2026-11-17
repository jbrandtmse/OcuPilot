---
title: "Story 21.32: A SQL settings change leaves the instance's class-query lists working"
type: 'bugfix'
created: '2026-11-16'
status: 'done'
baseline_revision: 'd6b5aa2750abe8c93745ded5e1ca597c2c4fc3ee'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Every `Config.SQL` activation advances the instance's SQL compile context version (`^%SYS("sql","sys","contextVersion","SQLCompile")`). A process whose context object (`$SYSTEM.Context.SQLCompile()`) predates that change discards it at its next SQL compile. When that compile is the vendor's `%PrepareClassQuery(...,2)`, the discard drops the `QueryAsProcOK` option it has just set, and the prepare fails with SQLCODE -428 (inference about the internal order; the failure itself is measured). OcuPilot calls the admin API in pooled web server processes, so after any SQL settings change (OcuPilot's own, the classic SQL page's, or a session's) each stale worker fails its next uncached class-query list once: Upcoming tasks, and ECP settings' data-server list (DW-2646).

**Approach:** Before every vendor call, `AdminPort` runs the vendor's own context check (`$$$SQLCompileCheckContext` from `%msql.inc`). A stale context is discarded before the prepare sets its option, not during it. The `config-settings` spec's cached-query purge was a test-side workaround and is removed.

## Boundaries & Constraints

**Always:**

- The check runs in `AdminPort.InvokeLocated`, before any vendor call. Both callers pass through it: the request worker and the turn job.
- It is the vendor's macro, not a copy of its expansion. The fallback is in Design Notes.
- A check that throws changes nothing, and the call proceeds as before.

**Never:**

- Recycle or terminate web server processes, from product code or from a test hook.
- Purge cached queries to mask the defect.
- Run the SQL settings write in a child process.
- Add a user-facing string.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Change made outside the pool | Worker context predates a session or classic-page `Config.SQL` change; Upcoming tasks not cached | `tasks.upcoming` read answers 200 with rows on the first try | none (was 500 `INTERNAL`, `-428` logged) |
| OcuPilot's own change, browser | `config-settings` sets and restores `SaveMAC`, then `dashboard` | Task manager group draws Upcoming tasks' rows | none (was `{"rows":0,"empty":null}`) |
| Another class-query list | ECP settings after the same change | `ECP.DataServer` read answers | none (was -428 `CONFIG.ECPSERVERS_STATUSLISTSMPFILTER`) |
| Context already current | version equals the context's | no discard; call unchanged | none |
| Check cannot run | the read of the version global throws | call proceeds as it does today | caught and ignored |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AdminPort.cls` -- the only class naming `%Api.Admin.*` (AD-2, AD-27). `InvokeLocated` begins at line 1274, with the `Set pFault = ""` line at 1280 just before its `Try`. `Invoke` (line 1265) delegates to it. No production subclass; ten `OcuPilot.Test.*` fixtures extend it (`PortFixture` among them), so `Include` reaches their compiles too.
- `%Api.Admin.Util.ClassQuery.RunQuery` (hidden vendor class, read through `GetTextAsString`) -- `stmt.%PrepareClassQuery(..QueryClass, ..QueryName, 2)` on every class-query list endpoint.
- `irislib/%SQL/Statement.cls:570-599` -- `%PrepareClassQuery` sets `$SYSTEM.Context.SQLCompile().Options("QueryAsProcOK")` before `..prepare`.
- `irislib/%msql.inc:397-405` -- `$$$SYSTEMContextGlo`, `$$$SQLCompileCheckContext`, `$$$SQLCompileUpdateContext`. The hidden `%SYSTEM.Context.SQLCompile.%OnNew` sets `Version` from the global.
- `irissys/%CSP/UI/Portal/SQL/Utils.cls:534-623` -- `SaveConfigSQLProperties` is the classic SQL page's save. It runs `Config.SQL.Modify` in its own web server process and purges cached queries through a background task when a purge key changed.
- `src/OcuPilot/Port/ConfigPort.cls:1004` -- `SendProperties`, OcuPilot's `Config.SQL.Modify`. Unchanged: the writing process refreshes its own context.
- `ui/browser/config-settings.browser-spec.mjs` -- `purgeCachedQueries` (lines 74-82) and its call and assertion in `after` (lines 150-166), plus the header sentence at lines 12-14. All were added by `6a5bcf05f`.
- `src/OcuPilot/Test/AdminPortSync.cls` -- the sibling test. It calls the port with no endpoint override, but its header says "Reads only".

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/AdminPort.cls` -- add `Include %msql` above the class. Add a private class method `RefreshCompileContext()`: `$$$SQLCompileCheckContext` inside `Try`, with an empty `Catch`. Its doc comment states the contract in one or two sentences. Call it in `InvokeLocated` after the output initialization and before the `Try` -- AD-2 port behavior, DW-2646.
- `src/OcuPilot/Test/AdminPortCompileContext.cls` -- a new `%UnitTest.TestCase` that includes `%msql`, with one method. Through the port, as `AdminPortSync` calls it, read `Task.CRUD` `UPCOMING` once, which creates the context and caches the query. Then `Do $I($$$SYSTEMContextGlo("SQLCompile"))` stands in for another process's change. In `%SYS` by save and restore, `$SYSTEM.SQL.PurgeQueries()`. Then read again and assert HTTP 200 and a rows array. The header says what it pins and that it leaves the version advanced and `%SYS`'s cached queries purged -- DW-2646.
- `ui/browser/config-settings.browser-spec.mjs` -- delete `purgeCachedQueries`, its call and its assertion. Restore the header sentence and the `after` comment to their pre-`6a5bcf05f` wording -- the test-side workaround goes.

**Acceptance Criteria:**

- AC1 (reproduction, settled in planning, see Design Notes). Given a fresh `ocupilot-ci` on the unfixed tree, when 16 concurrent Task history reads warm the workers, a session flips `SaveMAC` through `Config.SQL.Modify` and three Upcoming tasks reads follow, then the first answers 500 `INTERNAL`. `messages.log` shows SQLCODE -428 `'%SYS.TASK_UPCOMINGTASKSFILTER' not found` from a worker whose context version is older than the global, and the next read in that same worker answers rows (4 of 4). The browser path (`config-settings` SaveMAC test, then `dashboard`) fails the same way: the activation ran in worker 2021 and the failure came in worker 2041, whose context was at version 2 against a global of 4.
- AC2. Given the fix, when `config-settings`, `dashboard`, `ecp-settings` and `database-operations` run in that order on a fresh instance, then each is green. With the `RefreshCompileContext` call removed, `dashboard` AC2 goes red, and so does `ecp-settings` C2.
- AC3. Given the fix, when `AdminPortCompileContext` runs, then it is green, and it goes red (500 `INTERNAL`) with the call removed.

### Review Findings

Code review 2026-11-16 (full-opus; four layers). Patched in this pass:

- [x] [Review][Patch] `AdminPortCompileContext` header named the wrong grants (`%Admin_Secure:U`, `%DB_IRISSYS:R`) and said the version stays advanced; it needs `%Admin_Task:U` and `%DB_IRISSYS:RW`, and `%UnitTest.Manager` puts the version back at close (measured: 4 before and after a run) [low]
- [x] [Review][Patch] The test now asserts its own precondition (the context is older than the version) and the first read's rows array [low]
- [x] [Review][Patch] The test's `Catch` restores `$NAMESPACE` on its first line (AD-16) [low]
- [x] [Review][Patch] `RefreshCompileContext`'s doc comment says "uncached" and is two sentences [low]
- [x] [Review][Patch] AC1 had no line in `## Verification` [low]
- [x] [Review][Defer] The vendor's interop editors API fails the same way after a SQL settings change, outside `AdminPort` (21.24's CI log shows `%Api.InteropEditors.v1` -428) [med] -- DW-2647 escalated

Rejected:

- `false`: The purge removal reopens 21.24's database failure. 21.24's CI log shows that failure as -428 on `Database.ConfigCRUD` through `AdminPort`, which the fix covers. Its interop-editors sibling is DW-2647.
- `false`: The runtime `SQL` context goes stale too. Only the `SQLCompile` node exists under `contextVersion` (measured).
- `false`: `PollTask` skips the check. It runs only inside the `AwaitTask` of a request that already ran the check, and it reads a task row.
- `low`: `Template` and `ProbeAnswers` reach the vendor without the check. Neither runs a class query, so this is theoretical; it becomes real if one ever does.
- `low`: A settings change between the check and the prepare. The window is one request, and the outcome is the pre-fix single 500.
- `low`: The empty `Catch`. The spec requires it ("caught and ignored"). Every vendor call already needs `%SYS` access, and the check costs about 0.15 us per call (measured).
- `low`: The AC2 browser guard depends on shard order. This duplicates the triage log; `AdminPortCompileContext` is the CI pin.

## Spec Change Log

## Review Triage Log

### 2026-11-16 -- Review pass

- verdicts: 5 findings -- high 0, medium 0, low 3, false 2, maybe-false 0
- findings:
  - `[low]` `[reject]` The check-throws path of `RefreshCompileContext` has no test -- inducing a throw in a vendor macro needs a seam the change does not add; the guard is a three-line `Try`/`Catch`, and no user-reachable failure is shown.
  - `[low]` `[reject]` The browser guard for AC2 depends on `config-settings` running before its readers in one shard -- the in-process `AdminPortCompileContext` test is the self-contained pin and is run in every CI leg; shard assignment is outside this story.
  - `[low]` `[reject]` No assertion that a current context is left alone -- an unconditional discard only costs a recompile; the fix would add a second synthetic state to the test.
  - `[false]` `[reject]` The new test purges `%SYS` cached queries, which the intent forbids -- the intent forbids it as a product-side mask; the test uses it as setup to force the compile and its header says so.
  - `[false]` `[reject]` The unit test's staleness is synthetic and the real-surface evidence is prose -- the spec prescribes the version bump as the stand-in for another process, and the browser chain (AC2) ran on fresh instances with the recorded mutation.

## Design Notes

**Governing ADs:** AD-2 (port behavior), AD-27 (the vendor dependency stays in the port), AD-4 (the complete property set; unchanged), AD-7 (the write stays in the confirm or action request), AD-9 (no `JOB`), AD-16 (the test's `%SYS` purge uses save and restore). Inbox: DW-2646 is addressed by every task. Consumed-by and Consumes: no new service or module, so neither applies.

**Experiments** (fresh rebuilds of `ocupilot-ci`; scripts and logs in `/private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/21-32/`):

- In a session, with the version bumped and `%SYS` purged, the next `%PrepareClassQuery(...,2)` fails -428 once, then succeeds. Without the purge it succeeds, because the cached query compiles nothing.
- Bearer versus Basic makes no difference: curl with either, with warm workers, OcuPilot's set and a purge, stays green.
- Recipe A (warm, session flip, purge, read) is green: OcuPilot's own purged statements recompile first in the request and refresh the context (inference; the trace shows a stale worker refreshed without failing).
- Recipe B (history burst, OcuPilot's set, upcoming burst) is green. The worker that made the set compiled first, and the stale workers found the cache.
- Recipe C is AC1: red 4 of 4, one of them uninstrumented. With the candidate fix loaded it is green 2 of 2.
- Instrumented browser run: activation in worker 2021 (version 2 to 3), the session restore took it to 4, and the failure was in worker 2041 (context version 2). 2041's next Upcoming read answered.
- Recipe V uses the vendor's `/api/admin/v2/task/upcoming` only, with no OcuPilot route: red. The defect is the vendor's.
- In-process through `AdminPort.Invoke`: 500 without the fix, 200 with it. A `%SYS`-only purge is enough.
- Chains with the fix: the committed spec 4 of 4 files green, and the spec with the purge removed 4 of 4. Without the fix and without the purge: `dashboard` and `ecp-settings` red.
- DW-2646's evidence line has one finding wrong. Each stale worker fails once and is then current; the purges "did not clear it" because each one forced fresh compiles on other stale workers (inference). Correct the ledger with a trailer.

**Fix options weighed:** Moving the activation out of the web server process, or into a short-lived child, changes nothing for the reader: the version global is instance-wide, and every pooled worker is stale either way. Restoring the context after the write fixes only the process that wrote, which is already current. The reader-side check covers every source of the change, the classic page included. No AD-7 amendment is needed.

**Classic page:** its save runs `Config.SQL.Modify` in its own web server process, as OcuPilot does (measured stand-in: a session `Modify`). It therefore breaks OcuPilot's lists and the vendor's own admin API the same way (inference from the stand-in, which broke both). Owner item for the runner, never decided here: whether to report the vendor defect to InterSystems.

**Decided in-stage:** a new test class rather than a method on `AdminPortSync`, whose header promises reads only, while this test advances a vendor counter and purges `%SYS`'s cached queries. The class is not armed: both effects are what any SQL settings save does. If `Include %msql` collides at compile in `AdminPort` or a fixture subclass, write the macro's one-line expansion and name the macro in the doc comment.

**No AD amendment** (orchestrator ruling 2026-11-16): AD-27 covers it. `AdminPort` reads an internal vendor counter (`%msql.inc`) and calls an internal method (`$SYSTEM.CLS.ClearContext`), and both stay in the port.

## Verification

**Shared surfaces:** the `config-settings` spec's `after` hook. *Every test added or changed passes on a fresh environment, in either order.*

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only, never two test calls in one message. `L` is `/private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead`.

- `(loop)` `sh $L/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.AdminPortCompileContext`, then the same command for `AdminPortSync`, `TaskLists` and `PortGate`, one class per call -- green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh`, `cd ui && node --test tools/ci.test.mjs` -- clean.
- `(loop)` AC2 chain: `sh $L/fresh.sh <dir> rebuild`, `cd ui && npm run build`, `sh $L/fresh.sh <dir> deploy`, then `config-settings`, `dashboard`, `ecp-settings` and `database-operations`, one `node --test --test-concurrency=1 browser/<name>.browser-spec.mjs` per call, in that order, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci` -- all green.
- `(once)` `cd ui && npm run test:tools` -- green.
- `(once)`, runner-owned: the full ObjectScript sweep, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), to record:**

- AC2 and AC3: remove `Do ..RefreshCompileContext()`, rebuild fresh, and run the chain: `dashboard` and `ecp-settings` go red. `AdminPortCompileContext` goes red after a reload. Revert, check that `git status --short` and `git diff --stat` are unchanged, then reload.

Recorded (2026-11-16, `ocupilot-ci`):

- AC1 is a planning-time reproduction (Design Notes, Recipe C); `AdminPortCompileContext` is its pin, under AC3's mutation.
- mutation (code review, after the test gained its precondition assertion): the same removal, reloaded -> run 7 red on the three post-change assertions only, with the precondition green; reverted (tree byte-identical), run 8 green.

- mutation: removed `Do ..RefreshCompileContext()` from `InvokeLocated`, reloaded -> `AdminPortCompileContext.TestAnUpcomingTasksReadSurvivesASqlSettingsChange` went red (500 `INTERNAL`: status, 200 and rows-array assertions).
- mutation: the same removal on a fresh instance, committed spec with the purge removed -> `dashboard` AC2 and `ecp-settings` C2 went red (`config-settings` 7/7).
- Reverted (`git diff --stat` byte-identical), fresh rebuild: `config-settings` 7/7, `dashboard` 3/3, `ecp-settings` 5/5, `database-operations` 6/6.

**Runner ruling at the spec gate (2026-11-16):** validated. No AD amendment is written (see Design Notes). DW-2646's evidence is corrected in the ledger (one failure per stale worker). The vendor defect report is the owner's call, routed through the orchestrator.

## Auto Run Result

Summary: `AdminPort.InvokeLocated` now runs the vendor's `$$$SQLCompileCheckContext` before every vendor call (new private `RefreshCompileContext`, empty `Catch`), so a stale pooled-worker context is discarded before the class-query prepare sets its option. The test-side cached-query purge is removed from the `config-settings` spec.

Files changed:

- `src/OcuPilot/Port/AdminPort.cls` -- `Include %msql`, `RefreshCompileContext`, and its call in `InvokeLocated`.
- `src/OcuPilot/Test/AdminPortCompileContext.cls` -- new test: an Upcoming tasks read after the version advances and `%SYS` is purged answers 200 with rows.
- `ui/browser/config-settings.browser-spec.mjs` -- `purgeCachedQueries`, its call, its assertion and the header sentence removed.
- This spec -- design-note correction (no AD amendment), mutation lines, triage log.

Review: 0 patches, 0 deferred, 5 rejected with reasons in the triage log (3 low, 2 false).

Verification: `LOADERRORS=0`; `AdminPortCompileContext` 1/1, `AdminPortSync` 7/7, `TaskLists` 7/7, `PortGate` 4/4; `check-objectscript` and its harness, `lint-docs`, `ci.test.mjs` 103/103, `npm run test:tools` 2294/2294. Fresh chain on the fixed tree: `config-settings` 7/7, `dashboard` 3/3, `ecp-settings` 5/5, `database-operations` 6/6. Mutation (call removed) turned `AdminPortCompileContext`, `dashboard` AC2 and `ecp-settings` C2 red; reverted and confirmed byte-identical.

Follow-up review recommended: false.

Residual risk: `AdminPortCompileContext` purges `%SYS`'s cached queries, as any SQL settings save does; the version it advances is put back by `%UnitTest.Manager` at close.

Status: done
Blocking condition: none
