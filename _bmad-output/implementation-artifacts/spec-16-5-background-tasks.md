---
title: 'Story 16.5: Background tasks'
type: 'feature'
created: '2026-09-28'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
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

## Spec Change Log

- 2026-09-28, spec gate (lead): the plan's intent gap answered -- Q1 (A), a new `BackgroundTaskPort` as AD-27's Story 16.5 case; Q2, one appended step in `Kernel/Retention.cls`. Spine amended (AD-8, AD-15, AD-27, AD-37, AD-53). DW-1080 re-owned to `18-3-databases-configuration-creation-properties-and-volumes` and DW-1638 to `16-11-start-suspend-and-resume-the-task-manager` (by=spec_gate). Status `blocked` to `ready-for-dev`.

## Review Triage Log

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none -- resolved at the spec gate by the lead's ruling (Spec Change Log). The plan's halt read: intent gap -- AC3's second half needs a new port and a new AD-27 named case, which the dispatch reserves for the lead. Q1: (A) recommended, a new `Port/BackgroundTaskPort` extending AdminPort as an AD-27 case, merging the caller's `AsyncResult` `LIST` with the portal's `EnumerateTasks` read in `%SYS`, and controlling portal rows through `%SYS.BackgroundTask` `Cancel`/`Pause`/`Resume` after its `%Admin_Operate:USE` guard; (B) the portal half inside `LogSourcePort`; (C) the admin half only, as stated partial parity (owner). Q2: DW-1136's daily sweep step lives in `Kernel/Retention.cls`, contended with Epic 18 (recommended: one appended step; fallback: the installer start path).

Planned (plan stage, 2026-09-28): the full spec for option A and Q2's recommendation. It was built from two code maps and one instance-measurement pass on `ocupilot-ci`, which measured the classic rows, least-privilege pairs, admin API routes and control, a seeded pausable compact, audit, and purge scheduling; everything created there was removed. The pass also found that the shipped task error log reader rewrites live jobs to `Exited` for a caller without `%DB_IRISSYS:READ`, which this spec fixes. `DW-1080`'s section and `DW-1638` are declined with named owners. `DW-1101`, `DW-1136` and `DW-1137` are addressed.
