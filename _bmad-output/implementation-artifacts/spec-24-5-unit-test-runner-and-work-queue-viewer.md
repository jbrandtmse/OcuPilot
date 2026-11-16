---
title: 'Story 24.5: Unit-test runner and its run record'
type: 'feature'
created: '2026-11-16'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot run a namespace's `%UnitTest` classes or show what earlier runs recorded (catalog DT-02). The work-queue viewer (DT-03) cannot be built: the vendor queue records no owner, a poll consumes another client's result, and nothing lists the queue (owner answer U-77).

**Approach:** A destructive write, `explorer.unittests.run`, runs a package, a class or one method in process through `DevToolPort` (AD-23). Its key ships `false`. Two read-only screens show the run record from `%UnitTest_Result`: the namespace's runs, and one run's methods with their failure messages. DT-03 moves to the exclusion register, the catalog and the stage extract in one change, as 24.8 moved DT-11.

## Boundaries & Constraints

**Always:**

- `DevToolPort` checks everything before any body runs or any root is touched, in this order:
  1. `AtelierPort.Pairs()`.
  2. The namespace's shape and pairs. For a run these are `AtelierPort.WritePairs(ns)`; for a record read, `NamespacePairs(ns)`.
  3. The target's shape and level.
  4. The `OcuPilot` stem refusal.
  5. The target's resolution in the namespace, through system classes only, with the namespace saved and restored.
  6. The class cap.
  7. The production-test refusal.
  8. The one-run lock.
- A run uses the vendor's colon form with `/noload/nodelete/norecursive`.
- When the namespace's root global does not name an existing directory, it is set to `$System.Util.ManagerDirectory()` for the run. It is put back on every path: restored if it had a value, killed if it had none.
- Both reads are capped and report truncation (AD-36). A screen and its read tool share one read (AD-5).
- Harvested methods are identical to the sibling's at `c6aad31` after the rename table.

**Never:**

- No Atelier `work` route (AD-61 rule 7).
- No caller value in SQL text; no path (AD-21).
- No edit to `HarvestPort.cls` or `Harvest/Handler.cls`.
- No directory is created.
- No `OcuPilot.*` class is named while switched.
- A person's own Run is never asked governance (AD-22, AD-53).
- No ObjectScript test starts a `%UnitTest` run.

## I/O & Edge-Case Matrix

Probe classes live in `USER` on `ocupilot-b-ci`: `OcuProbe245.Mixed` has one passing and one failing method, and `OcuProbe245.Prod` extends `%UnitTest.TestProduction`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Run class | `OcuProbe245.Mixed`, level class, confirmed | A new run is recorded. The output is `{run, passed: 1, failed: 1}`. The root is unchanged afterward. | none |
| Run method | `OcuProbe245.Mixed:TestPasses`, level method | One method runs and passes. | none |
| Run package | `OcuProbe245`, level package | Both `Mixed` methods run. `Prod` is refused, see Production. | none |
| Record | after Run class | The runs list shows that run, newest first. Its methods list has two rows, and the failed row's `Failure` is the assertion's description. | none |
| Production | a target that resolves `OcuProbe245.Prod` | 409 `EXPLORER.UNITTEST.PRODUCTION`. Nothing runs. | not logged |
| Not found | missing class, a class that is not a test, a missing method, or a package with no test class | 404 `EXPLORER.UNITTEST.NOTFOUND` | not logged |
| Too many | a package over `MaxTestClasses()` (the fixture sets it to 1) | 400 `EXPLORER.UNITTEST.TOOMANY`, with `detail.count` and `detail.max` | not logged |
| Bad shape | `%Library`, `a..b`, `A:B:C`, `*`, or a level outside the three | 400 `PORT.VALIDATION` | not logged |
| Own code | any target whose first segment is `ocupilot`, in any case | 400 `EXPLORER.UNITTEST.OWNCODE` | not logged |
| Busy | the run lock is already held | 409 `EXPLORER.UNITTEST.BUSY` | not logged |
| Gate | no `%Development:USE`, or no WRITE on the routines database | 403 `AUTH.NOPRIVILEGE` with `detail.failedPair` | not logged |
| No result | the run lands no new instance | 500 `EXPLORER.UNITTEST.NORESULT` | logged |
| Agent | `explorer.unittests.run` with its key `false` | `GOVERNANCE.DISABLED`. With the key on, it mints; Confirm runs as Run class does. | structured |

In every refusal row the recorder records no body call, and the root global and the lock are as they were.

</intent-contract>

## Code Map

### Sibling and vendor

- The sibling repository is `/Users/jbrandt/git/iris-execute-mcp-v2` at `c6aad31`, read-only. `src/ExecuteMCPv2/REST/UnitTest.cls` has 668 lines; the harvest map's 333 is stale. Methods: `BuildTestSpec:186`, `ParseTestResults:224`, `GetFailureMessage:328`, `RunTests:37`, `Redirects:142`, `EnsureTestEnvironment:155`.
  - `RunTests` is **not taken**. It redirects output to `"^"_$ZNAME`. While switched to `USER`, a label call into an OcuPilot routine raises `<NOROUTINE>` (measured on `ocupilot-b-ci`). `EnsureTestEnvironment` writes the root global permanently and creates `<mgr>/unittest_mcp`.
- `irislib/%UnitTest/Manager.cls`:
  - `Root():1910` reads the root global. With nothing set it falls back to a source directory this image lacks.
  - Under `/norecursive`, a root that is not an existing directory skips the suite (`:620-626`).
  - `realRunTestSuites:487` kills `^IRIS.Temp.UnitState`, which is instance-wide, and resets the instance's SQL statistics flags (`:497`, `:738-741`).
  - `ReserveResultId:2833` takes `$i(^UnitTest.Result)`.
- `scripts/ci-unit-test.sh:95-118` is the project's own colon-form run. It sets the root to the manager directory and checks that a run "landed" from the newest index.
- `irislib/%UnitTest/Result/*.cls`: `TestInstance` is IdKey `InstanceIndex` and has `DateTime` and `Duration`. Below it are children `TestSuite` → `TestCase` → `TestMethod` (`Status` 0/1/2) → `TestAssert` (`Description`, `Status`). Owner is `%Developer`.

### OcuPilot seams

- `src/OcuPilot/Port/DevToolPort.cls` (509 lines). Its parts:
  - the header's ordered gate;
  - the `ENDPOINT*` parameters and `Endpoints():151`;
  - `Invoke:183-283`;
  - `RunBody`, `CountDocuments` (the switch model);
  - `SnippetForm` and `Snippet` (:471-482, empty today; AD-59 needs them for a write);
  - `Deny`, `Refuse` and `Fail`.
- `src/OcuPilot/Port/AtelierPort.cls` -- `Pairs():755`, `NamespacePairs():767`, `WritePairs():788`, `NAMESPACEPATTERN`.
- `src/OcuPilot/Port/HarvestPort.cls` -- `Invoke`. It captures the body's output with `%SYS.Capture`, and the body renders once.
- `src/OcuPilot/Port/Harvest/EnvSync.cls` and `Loc.cls` -- the harvested-file and rename-table model (24.1).
- `src/OcuPilot/Screen/Tool/AnalyticsCubeBuild.cls` and `AnalyticsAction.cls` -- the write model.
  - Parameters: `SCREENACTIONS`, `WRITETYPE`, `DESTRUCTIVE 1`, `READTYPE STATE`, `SENDSBODY 0`, `FINGERPRINTSUBJECT`, `PRECONDITIONFIELD`/`CODES` (:14-32).
  - Methods: `PortQuery:146`, `StateDiff:160`, `WriteOutput:195`.
- `src/OcuPilot/Screen/Tool/ExplorerSqlRun.cls` -- `IDARGUMENT` with a literal target (:80) and `ScreenActionDelta:151`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls:215` -- next to `"explorer.sqlquery.run": false`.
- `src/OcuPilot/Api/AtelierError.cls` -- the `EXPLORER.*` codes.
- Screens:
  - `src/OcuPilot/Screen/Descriptor/ExplorerNamespaceDiff.cls` -- the descriptor model.
  - `InteropQueueList.cls` and `InteropQueueMessageList.cls` -- the parent and child list model (`parentScope`, `id` single, one criterion, `rowTarget`).
  - `src/OcuPilot/Screen/Read.cls` (the `devtool` branch) and `Screen/Registry.cls:1438-1455` -- admit devtool endpoints from `Endpoints()`.
- Client:
  - `ui/src/app/areas/system-explorer/dev-tool.page.ts` (form :62-100, read :150, search :301) and `dev-tool.store.ts`.
  - `ui/src/app/areas/system-explorer/sql-query.page.ts:124,158-165` and `sql-query.store.ts:261-290` -- the Run, warning dialog and `sendFor` model.
  - `ui/src/app/shell/screen-outlet.ts:222-224`, `shell/data-table.ts` (`rowTarget`) and `core/navigation.ts:343-363` (child lists).
- Tests:
  - `Test/DevToolPortFixture.cls`, `DevToolHarvestRecorder.cls` and `DevToolProbe.cls`.
  - `Test/AnalyticsCubeActions.cls` -- the write-path test model.
  - `ui/browser/namespace-diff.browser-spec.mjs` -- the `runIris` and throwaway guard model.
  - `ui/browser/system-explorer-sql-query.browser-spec.mjs:181-200` -- clicking the confirm dialog.
- Rosters, with each count re-derived:
  - `Test/ReadTool.cls:93-94` (literal 462 and names)
  - `Test/ExplorerDescriptor.cls:161,162,171`
  - `Test/GovernanceBaseline.cls:15` and `Test/Governance.cls:33`
  - `Test/SurfaceCoverage.cls` (a tool row and two screen rows)
  - `Test/ToolRoundTrip.cls:104`, `Test/DraftRegistry.cls`, `Test/PortGate.cls:29` (a `<stub>` row for each new Harvest class)
  - `Test/DeveloperFloor.cls`, `Navigation`, `Descriptor`, `ReadDescriptions`, `ClassicPageGate`, `ToolEmit`, `Wire`, `WireAreaAnyScreen`
  - `ui/tools/navigation.test.mjs:386-395` and `screen-mirror.test.mjs`
- Register sources: listed under Tasks, batch 3. 24.8 is the precedent.

## Tasks & Acceptance

**Execution, batch 1 (server):**

- **Task 0, on `ocupilot-b-ci`, before any code.** Run one `%UnitTest` run at a time, never beside another test call. Record each result under Design Notes.
  1. A colon-form `/noload/nodelete/norecursive` run in `USER`, with the root set to the manager directory, runs `OcuProbe245.Mixed`. Afterwards the manager directory's listing is unchanged.
  2. That run, under `HarvestPort`'s capture from `HSCUSTOM` and switched to `USER`, keeps the capture and answers. If not, stop and report.
  3. A least-privileged principal can read `%UnitTest_Result` with privilege checks on. That principal holds `%Development:USE`, the `USER` pairs and WRITE on the routines database. If it is refused -99, record it; the reads then use `%ExecDirectNoPriv` after the gate (AD-29's `LogSourcePort` precedent).
  4. The same principal can take `Lock +^CacheTemp.OcuPilotUnitTestRun:0`.
  5. How long the probe run takes.
- `src/OcuPilot/Port/Harvest/UnitTest.cls` -- new, extends `OcuPilot.Port.Harvest.Handler`. It holds `BuildTestSpec`, `ParseTestResults` and `GetFailureMessage`, changed only by the rename table.
- `src/OcuPilot/Port/Harvest/UnitTestRun.cls` -- new, extends `UnitTest`. Its one handler, `Run()`:
  - reads the port's `target`, `level` and `namespace`;
  - switches with `..SwitchNamespace`;
  - takes the newest `^UnitTest.Result` index;
  - builds the spec with `..BuildTestSpec`, then calls `##class(%UnitTest.Manager).RunTest(spec, "/noload/nodelete/norecursive")`;
  - when no newer index landed, fails with `NORESULT`;
  - otherwise reads `..ParseTestResults(filter)`, adds `run`, restores the namespace and renders once.
- `src/OcuPilot/Port/DevToolPort.cls`:
  - Add endpoints `UnitTestRun` (`STATE`, `RUN`), `UnitTestRuns` (`LIST`) and `UnitTestMethods` (`LIST`, with key `run`).
  - Add the run steps in the Always order, plus `MaxTestClasses()` (50) and `LockName`.
  - The root set and restore is the one place the root global is named.
  - The `STATE` read answers `{Namespace, Tests, Level, Classes, Production, Busy}`.
  - The record reads use fixed statements with bound values. Runs come newest first, each with `Run`, `Started`, `Duration`, `Methods`, `Passed`, `Failed` and `Finished`. Methods carry `Class`, `Method`, `Result`, `Duration` and `Failure`; `Failure` holds the failed assertions' descriptions joined with "; " and cut at 2,000 characters.
  - Fill `Snippet` and `SnippetForm` for `UnitTestRun`/`RUN`: two `objectscript` lines with literal values, as `AnalyticsPort` writes them.
  - Update the header.
- `src/OcuPilot/Screen/Tool/ExplorerUnitTestRun.cls` -- new, on the cube build's model.
  - Tool `explorer.unittests.run`, `PORTCLASS DevToolPort`, `READTYPE STATE`, `WRITETYPE RUN`, `DESTRUCTIVE 1`, `SENDSBODY 0`, `READSVALUES 1`.
  - `SCREENACTIONS run`, `SCREENVALUES run=tests:level`.
  - `FINGERPRINTSUBJECT Namespace,Tests,Level,Classes`; precondition field `Busy`, with `Production` refused.
  - `WriteOutput` answers `{run, passed, failed}`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- `"explorer.unittests.run": false`, add-only.
- `src/OcuPilot/Api/AtelierError.cls` -- the six `EXPLORER.UNITTEST.*` codes and their ruled reasons.
- `src/OcuPilot/Screen/Descriptor/ExplorerUnitTests.cls` -- new.
  - Route `system-explorer/unit-tests`, side-bar position 17.
  - Criteria `tests` (text, 256) and `level` (choice `package`/`class`/`method`, default `class`).
  - Read `UnitTestRuns`; primary action `run`; `rowTarget` to the methods list.
  - `toolIdentifier` `explorer.unittests`, `classicPage` `""`.
- `src/OcuPilot/Screen/Descriptor/ExplorerUnitTestRun.cls` -- new. Route `system-explorer/unit-tests/methods`, position 0, `parentScope` the runs route, `id` single, one criterion `run`, read `UnitTestMethods`, `toolIdentifier` `explorer.unittestrun`.
- `src/OcuPilot/Screen/Titles.cls` -- regenerated. Every roster in the Code Map gets this story's members and its counts re-derived.
- `scripts/check-objectscript.py` and `scripts/test_check_objectscript.py`:
  - Admit the root-global token in `src/OcuPilot/Port/DevToolPort.cls` only, with a docstring line saying it is the vendor's root, set and restored by the runner.
  - Add one harness case for the admitted file and one for any other file.
- `src/OcuPilot/Test/UnitTestRunGate.cls` -- new, under 500 lines. It covers every refusal row and the dry run path through `DevToolHarvestRecorder`, which records `UnitTestRun.Run` with only the port's keys. It also covers the tool's mint, the key `false` refusal, and the root and lock restored on every path. The fixture overrides `MaxTestClasses`.
- `src/OcuPilot/Test/UnitTestRecord.cls` -- new. It builds its own `TestInstance` tree in `USER` with `%UnitTest.Result.*` objects, under `$Increment(^UnitTest.Result)`, and deletes it in `OnAfterOneTest`. It asserts both reads, the cap and the truncation, and the failure text.
- `src/OcuPilot/Test/DevToolProbe.cls` -- add `MakeTests` and `RemoveTests` for the `OcuProbe245` classes, plus `RemoveRun(index)`.

**Execution, batch 2 (client):**

- `ui/src/app/areas/system-explorer/dev-tool.store.ts` and `dev-tool.page.ts` -- add a run mode, used when the descriptor declares the primary action `run`:
  - The form takes `tests` and `level` and shows a Run button.
  - Run opens `app-warning-dialog` with the ruled consequence and sends `sendFor(descriptor, 'run', ...)`.
  - The page reads the runs list on arrival and again after the change event.
  - The table honors `rowTarget`.
  - Add one `.spec.ts` case.
- `ui/src/app/shell/screen-outlet.ts` -- add a loader line.
- `ui/src/app/core/strings.ts`, `core/screens.generated.ts` (`node tools/screen-mirror.mjs`) and EXPERIENCE.md's Fixed strings -- add-only.
- `ui/browser/unit-tests.browser-spec.mjs` -- new.
  - `before` asserts the throwaway and calls `MakeTests` through `runIris`.
  - It runs `OcuProbe245.Mixed` through the dialog, then opens the new run and sees both methods and the failure text.
  - The `Prod` target shows the production reason.
  - `after` calls `RemoveTests` and `RemoveRun`.

**Execution, batch 3 (register and planning documents):** apply bottom-up, 24.8's edit list applied to DT-03.

- `docs/exclusion-register.md` -- after the DT-11 row (:230), add the DT-03 row with gate kind `dependency`:
  - Reason: "The instance-wide work queue records no owner, a poll of an item consumes the result another client is waiting for, and the instance offers no way to list the queue. The unit-test runner keeps its own run record instead."
  - Gate: "The vendor records an owner per queued item and offers a read that does not consume it."
  - How to tell it has cleared: "The vendor's work queue records an owner per item and offers a read that leaves the item for its owner."
- `feature-catalog.md`:
  - :615 DT-03 becomes P4, with Evidence "— excluded: ... (owner answer U-77, 2026-11-16)".
  - :36 becomes `| 0 | 0 | 1 | 8 | 3 | 12 |` and :38 `**162** | **58**`.
  - Add the judgment call after :686.
  - :454's "(see DT-03 runner)" becomes "(see DT-02 runner)".
- `extract-stages.md` -- delete :600 and add DT-03 to Stage 5's last group. Then re-derive:
  - :17, :28-29 and :369;
  - :371, dropping "work-queue viewer";
  - :595, :642, :643, :647, :736, :772, :774, :826, :957, :966 and :967;
  - :734's pointer becomes DT-02.
- `epics.md:353-354` becomes `163 | 59 / 78 / 26` and `58 | 12 / 30 / 16`.
- `extract-catalog.md` -- :429 and :431, and the judgment call after :408.
- `harvest/iris-execute-mcp-v2.md:36` -- 333 becomes 668.
- `harvest/HARVEST-PLAN.md:106` -- `^UnitTestRoot` is the vendor's own root global. It is never renamed, and only `DevToolPort` names it.

**Acceptance Criteria:**

- **AC1.** Given the unit-test runner, when a person runs a class, a method or a package and confirms, then it round-trips over `%UnitTest.Manager`. That covers matrix rows Run class, Run method and Run package, observed in the browser on `ocupilot-b-ci`, and the root global ends as it began.
- **AC2.** Given the run record, when it is read after a run, then its two reads round-trip over `%UnitTest_Result` (matrix row Record), through the screen route and through each read tool.
- **AC3.** Given any refusal row, when the run is asked, then it answers that row's status and code, the recorder recorded no call, and the root global and the lock are unchanged.
- **AC4 (Integration).** Given `explorer.unittests.run` with its key `false`, when the agent calls it, then it answers `GOVERNANCE.DISABLED`. With the key on, Confirm runs the probe class and the record shows the run.
- **AC5.** Given the harvested methods, when they are compared with the sibling's after the rename table, then they are identical, and `uv run scripts/check-objectscript.py` passes.
- **AC6.** Given the work-queue viewer, when this story lands, then the register holds DT-03 as not planned with the U-77 reason, the catalog marks it P4, and `exclusion-register.test.mjs` passes.

## Spec Change Log

## Review Triage Log

## Design Notes

### The blocking question (intent gap, AD-10, same family as U-78)

A run executes the test classes' own code with the signed-in person's rights. That is the question 24.6 raised for the consoles:

- every arm of AD-10's prohibited set is reachable;
- OcuPilot's protected state is reachable through the guarded storage methods (DW-2634, with the owner);
- nothing on the write path can see what the code does.

The owner answered U-78 with "C: fix U-79 first, then A": the consoles wait for the DW-2634 fix on feature, then come in as a named AD-10 exception. Story 24.7 was parked on that answer as "runs arbitrary code". U-77 settled the work-queue viewer only, and the AD-10 question was never asked for the runner.

The spine's nearest precedent is AD-10's SQL-console gap, "a procedure's or function's own code" (Story 19.6): compiled code that a person's request runs. A test class is the same shape. Through OcuPilot's own class editor and SQL console, a `%Development` holder with WRITE on a routines database can already run code they compiled (inference).

- **A (recommended):** apply U-78's answer. 24.5 waits for the DW-2634 fix on feature, then is built as planned here. Proposed AD-10 sentence: "**The unit-test runner (Story 24.5)**: a run executes the test classes' own code with the person's rights, as the vendor's `%UnitTest.Manager` does. Named gap: a test class's own code. The runner refuses a test in an `OcuPilot` package as a screen, not a prohibition."
- **B:** build now, with the same AD-10 sentence and no wait, on the SQL-console precedent above. The key still ships `false`.
- **C (not recommended, owner-only):** exclude DT-02 as well. The run record alone ships.

Changing an AD and weakening AD-10's "whatever the caller" both sit in the veto window. Waiting on DW-2634 is the owner's own precedent. This stage cannot decide either.

### Governing ADs

- AD-10 (the question)
- AD-61, including rule 7: never the `work` routes; the gate pairs
- AD-23 and AD-29: `DevToolPort` is the gate
- AD-7: the run happens in the confirm or action request
- AD-22: the key ships `false` and is destructive; a person's Run is not asked
- AD-51, AD-52, AD-53, AD-6, AD-58, AD-59 and AD-14: the write model
- AD-36, AD-5 and AD-24: the reads
- AD-16: switches save and restore
- AD-21: bound values only
- AD-39: the output is three numbers and no vendor text; failure text arrives through the record read, which is data
- AD-17: test classes compile only on a throwaway

### Decided in-stage (reversible)

- **The run handler is OcuPilot's.** `Run()` is OcuPilot code, not the sibling's `RunTests`. `RunTests` redirects output to its own routine, and from `USER` that raises `<NOROUTINE>` (measured). It also writes the root and a directory permanently. `Run()` keeps the body's call order and the harvested helpers. This is a deliberate copy (Rule 31).
- **The root is set and restored.** The root global is set for the run and put back afterward, following `ci-unit-test.sh`. The checker admits it in one file instead of having the name assembled at runtime.
- **Production tests are refused.** `%UnitTest.TestProduction` stops any running production. Harvesting `ProductionGuard` would need two more sibling helpers.
- **The gate is `AtelierPort.WritePairs`,** as for every Atelier write. A `<PROTECT>` inside a run answers 403 through `HarvestPort`.
- **The lock lives in IRISTEMP:** `^CacheTemp.OcuPilotUnitTestRun`, so that `Kernel.State`'s guarded methods (DW-2634) gain no new member. Named limit: a run started outside OcuPilot takes no lock, and `ParseTestResults` reads the newest instance (inference).
- **Named limits, matching AD-7's cube build.** There is no cancel. A run that outlasts the gateway timeout finishes, but its answer is lost; the record shows it. Every run resets the instance's SQL statistics flags (vendor).
- **The agent's tool is advertised,** like `explorer.sqlquery.run`. A target in `OcuPilot` is refused as a screen, not a prohibition.

### Integration ACs, Consumed-by and Consumes

- **Integration AC:** AC4.
- **Consumed-by:** 24.20's undo, which takes no run because a run is not revertible (inference).
- **Consumes:** 24.1's `DevToolPort`, its recorder and its probe; 24.8's page; `AtelierPort`'s pairs; the cube build's write base.

### Contended files (more than appending; check `origin/OCU-1-epic21` at integrate-forward)

- `DevToolPort.cls`: the header and `Invoke`.
- `check-objectscript.py` and its harness.
- `dev-tool.page.ts` and `dev-tool.store.ts`.
- `HARVEST-PLAN.md:106`: a cell edit.
- `iris-execute-mcp-v2.md:36`.
- The count lines in the catalog, the extract, `epics.md` and `extract-catalog.md`. Epic 21's 21.12 re-derives these same totals. Re-count the rows after the union and never add the two deltas.
- `ReadTool`'s literal count.

### Governance keys

`explorer.unittests.run`, default `false`, destructive.

### Proposed strings (veto item)

- Titles: "Unit tests" and "Unit test run". Button: "Run tests".
- Criterion labels: "Tests" and "Run". The "Tests" hint reads "A package, a class, or Class:Method". The "Run" choices are "Package", "Class" and "Method".
- Dialog title: "Run these tests?" Consequence: "The tests run as you, with your rights, in this namespace. OcuPilot cannot check what their code changes."
- Reasons:
  - "Name a package, a class, or Class:Method with letters, digits and dots."
  - "No compiled test class matches in this namespace."
  - "This package holds more test classes than one run takes."
  - "These tests include a production test, which stops the running production. OcuPilot does not run production tests."
  - "Another unit-test run is in progress. Try again when it ends."
  - "OcuPilot does not run its own tests."
  - "The run recorded no results."
- Columns:
  - Runs: Run, Started, Duration, Methods, Passed, Failed.
  - Methods: Class, Method, Result, Duration, Failure.
  - Result values: "Passed", "Failed" and "Skipped".
- Empty states: "No unit-test runs are recorded in this namespace." Agent empty state: "run unit tests".

### Proposed spine amendments (for the owner's attended architecture update)

- The AD-10 sentence in the blocking question.
- Add `DevToolPort` to AD-29's Binds. It is already pending from 24.1.
- Add to AD-61: "a later call Atelier cannot carry: Story 24.5's run, in process."
- AD-7: the run is cost-named like the cube build, including the SQL statistics flag reset.

## Verification

**Shared surfaces:** `USER`'s `^UnitTest.Result` and root global, System Explorer side-bar 17, the read-tool and write-tool rosters, the governance baseline, and the devtool endpoint refusal sentence. Every test added or changed passes on a fresh environment, in either order.

**Kept apart from the suite's own runs.** No ObjectScript test starts a run. The record test writes rows in `USER` only; `ci-unit-test.sh` reads `HSCUSTOM`'s newest index. The browser spec's run is a `%UnitTest` run, so it runs in its own `(loop)` call, never beside a `ci-runner` call. In CI each browser leg has its own throwaway.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.UnitTestRunGate --class OcuPilot.Test.UnitTestRecord` -- expected: all pass. Run each roster class it touches the same way, keeping a call under about 170 s.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/unit-tests.browser-spec.mjs` -- expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components` -- expected: pass, `exclusion-register.test.mjs` included.
- `(loop)` `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` -- expected: clean.
- `(once)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, for k = 1..17, one call each -- expected: green. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC:**

- AC1: skip the root restore → the browser spec's root assertion goes red.
- AC2: drop the `Status=0` filter on `Failure` → `UnitTestRecord`'s failure-text test goes red.
- AC3: move the production check after `RunBody` → `UnitTestRunGate`'s Production test goes red.
- AC4: set the baseline key to `true` → `GovernanceBaseline` goes red.
- AC5: change one harvested line → the harvested-identity test goes red.
- AC6: leave DT-03 at P3 → `exclusion-register.test.mjs` goes red.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- AD-10 (the U-78 family). The unit-test runner executes the test classes' own code with the person's rights, so every arm of AD-10's prohibited set is reachable, and OcuPilot's protected state is reachable through the guarded storage methods (DW-2634, with the owner). This is the same question the owner answered for the consoles with U-78 ("C: fix U-79 first, then A"); U-77 settled only the work-queue viewer. Recommended (A): apply U-78's answer -- 24.5 waits for the DW-2634 fix on feature, then is built as this spec plans, with the AD-10 named gap "a test class's own code" proposed in Design Notes (the SQL console's procedure gap is the precedent). B: build now with the same named gap. C: exclude DT-02 too (owner-only). The rest of the spec is complete. Once ruled, it needs only the status flip and the spine sentence: the runner shape, the run record, the DT-03 register move, the resolved open items (root set and restored, production tests refused, the stale harvest size 333 to 668) and the verification plan.
