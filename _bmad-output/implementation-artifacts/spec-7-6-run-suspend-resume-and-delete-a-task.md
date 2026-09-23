---
title: 'Story 7.6: Run, suspend, resume and delete a task'
type: 'feature'
created: '2026-09-23'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-7-5-run-an-on-demand-task.md'
warnings: ['oversized']
deferred: []
footprint_extensions: # planned; this story's own members only (roster rule, 2026-09-23)
  - 'src/OcuPilot/Port/AdminPort.cls' # shared-append: three parameter lines gain entries
  - 'src/OcuPilot/Kernel/Proposal/Prohibited.cls' # contended; only if Q4 is answered "refuse"
  - 'ui/src/app/core/navigation.ts' # Epic 8 modified; only under Q1's answer
  - 'ui/tools/navigation.test.mjs' # Epic 8's pin at :963; only under Q1's answer
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

**Problem:** The Task schedule list has no row actions. A stopped task can be resumed only by the
agent (5.11), and nobody can run, suspend or delete a scheduled task. UJ-6 still sends the agent to
the schedule list instead of Task details.

**Approach:** Add three action-style writes on `TaskScheduleList`, and give 5.11's resume a screen
action. Each write has two callers (AD-53): the row action through
`POST /screens/tasks.schedule/action`, and the agent's proposal.

- `tasks.schedule.run` is a `TaskRun` subclass.
- `tasks.schedule.suspend` is new.
- `tasks.schedule.resume` is `TaskResume` plus `SCREENACTIONS`.
- `tasks.schedule.delete` is new.

Then replay UJ-6 against Task details.

## Boundaries & Constraints

**Always:**

- **Vendor quirk, from the owner (verbatim):** "The task list's `Suspended` field does not reflect
  a suspend or resume that has just been applied, while the task's own info read does. So the
  in-place row update **and the write's VERIFICATION** must both read task info, never the list's
  field. A verification that reads the list field sees stale data — which fails a correct write,
  or worse passes a wrong one."
- The screen caller mints no proposal, emits no marker, writes no ledger row, and is not gated by
  the kill switch or read-only mode. The agent's caller does all of those.
- Check the screen's own pairs, `%Admin_Task:USE` and `%DB_IRISSYS:READ`, before any read (AD-8).
- Publish one `task` change event per write. Re-fetch; never patch.
- The target is the numeric `Id` (`task:integer`).
- Hold no `%SYS.Task` OREF and no transaction across a write (the `RunNow` lock trap).
- Every string goes to Fixed strings and `strings.ts`, appended only.
- Any test that writes a task uses a probe it creates and deletes itself, on a throwaway only.

**Never:**

- No dialog before Run, Suspend or Resume. Only Delete opens one.
- No new armed test class, and no edit to `scripts/ci-*.sh`, `ci.yml`, `Write.cls`,
  `Operation.cls`, `Mint.cls`, `Confirm.cls`, `Registry.cls` or `Classification.cls`.
- No actions on Task details. It keeps `rowActions []`.
- Never write the demo task or any vendor task.
- No Task Manager suspend or resume (16.11).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|----------|--------------|----------|-------|
| Suspend | running probe; Suspend | no dialog. 200 `{action:"updated",target:{type:"task",scope:"instance",id}}`. The row re-reads through its `INFO` rowGet: Status reads Suspended, and the row is marked changed | – |
| Resume | suspended probe; Resume | the same, with Status Scheduled. History gains `Result` "Resumed task", `Username` the caller | – |
| No-op | Suspend a suspended task, or Resume a running one | refused 422 with `detail.problem`. Nothing sent | vendor would answer 200 and log a history row |
| Delete | probe; Delete; typed name | dialog "Delete <Name>" plus the consequence. On a match, 200 `deleted`. The row leaves, and focus returns to the grid | mismatch: "Does not match", nothing sent |
| Run | probe; Run | as 7.5: Next run set at once, a `Success` row within 180 s | – |
| Agent suspend or delete | proposal | suspend diff `Status: Scheduled → Suspended`. Delete removal rows `Name`, `TaskClass`, `NameSpace` | `PROPOSAL.TARGETCHANGED` if the subject moved |
| System task delete (Q4) | a `Type` System task | refused on the instance, whoever calls. The row action is drawn unavailable with the reason | nothing deleted |
| Short of the pair | no `%Admin_Task:USE` | 403 `AUTH.NOPRIVILEGE`, failedPair `%Admin_Task:USE`, before any read | probe unchanged |

</intent-contract>

## Code Map

Measured on `ocupilot-ci` on 2026-09-23. The probes were `OcuPilotProbe76` (id 1266) and a
`Type` 0 probe (id 1268); both were created and deleted.

- **Vendor `Task.CRUD` (`[Hidden]`)**
  - Request types: `TYPERESUME` 14 is `POST /task/resume`. `TYPESUSPEND` 15 is
    `POST /task/suspend`. `DELETE` is `DELETE /task`. Each takes `?id=`.
  - `RunSuspend` calls `Suspend(id, LeaveInQueue ? 1 : 2)`. `NeedsRequestBody` is true for
    SUSPEND. Its schema is `{"LeaveInQueue":false}`, and the key is optional. With no body the call
    answers 415, and an unknown key answers 400.
  - `RunDelete` calls `%DeleteId`, and its comment says it "allows system tasks". Its
    `NeedsRequestBody` is false.
  - `ResourcesOR`: RESUME and SUSPEND answer `%Admin_Task`. DELETE answers `%Admin_Task` or
    `%Admin_Operate`.
  - Unknown id: 404 `#5809`. A delete answers 200 `{}`, after which `INFO` answers 404.
- **What each action leaves behind**
  - Every suspend or resume writes a `%SYS.Task.History` row, including a no-op one. `Result` is
    "Suspended task" or "Resumed task", and `Username` is `$username`.
  - A delete writes "Delete <Name>", and the rows survive the delete. HISTORY serves them as
    `Result` and `Username`.
  - The audit event is `%System/%System/ConfigurationChange`, for example "Suspend task X" with
    the user.
- **`INFO` versus the list**
  - `INFO` answers `Type` (System or User), `Status`, `Error`, `LastSchedule`, `LastStarted`,
    `LastFinished`, `NextScheduled` and a boolean `Suspended`. Suspend and resume leave
    `NextScheduled` alone.
  - The list's `Suspended` is always false (`TreatColumnAsBoolean` over display text).
  - `GET` answers `Name`, `TaskClass`, `NameSpace`, `Description` and the schedule, with no
    `Suspended` or `Type`.
- **Task names and system tasks**
  - `Name` has no unique index.
  - The classic page (`%CSP.UI.Portal.TaskInfo:88-92`) disables Delete when `Type` is 0. A fixture
    can create a `Type` 0 task. That `INFO` then reads `Type` "System" is an inference from vendor
    task 4.
- **Tools**
  - `Screen/Tool/TaskResume.cls` is `tasks.schedule.resume` on `TaskScheduleList`. It has no
    `SCREENACTIONS`, and its `STATEFIELD` is `Status` (Suspended→Scheduled, `:75-79`).
    `ReadsSuspended` is at `:177`.
  - `TaskRun.cls:19` holds 7.6's subclass promise. `WebAppDelete.cls:45-49,123` is the delete
    template.
- **Port**
  - `AdminPort.cls`: `MUTATINGTYPES` `:197`, `BODYLESSTYPES` `:213`, `CONSTANTBODIES` `:237`
    (`;`-separated).
  - Epic 8 rewrites the first two lines and adds `VERIFIEDDELETES` and `VERIFIEDWRITES` (re-read
    `GET`) and `PORT.NOTAPPLIED`, none of which is on this branch.
- **Descriptors**
  - `TaskScheduleList.cls:70-126` has an id of `composite ["Id"]` and `rowActions []`. It has no
    `entityLabelKey`. Its `emptyNextKey` is `tableReadOnlyEmptyNext` and its `emptyAgentKey` is
    `""`.
  - Its read is `LIST` plus a `rowGet` `INFO` for `Suspended`, which is not yet a column. Its doc at
    `:62-66` names 7.6.
  - `TaskDetails` shows `Suspended` (kind `status`). It has no Status field.
- **Registry**
  - `TableProblem` `:1917-1932`: a write-capable list has an empty `emptyNextKey` and an
    `emptyAgentKey`.
  - `FingerprintSubjectProblem` `:2100`.
  - The self-protection vocabulary is `serves-ocupilot,protected-account` (`:2186`).
  - The task arm of `Prohibited.cls` (`:665`) refuses nothing.
- **Client**
  - `shell/screen-action-handler.ts`:
    - roster `:31-38`
    - `DESTRUCTIVE_CONSEQUENCES` `:94-99`
    - the typed target is the row key (`:371`), so the numeric `Id` today
    - send `:334-368`
  - `core/screen-actions.ts:61-73` has no `suspend` or `resume`. `STRINGS.actionSuspend` and
    `actionResume` exist.
- **Toast**
  - `core/toasts.ts:189` returns nothing when `openScreenShows`, so no toast is raised on Task
    details.
  - The target is `navigation.ts:450` `screenForChange`, and for `task` that is the first built
    screen, Task details. Epic 8 pins it at `navigation.test.mjs:963`.
- **Details highlight** comes from `core/detail-highlights.ts`, wired at `details.page.ts:178`.
- **Navigation**
  - The route is chosen by the model.
  - The UJ-6 "one line" is `ui/browser/task-resume.browser-spec.mjs:221`, with assertions at
    `:346-399` and `:455-470`.
  - `agent-navigator.ts:92-110` announces the destination screen's label.
- **Tests**
  - `Test/TaskResume.cls` (armed by `OCUPILOT_ALLOW_TASK_CONTROL`, 739 lines).
  - Its helpers are `EnsureProbeTask` `:468`, `SuspendProbeTask` `:509`, `InfoSuspended` `:550`,
    `HistoryRowsForTask` `:590` and `ResumeHistoryUser` `:618`.
  - `TaskRunFixture` (unarmed).
- **Rosters**
  - `ToolWrite` `:1026-1028,:1053,:1113-1124` assert that `Task.CRUD/SUSPEND` is **not** mutating
    and that the port answers 501. Re-point those to `Task.CRUD/PATCH`.
  - `ReadTool :93-94` goes from 57 to 60.
  - `SurfaceCoverage :101-114`, `ToolRoundTrip :33`, `PortFixture :21`, `Descriptor :102,:533`,
    `ProhibitedRoute :1360`.
  - `screen-mirror.test.mjs:849-859` is the On-demand template.
  - `tasks.browser-spec.mjs:318-325` holds the schedule headers.
  - `screen-action-handler.spec.ts:420-442` is the Run case.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/AdminPort.cls` (append entries only; no change to `Invoke`):
  - `MUTATINGTYPES` gains `Task.CRUD/SUSPEND` and `Task.CRUD/DELETE`.
  - `BODYLESSTYPES` gains `Task.CRUD/DELETE`.
  - `CONSTANTBODIES` gains `;Task.CRUD/SUSPEND={"LeaveInQueue":true}`.
  - The doc paragraph names each measured fact.
- `src/OcuPilot/Screen/Tool/TaskScheduleRun.cls` (new) extends `TaskRun`. It overrides `TOOLNAME`
  (`tasks.schedule.run`) and `DESCRIPTORCLASS` (`…TaskScheduleList`) and nothing else.
- `src/OcuPilot/Screen/Tool/TaskSuspend.cls` (new) is `TaskResume` inverted:
  - `SCREENACTIONS` `suspend`, `WRITETYPE` `SUSPEND`, `READTYPE` `INFO`, `SENDSBODY` 0,
    `DESTRUCTIVE` 0.
  - `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` are `Suspended`.
  - `STATEFIELD` `Status`, going from `Scheduled` to `Suspended`.
  - `StateDiff` refuses a task that is already suspended, or whose state it cannot read.
- `src/OcuPilot/Screen/Tool/TaskResume.cls`: add `Parameter SCREENACTIONS = "resume"` and update
  its doc.
- `src/OcuPilot/Screen/Tool/TaskDelete.cls` (new), with `WebAppDelete`'s shape:
  - `READTYPE` `GET`, `WRITETYPE` `DELETE`, `CHANGEACTION` `deleted`, `DESTRUCTIVE` 1.
  - `%Admin_Task:USE`.
  - `PRECONDITIONFIELD` `Name`. `FINGERPRINTSUBJECT` and `READANSWERS` are
    `Name,TaskClass,NameSpace`.
  - The removal rows are those three fields.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (only if Q4 is answered "refuse"):
  - The task arm refuses a `DELETE` whose target's `INFO` `Type` is `System`, with code
    `PROHIBITED.SYSTEMTASK` and the reason from Q4. Read `git show origin/OCU-1-epic8:<path>` first
    and stay off Epic 8's hunks.
  - Add the self-protection rule `system-task` (Registry vocabulary, mirror and client). That touches
    `Registry.cls`, so it goes to the lead with Q4.
- `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls`:
  - `rowActions` in the order `run`, `suspend`, `resume`, `delete`, destructive last.
  - `entityLabelKey` `proposalEntityTask`.
  - `emptyNextKey` `""` and `emptyAgentKey` `taskScheduleEmptyAgent`.
  - Add the column `{"field":"Suspended","labelKey":"taskColumnSuspended","kind":"status"}`, fed
    by the existing `INFO` rowGet and never by the list's field.
  - Rewrite the doc at `:62-66`.
- `ui/src/app/core/screen-actions.ts`: add `suspend: STRINGS.actionSuspend` and
  `resume: STRINGS.actionResume`.
- `ui/src/app/shell/screen-action-handler.ts`:
  - Add `TaskScheduleList` to the roster.
  - Add `DESTRUCTIVE_CONSEQUENCES.TaskScheduleList = {delete: STRINGS.taskDeleteConsequence}`.
  - Add `TYPED_NAME_FIELDS = {TaskScheduleList: 'Name'}`. The dialog title, the button and the
    typed match use the selected row's `Name`. The POST still carries the `Id` (Q3).
- `ui/src/app/core/strings.ts`: append the Design Notes keys. Then regenerate
  `screens.generated.ts`.
- Q1 (toast), only under its recommended answer:
  - `navigation.ts` `screenForChange` resolves to the listed screen of the type.
  - `toasts.ts` suppresses only when the open screen is that target.
  - Update Epic 8's `:963` pin under the contended-edit discipline.
- `src/OcuPilot/Test/TaskScheduleActions.cls` (new, unarmed, runs nothing, through
  `ProposalFixture`):
  - Every tool's declarations.
  - `TaskScheduleRun` differs from `TaskRun` only in its two parameters.
  - `StateDiff` arms for suspend and delete.
  - A mint over a canned read, and `TARGETCHANGED`.
  - `ConstantBody("Task.CRUD","SUSPEND")`.
  - Under Q4, the system-task refusal is exercised on a `Type` 0 probe it creates.
- `src/OcuPilot/Test/TaskRunFixture.cls`: add `EnsureScheduleProbeTask` (daily at 03:00,
  `OcuPilotProbeScheduleTask`) and `DeleteScheduleProbeTask`. They hold no OREF.
- `src/OcuPilot/Test/TaskResume.cls` (armed, append):
  - The screen actions over HTTP on the probe:
    - Suspend, then `InfoSuspended` is 1.
    - Resume, then it is 0, and the history gains "Resumed task" by the test account (AC2).
    - Delete, then `INFO` answers 404 and the history is kept.
  - A real `Mint`/`Confirm` of `tasks.schedule.delete`, with one marker and one ledger row.
  - Every check reads `INFO`, never the list.
- Rosters:
  - `ProhibitedRoute`: a short-of-pair Suspend leg.
  - `ToolWrite`: three `AssertActionWrite` tests, plus the re-point.
  - `PortFixture`, `SurfaceCoverage`, `ReadTool` (60), `ToolRoundTrip` (×3), `Descriptor`,
    `screen-mirror.test.mjs`.
- `ui/src/app/shell/screen-action-handler.spec.ts`:
  - Suspend and Resume are sent at once.
  - Delete opens the dialog naming the `Name`, and sends the `Id`.
- Browser specs:
  - `ui/browser/tasks.browser-spec.mjs`: the schedule headers gain Suspended and Actions.
  - `ui/browser/task-schedule-actions.browser-spec.mjs` (new; `-ci` guard; probe created in
    `before`, deleted in `after`):
    - Run, Suspend, Resume and Delete from the row menu and the command bar.
    - After each action, wait for the rowGet to land before reading the Suspended cell.
    - The Task history screen shows "Resumed task" and the user.
  - `ui/browser/task-resume.browser-spec.mjs` (UJ-6 replay):
    - The scripted navigation is `{route:'tasks/schedule/details', entityId}`.
    - Heading: "Task details — opened by the agent; Back returns".
    - After Confirm, the Suspended field is marked Changed within 2 s.
    - The toast "Open in Task schedule" opens the list with the row selected.

**Acceptance Criteria:**

- AC1: Given a selected probe task on Task schedule, when the user runs, suspends, resumes or
  deletes it, then each action updates the row in place. The Suspended cell is read through
  `INFO`. Delete names the task and requires its typed name. *Pin:*
  `task-schedule-actions.browser-spec.mjs`.
- AC2: Given a suspended task, when the user resumes it, then the task's history shows "Resumed
  task" by that user. *Pins:* `TaskResume` (CI) and the browser leg.
- AC3: Given UJ-6, when the agent navigates, then it lands on Task details, the Suspended field
  highlights on confirm, and a toast offers "Open in Task schedule" (Q1, Q2). *Pin:*
  `task-resume.browser-spec.mjs`.
- AC4: Given each new tool, when it is minted, then the diff and the fingerprint cover its declared
  subject, and a moved subject is refused. *Pin:* `TaskScheduleActions`.
- AC5: Given a principal short of `%Admin_Task:USE`, when it sends Suspend, then the answer is 403
  before any read. *Pin:* `ProhibitedRoute`.
- Integration AC (Rule 1): `ListPage` and Task details consume the `task` change event. They
  re-read through `INFO`, marking the row or field. This is observed in the browser against
  `ocupilot-ci`.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-53, AD-51 (as amended 2026-09-23), AD-56 (ii), AD-6, AD-8 and AD-10, AD-13 and AD-14, AD-15.
- AD-34, AD-36 (`INFO` is truthful; the `LIST` coerces `Suspended`), AD-39.
- AD-43 (Task schedule and Task details are on the roster; a live proposal pauses their refresh),
  AD-52.

**Suspend body.** The vendor's default, `LeaveInQueue` true (a `Suspended` value of 1), is sent
explicitly as a port constant (AD-51 amendment).

**The Suspended column** makes suspend and resume visible in the row. It reuses the published key
`taskColumnSuspended`. The lead adds it to EXPERIENCE `:102`'s column list.

**Consumes:**

- 5.11: `TaskResume` and its helpers.
- 6.5, 6.6 and 6.7: the lists and Task details.
- 7.1: the seam and the typed-name dialog.
- 7.5: `TaskRun`, `CONSTANTBODIES`, `TaskRunFixture`, `actionRun` and `proposalEntityTask`.

**Consumed-by:** none within Epic 7. 16.11 adds the Task Manager controls to the same list.

**Copy for the lead to publish** (a Fixed strings row and a `strings.ts` append):

| key | wording | note |
| --- | --- | --- |
| `taskDeleteConsequence` | "Deleting this task removes it from the schedule, so it no longer runs. Its history is kept. This cannot be undone." | measured: history outlives the task |
| `taskScheduleEmptyAgent` | "create a task that runs on a schedule" | names create (orchestrator ruling) |
| `taskSystemDeleteRefused` (Q4) | "This is one of the instance's own system tasks. Deleting it is not available here." | caller-neutral, like 7.2's |

Reused keys: `actionRun`, `actionSuspend`, `actionResume`, `actionDelete`, `taskColumnSuspended`,
`proposalEntityTask`.

**Intent gaps for the lead.** The spec above is planned as if each recommendation is adopted.

- **Q1: AC3's toast cannot appear as worded.**
  - *Evidence:*
    - `toasts.ts:189` raises nothing when the open screen shows the entity, per EXPERIENCE `:446`
      ("only for changes to entities whose screen is not open"). Task details shows `task`, so UJ-6
      step 5 gets no toast.
    - The toast target is Task details, which Epic 8 pinned deliberately
      (`navigation.test.mjs:963`, "a task change opens its details").
  - *Recommended (cross-epic, ask first):* a change toast opens the entity's **listed** screen,
    which is what "navigates with the entity selected" needs. It is suppressed only when that screen
    is open. The PRD's UJ-6 climax requires this ("a toast links to the row in the task list").
    This also moves the process and database toasts to their lists (inference).
    EXPERIENCE `:446` and `:673` are amended, and so is Epic 8's pin.
  - *Alternative:* drop AC3's toast clause (a narrowing).
  - The toast text stays the generic "Task <id> was updated"; "Resumed Nightly purge" is not
    reachable without a name lookup.
- **Q2: "Status field" (tier 1).** Task details has no Status field. The task's state is its
  `Suspended` field, which is of kind `status`. Restate AC3 and UJ-6 step 5 as "the Suspended field
  highlights".
- **Q3: the typed name.** The epic context says "Row key and typed name use the vendor's IdKey",
  which here means typing a number. AC1, FR-51, EXPERIENCE `:110` and `:453` ("Delete Nightly
  purge") all name the task. *Recommended:* type the `Name` for this list only, through a
  per-descriptor client map, and keep the `Id` on the wire. `Name` is not unique, but the selection
  already fixes the target.
- **Q4: deleting system tasks.**
  - The admin API deletes a `Type` System task. The classic page refuses to (`TaskInfo:92`).
    Deleting "Purge Journal", for example, silently stops the purge.
  - *Recommended:* refuse it on the instance, through a new AD-10 bullet (Rule 20), a `Prohibited`
    predicate and a `system-task` self-protection rule, which is a Registry edit.
  - *Alternative:* allow it, as the API does.
- **Q5: DW-1463 (addressed; decision needed).**
  - *Measured:* no model output follows a confirm. The confirm is a user request outside any turn
    (AD-7, AD-40). `Confirm.Answer` reaches only the panel, and later turns replay only the user
    message and the final reply (AD-24, `Convo.HistoryMessages:149-185`).
  - So 5.11's "the agent's reply names the next run and offers the audit entry", and UJ-6 step 5's
    last sentence, have no producer.
  - The fifth clause ("cites that history row by name") is model behavior over the shipped
    `tasks.taskhistory.read`, with no deterministic OcuPilot surface.
  - *Recommended:* amend both clauses out of 5.11 and UJ-6, noting that the toast and the
    transcript carry the change, and close DW-1463 `dropped`.
  - *Alternative:* a post-write `INFO` re-read in `Confirm.Answer`, with "Next run <time>" rendered
    on the closed card. That touches the contended `Confirm.cls` and `proposal-card.ts`.
- **Q6: "the write's VERIFICATION".**
  - *Read here as:* every check that a write landed reads `INFO`. That covers the row (the rowGet
    column) and every test and spec.
  - No runtime port re-read is added. Every measured SUSPEND and RESUME answered truthfully, and the
    runtime mechanism (`VERIFIEDWRITES`, `PORT.NOTAPPLIED`) is Epic 8's. Once it merges, a task entry
    there must re-read `INFO`, not `GET`.
  - If the owner means runtime verification now, that is a new `AdminPort` hook in `Invoke` plus an
    error code of Epic 8's.

## Verification

Writes happen only on `ocupilot-ci` (web port 52776), using the probe tasks. Run one test class per
call and never re-submit. Never stop, remove or recreate a container.

**Targeted (loop):**

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.TaskScheduleActions`
  must be green. Then run one call each for `ToolWrite`, `Descriptor`, `SurfaceCoverage`,
  `ReadTool`, `ToolRoundTrip`, `PortFixture`, `TaskRun` and `ProhibitedRoute`.
- `TaskResume` refuses on the reused `ocupilot-ci`. CI runs it; a refusal is not a pass.
- `cd ui && npm run test:tools && npm run test:components` must be green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`,
  then
  `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/task-schedule-actions.browser-spec.mjs browser/task-resume.browser-spec.mjs browser/tasks.browser-spec.mjs`.
  It must be green, with no probe task left afterwards.
- `uv run scripts/check-objectscript.py` must be clean on the changed paths.
- Rule 19 requires one `mutation:` per AC. Expected shapes:
  - AC1: the Suspended column fed by the list field (drop the rowGet) turns the browser suspend
    leg red.
  - AC2: `TaskResume` `SCREENACTIONS` `""` turns the resume leg red.
  - AC3: revert the navigation route turns the replay red.
  - AC4: `TaskSuspend` `StateDiff` without its refusal turns `TaskScheduleActions` red.
  - AC5: skip the pair gate turns `ProhibitedRoute` red.

**Once, before `dev_complete`:** run the full ObjectScript sweep on `ocupilot-ci` per class, with
totals from the numeric-run-index probe. Then `bash scripts/smoke.sh --container ocupilot-ci --user
_SYSTEM --password SYS`. There is no local full browser suite (Rule 29).

## Auto Run Result

Status: blocked
Blocking condition: intent gap — Q1 (AC3's toast is suppressed on Task details by EXPERIENCE `:446`, and its target is pinned to Task details by Epic 8 at `navigation.test.mjs:963`; cross-epic toast-target decision), Q2 (AC3 names a "Status field" Task details does not have; tier-1 restatement to "Suspended field"), Q3 (typed name: epic-context IdKey rule vs FR-51 "naming the task"), Q4 (refuse deleting system tasks — an AD-10 addition — or allow), Q5 (DW-1463: no agent reply follows a confirm; amend 5.11/UJ-6 and drop, or add a confirm re-read), Q6 (reading of "the write's VERIFICATION"). Recommendations and evidence are under Design Notes; the spec is planned as if each is adopted.
