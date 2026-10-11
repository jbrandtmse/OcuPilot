---
title: 'Story 18.11: Monitoring extras and the live log tail'
type: 'feature'
created: '2026-10-11'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: []
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

## Spec Change Log

- 2026-10-11, lead: narrowed on the orchestrator's split ruling (feature 39cb1e27, Rule 5): 18.11 keeps the metrics table, DW-1872 and DW-1898; the drill-downs, interoperability usage and live tail moved to Stories 18.36, 18.37 and 18.38 (their anchors are in this Code Map's slices 2 to 4, kept to seed them). The intent was narrowed to match and the Proposed Split section removed; status reset to `draft` for a re-plan in place.
