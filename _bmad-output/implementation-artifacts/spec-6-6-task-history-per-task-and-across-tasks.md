---
title: 'Task history, per task and across tasks'
type: 'feature'
created: '2026-09-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Nobody can see in OcuPilot when a task ran, who ran it, or what it said when it failed. The agent has no read tool for task history either.

**Approach:** Two hand-written descriptors over `Task.CRUD`'s `HISTORY` request type, read through `AdminPort`.

- **Task history** is a listed `list (server criteria)` screen. Its criteria form comes first and it searches on the server.
- **History** is an unlisted, parent-scoped `list` under Task schedule, keyed by the task's numeric `Id`.

The same story settles DW-1020 for both parent-scoped screens.

## Boundaries & Constraints

**Always:**

- **Descriptors** (both):
  - area `tasks`, `built` true, entity `task-history-entry`, scope `instance`, `refreshes` false (AD-43)
  - no primary or row action, `paging` `cap`, `emptyNextKey` `tableReadOnlyEmptyNext`, `emptyAgentKey` `""`
  - `secretFields` `[]`, `context.fields` = read fields, no link-out
  - pairs `%Admin_Task:USE` then `%DB_IRISSYS:READ`, the same as the other Tasks lists, so the area union is unchanged
  - full details are in the Tasks table
- **Source type `HISTORY`** (both engines, `Test/ReadSourceCorpus.cls`):
  - `READSOURCETYPES` becomes `LIST,GET,UPCOMING,HISTORY` and `AdminPort.TYPESUFFIXES` gains `HISTORY`.
  - `HISTORY` takes `UPCOMING`'s rules: admin only, no `rowGet`, no `forEach`. The type-refusal sentence names all four types.
  - `Read.Execute` issues it as it issues `UPCOMING`. The call is synchronous: `Task.CRUD` has no `ShouldRunAsync` and `RunHistory` queues nothing (AD-26).
- **Criterion `vendorParam`** (both engines, `Test/CriteriaCorpus.cls`, one sentence per refusal):
  - It is optional on a `read.criteria` field and must match `^[A-Za-z][A-Za-z0-9]*$`.
  - Case-folded, it may not equal `maxRows` or `ns`, or another field's `param` or `vendorParam`.
  - `Read.SeedCriteria` puts the value under `vendorParam`. The caller, the refusal text and the tool schema all keep using `param`.
  - This is how Task history sends the vendor's own `filter`, a name `CRITERIARESERVEDPARAMS` reserves for the tool.
- **DW-1020 (both engines):**
  - The route id of a screen with a non-empty `parentScope` names an entity of its parent's primary entity type: `Registry.RouteEntityType(descriptor)` and `navigation.ts` `routeEntityType(screen)`. Its rows keep the descriptor's own `entityType`. Every other screen's route entity type is its own `entityType`.
  - Validation of the production set refuses a built descriptor whose `parentScope` names no built descriptor with that route and an id.
  - Results: Secrets gives `wallet-collection`, History gives `task`.
- **TaskScheduleList `id`** becomes `{"kind": "composite", "parts": ["Id"]}`, one segment holding the vendor's numeric id (AD-13). Its name cell then links to `tasks/schedule/history/<Id>` through `childListFor`, with no client change.
- **Task history page** (`DESCRIPTOR_PAGES`, the Story 6.5 precedent):
  - The form comes first: a text field for `search` and a checkbox for `userOnly` (checked sends `1`, unchecked sends nothing), then Search. There is no read, table or skeleton before Search.
  - Search reads once and draws the skeleton, then the rows. Refresh is offered only after the first Search.
  - The `/:id` route opens a dialog listing every read field of that row, and closing it returns to the bare route.
  - The criteria, the searched state and the answer survive the page being re-created on `/:id`.
- **Shared files** (`Registry`, `Read`, `AdminPort`, `Install/Smoke`, `Test/Descriptor`, `screen-mirror.mjs`, `screen-store.ts`, `strings.ts`): additive edits only. New EXPERIENCE.md Fixed strings rows are appended after `:358`. Non-ASCII in code is written `\uXXXX`.

**Never:**

- No auto-refresh, no action or menu item beyond Refresh, no task created, run or suspended by any test or fixture, and no new port.
- No edits to any of these:
  - `Kernel/**`, `Screen/Tool/**`, `shell/panel/**`
  - `Port/ProviderPort.cls`, `scripts/check-objectscript.py` and its test
  - `app.ts`, `app.spec.ts`, `ui/package*.json`, `angular.json`, `README.md`
- No change to `AuditPage` or `AuditSearch`.
- A refusal is never an empty state or a 500.

## I/O & Edge-Case Matrix

The throwaway has the demo fixture. Its demo task's install-time run fails and leaves history rows. Reads are `GET /api/ocupilot/screens/<tool>/read`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| All tasks | `tasks.history` | 200. `fields` = the Tasks table's 13, and each is a key of the live row. Rows equal `%SYS.Task.History:DescendingTaskHistoryFilter("",0)` in order, up to the cap. | No error expected |
| Search | `search=OcuPilotDemo` | The port receives `filter=OcuPilotDemo`. Every row's joined text contains it, and the demo task's failed run is present. | — |
| User-defined only | `userOnly=1` | Rows equal the query with `UserOnly` 1 | — |
| Bad criterion | `userOnly=2`, or `search` of 101 characters | 400 `READ.CRITERION` naming `userOnly` / `search`, port not called | Names the param |
| One task | `tasks.taskhistory?taskId=<demo Id>` | Every row has `TaskId` = that id. Its `Result` carries the demo task's error text and `Username` is present. | — |
| Unknown task | `taskId=999999` or `taskId=abc` | 200 with no rows, so the per-task empty state shows | Not a refusal |
| No task id | `tasks.taskhistory` with no `taskId` | Rows equal All tasks (vendor behavior, accepted) | — |
| Cap | `maxRows=1` on both | 1 row, `truncated` true | — |
| Pairs | Principal holding `%Admin_Task:USE` alone, then both pairs | 403 `AUTH.NOPRIVILEGE` naming `%DB_IRISSYS:READ` on both routes. With both pairs, 200 and rows equal the test account's. | Never 500 |
| Corpora | `ReadSourceCorpus`, `CriteriaCorpus`, the parentScope-resolves rule | Every case gets its sentence in both engines | — |

</intent-contract>

## Code Map

- **Vendor** (hidden; `iris_doc_get %Api.Admin.Endpoints.Task.CRUD.cls` in `%SYS`, `ocupilot-slot-b`):
  - `TYPEHISTORY` = 10, dispatched to `RunHistory`. `ResourcesOR` is `%Admin_Task` or `%Admin_Operate`, and `ValidateQueryParams` returns early.
  - With `taskId` present it runs `DescendingTaskHistoryForTask(taskId)`, otherwise `DescendingTaskHistoryFilter(filter, userOnly)`. The filter is an upper-cased substring match across every column. An unknown id gives `[]` (inference, from source).
  - Row keys: `LastStart, Completed, Name, Status, Result, TaskId, Namespace, Routine, Pid, ErrDate, ErrNumber, Username, LogDatetime`. Confirm `LogDatetime` and `ErrDate`'s live shape on the throwaway; the probe suspects a double conversion (inference).
  - `%SYS.Task.History` makes no privilege check of its own.
- **Probed on slot B** (read-only, 2026-09-16):
  - 650 rows. `Username` is present (`_SYSTEM`, `_Ensemble`, `TASKMGR`).
  - A failed run is two rows: `Status` 1 with `Error` holding the `<THROW>` text, then `Status` 0 with "TASK Suspended due to error". `Status` 1 therefore does not mean success; `Result` carries the error text.
  - Expiry notices have an empty start.
- **Classic pages:**
  - `irissys/%CSP/UI/Portal/TaskHistory.cls`: `RESOURCE %Admin_Operate`, the user-defined checkbox, and `DescendingTaskHistoryFilter`.
  - `TaskHistoryId.cls`: keyed by `$ID1`, `DescendingTaskHistoryForTask`.
- **Grammar:**
  - `Screen/Registry.cls`: `READSOURCETYPES` `:1229`, type check `:821`, `CRITERIARESERVEDPARAMS` `:995`, `CriteriaProblem` `:1036`, criterion field keys `:1113`, `ParentCriteriaProblem` `:1088`, id-parts rule `:1532`.
  - `ui/tools/screen-mirror.mjs`: `criteriaProblem` `:785`, `parentCriteriaProblem` `:822`, `CRITERIA_RESERVED_PARAMS` `:765`, `IdAccessor` `:1510`.
  - `Test/CriteriaCorpus.cls:97-100` (parentScope cases).
  - `Test/Screen/Sub.cls` (route `tasks/history`, a stand-in fixture): check it does not collide with the real route in any registry sweep.
- **Read and port:** `Screen/Read.cls` `SeedCriteria` `:496` (seed `:532-541`), admin type call `:260-265`. `Port/AdminPort.cls:99` `TYPESUFFIXES`.
- **Client:**
  - `core/navigation.ts`: `childListFor` `:216`, `parentListFor` `:226`, `parentCriteria` `:268`.
  - `core/table-model.ts:40` `rowKey` (composite joins parts), `shell/data-table.ts:431-441` (link order).
  - `shell/screen-outlet.ts:54,76` (`ARCHETYPE_PAGES`, `DESCRIPTOR_PAGES`).
  - `areas/logs/audit.page.ts` (form markup `:70-116`, searched gate `:119,178-196`, dialog `:123-131`): a pattern to follow, not something to share.
  - `areas/tasks/upcoming.page.ts` / `upcoming.store.ts` (`heldFor`, the page over ListPage's binding).
  - `ui/browser/audit.browser-spec.mjs:313-343` (the no-read-before-Search legs).
- **Precedent descriptors:** `TaskUpcomingList.cls` (doc voice, composite id), `WalletSecretList.cls` (parent-scoped), `AuditList.cls` (criteria), `WalletCollectionList.cls` (`wallet-collection`, single id).
- **Rosters and pins** (each gains both screens and tools unless noted):
  - `Test/ReadTool.cls:93-100` (24 tools → 26; `:861` type sentence)
  - `screen-mirror.test.mjs:364,537,668-682`
  - `navigation.test.mjs:124-140`
  - `Test/Wire.cls:~604-624`
  - `navigation-wire.test.mjs:92-120,312` and `shell/rail-wire.spec.ts:101-121,339` (both `LIVE_PAYLOAD` copies; Task history is listed at 4)
  - `Test/WireSecurityRead.cls:342-398` (`TASKUSER`, `TASKBOTHUSER`)
  - `Install/Smoke.cls:118-122,551-559` and `Test/Smoke.cls:509-532`
  - `Test/ScreenRead.cls`
- **UX:**
  - EXPERIENCE.md `:104` and `:107` (IA rows), `:165` (side-bar order), `:567` (archetype states), `:358` (last Fixed strings row).
  - `strings.test.mjs:321` (band ≤ 330).
  - Reusable keys: `tableColumnName`, `headerNamespaceLabel`, `processColumnUser`, `processColumnPid`, `processColumnRoutine`, `auditCriteriaSearch`.
- **Browser:** `ui/browser/tasks.browser-spec.mjs` (`DEMO_TASK` `:45`, principal `:50-52`, `before`/`after` `:111-155`).

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/ReadSourceCorpus.cls`, `src/OcuPilot/Test/CriteriaCorpus.cls`: the `HISTORY` type, `vendorParam` and the parentScope-resolves rule, each with its Boundaries refusals. Each rule gets identical sentences in both engines, a sound case and one case per refusal. Add `RouteEntityType` / `routeEntityType` and update the generated `ReadCriterionField` type.
- [ ] `src/OcuPilot/Screen/Read.cls`, `src/OcuPilot/Port/AdminPort.cls`: issue `HISTORY`, seed under `vendorParam`, and add the `HISTORY` suffix. Update both class docs in contract voice.
- [ ] `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls`: change the id to `composite ["Id"]`. Replace the doc paragraph on the id with the contract: a numeric id, because History and Story 6.7 key on it.
- [ ] `src/OcuPilot/Screen/Descriptor/TaskHistoryList.cls` and `TaskRunList.cls` (new): the declarations below. Each class doc states contract only: the vendor semantics above, why each archetype, and the route entity type.

  Both read `Task.CRUD` `HISTORY` with the same fields:
  - **fields:** `LastStart, Completed, Name, Status, Result, TaskId, Namespace, Routine, Pid, ErrDate, ErrNumber, Username, LogDatetime`
  - **filter:** `Name, Namespace, Status, Result, Username, Routine`
  - **sort:** `LastStart, Completed, Name, Namespace, Status, Result, Username, LogDatetime`, default `LogDatetime` desc
  - **id:** composite `[TaskId, LogDatetime, Status]`
  - **columns (field:kind:labelKey):** LastStart:text:taskHistoryColumnStarted · Completed:text:taskHistoryColumnCompleted · Name:name:tableColumnName · Status:text:taskHistoryColumnStatus · Result:text:taskHistoryColumnResult · Username:text:processColumnUser · Namespace:text:headerNamespaceLabel

  | Class | route · pos · tool · aliases · archetype | criteria (param:kind:maxLength:labelKey) | parentScope · emptyStateKey · classicPage |
  | --- | --- | --- | --- |
  | TaskHistoryList | `tasks/history` · 4 · `tasks.history` · `["task history", "task runs"]` · `list (server criteria)` | search:text:100:taskHistorySearch, `vendorParam` `filter` · userOnly:choice:1:taskHistoryUserOnly, options `["1"]` | `""` · `taskHistoryEmpty` · `%CSP.UI.Portal.TaskHistory` |
  | TaskRunList | `tasks/schedule/history` · 0 · `tasks.taskhistory` · `[]` · `list` | taskId:text:10:taskHistoryColumnTaskId | `tasks/schedule` · `taskRunsEmpty` · `%CSP.UI.Portal.TaskHistoryId` |

  labelKeys: `taskHistoryLabel`, `taskRunsLabel`.
- [ ] `ui/src/app/core/navigation.ts`: add `routeEntityType`.
- [ ] `ui/src/app/areas/tasks/history.store.ts`, `history.page.ts`, `history.page.spec.ts` (new), and `ui/src/app/shell/screen-outlet.ts`: build the Task history page (Boundaries) and register it for `TaskHistoryList`. The store is framework-free (AD-19) and pinned by `ui/tools/history-store.test.mjs`.
- [ ] EXPERIENCE.md, `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs`: append two rows after `:358` in 6.5's style, each key commented `EXPERIENCE.md:<line>`. Reuse existing keys and widen the band if the count passes 330.
  - `:359` "Task history" · "Started" · "Completed" · "Status" · "Result" · "Task ID" · "Error date" · "Error number" · "Logged" · "Contains" · "User-defined tasks only" · "No task runs match."
  - `:360` "History" · "This task has no recorded runs."
  - Regenerate `screens.generated.ts`.
- [ ] `src/OcuPilot/Test/TaskHistory.cls` (new; needs the API app over HTTP, `_SYSTEM` and the demo fixture). It waits for the demo task's run row as `Test/Demo` waits for suspension, and creates nothing. Cover:
  - both descriptors validate with `AreaCoverageProblem` empty, and both classic pages compile
  - every Matrix row except Pairs and Corpora
  - `RouteEntityType` answers `task` for TaskRunList, `wallet-collection` for WalletSecretList and `task-history-entry` for TaskHistoryList
  - the Integration AC
- [ ] `src/OcuPilot/Test/ScreenReadSource.cls`: a fixture read issuing type `HISTORY`, and a criterion whose `vendorParam` reaches the port under that name and not under `param`.
- [ ] `src/OcuPilot/Test/WireSecurityRead.cls`: the Pairs row on both routes with the existing task principals, and the Tasks side-bar verdict with four listed entries.
- [ ] Rosters in the Code Map: add both screens and tools. Smoke gains `TASKHISTORYTOOL`, which passes on zero or one row at `maxRows=1`, as the OAuth checks do (21 checks). Update `navigation.test.mjs` for `routeEntityType` and TaskScheduleList's composite key.
- [ ] `ui/browser/tasks.browser-spec.mjs`: the browser legs of AC1-AC4.

**Acceptance Criteria:**

- **AC1 (across tasks).** Given `_SYSTEM` on the throwaway, when Task history opens from the fourth Tasks side-bar entry, then:
  - the criteria form shows with no read, table or skeleton
  - Search with "OcuPilotDemo" issues exactly one `tasks.history` read carrying `search`, and renders rows including the demo task's failed run
  - no command bar or command box action other than Refresh is offered, and none auto-refreshes
- **AC2 (one task).** Given Task schedule, when the user activates the demo task's name cell, then:
  - the URL is `tasks/schedule/history/<Id>`
  - one `tasks.taskhistory` read carries `taskId=<Id>`
  - every row names the demo task
  - the locator links back to Task schedule
- **AC3 (row content).** Given a history row from AC1 or AC2, when it renders, then Started, Completed, Status, Result (the error text where present) and User show. On Task history, activating the name cell opens a dialog listing every read field, and closing it restores the searched rows without a new read.
- **AC4 (gating).** Given the throwaway principal holding install-DB read and `%Admin_Task:USE` only, when it deep-links to either route, then it sees "You need %DB_IRISSYS:READ to open <title>." with no table and no read.
- **Integration.** Given consumer `Screen.Tool.Read.View`, when it reads `tasks.history.read` with `search` "OcuPilotDemo" and `tasks.taskhistory.read` with the demo `taskId` live, then each returns its route's fields and rows narrowed by the tool's row cap. Its input schema offers `search`, `userOnly` (enum `["1"]`) and `taskId` as criteria, while `filter` stays the tool's own view argument.

## Spec Change Log

- 2026-09-17 (spec gate, lead): AD-5 (route id takes the parent's entity type, DW-1020) and AD-36 (`HISTORY`, `vendorParam`) amended in the spine; EXPERIENCE.md `:104` makes the one-task history a plain `list`; the Task schedule row key change to `Id` and the temporary name-cell target (History until Story 6.7) accepted.

## Review Triage Log

## Design Notes

**Architecture decisions:**

- **AD-2 / AD-26 / AD-27:** `Task.CRUD` `HISTORY` through `AdminPort` only. It is synchronous and self-queues nothing (read from source).
- **AD-5:** two descriptors, and the sub-resource declares its parent. **AD-13 / AD-14:** rows are `task-history-entry` in scope `instance`; the route id's type is `task`.
- **AD-8 / AD-29:** the backing class checks nothing, so pairs are proven by a principal on the throwaway. **AD-21:** criteria are the allow-list, validated before the port.
- **AD-19:** the page store is framework-free. **AD-24 / AD-36:** one capped read per screen, shared with its tool. `Result` is untrusted text (AD-11).
- **AD-43:** neither screen refreshes, and neither is in the roster. **AD-44:** each names its classic page, and neither links out.

**Decisions for the gate:**

- **DW-1020 (Rule 20).** The route entity type is **derived** from `parentScope`, never declared a second time, so it cannot disagree with the parent. This clarifies AD-5 and changes no Rule. Recommended AD-5 addition: "Its route id identifies an entity of the parent screen's primary entity type, resolved through `parentScope`, while its rows keep its own."
- **AD-36 wording.** Recommend appending `HISTORY` beside `UPCOMING`, plus "a criterion may send its value under a declared vendor name (`vendorParam`)".
- **History is a `list`, not `list (server criteria)`.** Its only criterion is the route id, so a form before the read would have nothing to ask. Recommend amending EXPERIENCE.md `:104`'s archetype to `list`.
- **How History is reached.** Through Task schedule's name cell (`childListFor`) and by deep link. Story 6.7 re-points that cell to Task details and adds the History link (EXPERIENCE `:103-104`).
- **Task schedule's key becomes the numeric `Id`.** The vendor's per-task call takes only the id. Consequently the locator's entity segment on History reads the id, not the task name, until Story 6.7.
- **Server search sends the vendor's `filter`.** The criterion is renamed `search` because `filter` is the tool's own argument.
- **Row columns.** The vendor's `Status` is 1, empty or error text, and `Result` is "Success" or the error text. Both are shown, as the classic page shows them.
- **Row key.** No vendor key is unique, so the key is composite `[TaskId, LogDatetime, Status]`. That separates a failed run's two rows (inference that it suffices).

**Test rows.** No test creates or runs a task. The demo fixture requests its task's run at install, and that run fails, so a fresh throwaway with the demo holds a history row with error text within about a minute (inference, from `Fixture.CreateTask` and `DemoTask.OnTask`). Stock tasks add more rows. Tests wait for the demo row rather than assume it.

**Ledger inbox:** DW-1020 is addressed (Boundaries, Matrix Corpora, the `TaskHistory` test). DW-1001 and DW-1018 are not re-litigated. The DW-1021 analog does not arise: an unknown task id answers 200 with no rows.

**Integration ACs:**

- The Integration AC, plus AC1 and AC2 through the page and the data table.
- `RouteEntityType` / `routeEntityType` have no consumers in this story. The first consumer will be Story 4.4 (screen context).

**Consumes:** `AdminPort` (2.1), `Screen.Read` and criteria (2.3, 2.10), `ListPage` and the data table (2.4), the gate (1.9), `parentScope` and `childListFor` (6.3), and `UPCOMING` and the Tasks page precedent (6.5).

**Consumed-by:**

- 4.4: screen context uses `RouteEntityType`.
- 6.7: Task details links to `tasks/schedule/history/<Id>` and keys on `Id`.
- Epic 7/9: task writes publish `task`, which History's route type names.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: a clean compile. Slot B is only compiled into and read; nothing is created there.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy, with the demo fixture on. Every principal and every other state-creating step lives on this throwaway only. History rows come from its demo task's install-time run. Teardown: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`, `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for TaskHistory, ScreenReadSource, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor, Smoke, TaskLists and AdminPortSync -- expected: all green, with totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: the new history check passes, with no failures.
- `cd ui && npm run build && npm test` -- expected: green, and `screen-mirror --check` clean.
- From `ui/`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `tasks.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations (Rule 19).** Record each as `mutation: <change> -> <test red> (observed)`, then revert and confirm the tree is byte-identical.

- AC1: the page reads on open, and separately, `vendorParam` is ignored by `SeedCriteria` (recompiled with subclasses).
- AC2: TaskScheduleList's id goes back to `single`, with the mirror regenerated, the bundle rebuilt and redeployed.
- AC3: the `Result` column is dropped, and separately, the store clears on re-creation.
- AC4: `%DB_IRISSYS:READ` is dropped from TaskRunList.
- One task: `Read` issues `LIST` for `HISTORY`.
- DW-1020: `routeEntityType` returns the child's own type.
- Both engines: each new refusal arm is disabled in turn.
- Integration: the `userOnly` options are changed on the descriptor only.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only (halt after planning). Decisions for the gate are listed under Design Notes.
