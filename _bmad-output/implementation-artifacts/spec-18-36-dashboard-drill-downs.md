---
title: 'Story 18.36: Dashboard drill-downs'
type: 'feature'
created: '2026-10-11'
status: 'done'
baseline_revision: '587fdb80f3793d66b0c725ee1234cb5fdf92c3ab'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Dashboard (Story 16.7) shows meters only; its drill-down statistics and its busiest processes still need the classic portal.

**Approach:** Four read-only screens reached from the Dashboard's groups, each a declared read through `AdminPort` behind its own pairs: global and routine, ECP and system resource statistics, and the most active processes without the vendor's unused rows. Story 16.7 deferred busy processes with the drill-downs (its spec :103, :487).

## Boundaries & Constraints

**Always:** Each screen declares `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, checked in the caller's process (AD-8, AD-29). No row whose `Process` is `""` reaches a screen or a tool. One read serves each screen and its read tool (AD-36).

**Never:** A write tool, governance key, entity type, route, error code, side-bar entry, auto-refresh (AD-43) or listing logic (20.24). A read-grammar change (`Screen/Read.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`). The vendor's alerts read (AD-7). A `decision-pending` entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Resources | `GET /screens/osmgmt.resourcestatistics/read?maxRows=N` | at most N rows; `truncated` when the vendor answered N+1 | -- |
| Busy processes | vendor `BusyProcesses`: 2 rows and 8 `{"Process": "", "Commands": 0}` | the 2 rows, in vendor order | -- |
| Broken shape | a composed type's vendor answer of another shape | 500 `INTERNAL`, logged once | no rows |
| Pairs | without `%Admin_Operate:USE`, or `%DB_IRISSYS:READ`; or anonymous | 403 naming the pair; 401 | no vendor call |

</intent-contract>

## Code Map

Under `src/OcuPilot/` unless `ui/`, at HEAD 03eca55f.

- `Port/AdminPort.cls`: `Invoke` :1219; `LogFault` :1864; sibling grammar `HALVEDROWTYPES` :928 via `PairValue` :2874; no read answer is post-processed today.
- Client: `system-usage.page.ts` `counterViews` :190-203; `dashboard.store.ts` :73-138; `dashboard.page.ts` :91-154; link `journal-file-details.page.ts` :97-100, :332-346.
- Tests: `Test/Read/ReadFixture`, `PortFixture.SetEndpointClass`, `Test/ReadSource/Endpoint` (`Arm("byType", json, n)`); `Test/Dashboard.cls` :24-45; `ui/browser/dashboard.browser-spec.mjs` `atDashboard` :68-82; `list-spec.mjs` `waitForRows` :37.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; halt on a contradiction): record S0. (a) As `_SYSTEM`, `GET /api/admin/v2/monitor/dashboard/globals-and-routines`, `/ecp` and `/system-resources` answer Task 2's members. (b) `OcuProbe1836T0`, holding exactly `%Admin_Operate:U` and `%DB_IRISSYS:R`, gets 200 from them and `/main`; removed after. (c) `%SYS.Portal.Resources.NormalizePage` answers Task 2's classic keys for `/csp/sys/op/UtilSysStatisticsGlobal.csp`, `…ECP.csp`, `…Resource.csp`.

**Execution:**

1. `Port/AdminPort.cls`: `BARETYPES` (:1015) gains `Monitor/DASHBOARDGLOBALS,Monitor/DASHBOARDECP,Monitor/DASHBOARDRESOURCES`. New `Parameter COMPOSEDREADS = "Monitor/RESOURCEROWS=DASHBOARDRESOURCES,Monitor/BUSYPROCESSES=DASHBOARDMAIN"`: `Invoke` issues the named bare type for a composed one (before :1285) and, after a 2xx (:1425), answers `{"Resources": <the vendor's array>}` or `{"BusyProcesses": <SystemUsage.BusyProcesses' rows whose Process is not "", in order>}`; another shape is 500 `INTERNAL`, logged once (`LogFault`). Other types unchanged.
2. Four descriptors in `Screen/Descriptor/`: pairs as `Dashboard.cls`; scope `instance`, `entityType` "", id `none`, no actions, `sideBarPosition` 0, `refreshes` false; `refreshRates`, `commandAliases`, `secretFields` empty; context, read, filter and sort fields alike unless named, sort default the first asc; `emptyNextKey` `tableReadOnlyEmptyNext`.

   | Class | Route `os-management/` | `toolIdentifier` | Archetype | Source (admin, `Monitor`) | `classicPage` |
   |---|---|---|---|---|---|
   | `DashboardGlobals` | `global-statistics` | `osmgmt.globalstatistics` | `detail` | `GET`, parts `[{type: DASHBOARDGLOBALS, as: Statistics}]` | `%cspapp.op.utilsysstatisticsglobal` |
   | `DashboardEcp` | `ecp-statistics` | `osmgmt.ecpstatistics` | `detail` | `GET`, parts `[{type: DASHBOARDECP, as: Ecp}]` | `%cspapp.op.utilsysstatisticsecp` |
   | `DashboardResources` | `resource-statistics` | `osmgmt.resourcestatistics` | `list` | `RESOURCEROWS`, rows `Resources` | `%cspapp.op.utilsysstatisticsresource` |
   | `DashboardProcesses` | `active-processes` | `osmgmt.activeprocesses` | `list` | `BUSYPROCESSES`, rows `BusyProcesses` | `%cspapp.op.utildashboard` |

   Fields in vendor order, kind `number`, the first `name`: `Statistics.Globals.` RefLocal, RefUpdateLocal, RefRemote, RefUpdateRemote, RefPrivate, RefUpdatePrivate, LogicalBlocks, PhysBlockReads, PhysBlockWrites, WIJWrites, JrnEntries, JrnBlocks; `Statistics.Routines.` RtnCallsLocal, RtnFetchLocal, RtnCallsRemote, RtnFetchRemote, RtnCommands, RtnNotCached; `Ecp.AppServer.` MaxConn, ActConn, GloRef, ByteSent, ByteRcvd, BlockAdd, BlockBuffPurge, BlockSvrPurge, GloRefLocal, GloRefRemote, GloUpdateLocal, GloUpdateRemote, RoutineCallLocal, RoutineCallRemote, RoutineBuffLocal, RoutineBuffRemote; `Ecp.DataServer.` MaxConn, ActConn, GloRef, ByteSent, ByteRcvd, GloUpdate, ReqRcvd, ReqBuff, BlockSent, LockGrant, LockFail, LockQueGrant, LockQueFail, SvrBlockPurge, RoutinePurge, BigKill, BigString. Resources: Name, Seize, Nseize, Aseize, Bseize, BusySet; filter Name; default Seize desc. Processes: Process, Commands; filter Process; default Commands desc.
3. Client, `ui/src/app/`: `areas/os-management/statistics.page.ts` and `.store.ts` (new), mapped from `DashboardGlobals` and `DashboardEcp` in `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` (:202), read on open as `SystemUsagePage`; `aria-busy` and a skeleton until answered, then one `ocu-details-group` per field's second segment in declared order, headed through `STATISTICS_GROUPS` (`Globals` `processColumnGlobals`, `Routines` `explorerRoutineListLabel`, `AppServer` "Application server", `DataServer` `remoteDatabaseServer`), listing `stringFor(labelKey)` and `cellView().text`; a refused or failed read as `SystemUsagePage`. `dashboard.store.ts`: optional `drillDowns` per group, routes under `os-management/` (performance `global-statistics`, `resource-statistics`; ecp `ecp-statistics`; usage `active-processes`); `dashboard.page.ts` draws under the heading a `<nav class="ocu-details-links">` with an `ocu-details-link` per built target, labeled by its `labelKey`, href and click as the journal link.
4. `core/strings.ts`, add-only, `/** EXPERIENCE.md:375 */`; a literal a key already holds reuses it (Name `tableColumnName`; `processColumnPid`, `processColumnCommands`; LogicalBlocks, PhysBlockReads, PhysBlockWrites, JrnEntries, JrnBlocks and GloUpdate `systemUsage*`; MaxConn `licenseUsageMaxConnections`; GloRef `processDetailsGlobalReferences`). New, in field order: "Local global references", "Local global updates", "Remote global references", "Remote global updates", "Private global references", "Private global updates", "Write image journal writes"; "Local routine calls", "Local routine buffer loads and saves", "Remote routine calls", "Remote routine buffer loads and saves", "Routine commands", "Routines not in memory"; "Active connections", "Bytes sent", "Bytes received", "Blocks added to cache", "Blocks purged for buffers", "Blocks purged by the data server" (the eight local and remote ECP fields take the labels above of the same meaning), "Requests received", "Request buffers", "Blocks sent", "Locks granted", "Locks failed", "Queued locks granted", "Queued locks failed", "Block purges requested", "Routine purges sent", "Big kills", "Big strings"; "Seizes", "Nseizes", "Aseizes", "Bseizes", "Busy sets"; "Application server"; titles "Global and routine statistics", "ECP statistics", "System resource statistics", "Most active processes"; empty states "The instance answered no statistics." (both statistics screens), "The instance reports no system resources.", "No process reports executed commands."; three prompts a screen, two `promptGroupTroubleshooting` and one `promptGroupCapacity`, each a question the screen's figures answer. EXPERIENCE.md :375 in place (1044 lines): literals and roles, `[ADDED 2026-10-11 - Story 18.36]`. At most 55 new: 3134 to 3189 of 3400; stop past 3350. Then `cd ui && node tools/screen-mirror.mjs`.

**Tests** (each class under 500 lines; probes `OcuProbe1836*`):

5. `Test/ReadSource/Endpoint.cls`, add-only: `DASHBOARDECP` 10, `DASHBOARDGLOBALS` 11, `DASHBOARDRESOURCES` 13.
6. `Test/DashboardDrillDown.cls` (new): the four declarations as Task 2; through `ReadFixture`, both projections and the matrix's Resources, Busy processes and Broken shape rows (one `LogFault`); live, each read 200 with every declared field, processes at most ten rows, none with an empty `Process`.
7. `Test/DashboardDrillDownGate.cls` (new, armed by `OCUPILOT_ALLOW_PRINCIPALS`) with `Test/DashboardDrillDownProbe.cls` extending `SqlActivityProbe` (:188; `PRINCIPALPREFIX` `OcuProbe1836`): `Exact` (`%Admin_Operate:U,%DB_IRISSYS:R`), `NoOperate` (`%Admin_Manage:U,%DB_IRISSYS:R`) and `NoSys` (`%Admin_Operate:U`) read the four `GET /screens/<tool>/read?maxRows=10` as `DocDbAppGate.Wire` (:195): `200 `, `403 %Admin_Operate:USE`, `403 %DB_IRISSYS:READ`; anonymous 401; principals removed after. `scripts/ci-throwaway.sh` after :417, add-only: `# classes: DashboardDrillDownGate`.
8. Client: `statistics.page.spec.ts` (new): groups, labels, values, skeleton. `dashboard.page.spec.ts`: the links and hrefs; none for an unbuilt target. `ui/browser/dashboard-drill-downs.browser-spec.mjs` (new), each test first at `atDashboard`'s signal: follow each link; statistics pages answer (no `[aria-busy="true"]`) with their groups; resources `waitForRows`; processes rows with no empty Process ID, or the empty state; the side bar lists none.
9. **Rule 30 sweep** (each changed file joins the loop): `ReadTool` :93 (350 to 354), :94 (four names, sorted); `SurfaceCoverage` `Coverage` :54 and `Descriptor` `ReadShapes` :67, four rows each; `Navigation` :494 (46 to 50) and its per-index assertions; `ui/tools/navigation.test.mjs` :139 (the four lead OS management's unlisted block, by class name); `Wire` :742-766 and `WireSecurityRead` :611, :618, :621 where they list OS management's screens. Run, editing only if red: `ToolRoundTrip`, `ToolDispatch`, `ToolEmit`, `Dashboard`, `DashboardLive`, `SystemUsage`, `WireAreaAnyScreen`, the client tiers. Unchanged (no port, no tool): entity types (70), `PortGate`, `ClassicPageGate`, `MappingDescriptor`, `field-lists`.

**Acceptance Criteria:**

- **C1.** Given `ocupilot-ci`, when the four reads run, then each statistics screen answers one row of its fields, resources are cut at the cap, and processes are at most ten rows, none with an empty `Process`.
- **C2.** Given canned vendor answers, when the reads answer over them, then the matrix's Resources, Busy processes and Broken shape rows hold.
- **C3.** Given the gate's principals, when each reads the four screens, then the matrix's Pairs row holds and the exact holder reads them (AD-29).
- **C4.** Given the browser on the Dashboard, when a person follows the Performance, ECP and System usage groups' links, then each screen opens and answers, and the side bar lists none of them.
- **Integration.** Given `ocupilot-ci`, when the agent's four read tools run through dispatch with `{}`, then each conforms to its result schema within the row bound (`ToolRoundTrip`), and the pages consume the same reads (C4).

## Spec Change Log

## Review Triage Log

### 2026-10-11 - Review pass

- verdicts: 15 findings - high 0, medium 1, low 9, false 2, maybe-false 3
- findings:
  - `[medium]` `[patch]` Labels of the two statistics screens pinned for 12 of 51 fields, the rest compared with the descriptor's own keys - `statistics.page.spec.ts` now asserts every field, label and value in declared order against a table written in the spec; swapping two ECP lock labels in the mirror reddens it.
  - `[low]` `[patch]` The four `emptyStateKey` values were not pinned - one assertion per screen in `TestTheFourDeclarations`; `DashboardResources` set to another key reddens it.
  - `[low]` `[patch]` Only the Ctrl-click branch of the drill-down link handler was tested - the test now dispatches Ctrl, Meta, Shift and a non-primary button.
  - `[low]` `[patch]` Rule 19 lines missing for the element check, the empty-state pin and the label table - three `mutation:` lines added, each observed red and reverted.
  - `[low]` `[reject]` Pinning-test legs beyond one per AC carry no recorded mutation (the exact-holder, `NoSys` and anonymous legs, the Globals, Resources and processes links, the DW-1337 leg) - Rule 19 asks one demonstrated mutation per AC, and each AC has one; not worth a per-leg demonstration.
  - `[low]` `[reject]` `rows.%Size() <= 10` and the per-row `Process` loop pass for zero rows - the Matrix names exactly this bound, and the recorded busy-process mutation reddens it because the vendor pads the list; an empty list is a legitimate answer.
  - `[low]` `[patch]` The browser spec's `every` over a group's values passes for none - it now asserts a value beside every label first.
  - `[false]` `[reject]` The `built` flip on the shared `SCREENS` object leaks - it is restored in `finally` and vitest runs one file's tests in sequence.
  - `[low]` `[reject]` The live legs need at least four resources and a readable process list - inherent to a live read; C1 asserts the instance's own answer.
  - `[low]` `[patch]` The resources browser test said five headers and asserts six - title and header comment corrected.
  - `[maybe-false]` `[reject]` The Matrix is worded at the wire while the fixture legs run `Screen.Read.Execute` (cap, shapes, 500, log count) - Task 6 names `ReadFixture`; the route and the tool share that one read (AD-36), the route is unchanged, and the gate class reads all four through the route; a defect would be low.
  - `[maybe-false]` `[reject]` "No vendor call" on a refused principal is asserted nowhere - the refusal is the generic gate this story does not change; low and the fix is a new counter seam, and a defect there would be low.
  - `[low]` `[patch]` The busy-process fixtures are already in Commands-descending order, so "vendor order" cannot fail - the second case now answers 6 before 5 (neither process nor commands order).
  - `[maybe-false]` `[reject]` "Logged once" counts the fixture port's `LogFault`, not the production one - every AdminPort fault test counts there, and the production call site is the same line, and a defect would be low.
  - `[false]` `[reject]` Drill-down links are filtered on `built`, never on the caller's pairs - the links draw only inside the Dashboard, which declares the same two pairs, so a caller refused them never sees the page.

## Design Notes

**Read on `ocupilot` and in vendor source** (2026-10-11, read-only): `%Api.Admin.Endpoints.Monitor` declares `DASHBOARDECP` 10, `DASHBOARDGLOBALS` 11, `DASHBOARDMAIN` 12, `DASHBOARDRESOURCES` 13 behind `ResourcesOR()` `%Admin_Operate`, answering Task 2's members; `RunResources`' array honors `%request.Data` `maxRows`. The classic keys are compiled `%CSP.Util.AutoPage` classes. Labels follow `irissys/SYS/Stats/{Global,Routine,ECPAppSvr,ECPDataSvr}.cls`. Inferences: which route issues which type (Task 0 (a)); the classic dashboard draws busy processes; the new types read cumulative counters and keep no baseline, so AD-7 gains no shape.

**Composed types, not grammar:** `Screen/Read.cls` declares neither a top-level array (`RowsMember` :943) nor a nested `rows` member; two port-composed types answer AD-36's "one object holding row arrays", so no registry changes.

**Rule 31.** Extended: `BARETYPES`, `HALVEDROWTYPES`' grammar, `Dashboard.cls`'s parts, `LicenseProcessTab`'s rows read, `SqlActivityProbe`, `ReadSource.Endpoint`, the journal link. Copied: `SystemUsagePage.counterViews` (fifteen lines); a generic System usage page would tie its seven meters to two other screens.

**Governing ADs:** AD-2, 5, 7, 8, 13, 22, 24, 27, 29, 36, 39, 43, 44. **Integration ACs:** the Integration line. **Consumed-by:** 18.12 (every Stage 2 read tool). **Consumes:** 16.7 (the Dashboard, `source.rows`), 6.9 (`parts`, `BARETYPES`), 19.10 (`SqlActivityProbe`). **Ledger inbox:** empty.

**For the lead** (Rule 20):

- AD-36: "`AdminPort` answers two composed read types (Story 18.36), each read over one member (`source.rows`): `Monitor` `RESOURCEROWS`, `DASHBOARDRESOURCES`' array, and `BUSYPROCESSES`, `DASHBOARDMAIN`'s `SystemUsage.BusyProcesses` less rows whose `Process` is empty."
- AD-44: Task 2's four `classicPage` keys.
- 18.11 (planned): rosters union at the merge (`ReadTool` 355, `Navigation` 51).
- Rule 11: `ReadTool` :93 and :94 are token edits in an Epic 20 file; implement makes them only with the orchestrator's pre-authorization at the spec gate, as for 18.11. Other shared edits are add-only.
- No new vendor defect candidate (the padded rows are the owner's DC-article item).

## Verification

**Shared surfaces:** OS management's built screens (46 to 50) and their navigation and wire rosters; the read tools (350 to 354), `SurfaceCoverage`, `ReadShapes`; `BARETYPES`; the Dashboard's groups; Fixed strings; `screens.generated.ts`; the arming roster.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: `DashboardDrillDown`, `DashboardDrillDownGate` and each class Task 9 edits or runs.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/dashboard-drill-downs.browser-spec.mjs browser/dashboard.browser-spec.mjs` and any spec the sweep changes. Bundle vs the 3487kB warning: re-base under DW-1166 if crossed; stop above 3800kB.
- Full ObjectScript sweep: the runner's; browser suite: CI's.

**Mutations (Rule 19)**, each `mutation:` recorded once observed (descendants recompiled or bundle redeployed): C1 `BARETYPES` without `DASHBOARDGLOBALS` (`DashboardDrillDown` live, 501); C2 `BUSYPROCESSES` keeping empty rows, then `RESOURCEROWS` answering the bare array (fixture legs); C3 `DashboardResources` without `%Admin_Operate:USE` (gate's `NoOperate` leg); C4 the ecp group without `drillDowns` (`dashboard.page.spec.ts`, browser spec); one flat list (`statistics.page.spec.ts`); Integration `COMPOSEDREADS` without `BUSYPROCESSES` (`ToolRoundTrip`).

- mutation: `BARETYPES` without `DASHBOARDGLOBALS` -> `DashboardDrillDown` `TestTheFourReadsAnswerLive` (live, 501 `PORT.NOTIMPLEMENTED`) and `TestTheStatisticsScreensProjectOneRow`.
- mutation: `BUSYPROCESSES` keeping empty rows -> `DashboardDrillDown` `TestBusyProcessesDropThePaddedRows` and `TestTheFourReadsAnswerLive`.
- mutation: the composed answers returning the bare array -> `DashboardDrillDown` `TestResourcesAreCutAtTheCap`, `TestBusyProcessesDropThePaddedRows` and `TestTheFourReadsAnswerLive`.
- mutation: `DashboardResources` without `%Admin_Operate:USE` -> `DashboardDrillDownGate` `TestEachMissingPairIsRefusedByName` (the `NoOperate` leg) and `DashboardDrillDown` `TestTheFourDeclarations`.
- mutation: `COMPOSEDREADS` without `BUSYPROCESSES` -> `ToolRoundTrip` `TestEveryToolConformsToItsResultSchemaOrAnswersACode` (`osmgmt.activeprocesses.read`).
- mutation: the ecp group without `drillDowns` -> `dashboard.page.spec.ts` (three tests) and `dashboard-drill-downs.browser-spec.mjs` (the ECP leg, bundle rebuilt and redeployed).
- mutation: one flat list in `statistics.store.ts` -> `statistics.page.spec.ts` (four tests).
- mutation: `DashboardResources` `emptyStateKey` set to `statisticsEmpty` -> `DashboardDrillDown` `TestTheFourDeclarations`.
- mutation: the element check skipped in `AdminPort.ComposedAnswer` -> `DashboardDrillDown` `TestAnAnswerOfAnotherShapeFailsTheReadOnceLogged`.
- mutation: `statsEcpLocksGranted` and `statsEcpLocksFailed` swapped in the mirror -> `statistics.page.spec.ts` (the every-field test).

**S0:** no `OcuProbe1836*` user or role.

## Auto Run Result

Status: done
Blocking condition: none

Summary: four read-only drill-down screens reached from the Dashboard's groups. `AdminPort` gained three bare `Monitor` types and the `COMPOSEDREADS` parameter (`RESOURCEROWS`, `BUSYPROCESSES`; padded rows dropped, another shape a logged 500); four descriptors; a statistics page for the two counter screens; drill-down links on the Dashboard; 54 new strings; rosters unioned (`ReadTool` 360, `Navigation` 51, `SurfaceCoverage`, `Descriptor`, `navigation.test.mjs`, `Wire`, `WireSecurityRead`).

Files: `src/OcuPilot/Port/AdminPort.cls`; `src/OcuPilot/Screen/Descriptor/Dashboard{Globals,Ecp,Resources,Processes}.cls`; `src/OcuPilot/Test/DashboardDrillDown{,Gate,Probe}.cls`; roster edits in `Test/{ReadTool,SurfaceCoverage,Descriptor,Navigation,Wire,WireSecurityRead,PortFixture}.cls` and `Test/ReadSource/Endpoint.cls`; `scripts/ci-throwaway.sh` (one arming line); `ui/src/app/areas/os-management/{statistics.page,statistics.store,dashboard.page,dashboard.store}.ts` with specs; `shell/screen-outlet.ts`; `core/strings.ts`; `core/screens.generated.ts` (regenerated); `ui/tools/{dashboard-store,navigation,side-bar-pins}.test.mjs`; `ui/browser/dashboard-drill-downs.browser-spec.mjs`, `dashboard-spec.mjs` (shared `atDashboard`), `dashboard.browser-spec.mjs`; EXPERIENCE.md :375 in place.

Review: 15 findings; patches applied 7 (1 medium, 6 low), rejected 8 with the reasons in the log, deferred 0. Follow-up review recommended: false (no high patched, one medium).

Verification: Task 0 passed on `ocupilot-ci`; `DashboardDrillDown` 6 tests (run 672) and `DashboardDrillDownGate` 3 tests (run 669) green, plus the Task 9 classes (runs 653-667); `test:tools` 1911, `test:components` 2895 in 231 files, `check-objectscript` 0 problems, `lint-docs` clean; browser `dashboard-drill-downs` 5 and `dashboard` 3 green on a rebuilt, redeployed bundle (3.35 MB initial, under the 3487 kB warning); Fixed strings 3214 spans, 3191 distinct (bound 3400); ten mutations observed red and reverted; S0 holds.

Residual risks: ECP statistics draws its 33 fields in one column (cosmetic); on an idle instance Most active processes usually shows its empty state; `ReadTool`, `Navigation`, `strings.ts`, `screens.generated.ts`, `screen-outlet.ts`, EXPERIENCE.md and `ci-throwaway.sh` are also edited on Epic 20's branch and union at the merge.
