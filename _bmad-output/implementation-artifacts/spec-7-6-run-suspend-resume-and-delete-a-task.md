---
title: 'Story 7.6: Run, suspend, resume and delete a task'
type: 'feature'
created: '2026-09-23'
status: 'in-progress'
baseline_revision: 'b447f29466120d48b9d83d1ea2067cea6a349240'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-7-5-run-an-on-demand-task.md'
warnings: ['oversized']
deferred: []
footprint_extensions: # planned; this story's own members only (roster rule, 2026-09-23)
  - 'src/OcuPilot/Port/TaskPort.cls' # new; outside every listed glob
  - 'src/OcuPilot/Port/AdminPort.cls' # shared-append: two parameter lines gain entries
  - 'ui/src/app/shell/proposal-card.ts' # contended; one getter and one template block, off Epic 8's hunks
  - 'ui/src/app/shell/proposal-card.spec.ts' # Epic 8 modified; this story's cases only
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


**Orchestrator rulings, 2026-09-23 (binding; the six questions are closed).**

1. **Q1 -- no toast in this story.** Implement AC3's Suspended-field highlight and every other
   clause; do not change `navigation.ts` or Epic 8's pins (`navigation.test.mjs`). AC3's toast clause
   is amended (tier-1) and delivered after the Epic 7/8 merge (DW-1546, owner `range-end-cleanup`).
2. **Q2 -- "Status field" is the Suspended field** (tier-1, `epics.md` 7.6 AC3 and EXPERIENCE UJ-6).
3. **Q3 -- the delete dialog types the task's Name**; the request sends the numeric id.
4. **Q4 -- deleting a system task is allowed** behind the delete's typed-name confirmation (the
   owner's "developer tool first"): no AD-10 bullet, no `Prohibited.cls` or `Registry.cls` edit. The
   dialog and the agent's proposal card both carry the consequence line `taskSystemDeleteConsequence`
   for a system task, and a test fails when that line is removed for a system task. OcuPilot's own
   installer creates only the demo fixture task (`Install/Fixture.cls` `CreateTask`), which is
   deletable like any other task.
5. **Q5 -- DW-1463 is dropped**: 5.11's "the agent's reply names the next run and offers the audit
   entry" and the end of UJ-6 step 5 are amended out (a confirm is a user request outside any turn).
   No proposal-card next-run line (it would land in the contended `Confirm.cls`).
6. **Q6 -- verification reads `INFO`**: the row update and every check read the task's `INFO`,
   never the list's `Suspended`; Epic 8's post-write re-read must do the same after the merge.

Copy is published at `EXPERIENCE.md:416-418` and appended to `strings.ts`
(`taskDeleteConsequence`, `taskScheduleEmptyAgent`, `taskSystemDeleteConsequence`; `npm run
test:tools` 1,327/0) -- consume; `taskSystemDeleteRefused` is not published and not used.
</intent-contract>

## Code Map

Measured on `ocupilot-ci` (2026-09-23, probes created and deleted) and on slot A read-only.

- **Vendor `Task.CRUD` (`[Hidden]`).** `SUSPEND` (15) and `RESUME` (14) are `POST`, `DELETE` is
  `DELETE /task`, each `?id=`. `RunSuspend` reads `requestBody.%Get("LeaveInQueue", 1)` (read from
  the class source): 1 is "Suspend Leave", 0 is "Suspend Reschedule". With no body SUSPEND answers
  415; an unknown key 400. `RunDelete` is `%DeleteId` and allows system tasks; DELETE reads no
  body. `ResourcesOR`: SUSPEND/RESUME `%Admin_Task`; DELETE `%Admin_Task` or `%Admin_Operate`.
  Unknown id 404. A delete answers 200 `{}`; `INFO` then answers 404.
- **What each write leaves.** Every suspend/resume, no-op included, writes a `%SYS.Task.History`
  row (`Result` "Suspended task"/"Resumed task", `Username`). A delete writes "Delete <Name>" and
  the history survives. Audit: `%System/%System/ConfigurationChange`.
- **The three reads.** `LIST` rows: `Name, Type ("System"|"User"), Namespace, Description, Id,
  Suspended (always false), LastFinished, NextScheduled`. `GET`: `Name, TaskClass, NameSpace,
  Description`, schedule, **no `Type`, no `Suspended`**. `INFO`: `Type, Status, Error,
  LastSchedule, LastStarted, LastFinished, NextScheduled, Suspended` (truthful), **no `Name`**.
  Suspend and resume leave `NextScheduled` alone.
- **Tools.** `Screen/Tool/TaskResume.cls` (INFO read, subject `Suspended`, `STATEFIELD` `Status`
  Suspended→Scheduled, private `ReadsSuspended`) has no `SCREENACTIONS`. `TaskRun.cls:19` promises
  the schedule subclass. `WebAppDelete.cls` is the delete template (`StateDiff` = one removal row
  per subject field). Diff-row labels must be `STATEFIELD` or subject names
  (`Prohibited.ReviewedFewOnly`); the task arm of `Prohibited.cls` refuses nothing and stays so.
- **Port seam (AD-52).** `Write.PORTCLASS` is read by `Mint.PortClassOf`, `Operation.PortClassOf`
  (confirm re-read, write, screen caller) and `Prohibited.PortClassOf`; `ErrorDelete` declares
  `LogSourcePort`. A non-default port bypasses the test seam (`ProposalFixture`), so a canned-read
  mint cannot reach it. `AdminPort.Invoke` (`:472`) is not `Final`; Epic 8 keeps its signature.
- **AdminPort.** `MUTATINGTYPES :197`, `BODYLESSTYPES :213`, `CONSTANTBODIES :237` (`;`-separated).
  Epic 8 rewrites the first two lines; append at the end of each.
- **Descriptor.** `TaskScheduleList.cls`: `id composite ["Id"]`, `rowActions []`, `rowGet` INFO
  `fields ["Suspended"]`, no Suspended column, `emptyNextKey tableReadOnlyEmptyNext`,
  `emptyAgentKey ""`, doc `:62-66` names 7.6. Precedent for the column:
  `TaskUpcomingList.cls:72` (`Suspended`, `taskColumnSuspended`, kind `status`).
- **Client.** `shell/screen-action-handler.ts`: roster `:31`, `DESTRUCTIVE_CONSEQUENCES :94`,
  `PendingConfirm :126` (`target` is both the typed text and the sent id), `start :240`,
  `rowRoles :321` (the row-lookup idiom). `shell/typed-name-dialog.ts` (one `consequence` input;
  control flow must be paren-free, see `proposal-card.ts` header). `shell/list-page.ts:78` binds
  the dialog. `core/screen-actions.ts:61-73` lacks `suspend`/`resume`. `proposal-card.ts`:
  `RESIDUE_ENTITY_TYPE :40`, residue template `:149`, `residueVisible :530`; Epic 8's hunks sit at
  `:11-14`, `:216-230` and after `auditWarningVisible` (`~:567`) -- stay off them. Task details
  re-reads on a `task` change event through `RefreshService.onBusEvent` and highlights through
  `DetailHighlights` (`areas/tasks/details.page.ts:158-180`).
- **Tests and rosters.** `Test/TaskRun.cls` (7.5, unarmed) is the shape to copy. `Test/TaskResume.cls`
  (armed, CI only) helpers `EnsureProbeTask :468`, `SuspendProbeTask :509`, `InfoSuspended :550`,
  `HistoryRowsForTask :590`, `ResumeHistoryUser :618`. `TaskRunFixture` (unarmed, no OREF).
  `ToolWrite :1028,:1119` assert `Task.CRUD/SUSPEND` is not admitted -- re-point to
  `Task.CRUD/PATCH`; `:1053` (`IsBodyless` SUSPEND false) stays true. `ReadTool :93-94` 57→60.
  `SurfaceCoverage :109-110`, `ToolRoundTrip :33`, `PortFixture :21` (its `MUTATINGTYPES` copy),
  `Descriptor :102`, `TaskLists`, `ProhibitedRoute`, `screen-mirror.test.mjs:849-859`,
  `tasks.browser-spec.mjs:318-325`, `screen-action-handler.spec.ts:420-442` (Run case).
  `task-resume.browser-spec.mjs:221` `navReply` routes to `tasks/schedule`; assertions `:346-399`,
  `:423-470`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/AdminPort.cls` -- append only: `MUTATINGTYPES` gains `Task.CRUD/SUSPEND`,
  `Task.CRUD/DELETE`; `BODYLESSTYPES` gains `Task.CRUD/DELETE`; `CONSTANTBODIES` gains
  `;Task.CRUD/SUSPEND={"LeaveInQueue":true}`; doc names each measured fact.
- `src/OcuPilot/Port/TaskPort.cls` (new) -- extends `AdminPort`; overrides `Invoke` so a successful
  `Task.CRUD` `GET` also reads `INFO` with the same query and sets its `Type` on the answer; an
  INFO failure fails the whole read with INFO's status, HTTP code and fault; every other pair is
  `##super` unchanged -- the one read that names the task and says whether it is a system task.
- `src/OcuPilot/Screen/Tool/TaskScheduleRun.cls` (new) -- extends `TaskRun`, overrides only
  `TOOLNAME` `tasks.schedule.run` and `DESCRIPTORCLASS` `…TaskScheduleList`.
- `src/OcuPilot/Screen/Tool/TaskSuspend.cls` (new) -- `tasks.schedule.suspend`, `TaskResume`
  inverted (extending it is fine): `SCREENACTIONS suspend`, `WRITETYPE SUSPEND`, INFO read, subject
  and precondition `Suspended`, row `Status: Scheduled → Suspended`; `StateDiff` refuses a task
  that reads suspended or whose state is unreadable.
- `src/OcuPilot/Screen/Tool/TaskResume.cls` -- add `SCREENACTIONS = "resume"`; update the doc.
- `src/OcuPilot/Screen/Tool/TaskDelete.cls` (new) -- `tasks.schedule.delete`, `WebAppDelete`'s
  shape: `PORTCLASS OcuPilot.Port.TaskPort`, `READTYPE GET`, `WRITETYPE DELETE`, `SENDSBODY 0`,
  `CHANGEACTION deleted`, `DESTRUCTIVE 1`, `%Admin_Task:USE`, `PRECONDITIONFIELD Name`,
  `FINGERPRINTSUBJECT` and `READANSWERS` `Name,TaskClass,NameSpace,Type`; one removal row per
  subject field; `StateDiff` refuses an empty `Name` or an absent `Type` (fail closed); id argument
  `Id`, param `id`.
- `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls` -- `rowActions` `run, suspend, resume,
  delete` (selfProtection `""`); `entityLabelKey proposalEntityTask`; `emptyNextKey ""`,
  `emptyAgentKey taskScheduleEmptyAgent`; column
  `{"field":"Suspended","labelKey":"taskColumnSuspended","kind":"status"}` after Type, fed by the
  existing INFO `rowGet`; rewrite the doc (`:62-66` and the no-action paragraph).
- `ui/src/app/core/screen-actions.ts` -- `suspend: STRINGS.actionSuspend`, `resume:
  STRINGS.actionResume`.
- `ui/src/app/shell/screen-action-handler.ts` -- roster gains `TaskScheduleList`;
  `DESTRUCTIVE_CONSEQUENCES` gains `{delete: STRINGS.taskDeleteConsequence}`; a typed-name field map
  `{TaskScheduleList: 'Name'}` and a system-task advisory (`Type === 'System'` →
  `STRINGS.taskSystemDeleteConsequence`), both read off the selected row the way `rowRoles` reads
  it; `PendingConfirm` gains `name` (typed and titled; defaults to `target`) and `advisory` (`''`
  when none); the POST still sends the row key `Id`.
- `ui/src/app/shell/typed-name-dialog.ts`, `ui/src/app/shell/list-page.ts` -- an optional
  `advisory` input rendered as a second paragraph (existing `ocu-banner ocu-banner-warning`
  classes, `data-slot="advisory"`, paren-free getter) only when non-empty; `list-page` binds
  `[target]="pending.name"` and `[advisory]="pending.advisory"`.
- `ui/src/app/shell/proposal-card.ts` -- beside the residue caption: a `task` card whose removal
  rows carry `Type` before `System` draws `STRINGS.taskSystemDeleteConsequence` (warning banner,
  `data-slot="system-task"`); nothing else changes.
- `ui/src/app/core/screens.generated.ts` -- regenerate.
- `src/OcuPilot/Test/TaskScheduleActions.cls` (new, unarmed, writes nothing) -- each tool's
  declarations; `TaskScheduleRun` differs from `TaskRun` only in its two parameters; suspend and
  delete `StateDiff` arms over canned reads (a `Type` "System" read answers a `Type` row, an absent
  `Type` refuses); a suspend mint over a canned read and its `TARGETCHANGED`;
  `ConstantBody("Task.CRUD","SUSPEND")`; `TaskPort` GET of a `Type` System task found through `LIST`
  answers `Name` and `Type` (read-only).
- `src/OcuPilot/Test/TaskRunFixture.cls` -- `EnsureScheduleProbeTask` (daily 03:00,
  `OcuPilotProbeScheduleTask`, optional system type) and `DeleteScheduleProbeTask`; no OREF held.
- `src/OcuPilot/Test/TaskResume.cls` (armed, append) -- over HTTP on the probe: Suspend then
  `InfoSuspended` 1; Resume then 0 and history "Resumed task" by the test account; Delete then INFO
  404 with history kept; a real mint/confirm of `tasks.schedule.delete` on a system-type probe whose
  diff carries `Type: System`, one marker, one ledger row. Every check reads INFO.
- Rosters (this story's members only) -- `ProhibitedRoute` short-of-pair Suspend leg; `ToolWrite`
  three `AssertActionWrite` tests plus the `:1028/:1119` re-point; `PortFixture`, `SurfaceCoverage`,
  `ReadTool` (60), `ToolRoundTrip` (×3 `TOOL.ARGUMENTS`), `Descriptor`, `TaskLists`,
  `screen-mirror.test.mjs`.
- `ui/src/app/shell/screen-action-handler.spec.ts` -- Suspend and Resume sent at once; Delete opens
  the dialog titled with the row's `Name` and sends its `Id`; a `System` row carries the advisory, a
  `User` row none.
- `ui/src/app/shell/proposal-card.spec.ts` -- a task delete card with `Type: System` draws the line;
  `User`, and a non-task card, do not.
- `ui/browser/tasks.browser-spec.mjs` -- schedule headers gain Suspended and Actions.
- `ui/browser/task-schedule-actions.browser-spec.mjs` (new; `-ci` guard; probe in `before`, deleted
  in `after`) -- Run, Suspend, Resume, Delete from the row menu and the command bar; wait for the
  rowGet before reading the Suspended cell; Task history shows "Resumed task" and the user; Delete
  on a `System` vendor row shows the advisory, then Cancel sends nothing.
- `ui/browser/task-resume.browser-spec.mjs` -- `navReply` routes to `tasks/schedule/details` with
  the id; heading names Task details; after Confirm the Suspended field is marked changed within
  2 s; no toast assertion.

**Acceptance Criteria:**

- AC1: Given a selected probe on Task schedule, when the user runs, suspends, resumes or deletes it,
  then the row updates in place (Suspended from INFO, Next run from the run, the row leaving on
  delete), and Delete's dialog names the task's `Name` and releases only on that typed name.
  *Pin:* `task-schedule-actions.browser-spec.mjs`.
- AC2: Given a suspended task, when the user resumes it, then its history reads "Resumed task" by
  that user. *Pins:* the browser leg; `TaskResume` (CI).
- AC3: Given UJ-6, when the agent navigates and the user confirms, then Task details opens and its
  Suspended field highlights within 2 s. *Pin:* `task-resume.browser-spec.mjs`.
- AC4: Given each new tool, when it is minted, then its diff and fingerprint cover its declared
  subject, a no-op suspend or resume is refused, and a moved subject is refused
  `PROPOSAL.TARGETCHANGED`. *Pin:* `TaskScheduleActions`.
- AC5: Given a `System` task, when its delete is opened on the screen or proposed by the agent,
  then the dialog and the card carry `taskSystemDeleteConsequence`; a `User` task carries neither;
  the delete itself is allowed. *Pins:* the two spec files above; the browser Cancel leg.
- AC6: Given a principal short of `%Admin_Task:USE`, when it sends Suspend, then 403
  `AUTH.NOPRIVILEGE` before any read. *Pin:* `ProhibitedRoute`.
- Integration AC (Rule 1): `ListPage` and Task details consume the `task` change event and re-read
  through INFO, marking the row or the field; observed in the browser on `ocupilot-ci`.

## Spec Change Log

- 2026-09-23, lead: the implement stage's matrix ambiguity is ruled -- the no-op is 400
  `TOOL.ARGUMENTS` (Design Notes); `status` reset to `in-progress`; its uncommitted work is committed as
  WIP for crash safety before the re-dispatch.

- 2026-09-23, lead spec gate (re-plan): accepted; EXPERIENCE `:102` gains the suspended column
  (tier-1). `Port/TaskPort.cls` is a new port under AD-52 and must reach `Task.CRUD` only through
  `AdminPort` (AD-2, AD-27: only `AdminPort` names an `%Api.Admin.*` class).

- 2026-09-23, lead spec gate (partial): Q2 ratified -- AC3's "Status field" restates to the
  Suspended field (tier-1, applied to `epics.md` with the orchestrator's answer); Q3 ratified -- the
  delete dialog types the task's Name while the request sends the numeric id; Q6 ratified -- the
  row update and every verification read the task's `INFO`, never the list field, and Epic 8's
  runtime re-read must do the same for a task once it merges (merge-gate note). Q1, Q4 and Q5 are
  with the orchestrator; answered the same day (rulings in the intent block); `status` reset to `draft`.
- 2026-09-23, re-plan over the rulings: toast and `navigation.ts` work removed (Q1); system-task
  delete allowed with the consequence line on dialog and card, `Prohibited.cls` untouched (Q4);
  DW-1463 closed (Q5).

## Review Triage Log

## Design Notes

**Governing ADs:** AD-53, AD-51 (as amended), AD-52 (the `TaskPort` declaration), AD-56 (ii),
AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-34, AD-36 (INFO truthful, LIST coerces `Suspended`),
AD-39, AD-43, AD-27 (the composite read is a vendor wire fact kept in a port).

**Rulings over the frozen matrix.** The matrix's "No-op" row is refused **400 `TOOL.ARGUMENTS`** with
`detail.problem`, and nothing is sent (lead ruling 2026-09-23: the agent's mint answers its own refusals
in that shape and the screen route mirrors it on purpose, so the two callers of AD-53 agree; 422 on
one route would split them). Ruling 4 supersedes the matrix row "System task delete (Q4)":
the delete is allowed and carries the consequence line; nothing refuses it. The matrix's "Status
reads Suspended" is the Suspended column (ruling 2). The agent delete's removal rows gain `Type`
beside `Name`, `TaskClass`, `NameSpace`, because the card can only know a system task from its
rows (ruling 4) and every row label must be a subject name.

**Why a port for the system line.** No proposal channel on this branch carries a tool's judgement
to the card (Epic 8's `consequence` code is not merged and is computed from the payload, which a
delete does not have), `GET` has no `Type` and `INFO` no `Name`, and `Mint`, `Write`, `Confirm` are
out of bounds. A tool-declared port whose `GET` is completed by `INFO`'s `Type` is AD-52's own
mechanism, so the mint, the confirm re-read and the screen caller all see one answer (inference:
no spine change). After the Epic 7/8 merge the line may move to a `consequence` code.

**Suspend body.** The vendor default `LeaveInQueue` 1 is sent explicitly as the port constant
(AD-51 as amended), so the ledger records no body.

**The Suspended column** is what makes suspend and resume visible in the row (ruling 6). Lead
bookkeeping (tier-1): add "suspended" to EXPERIENCE `:102`'s column list.

**Consumes:** 5.11 `TaskResume` and its helpers; 6.5-6.7 the lists and Task details; 7.1 the seam
and the typed-name dialog; 7.5 `TaskRun`, `CONSTANTBODIES`, `TaskRunFixture`, `actionRun`,
`proposalEntityTask`. **Consumed-by:** none in Epic 7; 16.11 adds the Task Manager controls to this
list; the range-end cleanup's DW-1546 toast replays AC3's last clause.

**Ledger inbox:** DW-1463 is `dropped` (ruling 5, 2026-09-23T13:21:13Z) and owes this story
nothing. DW-1546 is `range-end-cleanup`'s. Q6 merge note: Epic 8's post-write re-read for a task
must read INFO.

**Copy** is published (`EXPERIENCE.md:416-418`, `strings.ts:1409-1417`); consume only. Reused:
`actionRun/Suspend/Resume/Delete`, `taskColumnSuspended`, `proposalEntityTask`.

## Verification

Writes only on `ocupilot-ci` (web 52776), only to probe tasks; one test class per call, never
re-submitted; no container is stopped, removed or recreated.

**Targeted (loop):**

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.TaskScheduleActions`
  -- green; then one call each for `ToolWrite`, `Descriptor`, `SurfaceCoverage`, `ReadTool`,
  `ToolRoundTrip`, `PortFixture`, `TaskLists`, `TaskRun`, `ProhibitedRoute`. `TaskResume` runs in CI
  (armed); a local refusal is not a pass.
- `cd ui && npm run test:tools && npm run test:components` -- green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`,
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/task-schedule-actions.browser-spec.mjs browser/task-resume.browser-spec.mjs browser/tasks.browser-spec.mjs`
  -- green, no probe task left.
- `uv run scripts/check-objectscript.py` -- clean on changed paths.
- Rule 19, one `mutation:` per AC: AC1 feed the column from LIST (drop the rowGet) → suspend leg
  red; AC2 `TaskResume` `SCREENACTIONS ""` → resume leg red; AC3 `navReply` back to
  `tasks/schedule` → replay red; AC4 `TaskSuspend.StateDiff` without its refusal →
  `TaskScheduleActions` red; AC5 drop the card block / the advisory → the two specs red; AC6 skip
  the pair gate → `ProhibitedRoute` red.

**Once, before `dev_complete`:** the full ObjectScript sweep on `ocupilot-ci`, per class, totals
from the numeric-run-index probe; then `bash scripts/smoke.sh --container ocupilot-ci --user
_SYSTEM --password SYS`. No local full browser suite (Rule 29).

Recorded (implement, `ocupilot-ci`; each applied, observed red, reverted, tree unchanged):

- `mutation: dropped TaskScheduleList's INFO rowGet, reloaded → red: task-schedule-actions.browser-spec.mjs Suspend and Resume leg, the Suspended cell never reads Yes (AC1, Integration AC)`
- `mutation: TaskResume SCREENACTIONS "", reloaded → red: the same leg at the Resume wait (AC2)`
- `mutation: navReply routed to tasks/schedule → red: task-resume.browser-spec.mjs "Task details opens" (AC3)`
- `mutation: TaskSuspend.StateDiff without its already-suspended refusal, reloaded → red: TaskScheduleActions.TestTheSuspendStateDiffRefusesANoOpAndAnUnreadableState, run 8003 (AC4)`
- `mutation: dropped proposal-card.ts's system-task block → red: proposal-card.spec.ts Story 7.6 case; emptied the advisory in TYPED_NAME_ROWS → red: screen-action-handler.spec.ts advisory case (AC5)`
- `mutation: skipped the first pair-Gate refusal in ScreenAction.Run, reloaded → red: ProhibitedRoute.TestAnAccountShortOfTheTaskPairIsRefusedTheSuspendScreenAction with the run, auditing and web-app legs, run 8004 (AC6)`

## Auto Run Result

Status: blocked
Blocking condition: matrix ambiguity -- the matrix row "No-op" says "refused 422 with
`detail.problem`. Nothing sent", but both callers refuse a no-op with 400 `TOOL.ARGUMENTS` and
`detail.problem`: the mint answers 400 (`Mint.cls`, which this spec's Never list closes), and
`Api/ScreenAction.cls` `Refuse` (`:470-478`) answers 400 on purpose, "the shape the mint answers its
own refusals in" (AD-53: one behavior for both callers). A 422 on the screen route alone would
split the two callers and change the refusal every earlier screen action (7.1, 7.2, 7.5) answers.
The tests assert 400, which the Matrix Test Audit forbids (it says fix the code or halt). Recommended
ruling, in the style of the existing "Rulings over the frozen matrix": the no-op is refused 400
`TOOL.ARGUMENTS` with `detail.problem`, and nothing is sent. With that ruling the audit passes as the
code stands, and the re-dispatch resumes at step-03's Verify.

footprint_extensions: `src/OcuPilot/Port/TaskPort.cls` (new), `Port/AdminPort.cls` (append-only),
`shell/proposal-card.ts` and `.spec.ts` (off Epic 8's hunks), `Test/ToolWrite.cls`,
`Test/PortFixture.cls`, `Test/SurfaceCoverage.cls`, `Test/ReadTool.cls`, `Test/ToolRoundTrip.cls`,
`Test/ProhibitedRoute.cls`, `ui/tools/screen-mirror.test.mjs`, `core/screens.generated.ts`, and,
beyond the plan: roster files `Test/PortGate.cls`, `Test/AsTheUser.cls`, `Test/TaskRunFixture.cls`
(none modified by Epic 8).

**Change (uncommitted; the lead's rework commit carries it).**

- Port: `AdminPort` admits `Task.CRUD/SUSPEND`, with the constant body `{"LeaveInQueue":true}`, and
  `Task.CRUD/DELETE`, which is bodyless.
- New `TaskPort` completes a `GET` with `INFO`'s `Type`.
- Tools: `TaskScheduleRun`, `TaskSuspend` and `TaskDelete` are new; `TaskResume` gains the list's
  `resume` action.
- `TaskScheduleList` declares four row actions, a Suspended column, `proposalEntityTask` and
  `taskScheduleEmptyAgent`.
- Client:
  - the handler registers the schedule;
  - the typed-name dialog takes the row's `Name` and a system-task advisory;
  - the proposal card draws `taskSystemDeleteConsequence`.
- No new string.

**Tiers run (targeted, `ocupilot-ci`, per class).**

- ObjectScript:

  | Class | Passed/failed |
  | --- | --- |
  | `TaskScheduleActions` | 6/0 |
  | `ToolWrite` | 27/0 |
  | `Descriptor` | 50/0 |
  | `SurfaceCoverage` | 4/0 |
  | `ReadTool` | 27/0 |
  | `ToolRoundTrip` | 2/0 |
  | `TaskLists` | 7/0 |
  | `TaskRun` | 6/0 |
  | `ProhibitedRoute` | 24/0 |
  | `PortGate` | 4/0 |
  | `AsTheUser` | 3/0 |
  | `ScreenRead` | 29/0 |
  | `Wire` | 20/0 |
  | `TaskHistory` | 11/0 |

  `TaskResume` refuses on `ocupilot-ci` (unarmed); its two new methods passed through a temporary
  unarmed subclass (run 8002), and CI decides.
- Client: `test:tools` 1,327/0 and `test:components` 885/0.
- Browser, on a rebuilt and redeployed bundle:
  - `task-schedule-actions` 4/4, `task-resume` 3/3, `screen-height` 15/15;
  - `tasks` 12/14 -- the two Task history legs 7.5 recorded;
  - no probe task left.
- `check-objectscript` is clean.
- Mutations: one per AC, recorded under `## Verification`.

**Not yet run:** the full ObjectScript sweep, `smoke.sh`, and both review layers.

**Open items:**

- The initial bundle is 1,119,895 bytes against the 1,120kB budget, 105 bytes of headroom.
- Lead bookkeeping: add the suspended column to EXPERIENCE `:102`.
