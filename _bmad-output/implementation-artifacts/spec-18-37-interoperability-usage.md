---
title: 'Story 18.37: Interoperability usage'
type: 'feature'
created: '2026-10-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-18-11-monitoring-extras-and-the-live-log-tail.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic Interoperability Usage page has no OcuPilot equivalent, and the catalog row's source, the deprecated `/api/monitor/interop`, adds `%All` with no caller check, failing AD-8.

**Approach:** An OS management tab group (Interfaces, Message volume, Database impact), each a read-only `monitor` read behind `MonitorPort`'s gate, answered by the classic page's class queries in `%SYS`.

## Boundaries & Constraints

**Always:** `MonitorPort`'s gate (`%Admin_Operate:USE`, `%DB_IRISSYS:READ`) runs in the caller's process before any vendor call (AD-29); the queries run through `%ResultSet`, as the classic page's do, in `%SYS` (AD-16) as the signed-in user, the vendor's own elevation the only one (AD-8). One read per tab and tool (AD-36).

**Never:** Call `/api/monitor/interop`, `SYS.Monitor.SAM.Sensors`' interop methods or a vendor `Consolidate*`, `Purge*`, `Record*`, `Cleanup*` or `Set*`. Add a write tool, governance key (AD-22), entity type, route, error code, criteria, auto-refresh or client page. Edit `Port/InteropPort.cls` or an Interoperability screen. Build on a `decision-pending` entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Exact holder | a tab's read, holding the two pairs | 200, rows of its fields | -- |
| Missing pair | without either pair; or anonymous | 403 naming the pair; 401 | no vendor query |
| Totals row | an Interfaces row, `Namespace` and `Protocol` `""` | kept `""`; the cell reads "All" | -- |
| Nothing recorded | no production has run | `rows` `[]`; the empty state | -- |
| Vendor fault | a query raises or errs | 500 `INTERNAL`, logged once | no rows |

</intent-contract>

## Code Map

Under `src/OcuPilot/` unless `ui/`, at `54af93be`.

- `Port/MonitorPort.cls`: `PAIRS` :30, `Invoke` :153, `Gate` :200, `Take` :216 (`%SYS` switch), `Fail` :469; seams via `Test/MonitorPortFixture`.
- Read path (code unchanged): `Screen/Read.cls` :597-606 (endpoint, `maxRows` cap + 1); `Test/Read/ReadFixture` :14 routes it to the fixture.
- Vendor (`%SYS`, read on `ocupilot`): the classic page (`RESOURCE` `%Admin_Operate`) reads `InteropInterfaces` (deployed, no source) and the `[Internal]` Messages and DatabaseImpact queries, whose `Fetch` adds `%DB_IRISMETRICS` only after `$system.Security.Check("%Admin_Operate","USE")`: AD-8 stands as written. Zen runs class queries through `%ResultSet` (`%ZEN.Component.querySource` :147-160). The deprecated API's setters (`%SYS.Ensemble` :771-1160) add `%All` unchecked.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; record S0 and whether a production runs; halt on a contradiction):

- (a) As `_SYSTEM`, Task 1's queries: columns, rows, a sample, time.
- (b) `$ZCRC` every `^IRIS.Metrics*` node before and after each query; a change halts `blocked` naming it (a seventh AD-7 shape, the lead's).
- (c) Jobs signed in as `OcuProbe1837T0` (`%Admin_Operate:U,%DB_IRISSYS:R`) and `OcuProbe1837T0No` (`%Admin_Manage:U,%DB_IRISSYS:R`) (Task 8's `InteropUsageProbe`, written first) run the queries directly (scratch class, deleted after): rows, `<PROTECT>` or SQLCODE. The first must answer as (a), else halt. If the second reads `InteropInterfaces` rows, the vendor escalates unchecked: halt `intent gap` (AD-8, the owner's): (A) keep the tab, AD-8 naming OcuPilot's gate as the check, or (B) ship two tabs; recommend (A): the classic page's audience and call.
- (d) `NormalizePage` of the classic URL answers `%CSP.UI.Portal.InteroperabilityUsage`. Remove (c)'s objects; confirm S0.

**Execution:**

1. `Port/MonitorPort.cls`: `Parameter ENDPOINTS = "Metrics,Interfaces,MessageVolume,DatabaseImpact"` (`ENDPOINT` stays); the maxRows check (:165) covers every `TYPELIST` endpoint. The new three answer a private `Usage`: in `%SYS` (restored first in `Catch`) it calls `UsageSource`, then types each raw row's fields, at most `maxRows`; a raise or error status is 500 `INTERNAL`, logged once (`Fail`), no rows. Overridable `UsageSource(pEndpoint, pMax, Output pRows)` (`$NAMESPACE` is `%SYS`): `%ResultSet.%New("<class>:<query>")`, `Execute(<arguments>)`, `Next(.tSC)` up to `pMax`, `{column: Get(column)}` per row.

   | Endpoint | Class query | Arguments | Fields |
   |---|---|---|---|
   | `Interfaces` | `SYS.Monitor.Interop.Interface.Utils:InteropInterfaces` | `"","","","","",1,1,1,0` | `Type`, `Namespace`, `Protocol` text; `Active` boolean; `Count` number |
   | `MessageVolume` | `%SYS.Monitor.Interop.Messages.Utils:MetricsTotalPerNamespace` | `"","",""` | `Namespace`, `Type` text; `Volume` number |
   | `DatabaseImpact` | `%SYS.Monitor.Interop.DatabaseImpact.Utils:Impact` | `$ZDATETIME(0,3)`, `$ZDATETIME(2980013,3)`, `""` | `Database` text; `DataCreated` number |

2. `Screen/Registry.cls` :1282-1300 and `ui/tools/screen-mirror.mjs` :1083-1100, :1422-1439 (`monitorEndpoints()` via the interop arm's `parseInteropEndpoints` :1105) admit any of `ENDPOINTS`, with identical sentences: "read.source.endpoint '<e>' is not one of the monitor port's endpoints ('Metrics', 'Interfaces', 'MessageVolume', 'DatabaseImpact') (AD-29)"; "read.source.type '<t>' is declared on a monitor source, which lists the instance's metrics and interoperability usage (AD-36)"; "read.source.<key> is declared on a monitor source, which answers its list whole (AD-36)". `Screen/Read.cls` docs :39, :296 likewise.
3. Three `Screen/Descriptor/` classes as `LicenseProcessTab`: `os-management`, `detail`, built, no refresh; privileges `MonitorPort.PAIRS`; `instance`, `entityType` `""`, id `none`, no actions; context = read fields; `classicPage` `%CSP.UI.Portal.InteroperabilityUsage`; prompts `interopUsagePrompt1`-`3` (`promptGroupCapacity`); read `{port: monitor, endpoint, type: LIST}`, `cap`, note `interopUsageNote`; `emptyNextKey` `tableReadOnlyEmptyNext`; tab group `os-management/interoperability-usage`; the first's aliases `interoperability usage`, `interop usage`.

   | Class (route under `os-management/`, tool) | Label; tab position; side bar | Endpoint | Columns (field kind labelKey) | Filter; default sort | Empty state |
   |---|---|---|---|---|---|
   | `InteropUsageTab` (`interoperability-usage`, `osmgmt.interopusage`) | `interopUsageLabel`, tab `interopUsageInterfacesTab`; 1; 22 | `Interfaces` | Type name `tableColumnType`; Namespace identifier `headerNamespaceLabel`; Protocol text `interopUsageColumnProtocol`; Active status `interopColumnActive`; Count number `interopColumnCount`; Namespace and Protocol `emptyKey` `interopUsageAll` | Type, Namespace, Protocol; Type asc | `interopUsageInterfacesEmpty` |
   | `InteropUsageVolumeTab` (`interoperability-usage/volume`, `osmgmt.interopvolume`) | `interopUsageVolumeLabel`; 2; 0 | `MessageVolume` | Namespace name `headerNamespaceLabel`; Type text `tableColumnType`; Volume number `interopItemTabMessages` | Namespace, Type; Volume desc | `interopUsageVolumeEmpty` |
   | `InteropUsageImpactTab` (`interoperability-usage/impact`, `osmgmt.interopimpact`) | `interopUsageImpactLabel`; 3; 0 | `DatabaseImpact` | Database name `systemInfoDatabase`; DataCreated number `interopUsageColumnDataCreated` | Database; DataCreated desc | `interopUsageImpactEmpty` |

4. Strings, add-only, `/** EXPERIENCE.md:603 */`: `interopUsageLabel` "Interoperability usage", `interopUsageInterfacesTab` "Interfaces", `interopUsageVolumeLabel` "Message volume", `interopUsageImpactLabel` "Database impact", `interopUsageColumnProtocol` "Protocol", `interopUsageColumnDataCreated` "Data created (MB)", `interopUsageAll` "All", `interopUsageInterfacesEmpty` "The instance has recorded no interoperability interfaces.", `interopUsageVolumeEmpty` "The instance has recorded no message volume.", `interopUsageImpactEmpty` "The instance has recorded no database impact from message activity.", `interopUsageNote` "Counts cover all the usage data the instance still keeps, with no date range.", `interopUsagePrompt1` "How many interoperability interfaces are active, and in which namespaces?", `interopUsagePrompt2` "Which namespace has sent and received the most messages?", `interopUsagePrompt3` "Which database has grown the most from message activity?". EXPERIENCE.md in place (line count unchanged): :603 gains them and their roles `[ADDED 2026-10-12 - Story 18.37]`; :164 gains "Interoperability usage (Stage 2, Story 18.37: three tabs)". Then `cd ui && node tools/screen-mirror.mjs`.

**Tests** (under 500 lines each; probes `OcuProbe1837*`):

5. `Test/MonitorPortFixture.cls`, add-only: `SetUsageRows(pEndpoint, pJson)`, `SetUsageRaise`, `UsageCalls()`, `UsageNamespace()`, a `UsageSource` override; `Clear` forgets them.
6. `Test/InteropUsagePort.cls` (new), through the fixture: typing (`"1"` to `true`, `"12"` to `12`, a totals `""` kept); the cut; a bad `maxRows` 400 and the gate 403 (`ScreenGate`), `UsageCalls` 0; a raise 500, `LogCalls` 1; `UsageNamespace` `%SYS`, the caller's restored. Live: each endpoint 200, exactly its fields per row; the queries' `FormalSpec` and `ROWSPEC` pinned (`%Dictionary.CompiledQuery`, `%SYS`).
7. `Test/InteropUsageDescriptor.cls` (new, as `MetricsDescriptor`): the declarations (the two `emptyKey`s included) and tab group; a `Cases` corpus (four endpoints sound; `Sensors`, type `GET`, a `rowGet` refused); each read through `ReadFixture` over armed rows; the three read tools.
8. `Test/InteropUsageGate.cls` (new, as `DashboardDrillDownGate`), `Test/InteropUsageProbe.cls` (extends `MetricsProbe`, prefix `OcuProbe1837`): on each tool, `Exact` (`%Admin_Operate:U,%DB_IRISSYS:R`) 200, `NoOperate` (`%Admin_Manage:U,%DB_IRISSYS:R`) 403 `%Admin_Operate:USE`, `NoSys` (`%Admin_Operate:U`) 403 `%DB_IRISSYS:READ`, anonymous 401. `scripts/ci-throwaway.sh` after :427, add-only: `# classes: InteropUsageGate`.
9. Client: `ui/tools/screen-mirror.test.mjs`, add-only "Story 18.37" over the new corpus, as :2954; new `ui/browser/interop-usage.browser-spec.mjs` (as `license-usage`'s): open the side-bar entry; the strip shows three tabs; each, once answered (no `[aria-busy="true"]`), shows the note and its read's row count then, or its empty state; an Interfaces totals row's Namespace reads "All".
10. **Rule 30 sweep** (changed files join the loop). Literal edits: `MetricsDescriptor` :51-57; `ReadTool` :93 (+3 to its count then), :94 (three names, sorted); `Navigation` :497 (+3) and per-index rows; `Wire` :734-745 (as 18.11); `WireSecurityRead` :612, :619, :622; `ui/tools/navigation.test.mjs` built-screens roster; the mirror test's note roster :197-212. Add-only: `StageTwoTools` (three `read-only`), `SurfaceCoverage` `Coverage`, `Descriptor` `ReadShapes`. Run, edit only if red: `MonitorPort`, `MetricsGate`, `ToolRoundTrip`, `ToolDispatch`, `ToolEmit`, `PortGate`, `ClassicPageGate`, `WireAreaAnyScreen`, `InteropFloor*`, `DeveloperFloor`, `ScreenRead`, `DashboardDrillDown`, client tiers.

**Acceptance Criteria:**

- **C1.** Given `InteropUsageGate`'s principals, when each reads the three tabs, then the Exact holder and Missing pair rows hold (AD-29).
- **C2.** Given armed vendor rows, when each tab's declared read answers, then each row carries exactly its typed fields (the Totals row kept), cut at the cap, read in `%SYS` with the namespace restored, and the Vendor fault row holds.
- **C3.** Given a `monitor` declaration, when either registry reads it, then the four endpoints pass and another endpoint, type or key is refused with one sentence.
- **C4.** Given the browser, when a person opens Interoperability usage from OS management's side bar, then the strip shows its three tabs, each answering its read's rows or its empty state under the note.
- **Integration.** Given `ocupilot-ci`, when the agent's three read tools run through dispatch with `{}`, then each conforms to its result schema within the row bound (`ToolRoundTrip`); the tabs consume the same reads (C4).

## Spec Change Log

- 2026-10-12, lead, spec gate: ready; AD-29, AD-36, AD-8, AD-7 and AD-44 amended as proposed; the `/api/monitor/interop` candidate filed as DW-2370 (decision-pending, owner hold); DW-2328 occurrence added. Rule 11: Task 10's literal edits sent to the orchestrator as a union ask. Epic 20's 20.29 (lazy screens): no page wrapper here; a page added later becomes a loader line.

## Review Triage Log

## Design Notes

**Measured on `ocupilot`** (read-only, 2026-10-12): `InteropInterfaces(NULL,NULL,NULL,NULL,NULL,1,1,1,0)` answered 16 rows, Inbound and Outbound totals among them, changing no activity row; a SQL `''` start raised `<ZDPT2>` (pass `""`); volume and impact were empty; `/api/monitor/interop/v1/current/interfaces` answered 200 anonymously.

**Scope.** One table per classic view: interfaces (totals, per namespace, per protocol), message totals per namespace and direction, data created per database. Named limits: no date range or per-day row (a `monitor` read takes no criteria); no per-namespace impact (the vendor's doc: it double-counts shared databases). Two tabs repeat their name column: DW-2328 (the burn-down's) covers them.

**Rule 31.** Extended: `MonitorPort`, its fixture, the mirror's parser, the License usage tabs, `MetricsProbe`. Copied: `UsageSource` after `BackgroundTaskPort.PortalRows` :352 (sharing couples two ports' vendor seams); `InteropUsageGate` after `DashboardDrillDownGate` (tests bound to their principals).

**Governing ADs:** AD-1, 5, 7, 8, 13, 16, 22, 24, 29, 36, 39, 43, 44, 60, 62 (12). **Consumes:** 18.11, 16.7, 18.36. **Consumed-by:** none beyond the agent's tools. **Ledger inbox:** none.

**For the lead:**

- AD-29: `MonitorPort`'s fourth way in (the classic page's queries in `%SYS`, same pairs). AD-36: `monitor` names one of `ENDPOINTS`. AD-8: the queries' temporary `%DB_IRISMETRICS` is the vendor's model, as `%SYS.Ensemble`'s production control. AD-7: the fifth shape gains the vendor's `%SYS` statements (inference). AD-44: the tabs' classic page.
- Vendor candidate, never reported: `/api/monitor/interop` adds `%All` unchecked, so with sign-in required on `/api/monitor` it serves every signed-in user (inference).
- Rule 11: Epic 20's diff (`f92b0dcf`) and `status -s` touch none of these files; Task 10's literal edits are for the union ask.

## Verification

**Shared surfaces:** the `monitor` arm's sentences; OS management's screens (51 to 54) and wire rosters; the read-tool registry; `StageTwoTools`, `SurfaceCoverage`, `ReadShapes`; the read-note roster; Fixed strings; the arming roster.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: `InteropUsagePort`, `InteropUsageDescriptor`, `InteropUsageGate`, `MetricsDescriptor`, then Task 10's.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/interop-usage.browser-spec.mjs` and any spec the sweep changes.
- Bundle vs the 3527kB warning: re-base under DW-1166 if crossed; stop above 3800kB. Fixed strings: 14 new, 3,309 at `54af93be` to 3,323 (3,340 after 18.42's and 18.46's); stop at 3,350.
- Full ObjectScript sweep: the runner's; browser suite: CI's.

**Mutations (Rule 19)**, as `mutation:` lines: C1, `Invoke` skips `Gate` for them (the gate tests); C2, `Active` as text, no cut, no namespace restore (`InteropUsagePort`); C3, either registry's arm admitting any endpoint (the corpus, "Story 18.37"); C4, `InteropUsageTab` unlisted, rebuilt and redeployed (the browser spec); Integration, `Interfaces` out of `ENDPOINTS` (`ToolRoundTrip`).

**S0:** no `OcuProbe1837*` user or role, no scratch class.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
