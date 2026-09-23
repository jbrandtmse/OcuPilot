---
title: 'Story 7.5: Run an on-demand task'
type: 'feature'
created: '2026-09-23'
status: 'done'
baseline_revision: '44428515205395e3a8de162b2542e4d9835574b3'
baseline_commit: '44428515205395e3a8de162b2542e4d9835574b3'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-11-tasks-resume-a-task-suspended-after-an-error.md'
warnings: ['oversized']
deferred: []
footprint_extensions: # planned; Epic 8 modified these, and this story adds only its own members (roster rule, 2026-09-23)
  - 'src/OcuPilot/Port/AdminPort.cls' # shared-append; MUTATINGTYPES gains one pair, new parameter appended
  - 'src/OcuPilot/Test/ToolWrite.cls'
  - 'src/OcuPilot/Test/PortFixture.cls'
  - 'src/OcuPilot/Test/SurfaceCoverage.cls'
  - 'src/OcuPilot/Test/ReadTool.cls'
  - 'src/OcuPilot/Test/ToolRoundTrip.cls'
  - 'src/OcuPilot/Test/ProhibitedRoute.cls'
  - 'ui/tools/screen-mirror.test.mjs'
  - 'ui/src/app/core/screens.generated.ts' # regenerated
---

<intent-contract>

## Intent

**Problem:** On-demand tasks lists tasks but has no Run action. The agent has no tool to run a
task. The vendor's `Task.CRUD` `RUN` type needs a body of `{"RunNow":true}`. No write path can send
that today: `AdminPort` answers 501 for `Task.CRUD/RUN`, and an action write sends no body or only
secrets.

**Approach:** Add one action-style write, `tasks.ondemand.run` (AD-51), with two callers (AD-53):

- the list's Run row action through `POST /screens/tasks.ondemand/action`;
- the agent's proposal and confirmation.

Both read `INFO` fresh and issue `RUN`. The port supplies the vendor's constant body as a wire fact,
the way `RENAMEDTYPES` supplies the vendor's key. Build it so Story 7.6's schedule Run is a subclass
that changes only the tool name and the owning descriptor.

## Boundaries & Constraints

**Always:**

- One operation, two callers. Reuse `ScreenAction`, `Operation`, `Mint` and `Confirm` unchanged.
- The screen caller mints no proposal, emits no marker, writes no ledger row, and is not gated by the
  kill switch or read-only mode. The agent's caller does all of those.
- Check the screen's own pairs, `%Admin_Task:USE` and `%DB_IRISSYS:READ`, before any read (AD-8).
- Publish one AD-14 `task` change event per write, and re-fetch rather than patch.
- Target the vendor's numeric `Id` under the `task:integer` identity rule (AD-13).
- Hold no `%SYS.Task` OREF, and no transaction, across the write. See the lock trap under Design
  Notes.
- Every new string goes to Fixed strings and `strings.ts`, appended only.
- Every test that runs a task runs a harmless probe task that it creates and deletes itself, on a
  throwaway only.

**Never:**

- No dialog before Run (EXPERIENCE `:173`).
- No new armed test class, and no edit to `scripts/ci-*.sh` or `ci.yml`.
- No edit to `Write.cls`, `Operation.cls`, `Mint.cls`, `Confirm.cls`, `Prohibited.cls`,
  `Registry.cls`, `Classification.cls`, `ToolFields.cls` or `EntityRef.cls`.
- No `RunOnce` / `Datetime` scheduling.
- No auto-refresh on On-demand tasks (AD-43's closed roster).
- Do not run the demo task.
- The schedule list's actions are Story 7.6's.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Screen Run | row selected; Run from the row menu or command bar | no dialog. One POST `{action:"run",id:"<Id>"}` answers 200 `{action:"updated",target:{type:"task",scope:"instance",id:"<Id>"}}`. The row re-fetches in place and is marked changed. Next run reads the request time at once. | No error expected |
| The run lands | after either caller | within one Task Manager pass (measured 26–43 s), `INFO` `LastFinished` is set, and the task's history gains a `Success` row | The test's wait is bounded at 180 s, so a lock held across the write would read red, not hang |
| Agent run | agent proposes `tasks.ondemand.run` for an id | the proposal diff shows `NextScheduled: "<current>" → "now"`. Confirm runs the task, marks it, and writes the ledger. | Blocked by read-only or the kill switch as every write is |
| Suspended target | `INFO` `Suspended` is true | the diff adds `Suspended: true → false`. The run also resumes the task (measured). | n/a |
| Unreadable state | `INFO` lacks a readable `Suspended` | the mint is refused with a problem naming the unread state | nothing proposed |
| State moved | `NextScheduled` or `Suspended` changes between mint and confirm | `PROPOSAL.TARGETCHANGED` | nothing sent |
| Short of the pair | principal without `%Admin_Task:USE` | 403 `AUTH.NOPRIVILEGE` with `detail.failedPair` `%Admin_Task:USE`, returned before any read | `NextScheduled` stays empty |
| Caller body on RUN | port asked to send an object body for `Task.CRUD/RUN` | refused as a port fault | the vendor is not called |

</intent-contract>

## Code Map

Measured on the throwaway `ocupilot-ci`, 2026-09-23, with a `%SYS.Task.RunLegacyTask` probe
(`ExecuteCode` `Quit`, `TimePeriod` 5), created and then deleted:

- **The vendor endpoint.** `%Api.Admin.Endpoints.Task.CRUD` is `[Hidden]` and not exported. It was
  read with `GetTextAsString`.
  - `TYPERUN` is 12. `NeedsRequestBody` is true for it.
  - `ValidateRequest` requires `RunNow`, with a template of `{RunNow:true, Datetime}`.
  - `RunRun` opens the task OREF as a local, calls `%SYS.Task.RunNow(id)`, and returns `{}` with
    status 200.
  - `ResourcesOR` for `RUN` is `%Admin_Task`. The wire path is `POST /v2/task/run?id=`.
- **What `RunNow` does.** It answered OK.
  - `INFO` `NextScheduled` became the request time at once, and so did the `LIST` row's (as
    `hh:mm:00`).
  - The run landed at the next whole-minute pass. `LastStarted`, `LastFinished` and `Error`
    `Success` were set, `NextScheduled` returned to `""`, and history gained a row with `Result`
    `Success`.
  - On a suspended task, `RunNow` answered OK, `Suspended` read false at once, and the task ran.
  - The OREF the caller held read `%Concurrency` 4 after `RunNow`. The run happened only after the
    caller killed it.
- **The shipped tool this copies.** `src/OcuPilot/Screen/Tool/TaskResume.cls` is Story 5.11's tool:
  `INFO` read, bodyless, `STATEFIELD`, `StateDiff`, `PrivilegePairs`, `IdArgument` `Id`,
  `IdParam` `id`.
- **The port.** `src/OcuPilot/Port/AdminPort.cls`:
  - `MUTATINGTYPES` `:191`. Epic 8 also extends this line, and the merge reconciles it.
  - `BODYLESSTYPES` `:207`. `RUN` is not listed there.
  - `RENAMEDTYPES` `:219` is the precedent for a wire fact.
  - `Invoke` `:451`, with its object-body refusal at `:490`. `RunSequence` substitutes `{}` at
    `:976`, and `ValidateRequest` gives 400 at `:1031`.
- **The write path, read only.**
  - `Api/ScreenAction.cls`: `ToolFor` `:121` matches `DESCRIPTORCLASS` plus `SCREENACTIONS`;
    `Run` `:192-281`.
  - `Operation.SecretBody` `:113` returns `""` for a bodyless tool, and `Apply` is at `:288`.
  - `Confirm.cls:356-376`: the claim, its lock and its `TSTART` all close in
    `Propose.GuardedClaimAndClose` before `Apply`, so the write runs at `$TLEVEL` 0 with no
    OcuPilot lock.
- **Prohibited.** `Prohibited.cls` covers `task` (`:149`, the `Task` arm at `:665`).
  `ReviewedFewOnly` refuses any changed field that it does not skip, and it skips `STATEFIELD` plus
  every subject name (`:1394`). Every diff-row label must be one of those.
- **The registry.** `Registry.FingerprintSubjectProblem` `:2100-2169`: the subject must contain
  `PRECONDITIONFIELD`, and every name must be a read field of the screen or in `READANSWERS`.
  `TableProblem` `:1926`: a write-capable list needs a non-empty `emptyAgentKey` and an empty
  `emptyNextKey`. An action write needs no `Classification.cls` entry.
- **The descriptor.** `src/OcuPilot/Screen/Descriptor/TaskOnDemandList.cls`:
  - `id` is `single`, so `rowKey()` would send the **Name**. It must become `composite ["Id"]`, as
    in `TaskScheduleList`.
  - `rowActions []`. The "declares no Run" doc is at `:17-19`.
- **The client.**
  - `ui/src/app/shell/screen-action-handler.ts`: roster `SCREEN_ACTION_DESCRIPTORS` `:30-36`. A
    non-destructive action with no warning is sent at once (`:264`).
  - `ui/src/app/core/screen-actions.ts`: `ACTION_LABELS` `:61-71` has no `run`. `STRINGS.actionRun`
    ("Run", `:111`) is unused.
  - The list re-fetches on a `task` event through `RefreshService.onBusEvent` (`core/refresh.ts:607`).
- **Existing keys to reuse:** `actionRun`, `taskColumnNextRun` ("Next run"), `taskColumnLastRun`.
  `proposalEntityWebApplication` (`strings.ts:1267`) is the noun precedent.
- **Test precedents.**
  - `Test/TaskResume.cls` (armed by `OCUPILOT_ALLOW_TASK_CONTROL`, 647 lines). Its helpers are
    `HistoryHighWater` `:565`, `HistoryRowsForTask` `:587` and `InfoSuspended` `:547`, and its
    real-write test is `:308-365`.
  - `ProhibitedRoute.TestAnAccountShortOfTheAuditingPairIsRefusedTheScreenAction` `:1611`.
    `ProhibitedRoute` already calls `TaskResume.EnsureProbeTask` without declaring the task
    variable (`:1373`).
  - `ToolWrite.AssertActionWrite` `:643`, and the `TaskResume` row at `SurfaceCoverage.cls:109`.
  - `ReadTool.cls:93-94`: the tool count (56) and the name list.
  - `ToolRoundTrip.cls:33` `REFUSEEMPTY`.
  - `Descriptor.cls:100` is the `TaskOnDemandList` row. `TaskLists.cls:138-290` covers 6.5's reads.
  - `ui/tools/screen-mirror.test.mjs:842-851`.
  - `ui/browser/tasks.browser-spec.mjs:984-1004` asserts five headers and a Refresh-only command bar.
    Both change.
  - `ui/browser/task-resume.browser-spec.mjs` covers the scripted agent turn (`turnprobe-spec.mjs`),
    the `-ci` container guard and `runIris` setup.
  - `ui/browser/web-applications-actions.browser-spec.mjs:115-275` covers select, the row menu, the
    press and the in-place check.
  - `screen-action-handler.spec.ts:408-417` and `:82-105`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/AdminPort.cls`:
  - Append `Task.CRUD/RUN` to `MUTATINGTYPES`.
  - Append `Parameter CONSTANTBODIES = "Task.CRUD/RUN={""RunNow"":true}"` and a class method
    `ConstantBody(pEndpoint, pType)` that answers a new `%DynamicObject` or `""`.
  - In `Invoke`, before the object-body refusal, a pair with a constant body is sent that constant
    when the caller's body is not an object. A caller object body for such a pair is refused as a
    port fault, and the vendor is not called.
  - The doc for both states that this is a vendor wire fact (AD-27), and that the kernel and the
    ledger still see no body.
- `src/OcuPilot/Screen/Tool/TaskRun.cls` (new) extends `Write`:
  - `TOOLNAME` `tasks.ondemand.run`, `DESCRIPTORCLASS` `…TaskOnDemandList`, `SCREENACTIONS` `run`.
  - `READTYPE` `INFO`, `WRITETYPE` `RUN`, `SENDSBODY` 0.
  - `WRITERESOURCE` `%Admin_Task`, `WRITEPERMISSION` `USE`.
  - `PRECONDITIONFIELD` `Suspended`, `FINGERPRINTSUBJECT` `NextScheduled,Suspended`,
    `READANSWERS` `NextScheduled,Suspended`, `STATEFIELD` `NextScheduled`.
  - `Endpoint` `Task.CRUD`, `IdArgument` `Id`, `IdParam` `id`, and `SettableFields`, `InputSchema`
    and `PrivilegePairs` as in `TaskResume`.
  - `StateDiff`:
    - Row `NextScheduled`: before is the read's value, after is `now`.
    - Add a `Suspended` true→false row when the task reads suspended.
    - An unreadable `Suspended` is a problem.
  - The class doc names the lock trap and states that Story 7.6's subclass overrides only
    `TOOLNAME` and `DESCRIPTORCLASS`.
- `src/OcuPilot/Screen/Descriptor/TaskOnDemandList.cls`:
  - `id` becomes `{"kind":"composite","parts":["Id"]}` and `rowActions`
    `[{"id":"run","selfProtection":""}]`.
  - Add `NextScheduled` to `read.fields`, `sort.fields` and `context.fields`, and add a column
    `{"field":"NextScheduled","labelKey":"taskColumnNextRun","kind":"text"}` after Last run.
  - `emptyNextKey` becomes `""` and `emptyAgentKey` `taskOnDemandEmptyAgent`. Add `entityLabelKey`
    `proposalEntityTask`.
  - Rewrite the "declares no Run" doc.
- `ui/src/app/shell/screen-action-handler.ts`: add `TaskOnDemandList` to
  `SCREEN_ACTION_DESCRIPTORS`, with its doc line.
- `ui/src/app/core/screen-actions.ts`: add `run: STRINGS.actionRun` to the shared `ACTION_LABELS`
  (7.6 reuses it).
- `ui/src/app/core/strings.ts`: append the two keys under Design Notes.
- `ui/src/app/core/screens.generated.ts`: regenerate with `screen-mirror.mjs`.
- `src/OcuPilot/Test/TaskRunFixture.cls` (new, not a test case, unarmed). All of these run in `%SYS`
  and hold no OREF:
  - `EnsureRunProbeTask(.id)` creates or reuses the task `OcuPilotProbeRunTask` (`RunLegacyTask`,
    `ExecuteCode` `Quit`, `TimePeriod` 5, `NameSpace` `%SYS`).
  - `AwaitRun(id, sinceHistoryId, budget, .elapsed)` polls every 5 s up to `budget` (180) for a
    `Success` history row newer than `sinceHistoryId`, reading fresh each time.
  - `NoLockHeld(id)` checks that `$Job` owns no lock on `^SYS("Task","TaskD",id)`.
  - `DeleteRunProbeTask()`.
- `src/OcuPilot/Test/TaskRun.cls` (new, unarmed, runs nothing), all through `ProposalFixture`:
  - Declarations: the tool's types, its subject, `SCREENACTIONS` `run`, the descriptor's composite
    id and its row action, and the registry admitting the tool.
  - `StateDiff`'s three arms.
  - A mint over a canned `INFO` answer: its rows, and `TARGETCHANGED` when `NextScheduled` moves.
  - `AdminPort.ConstantBody` for `Task.CRUD/RUN`, and `""` for `Task.CRUD/RESUME`.
- `src/OcuPilot/Test/TaskResume.cls` (armed; append two methods, each deleting the probe in its own
  frame):
  - `TestTheAgentsRunIsConfirmedAndLandsInTheTasksHistory`:
    - A real `Mint` and `Confirm` of `tasks.ondemand.run` on the probe answers `updated`, with one
      marker and one ledger row.
    - `INFO` `NextScheduled` is non-empty at once, and `NoLockHeld`.
    - `AwaitRun` passes within 180 s, and the `tasks.taskhistory` read for the id gains that row.
  - `TestTheScreenActionRunsTheTaskOverTheWire`:
    - HTTP as the test account answers 200 and the triple.
    - No marker and no ledger row.
    - `AwaitRun` passes.
- `src/OcuPilot/Test/ProhibitedRoute.cls` (append): as a principal holding `%DB_IRISSYS:R` and not
  `%Admin_Task:USE`, the Run screen action answers 403 naming `%Admin_Task:USE`, and the probe's
  `INFO` `NextScheduled` stays `""`.
- Roster moves. Our rows only, off Epic 8's hunks; read `git show origin/OCU-1-epic8:<path>` first:
  - `ToolWrite.cls`: a `TestTheTaskRunToolIsAnActionWriteOverTheScreensOwnPairs` method using
    `AssertActionWrite(…,"RUN",0)`.
  - `PortFixture.cls`: add `Task.CRUD/RUN`.
  - `SurfaceCoverage.cls`: add a row.
  - `ReadTool.cls`: count 57 and the name list.
  - `ToolRoundTrip.cls`: `tasks.ondemand.run:TOOL.ARGUMENTS`.
  - `Descriptor.cls:100` and `TaskLists.cls`: `NextScheduled`, the composite id and the row action.
  - `screen-mirror.test.mjs:849`.
- `ui/src/app/shell/screen-action-handler.spec.ts`: Run on `TaskOnDemandList` is sent at once,
  opens no dialog, and publishes the answered `task` change.
- `ui/browser/tasks.browser-spec.mjs:984-1004`: six headers (plus "Next run"), and Run is offered
  beside Refresh.
- `ui/browser/task-run.browser-spec.mjs` (new; `-ci` guard; the probe is created in `before` and
  deleted in `after`):
  - **Screen leg.** Filter to the probe, select it, and the row menu and command bar offer "Run".
    - Pressing it opens no dialog and sends one POST with the `Id`.
    - The row is marked changed in place, keeping its filter and selection, and Next run is
      non-empty.
    - A `Success` history row lands within 180 s. After Refresh, Last run is set.
  - **Agent leg.** The scripted turn proposes `tasks_ondemand_run`, and the card shows the
    `NextScheduled` row.
    - Confirm, and a new `Success` history row lands within 180 s.
    - The task's history screen shows it.

**Acceptance Criteria:**

- AC1: Given a row on On-demand tasks, when the user presses Run, then no dialog opens, the task
  runs (its history gains a `Success` row within one Task Manager pass), and the row updates in
  place. *Pin:* `task-run.browser-spec.mjs` screen leg, with the server-tier twin in `TaskResume`
  (CI).
- AC2: Given the run, when the agent proposes it instead, then it goes through a proposal and
  confirmation, is marked, and appears in that task's history. *Pins:* `TaskResume`'s agent method
  (CI) and the browser agent leg (local).
- AC3: Given a principal short of `%Admin_Task:USE`, when it sends Run, then the answer is 403
  naming that pair, before any read, and nothing is requested. *Pin:* `ProhibitedRoute`.
- AC4: Given a task, when the agent's run is minted, then the diff and the fingerprint cover
  `NextScheduled` and `Suspended`, a suspended task's diff also shows the resume, and a confirm after
  either field moved is refused `PROPOSAL.TARGETCHANGED`. *Pin:* `TaskRun`.
- AC5: Given the On-demand descriptor, when the registry and mirror build it, then its rows are keyed
  by `Id` and its empty state's second line invites the agent to create a task. *Pin:*
  `screen-mirror.test.mjs` and `Descriptor`.
- Integration AC (Rule 1): `ListPage` consumes the `task` change event this write publishes and
  re-reads the row in place, observed in the browser screen leg against a real throwaway.

### Review Findings

Code review 2026-09-23 (four layers, full-opus): 8 kept -- 0 high, 2 med, 6 low; 6 patched, 2 ledgered; 19 rejected. Patches verified on `ocupilot-ci`: `TaskRun` 6/6 (run 7988); `ProhibitedRoute` 22 passed, 1 skipped (the auditing method, as designed), 0 failed (run 7989). `TaskResume` compiles; it runs in CI only.

- [x] [Review][Patch] The run's "ledger records no field" check passed when the confirm wrote no ledger row at all [src/OcuPilot/Test/TaskRun.cls:186] -- it now asserts exactly one write ledger row first.
- [x] [Review][Patch] A caller body sent as JSON text was silently replaced by the constant [src/OcuPilot/Port/AdminPort.cls:508] -- any non-empty caller body is now refused 500, pinned by a leg in `TestThePortSendsRunsConstantBodyAndRefusesACallersBody`.
- [x] [Review][Patch] AC4's fingerprint half had no recorded mutation -- recorded under Verification.
- [x] [Review][Patch] The `TaskRun` test header said "the one call" to the shipped port (there are three), and the 404 message claimed the vendor validated the body [src/OcuPilot/Test/TaskRun.cls:7,228]
- [x] [Review][Patch] `TaskResume`'s header did not say the class now runs a task [src/OcuPilot/Test/TaskResume.cls:15]
- [x] [Review][Patch] `ProhibitedRoute`'s run leg did not assert the probe task is gone [src/OcuPilot/Test/ProhibitedRoute.cls]
- [x] [Review][Defer] Run from the list resumes a suspended task with no dialog -- DW-1542, by-design (spec Never: no dialog; the Suspended-target matrix row)
- [x] [Review][Defer] The two "NextScheduled is set at once" checks race a Task Manager pass -- DW-1543, wontfix-accepted

Rejected:

- false: `NoLockHeld` cannot go red. On `ocupilot-ci`, holding `^SYS("Task","TaskD",999999999)` in `%SYS` made it answer 0, and releasing the lock made it answer 1.
- false: the input schema's "a task the list does not report is refused" is never enforced. The on-demand set is every task (`TaskLists`), and an absent id fails `INFO`.
- false: `ProhibitedRoute` runs a task under the wrong arming variable. The refusal lands before the port, and the class already creates `TaskResume`'s probe.
- low: `StateDiff` refuses a numeric `Suspended`, which `TaskResume` accepts. `INFO` answers a JSON boolean (task 1 on `ocupilot-ci`).
- low: a string `"true"` passes as a boolean. The vendor sends a boolean.
- low: nothing checks that `CONSTANTBODIES` is well formed. A malformed entry turns `ToolWrite`'s bodyless-roster test red for its tool.
- low: a `;` inside a constant body would split the entry. No such body exists.
- low: the run legs do not check that the Task Manager is running. `tasks.browser-spec.mjs` restores it, and a suspended one turns the wait red anyway.
- low: `EnsureRunProbeTask` keeps a leaked probe's pending run. That run clears at the next pass.
- low: a failed `HistoryHighWater` could let an older Success row count. That also needs a reused probe id.
- low: a localized `Success` would not match. This build writes the literal.
- low: running a task that is already running queues a second run. That is the vendor's `RunNow`, as in the classic page.
- low: the fingerprint's `NextScheduled` refuses a confirm when a scheduled run fires in between. The refusal is safe, and AC4 names the field.
- low: `TaskRun` repeats six `TaskResume` members. Story 7.6 subclasses `TaskRun`, so no third copy is planned.
- low: the browser agent leg does not read the card's status, and it counts history rows by name. `AwaitRun` proves the confirm, and the history screen is scoped to the task id.
- low: the handler spec covers only the 200. The refusal path is the shared handler's, which 7.1-7.4 pin.
- low: the `REFUSEEMPTY` doc does not name the run. Its general sentence covers every write tool.
- spec: `TaskResume` is 736 lines, over the 500-line guideline. The spec puts the armed methods there because a new armed class is forbidden.
- process: `TaskResume`'s two new methods have not run yet. CI run 35858909423 decides that (Rule 28).

## Spec Change Log

- 2026-09-23, lead spec gate: the AD-51 sentence (a fixed vendor body comes from the port) is in the
  spine; the two strings are published at `EXPERIENCE.md:414-415` and appended to `strings.ts`
  (`taskOnDemandEmptyAgent`, `proposalEntityTask`; `npm run test:tools` 1,327/0) -- consume them.

## Review Triage Log

### 2026-09-23 — Review pass

- verdicts: 12 findings — high 0, medium 3, low 5, false 3, maybe-false 1
- findings:
  - `[medium]` `[patch]` The Integration AC had no `mutation:` line, and the screen leg never asserted Next run was empty before the press — added the empty-before check (`tableEmptyValue`), a Last-run-moved check after Refresh, and the mutation line below.
  - `[medium]` `[patch]` The browser agent leg's history-screen check passed on the screen leg's row, and `since` was unasserted — `since > 0` in both legs; the history screen must list more probe rows than `HistoryReadRows` read before the confirm.
  - `[medium]` `[patch]` `ProhibitedRoute`'s "nothing requested" compared two `InfoField` reads that both answer `""` on failure — `InfoField` gained `Output pRead`, and both reads are asserted to have answered.
  - `[false]` `[reject]` `ProhibitedRoute` creates a task outside the task-control roster — it already creates `TaskResume`'s probe (`:1373`); the task is the harmless `Quit` probe on an armed throwaway and runs only under a deliberate regression.
  - `[low]` `[patch]` The port test's fault-code check was skipped when no fault object came back — asserted the fault object first.
  - `[low]` `[reject]` A suspended task's resume is shown only as a diff row, not run live — a vendor fact measured at planning (Code Map); a third 180 s armed run buys no coverage of OcuPilot code.
  - `[low]` `[patch]` The mint-level unreadable-state refusal did not check the problem names the state — asserted `detail.problem` contains "suspended".
  - `[false]` `[reject]` Kill-switch and read-only gating are not exercised — they live in `Kernel/Agent/Loop.Boundary` for every write tool, which this diff does not touch.
  - `[maybe-false]` `[reject]` The agent caller's `task` change event is not asserted — published by the unchanged confirm path every write tool shares; settled by a browser assertion on the list row after Confirm; if true it is low.
  - `[low]` `[reject]` "The screen caller mints no proposal" is not asserted directly — `ScreenAction.Run` (unchanged) calls `Operation.Apply`, never `Mint`; no everyday path to the defect.
  - `[low]` `[reject]` The screen caller's server twin does not read `NextScheduled` — the browser screen leg observes it and the agent twin reads it.
  - `[false]` `[reject]` The port test infers "vendor not called" — 500 against the vendor's own 404 for the same absent id (the bodyless leg) discriminates the two.

## Design Notes

**Governing ADs:**

- AD-53 (one operation, two callers), AD-51 (action write, declared subject), AD-56 (ii) (only
  `{action,id}`).
- AD-2 and AD-27 (a vendor wire fact lives in the port), AD-8 (screen pairs at `USE`), AD-10 (`task`
  is covered and Run is not prohibited).
- AD-13 (`task:integer`), AD-14, AD-15, AD-30, AD-34.
- AD-36 (`INFO` is truthful; the `LIST` coerces `Suspended`), AD-39.
- AD-43 (On-demand is not on the roster; a live `task` proposal pauses the schedule and details
  screens through the framework), AD-44.

**Lock trap.** The vendor's `RunRun` holds its task OREF only as a local, which is released when it
returns. The path runs at `$TLEVEL` 0, so the trap bites only if OcuPilot code opens the task and
holds it across `Invoke`, or wraps the write in a transaction. `NoLockHeld` pins the first directly.
The 180 s wait turns either one into a red test rather than a hang.

**For the lead (Rule 20; recommended, not blocking).** AD-51 says an action write "sends no body".
`RUN`'s body is a caller-independent vendor constant, so it is kept in the port as `RENAMEDTYPES`
keeps a key. Recommended sentence for AD-51:

> *"A vendor type that requires a fixed body no caller supplies (`Task.CRUD` `RUN`'s
> `{"RunNow":true}`) takes it from the port, keyed by endpoint and type; the tool still sends no
> body, and the ledger records none."*

**Run resumes a suspended task.** This was measured, so the diff shows it rather than refusing. The
row label `NextScheduled` is `STATEFIELD`, and both labels are subject names, so
`Prohibited.ReviewedFewOnly` passes them. Golden rows: `{"field":"NextScheduled","before":"","after":"now"}`
and `{"field":"Suspended","before":"true","after":"false"}`.

**The Next run column** makes the in-place update visible at the write. Last run changes only after
the Task Manager's pass, which the list does not auto-refresh.

**Consumes:**

- 5.11: the `INFO` action-write pattern and the `TaskResume` helpers.
- 6.5: `TaskOnDemandList`.
- 6.6: the `tasks.taskhistory` read.
- 7.1: `ScreenAction`, `Operation` and the handler.

**Consumed-by:**

- 7.6: a `TaskRun` subclass on `TaskScheduleList`, the shared `run` label, `CONSTANTBODIES`,
  `TaskRunFixture` and `proposalEntityTask`.

**Copy for the lead to publish** (EXPERIENCE.md Fixed strings row, plus a `strings.ts` append):

| key | wording | row note |
| --- | --- | --- |
| `taskOnDemandEmptyAgent` | "create a task that runs on demand" | resolves `:315`'s invitation on On-demand tasks, which 7.5's Run makes write-capable. It names create, the task editor's action (orchestrator ruling), and supersedes `:369`'s read-only second line for this list. |
| `proposalEntityTask` | "Task" | the proposal card's noun for a task (UJ-6 "Proposal · Task Nightly purge") |

Reused: `actionRun`, `taskColumnNextRun`.

## Verification

Task runs happen only on the throwaway `ocupilot-ci` (web 52776), with the probe task.

- Run one test class per call, and never re-submit.
- Load changed classes onto `ocupilot-ci` as 7.4 did.
- Never stop, remove or recreate any container.

**Targeted (loop):**

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.TaskRun`, then
  one call each for `ToolWrite`, `Descriptor`, `TaskLists`, `SurfaceCoverage`, `ReadTool`,
  `ToolRoundTrip` and `ProhibitedRoute`. Each must be green.
- `TaskResume` refuses on the reused `ocupilot-ci`. CI's fresh throwaway runs it, and its result is
  read from CI. A refusal is not a pass.
- `cd ui && npm run test:tools && npm run test:components` must be green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`,
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node
  --test --test-concurrency=1 browser/task-run.browser-spec.mjs browser/tasks.browser-spec.mjs`.
  It must be green, and afterwards no `OcuPilotProbeRunTask` may remain.
- `uv run scripts/check-objectscript.py` on the changed paths must be clean.
- Rule 19: record one `mutation:` line per AC. Expected shapes:
  - AC1: drop `TaskOnDemandList` from `SCREEN_ACTION_DESCRIPTORS` → the browser screen leg goes red.
  - AC2: `TaskRun` `WRITETYPE` `INFO` → the browser agent leg's history wait goes red.
  - AC3: skip the pair `Gate` in `ScreenAction.Run` on `ocupilot-ci` → the `ProhibitedRoute` leg
    goes red.
  - AC4: `StateDiff` without the `Suspended` row → `TaskRun` goes red.
  - AC5: `emptyAgentKey` `""` → `screen-mirror.test.mjs` goes red.
  - The port: remove `CONSTANTBODIES` → `TaskRun`'s constant-body test and the browser screen leg
    (vendor 400) go red.
- Recorded (implement, `ocupilot-ci`; each applied, observed red, reverted, tree unchanged):
  - `mutation: dropped TaskOnDemandList from SCREEN_ACTION_DESCRIPTORS, rebuilt and redeployed → red: task-run.browser-spec.mjs screen leg ("the command bar offers Run") and screen-action-handler.spec.ts's Run case (AC1)`
  - `mutation: TaskRun WRITETYPE "INFO", reloaded → red: task-run.browser-spec.mjs agent leg, "a Success history row lands within 180 s (waited 180.27 s)" (AC2)`
  - `mutation: skipped the first pair-Gate refusal in ScreenAction.Run, reloaded → red: ProhibitedRoute.TestAnAccountShortOfTheTaskPairIsRefusedTheRunScreenAction, with the auditing and web-app screen-action legs (AC3)`
  - `mutation: StateDiff without the Suspended row → red: TaskRun.TestTheStateDiffAnswersItsThreeArms and TestTheMintCarriesTheRowsFromTheInfoRead (AC4)`
  - `mutation: emptyAgentKey "" on TaskOnDemandList → red: screen-mirror.test.mjs, the generator refusing the write-capable list (AC5)`
  - `mutation: CONSTANTBODIES "" → red: TaskRun.TestThePortSendsRunsConstantBodyAndRefusesACallersBody and the browser screen leg (the port refuses the bodyless RUN 500, so the row never marks) (port)`
  - `mutation: RefreshService.onBusEvent without its readNow(), rebuilt and redeployed → red: task-run.browser-spec.mjs screen leg, Next run never fills after the press (Integration AC)`
  - `mutation: TaskRun FINGERPRINTSUBJECT "Suspended", reloaded on ocupilot-ci → red: TaskRun.TestAConfirmAfterEitherFieldMovedIsRefused, the NextScheduled-moved leg confirms (AC4, code review)`
  - `mutation: AdminPort.Invoke's constant-body guard back to $IsObject(pBody) only, reloaded → red: TaskRun.TestThePortSendsRunsConstantBodyAndRefusesACallersBody, "as the same port fault" reads 404 (port, code review)`

**Once, before `dev_complete`:**

- Run the full ObjectScript sweep on `ocupilot-ci`, per class, with totals from the
  numeric-run-index probe.
- Run `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`. Every check must
  execute and pass.
- The full browser suite is not run locally (Rule 29).

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `tasks.ondemand.run` (`Screen/Tool/TaskRun.cls`) is an `INFO`-read, `RUN`-written action
write with two callers: the On-demand list's Run row action and the agent's proposal. `AdminPort`
admits `Task.CRUD/RUN` and keeps its `{"RunNow":true}` body in `CONSTANTBODIES`, refusing a caller
body as a port fault. `TaskOnDemandList` is keyed by `Id`, declares Run, shows Next run and invites
the agent when empty; the client registers the list and the shared `run` label.

**Files.** Port `AdminPort.cls`; tool `TaskRun.cls` (new); descriptor `TaskOnDemandList.cls`;
client `screen-action-handler.ts`, `screen-actions.ts`, `screens.generated.ts` (regenerated); tests
`TaskRun.cls` and `TaskRunFixture.cls` (new), two methods in armed `TaskResume.cls`, one in
`ProhibitedRoute.cls`, roster rows in `ToolWrite`, `PortFixture`, `SurfaceCoverage`, `ReadTool`,
`ToolRoundTrip`, `Descriptor`, `TaskLists`, `screen-mirror.test.mjs`; `screen-action-handler.spec.ts`;
browser `task-run.browser-spec.mjs` (new) and `tasks.browser-spec.mjs` (seven headers, Run beside
Refresh).

footprint_extensions: `AdminPort.cls`, `ToolWrite.cls`, `PortFixture.cls`, `SurfaceCoverage.cls`,
`ReadTool.cls`, `ToolRoundTrip.cls`, `ProhibitedRoute.cls`, `ui/tools/screen-mirror.test.mjs`,
`screens.generated.ts` -- this story's own members only (roster rule, 2026-09-23).

**Review.** 12 findings: 5 patched (3 medium, 2 low: test strengthening in the browser legs,
`InfoField`'s read flag, two port/mint assertions), 7 rejected (3 false, 1 maybe-false, 3 low);
none deferred. Follow-up review: false -- every patched entry was re-run green and the Integration
AC's new mutation went red.

**Verification** (`ocupilot-ci`):

- ObjectScript sweep, once: 182 classes, 1,646 methods, 1,645 passed, 0 failed (numeric-run-index
  probe, runs 7803-7984); `AuditingUpdate`, `ErrorDelete`, `ProcessControl`, `TaskResume` refuse
  here as armed classes. Targeted after patching: `TaskRun` 6/0, `ProhibitedRoute` 23/0.
- `smoke.sh`: executed 49, passed 49. `test:tools` 1,327/0, `test:components` 880/0,
  `check-objectscript` clean, build green.
- Browser (rebuilt, redeployed): `task-run.browser-spec.mjs` 2/2; no `OcuPilotProbeRunTask` remains.
  `tasks.browser-spec.mjs` 12/14: the two Task history tests (6.6 AC1, AC3) miss the demo row among
  49 `OcuPilotDemo` matches left by other classes' probes (history ids 1962-2249, before this
  story's first probe row 2301; none of this story's rows match the search). CI's fresh throwaway
  does not carry them (inference).
- Rule 19: seven `mutation:` lines under `## Verification`, each observed red and reverted.

**Residual risk.** `TaskResume`'s two new methods have only compiled locally; their result is read
from CI.
