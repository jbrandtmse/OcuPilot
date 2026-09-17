---
title: 'Task details'
type: 'feature'
created: '2026-09-17'
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

**Problem:** No screen shows everything about one task, so Task schedule's name cell opens History as a stand-in, and the agent has nowhere to take a user to a stopped task (UJ-6).

**Approach:** One unlisted `detail` descriptor, parent-scoped under Task schedule and keyed by the task's numeric `Id`. It reads `Task.CRUD` `GET` for properties and schedule, and one `INFO` detail call for the last and next run. A Tasks page renders it as fields plus the schedule in words, auto-refreshes through the shared framework, and links to History and to Edit task. Two grammar rules widen so a single-object read can take its id from the route.

## Boundaries & Constraints

**Always:**

- **Descriptor `TaskDetails`:**
  - route `tasks/schedule/details`, area `tasks`, `sideBarPosition` 0, archetype `detail`, `built` true, `parentScope` `tasks/schedule`
  - entity `task`, scope `instance`, id composite `["Id"]` (the route segment is the vendor id), `refreshes` true with rates `[5,10,30,60]` (AD-43 roster)
  - pairs `%Admin_Task:USE` then `%DB_IRISSYS:READ`; tool `tasks.taskdetails`; aliases `["task details"]`; no primary or row action; `emptyAgentKey` `""`
  - `classicPage` `%CSP.UI.Portal.TaskInfo`, exemption false; `secretFields` `[]`; `context.fields` = read fields
  - read: admin `Task.CRUD` `GET`; criterion `taskId` text maxLength 10 with `vendorParam` `id`
  - read fields (GET): `Name, Description, NameSpace, TaskClass, Priority, RunAsUser, TimePeriod, TimePeriodEvery, TimePeriodDay, DailyFrequency, DailyFrequencyTime, DailyIncrement, DailyStartTime, DailyEndTime, StartDate, EndDate`
  - `rowGet`: type `INFO`, `param` `id`, `key` `taskId`, fields `Type, Suspended, Error, LastStarted, LastFinished, NextScheduled`
  - `table` columns (field:kind:labelKey), which are the page's field list in order: Name:name:tableColumnName · Description:text:tableColumnDescription · NameSpace:text:headerNamespaceLabel · Type:text:tableColumnType · Suspended:status:taskColumnSuspended · TaskClass:text:taskDetailsTaskClass · Priority:text:taskDetailsPriority · RunAsUser:text:taskDetailsRunAs · LastStarted:text:taskHistoryColumnStarted · LastFinished:text:taskHistoryColumnCompleted · NextScheduled:text:taskColumnNextRun · Error:text:taskDetailsLastError (no `emptyKey`, so an empty error reads "(none)")
  - `emptyStateKey` `taskDetailsGone`
- **Never `Settings`.** GET's `Settings` object carries arbitrary task-class properties, passwords included, so no field, member projection, context field or test names it (AD-24, AD-35).
- **Grammar, both engines** (`Registry.cls` and `screen-mirror.mjs`, identical sentences, pinned in the corpora):
  - A single-object `GET` source may declare exactly one `read.criteria` field only when `parentScope` is non-empty (the route id). Without a `parentScope` it is still refused.
  - Such a source may declare `rowGet`, whose `key` must equal that criterion's `param`. `Read` issues the detail call with the criterion's seeded value under `rowGet.param`. Other GET sources keep refusing `rowGet`.
  - `refreshes` true with `read.criteria` stays refused, except for a parent-scoped screen whose only criterion is the route id.
  - `Read`: a parent-scoped `GET` source called without its criterion is refused 400 `READ.CRITERION` naming it, before the port.
- **Client pairing (`core/navigation.ts`):**
  - `detailScreenFor(list)`: the built, unlisted, id-keyed screen with a detail-class archetype, no `tab`, and `parentScope` equal to the list's route.
  - The data-table chain becomes classic row link, editor, document, **detail**, child list.
  - `childListFor` skips detail-class screens, so History stays Task schedule's child list, and `parentListFor(TaskDetails)` answers Task schedule.
- **Page** (`areas/tasks/details.page.ts` + `details.store.ts`, registered in `DESCRIPTOR_PAGES`):
  - It binds `RefreshService` with the declared read, filled from the route through `parentCriteria`.
  - It renders each table column as a label and value through `cellView`, and a name never renders as a link.
  - It shows a Schedule group with two lines, **How often** and **Time of day**, and links to History (`tasks/schedule/history/<Id>`, label `taskRunsLabel`).
  - Edit task renders only when `editorScreenFor(Task schedule)` resolves. Until Epic 9 it is absent, never disabled.
  - States: skeleton fields on first load only. A fault keeps the last values. A silent tick highlights each field whose value changed. Zero rows show `taskDetailsGone`.
- **Schedule in words:** a pure function in the store over GET's display values, whose vocabulary is AD-3's. TimePeriod: Daily, Weekly, Monthly, Monthly Special, Run After, On Demand. DailyFrequency: Once, Several. DailyFrequencyTime: Minutes, Hourly. Weekly `TimePeriodDay` digits 1–7 are Sunday–Saturday; Monthly Special is `<week>^<weekday>`. An unrecognized value renders the vendor's text as it stands. `Suspended` true makes Next run read `taskDetailsNextSuspended`.
- **Locator bar:** on a parent-scoped `detail` screen, once its row is loaded, the entity segment reads the value of its first `name` column, and until then the decoded id.
- **Shared files are additive** (see Code Map). New EXPERIENCE.md Fixed strings rows are appended after the table's last row. Non-ASCII in code is written `\uXXXX`. No new context field above 1,000 characters.

**Never:**

- No agent navigate tool, no UJ-6 replay (Story 7.6), no proposal events (Epic 5; the refresh pause already listens on `change-bus.ts`). No writes, no new port, no second `classicLinkExemption`.
- No edits to `Kernel/**`, `Port/ProviderPort.cls`, `Screen/Tool/**`, `scripts/check-objectscript.py` or its test, `app.ts`, `app.spec.ts`, `ui/package*.json`, `angular.json`, `README.md`, or `shell/panel/**`.
- No Edit control before its editor exists. No task created, run, resumed or suspended by any test.

## I/O & Edge-Case Matrix

The throwaway has the demo fixture. `OcuPilotDemo nightly purge` is Daily, every 1, Once at 03:00, and suspended after its failed install run. Reads are `GET /api/ocupilot/screens/tasks.taskdetails/read`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Demo task | `taskId=<demo Id>` | 200, one row. `Name` is the demo task, `TimePeriod` "Daily", `DailyFrequency` "Once", `DailyStartTime` "03:00:00", `Suspended` true, `Error` non-empty. Every declared field is a key. | No error expected |
| Deleted or unknown | `taskId=999999` | 200 with no rows, so the page shows "This task no longer exists." | Not a refusal (AD-37) |
| No id | no `taskId` | 400 `READ.CRITERION` naming `taskId`; port not called | Never 500 |
| Bad id | 11 characters | 400 `READ.CRITERION` | — |
| Pairs | `%Admin_Task:USE` alone, then both | 403 `AUTH.NOPRIVILEGE` naming `%DB_IRISSYS:READ`; with both, 200 | Never 500 |
| Words | the 6 periods × Once/Several (minutes and hours), weekly days, monthly special, singular and plural | the strings listed under Tasks, exactly | unknown value → vendor text |
| Grammar | GET + criterion without parentScope; rowGet key ≠ criterion; GET rowGet without criterion; refreshes + criteria without parentScope | each refused with its sentence in both engines; the TaskDetails shape validates | — |

</intent-contract>

## Code Map

- **Vendor** (`Task.CRUD`, hidden; probed on slot B, read-only):
  - GET and INFO take query `id`. An unknown id answers 404, which a GET source reads as zero rows (`Read.cls:238-259`).
  - GET keys come from `TaskToJson`. `TimePeriod`, `DailyFrequency`, `DailyFrequencyTime` and `Priority` arrive as display text; times as `HH:MM:SS`, dates as `YYYY-MM-DD`. It has no run times.
  - INFO (`RunInfo`) answers `Type, Status, Error, LastSchedule, LastStarted, LastFinished, NextScheduled, Suspended`. `Error` is raw `<THROW>` text (untrusted, AD-11).
  - `ResourcesOR` is `%Admin_Task` or `%Admin_Operate`. `AdminPort.TYPESUFFIXES` (`:101`) already has `INFO`.
- **Classic wording to mirror in meaning:** `%SYS.Task` `DisplayRunCalc` / `DisplayIntervalCalc` (compiled, no source). Probed outputs: "Weekly, every 2 weeks on Sunday Tuesday Thursday" for day `135`; "Monthly, every 2 months on Tuesday in the second week" for `2^3`; "Every 15 minute(s) between 01:00:00 and 20:00:00". `irissys/%CSP/UI/Portal/TaskInfo.cls` (`RESOURCE %Admin_Operate`, detail pane `:296-372`).
- **Grammar:** `Screen/Registry.cls`: GET rules `:834-852`, `SourceQueryProblem` `:1340`, `CriteriaProblem` `:1071-1113` (refreshes refusal `:1108`), `ParentCriteriaProblem` `:1119`, `RefreshProblem` `:346`, `TableProblem` `:1577`, `ROWGETTYPES` `:1463`, `TABLECOLUMNKINDS` `:1559`, `RouteEntityType` `:2055`. Mirror: `criteriaProblem` `:799-841`. Corpora: `Test/ReadSourceCorpus.cls`, `Test/CriteriaCorpus.cls`, `Test/RowGetCorpus.cls`.
- **Read:** `Screen/Read.cls` GET branch `:238-259`, `DetailRow` `:608-661` (`tQuery(param) = row.(key)`), `SeedCriteria` `:507-557`.
- **Precedents:** `Descriptor/TaskRunList.cls` (parentScope, criterion `:55,70-73`), `TaskScheduleList.cls` (refresh, pairs), `OAuthServerTab.cls` (detail + GET).
- **Client:**
  - `shell/screen-outlet.ts:52-81` (page maps). `shell/data-table.ts:429-442` (name-cell chain).
  - `core/navigation.ts`: `EDITOR_ROUTE_SUFFIX` `:166`, `editorScreenFor` `:176`, `childListFor` `:216`, `parentListFor` `:226`, `parentCriteria` `:268`, `routeEntityType` `:300`.
  - `core/refresh.ts`: `bind` `:227`, tick `:533`, bus pause `:608`.
  - `core/table-model.ts:71` `cellView`. `shell/locator-bar.ts:158-164,223-239`.
  - `core/screen-store.ts:207` `markChanged`.
  - Page precedents: `areas/web-applications/openapi-viewer.page.ts` (route id `:199,227`, skeleton `:191`) and `areas/tasks/history.page.ts` (refresh binding `:178-190`, field pairs `:128-137`).
- **Rosters to extend:**
  - `Test/ReadTool.cls:94,100,263`, `Test/Wire.cls:626`, `Test/WireSecurityRead.cls:346,350`
  - `Install/Smoke.cls:58,118-126`, `Test/Smoke.cls:439`, `Test/ScreenRead.cls`, `Test/Descriptor.cls:52`
  - `navigation.test.mjs:124-140,301`, `screen-mirror.test.mjs:602,740-748`
  - `navigation-wire.test.mjs:38,102-109,328` and `shell/rail-wire.spec.ts:37,101-108,358` (both `LIVE_PAYLOAD`s)
  - `classic-links.test.mjs:451-458` (unchanged count)
  - `strings.test.mjs:324-327` (band ≤ 350; last row comment `strings.ts:725`, `EXPERIENCE.md:360`)
- **UX:** EXPERIENCE.md `:103` (IA row), `:109` (Edit task), `:619` (refresh roster), `:360` (last Fixed strings row).
- **Browser:** `ui/browser/tasks.browser-spec.mjs`: `DEMO_TASK` `:45`, `TASK_USER` `:53-55`, and "Story 6.6 AC2/AC3" `:422-466`, which currently expects the name cell to open History.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/ReadSourceCorpus.cls`, `Test/CriteriaCorpus.cls`, `Test/RowGetCorpus.cls` -- the three grammar widenings in Boundaries. Give each refusal a case, add a sound TaskDetails-shaped case, and use identical sentences in both engines -- so a single-object read can take its id from the route and still refuse every other shape.
- [ ] `src/OcuPilot/Screen/Read.cls` -- seed the criterion on a GET source, refuse a missing parent-scoped criterion, and issue `rowGet` from the criterion value. Update the class doc in contract voice.
- [ ] `src/OcuPilot/Screen/Descriptor/TaskDetails.cls` (new) -- the declaration in Boundaries. The class doc states the vendor semantics, the `Settings` exclusion and the route entity type.
- [ ] `ui/src/app/core/navigation.ts`, `ui/src/app/shell/data-table.ts`, `ui/src/app/shell/locator-bar.ts` -- `detailScreenFor`, the chain order, the `childListFor` exclusion, the `parentListFor` resolution, and the locator's name label.
- [ ] `ui/src/app/areas/tasks/details.store.ts`, `details.page.ts`, `details.page.spec.ts` (new), `ui/src/app/shell/screen-outlet.ts` -- the page and its store, with the schedule words pinned by `ui/tools/details-store.test.mjs` over the Words matrix row.
- [ ] EXPERIENCE.md, `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` -- append one row after the last. Reuse existing keys where the value already exists (values are unique), and regenerate `screens.generated.ts`. Row values:
  - "Task details" · "This task no longer exists." · "Task class" · "Priority" · "Run as" · "Last error" · "Schedule" · "How often" · "Time of day" · "Not scheduled while suspended" · "Edit task"
  - "Every day" · "Every {n} days" · "Every week on {days}" · "Every {n} weeks on {days}" · "Every month on day {d}" · "Every {n} months on day {d}" · "Every month on the {ordinal} {weekday}" · "Every {n} months on the {ordinal} {weekday}" · "After another task completes" · "On demand only"
  - "Once at {time}" · "Every minute between {start} and {end}" · "Every {n} minutes between {start} and {end}" · "Every hour between {start} and {end}" · "Every {n} hours between {start} and {end}"
  - weekday names Sunday–Saturday and ordinals first–fifth
- [ ] `src/OcuPilot/Test/TaskDetails.cls` (new; API over HTTP, `_SYSTEM`, demo fixture) -- validation, with `AreaCoverageProblem` empty and TaskInfo compiling; Matrix rows Demo task, Deleted, No id, Bad id; `RouteEntityType` answers `task`; and the Integration AC. It finds the demo Id from `tasks.schedule` and asserts it is non-empty.
- [ ] `src/OcuPilot/Test/WireSecurityRead.cls` -- the Pairs row on the new route with the existing task principals.
- [ ] Code Map rosters -- add the screen and its tool. Smoke gains a `tasks.taskdetails` read keyed by the first `tasks.schedule` row's `Id`, which passes on exactly one row. `navigation.test.mjs` pins `detailScreenFor(schedule)` = TaskDetails, `childListFor(schedule)` = TaskRunList, and the chain order.
- [ ] `ui/browser/tasks.browser-spec.mjs` -- rework "6.6 AC2/AC3" to go name cell → details → History link, and add the AC legs below.

**Acceptance Criteria:**

- Given Task schedule on the throwaway, when the demo task's name cell is activated, then the URL is `/ocupilot/tasks/schedule/details/<Id>`, one `tasks.taskdetails` read is issued, and the page shows the Name, Namespace, Suspended "Yes", Last error text, Started, Completed, Next run "Not scheduled while suspended", How often "Every day" and Time of day "Once at 03:00:00".
- Given a cold deep link to that URL (the route the agent's navigation will produce, Story 4.7), when it loads, then the same task is shown and the locator bar names it "OcuPilotDemo nightly purge" rather than its id, with its screen segment linking back to Task schedule.
- Given the refresh chip set to 5 s, when a tick fires, then the task is re-read with no skeleton and no announcement, and a field whose value changed carries the highlight class.
- Given the page, when it renders, then the History link opens `/ocupilot/tasks/schedule/history/<Id>` with that task's runs, and no Edit task control exists; given a roster with a built `tasks/schedule/edit`, then `details.page.spec.ts` shows the Edit task link to `…/edit/<Id>`.
- Given a principal lacking `%DB_IRISSYS:READ`, when it opens the deep link, then the denied view names that pair and no read is issued.
- Integration: given the tool `tasks.taskdetails.read` with the demo Id, when called in process, then it answers the same row the screen's read answers, with no `Settings` key.

## Spec Change Log

- 2026-09-17 (spec gate, lead): AD-36 amended with the route-id criterion on a single-object `GET`, its keyed detail call and refresh; the other gate decisions (own details page, name cell re-pointed through `detailScreenFor`, Edit task control only once `tasks/schedule/edit` is built, locator names the task by name, schedule words built in the client, no `Settings` field) accepted as planned.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-26 and AD-27 (a synchronous `Task.CRUD` call through `AdminPort` only), AD-3 (schedule vocabulary), AD-5, AD-8 and AD-29 (pairs established with a real principal), AD-11 (`Error` is untrusted), AD-13 and AD-14, AD-19 (store), AD-24 and AD-35 (no `Settings`), AD-36, AD-37 (a gone task is "no longer exists", not a refusal), AD-43, and AD-44 (TaskInfo, no link-out).

**Pre-answered by the orchestrator (2026-09-16):**

- The "agent navigates here" criterion is verified through the route itself: a deep link carrying the task's scoped identity, as the agent's navigation tool will produce it (it takes allow-listed route identifiers, Story 4.7). The agent-driven UJ-6 replay is Story 7.6.
- "The row is selected" on a detail screen means the entity the route identifies is the one shown, and the locator bar names it by its name, not only its id.

**Decisions for the gate:**

- **Own page, not `DetailPage`.** `DetailPage` is a tab strip over `ListPage`'s table, and one entity is a field list, so the page follows the openapi-viewer and History precedents.
- **`table` doubles as the field list.** `TableProblem` requires a table on any read, and the columns already carry label keys and kinds that `cellView` renders. This avoids a second list grammar.
- **AD-36 wording (Rule 20).** Recommend adding: "a single-object `GET` under a `parentScope` takes its id from the route as its one criterion, and may name one detail call keyed by that criterion (Story 6.7)". AD-43's Rule is unchanged: the refusal on refreshes with criteria keeps its purpose, a server-criteria form, and a route-id criterion reads on open.
- **GET plus INFO.** GET alone has no run times, and INFO alone has no properties or schedule. Both are needed, and the list's `Suspended` is wrong (AD-36).
- **Schedule words are composed on the client** from GET's display values, not taken from the vendor's `DisplayRunCalc`. Calling a `%SYS` class from `Read` would bypass the ports, and the words then live in the string table. The tool carries the raw vocabulary, and its field descriptions are DW-1001 (Story 7.1).
- **Edit task is absent until its editor exists,** found by the existing `<list>/edit` pairing, so Epic 9 adds it with no change here. This avoids a dead control.
- **`RunAfterGUID` is not resolved to a task name.** That would need a second read, so the sentence reads "After another task completes".
- **Next run when suspended.** INFO answers a stale past time, so the page says "Not scheduled while suspended" (inference that the vendor's time is meaningless then).

**Ledger inbox:** `slice 6-7-task-details` is empty. DW-1001 and DW-1018 are not re-litigated. The DW-1021 analog does not arise, because a gone task reads as zero rows.

**Integration ACs:** the Integration AC, plus AC1 and AC2 through the page. `detailScreenFor` and the widened grammar have no other consumers in this story; the next are Epic 9's Edit task (`editorScreenFor` from this page) and any later parent-scoped detail, Story 6.8 among the candidates.

**Consumes:** `AdminPort` (2.1), `Screen.Read` and criteria (2.3, 2.10), the refresh framework (1.14), `cellView` and `ListPage` (2.4), `parentScope`, `childListFor` and `vendorParam` (6.3, 6.6), the `GET` source (6.4), and the gate (1.9).

**Consumed-by:** 7.6 (the UJ-6 replay on this route), Epic 9 (Edit task through `editorScreenFor`), 5.7 (the proposal pause on `task`), and 4.4 (screen context via `RouteEntityType`).

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: a clean compile. Slot B is compiled into and read only.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy with the demo fixture. Every principal and state-creating step lives on this slot B throwaway only. Teardown: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`, `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for TaskDetails, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor, Smoke, TaskHistory and TaskLists -- expected: all green, with totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: the new details check passes, with no failures.
- `cd ui && npm run build && npm test` -- expected: green, and `screen-mirror --check` clean.
- From `ui/`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `tasks.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations to record (Rule 19)**, each as `mutation: <change> -> <test red> (observed)`, with the tree confirmed byte-identical afterwards:

- AC1: `detailScreenFor` moved after `childListFor` in the chain (bundle rebuilt and redeployed).
- AC2: the locator label falls back to the id.
- AC3: the refresh binding omitted.
- AC4: the Edit link rendered unconditionally.
- AC5: `%DB_IRISSYS:READ` dropped from TaskDetails.
- Integration: `rowGet` sent with `row.(key)` instead of the criterion.
- Words: Weekly day digits read from 0.
- Each new grammar arm disabled in turn, in both engines.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
