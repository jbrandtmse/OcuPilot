---
title: 'Story 18.11: Monitoring extras and the live log tail'
type: 'feature'
created: '2026-10-11'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Monitoring in OcuPilot is sampled. There is no raw metrics table, no dashboard drill-down, no interoperability usage view, and no live tail on a text log.

**Approach (as epics.md states it):** Four read surfaces, each through its own port behind its own resource gate, plus a long-poll live tail with a heartbeat on the text logs that opt in. The Release 1 bounded-page rule holds for every other source. Ledger inbox: DW-1872 and DW-1898.

## Boundaries & Constraints

**Always:** The monitoring API's anonymous reachability never becomes OcuPilot's (AD-29). The bounded-page rule is superseded only for the sources that opt in.

**Never:** Call the vendor's alerts read, which advances `LastAlertSent` (AD-7). Build on a `decision-pending` entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-1872 | `GET /screens/osmgmt.databasevolumes/read` without `dir` | 400 `READ.CRITERION`; no admin call | Nothing logged |
| DW-1898 | A queued write still running when the poll bound is reached | Its caller answers started (202) | Nothing logged; a read at the bound still logs |

</intent-contract>

## Proposed Split

The planned scope does not fit one implement pass or a 16 KB spec. It covers four surfaces, each the size of a story in this epic, plus two ledger items. Narrowing 18.11's criteria and adding stories is Rule 5's ask-first tier, so this plan halts here. The lead (or orchestrator) amends `epics.md`, and 18.11 is planned again.

Recommendation: keep the key `18-11-monitoring-extras-and-the-live-log-tail`, so the ledger inbox needs no re-own; retitling it is the lead's call. Number the three new stories after 18.34. The run order already names 18.35 for the burn-down.

1. **18.11: the Prometheus metrics table, DW-1872 and DW-1898.** This slice keeps the first criterion for the metrics table.
   - `MonitorPort` answers a `LIST` with one row per exposition line, `{Metric, Labels, Value}`, from one collection, cut at the cap plus one.
   - A `monitor` read source kind lets a `list` descriptor in OS management render through `ListPage`, behind the port's `%Admin_Operate:USE` and `%DB_IRISSYS:READ`.
   - Each read rewrites the sensor baseline. AD-7 already names that shape.
   - The two ledger items are small, and both touch code this slice already opens (`Read.cls` and `AdminPort`).
2. **New: the dashboard drill-downs.** The admin API's `GET /v2/monitor/dashboard/globals-and-routines`, `/ecp` and `/system-resources` (`spec/admin-v2-paths.json` :215-226) become read-only screens reached from the Dashboard.
   - The repository does not record the request types behind those three routes. Only `DASHBOARDMAIN` is in `AdminPort`'s `BARETYPES` (:1015), so Task 0 reads them on a throwaway.
   - `BusyProcesses`' empty rows are dropped, as the "Admin API behavior to design for" block in `epics.md` says.
3. **New: interoperability usage.** It carries two architecture questions that need an answer before a port is built:
   - **AD-8.** The classic page `%CSP.UI.Portal.InteroperabilityUsage` (`RESOURCE` `%Admin_Operate`, :22) queries `SYS.Monitor.Interop.Interface.Utils:InteropInterfaces` (:124). `/api/monitor/interop` (`%Api.InteropMetrics.v1`, deprecated) checks nothing. It reaches `%SYS.Ensemble.SetSAMSensorsForInterop*` (:771-1160, `[Internal]`), and each of those escalates with `$$$AddAllRoleTemporaryInTry`. AD-8 accepts a vendor escalation only after the vendor has checked the caller.
   - **AD-7.** Do the sensor setters write state? If they do, that is a new AD-7 shape.
   - The epic context says the view reads `%Api.InteropMetrics.v1`; the classic page reads a different query. The story's plan chooses between them.
4. **New: the live log tail (the second criterion).**
   - **Sources.** `messages.log` and `alerts.log` are the only sources with `LogSourcePort`'s offset-and-identity cursor (`Page` :709). They opt in through a descriptor key, which is an AD-5 addition.
   - **The route.** An OcuPilot route long-polls within `Kernel.Provider.TestCall.BoundSeconds`. Between waits it re-checks the file's size and identity, because no vendor event signals a log write. The pattern is iris-couch's `ChangesHandler` (`/Users/jbrandt/git/iris-couch/src/IRISCouch/API/ChangesHandler.cls` :208-260).
   - **AD-12.** Today no handler writes or flushes before its envelope; only `Response` and `Error` write. The heartbeat therefore needs an AD-12 carve-out.
   - **Rule amendments.** EXPERIENCE.md :646, :848 and :899 ("Tail, not live … live tail is P2") and AD-43 are amended in place.
   - **Tests.** The "nothing streams" pins in `ui/src/app/areas/logs/log-viewer.spec.ts` :279 and `src/OcuPilot/Test/Descriptor.cls` :1065 and :1109 are re-scoped to the sources that do not opt in.

**Why the scope is too big (evidence):**

- A new read source kind has been a whole story twice before (19.10 `sqlactivity`, 19.17 `docdb`).
- 18.33's spec covered one surface and reached 37 KB.
- Slices 3 and 4 each need an amendment to an architecture decision at the spec gate.
- Slices 2 and 3 each need a Task 0 measurement. This stage could not run one: `ocupilot-ci` was busy, and `ocupilot` was read-only.

## Code Map

These anchors were gathered for the re-plan. Paths are under `src/OcuPilot/` unless stated.

**Slice 1:**

- `Port/MonitorPort.cls`:
  - `Invoke` (:139) answers only `Sensors`/`SENSORS`.
  - `Parse` (:240) reads only unlabeled lines.
  - The seams are `GateClass`, `Source` and `LogFault`, through `Test/MonitorPortFixture`.
  - `Test/PortGate.cls` :29 lists the roster row `OcuPilot.Port.MonitorPort=PAIRS`.
- `Screen/Read.cls`:
  - `Execute` (:402) holds the source-port allow-list at :422, then the branches from :432 to :708.
  - Monitor exists only as a part kind (`PARTMONITOR` :220, `PartsObject` :890).
- `Screen/Registry.cls`:
  - `ReadProblem` (:1137) declares the port list at :1167.
  - The per-port arm to copy is sqlactivity's (:1260-1277).
  - The `%DB_IRISSYS:READ` rule is at :1578.
- `ui/tools/screen-mirror.mjs`: `READ_SOURCE_PORTS` (:981), the arm at :1387, and the pair rule at :1634.
- Five tests pin the "thirteen sources" sentence or the port list:
  - `Test/SqlActivityDescriptor` :54
  - `Test/DocDbDescriptor` :59
  - `Test/InteropDescriptor` :98
  - `Test/AdminPairCorpus` :58. Its example of an unknown port is `metrics`, so do not name the new port `metrics`.
  - `ui/tools/screen-mirror.test.mjs` :2782
- **DW-1872:**
  - The route-criterion guard (`Read.cls` :676-681) covers only `tBareRows`.
  - `DatabaseVolumeList`'s source is `VOLUMELIST` with no `rows` member and a one-part id, so a read without `dir` reaches the vendor. The vendor answers 400, and `AdminPort.Fail` logs it at severity 2.
  - The fix: require the route criterion for a parent-scoped `VOLUMELIST` read too.
  - `Test/ToolRoundTrip.cls` :89 `REFUSEEMPTY` changes `osmgmt.databasevolumes.read:PORT.VALIDATION` to `READ.CRITERION`, along with its doc comment.
- **DW-1898:**
  - `AdminPort.AwaitTask` logs the bound at :3409-3412, before the caller converts the 503 to started.
  - The callers that convert are `NamespacePort` :145, `DatabasePort` :461, `AuditPort` :99, `JournalPort` :252 and `EcpPort` :326. Together they cover all twelve `QUEUEDWRITES` pairs (:853).
  - The fix: skip the `LogFault` when `IsQueuedWrite` (:2758) holds. A read that reaches the bound still logs.
  - No test pins the log line yet. The seam is `Test/LogProbe`, as `AdminPortAsync.cls` :235 uses it.
- **Rosters:**
  - `Test/ReadTool.cls`: :93 (350 tools), :94 and :112.
  - `Test/Descriptor.cls`: `ReadShapes` :67.
  - `Test/Navigation.cls`: :494 (46 built screens in OS management).
  - `ui/tools/navigation.test.mjs` :139.
  - `Test/Wire.cls` :766.
  - `Test/WireSecurityRead.cls` :611, :618 and :621.
  - `Test/SurfaceCoverage.cls` `Coverage` :54.

**Slice 4:**

- `Port/LogSourcePort.cls`:
  - `Page` :709-815; the identity check is `Identity` :3429.
  - The window is `ReadWindow` :3488.
  - The port contract (:23) is that it never writes to the device.
- `Api/LogPage.cls` `Handle` :33; `Api/Router.cls` log routes :148-162.
- `Api/Response.cls`: the sole-writer contract is at :2.
- Client:
  - `ui/src/app/areas/logs/log-viewer.store.ts` (`loadNewer` :458, `read` :467) and `log-viewer.page.ts` :320.
  - `ui/src/app/core/turn.ts` :1704 is the chained-poll precedent.

**Shared constraints:**

- `Api/Error.cls` has 989 of its 1,000 parameters (ERROR #5290). New codes go in a sibling class modeled on `Api/RestServiceError.cls`, with prefix arms in `Error.ReasonForToolCode` :1211 and `ReasonForViolation` :1452.
- Entity types: 70 (`Kernel/EntityType.cls` :115).
- Fixed strings: about 3130 of the 3400 bound (computed, not taken from a test run).
- Bundle: 3.31 MB against the 3326kB warning.

## Tasks & Acceptance

Not planned. The plan halted at the size check (see Proposed Split). The re-plan of the narrowed 18.11 writes its tasks and criteria.

## Design Notes

**Ledger.**

- DW-1872 is addressed by slice 1 (Code Map).
- DW-1898 is addressed by slice 1 (Code Map). Its 18.20 occurrence (`EcpPort`) closes with it.

**Governing ADs:** AD-1, 2, 5, 7, 8, 12, 21, 26, 29, 36, 43 and 44.

**For the lead (Rule 20):**

- Slice 3's AD-8 question: may OcuPilot call an unchecked vendor escalation?
- Slice 3's AD-7 question: do the sensor setters write state?
- Slice 4's AD-12 carve-out for heartbeat bytes.
- Slice 4's AD-5 opt-in key.
- Slice 4's AD-43 and EXPERIENCE.md :899 amendment.
- No vendor defect candidate was found.

## Verification

Not planned. The re-plan writes it, with its `Shared surfaces:` line and the standing criterion.

## Auto Run Result

Status: blocked
Blocking condition: scope exceeds one implement pass and the 16 KB spec cap: four story-sized surfaces (Prometheus metrics table, dashboard drill-downs, interoperability usage, live log tail) plus DW-1872 and DW-1898; proposed split in ## Proposed Split (18.11 keeps the metrics table, DW-1872 and DW-1898; three new stories take the drill-downs, interoperability usage and the live tail). Narrowing 18.11's criteria and adding stories is Rule 5's ask-first tier, the lead's or orchestrator's call.
