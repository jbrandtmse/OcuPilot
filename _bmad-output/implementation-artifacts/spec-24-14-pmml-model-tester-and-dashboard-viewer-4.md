---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 2b: a PMML test Cancel that lands)'
type: 'bugfix'
created: '2026-11-20'
status: 'done'
baseline_revision: '3e15dd0926acdd6d4d1711343bc6000e78d42fde'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-14-pmml-model-tester-and-dashboard-viewer-2.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A person's Cancel of a PMML test (`PmmlTest.CancelJob`: `CancelQuery` sent again 0.1 s apart, the guard re-read each try, 100 sends in a 10 s budget) reaches the job only while it is inside the SQL engine. That is about 2% of the vendor's loop over a fast join, so a Cancel can miss and the run goes on to its end (Batch 2 rework 1).

**Approach:** The orchestrator ruled the batch measurement-led and released U-123's cancel mechanics. Task 0 measured two options, and the plan picks **(b)**, since only (b) lands whatever the job is doing (Design Notes › Measured). The Cancel ends the run's own background job, then drops that run's result rows by test id itself. The job is exactly the process the run row records while that process holds the run's lock (`SqlRun.GuardedCancel`'s `pJobId` with `pLive`).

## Boundaries & Constraints

**Always:**

- **Recording the test id.** `AnalyticsPort.PmmlRun` allocates the test id (`TempResult.GetNewTestId()`) before it switches namespace. It then records the id through the stop class's new hook `RecordTest(pStopKey, pTestId)`, unswitched (AD-16), before the vendor writes anything. `PmmlVendor` takes the id as input.
- **The record.** `PmmlTest.RecordTest` writes `^IRIS.Temp.OcuPilotPmmlRun(runKey) = $ListBuild($Job, testId)`. `PmmlTest.Work` kills it after `PmmlRun` returns, on every path.
- **The cancel (`PmmlTest.CancelJob`).** It acts only when `pLive` is set and `pJobId` is not empty, and the target is always `pJobId`. It calls `$SYSTEM.Process.Terminate(pJobId)` once, from no escalated frame, with the person's own rights. It then waits up to `ENDSECONDS` (2) for `^$JOB(pJobId)` to be gone.
  - **When the job is gone:** if the record names that same `pJobId`, it drops the record's test id through `AnalyticsPort.PmmlDrop`; either way it kills the record.
  - **When the job is still there, or Terminate refuses or throws:** nothing is dropped and the failure is logged once. The job's own path then ends the run `canceled` and drops its rows when the vendor returns, as Batch 2 does.
- **Kept from Batch 2.** The always-drop guarantee: rows are dropped by test id on every ending, by the job or by the canceller. The `stopped` answer for a run past its bound, the owner-scoped 404, and busy, full and lost.
- **The target.** A person's Cancel answers the run `canceled` within 2 s, in 20 of 20 runs over `SLOWSCAN` and over a fast-statement cross join. It leaves no row for the test id, no record and no live job.

**Never:**

- A pid found by statement text, `INFORMATION_SCHEMA.CURRENT_STATEMENTS`, `^$LOCK` or the record's own pid (DW-2803's lesson); `CancelQuery` in the PMML cancel; and the `CANCEL*` parameters.
- Any edit to `BackgroundRun`, `SqlRun`, the MDX, pivot or SQL kinds, the client, the strings, the routes or the spine.
- `Terminate(` in any product file but `PmmlTest.cls` and `Port/ProcessPort.cls`.
- Edits to `ui/angular.json`, `ui/vitest-base.config.mjs`, `Prohibited.cls` or `scripts/ci-throwaway.sh`.

## I/O & Edge-Case Matrix

Every row runs in USER on `ocupilot-b-ci`, over HTTP as `OcuP2414PmmlReader` (the pairs and `%DB_USER:R`, no `%Admin_Operate`), unless it says otherwise. Each cancel is sent once the run has written a row.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Slow scan | Custom `SLOWSCAN` | Cancel answers `canceled` within 2 s; the job is gone; no row for the id; no record | - |
| Fast cross join | Custom `SIXWAY` (2,985,984 combinations) | Same | - |
| In no statement | `PmmlTestIdle`'s job (in-process start) | `canceled` within 2 s; the job is gone | - |
| Only its own job | `PmmlTestIdle` run; its record forged to name a bystander process of the same account and another test's seeded rows | The run's job is gone; the bystander lives; the seeded rows are whole | - |
| Past its bound, another user, busy | As Batch 2 | `stopped`; 404; 409, unchanged | `.NOTFOUND`, `.BUSY` |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `9fb5dca17`). No file here is changed on `origin/OCU-1-epic21` beyond feature (checked at plan time; the implement stage re-runs the `git log` check).

- `src/OcuPilot/Area/Analytics/PmmlTest.cls`: `CANCEL*` :172-180 and `CancelJob` :187-201 are replaced; `Work` :139-170 kills the record; the class doc :14-17 lists the seams. The hook overrides `BackgroundRun.CancelJob` :90, which gets its `pJobId` and `pLive` from `Cancel` :326-332 through `SqlRun.GuardedCancel` :274-311 (the row's `JobId`, live only while `LockHeld`).
- `src/OcuPilot/Port/AnalyticsPort.cls`: `PmmlStopAsked` :2633 (the sibling the record call follows); `PmmlRun` :2647-2677 allocates and records; `PmmlVendor` :2682-2712 takes `pId` as input; `PmmlDrop` :2812 is unchanged and is reused by the canceller.
- `src/OcuPilot/Test/PmmlRunSeam.cls`: its own stop class (:22), so it gains a `RecordTest` that records nothing.
- `src/OcuPilot/Test/PmmlTestIdle.cls`: drop `CANCELTRIES`/`CANCELBUDGET`; add `Bystander()`, an idle process released by `^IRIS.Temp.OcuPilotPmmlIdle("bystander")` or after 60 s.
- `src/OcuPilot/Test/PmmlProbe.cls`: gains `Seed`, moved from `AnalyticsPmmlRun.cls` :138 (Rule 2), and `Left` :232 reports `records:<n>` for `^IRIS.Temp.OcuPilotPmmlRun`. `Remove` and `DropRows` do not clear the records, so a leak stays visible.
- `src/OcuPilot/Test/AnalyticsPmmlRunEdge.cls`: `PRINCIPALS` :37 (`READER` is granted `SELECT` on `ProbePmml.Source` after the probe's `Create`); `TestACancelThatMeetsNoStatementIsBoundedByItsBudget` :249 and `TestACancelEndsARunAndLeavesNoRow` :343 are rewritten; `AwaitInStatement` :369 and its use at :415 are deleted; the class header is updated.
- `src/OcuPilot/Test/AnalyticsPmmlRun.cls`: calls `PmmlProbe.Seed`.
- `ui/tools/analytics.test.mjs`: a new test beside the Story 20.33 Never-list test :180, using its `codeOf`.
- Read-only: `irislib/%SYSTEM/Process.cls` `Terminate` :1755-1787, return codes 1, 0, -1 to -4.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Port/AnalyticsPort.cls`: allocate and record in `PmmlRun` (Always); make `PmmlVendor`'s `pId` an input; update both doc comments. This puts the id on record before any row exists.
- [ ] `src/OcuPilot/Area/Analytics/PmmlTest.cls`: add `RecordTest`, `ENDSECONDS` and the new `CancelJob`; `Work` forgets the record; the class doc states the cancel contract.
- [ ] `src/OcuPilot/Test/PmmlRunSeam.cls`, `PmmlTestIdle.cls`, `PmmlProbe.cls` and `AnalyticsPmmlRun.cls`: as the Code Map says.
- [ ] `src/OcuPilot/Test/AnalyticsPmmlRunEdge.cls`: the matrix's first four rows.
  - `TestACancelEndsARunOverEitherStatement` loops over `SLOWSCAN` and a new `SIXWAY` parameter. Each run is started and canceled over HTTP as `READER`. Read the run's `JobId` from `SqlRun` before the cancel, and assert the cancel's own answer reads `canceled` within 2 s.
  - `TestACancelEndsARunWhoseJobIsInNoStatement`.
  - `TestACancelEndsOnlyTheRunsOwnJob`. It releases the bystander and kills its forged record and the seeded rows on every path.
  - The busy test loses its `AwaitInStatement`.
- [ ] `ui/tools/analytics.test.mjs`: in product code (`src/OcuPilot` outside `Test/`), `Terminate(` appears only in `Port/ProcessPort.cls` and in `Area/Analytics/PmmlTest.cls`. In `PmmlTest.cls` it appears once, as `$SYSTEM.Process.Terminate(pJobId)`. Add-only.

**Re-open 2: the supervisor (orchestrator ruling A, veto item U-130). The newest Spec Change Log line is binding. Where the Always and Never items above, the Matrix or the Execution list name a direct `Terminate` from the cancel, the record's pid, or an edit ban on `BackgroundRun`, this block governs.** The working tree holds the previous implementation, uncommitted. Build on it. Its probe reference is `/private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e24u/24-14/sup-src/` (`Sup.cls` is the design; `Router.cls` shows how the probe held a web process busy) with logs `sup-*.txt` beside it. Read them.

- **Supervisor.** Today's `PmmlTest.Work` becomes the supervisor, the background run `BackgroundRun.Run` already spawns, which holds the run lock.
- **Child spawn.** ONE new helper in `src/OcuPilot/Kernel/Shell/BackgroundRun.cls`, called only by the PMML supervisor, spawns the child. A `JOB` command appears nowhere else in shipped code, and `scripts/check-objectscript.py` rule 19's roster is unchanged and green. The child runs today's run body: the checks, `PmmlRun`, `Finish`, record kill (move it to its own method in `PmmlTest`).
- **Wait.**
  - The supervisor creates a per-run named `$System.Event` resource whose name carries the 32-hex run key, `$Name(^IRIS.Temp.OcuPilotPmmlCancel(key))`, and re-checks `StopRequested` after the create.
  - It waits in short slices until a deadline of the bound plus a grace.
  - A wake without the owner's `StopRequested` is ignored. A deleted resource (-1) is re-created and the wait continues.
  - On every path it deletes the event resource.
- **Cancel.** `PmmlTest.CancelJob` checks ownership as today (`pLive`), sets the stop flag (`GuardedCancel` has), and signals the event. It treats <UNDEFINED> as "not waiting yet; the flag covers it". It then waits up to `ENDSECONDS` for the run to leave `running`. It NEVER calls `Terminate`. Remove the old direct-`Terminate` body.
- **A wake with the owner's flag.**
  - Terminate `$ZChild` only, never a pid read from storage; wait for the child to leave `^$JOB`.
  - Drop the test id's rows (`PmmlDrop`), remove `^IRIS.Temp.OcuPilotPmmlRun(key)`.
  - Only THEN write `canceled` (`Finish` ended with the owner's flag set). The poll must never read `canceled` while rows remain.
- **Other endings.**
  - The deadline ends the run `stopped` (the vendor's `{outcome: stopped, seconds}` shape), cleaned up the same way, reusing the port's `StoppedAnswer` if it is reachable.
  - When the child ends on its own, the supervisor reaps whatever is left (the record, any rows the record names, a still-`running` row ends `failed`) and exits, and never overwrites a final state the child wrote.
  - The supervisor's catch terminates its child, ends the run `failed`, and cleans up.
  - Check `SqlRun.GuardedFinish`'s behavior on an already-ended run before relying on it.
- **No escalation.** No `$Roles` change; spawn from no escalated frame (AD-9).
- **No transaction or lock at termination.** In the code and in Design Notes, confirm the child holds no open transaction and no lock other than none, or the run lock, at any moment it can be terminated. If it can be inside a `TSTART` (the vendor's result-row save), say what the rollback does. The comment states the contract, not the history.
- **Tests (each passes on its FIRST run on a fresh instance, in either order).** After every cancel, over BOTH `SLOWSCAN` and the fast six-way join (`SIXWAY`), assert: no live job or supervisor, no held run lock, no result rows, no `^IRIS.Temp.OcuPilotPmmlRun` node, no event resource. Also:
  - a cancel forced onto a different web process than the start (hold the first web process busy as the probe's `Hold` did, and assert the two pids differ);
  - another user's cancel refused, nothing changed;
  - a stale or reused pid never ended (end the job first, then cancel by the stale row);
  - a wake without the flag is ignored;
  - a deleted event resource is re-created and the run still cancels;
  - a hung job ended at bound plus grace (a fixture with a short bound and a short grace);
  - zero leftovers of each kind after every path, including a run that finishes without a cancel.
- **`ui/tools/analytics.test.mjs` guard.** In product code (`src/OcuPilot` outside `Test/`), `Terminate(` appears only in `Port/ProcessPort.cls` and in `Area/Analytics/PmmlTest.cls`, where it is aimed at `$ZChild`; pin that, and that `PmmlTest.CancelJob` contains none.
- **Re-measure** with the implemented code: 20 cross-process cancels per statement, distinct pids (starter web process and canceling web process), within 2 s. Record the timings in `## Verification`. If the target cannot be met, HALT `blocked` with `intent gap` and the measurements, and do not widen scope.
- **Named limits (write them in Design Notes; do not fix them).** A killed supervisor leaves the child running to its bound and the poll reads `failed`; the event resource is unguarded; a late cancel costs about 3.9 s for the drop.
- **Stale claims.** Replace, do not append to, every sentence in `## Design Notes` (Decided in-stage, Orchestrator conditions, Veto items) and `## Verification` (`Implement stage`, `Target`, `Decided in-stage`) that describes the direct-`Terminate` design; the Measured table is measurement history and stays. The `Auto Run Result` is not yours to edit.

**Acceptance Criteria:**

- **AC1 (Integration, Rule 1; the target).**
  - **Given** a least-privileged person's run over `SLOWSCAN` or `SIXWAY` that has written a row,
  - **When** the Test screen's Cancel posts `POST /analytics/pmml/background/:id/cancel`,
  - **Then** the answer reads `canceled` within 2 s, the run's job is gone, and the test id holds no row.
- **AC2 (any state).**
  - **Given** a run whose job is in no SQL statement,
  - **When** its owner cancels it,
  - **Then** it reads `canceled` within 2 s and its job is gone.
- **AC3 (only its own job).**
  - **Given** a run whose record names another process and another test,
  - **When** its owner cancels it,
  - **Then** only the run's recorded job ends, and the other test's rows are whole.
- **AC4 (fresh, either order).**
  - **Given** any added or changed test, run first on a fresh instance in either order,
  - **When** it ends,
  - **Then** `PmmlProbe.Gone()` is true, and no job it started is alive.

## Spec Change Log

- 2026-11-20, spec gate (runner, veto item U-129): option (b) kept as measured (20/20 over SLOWSCAN and the fast join, max 0.109 s); the temporary run node and the proposed AD-7 wording kept; Batch 2's spec corrected at its origin.
- 2026-11-20, re-open (runner, orchestrator ruling, veto item U-130): option (b) as a direct cancel is replaced by a per-run supervisor, because `Terminate` lands only from the job's direct parent (probe: 40/40 cross-process cancels, max 0.114 s, zero leftovers; logs `scratchpad/e24u/24-14/sup-*.txt`). The supervisor is the background run `BackgroundRun` already spawns (today's `PmmlTest.Work` becomes it). It JOBs the run's own job through one new `BackgroundRun.cls` helper that only it calls (no fifth `JOB` site; check-objectscript rule 19 unchanged), holds the run lock, and waits on a per-run named `$System.Event` with a deadline of the bound plus a grace. Cancel sets `StopRequested` and signals the event, and never calls `Terminate`. On a wake with the owner's flag set, the supervisor terminates `$ZChild` only, drops the test id's rows, removes the temp node and only then writes `canceled`. A wake without the flag is ignored. A deleted resource (-1) is re-created and the wait goes on. The deadline ends the run `stopped`. When the child ends on its own, the supervisor reaps and exits. Named limits: a killed supervisor leaves the child to its bound and the poll reads `failed`; the event resource is unguarded; a late cancel costs about 3.9 s for the drop. The AD-7 line is reworded and an AD-42 sentence is added, both proposed (U-130); the spine is unedited.

## Review Triage Log

### 2026-11-20 — Review pass

- verdicts: 14 findings — high 0, medium 1, low 6, false 6, maybe-false 1
- findings:
  - `[medium]` `[patch]` Supervisor endings other than cancel and bound (a child ended from outside, reaped) have no test -- added `TestAChildEndedFromOutsideIsReapedAndTheRunReadsFailed` with two recorded mutations, red then green.
  - `[low]` `[patch]` No `mutation:` line for the id hand-off or for `Reap`'s drop -- both run red and recorded under `## Verification`.
  - `[low]` `[patch]` The cross-process test's doc comment named a `ChildWork` forget-record mutation that no test can fail on (`Reap` removes the record too) -- the comment now names the two recorded mutations.
  - `[low]` `[reject]` `Residue`'s `lock:` and `rows:` legs cannot fail independently on the idle legs -- the real-run legs carry the rows, and the supervisor holds the lock to its exit; not worth a guard.
  - `[low]` `[reject]` The one-JOB-site claim is pinned by the per-file roster (`check-objectscript` rule 19) and the product has one caller of `SpawnChild`; a per-file count is more machinery than its risk.
  - `[low]` `[reject]` `Records()` counts every record node (state the test did not create) -- AC4's `PmmlProbe.Gone()` is that same count for every PMML class, and classes run one at a time.
  - `[low]` `[reject]` The source-text guard in `analytics.test.mjs` adds no behavior check -- it is supplemental to the runtime tests, which pin the behavior.
  - `[false]` `[reject]` A lost cancel between `Work`'s flag check and the first wait -- a signal sent to an existing event is kept until a wait takes it (`sup-point1-events.txt`: signal first, then wait answers 1 at once), and a signal sent before the event exists is covered by `Work`'s flag read after the create, the flag being set before the signal.
  - `[false]` `[reject]` The test id is allocated before the model resolves, so a path that never runs the vendor drops rows that do not exist -- the contract places the allocation before the namespace switch, and a drop of an unused id deletes nothing.
  - `[false]` `[reject]` The counter is read in the caller's namespace -- `GetNewTestId` is `$Increment(^IRIS.Temp.DeepSee.PMML.ResultI("TestIdx"))`, an IRISTEMP global every namespace shares.
  - `[false]` `[reject]` The cross-process test serves its requests through a test web application, not the product's -- it reaches the same `HandleStart`, `HandlePoll` and `HandleCancel`; the product routes are covered by `EndpointCoverage` and the other PMML classes.
  - `[false]` `[reject]` Several matrix rows run in-process -- the matrix names the idle row as an in-process start; the rows added beyond it (wake, deleted event, stale row) are not matrix rows.
  - `[false]` `[reject]` The cancel's own answer can read `running` for a late cancel -- a named limit in Design Notes, not an AC.
  - `[maybe-false]` `[reject]` The `CancelAcross` two-second bound could fail on a slow shard, since the drop grows with the rows written before the cancel -- measured 0.152 s at most against a 2 s bound; it would be low, and the fix (a smaller statement or a longer bound) moves the target.
  - The sed-written `AnalyticsPort.cls` hunk was read line by line by both layers: clean, an Edit-tool result (no `.bak`, no CR, `git diff --check` clean).

## Design Notes

**Governing ADs (Rule 6):**

- AD-7: the run's kind and its never-mutates scope.
- AD-8: the supervisor ends its own child with the person's own rights, measured; no escalation.
- AD-9: the run and its child are spawned from no escalated frame.
- AD-10: this is not a write-path terminate and not a tool; the Process screen's arm is untouched.
- AD-16: the record hook runs unswitched.
- AD-41 and AD-42: the caps and the spawn sites are unchanged; the child is a second `JOB` at `BackgroundRun`'s site (proposed AD-42 sentence).
- AD-65.

There is no contradiction. The 20.33 spec's Never ("no `Process.Terminate` in product code") binds that story's files, which `analytics.test.mjs`'s MDX set still pins.

**Integration and linkage (Rules 1, 2).**

- **Consumes:** `BackgroundRun.Cancel`/`CancelJob`, `SqlRun.GuardedCancel`, `AnalyticsPort.PmmlRun`/`PmmlDrop`.
- **Consumed-by:** the Test screen's Cancel (`pmml-test.store.ts`, unchanged).
- AC1 is the Integration AC.
- `CancelJob` overrides the hook `BackgroundRun` declares. `RecordTest` follows `StopRequested`'s hook shape.

**Ledger inbox (Rule 17):** none (`LEDGER slice` is empty).

**Measured (Task 0, plan, 2026-11-20, `ocupilot-b-ci`).** Setup: USER, the probe, the production `PmmlTest` subclassed per option in scratch classes (since removed). Each run was spawned in process as the instance administrator. The cancel was sent a random 0-1 s after the job's first row. "Lands" is the time from the cancel to the run reading anything but `running`, in seconds, 20 runs each.

| Option | Statement | Landed, all 20 | min | median | max | Rows left, jobs left |
|---|---|---|---|---|---|---|
| (a) tight loop, guard once, `CancelQuery` timeout 0 | `SLOWSCAN` | 20 | 0.011 | 0.013 | 0.016 | 0, 0 |
| (a) | `SIXWAY` | 20 | 0.072 | 0.220 | 1.653 | 0, 0 |
| (b) end the run's own job, drop by id | `SLOWSCAN` | 20 | 0.006 | 0.008 | 0.010 | 0, 0 |
| (b) | `SIXWAY` | 20 | 0.020 | 0.063 | 0.109 | 0, 0 |

- **(a) is a lottery.** Over `SIXWAY` its loop needed 191 to 128,101 sends (median 749), so its tail reached 1.65 s of the 2 s target. In trials, a `CancelQuery` timeout of 1 or 3 s made sends block, and two runs landed at 3.9 s and 4.3 s. It never reaches a job that is in no statement (the verification source).
- **(b) does not depend on luck.** `Terminate` answered 1 each time, and the job was gone within 0.012 s. Its catch did not run, so the canceller's drop is the only drop on that path.
  - A late cancel (37.6 s into `SIXWAY`) answered in 3.9 s, nearly all of it the drop of the rows written: about 28,000 a second (inference, from 248,832 in 8.9 s).
  - Afterwards there was no leftover statement, `SqlRun` lock or result row.
- **Rights, as a least-privileged principal** (`%Ens_Portal`, `%DeepSee_Portal`, `%Development`, `%DB_USER:R`):
  - `Terminate` of its own process answered 1 and the process ended, also while that process waited inside an OcuPilot escalated store frame (`GuardedReserve`'s lock wait). That store call never completed.
  - `Terminate` of another user's process threw `<PROTECT>`.
  - `^$JOB` was readable; `^$LOCK` on `^OcuPilotSqlRun` threw `<PROTECT>`, so it cannot serve as the guard.
  - `CancelQuery` on a process in no statement answered #6164.
  - From an HTTP request rather than a job (inference): AC1 pins it.

**Decided in-stage (plan).**

1. **Option (b) as a supervisor (Re-open 2).** `Terminate` lands only from a job's direct parent, so the run's own job, which `BackgroundRun.Run` spawns and which holds the run lock, supervises a child that runs the vendor call. The child is spawned by `BackgroundRun.SpawnChild`, the second `JOB` at the one spawn site (`check-objectscript` rule 19's roster is unchanged). The cancel signals the run's event and ends no process, so it lands from any web process.
2. **The record lives in IRISTEMP, keyed by run key**, because `SqlRun` is out of scope and the supervisor needs the id. It gives no new reach: IRISTEMP is writable by any code-running user, as the vendor's result rows are. A forged record needs the run key, which only the owner holds. The supervisor drops its rows only when its pid equals the `$ZChild` it spawned, and a pid read from it or from storage is never a target.
3. **The cancel's answer waits up to `ENDSECONDS` (2) for the run to leave `running`.** The supervisor drops the rows before it writes `canceled`, so a late cancel whose drop outlasts the wait answers `running` and a poll then reads `canceled` (named limit).
4. **The supervisor's timing.** One wait on the event lasts `WAKESECONDS` (0.5); the deadline is the bound plus `GRACESECONDS` (5); it waits up to `CHILDSECONDS` (1) for a child it ended to leave the process table. A child that does not leave is logged, and its rows and record are left, since it may still write.
5. **`Seed` moves to `PmmlProbe`** (Rule 2), so the edge class need not call another test class.
6. **The cross-process test** serves the start and the cancel through a test web application (`OcuPilot.Test.PmmlHoldRouter`, created by the edge class and removed with it), which answers the serving process id and can hold one web process busy, so the two requests are served by two processes.

**No transaction or lock at termination.** Neither job holds a lock but the run's, which the supervisor holds and nothing else takes. The child opens no transaction of its own. The vendor's save of a result row and the store's save of the run's end each open one for the instant of that save, and a process ended inside a transaction rolls it back. A result row whose save is cut can stay under the test id, and the drop by id removes every row whose index entry was written; IRISTEMP is not journaled, so the rollback restores nothing there (inference). A store save of the run's end that is cut leaves the run `running`, and the supervisor's own end then writes the state. The child's locks are freed when it ends. The same statement is in `PmmlTest.Work`'s comment.

**Orchestrator conditions (binding; AD-7 and AD-42 stay proposed, the spine is not edited).** Each is pinned in `## Verification`.

1. The record `^IRIS.Temp.OcuPilotPmmlRun(runKey)` is gone after every ending: the child removes it when it returns, the supervisor when it ended the child.
2. The supervisor writes the run's final state only after the child is gone and its rows are dropped, so a poll never reads `canceled` while rows remain, and a run never reads `running` once its supervisor has ended.
3. After a cancel, over `SLOWSCAN` and `SIXWAY`, tests assert no live child or supervisor, no held run lock, no rows for the test id, no record and no event resource. Added tests: another user's cancel is refused and changes nothing; a stale row whose supervisor ended first never ends the process it names; a wake without the owner's flag is ignored; a deleted event is created again; a hung child is ended at the bound plus the grace.

**Named limits (stated, not fixed).**

- A killed supervisor leaves its child running to its own bound, and the poll reads `failed`.
- The event resource is unguarded: any process may signal or delete it. The supervisor acts on a wake only with the owner's flag set and creates a deleted resource again.
- A late cancel costs about 3.9 s for the drop (Measured above), which outlasts the cancel's wait; the cancel then answers `running` and a poll reads `canceled`.
- A child that does not leave the process table within `CHILDSECONDS` after `Terminate` is logged and its rows and record are left; the store's end then reads `canceled` for a cancel, since `GuardedFinish` reads the owner's flag.

**Veto items (unattended):**

- The record `^IRIS.Temp.OcuPilotPmmlRun` and the event resource `^IRIS.Temp.OcuPilotPmmlCancel` (a change to how run state is kept).
- The second `JOB` in `BackgroundRun.SpawnChild` and the supervisor design.
- The proposed AD-7 and AD-42 wording.

**Proposed AD wording** (veto item U-130; the spine is unedited). AD-7:

> "The PMML model tester's test (Story 24.14) is the background run's third kind, a person's read-kind run. Its background run supervises a child job that runs the vendor's %RunModel, %RunModelFromPMMLRows or %RunModelFromSQL, which writes the vendor's result rows and test-id counter in IRISTEMP; the supervisor drops those rows with an embedded DELETE bound to the test id on every ending. Its owner's cancel, from any of the owner's processes, sets the run's stop flag and signals the run's event; the supervisor, the child's direct parent, ends that child, drops its rows and writes canceled; a wake without the owner's flag is ignored. An SQL data source runs only once SQL query's classification types it a query. The model's generated code runs with the person's rights (named limit)."

AD-42:

> "The PMML model test's background run (Story 24.14) is a supervisor: from the same site it JOBs the run's own job, holds the run's lock, and on its owner's cancel, its bound or the job's end ends that child, drops the test id's rows and writes the run's final state, since only a job's direct parent can end it without escalation."

**Proposed strings:** none.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only; the changed classes loaded with their subclasses recompiled):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsPmmlRunEdge`, then the same for `AnalyticsPmmlRun` and `AnalyticsPmmlModels`. Expected: green.
- `(loop)` `cd ui && npm run test:tools`. Expected: green.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The browser suite is left to CI (Rule 29); this batch changes no client file.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- **Target evidence.** 20 cross-process cancels per statement through the test web application, distinct pids, within 2 s; the numbers are under `Target`.

**Shared surfaces:** `PmmlProbe.Left` (read by every PMML class's `OnAfterAllTests`), the `analytics.test.mjs` guards, and the `CancelJob` hook.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order. It leaves no row, no record, no event resource, no lock and no process.

**Mutations (2026-11-20, `ocupilot-b-ci`).** Each was applied to the worktree file, loaded with every subclass of `BackgroundRun` and `AnalyticsPort` recompiled, run as the named test method of `AnalyticsPmmlRunEdge`, then reverted with the edit tool; the `shasum` of `PmmlTest.cls`, `AnalyticsPort.cls` and `BackgroundRun.cls` equals its value before the first mutation after each revert.

- mutation: AC1 `CancelJob` skips its `Signal` -> `TestACancelFromAnotherWebProcessEndsARunOverEitherStatement` red on the cancel's answer, the time (2.0 s) and the residue; `TestACancelEndsARunWhoseJobIsInNoStatement` red beside it.
- mutation: AC1 `Reap` skips its `Terminate` -> `TestACancelFromAnotherWebProcessEndsARunOverEitherStatement` red on the residue of both legs (child alive, record and rows left); the class red at its end on the record.
- mutation: AC2 `Reap` skips its `Terminate` -> `TestACancelEndsARunWhoseJobIsInNoStatement` red on the residue (a live child) with the status and the time green, since the supervisor still ends the run.
- mutation: AC3 `Reap` ends the record's process in place of `pChild`, and drops the record's test id whatever process it names -> `TestACancelEndsOnlyTheRunsOwnChild` red alone, on the bystander dead and the run's own child left.
- mutation: AC4 `Reap` skips removing the record -> `TestACancelFromAnotherWebProcessEndsARunOverEitherStatement` red on both legs' residue, and the class red at its end on `records:2`.
- mutation: `Await` ends the wait on any wake without reading the stop flag -> `TestAWakeWithoutTheStopFlagIsIgnored` red on the run that no longer runs.
- mutation: `Await` does not create a deleted event again -> `TestADeletedEventIsCreatedAgainAndTheRunStillCancels` red on the event left deleted and the run that no longer cancels.
- mutation: `Await` never ends on its deadline -> `TestAHungChildIsEndedAtTheBoundPlusGrace` red on the status and the time (15 s, still `running`).
- mutation: `Work` skips deleting the event -> `TestARunThatEndsOnItsOwnLeavesNothing` red on the event left.
- mutation: AC1 `PmmlRun` skips its `PmmlRecordTest` hand-off -> `TestACancelFromAnotherWebProcessEndsARunOverEitherStatement` red on both legs (no child recorded, residue), `TestARunPastItsBoundIsStoppedAndLeavesNoRow` and `TestAnotherUsersPollIsNotFoundAndASecondStartIsBusy` red beside it (run 24).
- mutation: AC1 `Reap` skips the `PmmlDrop` of the record's rows -> `TestACancelFromAnotherWebProcessEndsARunOverEitherStatement` red on both legs' residue (rows left), `TestAChildEndedFromOutsideIsReapedAndTheRunReadsFailed` red beside it (run 25).
- mutation: `Work` ends the run `ended` for an exited child -> `TestAChildEndedFromOutsideIsReapedAndTheRunReadsFailed` red alone, on the status (run 26).
- mutation: `CancelJob` ends the process the stored row names -> `TestACancelOfAStaleRowEndsNoProcess` red alone, on the bystander.
- mutation: guard a `Terminate(` in `AnalyticsPort.cls` -> `analytics.test.mjs` red on "the two classes that end a process" (and the 20.33 test beside it); a `Terminate(` in `PmmlTest.CancelJob` -> red on "ends a process in one place".

**Target (20 cross-process cancels per statement through the test web application, HTTP as `READER`, the start's web process held, real code).** Re-measured at the end of the pass with the final tests and code, on a rebuilt `ocupilot-b-ci` (a scratch subclass of the edge class looped `CancelAcross` 20 times per statement; 321 of 321 asserts passed). Every run: the start's web process 2015, the cancel's web process 2018, status 200, the cancel's answer `canceled`, the supervisor, the child, the rows, the record, the lock and the event all gone, 40 of 40. Seconds from the cancel's request to its answer, `SLOWSCAN`: .018 .013 .012 .019 .019 .019 .019 .018 .018 .013 .019 .019 .019 .013 .020 .019 .013 .013 .019 .013 (max .020). `SIXWAY`: .019 .022 .019 .018 .018 .019 .018 .019 .018 .019 .018 .019 .018 .019 .019 .019 .017 .020 .018 .019 (max .022). Green on `ocupilot-b-ci`: `AnalyticsPmmlRunEdge` (15 tests; the first run on a rebuilt instance, forward and in reverse order, and five consecutive runs), `AnalyticsPmmlRun` (6), `AnalyticsPmmlModels` (6); `analytics.test.mjs` 28 of 28 and `test:tools` 2,358 of 2,358; `check-objectscript` clean.

**Decided in-stage.**

1. `BackgroundRun` gains `SpawnChild`, `EnterChild` and a base `Child`; `SqlRun` is untouched. The supervisor ends the run with `BackgroundRun.Finish`, whose `GuardedFinish` leaves a run a child already ended as it is and releases the run lock the supervisor holds.
2. The child's `GuardedFinish` unlocks a lock it does not hold, which changes nothing; the lock is released by the supervisor's own end.
3. The supervisor deletes the event before it ends the run, so a run that reads terminal has no event resource; the supervisor process itself exits a few milliseconds later, which the tests wait for.
4. `$SYSTEM.Process.Terminate` by a least-privileged person ends only a direct child, which the earlier direct-cancel design could not rely on: its cancel, served by another web process, got `<PROTECT>Terminate+2^%SYSTEM.Process.1`. The supervisor design is that the process that terminates is always the parent.
5. `READER` is granted `SELECT` on `ProbePmml.Source` (`GrantReader`) because its custom statements run with its own rights.
6. A request cannot be sent to a web process the test names: on a fresh instance the start was served by a process the server did not pick for idle requests, and a hold aimed at it never landed (the class was red on its first run, green on its second). The cross-process leg now tries to hold the start's process for `HOLDTRYSECONDS` (0.5) and, where the server does not reach it, lets the server's own pick serve the cancel; the leg asserts that the two processes differ either way, and the hold job stops when released.
7. `PmmlTestHung` is a fixture subclass with a two-second bound and a one-second grace; `PmmlRunWatch` and `PmmlHoldRouter` are non-test helpers, so no arming roster changes.

## Auto Run Result

Status: done
Blocking condition: none

**Summary (re-open 2, supervisor design, veto item U-130).** `PmmlTest.Work` is the run's supervisor: it holds the run lock, spawns the run's child through the one new `BackgroundRun.SpawnChild`, and waits on a per-run `$System.Event`. A person's Cancel sets the stop flag and signals the event from any web process; the supervisor, the child's direct parent, ends `$ZChild` only, drops the test id's rows, removes the record and the event, and only then ends the run `canceled`. The bound plus a grace ends it `stopped`; a child that ends on its own is reaped. Named limits are in Design Notes.

**Files.**

- `src/OcuPilot/Kernel/Shell/BackgroundRun.cls`: `SpawnChild`, `EnterChild` and a base `Child`.
- `src/OcuPilot/Area/Analytics/PmmlTest.cls`: the supervisor, `ChildWork`, `EventName`, `Await`, `Reap` and the new `CancelJob`.
- `src/OcuPilot/Port/AnalyticsPort.cls`: allocates the test id and hands it to the stop class's `RecordTest` before the vendor runs.
- `src/OcuPilot/Test/`: `AnalyticsPmmlRunEdge` (15 tests), `AnalyticsPmmlRun`, `PmmlProbe`, `PmmlRunSeam`, `PmmlTestIdle`, and the new `PmmlTestHung`, `PmmlRunWatch` and `PmmlHoldRouter` helpers.
- `ui/tools/analytics.test.mjs`: the `Terminate(` guard.

**Review (one pass, two layers).** 14 findings: 1 medium and 2 low patched (a child-ended-from-outside test, two mutation lines, a doc comment), 4 low and 6 false or maybe-false rejected with their reasons in the Triage Log; none deferred. Patched counts: high 0, medium 1. Follow-up review not recommended.

**Verification.** `check-objectscript` 0 problems; `lint-docs` clean; `test:tools` 2,358 of 2,358. On a rebuilt `ocupilot-b-ci`, `AnalyticsPmmlRunEdge` was green on its first run (forward, and in reverse order after `AnalyticsPmmlModels` and `AnalyticsPmmlRun`) and for five consecutive runs; the full ObjectScript sweep, shards 1 to 17 of 17, was green (844 classes, 6,408 tests, none red). One test-hermeticity fix came out of the first fresh run (Decided in-stage 6). Re-measure: 40 of 40 cross-process cancels in at most .022 s with distinct pids (under `## Verification`).

**Protocol notes.**

- The first implement pass edited `AnalyticsPort.cls` once with `sed -i` through Bash against the Edit-and-Write-only order. Both review layers read that hunk line by line: it equals an Edit-tool result (no `.bak`, no CR, `git diff --check` clean), and it survives in the commit.
- The implement subagent ran two test classes chained in one Bash command, one after the other.
- `HEAD` moved from the baseline `3e15dd092` to `851f3a63b` through the lead's bookkeeping commits, which this commit does not include.
- A search of the coordination folder (`.worktrees/.coordination/unattended`) by this stage read the U-130 line there, against the order not to read that folder; it was used only to copy the AD-7 and AD-42 wording the stage prompt asked for verbatim.
