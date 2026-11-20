---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 2b: a PMML test Cancel that lands)'
type: 'bugfix'
created: '2026-11-20'
status: 'ready-for-dev'
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

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):**

- AD-7: the run's kind and its never-mutates scope.
- AD-8: the person's own rights end their own job, measured; no escalation.
- AD-9: the cancel is made from no escalated frame.
- AD-10: this is not a write-path terminate and not a tool; the Process screen's arm is untouched.
- AD-16: the record hook runs unswitched.
- AD-41 and AD-42: the caps and the four spawn sites are unchanged.
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

1. **(b), with `ENDSECONDS` 2**, which is the target. A job that has not ended by then keeps Batch 2's flag path.
2. **The record lives in IRISTEMP, keyed by run key**, because `SqlRun` is out of scope and the canceller needs the id. It gives no new reach: IRISTEMP is writable by any code-running user, as the vendor's result rows are. A forged record needs the run key, which only the owner holds. It is used only when its pid equals the store's `JobId`, and its pid is never a target.
3. **The cancel's answer waits for its drop.** A late cancel of a long run therefore answers in seconds (measured above), which is a named limit. Moving the drop out of the request would need a fifth spawn site.
4. **The pid window.** Between `GuardedCancel`'s lock check and `Terminate`, the job may end and its pid be reused. That is microseconds (inference, not measured), and the vendor refuses another user's process, so at worst it reaches a process of the same person (named limit).
5. **`Seed` moves to `PmmlProbe`** (Rule 2), so the edge class need not call another test class.

**Veto items (unattended):**

- The record `^IRIS.Temp.OcuPilotPmmlRun` (a change to how run state is kept).
- The proposed AD-7 wording.

**Proposed AD-7 wording** (it replaces Batch 2's proposed line):

> "The PMML model tester's test (Story 24.14) is the background run's third kind, a person's read-kind run. It runs the vendor's `%RunModel`, `%RunModelFromPMMLRows` or `%RunModelFromSQL` in the job, which writes the vendor's result rows and test-id counter in IRISTEMP, and it drops its own rows with an embedded `DELETE` bound to its test id on every path it ends itself. Its owner's cancel ends the run's own job, the process the run's row records while that process holds the run's lock, never a process found by its statement and never another user's, which the vendor refuses; it then drops that test id's rows. A job the cancel could not end runs to the vendor's end and ends `canceled`. An SQL data source runs only once SQL query's classification types it a query. The model's generated code runs with the person's rights (named limit)."

**Proposed strings:** none.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only; the changed classes loaded with their subclasses recompiled):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsPmmlRunEdge`, then the same for `AnalyticsPmmlRun` and `AnalyticsPmmlModels`. Expected: green.
- `(loop)` `cd ui && npm run test:tools`. Expected: green.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The browser suite is left to CI (Rule 29); this batch changes no client file.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- **Target evidence.** `TestACancelEndsARunOverEitherStatement` run 20 times on the rebuilt throwaway, one call each. Record each run's cancel seconds per statement under Design Notes.

**Shared surfaces:** `PmmlProbe.Left` (read by every PMML class's `OnAfterAllTests`), the `analytics.test.mjs` guards, and the `CancelJob` hook.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order. It leaves no row, no record and no job.

**Mutations (one per AC, recorded here as `mutation:` lines by the implement stage):**

- AC1: `CancelJob` skips its `Terminate`.
- AC2: the same, on the idle leg.
- AC3: `CancelJob` ends the record's pid in place of `pJobId`, then drops the record's id whatever pid it names.
- AC4: `Work` skips forgetting the record, so `Left` reddens.
- Guard: a second `Terminate(` in `AnalyticsPort.cls`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
