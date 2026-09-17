---
title: 'Task history, per task and across tasks'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: 'cc88200bf9bbd3a6faa9db11fbc99e3e80c5297e'
review_loop_iteration: 0
followup_review_recommended: true
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

**Review pass 1 patches (2026-09-17):**

- [x] `src/OcuPilot/Screen/Registry.cls` `SourceQueryProblem` and `ui/tools/screen-mirror.mjs`
  `sourceQueryProblem`: each collects the names a criterion could reach the port under from
  `param` alone (`tCriteriaParams`/`criteriaParams`), never `vendorParam`. Add `vendorParam`
  (case-folded) alongside `param` to that collected set in both engines, so a fixed
  `read.source.query` key colliding with a criterion's `vendorParam` is refused the same way a
  collision with a criterion's `param` already is. Add one case to
  `src/OcuPilot/Test/ReadSourceCorpus.cls` pairing a `source.query` key with a declared
  `vendorParam` of the same name (case-folded), pinning the exact refusal sentence in both
  engines (the corpus already runs through both).
- [x] `src/OcuPilot/Screen/Registry.cls` `ParentScopeResolutionProblem` and
  `ui/tools/screen-mirror.mjs` `parentScopeResolutionProblem`: the inner search loop that looks
  for a resolving parent never excludes the entry being checked itself, unlike the sibling
  `CriteriaVendorParamProblem`/`criteriaVendorParamProblem`, which does (`If tInnerIndex =
  tOuterIndex Continue`). A built descriptor whose `parentScope` equals its own `route` therefore
  resolves against itself and passes DW-1020's check instead of being refused. Add the same
  self-exclusion to both engines' inner loop, and add a self-referential-`parentScope` fixture
  case (built descriptor, `parentScope` = its own `route`) to the `OcuPilot.Test.ParentScope.*`
  fixture package (and a matching registry subclass) added during implementation, asserted from
  `src/OcuPilot/Test/Descriptor.cls`'s `TestAParentScopeThatDoesNotResolveIsRefusedByTheRoster`,
  plus the mirrored case in `ui/tools/screen-mirror.test.mjs`.
- [x] `src/OcuPilot/Test/TaskHistory.cls`
  `TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap`: `tId` (from `..DemoTaskId()`) is used
  inside the loop guarded only by `If tValue = "" Continue`, so a failure to find the demo task's
  id silently skips the entire `TaskRunList`/`tasks.taskhistory` half of this Integration-AC test
  with no assertion failure. Add `Do $$$AssertNotEquals(tId, "", "the demo task's numeric Id is
  found on the live schedule")` before the loop, matching the pattern already used in
  `TestOneTaskReadsOnlyTheDemoTasksOwnRuns`.
- [x] `ui/browser/tasks.browser-spec.mjs`, "Story 6.6 AC3: activating a row's name cell on Task
  history opens a dialog...": after clicking the dialog's close button, the test asserts only DOM
  state (`[role="dialog"]` gone, `[role="grid"]` present, read count unchanged) and never reads
  `page.url()`, so AC3's own claim that closing the dialog "returns to the bare route" is
  unverified at the URL/routing level -- unlike the sibling AC2/AC3 test in the same file, which
  does assert `window.location.pathname` after its own back-navigation. Add an assertion after the
  close click that `new URL(page.url()).pathname` is the bare `/ocupilot/tasks/history` route.

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

### 2026-09-17 — Review pass

- verdicts: 15 findings — high 0, medium 6, low 3, false 6, maybe-false 0
- findings:
  - `[medium]` `patch` `SourceQueryProblem`/`sourceQueryProblem` never fold a criterion's `vendorParam` into the collision set they check a fixed `read.source.query` key against, only `param` — a future descriptor pairing `source.query` with a colliding `vendorParam` would silently defeat the "no caller can change a fixed parameter" guarantee (AD-36) — fixed: both engines now also collect `vendorParam`, case-folded, into the same set `param` already feeds; one `ReadSourceCorpus.cls` case (`query: {"Who":"1"}` vs a criterion `vendorParam: "who"`) pins the refusal sentence in both engines; Rule 19 mutation (drop the `vendorParam` collection) observed red on the new corpus case in both engines, reverted byte-identical.
  - `[medium]` `patch` (same defect, reported independently) — evidence and fix as above.
  - `[medium]` `patch` `ParentScopeResolutionProblem`/`parentScopeResolutionProblem`'s inner search loop never excludes the entry being checked from its own candidate search, unlike the sibling `CriteriaVendorParamProblem`/`criteriaVendorParamProblem`, which does — a built descriptor whose `parentScope` equals its own `route` resolves against itself and passes DW-1020's check instead of being refused — fixed: both engines now skip `tInnerIndex = tOuterIndex` / `inner === outer`; a new self-referential fixture (`OcuPilot.Test.ParentScope.Self.Child`, `ParentScopeSelfRegistry`) and its JS mirror case pin the refusal `"...Self.Child: parentScope 'parent-scope/self/child' names no built descriptor with that route and an id (DW-1020)"`; Rule 19 mutation (drop the self-exclusion) observed red on the new assertion alone in both engines, reverted byte-identical.
  - `[medium]` `patch` (same defect, reported independently) — evidence and fix as above.
  - `[medium]` `patch` `OcuPilot.Test.TaskHistory:TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap` used `tId` (from `DemoTaskId()`) inside a loop guarded only by `If tValue = "" Continue`, so a failure to find the demo task's id silently skipped the whole `TaskRunList`/`tasks.taskhistory` half of the Integration AC with no test failure, unlike the sibling `TestOneTaskReadsOnlyTheDemoTasksOwnRuns`, which asserts non-empty — fixed: added `$$$AssertNotEquals(tId, "", ...)` before the loop, matching the sibling's pattern; Rule 19 mutation (force `DemoTaskId` to never match) observed red exactly on the new assertion, reverted byte-identical.
  - `[medium]` `patch` AC3's "closing it returns to the bare route" claim was unverified at the URL/routing level — the browser test asserted only DOM state (dialog gone, table present, no new read) after the close click, never `page.url()`, unlike the sibling AC2/AC3 test in the same file, which does assert `window.location.pathname` after its own back-navigation — fixed: added a `page.waitForFunction`/`assert.equal` pair on `new URL(page.url()).pathname` being the bare `/ocupilot/tasks/history` route after close; Rule 19 mutation (`onCloseDetail` navigates to `screen.route + '/0'` instead of the bare route) observed red exactly on the new assertion (prior DOM-only assertions stayed green), reverted byte-identical, confirmed by an identical rebuilt bundle hash.
  - `[low]` `reject` Composite row id `[TaskId, LogDatetime, Status]` could collide for two runs of the same task at the same second with the same status — real in principle, but the spec's own Design Notes already name and accept this exact risk ("That separates a failed run's two rows (inference that it suffices)"); requires a same-task/same-second/same-status double run to manifest, and a proper fix would need a vendor-provided sequence field this class does not expose — not worth a guard beyond the accepted inference.
  - `[low]` `reject` `history.store.ts` sends `userOnly=1` as a literal rather than deriving it from `TaskHistoryList`'s declared `options` — no shipped descriptor disagrees (`options` is exactly `["1"]`), and the same literal-value-tied-to-a-specific-descriptor pattern is already used elsewhere in this area (e.g. `UpcomingHorizon`'s hour choices); deriving it would be a design change, not a direct correction.
  - `[low]` `reject` The search input carries no client-side `maxlength`, so a >100-character search relies on the server's 400 rather than being blocked at input time — checked `AuditPage`'s own search field: it has no `maxlength` attribute either, so this matches existing project convention rather than regressing it; adding it only here would be the inconsistent choice.
  - `[false]` `reject` `## Auto Run Result` still read `Status: ready-for-dev` / "Planned only" after the frontmatter moved to `in-review` — this section is written by this workflow's own Finalize step, which runs after review triage completes; the diff reviewed here was staged mid-workflow, before that step, so the staleness was expected sequencing, not a defect. (Updated below under Finalize.)
  - `[false]` `reject` (same non-issue, reported independently) — evidence as above.
  - `[false]` `reject` `tasks.history`/`tasks.taskhistory` tool identifiers read "backwards" (the all-tasks screen is `tasks.history`, the per-task screen is `tasks.taskhistory`) — this is exactly what the spec's own Tasks & Acceptance table names literally for `TaskHistoryList` and `TaskRunList`; the code correctly implements the spec's stated names, and a change would be a spec edit, not a code fix.
  - `[false]` `reject` `TaskHistoryList`'s `commandAliases` includes `"task runs"`, which reads as more apt for `TaskRunList` — again exactly the spec's own table (`TaskHistoryList` aliases `["task history", "task runs"]`; `TaskRunList` aliases `[]`); correctly implements the spec as written.
  - `[false]` `reject` A cold deep link to `/tasks/history/<id>` before any Search shows no dialog and no table, silently — not a demonstrated bad outcome: this is the same "no table before Search" state AC1 already specifies as correct, is non-crashing, and neither the intent's matrix nor its ACs describe different behavior for this path.
  - `[false]` `reject` `screen-store.ts` was named in the spec's "Shared files: additive edits" list but received no changes — the file plausibly needed no change (composite-id/detail resolution reused existing unmodified helpers, confirmed by reading the diff), and naming a file as potentially-touched does not obligate an edit.

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

**Mutations observed (Rule 19), each applied, watched red, then reverted with the tree confirmed
byte-identical (an untracked new file's revert confirmed by exact-inverse edit and re-inspection;
a tracked file's by `git diff` against the pre-mutation working tree):**

- mutation: `history.page.ts` binds a real read and calls `readNow()` unconditionally instead of
  gating on `searchStore.searched()` -> browser `Story 6.6 AC1`'s "no read before Search"
  assertion red, reading one issued read (observed).
- mutation: `Read.SeedCriteria` seeds under `tParam` instead of the vendor key -> ObjectScript
  `OcuPilot.Test.ScreenReadSource:TestAHistorySourceIsIssuedAsItsOwnTypeAndVendorParamReachesThePort`
  red, the port receiving `search=` instead of `filter=` (observed).
- mutation: `TaskScheduleList`'s id reverted to `single` (mirror regenerated, bundle rebuilt and
  redeployed) -> browser `Story 6.6 AC2/AC3` times out waiting for rows, the name cell's link
  carrying the task's name instead of its vendor id so the per-task read matches nothing
  (observed).
- mutation: `TaskHistoryList`'s `Result` table column dropped (mirror regenerated, bundle rebuilt
  and redeployed) -> browser `Story 6.6 AC1`'s header-row assertion red, six headers instead of
  seven (observed).
- mutation: `TaskHistorySearch.readFor` calls `create()` unconditionally instead of memoizing ->
  `ui/tools/history-store.test.mjs`'s "readFor memoizes the first read it is given" red, a second
  object coming back instead of the first by reference (observed).
- mutation: `%DB_IRISSYS:READ` dropped from `TaskRunList`'s privileges -> `OcuPilot.Screen.Registry.Validate()`
  itself refuses the production roster, naming `TaskRunList`'s missing pair (observed directly,
  via `Validate` rather than a %UnitTest class, since the roster fails to validate at all).
- mutation: `Read.Execute`'s admin branch issues `..#READTYPE` (`LIST`) unconditionally instead of
  the declared `tSourceType` -> `OcuPilot.Test.TaskHistory` reddens 5 of 11 methods, including
  `TestAllTasksReadsTheVendorsHistory` (declared fields no longer answered) and the two polling
  methods (the demo task's failed run never found, since `LIST` answers Task schedule's shape)
  (observed).
- mutation: `Registry.RouteEntityType` returns `PrimaryEntityType` unconditionally, skipping the
  parent resolution -> `OcuPilot.Test.TaskHistory:TestRouteEntityTypeResolvesThroughTheParent` red
  alone (the other ten methods in the class stay green), reading `task-history-entry` where `task`
  is expected (observed).
- mutation: the HISTORY-source `rowGet` refusal arm removed from `Registry.ReadProblem`
  (ObjectScript) -> `ReadProblem` on a HISTORY+rowGet declaration falls through to a different,
  unrelated sentence (`read.source.rowGet.fields is empty...`) instead of the declared HISTORY
  refusal (observed directly, via `ReadProblem` rather than the corpus %UnitTest run). The same
  arm removed from `screen-mirror.mjs`'s `readProblem` -> the same shape answers a third, still
  different sentence (`...names the key field 'Name'...`) instead of the HISTORY refusal (observed
  directly, via `node -e`). Representative of the new refusal arms rather than exhaustive over
  every one Story 6.6 adds, given the number of arms and the cost of a throwaway cycle per check;
  the two-engine corpus tests (`ReadSourceCorpus`, `CriteriaCorpus`) already pin every arm's exact
  sentence against both engines on every run.
- mutation: `TaskHistoryList`'s `userOnly` options changed to `["1", "2"]` on the descriptor alone,
  mirror left stale -> `OcuPilot.Screen.Tool.Read.InputSchema`'s `userOnly` enum answers
  `["1","2"]` where the Integration AC's assertion expects the mirror's `["1"]` (observed directly,
  via `InputSchema`).
- mutation: `OcuPilot.Screen.Registry.ParentScopeResolutionProblem`'s body replaced with an early
  `Quit ""` -> `OcuPilot.Test.Descriptor:TestAParentScopeThatDoesNotResolveIsRefusedByTheRoster`'s
  three refusing-roster assertions go red, the not-found, not-built and no-id fixture rosters all
  validating clean instead of naming their DW-1020 sentence (observed).
- mutation: `screen-mirror.mjs`'s `parentScopeResolutionProblem` returns `null` unconditionally ->
  its own `node --test` assertion goes red, the not-found roster answering `null` where the
  DW-1020 sentence is expected (observed).
- mutation: `Registry.cls`'s `SourceQueryProblem` collects only `param`, not `vendorParam`, into
  its collision set (both engines) -> `OcuPilot.Test.ReadTool:TestEveryReadSourceCorpusCaseGetsItsSentence`
  and its own `node --test` case go red on the new `ReadSourceCorpus` case, a `source.query` key
  colliding with a criterion's `vendorParam` answering `null`/no refusal instead of the collision
  sentence (observed).
- mutation: `Registry.cls`'s `ParentScopeResolutionProblem` and `screen-mirror.mjs`'s
  `parentScopeResolutionProblem` inner search loop drops its `tInnerIndex = tOuterIndex` /
  `inner === outer` self-exclusion -> `OcuPilot.Test.Descriptor:TestAParentScopeThatDoesNotResolveIsRefusedByTheRoster`
  and the mirrored `node --test` case both go red on the new self-referential `ParentScope.Self.Child`
  fixture, a descriptor whose `parentScope` names its own route validating clean instead of being
  refused (observed).
- mutation: `TaskHistory.cls`'s `DemoTaskId` comparison forced to never match (simulating a demo
  task the live schedule cannot find) -> `TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap`'s new
  `$$$AssertNotEquals(tId, "", ...)` goes red; reverting only that assertion (pre-fix code) would
  instead have silently skipped the `TaskRunList`/`tasks.taskhistory` half of the test with no
  assertion failure (observed).
- mutation: `history.page.ts`'s `onCloseDetail` navigates to `screen.route + '/0'` instead of
  `screen.route` (an id the roster carries no row for, so the dialog still closes and the grid
  still renders) -> browser `Story 6.6 AC3`'s new `page.url()` pathname assertion times out waiting
  for the bare `/ocupilot/tasks/history` route, while the pre-existing DOM-only assertions above it
  would have passed against this exact regression (observed).

## Auto Run Result

**Summary.** Implemented two hand-written descriptors, `TaskHistoryList` (all tasks, `list (server
criteria)`) and `TaskRunList` (one task, unlisted `list` parented under Task schedule), both over
`Task.CRUD`'s new `HISTORY` request type, read through `AdminPort`. Added `HISTORY` to
`READSOURCETYPES`/`AdminPort.TYPESUFFIXES` in both engines with `UPCOMING`'s rules; added an
optional `vendorParam` on `read.criteria` fields so a criterion can send its value under the
vendor's own name; and settled DW-1020 with `Registry.RouteEntityType`/`navigation.ts
routeEntityType`, resolving a sub-resource screen's route-id entity type through its
`parentScope`, plus `ParentScopeResolutionProblem`/`parentScopeResolutionProblem` refusing a
built descriptor whose `parentScope` names no built descriptor with a route and an id.
`TaskScheduleList`'s id moved from `single` to `composite ["Id"]` so its name cell can link to
`tasks/schedule/history/<Id>`. Client: a new `HistoryPage`/`TaskHistorySearch` pair implements the
criteria-form-first, read-once, detail-dialog pattern for Task history, registered in
`DESCRIPTOR_PAGES`. A code-review pass then found and fixed four small gaps in the new validation
and test coverage (below).

**Files changed:**

- `src/OcuPilot/Screen/Registry.cls` — `HISTORY` source type, `vendorParam` criterion grammar,
  `RouteEntityType`/`ParentScopeResolutionProblem` (DW-1020); review-pass fix: `vendorParam` folded
  into `SourceQueryProblem`'s collision set, self-exclusion added to
  `ParentScopeResolutionProblem`'s inner search.
- `src/OcuPilot/Screen/Read.cls` — issues `HISTORY`; `SeedCriteria` seeds a criterion under its
  declared `vendorParam` when present.
- `src/OcuPilot/Port/AdminPort.cls` — `HISTORY` added to `TYPESUFFIXES`.
- `src/OcuPilot/Screen/Descriptor/TaskHistoryList.cls` (new) — the all-tasks screen.
- `src/OcuPilot/Screen/Descriptor/TaskRunList.cls` (new) — the per-task screen, parented under
  Task schedule.
- `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls` — id changed to `composite ["Id"]`.
- `src/OcuPilot/Install/Smoke.cls` — `TASKHISTORYTOOL` check, zero-or-one row like the OAuth checks.
- `src/OcuPilot/Test/ReadSourceCorpus.cls`, `Test/CriteriaCorpus.cls` — `HISTORY` and `vendorParam`
  corpus cases in both refusal directions; review-pass addition: a `source.query`/`vendorParam`
  collision case.
- `src/OcuPilot/Test/ReadSource/Endpoint.cls`, `Test/ReadSource/History.cls` (new),
  `Test/ScreenReadSource.cls` — fixture coverage for a `HISTORY` source with a `vendorParam`
  criterion.
- `src/OcuPilot/Test/Screen/SslParent.cls`, `Test/Screen/TaskScheduleParent.cls` (new) — built
  parent fixtures so two pre-existing `parentScope` literals resolve under the new DW-1020 check.
- `src/OcuPilot/Test/ParentScope/{NotFound,NotBuilt,NoId,Sound,Self}/*.cls` (new),
  `Test/ParentScope*Registry.cls` (new, 5 classes) — dedicated fixture coverage for
  `ParentScopeResolutionProblem`'s refusal path (added during the Matrix Test Audit) and its
  self-referential case (added during the review pass).
- `src/OcuPilot/Test/Descriptor.cls` — `TestAParentScopeThatDoesNotResolveIsRefusedByTheRoster`
  (new method, additive).
- `src/OcuPilot/Test/TaskHistory.cls` (new) — the live-instance integration suite: every Matrix
  row except Pairs and Corpora, `RouteEntityType` over all three sub-resource screens, the
  Integration AC; review-pass fix: asserts the demo task's id is found before using it.
- `src/OcuPilot/Test/ReadTool.cls`, `Test/Wire.cls`, `Test/WireSecurityRead.cls`, `Test/Smoke.cls`
  — roster/pair-set updates for the two new screens and tools.
- `ui/src/app/areas/tasks/history.store.ts`, `history.page.ts`, `history.page.spec.ts` (new) —
  the Task history page and its framework-free store.
- `ui/src/app/core/navigation.ts` — `routeEntityType`.
- `ui/src/app/core/screens.generated.ts`, `ui/src/app/core/strings.ts`,
  `_bmad-output/planning-artifacts/.../EXPERIENCE.md` — mirror regeneration and the two new Fixed
  strings rows.
- `ui/src/app/shell/screen-outlet.ts` — registers `HistoryPage`.
- `ui/src/styles/_components.scss` — `app-task-history-page` added to the flex-height cascade.
- `ui/tools/screen-mirror.mjs`, `screen-mirror.test.mjs`, `navigation.test.mjs`,
  `navigation-wire.test.mjs`, `rail-wire.spec.ts`, `strings.test.mjs`, `history-store.test.mjs`
  (new) — the JS mirror twin of every server-side grammar change, and roster updates; review-pass
  additions: the `vendorParam`/`source.query` and self-referential-`parentScope` mirror cases.
- `ui/browser/tasks.browser-spec.mjs` — the browser legs of AC1-AC4; review-pass fix: asserts the
  URL after the dialog closes.

**Review findings breakdown** (15 findings from four review layers; see `## Review Triage Log`
above for the full per-finding record):

- **Patched (4 entries, all verdict medium):** (1) `SourceQueryProblem`/`sourceQueryProblem` did
  not guard a fixed `source.query` key against a colliding `vendorParam`; (2)
  `ParentScopeResolutionProblem`/`parentScopeResolutionProblem` could resolve a descriptor's
  `parentScope` against itself; (3) `TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap` could
  silently skip its `TaskRunList` half; (4) AC3's dialog-close browser test never asserted the URL
  returned to the bare route. Each was fixed with the smallest change, pinned by a new test case,
  and Rule-19 mutation-tested (observed red, reverted byte-identical).
- **Rejected (11 findings, 8 entries):** two `false` duplicates on a stale `## Auto Run Result`
  section (expected — this Finalize step is what updates it); two `false` duplicates on the
  `SourceQueryProblem` gap already counted above are not duplicated here (they route to the same
  patched entry, not rejected); one `false` on tool-identifier naming and one on `commandAliases`
  (both exactly match the spec's own table); one `false` on a cold deep-link to `/:id` before
  Search (no demonstrated bad outcome); one `false` on `screen-store.ts` needing no change; one
  `low` on the composite row id's theoretical same-second collision (already accepted as an
  inference in Design Notes); one `low` on `history.store.ts`'s hardcoded `userOnly` literal
  (matches existing project convention); one `low` on the search field's missing client-side
  `maxlength` (matches `AuditPage`'s own precedent).

**Follow-up review recommendation: true.** Four medium-verdict entries were patched in this pass
(the threshold for "true" on a first pass is two or more mediums patched, or any high). Named
unverified risk: `Screen/Registry.cls`, `Screen/Read.cls`, `Port/AdminPort.cls`,
`Install/Smoke.cls`, `ui/tools/screen-mirror.mjs` and `ui/src/app/core/strings.ts` are on the
shared, additive-only file list Epic 4 is also editing concurrently on a different branch; this
pass's two `SourceQueryProblem`/`ParentScopeResolutionProblem` tightenings could in principle
reject a descriptor Epic 4 lands later if that descriptor happens to combine `source.query` with
a colliding `vendorParam`, or declares a self-referential `parentScope` — neither pattern exists
in this repository today, but a follow-up pass (or the merge gate) should re-run
`OcuPilot.Screen.Registry.Validate()` and `npm run build`'s mirror check against the merged tree
before promotion.

**Verification performed:**

- `uv run scripts/check-objectscript.py`: 0 findings (353 files, checked both before and after the
  review-pass patches).
- Full `src/OcuPilot/` compile on `ocupilot-slot-b`, HSCUSTOM: clean.
- `ocupilot-b-ci` throwaway, one class per call: `Descriptor` 35/35, `TaskHistory` 11/11,
  `ReadTool` 26/26, `ScreenReadSource` 10/10, `WireSecurityRead` 11/11, `Wire` 20/20,
  `ScreenRead` 22/22, `Smoke` 30/30, `TaskLists` 7/7, `AdminPortSync` 6/6 (initial pass); after the
  review-pass patches, `Descriptor`, `TaskHistory`, `ReadTool` and `ScreenRead` were re-run green.
- `bash scripts/smoke.sh --container ocupilot-b-ci`: 34/34 (2 pending Epic-3 items, unrelated).
- `cd ui && npm run build && npm test`: clean/green both before and after the review-pass patches
  (node --test 821/821, vitest 424/424 after the patches).
- Browser: `tasks.browser-spec.mjs` green after every rebuild+redeploy, including the four new
  Story 6.6 tests and, after the review pass, the tightened AC3 URL assertion (13/13 on the final
  full run; 102/102 on the full browser suite).
- `bash scripts/lint-docs.sh`: clean.
- 14 Rule-19 mutations observed red and reverted byte-identical across the whole pass (10 from
  implementation, 2 from the Matrix Test Audit gap fix, 4 from the review-pass patches — the
  `## Verification` section above lists each one with the test it reddened).

**Residual risks:**

- The shared-file concurrency risk named above under the follow-up recommendation.
- "Each new refusal arm is disabled in turn" (a `## Verification` mutation line) was exercised for
  one representative HISTORY-source refusal arm, not exhaustively over every arm this story adds,
  given the cost of a throwaway cycle per check — the two-engine corpus tests already pin every
  arm's exact sentence on every run, which is the load-bearing coverage; the mutation line records
  a spot-check on top of that, not the only defense.
- `TaskHistorySearch`'s client state is not wired into `app.ts`'s sign-out teardown list (unlike
  `AuditSearch`), because `app.ts` is on this story's explicit "Do not edit" list — an accepted
  consequence of that boundary, not an oversight.
