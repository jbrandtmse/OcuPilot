---
title: 'On-demand and upcoming tasks'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: '4b0b80422fb4a55f5702c1b6664f9cae13fc4406'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred:
  - summary: >-
      A fixed read.source.query on a single-object GET or on a per-parent read's child lists is seeded by Read.Execute but pinned by no test or corpus case.
    evidence: |-
      SeedSourceQuery is called on the GET branch and in ForEachRows; the only query fixture (Test/ReadSource/Fixed.cls) is a plain LIST, so deleting either call leaves every test green. No shipped descriptor declares query on those shapes yet; the grammar also lets a query key equal forEach.param, which the child call then overwrites.
    location: >-
      src/OcuPilot/Screen/Read.cls SeedSourceQuery callers; src/OcuPilot/Test/ReadSourceCorpus.cls
    severity: low
---

<intent-contract>

## Intent

**Problem:** The Tasks area stops at Task schedule. Nobody can see, in OcuPilot, which tasks can be run on demand or what the Task Manager will run over a chosen horizon, and the agent has no read tool for either.

**Approach:** Two hand-written `list` descriptors over `Task.CRUD` through `AdminPort`. On-demand tasks issues the vendor LIST with its own `onDemand=1` parameter, which needs a new fixed `read.source.query`. Upcoming tasks issues the vendor's `UPCOMING` request type, which needs a new list-shaped source type, and declares its horizon as two server criteria. A small area page draws the horizon control over the shared data table.

## Boundaries & Constraints

**Always:**

- **Descriptors** (both: area `tasks`, `built` true, entity `task`, no secondaries, scope `instance`, `refreshes` false, no primary or row action, `paging` `cap`, `emptyNextKey` `tableReadOnlyEmptyNext`, `emptyAgentKey` `""`, `secretFields` `[]`, `context.fields` = read fields, pairs `%Admin_Task:USE` then `%DB_IRISSYS:READ`, no link-out). Details are in the Tasks table.
- **`read.source.query` (both engines, one sentence per refusal, `Test/ReadSourceCorpus.cls`):**
  - Absent, or a non-empty object on an `admin` source.
  - Each key matches `^[A-Za-z][A-Za-z0-9]*$`. No key equals, case-folded, a `CRITERIARESERVEDPARAMS` name or a declared `read.criteria` param.
  - Each value is a non-empty string of at most 50 characters.
  - `Read.Execute` seeds every entry into the port query before the criteria. No caller can change or remove one.
- **Source type `UPCOMING` (same corpus).** `READSOURCETYPES` becomes `LIST,GET,UPCOMING`. `UPCOMING` is admin only and declares no `rowGet` or `forEach`. `Read.Execute` issues the declared type for every non-`GET` admin read (the cap and truncation are unchanged). `AdminPort.TYPESUFFIXES` gains `UPCOMING`. `Task.CRUD` defines no `ShouldRunAsync`, and `RunUpcoming` queues nothing, so the call is synchronous (AD-26).
- **The horizon.**
  - `hoursOffset` is a `choice` with maxLength 3 and options `1,4,12,24,72,168`. `toDatetime` is a `datetime` with maxLength 19.
  - The page sends exactly one of them: `hoursOffset=24` on open, or `toDatetime=<picked date> 23:59:59` in date mode. A date before today sends nothing and reads nothing.
  - Rows are occurrences, so a task can appear more than once. The default sort is `Datetime` ascending.
- **Pairs are established** (AD-29). The `%SYS.Task` query source is stripped on this build, so a real principal proves them on the throwaway.
- **Shared files** (`Registry`, `Read`, `Descriptor/Base`, `AdminPort`, `Install/Smoke`, `Test/Descriptor`, `screen-mirror.mjs`, `strings.ts`): additive edits only. New EXPERIENCE.md Fixed strings rows go after `:356`. Non-ASCII in code is written as `\uXXXX`.

**Never:**

- **No Run.** No `rowActions` entry, action label, handler or menu item. Epic 7 Story 7.5 adds the declaration together with its handler (AD-10; the brief).
- No auto-refresh (AD-43), no `Suspended` field on On-demand (the LIST coerces it, see TaskScheduleList), no new port, no task created or run on any instance.
- No edits under `Kernel/**`, `Screen/Tool/**` or `shell/panel/**`. Also none to `Port/ProviderPort.cls`, `scripts/check-objectscript.py` and its test, `app.ts`, `app.spec.ts`, `ui/package*.json`, `angular.json` or `README.md`.
- A refusal is never an empty state or a 500.

## I/O & Edge-Case Matrix

The throwaway has the demo fixture. Reads are `GET /api/ocupilot/screens/<tool>/read`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| On-demand | `tasks.ondemand` | 200. `fields` = `[Name,Namespace,Type,Description,Id,LastFinished]`. Row set equal, by `Id`, to `%SYS.Task:OnDemandTasksFilter("")`. `OcuPilotDemo nightly purge` is present. | No error expected |
| Fixed param | `ReadFixture` over a declaration with `query {onDemand:"1"}` and a caller supplying `onDemand=0` | The port receives `onDemand=1` | — |
| Upcoming default | `tasks.upcoming?hoursOffset=24` | `fields` = `[Id,Name,Namespace,Datetime,Suspended]`. Rows equal `%SYS.Task:UpcomingTasksFilter("",24,"","",cap+1)` in order. Every `Datetime` is `YYYY-MM-DD HH:MM:SS`. For each `Id`, `Suspended` equals `Task.CRUD` INFO's. | No error expected |
| Until a date | `toDatetime=<today+1> 23:59:59` | Rows equal the query with `ToDate` = today+1 and `ToTime` 86399 | — |
| Both sent | `hoursOffset=1&toDatetime=<today+2> 23:59:59` | The vendor honors the hours (observed on slot B) | Not refused |
| Bad criterion | `hoursOffset=5` or `toDatetime=2026-09-20` | 400 `READ.CRITERION`, port not called | Envelope names the param |
| Cap | `hoursOffset=168&maxRows=1` | 1 row, `truncated` true | — |
| Pairs | Principal with `%Admin_Task:USE` alone, then with both pairs | 403 `AUTH.NOPRIVILEGE` naming `%DB_IRISSYS:READ` on both routes; with both pairs, 200 and rows equal `_SYSTEM`'s | Never 500 |
| Corpora | `ReadSourceCorpus` | Every case gets its sentence in both engines | — |

</intent-contract>

## Code Map

- **Vendor** (hidden; `iris_doc_get %Api.Admin.Endpoints.Task.CRUD.cls` in `%SYS`, `ocupilot-slot-b`):
  - `ResourcesOR` is `%Admin_Task` or `%Admin_Operate` for LIST and UPCOMING.
  - `RunList` reads `onDemand` (default 0) and keeps the rows whose `Id` `OnDemandTasksFilter` returns. Keys are `Name, Type, Namespace, Description, Id, Suspended (coerced), LastFinished, NextScheduled`.
  - `RunUpcoming` reads `maxRows` (default 100), `toDatetime` (`$ZDATETIMEH(…,3)`), `hoursOffset` (24 when both are empty) and `filter`. Keys are `Id, Name, Namespace, Suspended` (plain boolean) and `Datetime`.
  - `TYPEUPCOMING` = 13.
- **Probed on slot B** (read-only, 2026-09-16):
  - `OnDemandTasksFilter("")` returns all 19 tasks, the same as `TaskListFilter`.
  - `UpcomingTasksFilter` returns one row per occurrence in ascending date and time. It includes a suspended task's past-due occurrences.
  - `HoursOffset` is in hours. Non-empty hours win over `ToDate`. `ToDate` alone ends at that day's 00:00, and `"abc"` returns 0 rows.
- **Classic pages:** `irissys/%CSP/UI/Portal/TasksOnDemand.cls` (`OnDemandTasksFilter`, Run hidden without `%Admin_Task`) and `TasksUpcoming.cls` (`UpcomingTasksFilter`, horizon choices). Both declare `RESOURCE %Admin_Operate`.
- **Precedent:** `Screen/Descriptor/TaskScheduleList.cls` (pairs, entity, scope and its doc voice); `AuditList.cls` (criteria block); spec 2.8 and spec 6.4's Code Map for the roster checklist.
- **Grammar:**
  - `Screen/Registry.cls`: `ReadProblem` `:776` (source keys, type arm and GET arm follow); `READSOURCETYPES` `:1207`; `CRITERIARESERVEDPARAMS` `:974`; `CriteriaProblem` `:1015`.
  - `ui/tools/screen-mirror.mjs`: `readProblem` `:490`, `READ_SOURCE_TYPES` `:922`, the `ReadSource` type.
- **Read:** `Screen/Read.cls`. `READTYPE` `:52`; admin LIST call `:251`; `SeedCriteria` `:465`; criteria refusal `:246-249`.
- **Port:** `Port/AdminPort.cls:95` `TYPESUFFIXES`; `Invoke` `:308`.
- **Client:**
  - `shell/list-page.ts` is the binding to copy.
  - `shell/screen-outlet.ts:75` `DESCRIPTOR_PAGES`.
  - `core/screen-read.ts:186` `createScreenRead(api, screen, criteria)`.
  - `core/table-model.ts:40` `rowKey` (composite parts).
  - `areas/logs/audit.page.ts:76-92` (native select and input style).
- **Rosters and pins** (each gains the two screens):
  - `Test/ReadTool.cls:93-100` (22 tools → 24).
  - `screen-mirror.test.mjs` shipped reads.
  - `navigation.test.mjs:130`.
  - `Test/Wire.cls:615-621`.
  - `navigation-wire.test.mjs:93-102,297` and `shell/rail-wire.spec.ts:92-101` (both `LIVE_PAYLOAD` copies).
  - `Test/WireSecurityRead.cls:340-353` (`TASKUSER`, `TASKBOTHUSER`).
  - `Install/Smoke.cls:58,542-547` (18 checks → 20) and `Test/Smoke.cls`.
  - `Test/ScreenRead.cls`.
- **UX:** EXPERIENCE.md `:105-106` (IA rows), `:165` (side-bar order), `:356` (last Fixed strings row). `strings.test.mjs:321` (band, now at most 330).
- **Browser:** `ui/browser/tasks.browser-spec.mjs` (`DEMO_TASK` `:40`, live-container guard).

## Tasks & Acceptance

**Execution:**

- [x] `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/ReadSourceCorpus.cls` -- add `query` to the source keys and the `UPCOMING` type with their Boundaries refusals. Each rule gets identical sentences in both engines, a sound case and one case per refusal. Update the type sentence and the generated `ReadSource` type.
- [x] `src/OcuPilot/Screen/Read.cls`, `src/OcuPilot/Port/AdminPort.cls` -- seed `source.query` and issue the declared non-`GET` type (Boundaries). Add `UPCOMING` to `TYPESUFFIXES`. Update both class docs in contract voice.
- [x] `src/OcuPilot/Screen/Descriptor/TaskOnDemandList.cls`, `TaskUpcomingList.cls` (new) -- the declarations below. Each class doc states contract only: the vendor semantics probed above, why the `list` archetype (EXPERIENCE `:105-106`), and why no Run.

  | Class | route · pos · tool · aliases | source | fields · filter · sort (default) | columns (field:kind:labelKey) | id · emptyStateKey · classicPage |
  | --- | --- | --- | --- | --- | --- |
  | TaskOnDemandList | `tasks/on-demand` · 2 · `tasks.ondemand` · `["on demand", "run task"]` | `Task.CRUD` LIST, `query {onDemand: "1"}` | Matrix fields · Name, Namespace, Type, Description · Name, Namespace, Type, LastFinished (Name asc) | Name:name:tableColumnName · Namespace:text:headerNamespaceLabel · Type:text:tableColumnType · Description:text:tableColumnDescription · LastFinished:text:taskColumnLastRun | single · `taskOnDemandEmpty` · `%CSP.UI.Portal.TasksOnDemand` |
  | TaskUpcomingList | `tasks/upcoming` · 3 · `tasks.upcoming` · `["upcoming", "next runs"]` | `Task.CRUD` UPCOMING, criteria per Boundaries (labelKeys `taskUpcomingHorizon`, `taskUpcomingUntil`; no marker) | Matrix fields · Name, Namespace · Datetime, Name, Namespace (Datetime asc) | Datetime:text:taskUpcomingColumnAt · Name:name:tableColumnName · Namespace:text:headerNamespaceLabel · Suspended:status:taskColumnSuspended | composite `[Id, Datetime]` · `taskUpcomingEmpty` · `%CSP.UI.Portal.TasksUpcoming` |

  labelKeys: `taskOnDemandLabel`, `taskUpcomingLabel`.
- [x] `ui/src/app/areas/tasks/upcoming.store.ts`, `upcoming.page.ts` (new), `ui/src/app/shell/screen-outlet.ts` -- register the page in `DESCRIPTOR_PAGES` for `TaskUpcomingList`.
  - **Store.** A framework-free store (AD-19) holding the mode (`hours` or `date`), the hours (default `24`) and the date, with `criteria()` per Boundaries.
  - **Page.** On ListPage's binding, the page draws a labeled horizon form above `app-data-table`: a native select with the six hour choices plus "Until a date", and a date input, enabled only in date mode, with `min` today. A change that yields criteria clears the answers and reads once. A date before today reads nothing.
  - **Tests.** `upcoming.page.spec.ts` for the page and `ui/tools/upcoming-store.test.mjs` for the store.
- [x] EXPERIENCE.md, `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` -- append two rows after `:356` in 6.4's style, each key commented `EXPERIENCE.md:<line>`. Reuse an existing key wherever the value already exists, and widen the band if the count passes 330.
  - `:357` "On-demand tasks" · "No tasks on this instance can be run on demand.".
  - `:358` "Upcoming tasks" · "Scheduled for" · "Suspended" · "Scheduled to run within" · "The next hour" · "The next 4 hours" · "The next 12 hours" · "The next 24 hours" · "The next 3 days" · "The next 7 days" · "Until a date" · "No tasks are scheduled to run within this horizon.".

  Regenerate `screens.generated.ts`.
- [x] `src/OcuPilot/Test/TaskLists.cls` (new; needs the API app over HTTP, `_SYSTEM` and the demo fixture) -- cover:
  - both descriptors pass `Registry.Validate` with `AreaCoverageProblem` empty
  - both classic pages compile
  - the Matrix rows On-demand, Upcoming default, Until a date, Both sent, Bad criterion and Cap
  - the Integration AC
- [x] `src/OcuPilot/Test/ScreenReadSource.cls` -- the Fixed param row, and an `UPCOMING` fixture read issuing type `UPCOMING`.
- [x] `src/OcuPilot/Test/WireSecurityRead.cls` -- the Pairs row on both routes with the existing task principals, plus the side-bar screens verdict for the tasks area.
- [x] Rosters in the Code Map -- add both screens and tools. Smoke gains `TASKONDEMANDTOOL` and `TASKUPCOMINGTOOL` on the existing pattern (20 checks).
- [x] `ui/browser/tasks.browser-spec.mjs` -- the browser legs of AC1-AC3.

**Review fixes (2026-09-17 review pass):**

- [x] R1 `ui/browser/tasks.browser-spec.mjs` AC3 -- `atHour <= atDay` cannot fail (a stale table passes). After the `hoursOffset=1` read lands, assert the rendered row count equals that response's `rows.length`, and assert the first response body carries `rows` before reading it.
- [x] R2 `ui/browser/tasks.browser-spec.mjs` AC3 -- nothing checks the Upcoming page offers no action but Refresh (the page spec reads only the generated declaration). Probe the command bar and command box on Upcoming as AC2 does on On-demand.
- [x] R3 `ui/src/app/areas/tasks/upcoming.page.spec.ts` -- "a change that yields criteria clears the answers" is unpinned (`readNow()` in place of `noteScopeChanged()` stays green). Add a case with a stub answer held back, asserting the table's rows are gone after a horizon change and before the answer lands.
- [x] R4 `src/OcuPilot/Test/WireSecurityRead.cls` Pairs row -- compare the both-pairs principal's rows with a wire read as the configured test principal (`OcuPilot.Test.Http` `GetTestUsername`/`GetTestPassword`), both bodies parsed the same way, rather than with an in-process `Read.Execute`.
- [x] R5 `src/OcuPilot/Test/TaskLists.cls` -- `OnDemandIds` and `UpcomingOccurrences` return `""` from their `Catch`, so a failed vendor query reads as an empty set; return text naming the error instead. In `TestADateHorizonAndBothCriteriaReadAsTheVendorAnswers` compute the day (`+$Horolog + 1`) once and use it for both the URL and the vendor query.
- [x] R6 Doc accuracy: `Screen/Registry.cls` `SourceQueryProblem` and `ui/tools/screen-mirror.mjs` `sourceQueryProblem` say the entries go on "every port call of the read", and `Screen/Read.cls`'s class doc says "each call of the read's own endpoint"; state exactly which calls carry them (the LIST or UPCOMING call, a single-object GET, each per-parent child list -- not the parent list and not a `rowGet` detail call). Repair the run-on dash nesting the `UPCOMING` clause left in `ReadProblem`'s doc and in `readProblem`'s JSDoc. `Install/Smoke.cls` `CheckAreaLists` doc: "on any instance" becomes "on a clean container". EXPERIENCE.md `:358` prose: the empty state refers to the chosen horizon rather than naming it.
- [x] R7 Rule 19 lines in `## Verification`, each observed then reverted: AC1 (swap the two new descriptors' `sideBarPosition` -> browser AC1 red); AC2 (drop `query` from TaskOnDemandList with the mirror regenerated -> `screen-mirror.test.mjs` red; drop the `LastFinished` column -> browser AC2 red); AC4 browser leg (drop `%DB_IRISSYS:READ` from TaskUpcomingList, server reloaded on the throwaway and bundle rebuilt and redeployed -> browser AC4 red); and one line each for R1-R3's new assertions.

**Acceptance Criteria:**

- **AC1.** Given `_SYSTEM` on the throwaway, when the Tasks area opens, then the side bar reads Task schedule, On-demand tasks, Upcoming tasks, and each entry opens its screen.
- **AC2 (on-demand).** Given the demo fixture, when On-demand tasks loads, then the table shows Name, Namespace, Type, Description and Last run from exactly one `tasks.ondemand` read, `OcuPilotDemo nightly purge` is a row, and no row, menu, command bar or command box offers an action other than Refresh.
- **AC3 (upcoming).** Given Upcoming tasks, when it loads, then all of the following hold:
  - it reads with `hoursOffset=24`, and rows render in ascending Scheduled for
  - choosing "The next hour" re-reads with `hoursOffset=1` and renders no more rows than before
  - choosing "Until a date" and tomorrow's date re-reads with `toDatetime=<tomorrow> 23:59:59` and no `hoursOffset`
- **AC4 (gating).** Given the throwaway principal holding install-DB read and `%Admin_Task:USE` only, when it deep-links to either route, then it sees "You need %DB_IRISSYS:READ to open <title>." with no table and no read.
- **Integration.** Given consumer `Screen.Tool.Read.View`, when it reads `tasks.ondemand.read` and `tasks.upcoming.read` (with `hoursOffset` `24`) live, then it returns each route's fields and rows narrowed by its cap. Its input schema offers `hoursOffset` as an enum of the six options.

## Spec Change Log

- 2026-09-17 (spec gate, lead): AD-36 amended with the two source shapes (`UPCOMING`, `source.query`); epics.md Story 6.5's "offering Run" AC amended to name Story 7.5 as where Run ships; the other gate decisions (vendor on-demand definition, six hour choices plus a date, plain `list`, the Suspended cross-check) accepted as planned.

## Review Triage Log

### 2026-09-16 — Review pass

- verdicts: 48 findings — high 0, medium 4, low 37, false 7, maybe-false 0
- findings:
  - `[low]` `[reject]` Blind: Upcoming and On-demand carry no Task Manager banner — the descriptor table declares none and a suspended Task Manager is rare; adding one needs a banner path on `UpcomingPage`; reopen_if the owner wants the Task schedule banner on every Tasks list.
  - `[low]` `[reject]` Blind: "today" and `toDatetime` come from the browser clock, not the instance's — wrong outcome is one empty horizon when the user picks the browser's today while the instance's date is already later; the fix needs an instance-date surface the client lacks; reopen_if a user reports an empty Upcoming list for today on an instance in another time zone.
  - `[low]` `[reject]` Blind: date mode with no valid date leaves the previous horizon's rows under an "Until a date" select — the spec's "reads nothing" leaves the table as it was; clearing it would show an empty state for a non-read (Never: a refusal is never an empty state).
  - `[low]` `[reject]` Blind: horizon change uses `noteScopeChanged`, clearing live proposals — `ListPage` uses the same call for a parent change; Upcoming does not refresh, so the proposal set only gates a fault resume.
  - `[low]` `[patch]` Blind: fixed query can clash with `forEach.param` / is not seeded on `rowGet`, and the docs overstate where it travels — R6 corrected the doc claims in `Registry`, `screen-mirror.mjs` and `Read`; the clash guard itself is rejected (no descriptor combines the shapes; two-engine refusal plus corpus is more than a correction).
  - `[low]` `[defer]` Blind: corpus and tests miss `query` on a GET or per-parent source — grouped with the verification-gap GET/forEach row; deferred.
  - `[low]` `[reject]` Blind: On-demand shows the same rows as Task schedule — spec-bound (gate decision "On-demand means the vendor's").
  - `[low]` `[reject]` Blind: alias "run task" on a screen with no Run — spec-bound (the Tasks table declares the aliases; an alias is not an action).
  - `[low]` `[patch]` Blind: smoke doc claims one row "on any instance" — R6 reworded to "on a clean container".
  - `[low]` `[reject]` Blind: live comparisons in `TaskLists`/`WireSecurityRead` can flake at a minute boundary — reads are milliseconds apart and stock tasks run at fixed minutes; a retry loop adds complexity.
  - `[low]` `[patch]` Blind: `OnDemandIds`/`UpcomingOccurrences` swallow errors as an empty set — R5 returns the error text and throws on a failed `Execute`.
  - `[low]` `[reject]` Blind: read tool schema does not say the two criteria are alternatives — field descriptions are `Screen/Tool/**` (Never) and DW-1001's.
  - `[low]` `[patch]` Blind: EXPERIENCE `:358` prose says the empty state names the horizon — R6 reworded.
  - `[low]` `[reject]` Blind: page spec lacks Refresh-with-date and past-date positive control — the store test pins the past-date guard (mutation observed); the date read is pinned by the "Until a date" case.
  - `[medium]` `[patch]` Blind: browser AC3 `atHour <= atDay` cannot fail — R1 asserts the rendered count equals the hour answer's rows (mutation observed).
  - `[low]` `[patch]` Blind: `ReadProblem` doc and `readProblem` JSDoc left run-on dash nesting — R6 split the sentences.
  - `[false]` `[reject]` Blind: `TestBothDescriptorsValidateAsTheTasksEntriesTheyReplace` is misleading — each descriptor replaces its classic page (AD-44), which the method asserts.
  - `[low]` `[patch]` Blind: `WireSecurityRead` parses the body without UTF-8 decode while comparing to an in-process read — R4 compares two wire reads through `AssertSameRowsAsTestAccount`.
  - `[low]` `[reject]` Edge: query key equal to `forEach.param` is overwritten — no descriptor combines the shapes; see the Blind clash row.
  - `[low]` `[reject]` Edge: `rowGet` detail calls go without the fixed query — no descriptor combines the shapes; docs now say so (R6).
  - `[low]` `[reject]` Edge: browser vs server time zone — same as the Blind clock row.
  - `[low]` `[reject]` Edge: page left open past midnight in date mode refreshes a past date — rare, recoverable, fix adds a branch to the read closure.
  - `[false]` `[reject]` Edge: impossible date `2026-02-31` from the store — a native `type=date` input sanitizes an invalid value to `""`, which the store answers as no criteria.
  - `[low]` `[reject]` Edge: timed comparisons flake — same as the Blind flake row.
  - `[low]` `[patch]` Edge: date test computes tomorrow twice across midnight — R5 computes `tDay` once.
  - `[low]` `[reject]` Edge: engines report a different first bad key for `{"a-b":…,"5":…}` — two invalid keys in one declaration; fix changes both engines' iteration order.
  - `[false]` `[reject]` Edge: surrogate pairs count differently — IRIS strings are UTF-16 code units, as JS `.length`.
  - `[low]` `[patch]` Edge: browser AC3 `first.body.rows` TypeError hides the cause — R1 asserts `rows` first.
  - `[low]` `[patch]` Edge: doc claim "every port call" is wrong — R6.
  - `[low]` `[defer]` Verification gap: fixed query on a GET or per-parent read is untested (filed defer) — deferred.
  - `[medium]` `[patch]` Verification gap: `atHour <= atDay` cannot fail — grouped with Blind row; R1.
  - `[medium]` `[patch]` Verification gap: Upcoming's no-action-but-Refresh reads only the generated declaration — R2 probes the command bar and box on Upcoming (mutation observed).
  - `[medium]` `[patch]` Verification gap: horizon change clearing rows is unpinned — R3 page-spec case with a held answer (mutation observed).
  - `[low]` `[patch]` Verification gap: no live test catches On-demand's `query` dropped — R7 recorded the declaration pin's mutation (`screen-mirror.test.mjs` red).
  - `[low]` `[patch]` Verification gap: AC1 has no mutation line — R7 (sideBarPosition swap, browser AC1 red).
  - `[low]` `[patch]` Verification gap: AC2 headers/one-read/no-action have no mutation line — R7 (LastFinished column dropped, browser AC2 red).
  - `[low]` `[patch]` Verification gap: AC4 browser leg has no mutation line — R7 (pair dropped, browser AC4 red).
  - `[low]` `[reject]` Verification gap: fixed query overwritten by `forEach.param` — same as the Blind clash row.
  - `[low]` `[patch]` Verification gap: docs disagree on where the query travels — R6.
  - `[low]` `[patch]` Intent: Pairs row compares with an in-process read, not `_SYSTEM`'s wire rows — R4.
  - `[low]` `[reject]` Intent: "run task" alias — spec-bound.
  - `[low]` `[patch]` Intent: live On-demand parity cannot tell `onDemand=1` from none — grouped with the verification-gap row; R7.
  - `[false]` `[reject]` Intent: synchronous `UPCOMING` untested — the port answers either path as an ordinary call (AD-26); no reachable wrong outcome.
  - `[low]` `[reject]` Intent: exactly-one criterion is page-only — by design (matrix "Both sent": not refused).
  - `[low]` `[reject]` Intent: past date refused client-side only — by design (Boundaries: the page sends nothing).
  - `[false]` `[reject]` Intent: default sort not tested on the table — the page spec and browser AC3 assert ascending rendered order.
  - `[false]` `[reject]` Intent: Suspended "Yes or No" untested with `kind: status` — `core/table-model.ts:68` renders a boolean status as Yes or No.
  - `[false]` `[reject]` Intent: shared-file edits are not strictly additive — the intent itself requires the changed type sentence and `READSOURCETYPES`.

## Design Notes

**Architecture decisions:**

- **AD-2 / AD-27:** `Task.CRUD` only, through `AdminPort`. The class is inventoried, and `UPCOMING` is synchronous (read from source).
- **AD-5:** two descriptors.
- **AD-8 / AD-29:** pairs are proven by a principal. **AD-10:** no Run (Never).
- **AD-13 / AD-14:** entity `task`, scope `instance`, so Story 7.5's change event re-reads both.
- **AD-19:** the horizon store is framework-free. **AD-21:** the criteria are the allow-list, validated before the port.
- **AD-24 / AD-36:** one capped read per screen, shared with the tool. **AD-43:** no refresh. **AD-44:** each descriptor names its classic page.

**Decisions for the gate:**

- **AD-36 wording (Rule 20).** This story adds two source shapes: a fixed `source.query` and a list-shaped request type other than `LIST`. Neither contradicts the Rule, but 6.4 recorded its shapes there. Recommend appending: "a read may name a list-shaped admin request type other than LIST (`UPCOMING`) and fixed query parameters no caller can change (`source.query`)."
- **On-demand means the vendor's.** The screen replaces `TasksOnDemand`, whose query returned every task on slot B, rather than `TimePeriod` 5 (On Demand schedule, zero tasks). Catalog TM-02 names the vendor filter.
- **No Run control.** This follows 2.8's Resume precedent and the brief: AC "offering Run" is met by Story 7.5 adding the action with its handler.
- **Horizon as a choice.** "A number of hours" is six preset hour counts, not free entry. A new `number` kind would fall into `Screen/Tool/Read.AddCriteria`'s "comma-separated names" description (out of bounds, DW-1001), and free text like `abc` silently returns zero rows (observed).
- **Upcoming stays `list`** (EXPERIENCE `:106`) and reads on open, unlike `list (server criteria)`. The horizon scopes the query rather than searching it.

**Test rows.** No task is created. A fresh throwaway holds the stock system tasks and the demo task (inference, from slot B's 16 system tasks), and daily system tasks fall inside 24 hours, so both lists have rows.

**Ledger inbox:** none owned. DW-1001 and DW-1018 are not re-litigated (the tasks area's pairs are unchanged).

**Integration ACs:** the Integration AC, AC2 and AC3 through the page and the data table, and the two smoke checks.

**Consumes:** `AdminPort` (2.1), `Screen.Read` and criteria (2.3, 2.10), `ListPage` and the data table (2.4), the gate (1.9), the area union (6.3), and the `GET` and `forEach` source grammar (6.4).

**Consumed-by:**

- 4.2 / 4.4: tool registry, screen context.
- 6.6: `HISTORY` is the next list-shaped request type (inference).
- 7.5: Run on On-demand rows.
- 5.7: pause on a `task` proposal.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: a clean compile. Slot B is only read and compiled into; nothing is created there.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy, demo fixture on. Every principal and every mutation lives on this throwaway only. Teardown: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`, run `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for TaskLists, ScreenReadSource, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor, Smoke and AdminPortSync -- expected: all green, with totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: the two new task checks pass, with no failures.
- `cd ui && npm run build && npm test` -- expected: green, and `screen-mirror --check` clean.
- From `ui/`, run `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `tasks.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations (Rule 19).** Record each as `mutation: <change> -> <test red> (observed)`, then revert and confirm the tree is byte-identical.

- AC2: drop `query` from TaskOnDemandList, or have `Read` skip seeding it (recompiled with descendants).
- AC3: `criteria()` always sends `hoursOffset`; the default sort `desc`.
- Upcoming default: `Read` issues `LIST` for every admin type.
- Both engines: each new refusal arm disabled in turn reddens its corpus case.
- AC4: drop `%DB_IRISSYS:READ` from TaskUpcomingList.
- Integration: `hoursOffset` options changed on the descriptor only, with the mirror regenerated.

**Observed (slot B throwaway `ocupilot-b-ci`, 2026-09-17):**

- mutation: `Read.Execute` skips `SeedSourceQuery` (recompiled with subclasses) -> `ScreenReadSource.TestAFixedQueryParameterReachesThePortWhateverTheCallerSends` red (observed)
- mutation: `upcoming.store.ts` `criteria()` always sends `hoursOffset` -> `upcoming-store.test.mjs` two tests, `upcoming.page.spec.ts` "Until a date", and the rebuilt, redeployed `tasks.browser-spec.mjs` Story 6.5 AC3 red (observed)
- mutation: TaskUpcomingList default sort `desc`, mirror regenerated -> `upcoming.page.spec.ts` "ascending Scheduled for" red (observed)
- mutation: `Read.Execute` issues `READTYPE` for every admin read -> `TaskLists` default-horizon and date-horizon tests and `ScreenReadSource.TestAnUpcomingSourceIsIssuedAsItsOwnType` red (observed)
- mutation: each of the ten new `readProblem` / `sourceQueryProblem` arms disabled in turn -> its own `ReadSourceCorpus` case red in `screen-mirror.test.mjs` (observed, ten runs)
- mutation: each of the ten new `ReadProblem` / `SourceQueryProblem` arms disabled in turn, recompiled with subclasses -> its own `ReadSourceCorpus` case red in `ReadTool.TestEveryReadSourceCorpusCaseGetsItsSentence` (observed, ten runs)
- mutation: `%DB_IRISSYS:READ` dropped from TaskUpcomingList -> `WireSecurityRead` Pairs row (tasks.upcoming refusal) and task side-bar verdict red (observed)
- mutation: `hoursOffset` options changed on TaskUpcomingList -> `TaskLists.TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap` enum assertion red on the server, and with the mirror regenerated `upcoming-store.test.mjs` declared-options test red (observed)
- mutation: past-date guard dropped from `criteria()` -> `upcoming-store.test.mjs` "a date before today" red (observed)
- mutation: TaskOnDemandList and TaskUpcomingList `sideBarPosition` swapped, both reloaded, mirror regenerated, bundle rebuilt and redeployed -> browser Story 6.5 AC1 "the three entries in their declared order" red (observed)
- mutation: `query` dropped from TaskOnDemandList, mirror regenerated -> `screen-mirror.test.mjs` "readProblem returns every admin-privilege sentence OcuPilot.Test.AdminPairCorpus declares" red on its pinned TaskOnDemandList source (observed)
- mutation: TaskOnDemandList `LastFinished` column dropped, reloaded, mirror regenerated, bundle rebuilt and redeployed -> browser Story 6.5 AC2 headers assertion red (observed)
- mutation: `%DB_IRISSYS:READ` dropped from TaskUpcomingList, reloaded on the throwaway, bundle rebuilt and redeployed (the generator refuses the mutated declaration, so the mirror stays real) -> browser Story 6.5 AC4 red, no denied title within the timeout (observed)
- mutation: `UpcomingPage.apply()` issues the hour read without applying it, leaving the 24-hour table, bundle rebuilt and redeployed -> browser Story 6.5 AC3 "the table renders the next hour's answer" red, 445 against 19 (observed)
- mutation: TaskUpcomingList declares a `run` row action, mirror regenerated, bundle rebuilt and redeployed -> browser Story 6.5 AC3 "the command bar offers Refresh alone" red (observed)
- mutation: `UpcomingPage.apply()` calls `readNow()` in place of `noteScopeChanged()` -> `upcoming.page.spec.ts` "a horizon change clears the rows before the new answer lands" red (observed)

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Two built Tasks lists over `Task.CRUD` through `AdminPort`: On-demand tasks (LIST with a fixed `source.query` `onDemand=1`) and Upcoming tasks (new `UPCOMING` source type, horizon as two server criteria, `UpcomingPage` over the data table with a framework-free horizon store). Registry and mirror grammar for `query` and `UPCOMING` in both engines with 22 corpus cases; no Run anywhere.

**Files changed.**

- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/ReadSourceCorpus.cls` -- `query` and `UPCOMING` refusals, same sentences.
- `src/OcuPilot/Screen/Read.cls`, `src/OcuPilot/Port/AdminPort.cls` -- seed the fixed query, issue the declared type; `UPCOMING` suffix.
- `src/OcuPilot/Screen/Descriptor/TaskOnDemandList.cls`, `TaskUpcomingList.cls` -- the two declarations.
- `ui/src/app/areas/tasks/upcoming.store.ts`, `upcoming.page.ts`, `upcoming.page.spec.ts`; `ui/src/app/shell/screen-outlet.ts` -- the horizon page and its registration.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md `:357-358`, `ui/src/app/core/screens.generated.ts` -- strings and regenerated mirror.
- `src/OcuPilot/Test/TaskLists.cls` (new), `ScreenReadSource.cls`, `WireSecurityRead.cls`, `Wire.cls`, `ReadTool.cls`, `ScreenRead.cls`, `Smoke.cls`; `src/OcuPilot/Install/Smoke.cls` (20 checks) -- tests and rosters.
- `ui/browser/tasks.browser-spec.mjs`, `ui/tools/upcoming-store.test.mjs`, `navigation*.test.mjs`, `screen-mirror.test.mjs` -- client and browser legs.
- Outside the task list: `src/OcuPilot/Test/ReadSource/Endpoint.cls` (records type and query), new fixtures `Test/ReadSource/Fixed.cls` and `Upcoming.cls`, `ui/src/app/shell/rail-wire.spec.ts` (LIVE_PAYLOAD copy).

**Review.** 48 findings (medium 4, low 37, false 7). Patched 17 rows as R1-R7 by a fresh subagent: medium 4 (AC3 count assertion, Upcoming action probe, rows cleared on horizon change), low 13 (doc claims, smoke wording, test helper errors, midnight date, Pairs wire comparison, Rule 19 lines for AC1, AC2, AC4). Deferred 2 rows as one item (query on GET/per-parent untested). Rejected 29 with reasons in the triage log, notably the browser-clock "today" (reopen_if an empty Upcoming list for today is reported across time zones) and the `forEach.param` clash guard.

**Follow-up review: recommended** (patched: high 0, medium 4, low 13). Unverified risk: R4 re-pinned the Pairs row's row comparison to `AssertSameRowsAsTestAccount` without its own mutation line.

**Verification.** `check-objectscript` 0 problems; `lint-docs` clean; `npm run build` (screen-mirror up to date) and `npm test` (812 node, 416 component) green; 333 classes loaded and changed classes compiled clean on `ocupilot-slot-b`; on a recycled `ocupilot-b-ci` throwaway, one class per call: TaskLists 7, ScreenReadSource 9, WireSecurityRead 10, ReadTool 26, Smoke 30, Wire 20, ScreenRead 22, Descriptor 34, AdminPortSync 6, all 0 failed (run indices 1-9 consecutive); `smoke.sh` 33/33 passed; full browser suite 98/98. Throwaway torn down.

**Residual risks.** Horizon "today" is the browser's date; the horizon resets to 24 hours when a name cell link re-mounts the page; On-demand's fixed parameter is only observable through the declaration and fixture pins because the vendor answers every task on this build.
