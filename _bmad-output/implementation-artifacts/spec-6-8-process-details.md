---
title: 'Process details'
type: 'feature'
created: '2026-09-17'
status: 'in-review'
baseline_revision: 'c75bf657633ccfbf916cddff73f79a448f4af7fa'
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

**Problem:** Processes' Pid cell is inert: no screen shows what one process is doing, so an administrator cannot judge a process before acting on it (Stories 7.8, 5.12), and 6.10's lock owner has nowhere to link.

**Approach:** One unlisted `detail` descriptor, parent-scoped under Processes and keyed by `Pid`, reading `Process` `GET` through `AdminPort`, reached through 6.7's `detailScreenFor` chain. An OS management page renders it as the classic page's three metric groups, auto-refreshing through the shared framework. The SQL clause follows the recommended amendment under Design Notes (pending the lead).

## Boundaries & Constraints

**Always:**

- **Descriptor `ProcessDetails`:**
  - route `os-management/processes/details`, area `os-management`, `sideBarPosition` 0, archetype `detail`, `built` true, `parentScope` `os-management/processes`
  - entity `process`, scope `instance`, id composite `["Pid"]`, `refreshes` true, rates `[5,10,30,60]`
  - pairs, in order: `%Admin_Operate:USE`, `%Admin_Manage:USE`, `%DB_IRISSYS:READ` (Processes' set; GET runs `VariableByPid`, which checks `%Admin_Manage:USE`); confirm each with a real principal
  - tool `osmgmt.processdetails`; aliases `["process details"]`; no primary or row action; `emptyAgentKey` `""`; `classicPage` `%CSP.UI.Portal.ProcessDetails`, exemption false; `secretFields` `[]`; `context.fields` = read fields
  - read: admin `Process` `GET`, no `rowGet`; criterion `pid` text maxLength 10, `vendorParam` `id`
  - read fields and `table` columns (field:kind), in page order:
    - **General:** Pid:name · ParentPid:text · UserName:text · LoginRoles:text · EscalatedRoles:text · OSUserName:text · NameSpace:text · Priority:number · StartTimeUTC:text · CPUTime:number · CommandsExecuted:number · GlobalReferences:number · PrivateGlobalReferences:number · PrivateGlobalBlockCount:number · MemoryAllocated:number · MemoryPeak:number · MemoryUsed:number · CurrentDevice:text · OpenDevices:text
    - **Execution:** State:text · InTransaction:text · Routine:identifier · CurrentLineAndRoutine:identifier · Location:text
    - **Client application:** ClientNodeName:text · ClientExecutableName:text · ClientIPAddress:text
  - `emptyStateKey` `processDetailsGone`
- **Never named, anywhere** (field, context, test assertion, fixture output): `Variables` (the process's whole local variable table), `CSPSessionID`, `CurrentSrcLine`, `LastGlobalReference`, `UserInfo`, `Roles`, `LicenseUserId`, `CanBe*` (AD-24, AD-35; see Design Notes).
- **Page** (`areas/os-management/process-details.page.ts` + `.store.ts`, in `DESCRIPTOR_PAGES`):
  - Mirrors 6.7's details page: `RefreshService` bound to the declared read, criterion from the route through `parentCriteria`, skeleton fields on first load only, a fault keeps the last values, a silent tick highlights changed fields, zero rows show `processDetailsGone`.
  - Each value renders through `cellView` (arrays join with `, `). The name never renders as a link.
  - The three group headings are a page constant naming columns. A declared column no group names renders in General, so nothing is hidden.
  - `InTransaction` reads "Yes" for non-zero and "No" for zero (`tableStatusYes`/`tableStatusNo`).
  - No meter component and no thresholds: process metrics declare none, and 6.9 builds the meter.
- 6.7's `TaskDetailsHighlights` moves unchanged to `ui/src/app/core/detail-highlights.ts` as `DetailHighlights`, and both pages import it (no cross-slice import).
- **Auto-refresh roster:** EXPERIENCE.md's auto-refresh bullet and Process details IA row gain Process details. AD-43's roster wording is the lead's (Design Notes).
- Shared files are additive. New Fixed strings rows go after the last. Non-ASCII in code is `\uXXXX`. No context field above 1,000 characters.

**Never:**

- No terminate, suspend, resume or broadcast control (7.8, 5.12, 16.6), no Variables tab, no audit-view event, no new port, source kind or grammar rule, no classic link-out.
- No edits to `Kernel/**`, `Port/ProviderPort.cls`, `Screen/Tool/**`, `scripts/check-objectscript.py` or its test, `app.ts`, `app.spec.ts`, `ui/package*.json`, `angular.json`, `README.md`, `shell/panel/**`.
- No test starts, suspends or terminates a process.

## I/O & Edge-Case Matrix

Reads are `GET /api/ocupilot/screens/osmgmt.processdetails/read`. A stable pid: in ObjectScript tests, the test's own `$J`, which lives for the test's duration. In browser specs, the write daemon (`WRTDMN`, `processes.browser-spec.mjs`), which lives for the container's life.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Live process | `pid=<stable pid>` | 200, one row. `Pid` equals the pid; `OpenDevices` is an array; every declared field is a key; no `Variables`/`CSPSessionID` key | — |
| Gone | `pid=999999999` | 200, zero rows (vendor 404), page shows "This process no longer exists." | Not a refusal (AD-37) |
| No id | no `pid` | 400 `READ.CRITERION` naming `pid`; port not called | Never 500 |
| Bad id | 11 characters | 400 `READ.CRITERION` | — |
| Pairs | `%Admin_Operate:USE`+`%DB_IRISSYS:READ` principal; then all three | 403 `AUTH.NOPRIVILEGE` naming `%Admin_Manage:USE`; then 200 | Never 500 |

</intent-contract>

## Code Map

- **Vendor** (`%Api.Admin.Endpoints.Process`, hidden; read on slot B, read-only):
  - `GET` takes query `id` (`ValidateQueryParams`). An unknown pid answers 404, so the source reads zero rows (`Read.cls` GET branch `:246-297`).
  - `ObjToJson` answers the keys above. `LoginRoles`, `EscalatedRoles`, `Roles` and `OpenDevices` are arrays. `StartTimeUTC` is `YYYY-MM-DD HH:MM:SS`. It has no SQL table or statement; a process running SQL names its cached query in `Routine` (`%sqlcq.*` or `%SYS.sqlcq.*`).
  - It also runs `SYS.Process:VariableByPid` into `Variables` (vendor cap 1,000 rows).
  - `ResourcesOR` is `%Admin_Operate`. `%SYS.ProcessQuery.AllowToOpen` (`irissys/%SYS/ProcessQuery.cls:423`) admits IRISSYS read. `VariableByPid` (`:1494`) requires `%Admin_Manage:USE` or IRISSYS write.
- **Classic page** `irissys/%CSP/UI/Portal/ProcessDetails.cls`: `RESOURCE %Admin_Operate`, auto-refresh (`OnDrawRibbon :236`), value groups in `GetDetailPane :457-558` (General Information, Execution Details, Client Application Details).
- **Precedents:**
  - `src/OcuPilot/Screen/Descriptor/TaskDetails.cls` (whole shape); `ProcessList.cls` (pairs rationale `:40-65`; its Pid-cell sentence `:15-18` and the Story 6.8 sentence `:70` go stale).
  - `src/OcuPilot/Test/TaskDetails.cls` (`TestTheDeclarationValidates… :92`, `TestTheDemoTaskReadsOverTheWire :141`, `TestAnUnknownIdReadsAsNoRows :184`, `TestNoIdIsRefused :195`, `TestAnOverLongIdIsRefused :209`, `TestTheReadToolAnswersTheSameRowAsTheRoute :220`).
  - `src/OcuPilot/Test/WireSecurityRead.cls`: `AssertReadRefused` (asserts `:324-328`) (403 `AUTH.NOPRIVILEGE`, `detail.failedPair`), `TestTheProcessesListsPairSetIsEnforcedForARealPrincipal :493` (`OPERATEUSER` lacks `%Admin_Manage:USE`; `PROCESSUSER` holds all three).
- **Client:**
  - `ui/src/app/areas/tasks/details.page.ts` (`:23` import, `:139-153` highlights) and `details.store.ts` (`changedFields :170`, `TaskDetailsHighlights :183`); `ui/tools/details-store.test.mjs:118` pins the tracker.
  - `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES :78`; `core/navigation.ts` `detailScreenFor`/`parentListFor` (unchanged); `core/table-model.ts` `cellView`; `shell/locator-bar.ts` (names a parent-scoped detail by its first `name` column).
  - `ui/src/app/areas/os-management/` does not exist yet (Processes renders through `ListPage`); this story creates it.
  - `core/strings.ts`: reusable keys `tableStatusYes :307`, `tableStatusNo :309`, `taskHistoryColumnStarted :704`.
- **Rosters to extend** (6.7's list): `Test/ReadTool.cls`, `Test/Wire.cls`, `Test/Descriptor.cls`, `Test/ScreenRead.cls`, `Install/Smoke.cls` (+ `Test/Smoke.cls`), `ui/tools/navigation.test.mjs`, `screen-mirror.test.mjs`, `navigation-wire.test.mjs` and `shell/rail-wire.spec.ts` `LIVE_PAYLOAD`s, `strings.test.mjs`, `classic-links.test.mjs` (count unchanged).
- **UX:** EXPERIENCE.md `:92` (IA row) and `:620` (auto-refresh roster) already amended; Fixed strings table ends at `:361` (Task details row).
- **Browser:** `ui/browser/processes.browser-spec.mjs` (`DAEMON_ROUTINE :51`, `readDaemonPid :88`).

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Screen/Descriptor/ProcessDetails.cls` (new) -- the declaration in Always. Class doc: vendor semantics, the never-named fields and why, the pair set, the route entity type. Replace `ProcessList.cls`'s stale Pid-cell and Story 6.8 sentences with the current fact.
- [ ] `ui/src/app/core/detail-highlights.ts` (new), `areas/tasks/details.store.ts`, `details.page.ts`, `ui/tools/details-store.test.mjs` -> `ui/tools/detail-highlights.test.mjs` (new) -- move the tracker as `DetailHighlights` with its test and mutation note; behavior unchanged.
- [ ] `ui/src/app/areas/os-management/process-details.store.ts`, `process-details.page.ts`, `process-details.page.spec.ts` (new), `ui/src/app/shell/screen-outlet.ts` -- the page, its group map (unnamed column falls to General) and the transaction words; register in `DESCRIPTOR_PAGES`. Pin the store in `ui/tools/process-details-store.test.mjs` (new).
- [ ] EXPERIENCE.md (after `:361`), `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` -- append one Fixed strings row: "Process details" · "This process no longer exists." · "General" · "Execution" · "Client application" · "Parent process ID" · "Login roles" · "Escalated roles" · "OS user" · "CPU time (ms)" · "Global references" · "Private global references" · "Private global blocks" · "Memory limit (KB)" · "Memory peak (KB)" · "Memory used (KB)" · "Current device" · "Open devices" · "In transaction" · "Source location" · "Location" · "Client name" · "Client executable" · "Client IP address". Reuse existing keys for Process ID, User, Namespace, Priority, Routine, State, Commands, and "Started" for `StartTimeUTC`. Regenerate the mirror.
- [ ] `src/OcuPilot/Test/ProcessDetails.cls` (new; HTTP, `_SYSTEM`) -- declaration validates with `AreaCoverageProblem` empty and `RouteEntityType` = `process`; matrix rows Live, Gone, No id, Bad id; the Integration AC.
- [ ] `src/OcuPilot/Test/WireSecurityRead.cls` -- the Pairs row: `OPERATEUSER` refused on `osmgmt.processdetails` naming `%Admin_Manage:USE`; `PROCESSUSER` (exactly the three pairs) reads 200 with one row for the test's own `$J`, which is AD-29's real-principal confirmation.
- [ ] Rosters -- extend each Code Map roster by the new descriptor. Smoke gains an `osmgmt.processdetails` read keyed by the first `osmgmt.processes` row's `Pid`, passing on exactly one row whose `Pid` matches. `navigation.test.mjs` pins `detailScreenFor(processes)` = ProcessDetails.
- [ ] `ui/browser/processes.browser-spec.mjs` -- the browser legs of AC1-AC5 against the write daemon.

**Acceptance Criteria:**

- AC1: Given Processes on the throwaway, when the write daemon's Pid cell is activated, then the URL is `/ocupilot/os-management/processes/details/<pid>`, one `osmgmt.processdetails` read is issued, and the page shows the General, Execution and Client application groups with Process ID `<pid>`, Routine `WRTDMN`, and Open devices text.
- AC1b: Given a read row whose `Routine` is `%sqlcq.HSCUSTOM.cls1` and `ClientExecutableName`/`ClientIPAddress` set (component spec), when the page renders, then the Execution group shows that routine verbatim and the Client application group shows both values.
- AC2: Given a cold deep link to that route with the write daemon's pid (the route 6.10's owner link opens), when it loads, then that process is shown and the locator bar's screen segment links back to Processes.
- AC3: Given the refresh chip at 5 s, when a tick fires, then the process is re-read with no skeleton and no announcement, and a changed field carries the highlight class (component spec with a fake tick; the browser leg asserts no skeleton after a tick).
- AC4: Given a pid that has exited, when the route opens, then "This process no longer exists." shows and no refusal renders.
- AC5: Given a principal lacking `%Admin_Manage:USE`, when it opens the deep link, then the denied view names that pair and no read is issued.
- Integration: given the tool `osmgmt.processdetails.read` with the test's own `$J`, when called in process, then it answers the row the screen's read answers for the same pid over the declared fields, with no `Variables` key.

## Spec Change Log

- 2026-09-17 (spec gate, orchestrator answers): intent gap resolved. AC1 narrowed in epics.md as the intent block already states (a cached SQL query named by its routine; statement text is Story 19.10's). AD-43's roster grows to seven with Process details (spine amended; EXPERIENCE.md Auto-refresh controls row and Process details row updated; the meter row no longer names Process details). Plan-level decisions (dashboard values, the three pairs confirmed by a real principal on `ocupilot-b-ci`, never-named fields, reuse of 6.7's grammar, 6.10 as consumer) accepted. Status reset to `draft` for re-plan.

## Review Triage Log

### 2026-09-17 — Review pass

- verdicts: 16 findings — high 0, medium 5, low 4, false 7, maybe-false 0
- findings:
  - `[false]` `reject` Blind Hunter: `process-details.page.ts`'s `cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text` is a 3-arg call against a supposedly 2-arg `cellView`, and `TableColumn` supposedly has no `emptyKey` — `table-model.ts:71-76` declares `cellView(value, kind, emptyKey = '', lookup = stringFor)`, and `screens.generated.ts:289` declares `readonly emptyKey?: string` on `TableColumn`; the identical 3-arg pattern already ships unchanged in `areas/tasks/details.page.ts:245` and `shell/data-table.ts:461`.
  - `[medium]` `patch` Blind Hunter: `process-details.page.spec.ts`'s `'InTransaction reads Yes for non-zero and No for zero'` test never asserts the "Yes" branch — after `setRows([row({ InTransaction: 1 })])` it calls `detectChanges`/`settle` and ends with no further assertion. Grouped with the Edge Case Hunter and Intent Alignment rows below (same defect). Fix: trigger a real refresh (`actions.run(DESCRIPTOR, REFRESH_ACTION_ID)`) after `setRows` and assert `fieldValue(host, 'processDetailsInTransaction')` equals `STRINGS.tableStatusYes`, applied.
  - `[low]` `reject` Blind Hunter: `pid` criterion (`text`, `maxLength` 10, no digit-only constraint) is untested against a non-numeric value. The criterion shape is the intent-contract's own explicit requirement (mirrors `TaskDetails`' `taskId` and the Secrets list's parent-collection criterion), and the intent's 5-row I/O matrix is its own deliberately exhaustive edge-case set with no such row; no evidence of an actual 500 or vendor-forwarding defect.
  - `[false]` `reject` Blind Hunter: the `MemoryAllocated`/`MemoryPeak`/`MemoryUsed`/`CPUTime` labels claim units (KB, ms) allegedly unverified against the vendor — `irissys/%CSP/UI/Portal/ProcessDetails.cls:533-536` (the vendor classic page this screen mirrors) labels these meters with tooltips "Amount of memory (Kbytes)..." and "System+User CPU Time (ms)", confirming the shipped units exactly.
  - `[false]` `reject` Blind Hunter: "Memory limit" for `MemoryAllocated` allegedly mismatched vendor terminology — same vendor source, line 533: `BuildMeter($$$Text("Memory Limit"),"MemoryAllocated",...)` — the vendor's own label for this field is "Memory Limit" verbatim.
  - `[low]` `patch` Blind Hunter: `Install/Smoke.cls`'s `CheckProcessDetails` doc comment describes the failure guard as triggering "when the list read answers no row," but the code actually guards on the extracted `Pid` string being empty. Fix: reword the comment to name the actual guard, applied.
  - `[low]` `reject` Verification Gap: `Install/Smoke.cls:726-757` — the pid a smoke run keys the second read by could exit between the two reads. The chosen pid is the processes list's first (lowest-numbered, typically long-lived) row, making the real trigger window very unlikely, and a robust fix (retry/stability logic) is more than a direct correction.
  - `[false]` `reject` Verification Gap: the task list's "the browser legs of AC1-AC5" allegedly overstates coverage since AC5 is proven only via `WireSecurityRead` over HTTP, not the browser spec. AC5 is a denial-view requirement already proven server-side, matching this codebase's established pattern (other screens' denial paths are proven the same way); the underlying requirement is satisfied, only the task-list's shorthand wording invites the reading. Also barred outright: its only fix would edit this build's spec.
  - `[medium]` `patch` Verification Gap: `ui/tools/navigation-wire.test.mjs`'s `LIVE_PAYLOAD` (the `os-management` area's `screens` array) was not extended with the new `os-management/processes/details` entry the way 6.7 added `tasks/schedule/details` — the Code Map's "Rosters to extend" bullet names this file explicitly. Grouped with the `rail-wire.spec.ts` row below. Fix: add the entry ahead of `os-management/processes`, mirroring the `tasks/schedule/details` shape, applied.
  - `[medium]` `patch` Verification Gap: `ui/src/app/shell/rail-wire.spec.ts`'s `LIVE_PAYLOAD` has the same gap as the row above, also named explicitly by the Code Map. Fix applied the same way.
  - `[medium]` `patch` Edge Case Hunter: confirmed by direct code reading — `process-details.page.spec.ts`'s InTransaction test calls neither `actions.run(...)` nor `fireTick()` after `setRows`, so no new read is ever issued and the assertion is simply absent; the Rule-19 mutation this test's docblock claims it would catch ("Read `InTransaction` as zero for non-zero -> the transaction-word assertion goes red") cannot actually go red, since there is no such assertion. Same fix as the grouped Blind Hunter row, applied.
  - `[low]` `patch` Edge Case Hunter (other finding): the file's mutation-note doc comment says dropping `CurrentLineAndRoutine` from `EXECUTION_FIELDS` would redden "the AC1b assertion," but AC1b's test never references `CurrentLineAndRoutine` — that mutation is actually caught by `ui/tools/process-details-store.test.mjs`'s `groupFor` test. Fix: reword the comment to name the correct test, applied.
  - `[false]` `reject` Intent Alignment: EXPERIENCE.md's auto-refresh bullet (`:620`) allegedly not updated to include Process details — the line already lists "Process details" second in the roster of seven ("On Processes, Process details, Databases, Database details, Task schedule, Task details, System usage"), committed by an upstream stage before this story's `baseline_revision`, per the spec's own Design Notes ("Settled at the gate ... no task edits `:92` or `:620`").
  - `[false]` `reject` Intent Alignment: EXPERIENCE.md's Process details IA row (`:92`) allegedly not narrowed to what 6.8 ships — the row already reads the narrowed text ("whether a cached SQL query is executing (named by its routine; statement text is Story 19.10's)") on disk, from the same upstream commit the Spec Change Log's 2026-09-17 entry records.
  - `[false]` `reject` Intent Alignment: the intent's "SQL clause ... pending the lead" sentence allegedly has no corresponding artifact in the diff — the spec's Design Notes "Settled at the gate" entry records this as adopted and covered by AC1/AC1b through the `Routine` field, and AC1b's component-spec test (`process-details.page.spec.ts`) exercises exactly that.
  - `[medium]` `patch` Intent Alignment: same InTransaction Yes-branch gap noted as a "minor, same-shape gap." Grouped with the Blind Hunter and Edge Case Hunter rows above; same fix, applied.

## Design Notes

**Governing ADs:**

- AD-2, AD-26, AD-27: a synchronous `Process` GET through `AdminPort` only.
- AD-5, AD-8, AD-29: pairs from the backing class's checks, confirmed by a real principal.
- AD-11: every text value is untrusted. AD-24, AD-35, AD-48 (by analogy): the never-named fields.
- AD-13, AD-14 (entity `process`, scope `instance`), AD-19, AD-36 (6.7's parent-scoped GET grammar, unchanged).
- AD-37: an exited process reads as zero rows.
- AD-43 (roster of seven, Process details included) and AD-44 (ProcessDetails key, no link-out).

**Settled at the gate (2026-09-17, commit `581ddff4949732c6177fbb6f9891968525a0e137`):** the intent contract's "SQL clause … pending the lead" is adopted (AC1 amended, covered by AC1/AC1b through `Routine`); "AD-43's roster wording is the lead's" is done in the spine; the Always bullet on EXPERIENCE.md's auto-refresh bullet and IA row is already true, so no task edits `:92` or `:620`.

**Decisions:**

- **"Dashboard meters"** are the classic page's labeled value groups, no thresholds; 6.9 builds the meter component.
- **Never-named fields.** `Variables` and `CSPSessionID` are excluded outright; `CurrentSrcLine` (source with literals) and `LastGlobalReference` (subscripts can hold patient identifiers) are omitted, since `secretFields` also strips the screen and no screen-only field grammar exists. `UserInfo`, `Roles`, `LicenseUserId` are not asked for.
- **Id is `Pid`**, the list's own id; GET answers `Pid`, so `Read`'s seeding writes the same value.
- **The highlight tracker moves to `core/`** so the OS management slice imports no Tasks file.
- **Stable pids:** ObjectScript tests use their own `$J`; browser specs use the write daemon.

**Ledger inbox:** `slice 6-8-process-details` is empty. DW-1001 and DW-1018 are not re-filed.

**Integration ACs:** the Integration AC, plus AC1 and AC2 through the page against the throwaway.

**Consumes:** `AdminPort` (2.1), `Screen.Read` with the GET route-id grammar and `detailScreenFor` (6.7), the refresh framework (1.14), `cellView` (2.4), the gate (1.9).

**Consumed-by:** 6.10 (owner link opens this route), 7.8 and 5.12 (process actions and the terminate dialog, hosted here), 4.4 (screen context via `RouteEntityType`).

## Verification

Stateful steps run on the slot B throwaway `ocupilot-b-ci` only; `ocupilot-slot-b` is compiled into and read, never changed otherwise.

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: clean compile.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy. Teardown (only if this run's `up`): `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`: `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for ProcessDetails, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor, Smoke -- expected: green, totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: processdetails check passes, no failures.
- `cd ui && npm run build && npm test` -- expected: green, `screen-mirror --check` clean.
- From `ui/`: `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `processes.browser-spec.mjs` and `tasks.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations to record (Rule 19)**, each as `mutation: <change> -> <test red> (observed)`, tree byte-identical after:

- AC1: `ProcessDetails` `parentScope` emptied (bundle rebuilt and redeployed).
- AC1b: `Routine` dropped from the Execution group map.
- AC2: route id not passed to `parentCriteria`.
- AC3: the refresh binding omitted.
- AC4: 404 mapped to a fault.
- AC5: `%Admin_Manage:USE` dropped.
- Integration: `Variables` added to read fields.
- Transaction words: non-zero read as "No".

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
