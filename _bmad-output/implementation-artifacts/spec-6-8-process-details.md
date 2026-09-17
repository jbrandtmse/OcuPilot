---
title: 'Process details'
type: 'feature'
created: '2026-09-17'
status: 'blocked'
baseline_revision: 'd1a3340cf5a197c9f215b02d26d835475f9e0260'
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
  - `ObjToJson` answers the keys above. `LoginRoles`, `EscalatedRoles`, `Roles` and `OpenDevices` are arrays. `StartTimeUTC` is `YYYY-MM-DD HH:MM:SS`. It has no `ElapsedTime` and no SQL table or statement.
  - It also runs `SYS.Process:VariableByPid` into `Variables` (vendor cap 1,000 rows, `ClassQuery.GetMaxRows`).
  - `ResourcesOR` is `%Admin_Operate`. `%SYS.ProcessQuery.AllowToOpen` (`irissys/%SYS/ProcessQuery.cls:423`) admits IRISSYS read. `VariableByPid` (`:1494`) requires `%Admin_Manage:USE` or IRISSYS write.
- **Classic page** `irissys/%CSP/UI/Portal/ProcessDetails.cls`: `RESOURCE %Admin_Operate`, auto-refresh (`OnDrawRibbon :236`), and the "dashboard meters" are the `HTMLDashboardPane` value groups (`GetDetailPane :457-558`: General Information, Execution Details, Client Application Details). The "SQL table & statement info" toggle adds only `LastSQLReference` from `SYS.Metrics.GetSQLProcessMetrics`, a table name rather than a statement.
- **Precedents:**
  - `Screen/Descriptor/TaskDetails.cls` (whole shape) and `ProcessList.cls` (pairs rationale, `:40-65`; its Pid-cell comment `:15-18` becomes stale).
  - `Test/TaskDetails.cls` (matrix and integration tests). `Test/WireSecurityRead.cls:482-515` (`OPERATEUSER`, `PROCESSUSER` principals).
- **Client:** `areas/tasks/details.page.ts` and `details.store.ts` (`TaskDetailsHighlights :183`, `changedFields :170`); `shell/screen-outlet.ts` `DESCRIPTOR_PAGES :75`; `core/navigation.ts` `detailScreenFor`/`parentListFor` (built in 6.7, unchanged); `core/table-model.ts` `cellView :71`; `shell/locator-bar.ts` (names a parent-scoped detail by its first `name` column: the pid).
- **Rosters to extend** (6.7's list, same files): `Test/ReadTool.cls:94,100,263`, `Test/Wire.cls`, `Test/Descriptor.cls`, `Test/ScreenRead.cls`, `Install/Smoke.cls:62` (+ `Test/Smoke.cls`), `navigation.test.mjs`, `screen-mirror.test.mjs:603`, `navigation-wire.test.mjs` and `shell/rail-wire.spec.ts` `LIVE_PAYLOAD`s, `strings.test.mjs`, `classic-links.test.mjs` (count unchanged).
- **UX:** EXPERIENCE.md `:92` (IA row), `:620` (auto-refresh roster), last Fixed strings row (after the Task details row).
- **Browser:** `ui/browser/processes.browser-spec.mjs` (`DAEMON_ROUTINE :51`, `readDaemonPid :88`).

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Screen/Descriptor/ProcessDetails.cls` (new) -- the declaration above. The class doc gives the vendor semantics, the never-named fields and why, the pair set, and the route entity type. Refresh `ProcessList.cls`'s stale Pid-cell sentence.
- [ ] `ui/src/app/core/detail-highlights.ts` (new), `areas/tasks/details.store.ts`, `details.page.ts` -- move the highlight tracker. Its tests move with it.
- [ ] `ui/src/app/areas/os-management/process-details.store.ts`, `process-details.page.ts`, `process-details.page.spec.ts` (new), `shell/screen-outlet.ts` -- the page, the groups and the transaction words. Pin the store in `ui/tools/process-details-store.test.mjs`.
- [ ] EXPERIENCE.md, `core/strings.ts`, `tools/strings.test.mjs`:
  - Append one Fixed strings row: "Process details" · "This process no longer exists." · "General" · "Execution" · "Client application" · "Parent process ID" · "Login roles" · "Escalated roles" · "OS user" · "CPU time (ms)" · "Global references" · "Private global references" · "Private global blocks" · "Memory limit (KB)" · "Memory peak (KB)" · "Memory used (KB)" · "Current device" · "Open devices" · "In transaction" · "Source location" · "Location" · "Client name" · "Client executable" · "Client IP address".
  - Reuse existing keys wherever the value already exists: Process ID, User, Namespace, Priority, Routine, State, Commands, and "Started" (`taskHistoryColumnStarted`) for `StartTimeUTC`.
  - Amend `:92` and `:620` for auto-refresh, and regenerate the mirror.
- [ ] `src/OcuPilot/Test/ProcessDetails.cls` (new; HTTP, `_SYSTEM`) -- validation with `AreaCoverageProblem` empty, and `RouteEntityType` answering `process`. Cover the matrix rows Live, Gone, No id and Bad id, plus the Integration AC.
- [ ] `src/OcuPilot/Test/WireSecurityRead.cls` -- the Pairs row with the existing principals.
- [ ] Code Map rosters:
  - Smoke gains an `osmgmt.processdetails` read keyed by the first `osmgmt.processes` row's `Pid`, and passes on exactly one row whose `Pid` matches.
  - `navigation.test.mjs` pins `detailScreenFor(processes)` = ProcessDetails.
- [ ] `ui/browser/processes.browser-spec.mjs` -- the AC legs below, against the write daemon.

**Acceptance Criteria:**

- Given Processes on the throwaway, when the write daemon's Pid cell is activated, then the URL is `/ocupilot/os-management/processes/details/<pid>`, one `osmgmt.processdetails` read is issued, and the page shows the General, Execution and Client application groups with Process ID `<pid>`, Routine `WRTDMN`, and Open devices text.
- Given a cold deep link to that route with the write daemon's pid (the route the Locks owner link will open, Story 6.10), when it loads, then that process is shown and the locator bar's screen segment links back to Processes.
- Given the refresh chip at 5 s, when a tick fires, then the process is re-read with no skeleton and no announcement, and a changed field carries the highlight class (component spec with a fake tick; the browser leg asserts no skeleton after a tick).
- Given a pid that has exited, when the route opens, then "This process no longer exists." shows and no refusal renders.
- Given a principal lacking `%Admin_Manage:USE`, when it opens the deep link, then the denied view names that pair and no read is issued.
- Integration: given the tool `osmgmt.processdetails.read` with the test's own `$J`, when called in process, then it answers the row the screen's read answers for the same pid over the declared fields, with no `Variables` key.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-26 and AD-27: a synchronous `Process` GET through `AdminPort` only.
- AD-5, AD-8 and AD-29: the pair set is taken from the backing class's checks and confirmed with a real principal.
- AD-11: every text value is untrusted.
- AD-13, AD-14 (entity type `process`, scope `instance`), AD-19, AD-24, AD-35 and AD-36 (6.7's GET grammar, reused unchanged; no new shape).
- AD-37: an exited process reads as zero rows.
- AD-43 (roster, below) and AD-44 (ProcessDetails, no link-out).

**Intent gap -- the SQL clause (blocking).** AC1 asks for "the current SQL statement where the instance makes it available".

- **Evidence:** no admin API endpoint carries statement text, and `Process` GET carries none (probed on slot B; the 70 `%Api.Admin.Endpoints.*` classes list none for SQL). The classic toggle shows only `LastSQLReference`, a table name from `SYS.Metrics`, which GET also lacks. Statement text lives in `INFORMATION_SCHEMA.CURRENT_STATEMENTS`, which no port reaches. Epics.md Story 19.10 (SQL activity, catalog OS-23) owns that screen.
- **Readings with different outcomes:**
  - (a) Show nothing for SQL on 2026.2. This is vacuous.
  - (b) Add a statement source, which needs a new port or source kind (an AD-36 and paradigm amendment), a pair set to establish, and a decision on whether statement literals, which can hold patient data, enter context.
  - (c) Show what GET does carry: a process running SQL names its cached query in `Routine` (`%sqlcq.*` or `%SYS.sqlcq.*`, observed), and the statement text is deferred to 19.10.
- **Recommended amendment (c).** Epics.md 6.8 AC1: "…open devices, and whether the process is executing a cached SQL query, named by its routine; the statement text is Story 19.10's." This narrows an AC, so it is Rule 5 ask-first. The contract above is written to (c) and needs no other change.

**Decisions for the gate:**

- **AD-43 roster (Rule 20).** Recommend: "The set is seven: Processes, Process details, Databases, Database details, Task schedule, Task details, System usage", with EXPERIENCE.md `:620` and `:92` amended to match. Evidence the AC intends it: the classic page auto-refreshes (`OnDrawRibbon`), catalog OS-08 marks it, and `reconcile-catalog.md` G-13 records FR-7 omitting it as a low gap. Process metrics change with no write behind them.
- **"Dashboard meters"** are the classic page's `HTMLDashboardPane` value groups, labeled values with no thresholds, so no meter component is built here. 6.9 builds the threshold meter from `EnsembleMonitor`. EXPERIENCE.md `:405` listing Process details as a meter consumer is then stale (inference that it meant these groups), and the lead may drop Process details there.
- **Never-named fields (AD-24, AD-35, AD-11).** `Variables` and `CSPSessionID` are excluded outright. `CurrentSrcLine` (source text with literals) and `LastGlobalReference` (subscripts can hold patient identifiers on IRIS for Health) are omitted rather than shown. `secretFields` strips from the screen too, and no screen-only field grammar exists (AD-48's split is a port's, not a descriptor's). Neither is in the AC. `UserInfo`, `Roles` and `LicenseUserId` are omitted as not asked for.
- **Id is `Pid`**, the list's own id. GET answers `Pid` itself, so `Read`'s seeding writes the same value.
- **The highlight tracker moves to `core/`** so the OS management slice does not import the Tasks slice.

**Ledger inbox:** `slice 6-8-process-details` is empty. DW-1001 (derived tool describes the required `pid` as optional) and DW-1018 are not re-filed.

**Integration ACs:** the Integration AC, plus AC1 and AC2 through the page. The Locks owner link is 6.10's; this story pins the route it will open.

**Consumes:** `AdminPort` (2.1), `Screen.Read` with the GET route-id grammar and `detailScreenFor` (6.7), the refresh framework (1.14), `cellView` (2.4), and the gate (1.9).

**Consumed-by:** 6.10 (owner link opens this route), 7.8 and 5.12 (process actions and the terminate dialog, hosted here), 4.4 (screen context via `RouteEntityType`), and 19.10 (a statement link, if amended as recommended).

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: a clean compile. Slot B is compiled into and read only.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy. Every principal and every state-creating step lives on this slot B throwaway only. Teardown: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`, run `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for ProcessDetails, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor and Smoke -- expected: green, totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: the processdetails check passes, with no failures.
- `cd ui && npm run build && npm test` -- expected: green, and `screen-mirror --check` clean.
- From `ui/`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `processes.browser-spec.mjs` and `tasks.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations to record (Rule 19)**, each as `mutation: <change> -> <test red> (observed)`, tree byte-identical after:

- AC1: `ProcessDetails` `parentScope` emptied (bundle rebuilt and redeployed).
- AC2: route id not passed to `parentCriteria`.
- AC3: the refresh binding omitted.
- AC4: 404 mapped to a fault.
- AC5: `%Admin_Manage:USE` dropped.
- Integration: `Variables` added to read fields.
- Transaction words: non-zero read as "No".

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- Story 6.8 AC1's "the current SQL statement where the instance makes it available" cannot be met through the admin API (no endpoint or `Process` GET key carries statement text; statement text lives only in `INFORMATION_SCHEMA.CURRENT_STATEMENTS`, which no port reaches). Recommended amendment (Rule 5, ask-first, it narrows an AC): "...open devices, and whether the process is executing a cached SQL query, named by its routine; the statement text is Story 19.10's." The intent contract is already written to that amendment; on acceptance reset `status` to `draft` and re-dispatch. Alternatives and evidence under Design Notes.
