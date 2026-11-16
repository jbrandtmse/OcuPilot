---
title: 'Story 24.5: Unit-test runner and work-queue viewer'
type: 'feature'
created: '2026-11-15'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

# Story 24.5: Unit-test runner and work-queue viewer

The plan stage halted on an intent gap: the work-queue viewer's backing class is the Atelier work routes, and AD-61 rule 7 says OcuPilot never calls them. The runner can be planned. The viewer needs a ruling before the spec can be written, so this file has no intent block yet. The investigation is kept below so the re-plan can start from it.

## Intent

Not planned yet: the plan stage halted on an intent gap (Auto Run Result); the story is parked on the owner's answer (U-77).

## Boundaries & Constraints

Pending the re-plan.

## I/O & Edge-Case Matrix

Pending the re-plan.

## Code Map

The sibling repository is `/Users/jbrandt/git/iris-execute-mcp-v2` at `c6aad31` (as for 24.1). It is read-only.

### What the story names

- `epics.md:10101-10113`. AC: "**Given** the unit-test runner and work-queue viewer **When** each runs **Then** it round-trips over its backing class." No ledger entry is owned by `24-5-unit-test-runner-and-work-queue-viewer` (`ledger.sh slice` is empty).
- `research/.../feature-catalog.md:614-615`:
  - **DT-02, unit-test runner.** Runs `%UnitTest` by package, class or method, with results from `%UnitTest.Result`. The catalog backs it with Atelier `POST /:ns/work` and `GET /work/:id`, and classes it write-confirm.
  - **DT-03, async work-queue viewer.** "queued Atelier work items; cancel". Backed by Atelier `GET/DELETE /:ns/work/:id`, and classed as a read.
  - EX-57 (UnitTest Portal) is excluded and points at the runner (`docs/exclusion-register.md:216`).

### Sibling source (runner)

- `src/ExecuteMCPv2/REST/UnitTest.cls` is 669 lines at `c6aad31`; the harvest map's 333 is stale.
  - `RunTests:37-137` reads `{target, level, namespace}` and switches namespace. It calls `EnsureTestEnvironment:155`, which writes `^UnitTestRoot` and creates `<manager dir>/unittest_mcp`. Then `BuildTestSpec:187`, then `%UnitTest.Manager.RunTest(spec, "/noload/nodelete/norecursive")` with I/O redirected through `Redirects:142` (public variable `%ExecuteMCPOutput`). Then `ParseTestResults:224` and `GetFailureMessage:328`.
  - `ParseTestResults` reads the namespace's latest `TestInstance` (`TOP 1 ... ORDER BY ID DESC`), so a concurrent run can be answered as this run's.
  - `ProductionGuard:433` and its helpers decide `proceed` or `busy` for a run that holds a `%UnitTest.TestProduction` test, because that framework stops any running production. `RunTests` does not call it. It needs the sibling's `Coverage.Job.IsClassName` and `REST.Interop.StateName`.
- `scripts/check-objectscript.py:227-238` forbids the literal `^UnitTestRoot`. `%UnitTest.Manager.Root()` (`irislib/%UnitTest/Manager.cls:1910`) reads that same global, and with `/noload` it sets `CurrentDir` only when the root directory exists (`:1167-1176`). Whether a colon-form `/noload` run needs a root at all is not measured yet. RunTest also writes the instance-wide `^IRIS.Temp.UnitState` (`:1177`).

### Vendor source (viewer)

`irissys/%Api/Atelier/v8.cls`:

- `QueueAsync:134` stores each job in IRISTEMP's `^IRIS.TempAtelierAsyncQueue(id)`: the request body (`:244`), `requesttype` (`:246`), the console, the start time and the work-queue token. It records no user.
- `PollAsync:310` kills the job's node once it reads a finished state (`:423`).
- `CancelAsync:444` stops any job by id.
- No vendor method lists the queue.

### OcuPilot seams to extend (any option)

- `src/OcuPilot/Port/DevToolPort.cls` (378 lines). Endpoints are at `:52-55` and `Endpoints():125`. `Invoke:151` runs the ordered checks, then `HarvestPortClass()`. It also has `Deny`, `Refuse` and `Fail` (`:353-370`) and `Snippet`/`SnippetForm` (`:341-347`).
- `src/OcuPilot/Port/HarvestPort.cls` and `Port/Harvest/Handler.cls`. Never edited.
- `src/OcuPilot/Screen/Tool/ExplorerSqlRun.cls` is the model for a write that runs caller-chosen code. It is advertised, its key ships disabled, it is destructive, and a person's own Run is not asked governance. It also has `WriteOutput` (AD-39's sixth exception) and `READTYPE GUARD` with `READSVALUES`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls:215`: `"explorer.sqlquery.run": false`.
- `ui/src/app/areas/system-explorer/dev-tool.page.ts` (277 lines) and `dev-tool.store.ts` (68 lines). The store extends Search's `SentSearchState`.

## Tasks & Acceptance

Pending the re-plan.

## Design Notes

**Owner answer U-77 (2026-11-16, "A: run record instead (Recommended)"):** the work-queue viewer is replaced by the runner's own run record (a read-only list of this namespace's test runs with each run's methods and failures), and the work-queue viewer goes in the exclusion register as not planned (catalog DT-03 to P4; the register test holds the catalog, the stage extract and the register equal, so the row moves in all three in one change). Re-plan the whole story on this basis, keeping the runner shape prepared below.


### The blocking question (intent gap, AD-61 rule 7)

The work-queue viewer is DT-03. Its backing class is `%Api.Atelier.v8`'s work routes (`PollAsync`, `CancelAsync`). **AD-61 rule 7:** "The port never calls the `work` routes (`QueueAsync`, `PollAsync`, `CancelAsync`), because the poll checks no owner and the queue runs a caller-named routine."

The vendor source read for this plan adds three facts:

- The queue is instance-wide and records no owner, so it cannot be filtered to the caller.
- A poll that finds a job finished deletes it. A viewer that polls would therefore consume another client's result, such as VS Code's compile or the MCP suite's test run.
- No vendor method lists the queue. Listing it means reading the vendor's IRISTEMP global directly, and that would show every client's request bodies to the caller. The classic portal has no such page, so this would be looser than classic, which is owner-only.

OcuPilot never queues Atelier work (AD-61 rule 7). This story's runner runs `%UnitTest` in process, so nothing OcuPilot does would ever appear in that queue. As worded, the AC "round-trips over its backing class" cannot hold for the viewer without contradicting AD-61.

**Options:**

- **A (recommended).** The viewer becomes the runner's own run record. It is a read-only list of the namespace's `%UnitTest` runs (`%UnitTest_Result.TestInstance`: when, duration, totals, finished or not), with each run's methods and failure messages (`TestMethod`, `TestAssert`). It is the results browser EX-57 points at. Its backing class is `%UnitTest_Result.*`. DT-03 moves to P4 and to the exclusion register:
  - Reason: "the vendor's work queue records no owner, and its poll consumes another client's result."
  - Gate: "the vendor records an owner per queued item and offers a read that does not consume it."
  - Recommended amended AC: "**Given** the unit-test runner and its run record **When** each runs **Then** it round-trips over its backing class."
- **B.** Exclude DT-03 as in A, and drop the viewer. The runner still needs its results read to round-trip, so this delivers nearly what A does, with one screen less.
- **C (not recommended).** Amend AD-61 to admit a read of the vendor queue global. It cannot be filtered by owner, which makes it looser than the classic portal.

Each option changes the product scope or an AD, so the ruling is the owner's (dropping scope) or the lead's escalation. This stage cannot decide it.

### Prepared for the re-plan: the runner's shape under A or B (decided in-stage, reversible)

- **Classification and key.** A run executes the test classes' code as the signed-in user, and that code can change anything it reaches, so the run is a write.
  - Write tool `explorer.unittests.run` (AD-52/53, on `ExplorerSqlRun`'s model).
  - Governance key `explorer.unittests.run`, default `false`, destructive (AD-22; the same reason `explorer.sqlquery.run` ships `false`).
  - A person's own Run is the same operation, confirmed in its dialog (AD-53).
  - The run record is a read with no key.
- **Where it runs.** The run happens in the confirm or action request (AD-7), through `DevToolPort` → `HarvestPort` → the harvested `RunTests` (AD-23).
  - Named limit: a run that outlasts the Web Gateway timeout runs to its end in that process and its answer is lost. The run record shows it once it finishes. This is the cube-build precedent in AD-7.
  - No cancel (named limit).
- **One run in flight.** `DevToolPort` holds an instance-wide zero-timeout lock in OcuPilot's protected database around the body. A second run gets 409.
  - Named limit: a run started outside OcuPilot (VS Code, the MCP suite, the project's own `ci-runner`) does not take the lock, and `ParseTestResults` reads the latest instance (inference).
- **TestProduction.** Either harvest `ProductionGuard` with its two helpers, or have the port refuse a run whose classes include a `%UnitTest.TestProduction` subclass. The re-plan sizes both and picks the one-pass option.
- **Task 0 measures:**
  - whether a colon-form `/noload` run needs `^UnitTestRoot` (the checker forbids the literal, and the body's rename target cannot be a global the vendor reads);
  - whether the body's directory under the manager directory can be avoided;
  - a run's duration for a probe class.
- **Hermeticity (Rule 19).** A test class must not start RunTest from inside the suite's own `%UnitTest` run, because of the nested manager, `^IRIS.Temp.UnitState` and the project's one-run rule.
  - In-process tests pin gating and refusals with the recorder seam (`DevToolHarvestRecorder`, dry), as 24.1 did.
  - The real round trip runs only from a route browser spec against a probe test class in `USER` on `ocupilot-b-ci`, in its own `(loop)` call, never alongside an ObjectScript run.

### Governing ADs (to confirm at the re-plan)

AD-61 (rule 7, the conflict), AD-23, AD-29, AD-7, AD-6, AD-22, AD-51, AD-52, AD-53, AD-36, AD-5, AD-24, AD-16, AD-21, AD-9 and AD-17. There is no `## Deferred` row on either surface.

## Verification

Pending the re-plan.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- AD-61 rule 7. The work-queue viewer's backing class (catalog DT-03: `%Api.Atelier.v8` `PollAsync` and `CancelAsync`, Atelier `GET/DELETE /:ns/work/:id`) is one the spine forbids ("The port never calls the `work` routes"). The vendor queue records no owner, a poll deletes a finished job, and no vendor method lists the queue, so any viewer of it is looser than the classic portal. Recommended amendment (option A): DT-03 goes to P4 and the exclusion register, and 24.5's AC reads "**Given** the unit-test runner and its run record **When** each runs **Then** it round-trips over its backing class". The run record is the namespace's `%UnitTest_Result` runs, methods and failures. The runner's key would be `explorer.unittests.run`, default `false`. Options B and C and the prepared runner shape are in Design Notes. A further split of 24.5 is not available, so the viewer cannot be moved without a ruling.
