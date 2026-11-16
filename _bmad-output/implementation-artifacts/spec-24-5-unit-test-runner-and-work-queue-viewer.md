---
title: 'Story 24.5: Unit-test runner and its run record'
type: 'feature'
created: '2026-11-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot run a namespace's `%UnitTest` classes, and it cannot show what earlier runs recorded (catalog DT-02). The work-queue viewer (DT-03) cannot be built. The vendor's queue records no owner, a poll consumes another client's result, and nothing lists the queue (owner answer U-77).

**Approach:** The runner is a person's own action, built under a named AD-10 exception (owner answer U-86): it is off by default, people only, and every run is confirmed with its consequence named.

- **The write.** `explorer.unittests.run` runs a package, a class or one method in process through `DevToolPort` (AD-23).
- **People only.** The tool is unadvertised (AD-53).
- **Off by default.** The tool declares the new write-base gate `PERSONGATE`. The screen action route then asks the tool's governance key, which ships `false`; an OcuPilot administrator switches it on in Governance policy (AD-22's allow-list precedent).
- **The record.** Two read-only screens and their read tools show the run record from `%UnitTest_Result`: the namespace's runs, and one run's methods.
- **DT-03** moves to the exclusion register, as 24.8 moved DT-11.

## Boundaries & Constraints

**Always:**

- A person's Run passes through `POST /screens/:screen/action` in this order: the screen's pairs, the governance key (403 `EXPLORER.UNITTEST.OFF` while it is off), the hold, the fresh read and the write. The same order applies to the route's preview paths (`/impact`, `/dryrun`).
- `DevToolPort` then checks everything before any body runs or any root is touched, in this order:
  1. `AtelierPort.Pairs()`, which is `%Development:USE`.
  2. The namespace's shape and pairs: `WritePairs(ns)` for a run, `NamespacePairs(ns)` for a record read.
  3. The target's shape and level.
  4. The `OcuPilot` stem refusal.
  5. The target's resolution, through system classes only, with the namespace saved and restored.
  6. The class cap.
  7. The production-test refusal.
  8. The one-run lock.
- A run uses the vendor's colon form with `/noload/nodelete/norecursive`.
- When the namespace's root global does not name an existing directory, it is set to `$System.Util.ManagerDirectory()` for the run. It is put back on every path: restored if it had a value, killed if it had none.
- The client's Run opens a warning dialog that names the consequence. Nothing is sent until the person confirms.
- Both reads are capped and report truncation (AD-36). A screen and its read tool share one read (AD-5).
- Harvested methods are identical to the sibling's at `c6aad31` after the rename table.

**Never:**

- The agent never starts a run. No advertised tool reaches the run, and the prohibited set refuses one that does (`PROHIBITED.PERSONONLY`). There is no mint, no proposal card and no copy-out draft.
- No Atelier `work` route (AD-61 rule 7).
- No caller value in SQL text, and no path (AD-21).
- No edit to `HarvestPort.cls`, `Harvest/Handler.cls` or `AllowedDirectorySave.cls`.
- No directory is created.
- No `OcuPilot.*` class is named while switched.
- No ObjectScript test starts a `%UnitTest` run.

## I/O & Edge-Case Matrix

Probe classes live in `USER` on `ocupilot-b-ci`. `OcuProbe245.Mixed` has one passing and one failing method. `OcuProbe245P.Prod`, in a package of its own, extends `%UnitTest.TestProduction`. Rows from Run class to Busy assume the key is switched on.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Run class | `OcuProbe245.Mixed`, level class, confirmed | A new run is recorded. The output is `{run, passed: 1, failed: 1}`. The root is unchanged. | none |
| Run method | `OcuProbe245.Mixed:TestPasses`, level method | One method runs and passes. | none |
| Run package | `OcuProbe245`, level package | Both `Mixed` methods run. | none |
| Record | after Run class | The runs list shows the run, newest first. Its methods list has two rows, and the failed row's `Failure` is the assertion's description. | none |
| Production | `OcuProbe245P` or `OcuProbe245P.Prod` | 409 `EXPLORER.UNITTEST.PRODUCTION`. Nothing runs. | not logged |
| Not found | missing class, a class that is not a test, a missing method, or a package with no test class | 404 `EXPLORER.UNITTEST.NOTFOUND` | not logged |
| Too many | a package over `MaxTestClasses()` (the fixture sets it to 1) | 400 `EXPLORER.UNITTEST.TOOMANY` with `detail.count` and `detail.max` | not logged |
| Bad shape | `%Library`, `a..b`, `A:B:C`, `*`, or a level outside the three | 400 `PORT.VALIDATION` | not logged |
| Own code | a first segment of `ocupilot`, in any case | 400 `EXPLORER.UNITTEST.OWNCODE` | not logged |
| Busy | the run lock is already held | 409 `EXPLORER.UNITTEST.BUSY` | not logged |
| Gate | no `%Development:USE`, or no WRITE on the routines database | 403 `AUTH.NOPRIVILEGE` with `detail.failedPair` | not logged |
| No result | the run lands no new instance | 500 `EXPLORER.UNITTEST.NORESULT` | logged |
| Switched off | any Run, with the key at its shipped `false` | 403 `EXPLORER.UNITTEST.OFF`, before the hold and the fresh read | not logged |
| Agent | `explorer_unittests_run` by wire name or by tool name | Resolves nothing (`TOOL.UNKNOWN`). A fixture registry that lists the tool as advertised gets 403 `PROHIBITED.PERSONONLY` from the shared operation gate. | structured |

In every refusal row the recorder records no body call, and the root global and the lock are as they were.

</intent-contract>

## Code Map

**Sibling and vendor (read-only):**

- `/Users/jbrandt/git/iris-execute-mcp-v2` at `c6aad31`, `src/ExecuteMCPv2/REST/UnitTest.cls`, 668 lines. The methods are `BuildTestSpec:186`, `ParseTestResults:224`, `GetFailureMessage:328`, `RunTests:37`, `Redirects:142` and `EnsureTestEnvironment:155`.
  - `RunTests` is not taken. It redirects output to `"^"_$ZNAME`, which from `USER` raises `<NOROUTINE>` (measured). It also writes the root and a directory permanently.
- `irislib/%UnitTest/Manager.cls`:
  - `Root():1910`.
  - Under `/norecursive`, a root that is not a directory skips the suite (`:620-626`).
  - `realRunTestSuites:487` kills `^IRIS.Temp.UnitState` and resets the SQL statistics flags (`:497`, `:738-741`).
  - `ReserveResultId:2833`.
- `irislib/%UnitTest/Result/*.cls`: `TestInstance` (`DateTime`, `Duration`) → `TestSuite` → `TestCase` → `TestMethod` (`Status` 0/1/2) → `TestAssert` (`Description`, `Status`).
- `scripts/ci-unit-test.sh:95-118` is the project's own colon-form run. It sets the root and checks that a run "landed".
- The vendor's web terminal, read from source: `irissys/%Atelier/v7/TerminalAgent.cls:10,375` requires only `%Development:USE`. On `ocupilot-b-ci` there is no terminal web application, and `%Service_Terminal` is `Enabled` 1 (probed). The classic `%UnitTest.Portal` pages are read-only and gated by `%Development` (`standardPage.cls:11`). The runner's gate is `%Development:USE`, plus the namespace pairs, plus WRITE on the routines database, plus a key that is off by default, so it is stricter than either.

**Person gate (new):**

- `src/OcuPilot/Area/Security/AllowedDirectorySave.cls:82-90`: the precedent. A person's write asks `Gate.Decide` and refuses 403 with its own code. It is not edited.
- `src/OcuPilot/Api/ScreenAction.cls` `Run`: the pair gate (`Operation.Gate`, about line 303), then the hold (about line 315). The key check goes between them, so preview, impact and dry run refuse identically.
- `src/OcuPilot/Screen/Tool/Write.cls`: add `PERSONGATE`, next to `SCREENACTIONS`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `:1622-1626` is the `ALLOWLISTAGENT` arm. The new arm is a sibling of it.
  - `AgentReachable:6381` is reused.
  - `:161-165` and `:1127`, `:1173` are the code list and `ReasonFor`.
- `src/OcuPilot/Kernel/Governance/Gate.cls:1-5`: header text only.
- `src/OcuPilot/Screen/Tool/AllowedDirectoryUpdate.cls`: the unadvertised tool's doc and parameter model.
- `src/OcuPilot/Test/AllowListAgent.cls:96-122`: the people-only test model.
- `ui/browser/preferences-reset.mjs`: `setGovernanceKey`, `resetGovernancePolicy` and `governanceRowVersion`. `ui/browser/allowed-directory-write.browser-spec.mjs:31-79` is the model for switching a key and restoring it.

**OcuPilot seams carried from iteration 2:**

- `src/OcuPilot/Port/DevToolPort.cls`: the header gate; `ENDPOINT*` and `Endpoints():151`; `Invoke:183-283`; `RunBody` and `CountDocuments`; `Deny`, `Refuse` and `Fail`.
- `src/OcuPilot/Port/AtelierPort.cls`: `Pairs():755`, `NamespacePairs():767`, `WritePairs():788` and `PAIRS = "%Development:USE"`.
- `src/OcuPilot/Port/HarvestPort.cls` `Invoke`: the `%SYS.Capture` capture, rendered once. `src/OcuPilot/Port/Harvest/EnvSync.cls` and `Loc.cls` are the harvest model.
- `src/OcuPilot/Screen/Tool/AnalyticsCubeBuild.cls` and `AnalyticsAction.cls`: the action-write model (`:14-32`, `PortQuery:146`, `StateDiff:160`, `WriteOutput:195`). `ExplorerSqlRun.cls:80` is the literal `IDARGUMENT`.
- `src/OcuPilot/Screen/Descriptor/ExplorerSqlQuery.cls`: `rowActions` `run`, `entityType` `class`, `%Development:USE`. `ExplorerNamespaceDiff.cls` is the descriptor model. `InteropQueueList.cls` and `InteropQueueMessageList.cls` are the parent and child list model.
- `src/OcuPilot/Screen/Read.cls` (the `devtool` branch) and `Screen/Registry.cls:1438-1455`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls:93,215` and `src/OcuPilot/Api/AtelierError.cls` (the `EXPLORER.*` codes).
- Client:
  - `ui/src/app/areas/system-explorer/dev-tool.page.ts` (form :62-100, read :150, search :301) and `dev-tool.store.ts`.
  - `sql-query.page.ts:124,158-165` and `sql-query.store.ts:261-290`: the Run, warning dialog and `sendFor` model.
  - `shell/screen-outlet.ts:222-224`, `shell/data-table.ts` (`rowTarget`) and `core/navigation.ts:343-363`.
- Tests:
  - `Test/DevToolPortFixture.cls`, `DevToolHarvestRecorder.cls`, `DevToolProbe.cls` and `Test/AnalyticsCubeActions.cls`.
  - `ui/browser/namespace-diff.browser-spec.mjs` (`runIris` and the throwaway guard) and `system-explorer-sql-query.browser-spec.mjs:181-200` (the confirm dialog).
- Rosters, with each count re-derived:
  - Every file in `src/OcuPilot/Test` and `ui/tools` that names `security.alloweddirectories.update` lists registered or unadvertised tools; check each. Known ones are `ReadTool.cls:93-94`, `SurfaceCoverage.cls:554` (the row points at a person-path test), `Governance.cls`, `GovernanceBaseline.cls:15` and `ToolRoundTrip.cls`.
  - Also `ExplorerDescriptor.cls:161,162,171`, `DraftRegistry.cls`, `PortGate.cls:29`, `Test/Prohibited.cls` (code roster), `DeveloperFloor`, `Navigation`, `Descriptor`, `ReadDescriptions`, `ClassicPageGate`, `ToolEmit`, `Wire`, `WireAreaAnyScreen`, `ui/tools/navigation.test.mjs:386-395` and `screen-mirror.test.mjs`.

## Tasks & Acceptance

**Execution, batch 1 (server):**

- **Task 0, on `ocupilot-b-ci`, before any code.** Run one `%UnitTest` run at a time, never beside another test call. Record each result under Design Notes as `Task 0 (measured)`.
  1. A colon-form `/noload/nodelete/norecursive` run in `USER`, with the root set to the manager directory, runs `OcuProbe245.Mixed`. Afterwards the manager directory's listing is unchanged.
  2. The same run, under `HarvestPort`'s capture from `HSCUSTOM` and switched to `USER`, keeps the capture and answers. If it does not, stop and report.
  3. A least-privileged principal can read `%UnitTest_Result` with privilege checks on. The principal holds `%Development:USE`, the `USER` pairs and WRITE on the routines database. If the read is refused -99, the reads use `%ExecDirectNoPriv` after the gate (`LogSourcePort` precedent).
  4. The same principal can take `Lock +^CacheTemp.OcuPilotUnitTestRun:0`.
  5. How long the probe run takes.
  6. With auditing on, whether a run records any vendor audit event.
- `src/OcuPilot/Port/Harvest/UnitTest.cls` -- new; extends `Harvest.Handler`. It holds `BuildTestSpec`, `ParseTestResults` and `GetFailureMessage`, changed only by the rename table.
- `src/OcuPilot/Port/Harvest/UnitTestRun.cls` -- new; extends `UnitTest`. Its one handler, `Run()`:
  1. Reads `target`, `level` and `namespace`, then switches with `..SwitchNamespace`.
  2. Takes the newest `^UnitTest.Result` index.
  3. Calls `%UnitTest.Manager.RunTest(..BuildTestSpec(...), "/noload/nodelete/norecursive")`.
  4. If no newer index landed, fails with `NORESULT`.
  5. Otherwise adds `run` to `..ParseTestResults(filter)`, restores the namespace and renders once.
- `src/OcuPilot/Port/DevToolPort.cls`:
  - Add the endpoints `UnitTestRun` (`STATE`, `RUN`), `UnitTestRuns` (`LIST`) and `UnitTestMethods` (`LIST`, with key `run`).
  - Add the Always steps, `MaxTestClasses()` (50), `LockName` and the root set and restore. This is the one place the root global is named.
  - The `STATE` read answers `{Namespace, Tests, Level, Classes, Production, Busy}`.
  - The record reads use fixed statements with bound values. Runs come newest first: `Run`, `Started`, `Duration`, `Methods`, `Passed`, `Failed`, `Finished`. Methods carry `Class`, `Method`, `Result`, `Duration` and `Failure`. `Failure` is the failed assertions' descriptions joined with "; " and cut at 2,000 characters.
  - Update the header.
  - Fill `Snippet` and `SnippetForm` only if `Test/DraftRegistry.cls` demands a form for every registered write.
- `src/OcuPilot/Screen/Tool/Write.cls` -- add `Parameter PERSONGATE = ""`. A non-empty value is the code a person's action is refused with while the tool's governance key is off. It marks the tool as AD-10's run-code exception (U-86).
- `src/OcuPilot/Api/ScreenAction.cls` `Run` -- between the pair gate and the hold: when the tool declares `PERSONGATE`, call `Gate.Decide(TOOLNAME, kind, ..CallerUsername(), values)`. On a denial, render 403 `FORBIDDEN` with that code and its reason (`AtelierError.ReasonFor`), before any hold or read. An error status renders internal. Add a header sentence.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - Add `PERSONONLY = "PROHIBITED.PERSONONLY"` and its reason.
  - Add the code to the code list and to `ReasonFor`.
  - Add the arm: for any tool whose class declares a non-empty `PERSONGATE` and that `..AgentReachable(pToolName)`, refuse. It is judged on the tool, before the type arms, and reads no target.
- `src/OcuPilot/Kernel/Governance/Gate.cls` -- the header names the screen action route's `PERSONGATE` ask beside `POST /allowed-directories`.
- `src/OcuPilot/Screen/Tool/ExplorerUnitTestRun.cls` -- new, on the cube build's model.
  - `TOOLNAME` `explorer.unittests.run`, `ADVERTISED 0`, `PERSONGATE "EXPLORER.UNITTEST.OFF"`.
  - `PORTCLASS DevToolPort`, `READTYPE STATE`, `WRITETYPE RUN`, `DESTRUCTIVE 1`, `SENDSBODY 0`, `READSVALUES 1`.
  - `SCREENACTIONS run`, values `tests:level`, and `IDARGUMENT` with the port's literal `IDVALUE`.
  - `FINGERPRINTSUBJECT Namespace,Tests,Level,Classes`; `PRECONDITIONFIELD Busy`, with `Production` refused. `WriteOutput` answers `{run, passed, failed}`.
  - `DESCRIPTION` "Run a namespace's unit tests. Only a person runs them, from the Unit tests screen; the agent never does."
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- `"explorer.unittests.run": false`, add-only.
- `src/OcuPilot/Api/AtelierError.cls` -- add seven `EXPLORER.UNITTEST.*` codes (`OFF` among them) with the reasons under Proposed strings.
- `src/OcuPilot/Screen/Descriptor/ExplorerUnitTests.cls` -- new.
  - Route `system-explorer/unit-tests`, side-bar position 17.
  - `%Development:USE`, `entityType` `class`, scope `namespace`.
  - Criteria: `tests` (text, 256) and `level` (`package`/`class`/`method`, default `class`).
  - Read `UnitTestRuns`; `rowActions` `run`; `rowTarget` to the methods list.
  - `toolIdentifier` `explorer.unittests`, `classicPage` `""`, read-only suggested prompts.
- `src/OcuPilot/Screen/Descriptor/ExplorerUnitTestRun.cls` -- new. Route `system-explorer/unit-tests/methods`, position 0, `parentScope` the runs route, `id` single, criterion `run`, read `UnitTestMethods`, `toolIdentifier` `explorer.unittestrun`.
- `src/OcuPilot/Screen/Titles.cls` -- regenerate. Add this story's members to every roster in the Code Map and re-derive each count.
- `scripts/check-objectscript.py` and `scripts/test_check_objectscript.py` -- admit the root-global token in `src/OcuPilot/Port/DevToolPort.cls` only, with a docstring line. Add one harness case for that file and one for any other file.
- `src/OcuPilot/Test/UnitTestRunGate.cls` -- new, under 500 lines. Through a `ScreenAction` fixture and `DevToolHarvestRecorder`, it covers:
  - every refusal row;
  - Switched off, with the key at baseline;
  - the run path with the key stored `true`, which records `UnitTestRun.Run` with the port's keys only;
  - the root and the lock restored on every path.
  - It overrides `MaxTestClasses`. It saves the stored policy and restores it.
- `src/OcuPilot/Test/UnitTestPersonOnly.cls` -- new, modeled on `AllowListAgent`.
  - The tool appears in no provider list, wire lookup, screen context or `shell.tools.find` result. The registry still resolves it for the route.
  - A `Prohibited` subclass whose registry lists it as advertised refuses `PROHIBITED.PERSONONLY`.
  - Every registered write whose port endpoint is `DevToolPort`'s `UnitTestRun` declares `PERSONGATE`.
- `src/OcuPilot/Test/UnitTestRecord.cls` -- new. It builds its own `TestInstance` tree in `USER` under `$Increment(^UnitTest.Result)` and deletes it in `OnAfterOneTest`. It asserts both reads, the cap and truncation, and the failure text.
- `src/OcuPilot/Test/DevToolProbe.cls` -- add `MakeTests`/`RemoveTests` for `OcuProbe245` and `OcuProbe245P`, and `RemoveRun(index)`.

**Execution, batch 2 (client):**

- `ui/src/app/areas/system-explorer/dev-tool.store.ts` and `dev-tool.page.ts` -- add a run mode for a descriptor whose action is `run`.
  - The form takes `tests` and `level`.
  - Run opens `app-warning-dialog` with the consequence. Confirm sends `sendFor(descriptor, 'run', ...)`. Cancel sends nothing.
  - A refusal shows the instance's reason, `EXPLORER.UNITTEST.OFF` included.
  - The runs list is read on arrival and after the change event. The table honors `rowTarget`.
  - Add `.spec.ts` cases: the dialog's consequence, Cancel sends nothing, and the off reason is shown.
- `ui/src/app/shell/screen-outlet.ts` -- add a loader line.
- `ui/src/app/core/strings.ts`, `core/screens.generated.ts` (`node tools/screen-mirror.mjs`) and EXPERIENCE.md's Fixed strings -- add-only, including both refusal sentences.
- `ui/browser/unit-tests.browser-spec.mjs` -- new.
  - `before`: assert the throwaway, then `MakeTests` through `runIris`.
  - With the key at baseline, Run then Confirm shows the off sentence, and no run is added.
  - `setGovernanceKey` on: run `OcuProbe245.Mixed` through the dialog, then open the new run and see both methods and the failure text. The root is unchanged.
  - The `OcuProbe245P.Prod` target shows the production reason.
  - `after`: `RemoveTests`, `RemoveRun`, then restore the governance policy as the allow-list spec does.

**Execution, batch 3 (register and planning), 24.8's edit list applied to DT-03, bottom-up:**

- `docs/exclusion-register.md` -- add the DT-03 row after DT-11 (:230), gate kind `dependency`.
  - Reason: "The instance-wide work queue records no owner, a poll of an item consumes the result another client is waiting for, and the instance offers no way to list the queue. The unit-test runner keeps its own run record instead."
  - Gate: "The vendor records an owner per queued item and offers a read that does not consume it."
  - How to tell it has cleared: "The vendor's work queue records an owner per item and offers a read that leaves the item for its owner."
- `feature-catalog.md`:
  - :615 DT-03 becomes P4, with "— excluded: ... (owner answer U-77, 2026-11-16)".
  - Re-derive :36 and :38.
  - Add the judgment call after :686.
  - :454 "(see DT-03 runner)" becomes "(see DT-02 runner)".
- `extract-stages.md`:
  - Delete :600 and add DT-03 to Stage 5's last group.
  - Re-derive :17, :28-29, :369, :371 (drop "work-queue viewer"), :595, :642, :643, :647, :736, :772, :774, :826, :957, :966 and :967.
  - :734's pointer becomes DT-02.
- `epics.md:353-354`, `extract-catalog.md:429,431` (and the judgment call after :408) -- re-derive the counts.
- `harvest/iris-execute-mcp-v2.md:36` -- 333 becomes 668.
- `harvest/HARVEST-PLAN.md:106` -- `^UnitTestRoot` is the vendor's root. It is never renamed, and only `DevToolPort` names it.

**Acceptance Criteria:**

- **AC1.** Given the key switched on, when a person runs a class, a method or a package and confirms, then it round-trips over `%UnitTest.Manager`. This covers matrix rows Run class, Run method and Run package, observed in the browser on `ocupilot-b-ci`, and the root global ends as it began.
- **AC2.** Given the run record, when it is read after a run, then both reads round-trip over `%UnitTest_Result` (matrix row Record), through the screen route and through each read tool.
- **AC3.** Given any refusal row, when the run is asked, then it answers that row's status and code. The recorder recorded no call, and the root global and the lock are unchanged.
- **AC4 (Integration, off by default).** The consumer is `ScreenAction`. Given `PERSONGATE` and the key at its shipped `false`, when a person's Run is sent, then it answers 403 `EXPLORER.UNITTEST.OFF` and nothing is held, read or run. After an administrator's `PUT /agent/governance` sets the key on, the same Run runs the probe class and the record shows it.
- **AC5 (people only).** Given the agent, when it looks for or calls the runner, then the tool is in none of its lists and resolves by no name. A registry that offered it is refused `PROHIBITED.PERSONONLY` on the instance.
- **AC6 (confirmed).** Given the Unit tests screen, when the person presses Run, then the warning dialog shows the consequence sentence. Nothing is sent before Confirm, and Cancel sends nothing.
- **AC7.** Given the harvested methods, when they are compared with the sibling's after the rename table, then they are identical, and `uv run scripts/check-objectscript.py` passes.
- **AC8.** Given the work-queue viewer, when this story lands, then the register holds DT-03 as not planned with the U-77 reason, the catalog marks it P4, and `exclusion-register.test.mjs` passes.

## Spec Change Log

- 2026-11-16, re-plan (iteration 3), owner answer U-86 "A". The intent contract was rewritten on the runner's re-plan directive:
  - The agent's tool and its mint were removed. AC4's agent leg became AC4 (off by default) and AC5 (people only).
  - The `PERSONGATE` gate and AC6 (confirmed) were added.
  - Known-bad state avoided: a run the agent can reach, or one that is on by default.
  - KEEP: the run record, the root set and restore, the production refusal, the IRISTEMP lock, Task 0 and the DT-03 move.

## Review Triage Log

## Design Notes

**Owner answer U-86 (2026-11-16, "A"):** the runner is built with a named AD-10 exception for a test class's own code: off by default, people only, every run confirmed with its consequence named. The DW-2634 fix (Story 21.30) is on feature. Stories 24.6 and 24.7 carry the same answer (U-78 A) and reuse this gate.

### The gate chosen, and why

- **People only** uses AD-53's unadvertised case: no provider list, dispatch lookup, screen context or discovery search carries the tool, and a test pins all four. The kernel arm makes it hold on the instance: AD-10 says "a self-protection rule that a screen enforces only in its UI is not a prohibition". That arm is the allow-list's `ALLOWLISTAGENT` pattern, generalized from an entity type to a tool declaration, so 24.6 and 24.7 need no new arm.
- **Off by default** uses AD-22's one existing person-key mechanism: `POST /allowed-directories` asks `security.alloweddirectories.update`, which ships `false` because the owner wanted the action "switched off by default".
  - `PERSONGATE` moves that ask into the generic screen action route, so a later tool opts in by one parameter instead of a route of its own (Rule 31: extend).
  - The key is switched on by an OcuPilot administrator in Governance policy; that write is audited (FR-29).
  - Alternatives rejected: AD-64's per-screen pairs lower or raise a requirement but cannot ship a screen closed. A new `Security.Resources` resource would need an installer change and a role grant: more parts, and a privilege change in the veto window.
- **"Gated like the vendor terminal"** (measured from source and on `ocupilot-b-ci`): the vendor's web terminal asks only `%Development:USE`, and `%Service_Terminal` is enabled. The runner asks that pair, the namespace pairs and WRITE on the routines database, behind a key that is off by default. It is stricter, never looser.
- The kill switch and enforced read-only still do not gate it (AD-53). The governance preset does, through the key, as it does for the allow-list.

### Governing ADs

- AD-10: the named exception and `PERSONONLY`.
- AD-22: the person key.
- AD-53: the unadvertised tool, two callers, and the dialog as the review.
- AD-61, including rule 7: never the `work` routes; the gate pairs.
- AD-23 and AD-29: `DevToolPort` is the gate.
- AD-7: the run happens in the action request.
- AD-51, AD-52, AD-58 and AD-14: the write model.
- AD-36, AD-5, AD-24, AD-11 and AD-60: the reads. Failure text is untrusted data.
- AD-16: the switch saves and restores. AD-21: bound values only.
- AD-39: the output is three numbers. AD-17: test classes compile only on a throwaway.

### Decided in-stage (reversible)

- **The run handler is OcuPilot's** (`Run()`, not `RunTests`). It is a deliberate copy of the body's call order (Rule 31), because `RunTests` hits `<NOROUTINE>` and writes the root permanently.
- **The root is set and restored,** as `ci-unit-test.sh` does. The checker admits the root global in one file.
- **Production tests are refused,** because `%UnitTest.TestProduction` stops the running production.
- **The lock lives in IRISTEMP** (`^CacheTemp.OcuPilotUnitTestRun`), so DW-2634's guarded methods gain no member. Named limit: a run started outside OcuPilot takes no lock.
- **Named limits, as for AD-7's cube build:** there is no cancel; an answer lost to the gateway timeout still shows in the record; every run resets the instance's SQL statistics flags.
- **The screen does not draw Run off before a click.** The off sentence arrives at Confirm, on the surface every refusal uses. Reversible: a later story may read the verdict as the allow-list screen does.
- **`entityType` is `class` with a literal target,** as the SQL console declares. No new entity type.
- **No copy-out draft:** a person-only tool mints nothing.

### Integration ACs, Consumed-by and Consumes

- **Integration ACs:** AC4 (the action route consumes `PERSONGATE`) and AC5 (the prohibited set consumes it).
- **Consumed-by:**
  - 24.6: each console's write declares `PERSONGATE` with its own code and key, shipped `false`.
  - 24.7: the web terminal's command write, the same way.
  - 24.20's undo takes no run (inference: a run is not revertible).
- **Consumes:** 24.1's `DevToolPort`, recorder and probe; 24.8's page; `AtelierPort`'s pairs; `AllowedDirectorySave`'s key pattern; `Prohibited.AgentReachable`.

### Contended files: edits beyond appending (check `origin/OCU-1-epic21` at integrate-forward)

- `DevToolPort.cls`: the header and `Invoke`.
- `ScreenAction.cls` `Run`: an insertion.
- `Prohibited.cls`: an arm insertion.
- `Gate.cls`: the header.
- `check-objectscript.py` and its harness.
- `dev-tool.page.ts` and `dev-tool.store.ts`.
- `HARVEST-PLAN.md:106` and `iris-execute-mcp-v2.md:36`.
- The count lines in the catalog, the extract, `epics.md` and `extract-catalog.md`. Epic 21's 21.12 re-derives the same totals: re-count after the union, and never add the deltas.
- `ReadTool`'s literal count.

### Governance keys and gates

- `explorer.unittests.run`: default `false`, destructive, person-only.
- Gate `PERSONGATE`: a write-base parameter, default `""` (not gated). This story sets it to `EXPLORER.UNITTEST.OFF`.

### Proposed strings (veto item)

- Titles: "Unit tests" and "Unit test run". Button: "Run tests".
- Criteria: "Tests", with the hint "A package, a class, or Class:Method". "Run", with the choices "Package", "Class" and "Method".
- Dialog title: "Run these tests?" Consequence: "The tests' own code runs as you, with your rights, in this namespace. OcuPilot cannot see or undo what it changes."
- Refusal reasons:
  - Off: "Running unit tests is switched off on this instance. An administrator can switch it on in Governance policy."
  - Person only: "This runs code with the rights of whoever starts it, so it is started from its own screen alone."
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
  - Results: "Passed", "Failed" and "Skipped".
- Empty state: "No unit-test runs are recorded in this namespace."
- Suggested prompts: "Which tests failed in the newest run?" and "How long did the newest run take?"

### Proposed spine amendments (the runner writes these at the spec gate)

Written at the spec gate on 2026-11-16, citing owner answer U-86: the AD-10 paragraph, the AD-22 exception and AD-53's fifth unadvertised tool (orchestrator ruling; a veto item for the owner). AD-29's Binds, AD-61 and AD-7 stay proposed for the owner's attended update. The AD-53 audit-gap sentence waits on Task 0 item 6.

- **AD-10**, a new paragraph after the SQL-console paragraph:

  > **Code a person runs through OcuPilot** [AMENDED 2026-11-16, Story 24.5 spec gate, owner answer U-86, Rule 20]: the unit-test runner (Story 24.5) executes the test classes' own code with the signed-in person's rights, as the vendor's `%UnitTest.Manager` does, so nothing on the write path can see what that code changes. Named gap: a test class's own code, the same shape as the SQL console's procedure gap. It is a named exception held to three rules. It is a person's alone: its tool declares `PERSONGATE` and is unadvertised (AD-53), and a call of such a tool that the agent can reach is refused `PROHIBITED.PERSONONLY` from either caller. It is off by default: the screen action route asks the tool's governance key, shipped `false`, which an OcuPilot administrator switches on in Governance policy (AD-22). Every run passes a confirmation that names its consequence. A target in an `OcuPilot` package is refused by the port as a screen, not a prohibition. Stories 24.6 and 24.7 (owner answer U-78) come in under the same three rules.

- **AD-22**, "One person's write asks its key": append "A tool declaring `PERSONGATE` (AD-10's run-code exception, owner answer U-86) is asked its key by `POST /screens/:screen/action` too, after the screen's pairs and before the hold and the fresh read, refusing 403 with the tool's code. `explorer.unittests.run` ships `false` (Story 24.5)." Its sentence "No other person's write is asked." becomes "No other person's write is asked, except through `PERSONGATE`."
- **AD-53**: "A fifth unadvertised tool: `explorer.unittests.run` (Story 24.5), person-only under AD-10's run-code exception; its key ships `false` and is asked by the action route." If Task 0 item 6 measures no vendor event, add a named gap for Unit tests' Run. The implement stage records the measurement; the runner adds the sentence.
- Add `DevToolPort` to AD-29's Binds. This is already pending from 24.1.
- **AD-61**: "a later call Atelier cannot carry: Story 24.5's run, in process."
- **AD-7**: the run is cost-named like the cube build, including the reset of the SQL statistics flags.

## Verification

**Shared surfaces:** `USER`'s `^UnitTest.Result` and root global; System Explorer side-bar position 17; the registered and unadvertised tool rosters; the governance baseline and the stored policy; the prohibited code roster and EXPERIENCE.md's Fixed strings; the devtool endpoint refusal sentence. Every test added or changed passes on a fresh environment, in either order.

**Kept apart from the suite's own runs:** no ObjectScript test starts a run. The record test writes rows in `USER` only, while `ci-unit-test.sh` reads `HSCUSTOM`'s newest index. The browser spec's run is a `%UnitTest` run, so it gets its own `(loop)` call and never runs beside a `ci-runner` call. Tests that store a governance key restore the policy they found.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.UnitTestRunGate --class OcuPilot.Test.UnitTestPersonOnly --class OcuPilot.Test.UnitTestRecord` -- expected: all pass. Run each roster or existing class touched (`Prohibited`, `Governance`, `GovernanceBaseline`, `SurfaceCoverage`, `ReadTool`, `ToolRoundTrip`, `ExplorerDescriptor`, `DraftRegistry`, `PortGate`, `AllowListAgent`, the `ScreenAction` suite) the same way, one call at a time, each under about 170 s.
- `(loop)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/unit-tests.browser-spec.mjs` -- expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components` -- expected: pass, `exclusion-register.test.mjs` included.
- `(loop)` `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` -- expected: clean.
- `(once)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, for k = 1..17, one call each -- expected: green. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC:**

- AC1: skip the root restore → the browser spec's root assertion goes red.
- AC2: drop the `Status=0` filter on `Failure` → `UnitTestRecord`'s failure-text test goes red.
- AC3: move the production check after `RunBody` → `UnitTestRunGate`'s Production test goes red.
- AC4: remove the `PERSONGATE` ask from `ScreenAction.Run` → `UnitTestRunGate`'s switched-off test goes red, because the recorder records a call.
- AC5: set `ADVERTISED 1` on the tool → `UnitTestPersonOnly`'s list test goes red. Remove the `PERSONONLY` arm → its fixture-registry test goes red.
- AC6: send on Run without the dialog → the `dev-tool.page` spec's Cancel case goes red.
- AC7: change one harvested line → the harvested-identity test goes red.
- AC8: leave DT-03 at P3 → `exclusion-register.test.mjs` goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
