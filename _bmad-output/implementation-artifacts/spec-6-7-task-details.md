---
title: 'Task details'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_revision: '56d71a4f4d05add8470cc78231330ebed42bf663'
baseline_commit: '56d71a4f4d05add8470cc78231330ebed42bf663'
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

- [x] `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/ReadSourceCorpus.cls`, `Test/CriteriaCorpus.cls`, `Test/RowGetCorpus.cls` -- the three grammar widenings in Boundaries. Give each refusal a case, add a sound TaskDetails-shaped case, and use identical sentences in both engines -- so a single-object read can take its id from the route and still refuse every other shape. (`RowGetCorpus.cls` left unchanged: the widened key-allowed shape is a GET-source interplay, and `ReadSourceCorpus` already carries it, sound and refusing, through the same `ReadProblem`/`readProblem` both engines run.)
- [x] `src/OcuPilot/Screen/Read.cls` -- seed the criterion on a GET source, refuse a missing parent-scoped criterion, and issue `rowGet` from the criterion value. Update the class doc in contract voice.
- [x] `src/OcuPilot/Screen/Descriptor/TaskDetails.cls` (new) -- the declaration in Boundaries. The class doc states the vendor semantics, the `Settings` exclusion and the route entity type.
- [x] `ui/src/app/core/navigation.ts`, `ui/src/app/shell/data-table.ts`, `ui/src/app/shell/locator-bar.ts` -- `detailScreenFor`, the chain order, the `childListFor` exclusion, the `parentListFor` resolution, and the locator's name label.
- [x] `ui/src/app/areas/tasks/details.store.ts`, `details.page.ts`, `details.page.spec.ts` (new), `ui/src/app/shell/screen-outlet.ts` -- the page and its store, with the schedule words pinned by `ui/tools/details-store.test.mjs` over the Words matrix row.
- [x] EXPERIENCE.md, `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` -- append one row after the last. Reuse existing keys where the value already exists (values are unique), and regenerate `screens.generated.ts`. Row values:
  - "Task details" · "This task no longer exists." · "Task class" · "Priority" · "Run as" · "Last error" · "Schedule" · "How often" · "Time of day" · "Not scheduled while suspended" · "Edit task"
  - "Every day" · "Every {n} days" · "Every week on {days}" · "Every {n} weeks on {days}" · "Every month on day {d}" · "Every {n} months on day {d}" · "Every month on the {ordinal} {weekday}" · "Every {n} months on the {ordinal} {weekday}" · "After another task completes" · "On demand only"
  - "Once at {time}" · "Every minute between {start} and {end}" · "Every {n} minutes between {start} and {end}" · "Every hour between {start} and {end}" · "Every {n} hours between {start} and {end}"
  - weekday names Sunday–Saturday and ordinals first–fifth
- [x] `src/OcuPilot/Test/TaskDetails.cls` (new; API over HTTP, `_SYSTEM`, demo fixture) -- validation, with `AreaCoverageProblem` empty and TaskInfo compiling; Matrix rows Demo task, Deleted, No id, Bad id; `RouteEntityType` answers `task`; and the Integration AC. It finds the demo Id from `tasks.schedule` and asserts it is non-empty.
- [x] `src/OcuPilot/Test/WireSecurityRead.cls` -- the Pairs row on the new route with the existing task principals.
- [x] Code Map rosters -- add the screen and its tool. Smoke gains a `tasks.taskdetails` read keyed by the first `tasks.schedule` row's `Id`, which passes on exactly one row. `navigation.test.mjs` pins `detailScreenFor(schedule)` = TaskDetails, `childListFor(schedule)` = TaskRunList, and the chain order.
- [x] `ui/browser/tasks.browser-spec.mjs` -- rework "6.6 AC2/AC3" to go name cell → details → History link, and add the AC legs below.

**Acceptance Criteria:**

- Given Task schedule on the throwaway, when the demo task's name cell is activated, then the URL is `/ocupilot/tasks/schedule/details/<Id>`, one `tasks.taskdetails` read is issued, and the page shows the Name, Namespace, Suspended "Yes", Last error text, Started, Completed, Next run "Not scheduled while suspended", How often "Every day" and Time of day "Once at 03:00:00".
- Given a cold deep link to that URL (the route the agent's navigation will produce, Story 4.7), when it loads, then the same task is shown and the locator bar names it "OcuPilotDemo nightly purge" rather than its id, with its screen segment linking back to Task schedule.
- Given the refresh chip set to 5 s, when a tick fires, then the task is re-read with no skeleton and no announcement, and a field whose value changed carries the highlight class.
- Given the page, when it renders, then the History link opens `/ocupilot/tasks/schedule/history/<Id>` with that task's runs, and no Edit task control exists; given a roster with a built `tasks/schedule/edit`, then `details.page.spec.ts` shows the Edit task link to `…/edit/<Id>`.
- Given a principal lacking `%DB_IRISSYS:READ`, when it opens the deep link, then the denied view names that pair and no read is issued.
- Integration: given the tool `tasks.taskdetails.read` with the demo Id, when called in process, then it answers the same row the screen's read answers, with no `Settings` key.

### Review Findings

Code review 2026-09-17 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 0 decision-needed, 18 patch (all applied), 2 defer, 13 rejected.

- [x] [Review][Patch] A read fault never re-rendered the page, so the refusal and Retry did not show (med) [ui/src/app/areas/tasks/details.page.ts:190]
- [x] [Review][Patch] A changed-field highlight cleared on the next store notification or unchanged tick, against EXPERIENCE.md "Highlight." (med) [ui/src/app/areas/tasks/details.store.ts:195]
- [x] [Review][Patch] AC3 had no timer-tick test on Task details (med) [ui/src/app/areas/tasks/details.page.spec.ts:197]
- [x] [Review][Patch] AC2's cold deep link was untested, and the locator spec re-navigated after the store tick (med) [ui/browser/tasks.browser-spec.mjs:582]
- [x] [Review][Patch] AC1's Namespace and Last error asserts could not fail; Started and Completed were unasserted (med) [ui/browser/tasks.browser-spec.mjs:516]
- [x] [Review][Patch] The smoke `taskdetails` check passed on any one-row read, including the wrong tool's (med) [src/OcuPilot/Install/Smoke.cls:672]
- [x] [Review][Patch] The changed tint had no rule for a details field (low) [ui/src/styles/_components.scss:3479]
- [x] [Review][Patch] The per-store highlight `WeakMap` was always reset, so its doc was false (low) [ui/src/app/areas/tasks/details.page.ts:39]
- [x] [Review][Patch] Two template conditions were not member references (low) [ui/src/app/areas/tasks/details.page.ts:126]
- [x] [Review][Patch] No corpus case kept the rowGet-key widening to GET sources (low) [src/OcuPilot/Test/ReadSourceCorpus.cls:53]
- [x] [Review][Patch] A top-level `Settings` assertion could not fail (low) [src/OcuPilot/Test/TaskDetails.cls:241]
- [x] [Review][Patch] Descriptor doc: an ungrammatical sentence and a false empty-state claim (low) [src/OcuPilot/Screen/Descriptor/TaskDetails.cls:24]
- [x] [Review][Patch] Locator spec provider comment was false (low) [ui/src/app/shell/locator-bar.spec.ts:124]
- [x] [Review][Patch] Navigation test title still said the name cell opens History (low) [ui/tools/navigation.test.mjs:300]
- [x] [Review][Patch] `describeBanner`'s JSDoc sat above the wrong function (low) [ui/browser/tasks.browser-spec.mjs:241]
- [x] [Review][Patch] Browser test titles misnumbered the ACs they cover (low) [ui/browser/tasks.browser-spec.mjs:461]
- [x] [Review][Patch] `details-store.test.mjs` header named a mutation that reddens differently (low) [ui/tools/details-store.test.mjs:20]
- [x] [Review][Patch] Rule 19 mutation lines missing for AC1, AC3, AC4, AC5, Integration, Words and the grammar arms (low, closed in-pass under Verification)
- [x] [Review][Defer] The derived tool describes the required `taskId` as an optional comma list [src/OcuPilot/Screen/Tool/Read.cls] — deferred: DW-1001 occurrence (contended `Screen/Tool/**`, routed 7-1)
- [x] [Review][Defer] The integration test compares two live reads of the demo task [src/OcuPilot/Test/TaskDetails.cls:220] — deferred: DW-1026 occurrence (runs after the Suspended poll)

Rejected:

- low: `StartDate`/`EndDate` not rendered -- the spec's column list is the field list (spec-bound).
- false: skeleton forever when the screen has no read -- the page is registered only for TaskDetails, which declares both.
- low: `Read.cls` seeds the rowGet key outside the criterion guard -- the grammar refuses a GET rowGet without a criterion.
- low: 22 filter and sort fields on a one-row read -- tool schema is contended `Screen/Tool/**`; no user harm shown.
- low: tests read `tAnswer.code` without `$IsObject` -- a non-JSON body still reds the test.
- low: no tool-path test of the missing criterion -- tool and route share `Read.Execute`, whose refusal is tested.
- low: schedule lines take no highlight -- a schedule changes only through Epic 9's editor.
- low (maybe-false): Monthly day 31 as "last day" -- vendor semantics unconfirmed; the vendor's text renders as it stands.
- low: empty Monthly `TimePeriodDay` -- the vendor requires a day.
- false: the detail call is keyed from the row -- `Read` seeds the criterion value under the key, so the call sends that value.
- low: `detailScreenFor` tests the literal `detail` -- a form-page child is `editorScreenFor`'s.
- rejected: spec counts and Auto Run Result length -- the fix edits the spec under review.
- false: chain order unpinned -- the browser leg reddens on the swap (Verification).

## Spec Change Log

- 2026-09-17 (spec gate, lead): AD-36 amended with the route-id criterion on a single-object `GET`, its keyed detail call and refresh; the other gate decisions (own details page, name cell re-pointed through `detailScreenFor`, Edit task control only once `tasks/schedule/edit` is built, locator names the task by name, schedule words built in the client, no `Settings` field) accepted as planned.

## Review Triage Log

### 2026-09-17 — Review pass

- verdicts: 17 findings — high 1, medium 0, low 9, false 7, maybe-false 0
- findings:
  - `[high]` `[patch]` The new `.ocu-details-*` template classes (`details.page.ts`) carried zero CSS anywhere, unlike every precedent page's own custom classes (`.ocu-openapi-*`, `.ocu-field*`), so the page would render fully unstyled — added a `.ocu-details-*` block to `_components.scss` (page/fields/schedule/links layout, `typo.ocu-type` mixin) mirroring the `.ocu-openapi-*` precedent; `npm run build` and a fresh browser run stayed green.
  - `[low]` `[patch]` `WireSecurityRead.DemoTaskId()` hardcoded the magic length `12` instead of a named constant, unlike `Test.TaskDetails.DemoTaskId()`'s `DEMONAME`-derived check in this same diff — replaced with `$Length(..#DEMOCOLLECTION)`/`..#DEMOCOLLECTION`, the class's own existing "OcuPilotDemo" constant; `WireSecurityRead` re-ran green (12/12).
  - `[low]` `[patch]` `nextRunText()` bypasses `cellView`'s shared empty-value fallback for the one column it renders directly, so a not-suspended Run-After/On-Demand task's blank `NextScheduled` would show literally empty rather than "(none)" like every other field on the page — added the same empty -> `tableEmptyValue` fallback; a new `details-store.test.mjs` case pins it, all green.
  - `[low]` `[reject]` `oftenText`'s Weekly branch has no guard for an empty `TimePeriodDay`, producing "Every week on " with nothing after "on" — rejected: the vendor does not allow a Weekly task with no day selected, so this is unreachable in practice, and a real fix would need a new fallback decision (added complexity), not a direct correction.
  - `[low]` `[patch]` EXPERIENCE.md's new Task details row credited the schedule vocabulary to only `TimePeriod`, `DailyFrequency` and `DailyFrequencyTime`, omitting `TimePeriodEvery`, `TimePeriodDay`, `DailyIncrement`, `DailyStartTime` and `DailyEndTime`, which `scheduleWords()` also reads — corrected the sentence to list all eight fields; `lint-docs.sh` stayed clean.
  - `[low]` `[reject]` `Install.Smoke.CheckTaskDetails` issues two separate reads (schedule, then detail) with no protection against the row changing between them — rejected: nothing else mutates tasks during a smoke run, so this is unreachable in everyday use, and a real fix (combining or retrying the reads) adds complexity beyond a direct correction.
  - `[false]` `[reject]` The auto-refresh widening in `CriteriaProblem`/`criteriaProblem` generalizes to any parent-scoped single-criterion read, not only the new GET case, with no LIST-sourced test of the combination — refuted: AD-5 already defines a parent-scoped read's one criterion as route-filled rather than a user search, and the Design Notes explicitly generalize the rule ("a route-id criterion reads on open"); the general form is the documented, intended scope.
  - `[false]` `[reject]` No test proves a non-numeric `taskId` within the 10-character bound (e.g. "abc") avoids a vendor 500 the way an over-long id might — refuted by a live read against `ocupilot-slot-b`: `GET tasks.taskdetails/read?taskId=abc` answers HTTP 200 with zero rows, the same fallback as the tested "Deleted or unknown" case.
  - `[low]` `[reject]` `Read.cls`'s route-id seeding only handles a single-part composite id (`$ListLength(tIdParts) = 1`); a future multi-part-composite descriptor pairing this grammar would silently seed nothing — rejected: no such descriptor exists or is planned by this story; deciding how one criterion value maps onto multiple id parts is a real design question, not a direct correction, and the situation is not currently reachable.
  - `[false]` `[reject]` `WireSecurityRead.DemoTaskId()` calls `%FromJSON` and reads `.rows` with no Try/Catch or `$IsObject` guard, unlike `Test.TaskDetails.DemoTaskId()`'s guarded form — refuted: every other method in `WireSecurityRead.cls` (12 call sites) uses the identical unguarded `%FromJSON(tBody)` pattern already, trusting the established 200-is-well-formed-JSON contract; this is the file's own pre-existing convention, not a new risk.
  - `[low]` `[reject]` Same root cause as the `Read.cls` composite-id finding above (`RowGetProblem`/seeding interplay) — grouped; rejected for the same reason.
  - `[low]` `[patch]` `navigation.test.mjs`'s Story 6.6 test still carried a comment and assertion message claiming Task schedule's "name cell opens History", which this story changed to open Task details — corrected the comment and message to describe `childListFor` as resolving the child list rather than the name cell's target; `navigation.test.mjs` re-ran green (836 tool tests).
  - `[low]` `[patch]` `Test.ReadTool`'s doc comment named its mutation target as `"a GET with a detail call"`, the corpus case's pre-rename name — corrected the quoted name to `"a GET with a detail call and no criteria"`; `ReadTool` re-ran green on a throwaway (26/26).
  - `[false]` `[reject]` The intent's Execution checklist names `Test/RowGetCorpus.cls` for the widened-shape coverage, but the diff carries it in `Test/ReadSourceCorpus.cls` instead, said to be explained only in the Auto Run Result narrative — refuted: the substitution is recorded exactly where the original instruction was given, inline in the Tasks & Acceptance checklist item itself.
  - `[false]` `[reject]` The "Words" matrix row is framed alongside wire-read scenarios, but its full vocabulary coverage lives in a client-side unit test rather than an HTTP-level one — refuted: the intent's own "Never" list forbids any test creating, running, resuming or suspending a task, which a wire-level test of all twelve TimePeriod/DailyFrequency combinations would require; the client-side pure-function test is the only intent-compliant way to cover the full cross-product.
  - `[false]` `[reject]` The refresh-widening's broad scope (any parent-scoped single-criterion read) and the locator bar's narrow scope (`archetype === 'detail'` only) generalize the "route id fills the one criterion" idea at different rates — refuted: the intent's own Boundaries text scopes the locator behavior explicitly to "a parent-scoped detail screen", so the narrower scope there is what was asked for.
  - `[false]` `[reject]` The intent and its matrix never mention the gap between the demo fixture's `RunNow` request and the Task Manager's next pass, so the matrix's flat "Suspended true" claim needed softening into a poll — already resolved within this same review pass: `Test.TaskDetails.TestTheDemoTaskReadsOverTheWire` and the browser spec's `waitForDemoTaskSuspended` both poll for `Suspended` before asserting, reproduced live on a throwaway seconds old (red without the poll, green with it).

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

**Observed (QA, 2026-09-17):**

- mutation: `details.page.ts`'s `showSkeleton` getter changed from `!this.loaded && !this.showRefusal` to `!this.showRefusal` (skeleton no longer gated on first-load-only) -> `details.page.spec.ts`'s `a silent tick highlights only the field whose value changed` went red (skeleton reappeared on the silent tick), along with two other tests asserting no skeleton; reverted, tree byte-identical, `ng test --include='src/app/areas/tasks/details.page.spec.ts'` back to 9/9 green.
- mutation: `locator-bar.ts`'s `entityLabel` changed from `return text === '' ? entity : text;` to `return entity;` (entity segment never reads the loaded row's name column) -> `locator-bar.spec.ts`'s `Story 6.7: on a parent-scoped detail screen the entity segment names the loaded row, and the decoded id until then` went red (`'42'` instead of `'The forty-second row'`); reverted, tree byte-identical, `ng test --include='src/app/shell/locator-bar.spec.ts'` back to 16/16 green.

**Observed (code review, 2026-09-17):** each reverted, tree byte-identical; ObjectScript mutations loaded into `ocupilot-b-ci` from `/tmp` and restored from source; the client mutation in `data-table.ts` rebuilt and redeployed before the browser run.

- mutation: `data-table.ts` chain puts `childListFor` before `detailScreenFor` -> `tasks.browser-spec.mjs` "Story 6.7 AC1/AC2/AC4" and "Story 6.7 AC2" red (observed).
- mutation: `locator-bar.ts` store subscription made a no-op -> `locator-bar.spec.ts` "Story 6.7: ... names the loaded row" red (observed).
- mutation: `details.page.ts` refresh binding omitted -> 10 of 11 `details.page.spec.ts` tests red, AC3's tick test among them (observed).
- mutation: `TaskDetailsHighlights.update` replaces the set on an unchanged tick -> `details.page.spec.ts` AC3 and `details-store.test.mjs` highlight test red (observed).
- mutation: `details.page.ts` refresh subscription dropped -> "a fault on a re-read shows the refusal" red (observed).
- mutation: Edit link `@if (true)` -> "no Edit task control exists yet" red (observed).
- mutation: `%DB_IRISSYS:READ` dropped from TaskDetails -> `WireSecurityRead.TestTaskDetailsPairSetIsEnforcedForARealPrincipal` red (observed).
- mutation: `Read.cls` rowGet-key seeding disabled -> `TaskDetails.TestTheReadToolAnswersTheSameRowAsTheRoute` and `TestTheDemoTaskReadsOverTheWire` red (observed).
- mutation: `weekdayName` reads digits from 0 -> `details-store.test.mjs` Weekly and Monthly Special red (observed).
- mutation: `Smoke.TASKDETAILSTOOL` = `tasks.taskhistory` -> `Test.Smoke.TestTheTaskDetailsIsALiveCheck` red (observed).
- mutation, each grammar arm in both engines (`Registry.cls` / `screen-mirror.mjs`): GET criteria without parentScope, GET rowGet without criteria, route-id rowGet key, parent-scoped refresh, GET-only key widening -> `ReadTool` and `screen-mirror.test.mjs` corpus tests red on the named case (observed, 5 of 5 per engine).

**Review re-verification:** `check-objectscript.py` 0; `npm run build` and `npm test` green (836 tool tests, 38 component files); on a fresh `ocupilot-b-ci`: ReadTool 26, TaskDetails 6, WireSecurityRead 12, Smoke 31, all green; `smoke.sh` 35/35; `tasks.browser-spec.mjs` 14/14.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Implemented Task details end to end: the `TaskDetails` descriptor (parent-scoped under
Task schedule, keyed by the vendor's numeric `Id`), the two widened GET-source grammar rules plus
the refresh-with-route-id-criterion widening (`Registry.cls` / `screen-mirror.mjs`), the criterion
seeding and required-criterion refusal in `Read.cls`, the client pairing
(`detailScreenFor`/`childListFor`/`parentListFor`, the data-table link chain, the locator bar's
name-column entity label), the page and its schedule-in-words store, the new strings and
EXPERIENCE.md row, and the full test surface (ObjectScript corpora and wire tests, Node unit tests,
an Angular component spec, and a reworked browser spec). Two real bugs surfaced during
verification and were fixed in this same pass (see below); a review pass then found and patched
one high-severity gap (no CSS for the new page) and eight low-severity nits, and rejected or
refuted the remaining findings.

**Files changed:**

- `src/OcuPilot/Screen/Descriptor/TaskDetails.cls` (new) -- the descriptor declaration.
- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs` -- the three grammar widenings, identical sentences in both engines.
- `src/OcuPilot/Screen/Read.cls` -- route-id criterion seeding, the required-criterion refusal, and the keyed `rowGet` detail call.
- `src/OcuPilot/Test/TaskDetails.cls` (new) -- the I/O matrix, declaration and Integration AC tests, with a poll for the demo task's `Suspended` state.
- `src/OcuPilot/Test/ReadSourceCorpus.cls`, `Test/CriteriaCorpus.cls` -- new grammar corpus cases (sound and refusing).
- `src/OcuPilot/Test/WireSecurityRead.cls` -- the Pairs row on the new route, real-principal proof.
- `src/OcuPilot/Test/Wire.cls`, `Test/ReadTool.cls`, `Test/Smoke.cls` -- roster/count updates for the new screen and tool.
- `src/OcuPilot/Install/Smoke.cls` -- the `taskdetails` live check.
- `ui/src/app/areas/tasks/details.page.ts`, `details.store.ts`, `details.page.spec.ts` (all new) -- the page, its schedule-words/highlight store, and its component spec.
- `ui/src/app/core/navigation.ts` -- `detailScreenFor`, `childListFor`'s detail-archetype exclusion, `parentListFor`'s inversion.
- `ui/src/app/shell/data-table.ts` -- the name-cell link chain gains the detail-screen step.
- `ui/src/app/shell/locator-bar.ts`, `locator-bar.spec.ts` -- the entity segment names a loaded detail row by its name column.
- `ui/src/app/shell/screen-outlet.ts` -- registers `TaskDetailsPage`.
- `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs`, `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the new Fixed strings row.
- `ui/src/styles/_components.scss` -- the `.ocu-details-*` layout, added in review (see Findings).
- `ui/tools/navigation.test.mjs`, `navigation-wire.test.mjs`, `screen-mirror.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts` -- pin the new screen's position and pairs.
- `ui/tools/details-store.test.mjs` (new) -- the schedule-words vocabulary and highlight tracker, pure-function tested.
- `ui/browser/tasks.browser-spec.mjs` -- reworked to go name cell -> Task details -> History, plus a `waitForDemoTaskSuspended` poll added in review.
- `src/OcuPilot/Screen/Descriptor/TaskDetails.cls`'s `Registry`/mirror rosters and Code Map -- extended as listed above.

**Two bugs found and fixed during implementation/verification (not review findings):**

1. `LocatorBar`'s `resolved` computed did not read `generation` directly, so a store-only tick (no route change) never invalidated it and the entity segment stuck on the id after the read landed. Found by the browser run alone. Fixed by reading `generation()` directly inside `resolved`.
2. `Test.TaskDetails.TestTheDemoTaskReadsOverTheWire` and the browser spec's Story 6.7 leg both asserted `Suspended`/`Error` on the first read, but the demo fixture's own `RunNow` request does not wait for the Task Manager's next once-a-minute pass (`Install.Fixture.CreateTask`) -- reproduced live on a throwaway seconds old (red), passing once the pass had run (green). Fixed both to poll for `Suspended` before asserting, mirroring `OcuPilot.Test.Demo.TestDemoTaskIsSuspendedAfterAnError`'s own wait (`SUSPENDWAITSECONDS`/`SUSPENDPOLLSECONDS` = 180/5; the browser leg clicks the manual Refresh action between polls, since auto-refresh is off by default). Re-verified against a throwaway seconds old: both green.

**Review findings (2026-09-17 pass, full log above):** 17 findings, high 1, low 9, false 7.

- Patched (9): the missing `.ocu-details-*` CSS (high); `WireSecurityRead.DemoTaskId()`'s magic-number prefix check; `nextRunText()`'s bypass of the shared empty-value fallback; EXPERIENCE.md's under-listed schedule-vocabulary inputs; two stale doc comments/assertion messages (`navigation.test.mjs`, `Test.ReadTool`). Each re-verified: `check-objectscript.py`, `lint-docs.sh`, `npm run build && npm test` (836/434 green), and a fresh throwaway (`WireSecurityRead` 12/12, `TaskDetails` 6/6, `tasks.browser-spec.mjs` 13/13, `smoke.sh` 35/35) all green; the styled page was also visually confirmed in a real signed-in browser session (screenshot), matching the app's design system.
- Rejected (4, low, unreachable + fix needs added complexity): an unguarded empty `TimePeriodDay` in the Weekly schedule-words branch; `Install.Smoke.CheckTaskDetails`'s two-read race; `Read.cls`'s single-part-only composite-id seeding (two grouped findings).
- Refuted (7, false): the broadened refresh-with-criteria grammar (matches AD-5's existing semantics and the Design Notes' own general wording); an untested non-numeric `taskId` (live-probed: 200/zero rows, same as the tested unknown-id case); `WireSecurityRead.DemoTaskId()`'s unguarded `%FromJSON` (matches the file's own 12 other unguarded call sites); the `RowGetCorpus.cls` coverage substitution (documented exactly at the Tasks & Acceptance item it replaces); the Words matrix row's wire-level framing (a wire-level test of every combination would violate the intent's own "no task created/run/resumed/suspended by any test"); the refresh-widening/locator-bar asymmetry (the intent itself scopes the locator behavior to `archetype === 'detail'`); the async Suspended-timing gap (already fixed, see above).

**Follow-up review recommendation:** false. One high-severity entry was patched (the CSS gap), which the rule defaults to `true` on a first pass, but the specific risk that patch left open -- whether the new layout actually renders acceptably rather than merely compiling -- was resolved within this same pass: a real signed-in browser session against a fresh throwaway was screenshotted after the fix, showing a properly laid-out page consistent with the rest of the app (label/value pairs, Schedule section, History link). No other patched entry was medium or high. No unverified risk can be named.

**Verification performed:** `uv run scripts/check-objectscript.py` (clean, 355 files); `bash scripts/lint-docs.sh` (clean); `cd ui && npm run build && npm test` (836 tool tests, 434 component tests, green); `Registry.Validate` sound and all changed classes compiled clean on `ocupilot-slot-b`; on fresh `ocupilot-b-ci` throwaways, `ci-runner.mjs` green for Descriptor (35), ReadTool (26), ScreenRead (22), TaskDetails (6), TaskHistory (11), TaskLists (7), Wire (20), WireSecurityRead (12) and Smoke (31) -- 170 methods, 0 failed; `bash scripts/smoke.sh` PASSED (35/35, including `taskdetails`); `tasks.browser-spec.mjs` green (13/13) against a rebuilt-and-redeployed bundle, run twice more from a throwaway seconds old to prove the `Suspended`-poll fix under the actual race; a live read (`GET tasks.taskdetails/read?taskId=abc`) against `ocupilot-slot-b` to settle a review finding; a signed-in browser screenshot of the rendered page to settle the CSS finding.

**Residual risks:** none identified. `Test/RowGetCorpus.cls` and the "Bad id" matrix's non-numeric variant were both examined during review and found not to need further coverage (see Findings).
