---
title: 'Story 16.5: Background tasks'
type: 'feature'
created: '2026-09-28'
status: 'done'
baseline_revision: '317b4463df8d3bb82355eb905d287d5af2785420'
baseline_commit: '317b4463df8d3bb82355eb905d287d5af2785420'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The live Background tasks tests could flake if a seeded compact finishes between a Resume and the next Pause or mint.
    evidence: |-
      Maybe-false. BackgroundTasksLive resumes a seeded compact (about 1.2 GB, about 2 s of work
      measured locally) and then pauses it or mints a pause at once; a much faster host could finish
      it first and answer 409. Settled by the CI shard timings of BackgroundTasksLive over several runs.
    location: >-
      src/OcuPilot/Test/BackgroundTasksLive.cls TestTheScreensActionsResumePauseAndCancelACompact, TestTheAgentsConfirmPausesACompact
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Long-running work on the instance has no view or control in OcuPilot. That covers the admin API's own async tasks and the classic portal's background jobs (compact, defragment, compile, export and the rest). A stuck job can be seen and stopped only on the classic Background Tasks page, and only for the portal's half.

**Approach:** Add Background tasks as the fifth Tasks entry. It is one list over one read from a new `Port/BackgroundTaskPort`. The port merges the caller's admin API `AsyncResult` `LIST` with the portal's `%CSP.UI.System.BackgroundTask:EnumerateTasks`, read in `%SYS`. Three action-style write tools act on a row through that port: Cancel, Pause and Resume. Admin rows go through `AsyncResult` `CANCEL`/`PAUSE`/`RESUME`, and portal rows through `%SYS.BackgroundTask` `Cancel()`/`Pause()`/`Resume()`. The story also fixes the async-row leak in `AdminPort` (DW-1101, DW-1136, DW-1137).

## Boundaries & Constraints

**Always:**

- **Read** (`tasks.background.read`, AD-36): source `{port: background, endpoint: BackgroundTask, type: LIST}`.
  - Fields: `Source, Id, Task, Namespace, Status, Details, ErrorCount, StartTime`.
  - Columns: Task (name), Source, Status (status), Namespace, Details, Error count, Start time.
  - Sort: `StartTime` descending. The row cap applies to the merged rows, and truncation is reported.
  - Row key: `id {kind: composite, parts: [Source, Id]}`. Entity type `background-task` (new), scope `instance`. Classic page `%CSP.UI.Portal.BackgroundTaskList`.
- **Rows:**
  - A portal row has `Source` "Management Portal", `Id` = the job number (EnumerateTasks' `ID`), and the query's `Task`, `Namespace`, `Status`, `Details`, `ErrorCount` and `StartTime`.
  - An admin row has `Source` "Admin API", `Id` = `GUID` (always a string: leading zeros are significant, measured), `Task` = `TaskName`, `Status` = `State`, `Details` = `FailureReason` and `StartTime` = `TimeStarted`. Its `Namespace` and `ErrorCount` are empty, because the vendor answers neither.
- **Pairs** (AD-8, AD-29; measured on `ocupilot-ci`):
  - The screen declares `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, with `ownPrivileges` `%Admin_Operate:USE`. The Tasks area's pairs are `%Admin_Task:USE` and `%DB_IRISSYS:READ`.
  - The tools declare the screen's pairs and nothing more.
  - The port refuses a caller missing either pair by name, before any vendor call.
- **The portal half runs in `%SYS`** (AD-16). Without it the query shows stored states and blank `SysBGTaskId`s, and `%OpenId` fails `<CLASS DOES NOT EXIST>` (measured).
- **Control** (AD-51, AD-52, AD-53):
  - Tools `tasks.background.cancel`, `tasks.background.pause` and `tasks.background.resume`, with arguments `source` (one of the two words) and `id`.
  - Fresh read: the port's `LIST` row whose `Source` and `Id` equal the arguments exactly.
  - `FINGERPRINTSUBJECT` and `PRECONDITIONFIELD` `Status`; no body; `DESTRUCTIVE 0`.
  - A portal row acts on its `SysBGTaskId`, read fresh at the write.
  - Pause and Resume are sent at once. Cancel opens the warning dialog (primary button) with its consequence.
- **One published refusal:** `TASK.BACKGROUND.STATE`, 409. It is answered for the vendor's own state refusal (admin `#40320`/`#40321`/`#40322`, portal `#9503`, measured) and, before any vendor call, for a portal row with no `SysBGTaskId`. The kernel's reason equals the published sentence.
- **Async rows** (DW-1101, DW-1136, DW-1137):
  - `AdminPort.ForgetTask` always attempts the delete. It suppresses only `<PROTECT>`, without logging, and logs any other failure. `ASYNCTASKPAIR` is removed.
  - A daily step of the retention sweep deletes the terminal rows OcuPilot's port queued. A row qualifies when:
    - its `TaskName` carries the `STUBURLPREFIX` label `/v2/ocupilot/`;
    - its `State` is `Finished`, `Failed` or `Canceled`;
    - it was queued more than 24 hours ago.
- **The task error log reads the same way.** `LogSourcePort`'s task reader reads in `%SYS` and requires `%DB_IRISSYS:READ`. Today a caller holding only `%Admin_Operate:USE` rewrites a live job's stored status to `Exited` (measured).
- **Governance:** three keys, enabled, appended to `Baseline.cls`.
- **Copy:** EXPERIENCE.md and `strings.ts` together, and EXPERIENCE.md stays 993 lines.

**Never:**

- No `AsyncResult` `GET` from this story's read or tools. A finished task is read at most once, by `AdminPort`'s await.
- No new REST route. The AD-53 routes and `GET /screens/:screen/read` carry everything.
- No auto-refresh (AD-43's roster is unchanged), no Purge command, no per-task detail dialog.
- The story does not touch `DatabaseDetails.cls` or `Port/PathPort.cls`.
- No test starts, pauses or cancels work on `ocupilot`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Portal rows | a paused portal compact, a finished portal job | one row each; a compact's status is its `RunningState` (`Paused`), and a job without a background task shows its stored status | none |
| Admin rows | the caller's own admin API compact | a row with Source "Admin API", `State`, `TaskName`; namespace and error count "(none)" | none |
| Others' admin tasks | `_SYSTEM`'s admin task, read by another principal | not listed (the vendor lists the caller's own, measured) | none |
| Empty | no tasks | empty state and the agent invitation | none |
| Tasks holder only | `%Admin_Task:USE` + `%DB_IRISSYS:READ`, no `%Admin_Operate` | Background tasks unavailable ("Requires %Admin_Operate"); the other Tasks screens open | route and read refused naming the pair |
| Pause / Resume | a running (paused) portal or admin compact | one POST; the row re-reads `Paused` (`Running` or `Done`) with the Changed tag | none |
| Cancel | a paused row; Proceed in the warning dialog | one POST; the row re-reads `Cancelled` (`Exited` for a caller without `%DB_IRISSYS:WRITE`, measured) | the dialog's Cancel sends nothing |
| Agent | `tasks.background.pause {source, id}` | the card shows `Status` moving to `Paused`; Confirm pauses; the marker is emitted | none |
| Not allowed | Pause on a `Done` row; any control on a portal compile job; admin Pause on a base task | refused with the published sentence; a portal row with no background task sends nothing | `TASK.BACKGROUND.STATE` 409 |
| Moved | `Status` changes between mint and confirm | refused | `PROPOSAL.TARGETCHANGED` |
| Gone | the row is purged before the write | refused at the fresh read | not-found envelope |
| Task error log (fix) | a caller holding `%Admin_Operate:USE` without `%DB_IRISSYS:READ` | refused; a live job's stored status stays `Running` | refused naming `%DB_IRISSYS:READ` |
| Unprivileged async read (DW-1136, DW-1137) | a read through `AdminPort`'s async path by a caller without WRITE on IRISLOCALDATA | answers normally; nothing logged; the row is left for the sweep | none |
| Sweep (DW-1101, DW-1136) | labeled terminal row queued 2 days ago; labeled row queued now; unlabeled old row; labeled old `Running` row | only the first is deleted | a failed delete is the step's logged status |

</intent-contract>

## Code Map

- **Classic page and its query** (read-only vendor code):
  - `irissys/%CSP/UI/Portal/BackgroundTaskList.cls` is the classic page: columns :73-80, Purge :174.
  - `irissys/%CSP/UI/System/BackgroundTask.cls:1191-1260`: `EnumerateTasks` overlays `RunningState` for a row with `SysBGTaskId` (:1220), and writes `Exited` for a job `%SYS.ProcessQuery` cannot see (:1236).
  - `:643` and `:658` are the only tasks with a `SysBGTaskId`.
  - `RunTask` :31. `Task1` cannot start through it: `TASKS` (:22) has no trailing comma.
- **Vendor control:**
  - `irissys/%CSP/UI/Portal/Background/Dialog/TaskInfo.cls` has `RESOURCE %Admin_Operate:USE` and calls `ActionProcess`.
  - `irissys/%SYS/BackgroundTask.cls`:
    - `Cancel`/`Pause`/`Resume` :283-302, public and Final.
    - `Request` :675: its `%Admin_Operate:USE` check throws `<UNDEFINED>` on failure (measured), so the port checks first.
    - `ListAll` :922 and `DatabaseList` :911 are public; `RunningInDatabase` :899 is Internal.
- **The vendor's admin side** (not exported; the hidden sources are saved at `scratchpad/epic-16/16-5/cls_*.txt`):
  - `%Api.Admin.Endpoints.AsyncResult`:
    - `ResourcesOR` `%Admin_Operate`.
    - `LIST` filters `Username = %session.Username`.
    - Types `CANCEL` 10, `PAUSE` 11, `RESUME` 12.
    - A non-owner gets 404 `#5809`.
  - `%Api.Admin.Util.AsyncTask`: `Cancel` only while `Queued`, and `Pause`/`Resume` are 409 by default.
  - `...Database.AsyncTaskSysBackground` wraps a `%SYS.BackgroundTask`.
- **`src/OcuPilot/Port/AdminPort.cls`**:
  - Async parameters: `ASYNCTASKCLASS` :74, `ASYNCTASKPAIR` :87 (literal; remove), `ASYNCRESULTENDPOINT` :98, `ASYNCLOCATION` :102, `STUBURLPREFIX` :595 (the label source).
  - Type tables: `MUTATINGTYPES` :308, `BODYLESSTYPES` :324, `QUEUEDWRITES` :514.
  - Await: the site :880; `PollTask` :1198; `ForgetTask` :1214; `AwaitTask` :2268; the handoff :2219-2240.
  - Session stub: `RunSequence` :2129; the stub `%session` :2151 is `$USERNAME`, so `LIST` is the caller's.
  - Script rendering: `SnippetForm` :2596 and `Snippet` :2617. `Port/AdminRoutes.cls:81-83` already route `AsyncResult` `CANCEL`/`PAUSE`/`RESUME` (`POST /async-result/<verb>`).
- **`src/OcuPilot/Port/ProcessPort.cls`** is the model port: it extends AdminPort, overrides `Invoke` :41 for one pair (repeating the vendor gate, :58) and defers to `##super` otherwise, with `SnippetForm` :117 and `Snippet` :127.
- **`src/OcuPilot/Port/LogSourcePort.cls`**: `TASKERRORSPAIRS` :172, `PairsFor` :437/:443, `TaskErrors` :1212, `FetchTasks` :1385 (EnumerateTasks :1391, no namespace switch), `FetchTaskErrors` :1413. `Screen/Descriptor/LogTaskErrorViewer.cls` privileges. `Test/LogSecondaryWire.cls:34` pins EnumerateTasks' columns.
- **Read source keys:**
  - `Screen/Read.cls:134-178`: `SOURCEADMIN` through `SOURCETIMELINE`, each with a `*PortClass()`.
  - `Screen/Registry.cls:1037` accepts the six.
  - `ui/tools/screen-mirror.mjs:940` holds `READ_SOURCE_PORTS`, checked at :1153.
- **Descriptors:**
  - `Screen/Descriptor/TaskScheduleList.cls:80-140` is the model list: `rowActions` :99, a `status` column :127.
  - Tasks are positions 1-4, so the new screen is 5.
  - `Screen/Area.cls:110` holds the Tasks pairs.
  - Column kinds are `name, identifier, text, number, status` (`Registry.cls:2171`).
  - `WebSessionList.cls` is the `ownPrivileges` example.
- **Tools:**
  - `Screen/Tool/ErrorDelete.cls` is the composite-id write tool model: `IdArgument` :89 and extra arguments :109.
  - `Screen/Tool/TaskResume.cls` is the action-style model; `TaskSuspend` extends it.
  - `Screen/Tool/WebSessionEnd.cls` is the `LIST` fresh-read model (`READROWKEYEXACT`).
  - `Screen/Tool/Write.cls:114` holds `PORTCLASS`.
- **Kernel:** `Kernel/Retention.cls` `Sweep` :34 has `Step(...)` per phase. `Kernel/RetentionTask.cls` sets no `RunAsUser`, so the task runs as its installing user (inference).
- **Kernel registries:** `Kernel/EntityType.cls:43` has 33 `TYPES`. `Kernel/Governance/Baseline.cls:17-98` ends with `webapp.sessions.end` :96.
- **Tests:**
  - `Test/AdminPortForget.cls`: `TestAnUnprivilegedCallerSkipsTheDeleteAndLogsNothing` :41 and `TestTheDeclaredPairNamesTheDatabaseTheRowsLiveIn` :61.
  - `Test/AdminPortAsync.cls`: `TestDatabaseInfoIsPolledToAnOrdinarySuccess` :115 ("the queued row is gone"); `QUEUEDWRITES` pinned :88.
  - `Test/PortFixture.cls`: `MUTATINGTYPES` :21, canned `PollTask` :160.
- **Client:**
  - `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :51-73, `WARNING_CONSEQUENCES` :273-275 (the warning dialog, title = verb), `startFor` :527-534.
  - `ui/src/app/core/screen-actions.ts`: `ACTION_LABELS` :72-92 (no `cancel` or `pause` yet), `DESCRIPTOR_ACTION_LABELS` :102-134.
  - The change chain is `send` :690-733 → `refresh.ts` `onBusEvent` :641 → `markChanged`.
- **EXPERIENCE.md:**
  - :112 and :165 place the screen (fifth Tasks entry, a list).
  - :371 is the Task history strings row, the one to fold into.
  - :173 is Dialogs ("the two warnings that precede a non-delete write").
- **`ui/src/app/core/strings.ts`:**
  - Append after the Story 16.2 block (:3383).
  - Reuse `taskHistoryColumnStatus` 'Status', `headerNamespaceLabel` 'Namespace', `taskStartTime` 'Start time', `auditEventFieldSource` 'Source', `proposalEntityTask` 'Task' and `actionResume` 'Resume'. Values are unique (`strings.test.mjs:710`).
- **Browser models:**
  - `ui/browser/web-sessions.browser-spec.mjs`: seeding via `runIris`, the dialog, DW-1337 `structural` :120-150, `after` :195.
  - `ui/browser/task-schedule-actions.browser-spec.mjs:291+` drives Suspend/Resume.

## Tasks & Acceptance

**Execution:**

**Server:**

- `src/OcuPilot/Port/BackgroundTaskPort.cls` (new): extends `AdminPort`, as `ProcessPort` does.
  - **Endpoint:** the pseudo-endpoint `BackgroundTask` with types `LIST`, `CANCEL`, `PAUSE` and `RESUME`. Every other call defers to `##super`.
  - **Gate:** `$System.Security.Check` on `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, refusing 403 by name.
  - **`LIST`:** the caller's `AsyncResult` `LIST` through `##super`, then EnumerateTasks in `%SYS` (AD-16 save and restore), each mapped per Boundaries.
  - **Control:**
    - Admin rows call `##super` `AsyncResult` `<TYPE>` `id=<GUID>`.
    - Portal rows re-read the row. They refuse `TASK.BACKGROUND.STATE` when it carries no `SysBGTaskId`, and otherwise call `%SYS.BackgroundTask` `%OpenId(SysBGTaskId).<Verb>()` in `%SYS`.
    - Vendor `#9503` and 409 map to `TASK.BACKGROUND.STATE`. The reference is dropped after the call.
  - **`SnippetForm` and `Snippet`:** they mirror each branch. The admin branch renders through `##super` (REST); the portal branch renders ObjectScript.
- `src/OcuPilot/Screen/Read.cls`, `Screen/Registry.cls:1037` and `ui/tools/screen-mirror.mjs:940`: add the source key `background` → `OcuPilot.Port.BackgroundTaskPort`, appended.
- `src/OcuPilot/Kernel/EntityType.cls`: append `background-task`.
- `src/OcuPilot/Screen/Descriptor/BackgroundTaskList.cls` (new):
  - route `tasks/background`, `sideBarPosition` 5, `toolIdentifier` `tasks.background`;
  - the read, table, pairs and `ownPrivileges` from Boundaries;
  - `rowActions [cancel, pause, resume]` with empty `selfProtection`;
  - context fields = the read's fields, no secrets;
  - empty and invitation keys;
  - three prompts in `promptGroupTroubleshooting`;
  - command aliases "background tasks", "background jobs".
- `src/OcuPilot/Screen/Tool/BackgroundTaskCancel.cls` (new), with `BackgroundTaskPause.cls` and `BackgroundTaskResume.cls` extending it:
  - `PORTCLASS` `OcuPilot.Port.BackgroundTaskPort`, `READTYPE LIST`, composite fresh read as `ErrorDelete` does, `WRITETYPE` `CANCEL`/`PAUSE`/`RESUME`, `SENDSBODY 0`, `DESTRUCTIVE 0`, `PRECONDITIONFIELD`/`FINGERPRINTSUBJECT` `Status`;
  - `StateDiff`: `Status` becomes `Canceled`/`Paused`/`Running` for an admin row and `Cancelled`/`Paused`/`Running` for a portal row;
  - the `source` argument is an enum of the two words;
  - the `id` description tells the model to copy the id as a string, leading zeros included.
  - Each `(endpoint, type)` pair is registered the way `ProcessPort`'s own pair is (`Test/ToolWrite.cls:1192`, `Test/PortFixture.cls:21`).
- `src/OcuPilot/Port/AdminPort.cls`:
  - Append `AsyncResult/CANCEL`, `/PAUSE` and `/RESUME` to `MUTATINGTYPES` and `BODYLESSTYPES`. They answer synchronously (measured: 200 over HTTP).
  - Rewrite `ForgetTask` per Boundaries and delete `ASYNCTASKPAIR` (DW-1136, DW-1137).
  - Add `SweepOwnTasks(pHours = 24)`: one bound-parameter `DELETE` in `%SYS` over the async task table, naming the class only through `ASYNCTASKCLASS` and the label only through `STUBURLPREFIX` (DW-1101, DW-1136).
- `src/OcuPilot/Kernel/Retention.cls`: append a `Sweep` step calling `AdminPort.SweepOwnTasks()`, whose failure is the step's status (lead ruling Q2).
- `src/OcuPilot/Port/LogSourcePort.cls` + `Screen/Descriptor/LogTaskErrorViewer.cls`:
  - `FetchTasks` switches to `%SYS` (AD-16).
  - `TASKERRORSPAIRS` and the viewer's `privileges` gain `%DB_IRISSYS:READ`, which the Logs area already declares.
- `src/OcuPilot/Api/Error.cls`: append `TASK.BACKGROUND.STATE` with its published sentence.
- `src/OcuPilot/Kernel/Governance/Baseline.cls`: append `"tasks.background.cancel"`, `"tasks.background.pause"` and `"tasks.background.resume"`, each `true`.

**Client:**

- `ui/src/app/core/screen-actions.ts`: add `cancel` ("Cancel task") and `pause` ("Pause"), and a `BackgroundTaskList` label entry.
- `ui/src/app/shell/screen-action-handler.ts`:
  - register the descriptor;
  - add `WARNING_CONSEQUENCES.BackgroundTaskList.cancel`;
  - Pause and Resume are sent at once.
- `ui/src/app/core/screens.generated.ts`: regenerate through `screen-mirror.mjs`.
- `ui/src/app/core/strings.ts` + EXPERIENCE.md :371, folded in place with `[ADDED 2026-09-28 - Story 16.5]`, each key cited `/** EXPERIENCE.md:371 */`. The strings:
  - "Background tasks";
  - "Details";
  - "Error count";
  - "Pause";
  - "Cancel task";
  - "No background tasks.";
  - the invitation "cancel, pause or resume a background task";
  - the consequence "Canceling stops this task where it is. What it has done stays done, and it cannot be resumed.";
  - the refusal "This background task's current state does not allow that.";
  - the card noun "Background task";
  - the prompts "Which background tasks are running, and since when?", "Which background tasks ended with errors?" and "Is a database compact or defragment running?".

  :173 is edited in place to "the three warnings that precede a non-delete write (Suspend Task Manager; disable auditing; cancel background task)". Line count stays 993.

**Rosters (additive only):**

| File | Change |
|---|---|
| `Test/ReadTool.cls:93` | 132→136, plus the four names |
| `Test/SurfaceCoverage.cls` | a screen row and three tool rows |
| `Test/ToolRoundTrip.cls:39` | three `REFUSEEMPTY` entries |
| `Test/ToolWrite.cls:1192`, `Test/PortFixture.cls:21` | the new pairs |
| `Test/Descriptor.cls:1700` | 33→34 |
| `Test/Wire.cls:646`, `Test/WireSecurityRead.cls:388`, `:392` | the Tasks screen lists gain `tasks/background` |
| `Test/AdminPortAsync.cls:88` | unchanged (`QUEUEDWRITES`) |
| `Test/ScreenRead.cls:200` | exclude `BackgroundTaskList`: a fresh instance holds no task, as `WebSessionList` |
| `Test/LogPairs.cls`, `Test/LogSecondaryWire.cls` | the task error log's new pair |
| `ui/tools/navigation.test.mjs:158-167`, `navigation-wire.test.mjs:168-217`, `ui/src/app/shell/rail-wire.spec.ts:165-216` | the fifth Tasks entry |
| `ui/tools/screen-mirror.test.mjs:961` | the new descriptor; the `READ_SOURCE_PORTS` pin |
| `ui/tools/screen-actions.test.mjs:110-115` | the new labels |

**Tests:**

- `src/OcuPilot/Test/BackgroundTasks.cls` (new, ≤500 lines), over canned port answers:
  - the descriptor and tool declarations, including `ownPrivileges`;
  - the row mapping for both halves;
  - the exact composite fresh read (`Id` "017…" does not match "17…");
  - `StateDiff` per half;
  - the fingerprint refusing a moved `Status`;
  - the portal no-`SysBGTaskId` refusal sending nothing;
  - vendor `#9503` and 409 mapped to `TASK.BACKGROUND.STATE`;
  - the reason pinned equal to the published sentence;
  - `Snippet` rendering both branches.
- `src/OcuPilot/Test/BackgroundSeed.cls` (new helper, no web surface):
  - `PausedCompact()` creates scratch database `OCUBGSEED` (resource first), fills about 200 MB, frees half, starts the portal's `CompactDBSpace` through `RunTask` and pauses it at once (measured: paused within 41 ms). It returns the job and `SysBGTaskId`.
  - `Remove()` cancels, kills the `^IRIS.Temp.MgtPortalTask` row, deletes the `%SYS.BackgroundTask` row, then dismounts and deletes the database, directory and resource.
- `src/OcuPilot/Test/BackgroundTasksLive.cls` (new), each test seeding its own:
  - a seeded portal compact is listed with `Paused`, Namespace `%SYS` and its `Details`;
  - screen-action pause, resume and cancel on it each answer 200 and re-read the new state;
  - an admin-API compact queued as the test principal over HTTP is listed as "Admin API", and pause and cancel act through `AsyncResult`;
  - a purpose-built role holding the Tasks pairs without `%Admin_Operate` is refused by name. Never `%Operator`.
  - The agent's mint-and-confirm pauses a seeded compact.
- `src/OcuPilot/Test/AdminPortForget.cls`:
  - replace `TestTheDeclaredPairNamesTheDatabaseTheRowsLiveIn` with the unprivileged leg: `<PROTECT>` suppressed, nothing logged, row left;
  - add `SweepOwnTasks` legs over rows seeded through a `PortFixture` helper that names the class through `ASYNCTASKCLASS` (AD-27), per the Sweep matrix row;
  - add one leg through `Retention.Sweep()`.
- `ui/src/app/shell/screen-action-handler.spec.ts` + `list-page.spec.ts`, against the descriptor: the Cancel warning (title "Cancel task", consequence, Proceed sends one POST, Cancel sends none); Pause and Resume sent at once; the empty state.
- `ui/browser/background-tasks.browser-spec.mjs` (new), on the `-ci` throwaway:
  - seed through `BackgroundSeed.PausedCompact()`;
  - Background tasks is fifth in Tasks;
  - the row shows "Management Portal", "Compact DB Space", `%SYS`, `Paused`;
  - Cancel opens the warning, and Proceed sends one POST, after which the row reads `Cancelled` with the Changed tag;
  - the DW-1337 gate in both themes with the warning open, with no new allowance;
  - `after` calls `Remove()` in a `finally`.

**Acceptance Criteria:**

- Given the Background tasks screen, when it loads, then it lists each task's status, namespace, details and error count. The portal's rows are instance-wide, the admin API's are the caller's own, and each row names its source.
- Given a background task, when the user cancels, pauses or resumes it, then it acts, and the row updates in place on the re-read with the Changed tag. The same write proposed by the agent acts on Confirm.
- Given the admin API tracks only its own async tasks, when this screen is built, then both halves ship: `AsyncResult` for the admin tasks, and `BackgroundTaskPort` for the portal's jobs. The stated parity gaps are in Design Notes.
- Given an async read by a caller who cannot delete its row, when it completes, then it answers normally and logs nothing. The daily sweep deletes OcuPilot's terminal rows once a day old, and never a row OcuPilot did not queue.

### Review Findings

Code review 2026-09-28, `full-opus`: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor ran, none failed. 2 `decision-needed` resolved by judgment (the `ForgetTask` guard below, and DW-1805), 10 `patch` (all applied), 2 `defer`, 20 rejected. Mutations: `## Verification`, code-review table.

- [x] [Review][Patch] (high, Rule 6 AD-16) Two test helpers restored the namespace only after `Try`/`Catch`; each `Catch` now restores first (behavior-neutral) [src/OcuPilot/Test/AdminPortForget.cls:254, src/OcuPilot/Test/BackgroundTasksLive.cls:483]
- [x] [Review][Patch] (medium) Portal 9502 (a defragment's pause or resume) and 9505 (no longer running) answered 500 and were logged; `PORTALSTATECODES` answers them as the published 409 [src/OcuPilot/Port/BackgroundTaskPort.cls:72]
- [x] [Review][Patch] (medium) An unprivileged async read's delete met `<PROTECT>`, which IRIS audits (24 `Protect` rows on `ocupilot-ci`, visible about 57 s later) into the log Logs › Audit shows; `ForgetTask` now asks `MayDeleteTask` (`GetGlobalPermission` on the storage-derived global) first [src/OcuPilot/Port/AdminPort.cls:1219]. For the lead (Rule 5, apply and report): Boundaries' "always attempts the delete" now reads "attempts it when the instance answers the caller may write the row", DW-1137's first option.
- [x] [Review][Patch] (medium) The sweep's 24 h cutoff was bracketed only by 0 h and 48 h rows; a kept 23 h and a deleted 25 h row were added [src/OcuPilot/Test/AdminPortForget.cls:131]
- [x] [Review][Patch] (low) The port's vendor-reaching seams were public and ungated (AD-29; no caller); now `Private`, with the fixture's overrides [src/OcuPilot/Port/BackgroundTaskPort.cls:316]
- [x] [Review][Patch] (low) The port's class doc named seams the fixture does not override [src/OcuPilot/Port/BackgroundTaskPort.cls:25]
- [x] [Review][Patch] (low) No control write ran as a holder of the screen's pairs alone; the live Pause now runs as `READERUSER` [src/OcuPilot/Test/BackgroundTasksLive.cls:190]
- [x] [Review][Patch] (low) Resume's change-event check was skipped when the body was not JSON [src/OcuPilot/Test/BackgroundTasksLive.cls:187]
- [x] [Review][Patch] (low) The seed paused as soon as the task id existed, while the task could still read `Starting` (9503); it now waits that out [src/OcuPilot/Test/BackgroundSeed.cls:143]
- [x] [Review][Patch] (low) Stale principal counts in comments [src/OcuPilot/Test/BackgroundTasksLive.cls:74]
- [x] [Review][Defer] (maybe-false, medium) The admin compact is paused after several list reads, and a resumed compact can finish before the next Pause or mint [src/OcuPilot/Test/BackgroundTasksLive.cls:235] — deferred: DW-1802 occurrence; settled by CI shard timings
- [x] [Review][Defer] (low) OcuPilot's own port-queued async tasks are listed with controls, and the await does not treat `Canceled` as terminal [src/OcuPilot/Port/BackgroundTaskPort.cls:361] — deferred: DW-1805 `wontfix-accepted`, `reopen_if` in the ledger; the rows are the caller's own (AC1)

Rejected:

- Cancel is `DESTRUCTIVE 0` — spec-bound (Boundaries; the warning is a primary-button dialog).
- Actions offered whatever the row's state — spec-bound (empty `selfProtection`; the instance answers the click).
- Cancel listed first — spec-bound order.
- The vendor purge already runs daily — false: nothing schedules `PurgeAsyncQueue` (measured).
- The sweep's dynamic SQL fails for a non-`%All` retention user — low: install needs `%All`-level administration.
- The retention task's description omits the step — low: incomplete, not wrong; set only at creation.
- Baseline keys out of name order — standing ruling: appended at the end of a contended list.
- The registry does not require a `background` read's system pair — low: the shape rule pins the one read; the port refuses 403 by name.
- A failed admin half fails the whole list — false: AD-36, never a partial list.
- An admin 409 is logged by `AdminPort.Fail` — low: the port's existing contract for every admin refusal.
- Portal after-states are English literals — low: localized sessions only.
- Tests hard-code IRISLOCALDATA — low: a moved store reddens the row-left leg.
- EXPERIENCE.md :112 and :155 carry no contents — low: the spec scoped copy to :173 and :371.
- Strings folded into the Task history row — spec-bound (993 lines).
- The spine's :46 port roster omits the port — low: every other port is recorded as an AD-27 case the same way.
- The GUID is typed `%Integer` and loses digits — false: the in-process `LIST` answers it as a string on `ocupilot-ci`; the live admin Pause is green.
- Two portal jobs started in one second show as one — low: the vendor query's own behavior (first id per `StartTime`), which AD-27's case names; an IRIS defect-report candidate.
- A reused job number between mint and confirm — low: needs a new portal job with that pid and an equal `Status` within ten minutes.
- The added rail verdict echoes itself — low: a roster row the spec lists; the verdict is pinned live by `Wire` and `WireSecurityRead`.
- The spec says a 200 MB seed where the code fills 1.2 GB — the fix edits the spec; for the lead.

## Spec Change Log

- 2026-09-28, after code review (lead): Boundaries' "`ForgetTask` always attempts the delete" is superseded by the review's patch -- it attempts the delete when the instance answers that the caller may write the row (`MayDeleteTask`), so an unprivileged read leaves no `<PROTECT>` audit row; the intent block is left as written. CI run 36496304575 on `73f7b3b8` was red on two tests this story reached: `tasks.browser-spec.mjs`'s Tasks side-bar roster (now five entries) and `BackgroundTasksLive`'s agent pause, which read the state before the vendor carried the pause out (now `BackgroundSeed.Settled`); both fixed by the lead, test-only.

- 2026-09-28, spec gate (lead): the plan's intent gap answered -- Q1 (A), a new `BackgroundTaskPort` as AD-27's Story 16.5 case; Q2, one appended step in `Kernel/Retention.cls`. Spine amended (AD-8, AD-15, AD-27, AD-37, AD-53). DW-1080 re-owned to `18-3-databases-configuration-creation-properties-and-volumes` and DW-1638 to `16-11-start-suspend-and-resume-the-task-manager` (by=spec_gate). Status `blocked` to `ready-for-dev`.

## Review Triage Log

### 2026-09-28 — Review pass

- verdicts: 26 findings — high 0, medium 5, low 16, false 4, maybe-false 1
- findings:
  - `[medium]` `[patch]` (verification-gap) No live test checks the listed `StartTime` and `ErrorCount` values, so a misread column ships green — `TestASeededPortalCompactIsListedPaused` now compares every listed field with the portal's own query row read in `%SYS` (the job's error count set to 2), and the admin leg asserts a start time; mutation run 18350.
  - `[medium]` `[patch]` (verification-gap, Rule 19; grouped with the row above) The `%IsDefined` loop cannot fail, because `Read.Project` writes `null` for a missing key — replaced by the value comparison above.
  - `[low]` `[patch]` (verification-gap) `BackgroundTaskMint`'s separator refusal has no test — `BackgroundTasks.TestTheMintRefusesTheSeparatorInAnArgument` pins its problem text, since the kernel's absent-target refusal is also 400 `TOOL.ARGUMENTS`; mutation run 18353.
  - `[low]` `[patch]` (verification-gap, Rule 19) `AdminPortForget`'s "it is not a protect" assertion cannot fail for a `%All` caller — deleted; `SetHoldsPair(0)` kept with a comment, since it arms the recorded guard-restore mutation.
  - `[low]` `[reject]` (verification-gap, Rule 19) No mutation line for the sweep's age and state legs or the browser Changed tag — Rule 19 asks one demonstrated mutation per AC, and AC2 and AC4 each carry several.
  - `[medium]` `[patch]` (verification-gap) A `background` read's shape is unchecked, so a later descriptor could send any admin endpoint through it past the admin-read pair rules — `Registry.ReadProblem` and `screen-mirror.mjs` `readProblem` now require the port's endpoint, `LIST` and no `rowGet`/`forEach`/`query`/`parts`, with four `AdminPairCorpus` cases; mutations run 18356 and the client test.
  - `[maybe-false]` `[defer]` (verification-gap) A compact could finish between Resume and the next Pause on a faster CI host — deferred as medium (unverified).
  - `[low]` `[reject]` (intent-alignment) The admin half is cut at the cap in the vendor's newest-queued order before the merge by start — it differs only for a caller with more admin tasks than the cap whose queue and start orders disagree.
  - `[false]` `[reject]` (intent-alignment) Any admin 409, and a `SysBGTaskId` that no longer opens, map to the published refusal — `AsyncResult` control's 409s are `AsyncTask`'s state refusals, and the vendor query itself blanks an id that does not open (`BackgroundTask.cls:1218-1220`).
  - `[false]` `[reject]` (intent-alignment) An admin cancel of a paused task is refused — the vendor cancels an async task only while it is `Queued`, a state refusal the intent covers.
  - `[low]` `[reject]` (intent-alignment) The sweep matches the label by "contains" — vendor task names are `<verb> <path>`, and no route the vendor queues carries `/v2/ocupilot/` elsewhere.
  - `[false]` `[reject]` (intent-alignment) The sweep's 24-hour cutoff might use another clock than the vendor's — `AsyncTask` stamps `TimeQueued` with `$ZDATETIME($H, 3)`, the clock `SweepOwnTasks` uses.
  - `[low]` `[reject]` (intent-alignment) The Changed tag after Pause and Resume is not rendered in a browser test — the change-event path is shared, and the browser Cancel leg pins it.
  - `[low]` `[reject]` (intent-alignment) A Cancel card predicts `Cancelled` where a caller without `%DB_IRISSYS:WRITE` re-reads `Exited` — spec-bound `StateDiff` spelling; AD-58 computes no compare for an action-style write.
  - `[low]` `[reject]` (intent-alignment) A successful admin cancel is never exercised live — same `AdminControl` path as the live admin Pause and Resume, and the vendor's cancel window (`Queued`) cannot be held by a test.
  - `[medium]` `[patch]` (intent-alignment) No not-allowed case reaches the real vendor — a live Pause of the canceled compact now asserts vendor 9503 answered as 409 `TASK.BACKGROUND.STATE` with the published sentence; mutation run 18354 (500 without the mapping).
  - `[low]` `[reject]` (intent-alignment) A finished portal job's stored status is not tested against the vendor — the vendor query computes it, and the listed status is now compared with the query's own on a live row.
  - `[low]` `[reject]` (intent-alignment) The "(none)" placeholder is not asserted for this screen — shared table rendering of an empty cell.
  - `[low]` `[reject]` (intent-alignment) The Tasks-only holder's rendered text and client route refusal are not asserted — shared shell rendering of a server verdict pinned live by `TestATasksHolderKeepsTheAreaAndIsRefusedBackgroundTasks`.
  - `[medium]` `[patch]` (intent-alignment) The port's own `%Admin_Operate:USE` check is unexercised — the fixture deny leg now covers both `PAIRS` members; mutation run 18355.
  - `[low]` `[reject]` (intent-alignment) Cross-half order and `truncated` are not asserted live — the fixture pins the merge order and cap; truncation is the executor's shared N+1 path.
  - `[low]` `[reject]` (intent-alignment) The agent's dispatch path and admin half are unexercised — dispatch reaches the same mint and confirm the live test calls, and `ToolRoundTrip` covers the schema.
  - `[low]` `[reject]` (intent-alignment) No confirm or action after a purge — both callers reach the fresh read through `Operation.ReadTarget`, pinned to 404.
  - `[low]` `[reject]` (intent-alignment) "Row left" is asserted on the direct `ForgetTask` call, not the async-read path — the async path calls the same method.
  - `[low]` `[reject]` (intent-alignment) A failed sweep step's logged status is untested — `Retention.Step` is the existing shared step logger.
  - `[false]` `[reject]` (intent-alignment) The portal script reads `^IRIS.Temp.MgtPortalTask` rather than the query — the query reads the same node and blanks an id that does not open, which the script refuses the same way.

## Design Notes

**Ruling (lead, spec gate 2026-09-28): Q1 (A), Q2 the appended step.** AC3 itself requires the custom half, and AD-27's conditions hold (the admin API has no such operation), so `BackgroundTaskPort` is recorded as AD-27's Story 16.5 case, with AD-8, AD-15, AD-53 and AD-37 amended in the same commit. `Kernel/Retention.cls` is not on the orchestrator's contended list and Epic 18 has not touched it, so the one appended step is taken and reported as a footprint extension. The plan's options, for the record:

- **Q1, AC3's second half.** "The rest" is two vendor stores that no admin-API class reaches (measured):
  - the portal's job log `^IRIS.Temp.MgtPortalTask` (IRISTEMP, instance-wide), read by the classic page's own query;
  - `%SYS.BackgroundTask` for the Compact and Defragment rows it can control.

  `AsyncResult` opens only the caller's `%Api.Admin.Util.AsyncTask` rows (404 `#5809` otherwise). The options:
  - **(A) Recommended, and the one this spec is written to.** A new `BackgroundTaskPort`, recorded as an AD-27 named case, as `WalletPort` and `ProcessPort` are. It merges both halves in one read, so there is no composition kind and no tab group. Its read key `background` is a port endpoint (AD-36's first kind), not a new kind.
  - **(B)** Put the portal half into `LogSourcePort`. The classic page calls itself a log ("Purge Log"), but controlling running jobs widens that port's charter, and B still needs the AD-27 case.
  - **(C)** Ship only the admin half as stated partial parity. That narrows the product, so it is the owner's call.
- **Q2, DW-1136's sweep step.** `Kernel/Retention.cls` is outside Epic 16's footprint and inside Epic 18's `Kernel/**`, so it is contended (Rule 11c).
  - Recommended: the one appended step.
  - The fallback, the installer's start path, bounds the rows by restarts, not by time.

**Spine cases this story needs** (the lead records them at the spec gate, Rule 20):

- **AD-27:** the `BackgroundTaskPort` case.
- **AD-8:** Background tasks' own pair `%Admin_Operate:USE`.
- **AD-15 and AD-53:** named no-vendor-event cases. Pause, resume and cancel wrote no audit row with auditing on, by either path (measured).
- **AD-37:** OcuPilot deletes the async task rows its own port queued (the sweep).

**Measured on `ocupilot-ci`, 2026-09-28:**

- **Minimum pairs.** The portal read needs `%DB_IRISSYS:READ` and the switch to `%SYS`. Control adds `%Admin_Operate:USE`.
- **Pause timing.** A 200 MB compact finishes in 0.6 s, so the seed pauses at once.
- **`ERROR #7846`** did not reproduce on two `GET`s. The no-`GET` rule stands anyway.
- **Sweep scheduling.** No `%SYS.Task` schedules the vendor's `PurgeAsyncQueue`.
- **Async rows** (`ocupilot-ci` holds 180):
  - 162 are unprivileged test principals' (DW-1136).
  - 17 are `irisowner`'s `GET /v2/ocupilot/database/syscrud` rows. `AdminPortAsync` proves the await removes a privileged caller's row. These are from arms that end the await before the worker's last save — a timeout, a background continuation, the fixtures' canned polls (inference) — which is DW-1101's residue, so the sweep takes them.

**Parity gaps, stated:**

- No Purge command.
- No progress detail dialog.
- The Error count is not linked to Logs › Background task errors.
- An administrator sees only their own admin API tasks.
- Status changes after a write show only on the next read (no auto-refresh).

**Declined DW-1080 (the Database details section):** the port decision is taken here (Q1), and `%SYS.BackgroundTask:DatabaseList` is public (`irissys/%SYS/BackgroundTask.cls:911`), so no AD-36 widening is needed. `DatabaseDetails.cls` is `18-3-databases-configuration-creation-properties-and-volumes`'s, and the lead routes the section there.

**Declined DW-1638:** it is about the Task Manager's scheduled-task row tools, not background tasks. It belongs to `16-11-start-suspend-and-resume-the-task-manager`, which builds the Task schedule's next actions. The fix is a public wrapper for the private `TaskRules.Permitted` (:996) and an `ArgumentProblem` in each of `TaskDelete`/`Suspend`/`Resume`/`Run`/`ScheduleRun`, the last four with a `GET` for `TaskClass` and `NameSpace` (`INFO` carries neither).

**Governing ADs:** AD-2, AD-5, AD-8, AD-13, AD-14, AD-15, AD-16, AD-22, AD-24, AD-26, AD-27, AD-29, AD-36, AD-37, AD-43, AD-44, AD-51, AD-52, AD-53, AD-58, AD-59.

**Integration ACs:** `BackgroundTaskPort` is consumed in this story by the list page, the screen-action route and the agent's confirm, each exercised against the instance by `BackgroundTasksLive` and the browser spec. **Consumes:** `AdminPort` (`AsyncResult`), `Retention.Sweep`, the warning dialog. **Consumed-by:** DW-1080's Database details section (18.3), through `DatabaseList`.

**Contended files, touched add-only:** `AdminPort.cls` lists, `EntityType.cls`, `Baseline.cls`, `Api/Error.cls`, `strings.ts`, EXPERIENCE.md (in place), and the rosters above. `AdminPort`'s method edits are confined to `ForgetTask` and the new `SweepOwnTasks`.

## Verification

**Commands:**

- `rsync -a --delete src/ /tmp/ocupilot-ci/src/` and `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-16/compile.sh <changed paths>`, then `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>`, one class per call (loop), for:
  - `BackgroundTasks`, `BackgroundTasksLive`, `AdminPortForget`, `AdminPortAsync`, `LogSecondaryWire`, `LogPairs`, `ReadTool`, `SurfaceCoverage`, `Descriptor`, `Wire`, `ToolWrite`, `ToolRoundTrip`, `ScreenRead`, `GovernanceBaseline`.

  Expected: green. Planned mutations:
  - drop the portal half from the port's `LIST` → the `BackgroundTasksLive` listing leg red;
  - drop the admin half → the admin-row leg red;
  - skip the portal vendor call → the pause, resume and cancel legs red;
  - guard `ForgetTask` with a pair the caller lacks → `AdminPortAsync` "the queued row is gone" red;
  - drop the sweep's label condition → the unlabeled leg red;
  - remove the Retention step → the retention leg red;
  - read `FetchTasks` outside `%SYS` → the task-error-log pair leg red;
  - drop `ownPrivileges` → the `BackgroundTasks` descriptor test red.
- `cd ui && npm run test:tools && npx ng test --include src/app/shell/screen-action-handler.spec.ts --include src/app/shell/list-page.spec.ts` (loop). Expected: green. Planned mutation: remove `cancel` from `WARNING_CONSEQUENCES` → the warning case red.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/background-tasks.browser-spec.mjs` (loop). Expected: green.
- `cd ui && npm test` (once, before dev_complete). Expected: green, with the bundle under `maximumWarning` 2107kB.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete). Expected: green apart from the known residue. The full browser suite is CI's.

**Mutations observed (implement pass).** Each ran on `ocupilot-ci` after rsync and a recompile of the class and its descendants. Each was then reverted and recompiled, and `git status --short` and `git diff --stat` were unchanged.

- mutation (AC1, AC3, portal half): drop `tPortal` from `BackgroundTaskPort.Rows`'s merge -> `BackgroundTasksLive.TestASeededPortalCompactIsListedPaused` "the screen's read lists it" went red (run 18320).
- mutation (AC1, AC3, admin half): drop `tAdmin` from the merge -> `BackgroundTasksLive.TestAnAdminApiCompactIsListedAndPausedThroughAsyncResult` (run 18321) and `BackgroundTasks.TestTheListMergesBothHalvesNewestFirst` (run 18329) went red.
- mutation (AC1, the caller's own admin tasks): `AdminPort`'s stub `%session` carries `"_SYSTEM"` in place of `$USERNAME` -> `BackgroundTasksLive.TestAnotherCallersAdminTaskIsNotListed` went red (run 18345; green on the restored tree, run 18344).
- mutation (AC2): answer `$$$OK` in place of the vendor call in `PortalControl` -> the resume and cancel legs of `BackgroundTasksLive.TestTheScreensActionsResumePauseAndCancelACompact`, and `TestTheAgentsConfirmPausesACompact`, went red (run 18322).
- mutation (AC2, client): empty `WARNING_CONSEQUENCES`'s `BackgroundTaskList` entry -> the Story 16.5 warning cases in `screen-action-handler.spec.ts` and `list-page.spec.ts` went red. After a rebuild and redeploy, the AC2 test in `background-tasks.browser-spec.mjs` went red as well.
- mutation (AC4, the delete): `If 1 Quit` before `ForgetTask`'s delete -> `AdminPortAsync` "the queued row is gone" went red in two tests (run 18323). The runner holds `%All`, so a guard on a real pair would pass for it. The `HoldsPair("%DB_IRISLOCALDATA:WRITE")` guard -> `AdminPortForget.TestTheDeleteIsNotGatedOnAPairAndAnotherFailureIsLogged` went red (run 18338).
- mutation (AC4, logs nothing): attempt `ForgetTask`'s delete without asking `MayDeleteTask` -> `AdminPortForget.TestAnUnprivilegedCallersDeleteLeavesTheRowAndLogsNothing` "the delete met no protect" went red (run 18715).
- mutation (AC4, only OcuPilot's rows): drop the label condition from `SweepOwnTasks` -> `AdminPortForget.TestTheSweepTakesOnlyOcuPilotsTerminalRowsADayOld` "the Unlabeled row is left" went red (run 18324).
- mutation (AC4, daily): the Retention step answers `$$$OK` without calling `SweepOwnTasks` -> `AdminPortForget.TestTheRetentionSweepDeletesOcuPilotsOldRows` went red (run 18326).
- mutation (task error log):
  - read `FetchTasks` outside `%SYS` -> the task-error-log leg of `TestASeededPortalCompactIsListedPaused` went red (run 18327);
  - drop `%DB_IRISSYS:READ` from `TASKERRORSPAIRS` -> `TestTheTaskErrorLogRequiresTheSystemRead` went red (run 18337).
- mutation (AD-8 own pair):
  - drop `ownPrivileges` -> `BackgroundTasks.TestTheDescriptorDeclaresTheListItsPairsAndItsActions` went red (run 18328);
  - move `%Admin_Operate:USE` from `ownPrivileges` into the Tasks area's pairs -> `BackgroundTasksLive.TestATasksHolderKeepsTheAreaAndIsRefusedBackgroundTasks` went red (run 18336).
- mutation (`BackgroundTasks`), applied one at a time:

  | Mutation | Red test | Run |
  |---|---|---|
  | compare ids numerically in `Find` | `TestTheFreshReadComparesTheCompositeIdExactly` | 18330 |
  | add `Details` to `FINGERPRINTSUBJECT` | `TestTheFingerprintRefusesAMovedStatus` and `TestTheToolsAreActionWritesOverTheScreensOwnPairs` | 18331 |
  | drop the no-`SysBGTaskId` refusal | `TestAPortalJobWithNoBackgroundTaskSendsNothing` | 18333 |
  | drop the `PORTALSTATECODES` mapping | `TestEveryVendorStateRefusalIsTheOnePublishedCode` | 18334 |
  | send every control row through `Snippet`'s admin branch | `TestTheScriptRendersBothBranches` | 18335 |

- After the pass, every changed class was recompiled from the tree. Then these ran green:
  - `BackgroundTasks` (run 18340), `BackgroundTasksLive` (18341), `AdminPortForget` (18342) and `AdminPortAsync` (18343);
  - on the rebuilt, redeployed bundle, the browser spec (2/2) and the two component specs (82/82).

**Mutations observed (review pass).** Applied one at a time on `ocupilot-ci` with the mutated class and its descendants recompiled, then reverted and recompiled; the tree was byte-identical after each.

| Mutation | Red test | Run |
|---|---|---|
| read the portal `StartTime` column as `Started` in `PortalRows` | `BackgroundTasksLive.TestASeededPortalCompactIsListedPaused` "the listed StartTime is the portal's own" | 18350 |
| delete `BackgroundTaskMint`'s separator refusal | `BackgroundTasks.TestTheMintRefusesTheSeparatorInAnArgument` | 18353 |
| drop the `PORTALSTATECODES` mapping, live | `BackgroundTasksLive.TestTheScreensActionsResumePauseAndCancelACompact` (a Pause of the canceled compact answered 500) | 18354 |
| drop `%Admin_Operate:USE` from the port's `PAIRS` | `BackgroundTasks.TestTheListMergesBothHalvesNewestFirst` | 18355 |
| drop the `background` read-shape rule from `Registry.ReadProblem` | `ReadTool.TestEveryAdminPairCorpusCaseGetsItsSentence`, the three background cases | 18356 |
| drop the `background` read-shape rule from `screen-mirror.mjs` `readProblem` | `screen-mirror.test.mjs` "readProblem returns every admin-privilege sentence" | client |

**Mutations observed (code review).** Applied one at a time on `ocupilot-ci`, the mutated class compiled with its subclasses, then reverted and recompiled; the tree was byte-identical after each.

| Mutation | Red test | Run |
|---|---|---|
| drop 9502 from `BackgroundTaskPort.PORTALSTATECODES` | `BackgroundTasks.TestEveryVendorStateRefusalIsTheOnePublishedCode` | 18712 |
| attempt `ForgetTask`'s delete without asking `MayDeleteTask` | `AdminPortForget.TestAnUnprivilegedCallersDeleteLeavesTheRowAndLogsNothing` | 18715 |
| halve `SweepOwnTasks`' cutoff hours | `AdminPortForget.TestTheSweepTakesOnlyOcuPilotsTerminalRowsADayOld` (the Day23 row) | 18717 |
| add `%Admin_Secure:USE` to `BackgroundTaskPort.PAIRS` | `BackgroundTasksLive.TestTheScreensActionsResumePauseAndCancelACompact` (the least-privileged Pause) | 18721 |

Green on the restored tree: `BackgroundTasks` 10/10 (18723), `AdminPortForget` 4/4 (18719), `AdminPortAsync` 4/4 (18718), `BackgroundTasksLive` 7/7 (18722); `WireSecurityRead` 23/24 (18724, the known task-history residue only).

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** Background tasks is the fifth Tasks entry: `Port/BackgroundTaskPort` (AD-27's 16.5 case) merges the caller's `AsyncResult` `LIST` with the portal's `EnumerateTasks` read in `%SYS`, behind its own `%Admin_Operate:USE` and `%DB_IRISSYS:READ` gate, and carries cancel, pause and resume to `AsyncResult` or `%SYS.BackgroundTask`, mapping vendor state refusals to `TASK.BACKGROUND.STATE`. Three action-style tools (fingerprint `Status`, governance keys enabled), the list descriptor with `ownPrivileges`, the `background` read source in both engines (with a shape rule), the Cancel warning, strings and EXPERIENCE.md (993 lines). `AdminPort.ForgetTask` always deletes and stays silent only on `<PROTECT>`; `SweepOwnTasks` is the retention sweep's new last step; the task error log reads in `%SYS` and requires `%DB_IRISSYS:READ`. Plan stage: see the Spec Change Log.

**Files.**

- New server: `Port/BackgroundTaskPort.cls`; `Screen/Descriptor/BackgroundTaskList.cls`; `Screen/Tool/BackgroundTaskCancel.cls`, `Pause`, `Resume`, and `BackgroundTaskMint.cls` (joins `source` and `id`).
- Changed server: `Port/AdminPort.cls` (type lists, `ForgetTask`, `SweepOwnTasks`, `ASYNCTASKPAIR` removed); `Port/LogSourcePort.cls` and `Screen/Descriptor/LogTaskErrorViewer.cls` (task error log); `Screen/Read.cls` and `Screen/Registry.cls` (the `background` source and its shape rule); `Kernel/Retention.cls` (the sweep step); `Kernel/EntityType.cls`, `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`, `Api/Error.cls` (appended entries).
- New tests: `Test/BackgroundTasks.cls`, `Test/BackgroundTasksLive.cls`, `Test/BackgroundSeed.cls`, `Test/BackgroundTaskFixture.cls`, `Test/BackgroundTaskConfirm.cls`, `Test/BackgroundTaskMintFixture.cls`, `ui/browser/background-tasks.browser-spec.mjs`.
- Changed tests and rosters: `AdminPortForget`, `PortFixture`, `AdminPairCorpus`, `Descriptor`, `LogPairs`, `LogSecondary`, `LogSecondaryWire`, `LogSource`, `LogSourceDenial`, `PortGate`, `Prohibited`, `ProposalConfirm`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `Wire`, `WireSecurityRead`; `scripts/ci-throwaway.sh` (arming comment).
- Client: `ui/src/app/core/strings.ts`, `screen-actions.ts`, `screens.generated.ts` (regenerated), `ui/src/app/shell/screen-action-handler.ts` and its spec, `list-page.spec.ts`, `rail-wire.spec.ts`; `ui/tools/screen-mirror.mjs` and the tool tests; EXPERIENCE.md `:173` and `:371`.

**Review.** 26 findings (high 0, medium 5, low 16, false 4, maybe-false 1): 7 patched (four medium entries, two low, one deletion), 1 deferred (the maybe-false compact-timing flake), 18 rejected with reasons in the Review Triage Log. Follow-up review recommended: false — the four patched medium entries are each pinned by a demonstrated mutation (runs 18350 to 18356), so no unverified risk remains to name. Before review, the Matrix Test Audit found the "Others' admin tasks" row uncovered; `TestAnotherCallersAdminTaskIsNotListed` was added (mutation run 18345).

**Verification.**

- Targeted classes on `ocupilot-ci`, one per call, green after the last patch: `BackgroundTasks` 10/10 (18705), `BackgroundTasksLive` 7/7 (18706), `AdminPortForget` 4/4, `ReadTool` 27/27, `LogSecondary`, `LogSource`, `LogSourceDenial`, `PortGate`, `ProposalConfirm`, `ToolEmit` (18680).
- Full ObjectScript sweep (once, `--shard k/16` over the 342 classes the instance offers, one class at a time): 2,672 tests, 12 failed on the first pass. Six classes failed on this story's own changes, were fixed and re-ran green: `LogSecondary`, `LogSource` and `LogSourceDenial` (the task error log's new pair), `PortGate` (roster row), `ProposalConfirm` (`tasks.background.cancel` matched its "cancel" name check) and `ToolEmit` (the tools now declare `WRITERESOURCE`). Residue, all known: `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal`, `TaskHistory`'s three demo-task tests, `Retention.TestAnEntryAgesByItsOwnDefinitionAndTheLedgerByTheLongest` (other suites' expired rows on the long-lived throwaway; red in runs 16919, 17323 and 17724 before this story), and 19 classes refusing on older arming variables (`AuditPurge`, `AuditingUpdate`, `DemoErrorSeed`, `DraftExecute`, `ErrorDelete`, `InjectionChannels`, `InjectionCompromised`, `LdapEdit`, `LdapUpdate`, `PreferencesWire`, `ProcessControl`, `ServiceEdit`, `TaskCreate`, `TaskEdit`, `TaskResume`, `TaskRules`, `TaskSave`, `TaskUpdate`, `TaskWire`).
- `npm run build`: green; bundle initial total 2.06 MB (main 1.88 MB, styles 172.99 kB), under the 2107kB warning. Deployed to `ocupilot-ci`; `background-tasks.browser-spec.mjs` 2/2, DW-1337 walk included.
- `npm test`: tools 1,687/1,687; components 126 files passed.
- `check-objectscript.py` 0 problems; `lint-docs.sh` clean. `ocupilot-ci` left with no seed database, resource, test principal or seeded async row.

**Residual risks.** The compact-timing flake (deferred). An admin row older than the 1,000 newest async rows a caller owns cannot be acted on (the fresh read lists that many), unlikely now that the await and the daily sweep delete them (inference). `AdminPortForget`'s retention leg runs the whole sweep, so on a long-lived throwaway it also deletes other suites' expired rows.

**Footprint extensions:** `src/OcuPilot/Kernel/Retention.cls`, `src/OcuPilot/Kernel/EntityType.cls`, `src/OcuPilot/Kernel/Governance/Baseline.cls`, `scripts/ci-throwaway.sh`, `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`.
