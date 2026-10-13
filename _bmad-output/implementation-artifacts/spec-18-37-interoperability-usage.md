---
title: 'Story 18.37: Interoperability usage'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: '6ec2d9db4144ccd1fcfe8895e50a1ebe2463fc6e'
baseline_commit: '6ec2d9db4144ccd1fcfe8895e50a1ebe2463fc6e'
review_loop_iteration: 0
followup_review_recommended: true
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

### 2026-10-13 - Review pass

- verdicts: 12 findings - high 0, medium 2, low 8, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` Verification gap: the real `UsageSource` arms (arguments, date window, column reads) are replaced wholesale by the fixture, so the live tests assert no row floor - patched: `TestTheLiveReadsHoldEveryRowTheVendorQueriesAnswer` compares each live read with the vendor query run directly in `%SYS`, the signature test now pins the port's fields to the queries' `ROWSPEC` columns, and the real source's refusal of an unknown endpoint is asserted; mutations recorded (runs 686, 689).
  - `[low]` `[patch]` `InteropUsageGate` doc comment says skipping the port's gate alone reddens both legs, against the recorded run 654; the NoOperate leg and the 401 clause have no mutation of their own - comment corrected to the recorded compound mutation; the port gate alone is pinned by `InteropUsagePort`, Rule 19 asks one mutation per AC, and 401 is the web application's authentication.
  - `[low]` `[patch]` Browser spec comment names a mutation (Message volume tab given the Interfaces endpoint) that would not redden its count leg, because the route read follows the same descriptor - comment replaced by the recorded note-key mutation; the endpoint is pinned by `InteropUsageDescriptor`.
  - `[low]` `[reject]` The Integration mutation (`Interfaces` out of `ENDPOINTS`) reddens `ToolRoundTrip` through the registry rather than through a result schema - the schema and row-bound clause is carried by `TestTheThreeReadToolsAnswerTheLiveRows`, whose own mutation (run 674) is recorded; a second `ToolRoundTrip` mutation would prove the same tool list again.
  - `[low]` `[patch]` Intent alignment: the message volume tab reads `MetricsTotalPerNamespace` and the interfaces tab reads `InteropInterfaces` with every grouping on, where the classic page reads `MetricsPerType` and `MetricsPerNamespace` per day and `InteropInterfaces` per view - the choice is the spec's own (Task 1 table, Design Notes named limits: no date range, no per-day row), same vendor classes and `Fetch`; the doc comments that called them "the classic page's queries" are corrected.
  - `[medium]` `[patch]` Intent alignment: the "Nothing recorded" row is exercised only by the live Database impact read happening to be empty, and no test arms an empty list - patched: `TestAnEmptyListIsAnsweredWholeNotAsAFault` and `TestAnEmptyListReadsAsNoRows` arm `[]`; mutation recorded (runs 687, 688). On a fresh instance Interfaces still answers the vendor's zero-count totals rows, so its empty state shows only when the vendor answers none.
  - `[low]` `[patch]` Intent alignment: the wire test cannot tell the port's gate from the screen's own gate - same root cause as the gate-comment row; corrected there.
  - `[low]` `[reject]` Intent alignment: the 401 clause lives in the web application's authentication - no code in the diff can change it, the spec's mutation line says so, and the test pins the deployment.
  - `[low]` `[reject]` Intent alignment: the production `UsageSource` error legs (`%New`, `Execute`, `Next`) have no retained test - the unknown-endpoint leg is now asserted; the others return the vendor's status unchanged, the fixture's error mode exercises `Usage`'s handling of it, and a deterministic vendor fault cannot be provoked.
  - `[false]` `[reject]` Intent alignment: `emptyKey` reads "All" for any empty namespace or protocol cell, not only totals rows - an empty protocol on a per-namespace row aggregates all protocols, so "All" is accurate, and Task 3 declares it per column.
  - `[low]` `[reject]` Intent alignment: one list per tab, with the page's Date column and per-namespace impact views dropped - a named limit in the spec (a `monitor` read takes no criteria; the vendor's own documentation says per-namespace impact double-counts shared databases).
  - `[false]` `[reject]` Intent alignment: `MonitorPort`'s header and the `MetricsDescriptor` sentence edits - the header's claim (the only product class that names `SYS.Monitor.SAM.Sensors`) still holds, since `UsageSource` names none, and the sentence union is the one the orchestrator pre-authorized.

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

**Task 0 findings** (`ocupilot-ci`, 2026-10-13; S0 held before; no production runs, `GetProductionStatus` reads stopped in USER and HSCUSTOM; the classic queries' sources read from `%SYS`).

- (a) As `_SYSTEM`: `Interfaces` Type, Namespace, Protocol, Count, Active, 23 rows (first four Inbound `""` `""` 0 1; Inbound 0 0; Outbound 0 1; Outbound 74 0), 257.6 ms; `MessageVolume` Namespace, Type, Volume, 2 rows (USER Inbound 80, USER Outbound 18), 35.4 ms; `DatabaseImpact` Database, DataCreated, 0 rows, 57.7 ms. With a namespace filter naming none, `InteropInterfaces` still answers six totals rows (Inbound, Outbound and Web API, Active 1 and 0, Count 0): the totals rows exist before any production runs.
- (b) `$ZCRC` of every node of the seven populated `^IRIS.Metrics*` globals (InterfaceActD 606 nodes, InterfaceActI 140, InterfaceD 123, InterfaceI 138, InteropMsgs 1, InteropMsgsD 3, InteropMsgsI 2) and of the empty `InteropDBImpactD`, `InteropDBImpactI` and `Interop`, before and after each query: unchanged, and the populated set unchanged. No halt.
- (c) `OcuProbe1837T0` (`%Admin_Operate:U,%DB_IRISSYS:R`): 23, 2 and 0 rows, as (a). `OcuProbe1837T0No` (`%Admin_Manage:U,%DB_IRISSYS:R`): `InteropInterfaces` SQLCODE -99 "User ... is not privileged for the operation", and `MetricsTotalPerNamespace` and `Impact` `<PROTECT>` on `^IRIS.Metrics.InteropMsgsI("ConstraintIndex",0)` and `^IRIS.Metrics.InteropDBImpactI("TimeStampIndex","1840-12-31")` (SQLCODE -400); no rows, `$ZCRC` unchanged. The vendor does not escalate unchecked, so no halt. The two principals, a scratch class and its copied file were removed.
- (d) `NormalizePage` of `/csp/sys/op/%CSP.UI.Portal.InteroperabilityUsage.zen` (also with `%25`) answers `%CSP.UI.Portal.InteroperabilityUsage`; its `RESOURCE` is `%Admin_Operate`.

**Sizes.** Initial total 1.91 MB (1,861.7 kB of the files `index.html` loads) against `maximumWarning` 1992 kB, no warning; the largest lazy chunk `data-browser-page` 83.32 kB against the 88 kB cap, unchanged. Fixed strings 3,326 to 3,340 of 3,400.

**Runs** (`ocupilot-ci`, indexes from `%UnitTest_Result`): `InteropUsagePort` 690 (9), `InteropUsageDescriptor` 691 (6), `InteropUsageGate` 692 (3), `MonitorPort` 681, `MetricsDescriptor` 682, `MetricsGate` 683; sweep `ReadTool` 634, `SurfaceCoverage` 635, `StageTwoTools` 636, `Navigation` 637, `Descriptor` 638, `ToolEmit` 639, `ToolRoundTrip` 640, `ToolDispatch` 641, `Wire` 642, `WireAreaAnyScreen` 643, `PortGate` 644, `ClassicPageGate` 645, `WireSecurityRead` 646, `DeveloperFloor` 647, `InteropFloor` 648 to `InteropFloorTurn` 651, `ScreenRead` 652, `DashboardDrillDown` 653. Client: `test:tools` 1959 of 1959, `test:components` 3028 of 3028, `interop-usage.browser-spec.mjs` 4 of 4 on a rebuilt and redeployed bundle. `check-objectscript` 0 problems, `lint-docs` 0 issues.

**Recorded mutations**, each applied on `ocupilot-ci` with the class recompiled (the bundle rebuilt and redeployed) and reverted byte-identical:

- mutation: C1, `Invoke` skips `Gate` for the three usage endpoints -> `InteropUsagePort` `TestAMissingPairIsRefusedBeforeAnyQuery` red (run 655) and `InteropUsageDescriptor` `TestAFaultFailsTheReadAndAMissingPairRefusesIt` red (run 656), `InteropUsageGate` green (run 654) because the screen's own gate also refuses; with the three descriptors declaring `%Admin_Operate:USE` alone and the Registry's system-database arm relaxed for `monitor` as well -> `InteropUsageGate` `TestEachMissingPairIsRefusedByName` red on the NoSys leg of all three tools (run 657).
- mutation: C2, `Active` answered as text -> `InteropUsagePort` `TestEachListTypesItsFieldsAndKeepsATotalsRow` and `TestTheLiveQueriesAnswerExactlyTheirFields` red (run 658), `InteropUsageDescriptor` `TestEachReadAnswersItsArmedRowsAndReportsTheCut` red (run 659); numbers answered as text -> the same two port tests red (run 677); the cut dropped from `Usage` -> `TestEachListIsCutAtTheCap` red (run 660); no switch to `%SYS` -> `TestTheQueryRunsInSysAndTheCallersNamespaceIsRestored` and the live test red (run 676); no restore after `UsageSource` -> `TestAMissingPairIsRefusedBeforeAnyQuery` red (run 662) and the descriptor read test red (run 663); no restore in the `Catch` -> `TestAQueryThatRaisesOrErrsFailsTheWholeRead` red (run 664) and the descriptor fault test red (run 665); the status test after `UsageSource` dropped -> the erring leg red (run 675); `Usage` answering no rows -> `InteropUsageGate` `TestTheExactPairsReadAllThree` red (run 666), the port (run 667) and descriptor (run 668) read tests red.
- mutation: C2 (the live read holds every row the vendor query answers), the interfaces call in `UsageSource` narrowed to `1, 0, 0, 0` -> `InteropUsagePort` `TestTheLiveReadsHoldEveryRowTheVendorQueriesAnswer` red alone (run 686); a field renamed in `FIELDSDATABASEIMPACT` -> `TestTheVendorQueriesKeepTheirSignatures` and `TestEachListTypesItsFieldsAndKeepsATotalsRow` red (run 689).
- mutation: Nothing recorded, `Usage` failing a source that answers no rows -> `InteropUsagePort` `TestAnEmptyListIsAnsweredWholeNotAsAFault` red (run 687) and `InteropUsageDescriptor` `TestAnEmptyListReadsAsNoRows` red (run 688); each reverted byte-identical, then 690 and 691 green.
- mutation: C3, the Registry's monitor arm admitting any endpoint -> `InteropUsageDescriptor` `TestTheMonitorSourceAdmitsItsFourEndpointsAndRefusesTheRest` red (run 669) and `MetricsDescriptor` `TestTheMonitorSourceRefusals` red (run 670); the mirror's arm admitting any endpoint -> "Story 18.37" and "Story 18.11" in `screen-mirror.test.mjs` red.
- mutation: C4, `InteropUsageTab` unlisted (`sideBarPosition` 0), mirror regenerated, bundle rebuilt and redeployed -> `interop-usage.browser-spec.mjs` side-bar test red alone ("Interoperability usage is the twenty-second"); `emptyKey` dropped from the Namespace and Protocol columns and the Message volume tab's note key changed, together -> the totals test and the note test red, the side-bar and DW-1337 tests green; each reverted, the mirror byte-identical, rebuilt and redeployed -> 4 of 4.
- mutation: C4 (declarations), `PAIRS` without `%DB_IRISSYS:READ`, `refreshes` true on the Message volume tab and the Protocol `emptyKey` dropped -> `InteropUsageDescriptor` `TestTheThreeTabsDeclareTheirReadsAndFormOneGroup` red on the pairs, refresh and columns legs (run 673); `SOURCEMONITOR` out of `OcuPilot.Screen.Read.Execute`'s source list -> `InteropUsageDescriptor` read, fault and tool tests red (run 674).
- mutation: Integration, `Interfaces` out of `ENDPOINTS` -> `ToolRoundTrip` both tests red (run 671: the registry refuses `InteropUsageTab`, so the tool list does not build) and `InteropUsageDescriptor` red (run 672).
- C1's 401 clause (`InteropUsageGate` `TestARequestWithNoCredentialsIsRefused`) has no mutation: the web application's authentication answers it before any OcuPilot code runs (inference), so the test pins the deployment.
- (QA) Test changed: `src/OcuPilot/Test/InteropUsageGate.cls` gains `TestThePortRefusesWhatALoweredScreenAdmits` (AD-64: the three screens' stored sets lowered to `%Admin_Operate:USE`, then `%Admin_Manage:USE`; the port refuses the principal the screen admits, and the refusal names no screen), a `StoredAdjustment` property and `Adjust`, `RemoveAdjustment` and `OnAfterOneTest` helpers that store and remove those rows. No new file.
- (QA) mutation: C1, `Invoke` skips `Gate` for the three usage endpoints, the screens' sets as declared -> `InteropUsageGate` `TestThePortRefusesWhatALoweredScreenAdmits` red alone, on both principals and all three screens (run 694); the other three tests stay green, as above; reverted byte-identical, then 698 (4 of 4) green.
- (QA) mutation: Totals row, `Usage` drops text cells that read `""` -> `InteropUsagePort` `TestEachListTypesItsFieldsAndKeepsATotalsRow` and `TestTheLiveQueriesAnswerExactlyTheirFields` red (run 695); reverted byte-identical, then 697 (9 of 9) green.
- (QA) mutation: Vendor fault, `Fail` no longer logs -> `InteropUsagePort` `TestAQueryThatRaisesOrErrsFailsTheWholeRead` red (run 696, the "logged once" legs); reverted byte-identical, then 697 green.
- (QA) Rule 3: `interop-usage.browser-spec.mjs` 4 of 4 on a bundle rebuilt and redeployed to `ocupilot-ci`; it opens each of the three tabs and compares its rows, or its empty state, with the read route under the note.

**S0:** no `OcuProbe1837*` user or role, no scratch class.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** `MonitorPort` gains the endpoints `Interfaces`, `MessageVolume` and `DatabaseImpact`, answered by the vendor's interoperability usage class queries run in `%SYS` behind the port's gate, typed and cut at the cap (`Usage`, overridable `UsageSource`). Three `os-management/interoperability-usage` descriptor tabs and their three read tools, 14 strings, and both registries' `monitor` arm now admit the four endpoints. Task 0 found no halt: the principal without `%Admin_Operate` reads no row, so the vendor does not escalate unchecked; `^IRIS.Metrics*` is unchanged by the queries.

**Files changed.**

- Port and registries: `Port/MonitorPort.cls`, `Screen/Read.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/core/screens.generated.ts` (regenerated).
- Screens and strings: `Screen/Descriptor/InteropUsageTab.cls`, `InteropUsageVolumeTab.cls`, `InteropUsageImpactTab.cls`; `ui/src/app/core/strings.ts`; `EXPERIENCE.md` (lines 164 and 603, line count unchanged).
- New tests: `Test/InteropUsagePort.cls`, `InteropUsageDescriptor.cls`, `InteropUsageGate.cls`, `InteropUsageProbe.cls`, `ui/browser/interop-usage.browser-spec.mjs`.
- Shared-surface edits (Rule 30 sweep): `Test/MonitorPortFixture`, `MetricsDescriptor`, `ReadTool`, `Navigation`, `Wire`, `WireAreaAnyScreen`, `WireSecurityRead`, `StageTwoTools`, `SurfaceCoverage`, `Descriptor`; `scripts/ci-throwaway.sh` (one arming line); `ui/tools/navigation.test.mjs`, `screen-mirror.test.mjs`, `side-bar-pins.test.mjs`; `ui/src/app/shell/area-verdict.spec.ts`.

**Review.** Two layers (verification-gap, intent-alignment), 12 findings: patches applied 6 (medium 2, low 4), deferred 0, rejected 6 with the reasons in the triage log. The patches add tests only (a live read compared with the vendor query run directly, the port's fields pinned to the queries' columns, an armed empty list at the port and at the tab) and correct four comments and doc comments. Follow-up review recommended: true, because two medium findings were patched. The unreviewed risk is the new `TestTheLiveReadsHoldEveryRowTheVendorQueriesAnswer`, which reads live vendor data twice and holds only while no production writes between the reads (none runs on a throwaway).

**Verification.** `ocupilot-ci` loaded `LOAD-OK` / `STARTPATH-OK`; final runs `InteropUsagePort` 690 (9 of 9), `InteropUsageDescriptor` 691 (6 of 6), `InteropUsageGate` 692 (3 of 3); the earlier sweep runs, the client tiers and the browser spec (4 of 4) are recorded under `## Verification`, with the nine mutations, each reverted byte-identical. After the patches, `npm run test:tools` passed 1959 of 1959, `check-objectscript` and `lint-docs` report 0 problems, and `screen-mirror.mjs --check` is up to date. Bundle: initial 1.91 MB (1,861.7 kB of the files `index.html` loads) against the 1992 kB warning; largest lazy chunk `data-browser-page` 83.32 kB against 88 kB. `ocupilot-ci` reads S0.

**Residual risks.**

- Two of the three tabs read vendor queries the classic page does not call itself (`MetricsTotalPerNamespace`, and `InteropInterfaces` with every grouping on), by the spec's design; a reader of the intent's "the classic page's class queries" may expect the page's per-day lists.
- On an instance with no recorded activity the Interfaces tab shows the vendor's zero-count totals rows, not its empty state.
- The Database impact tab's non-empty rendering is pinned by armed rows at the port and the tab, not by a live browser row.
- Merge with Epic 20: `Test/ReadTool.cls` lines 93-94, `EXPERIENCE.md`, `strings.ts`, `ci-throwaway.sh`, `SurfaceCoverage` and `screens.generated.ts` (regenerate with `node tools/screen-mirror.mjs`) overlap its diff.
