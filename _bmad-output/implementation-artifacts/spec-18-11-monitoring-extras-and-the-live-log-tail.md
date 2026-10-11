---
title: 'Story 18.11: Monitoring extras and the live log tail'
type: 'feature'
created: '2026-10-11'
status: 'done'
baseline_revision: 'b2be790d12e58d2c3b5579f32d578027cdb75965'
baseline_commit: 'b2be790d12e58d2c3b5579f32d578027cdb75965'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Monitoring in OcuPilot is sampled: there is no table of the instance's raw Prometheus metrics. Two of OcuPilot's own reads also raise the instance's monitor and alert state (DW-1872, DW-1898).

**Approach:** A read-only Prometheus metrics table through `MonitorPort` behind its own resource gate (a `monitor` read source kind), plus DW-1872 and DW-1898. Split on the orchestrator's ruling (2026-10-11, Rule 5): the dashboard drill-downs are Story 18.36's, interoperability usage Story 18.37's and the live log tail Story 18.38's.

## Boundaries & Constraints

**Always:** The monitoring API's anonymous reachability never becomes OcuPilot's (AD-29). The Release 1 bounded-page rule is unchanged (the live tail is Story 18.38's).

**Never:** Call the vendor's alerts read, which advances `LastAlertSent` (AD-7). Build on a `decision-pending` entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-1872 | `GET /screens/osmgmt.databasevolumes/read` without `dir` | 400 `READ.CRITERION`; no admin call | Nothing logged |
| DW-1898 | A queued write still running when the poll bound is reached | Its caller answers started (202) | Nothing logged; a read at the bound still logs |

</intent-contract>


## Code Map

Paths under `src/OcuPilot/` unless `ui/` or `scripts/`; checked on this branch. Tasks 3 and 4 carry the registries' anchors.

- `Port/MonitorPort.cls`: `Invoke` :139 (only `Sensors`/`SENSORS`), `Collect` :184, `Parse` :240 (unlabeled lines only); seams through `Test/MonitorPortFixture` (`SetText`, `SourceCalls`, `LogCalls`); `PortGate` :29 already rosters it.
- `Screen/Read.cls`: allow-list :422; sqlactivity branch :581-590 (the sibling); `MonitorPortClass` :224; `Test/Read/ReadFixture.cls` :14 routes it to the fixture. DW-1872: the guard :676-681 covers only `tBareRows`, and `DatabaseVolumeList` (parent-scoped `VOLUMELIST`) declares no `rows`, so a read without `dir` reaches the vendor, whose 400 is logged.
- `Port/AdminPort.cls` (DW-1898): `AwaitTask` logs the bound (:3409-3412) before `NamespacePort.Started` :141 and four sibling ports answer it started; `IsQueuedWrite` :2758; `QUEUEDWRITES` :853. Seams: `Test/PortFixture` (canned poll, timeout, `LogFault` :187 to `LogProbe`); `AdminPortFault` :291; `AuditStarted` :106 (the route, in process).
- Siblings: `SqlActivityList.cls`, `LogHub.cls` (id `none`), `Test/SqlActivityDescriptor`, `Test/SqlActivityProbe.EnsurePrincipals` :188 (keyed by `PRINCIPALPREFIX`), `Test/DocDbAppGate.Wire` :195, `ui/browser/sql-activity.browser-spec.mjs`.
- Slices 2 to 4 (Stories 18.36, 18.37, 18.38): anchors in this spec at d0d9daef.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`): record S0; take one collection through `MonitorPort.Source()` in `%SYS` and check Task 1's grammar parses every sample line; halt on one it cannot.

**Execution:**

1. `Port/MonitorPort.cls`: `Parameter ENDPOINT = "Metrics"`, `TYPELIST = "LIST"`, `MAXROWSKEY = "maxRows"` (`SqlActivityPort` :40-46). `Invoke`, after `Gate`, answers `ENDPOINT`/`TYPELIST` with a new `Samples(pText, pMax, Output pRows)` over one collection, a bad `maxRows` refused as `SqlActivityPort.Invoke` :128 refuses it; anything else unchanged. Grammar: skip blank and `#` lines, but `# HELP <name> <text>` sets that metric's Help; a sample is `<name>[{<labels>}] <value>[ <timestamp>]`. `Metric` runs to `{` or a space; `Labels` is the text between the braces as answered (the closing brace is the first `}` outside a quoted value, `\"` escaped), `""` when none; `Value` a JSON number when `$IsValidNum`, else its text (`NaN`, `+Inf`); `Help` the HELP text or `""`. Rows in exposition order, at most `pMax`. A sample with no value or an unclosed label set fails the read: 500 `INTERNAL`, logged once, no rows. `Parse` is untouched.
2. `Screen/Read.cls`: `Parameter SOURCEMONITOR = "monitor"` joins :422; a branch beside :581: no namespace, no criteria, `maxRows` the cap plus one, `MonitorPortClass()` with the port's `ENDPOINT`/`TYPELIST`; header doc :25-39. **DW-1872** at :677: the route criterion is required when `tBareRows || (tSourceType = ..#VOLUMELISTTYPE)`.
3. `Screen/Registry.cls` `ReadProblem`: `SOURCEMONITOR` in :1167 and the :1168 sentence ("thirteen" becomes "fourteen" at :1100); an arm beside :1260-1277 (endpoint `MonitorPort.#ENDPOINT`, type `#TYPELIST`, no `rowGet`, `forEach`, `query` or `parts`); the :1578 rule also binds `monitor`.
4. `ui/tools/screen-mirror.mjs`: `SOURCE_MONITOR`, `MONITOR_PORT_SOURCE` read through `parseBackgroundEndpoint` :1025 as :1062-1079; join :981 and :1308-1309; the arm beside :1387; the :1634 rule. Every sentence character for character the Registry's.
5. `Screen/Descriptor/MetricsList.cls` (new): route `os-management/metrics`; `labelKey` `metricsLabel`; `sideBarPosition` 21; `list`, built; `refreshes` false; privileges `%Admin_Operate:USE`, `%DB_IRISSYS:READ` (no own pair); `entityType` `""`; scope `instance`; id `none` (LogHub's); no actions; context fields `Metric, Labels, Value, Help`; `emptyStateKey` `metricsEmpty`; aliases `prometheus metrics`, `metrics`, `sensors`; prompts `metricsPrompt1` (`promptGroupCapacity`), `2` and `3` (`promptGroupTroubleshooting`); `classicPage` `""` (no classic page, AD-44); read `{port: monitor, endpoint: Metrics, type: LIST}`, those four fields, filter `Metric, Labels, Help`, sort `Metric, Value` default `Metric` asc, paging `cap`, note `metricsNote`; columns Metric (`name`, `metricsColumnMetric`), Labels (`identifier`, `metricsColumnLabels`), Value (`number`, `errorLogColumnValue`), Help (`text`, `tableColumnDescription`); `emptyNextKey` `tableReadOnlyEmptyNext`; `toolIdentifier` `osmgmt.metrics`.
6. `Port/AdminPort.cls` `AwaitTask` :3409-3412 (**DW-1898**): log the bound only when `'..IsQueuedWrite(pEndpoint, pType)`.
7. Strings, add-only, `/** EXPERIENCE.md:603 */`: `metricsLabel` 'Prometheus metrics', `metricsColumnMetric` 'Metric', `metricsColumnLabels` 'Labels', `metricsEmpty` 'The instance answered no metrics.', `metricsNote` 'Each read takes a new sensor collection, which shortens the per-second intervals an external Prometheus scraper reports.', `metricsPrompt1` 'Which databases are the largest, by their size metrics?', `metricsPrompt2` 'How busy is the instance right now: CPU, cache efficiency and global references?', `metricsPrompt3` 'What do the Web Gateway metrics read?'. EXPERIENCE.md in place, line count unchanged: :603 gains them with their roles `[ADDED 2026-10-11 - Story 18.11]`; :164 gains "Prometheus metrics (Stage 2, Story 18.11)". `node tools/screen-mirror.mjs`; stop past 3350 strings.

**Tests** (each class under 500 lines; probes `OcuProbe1811*`):

8. ObjectScript:
   - `Test/MonitorPort.cls`, methods added: Task 1's grammar over `SetText` (labeled, unlabeled, HELP/TYPE/UNIT, a label value holding a space, `}` and `\"`, `NaN`), the cut, a malformed sample (500, `LogCalls` 1), the gate (403, `SourceCalls` 0), a live collection.
   - New `Test/MetricsDescriptor.cls` (as `SqlActivityDescriptor`): the monitor arm's refusals, the shape, the read through `Test/Read/ReadFixture` over canned text, the read tool.
   - New `Test/MetricsGate.cls`, with `Test/MetricsProbe.cls` extending `SqlActivityProbe` (`PRINCIPALPREFIX` `OcuProbe1811`): `OcuProbe1811Exact` (`%Admin_Operate:U,%DB_IRISSYS:R`), `NoOperate` (`%Admin_Manage:U,%DB_IRISSYS:R`, past the API floor), `NoSys` (`%Admin_Operate:U`), reading as `DocDbAppGate.Wire`; removed after the last test. Joins `scripts/ci-throwaway.sh`'s roster beside :414, add-only.
   - New `Test/VolumeListCriterion.cls` (**DW-1872**): through `ReadFixture` and `PortFixture`, no `dir` is 400 `READ.CRITERION` "dir is required", no endpoint run (`PortFixture.Recorded("name")` empty), nothing logged; the route over `Test/Http` answers the same.
   - **DW-1898**: `Test/PortFixture.cls` gains, at its end, `Await(pEndpoint, pType, Output pHttpStatus, Output pFault)` calling `AwaitTask`; `AdminPortFault` gains `TestAQueuedWriteStillRunningAtTheBoundLogsNothing` beside :291 (canned `Running`, timeout 0): `Namespace.Namespace`/`MAPPINGS` is 503 `PORT.TIMEOUT`, nothing logged; `Database.SysCRUD`/`INFO` logs. `AuditStartedPort` gains `LogFault` to `FaultProbe`; `AuditStarted` :106 asserts nothing logged once the route answers `continues`.
9. Client: new `ui/browser/prometheus-metrics.browser-spec.mjs` (as `sql-activity.browser-spec.mjs`): open from the side bar, `waitForRows`; the note reads `metricsNote`; filter on the first unlabeled `Metric` the route answers at that moment and see only its rows; a labeled row shows its labels. `ui/tools/screen-mirror.test.mjs`: the monitor arm's refusals, add-only.
10. **Rule 30 sweep.** Edit: `ReadTool` :93 (351), :94, :112; `SurfaceCoverage` `Coverage` :54 row; `Descriptor` `ReadShapes` row `MetricsList`; `Navigation` :494 (47) and "then Prometheus metrics, at position 21"; `navigation.test.mjs` :139; `Wire` :766; `WireSecurityRead` :611, :618, :621; `ToolRoundTrip` :89 `osmgmt.databasevolumes.read:READ.CRITERION` and the :20-22 sentence (four at the criterion check, two at the port's); the sources sentence in `SqlActivityDescriptor` :54, `DocDbDescriptor` :59, `InteropDescriptor` :98, `AdminPairCorpus` :58 and `screen-mirror.test.mjs` :2782. Run, editing only if red: `EndpointCoverage`, `ToolDispatch`, `ToolEmit`, `PortGate`, `ClassicPageGate`, `MappingDescriptor`, `Dashboard`, `DashboardLive`, `ScreenRead`, `AdminPortAsync`, `NamespaceCopy`, `NamespaceInterop`, and the client tiers whole (`field-lists`, `navigation-wire`, `ci` among them).

**Acceptance Criteria:**

- **C1.** Given `MetricsGate`'s principals, when each reads `GET /screens/osmgmt.metrics/read`, then the holder of exactly the port's two pairs reads the instance's samples as `{Metric, Labels, Value, Help}` rows, one missing either pair is refused 403 naming it with no collection taken, and an unauthenticated request is refused 401 (AD-29).
- **C2.** Given an exposition carrying Task 1's cases, when the screen's read answers over it, then it holds one row per sample in exposition order, cut at the cap plus one, and a malformed sample fails the read, logged once, with no rows.
- **C3.** Given a declaration naming `monitor` with another endpoint or type, a `rowGet`, `forEach`, `query` or `parts`, or no `%DB_IRISSYS:READ`, when either registry reads it, then both refuse it with one sentence.
- **C4.** Given the browser, when the screen answers, then OS management's side bar lists Prometheus metrics at position 21, the table shows the read's rows under the note, and a metric's filter leaves only its rows.
- **Integration.** Given `ocupilot-ci`, when the agent's `osmgmt.metrics.read` runs through dispatch with `{}` and the page opens, then the tool answers at most 200 rows, conforming to its result schema (`ToolRoundTrip`), and the page consumes the same read (C4).

## Design Notes

**Ledger.** DW-1872: Task 2, `VolumeListCriterion`, `ToolRoundTrip`. DW-1898: Task 6, `AdminPortFault`, `AuditStarted`; one guard covers all twelve `QUEUEDWRITES` pairs, so its 18.20 occurrence (`EcpPort`) closes with it.

**Measured** (GET `/api/monitor/metrics` on `ocupilot`, 2026-10-11): 585 samples, 513 labeled; 108 HELP, 108 TYPE, 27 UNIT lines; every value numeric; `iris_system_info`'s label values hold spaces.

**Rule 31.** Extended: `MonitorPort.Invoke` and `Collect`, the sqlactivity pattern, `SqlActivityProbe`, `PortFixture`. `Parse` stays separate and tolerant: Home's row and the Dashboard's part must not fail on a line they never read, while the table fails closed. The log hub (16.9) is not extended: a sample is not a log line.

**Scope.** No write tool, governance key (AD-22), entity type, route, error code or listing logic (20.24). No auto-refresh: each read rewrites the sensor baseline (AD-7), as its note states, and joining is an AD-43 amendment no criterion asks for.

**Governing ADs:** AD-1, 2, 5, 7, 8, 13, 22, 24, 26, 29, 36, 39, 43, 44, 60. **Integration ACs:** the Integration line. **Consumed-by:** 18.12 (every Stage 2 read tool). **Consumes:** 16.18 and 16.7 (`MonitorPort`, its gate), 19.10 (the source-kind pattern).

**For the lead** (Rule 20): AD-36, the `monitor` source kind, and a parent-scoped `VOLUMELIST` read requiring its criterion (DW-1872); AD-29, `MonitorPort`'s third way in; AD-7, the sensor-baseline shape names the table; AD-26, a queued write past the bound logs nothing (DW-1898). **Contended (Rule 11):** `ToolRoundTrip` :89 (a token on the line Epic 20's 20.23 appends to) and its doc sentence, `InteropDescriptor` :98 (Epic 20's hunk is :389) and `ReadTool` :93, :94, :112 are not add-only edits in Epic 20's files; implement makes them only with the orchestrator's pre-authorization recorded at the spec gate, as for 18.32. No vendor defect candidate.

## Verification

**Shared surfaces:** the read-source vocabulary and its sentence; OS management's screens (46 to 47) and their wire rosters; the read-tool registry (350 to 351), `SurfaceCoverage`; `REFUSEEMPTY`; `AdminPort`'s bound log line; Fixed strings.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands:**

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: `MonitorPort`, `MetricsDescriptor`, `MetricsGate`, `VolumeListCriterion`, `AdminPortFault`, `AuditStarted`, and every class Task 10 edits or runs.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/prometheus-metrics.browser-spec.mjs` and any spec the sweep changes. Initial bundle against the 3487kB warning: re-base under DW-1166 if crossed; stop and ask above 3800kB.
- Full ObjectScript sweep: the runner's; browser suite: CI's.

**Mutations (Rule 19),** each recorded as `mutation:`, applied on `ocupilot-ci` with the mutated class and every descendant recompiled (or the bundle rebuilt and redeployed) and reverted byte-identical:

- mutation: C1, `MonitorPort.Gate` answers OK -> `MonitorPort` `TestTheGateRefusesTheListBeforeAnyCollection` red (run 620); with `MetricsList` declaring `%Admin_Operate:USE` alone and the system-database arm relaxed for `monitor` too, since both gates refuse -> `MetricsGate` `TestEachMissingPairIsRefusedByNameAndTakesNoCollection` red on the NoSys leg (run 621); `PAIRS` without `%DB_IRISSYS:READ` -> `MetricsDescriptor` `TestTheDescriptorShape` and `TestAMalformedSampleAndAMissingPairFailTheRead` red (run 647); `Take` answers no text -> `MetricsGate` `TestTheExactPairsReadTheSamples` red (run 644).
- mutation: C2, the name scan runs on to the first space -> `MonitorPort` `TestTheSampleGrammarAnswersEveryLineShape` and `TestAMalformedSampleFailsTheWholeRead` red (run 624); `Value` always a number -> `TestTheSampleGrammarAnswersEveryLineShape` red (run 625) and `MetricsDescriptor` `TestTheReadAnswersTheSamplesInOrderAndReportsTheCut` red (run 626); the cut dropped -> `TestTheListIsCutAtTheCap` and `TestTheLiveCollectionAnswersSamples` red (run 641); a sample with no value read as a value -> `TestAMalformedSampleFailsTheWholeRead` red (run 642) and `MetricsDescriptor` `TestAMalformedSampleAndAMissingPairFailTheRead` red (run 643).
- mutation: C2 (escape and raise), the backslash branch of `LabelsEnd` dropped -> `MonitorPort` `TestTheSampleGrammarAnswersEveryLineShape` red on the escaped-quote-then-brace row (run 659); the status test after `Take` dropped in the list branch -> `TestAListCollectionThatRaisesAnswersTheInternalFault` red (run 660).
- mutation: C3, the Registry's monitor arm dropped -> `MetricsDescriptor` `TestTheMonitorSourceRefusals` red (run 627); the mirror's arm dropped -> `screen-mirror.test.mjs` "Story 18.11" red; the Registry's system-database arm drops `monitor` -> `TestTheMonitorSourceRefusals` red (run 645); `MetricsList` declaring `refreshes` true -> `TestTheDescriptorShape` red (run 646).
- mutation: C4, `Metric` out of `MetricsList`'s filter, mirror regenerated, bundle rebuilt and redeployed -> `prometheus-metrics.browser-spec.mjs` filter test red; reverted, rebuilt and redeployed -> 4 of 4 green.
- mutation: C4 (side bar, refresh, labels), `MetricsList` `sideBarPosition` 0 with the mirror regenerated and the bundle rebuilt and redeployed -> `prometheus-metrics.browser-spec.mjs` side-bar leg red; `refreshes` true with `refreshRates` set, same rebuild -> the same leg red; `Labels` blanked in `MonitorPort.Samples` -> the labeled-row leg red alone; each reverted byte-identical, rebuilt and redeployed -> 4 of 4 green.
- C1's 401 clause (`MetricsGate` `TestARequestWithNoCredentialsIsRefused`) has no mutation: the web application's authentication answers it before any OcuPilot code runs (inference), so the test pins the deployment, not a method.
- mutation: Integration, `SOURCEMONITOR` out of Read's allow-list -> `ToolRoundTrip` `TestEveryToolConformsToItsResultSchemaOrAnswersACode` red (run 628) and `MetricsDescriptor` read, failure and tool legs red (run 629).
- mutation: DW-1872, `VOLUMELIST` out of the route-criterion guard -> `VolumeListCriterion` both tests red (run 630) and `ToolRoundTrip` red on `osmgmt.databasevolumes.read:READ.CRITERION` (run 631).
- mutation: DW-1898, the `IsQueuedWrite` guard dropped from `AwaitTask` -> `AdminPortFault` `TestAQueuedWriteStillRunningAtTheBoundLogsNothing` red (run 632) and `AuditStarted` `TestTheScreenRouteAnswersThatACopyStillRunningContinues` red (run 633).

**S0:** no `OcuProbe1811*` user or role.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Prometheus metrics, OS management's twenty-first screen: a `monitor` read source kind, `MonitorPort`'s `Metrics`/`LIST` read (`Samples`, `LabelsEnd`, `Take`) behind the port's two pairs, `MetricsList`, eight strings, and the Registry and mirror arms. DW-1872: a `VOLUMELIST` read requires its `dir` criterion before any call. DW-1898: `AwaitTask` logs the bound only for a pair outside `QUEUEDWRITES`.

**Files.** Product: `Port/MonitorPort.cls`, `Port/AdminPort.cls`, `Screen/Read.cls`, `Screen/Registry.cls`, `Screen/Descriptor/MetricsList.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/core/strings.ts`, `ui/src/app/core/screens.generated.ts` (regenerated), `EXPERIENCE.md` (:164, :603), `scripts/ci-throwaway.sh` (roster). Tests: `MonitorPort`, `MetricsDescriptor`, `MetricsGate`, `MetricsProbe`, `VolumeListCriterion`, `AdminPortFault`, `AuditStarted`, `AuditStartedPort`, `PortFixture`, `prometheus-metrics.browser-spec.mjs`, `screen-mirror.test.mjs`. Sweep: `ReadTool`, `SurfaceCoverage`, `Descriptor`, `Navigation`, `Wire`, `WireSecurityRead`, `WireAreaAnyScreen`, `ToolRoundTrip`, `InteropDescriptor`, `SqlActivityDescriptor`, `DocDbDescriptor`, `AdminPairCorpus`, `navigation.test.mjs`, `side-bar-pins.test.mjs`, `area-verdict.spec.ts`.

**Review.** Eleven findings, two patched at medium and one at low, eight rejected (`## Review Triage Log`); nothing deferred. Follow-up review: not recommended; the patches are test additions, each shown red under its mutation and green after.

**Verification** (on `ocupilot-ci`, run indexes from `%UnitTest_Result`). Story classes: `MonitorPort` 661 (12), `MetricsDescriptor` 662 (6), `MetricsGate` 652 (3), `VolumeListCriterion` 654 (2), `AdminPortFault` 655 (25), `AuditStarted` 656 (3), `ToolRoundTrip` 657 (2). The sweep classes ran green in the implement pass (`ReadTool`, `SurfaceCoverage`, `Descriptor`, `Navigation`, `Wire`, `WireSecurityRead`, `WireAreaAnyScreen`, `InteropDescriptor`, `SqlActivityDescriptor`, `DocDbDescriptor`, `EndpointCoverage`, `ToolDispatch`, `ToolEmit`, `PortGate`, `ClassicPageGate`, `MappingDescriptor`, `Dashboard`, `DashboardLive`, `ScreenRead`, `AdminPortAsync`, `NamespaceCopy`, `NamespaceInterop`). `AdminPairCorpus` is a corpus with no methods of its own. Client: `test:tools` 1909 of 1909, `test:components` 2880 of 2880, `prometheus-metrics.browser-spec.mjs` 4 of 4 on a rebuilt and redeployed bundle. `check-objectscript` 0 problems, `lint-docs` 0 issues. Initial bundle 3.32 MB against the 3487kB warning, so `angular.json` is untouched; fixed strings 3,134 to 3,142 of 3,400. S0 holds on `ocupilot-ci`.

**Residual risk.** The full ObjectScript sweep and the browser suite are the runner's and CI's. The DW-1872 mutation let the vendor's 400 reach `messages.log` on `ocupilot-ci` once; no probe object remains.

## Spec Change Log

- 2026-10-11, lead: narrowed on the orchestrator's split ruling (feature 39cb1e27, Rule 5): 18.11 keeps the metrics table, DW-1872 and DW-1898; the drill-downs, interoperability usage and live tail moved to Stories 18.36, 18.37 and 18.38 (their anchors are in this Code Map's slices 2 to 4, kept to seed them). The intent was narrowed to match and the Proposed Split section removed; status reset to `draft` for a re-plan in place.

## Review Triage Log

### 2026-10-11 - Review pass

- verdicts: 11 findings - high 0, medium 2, low 8, false 1, maybe-false 0 (the intent-alignment auditor's divergences are each one row)
- findings:
  - `[medium]` `[patch]` `MonitorPort.LabelsEnd`'s backslash branch is pinned by no test: the grammar test's escaped quotes come in a pair with no brace between them, so a scanner that ignores `\` closes in the same place - added a `probe_h` sample whose value holds `\"}`; dropping the branch is red (run 659).
  - `[medium]` `[patch]` The list branch of `Invoke` has no test for a collection that raises; without its status test a raise is answered 200 with no rows - added `TestAListCollectionThatRaisesAnswersTheInternalFault`; dropping the status test is red (run 660).
  - `[low]` `[patch]` C1's 401 clause and C4's side-bar, no-refresh and labels clauses had no recorded `mutation:` line (Rule 19) - ran position 0, `refreshes` true and blank `Labels`, each red, and recorded them; the 401 clause has no OcuPilot code to mutate and the line says so.
  - `[low]` `[reject]` `MetricsDescriptor` `TestTheScriptForms` asserts two constants - it pins AD-59's rule that a read-only port has no script form and goes red when either method changes, as `SqlActivityDescriptor`'s does.
  - `[low]` `[reject]` The spec's `## Auto Run Result` read `ready-for-dev` and recorded no class totals - finalize rewrites it with the totals; a finding whose fix edits this spec is rejected.
  - `[low]` `[reject]` DW-1898 is tested at `AwaitTask` (503) while the matrix names the caller's 202 - the 202 is each caller's own contract and this diff only removes a log call; `AuditStarted` pins the started answer and the continuing route and ran green (run 656).
  - `[low]` `[reject]` The DW-1898 log assertions read the in-process seam, not `messages.log` - `LogFault` is the bound line's only writer and the guard's mutation reddens both tests (runs 632 and 633).
  - `[low]` `[reject]` DW-1872's wire test asserts only the 400 sentence - the route and the in-process read run the same `Read.Execute`; dropping the guard reddens both `VolumeListCriterion` tests and `ToolRoundTrip` (runs 630 and 631).
  - `[low]` `[reject]` The guard covers only the `VOLUMELIST` type under a parent scope - the intent names that route; other parent-scoped lists are another story's.
  - `[false]` `[reject]` No assertion that the vendor's alerts read is never called - no source file outside `Test/DashboardLive` mentions it (searched `src/OcuPilot` for `LastAlertSent`, `SAM.Alerts` and `monitor/alerts`).
  - `[low]` `[reject]` The spec's title and filename still say "live log tail" - the lead renames them at the split; the intent contract and the diff agree on the metrics table.
