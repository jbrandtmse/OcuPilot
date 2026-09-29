---
title: 'Story 16.7: License usage and the full dashboard'
type: 'feature'
created: '2026-09-28'
status: 'done'
baseline_revision: '225ecdc1625d82a8c8e4b14476549b553a6ab4c1'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** License use and the instance's health are visible only on two classic pages: License Usage (a summary, plus usage by process, by user and distributed) and the System Dashboard (seven meter groups). OcuPilot's System usage draws seven meters and Home five rates, but no screen shows license use, CPU, ECP, alerts or the Task Manager.

**Approach:** Add two read-only OS-management screens over the ports that already exist.

- **License usage** is a four-tab group of lists. Each tab reads one member of the admin API's `Monitor` `LICENSEUSAGE` answer through `AdminPort`.
- **Dashboard** is a `meters` screen. Its one read merges `Monitor` `DASHBOARDMAIN` (through `AdminPort`) with a `MonitorPort` sensors part that supplies CPU, and draws the classic page's seven groups. Its Task manager group issues Upcoming tasks' own read.
- No write, no governance key, no route.

## Boundaries & Constraints

**Always:**

- **License usage: four descriptors**, tab group `os-management/license-usage` (AD-5, the OAuth 2.0 precedent). All four use source `{port: admin, endpoint: Monitor, type: LICENSEUSAGE, rows: <member>}`.

  | Tab | Route (position) | `rows` | Fields, name column first | Filter |
  |---|---|---|---|---|
  | 1 Summary | `os-management/license-usage` (side bar 7) | `Summary` | `LicenseUnitUse`, `Local`, `Distributed` | none |
  | 2 By process | `…/processes` (0) | `UsageByProcess` | `PID`, `Process`, `LID`, `Type`, `Con`, `Active`, `CSPCon`, `LU`, `Grace` | `Process`, `LID`, `Type` |
  | 3 By user | `…/users` (0) | `UsageByUser` | `UserId`, `Type`, `Connects`, `MaxCon`, `CSPCon`, `LU`, `Active`, `Grace` | `UserId`, `Type` |
  | 4 Distributed | `…/distributed` (0) | `ConnectionList` | `UserId`, `LicenseUnits`, `Connections`, `ServerIP`, `Instance` | `UserId`, `ServerIP` |

  Each tab also declares:
  - archetype `detail` and `refreshes: false`;
  - privileges `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, which the area covers, so no `ownPrivileges`;
  - `entityType ""`, scope `instance`, `id {kind: none}`, and no actions;
  - classic page `%CSP.UI.Portal.LicenseUsage`, with no exemption;
  - `context.fields` equal to the read's fields, and `paging: cap`;
  - the name column's field as the default sort, ascending;
  - tool identifiers `osmgmt.licensesummary`, `osmgmt.licenseprocesses`, `osmgmt.licenseusers` and `osmgmt.licensedistributed`;
  - the same three prompt keys. Two descriptors already share `agentTranscriptsPrompt1`-`3`, so sharing is accepted.
- **The `rows` read shape** (AD-36 as amended, Q1):
  - The read sends the vendor's `maxRows` as the cap plus one.
  - The answer must be an object whose `rows` member is an array of objects. Those objects are the rows, projected, filtered, sorted, capped and reported exactly as a `LIST`'s rows are.
  - Any other answer fails the whole read.
  - `Screen/Registry.cls` and `screen-mirror.mjs` accept `rows` only on an `admin` source with an upper-case bare type, and never beside `parts`, `forEach` or `rowGet`.
  - `AdminPort` `BARETYPES` gains `Monitor/LICENSEUSAGE`.
- **Dashboard descriptor:**
  - route `os-management/dashboard`, side bar 8, archetype `meters`;
  - `refreshes: true`, `refreshRates [5, 10, 30, 60]`, default off;
  - the same two pairs, `entityType ""`, `id none`, and classic page `%cspapp.op.utildashboard`;
  - aliases `dashboard`, `system dashboard` and `cpu`;
  - tool `osmgmt.dashboard`.

  Its read is `{port: admin, endpoint: Monitor, type: GET, parts: [{type: DASHBOARDMAIN, as: Dashboard}, {port: monitor, type: SENSORS, as: Sensors}]}`. It has 30 fields, which are the fields of the Meters table in Tasks, and declares `filter` and `sort` over all of them, as System usage does. Its `table` declares every field as a column, with `Dashboard.Status.UpTime` as the name column. `context.fields` equals the read's fields.
- **Empty states and prompts:**
  - Each License tab's `emptyStateKey` is its empty text (Docs). Each screen uses `emptyNextKey` `tableReadOnlyEmptyNext` and `emptyAgentKey ""`.
  - Dashboard's `emptyStateKey` is "The dashboard is unavailable."
  - The License prompts are in group `promptGroupCapacity`.
  - Dashboard's prompts are, in order: `promptGroupTroubleshooting`, `promptGroupCapacity`, `promptGroupTroubleshooting`.
- **The monitor part** (AD-36 and AD-29 as amended, Q2): `MonitorPort.Invoke("Sensors", "SENSORS", …)` has `AdminPort.Invoke`'s signature.
  1. It evaluates `PAIRS` first; on a refusal, no sensor call is made.
  2. It takes one collection and answers `{cpuUsage}` from the unlabeled `iris_cpu_usage`.
  3. Any other endpoint or type answers 500.

  A part is `admin` by default. A part fault fails the whole read. Home's `/ui/performance` still answers its five members.
- **Meters** use System usage's three kinds and its `app-meter`:
  - a **status** meter shows the vendor's word: `Normal` is success, `Warning` is warning, `Troubled` is error, and any other word is warning, shown as that word;
  - a **percent** meter uses DESIGN.md's cut-offs, 85 for warning and 95 for error;
  - a **value** meter has no state and no state color.

  Every meter shows "—" with a skeleton until its first value, puts its error in the tooltip, and never animates.
- **Task manager group:**
  - It issues Upcoming tasks' declared read (`tasks/upcoming`, AD-5) with `maxRows` 5 once per Dashboard tick, and draws those rows' At, Name and Suspended cells with that screen's own labels.
  - For a caller without that screen's pairs it shows "Requires <pair>" and reads nothing.
  - When there are no rows, it shows that screen's empty text.
- **Honest absence:**
  - ECP and shadowing on an instance with neither draw the vendor's words ("Normal") and traffic 0, as the classic page does.
  - The Distributed tab draws `ConnectionList` as the vendor answers it.
  - No state is invented.
- **Placement and copy:**
  - Side bar: License usage is position 7 and Dashboard is position 8.
  - The strings are folded into EXPERIENCE.md:375 in place and appended to `strings.ts`.
  - A value that already exists reuses its key.
  - EXPERIENCE.md stays 993 lines.
- **Bundle:** stay under `maximumWarning` 2107kB, or re-base it under DW-1166 to 5% above the measured size. Stop above 3800kB.

**Never:**

- No write tool, governance key, REST route, port, entity type, AD-27 case or arming variable.
- No call to `SYS.Monitor.SAM.Sensors.Alerts()` or `/api/monitor/alerts`, and no read that writes `^IRIS.Temp.SAM("LastAlertSent")` (DW-1116, AD-7).
- Product code must not name `^IRIS.Temp.SAM`, `SYS.Metrics` or `%SYSTEM.License`.
- No threshold or state the instance does not give: no "Normal" on a value meter.
- No change to System usage, Home or Upcoming tasks.
- No drill-downs (`DASHBOARDECP`, `DASHBOARDGLOBALS`, `DASHBOARDRESOURCES`, busy processes). They belong to Story 18.11.
- No reordering or reflowing of a contended list.
- No test that opens or holds a session on `ocupilot`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| License present | caller holds both pairs | Summary shows the vendor's 5 rows. By process shows one row per process holding a license entry | — |
| By user empty | only REST traffic | By user's empty state | — |
| Distributed, no license server | single-server key | the vendor's rows, which are the instance's own; the Summary's Distributed column carries the vendor's "Not connected to license server" | — |
| Over the cap | member longer than the cap | cut to the cap, and truncation reported; `maxRows` = cap + 1 was sent | — |
| Malformed | answer is not an object, or the member is not an array of objects | whole read fails | 500 generic, logged once; never partial |
| Dashboard present | caller holds both pairs | seven groups with CPU; status words; percent meters; value meters | — |
| Percent cut-offs | CPU or license use at 84, 85 or 95 | Normal, Warning, Troubled (word and color) | — |
| Sensors refused | a `MonitorPort` pair is missing (fixture gate) | whole read 403 naming the pair; sensor calls = 0 | `Denial` envelope |
| A part fails | `DASHBOARDMAIN` or sensor fault | whole read fails with that part's fault | no partial row |
| Operate missing | principal holding `%DB_IRISSYS:READ` without `%Admin_Operate:USE` | both screens unavailable; the five read tools refused naming the pair | 403 |
| Tasks pairs missing | Dashboard caller without `%Admin_Task:USE` | Task manager group shows "Requires %Admin_Task"; the other six groups draw | no fault stamp |
| Alert cursor | `LastAlertSent` undefined, or older than the newest line | unchanged after a Dashboard read and a License read | — |

</intent-contract>

## Code Map

**Server:**

- `src/OcuPilot/Screen/Read.cls`:
  - the executor guard :292 (it admits only the five list and object types);
  - the admin `LIST` branch: `tQuery("maxRows") = tMax + 1` :448, `Invoke` :454, the array check :460-463 (`rows` goes between them);
  - the parts branch :402-417 → `PartsObject` :638-679 (`Invoke` :650);
  - the port seams :127-194 (add `MonitorPortClass()`).
- `src/OcuPilot/Screen/Registry.cls`:
  - read sources :1037;
  - source types :1049 and :1814;
  - `PartsProblem` :2049-2060;
  - `TableProblem` :2209;
  - `TabProblem` :543 and `TabGroupProblem` :662 (positions 1..n with no gaps);
  - `SUGGESTEDPROMPTSMIN` :2558.
- `ui/tools/screen-mirror.mjs`:
  - `READ_SOURCE_PORTS` :943, checked :1183;
  - the prompt rules :2121-2151;
  - the parts and type rules sit beside `readProblem`.
- `src/OcuPilot/Port/AdminPort.cls`:
  - `BARETYPES` :587;
  - `EndpointType` :2156-2169, whose `ImplementsRead` :2183 admits every `Monitor` type.
- `src/OcuPilot/Port/MonitorPort.cls`: `PAIRS` :20, `METRICS` :31, `Performance` :62, the `Source()` seam :117, `Parse` :135 (exact bare names, all or nothing).
  - Fixture: `Test/MonitorPortFixture.cls`.
  - Callers: `Kernel/Shell/Performance.cls` and `Api/UiPerformance.cls`.
- **Descriptor precedents:**
  - `Screen/Descriptor/SystemUsage.cls`: a `meters` read over parts.
  - `OAuthServerDescriptionTab.cls` (listed tab 1) and `OAuthServerTab.cls` (tab 4, position 0): a tab group.
  - `TaskUpcomingList.cls`: the Task manager group's read, with pairs `%Admin_Task:USE` and `%DB_IRISSYS:READ`.
  - `Screen/Area.cls:109`: the OS management pairs `%Admin_Operate:USE`, `%Admin_Manage:USE` and `%DB_IRISSYS:READ`.
  - Side-bar positions 1-6 are taken; `NamespaceList.cls:27` holds 6.
- **Vendor code** (read-only; the hidden copies are in `scratchpad/epic-16/16-7/`):
  - `lic-cls_%Api.Admin.Endpoints.Monitor.txt` (scratch lines): types :12-24, `ResourcesOR` `%Admin_Operate` :26-29, `RunMain` :109-141, `RunLicenseUsage` :210-236.
  - `irissys/%CSP/UI/Portal/LicenseUsage.cls`: views :74-83, `RESOURCE` :22.
  - `irissys/SYS/Stats/Dashboard.cls:76-97`: the status words.
  - `irissys/%CSP/Util/HTMLDashboardPane.cls:291-311`: the classic indicator.

**Client:**

- `ui/src/app/shell/screen-outlet.ts`: `ARCHETYPE_PAGES` :85-96 (`meters` goes to `SystemUsagePage`) and `DESCRIPTOR_PAGES` :114-146, which must register `Dashboard`.
- `ui/src/app/shell/detail-page.ts`: the tab strip (`tabMembersFor`, `core/navigation.ts:309`) over `ListPage`.
- `ui/src/app/areas/os-management/`:
  - `system-usage.page.ts:125-147`: the refresh binding and `REFRESH_ACTION_ID`;
  - `system-usage.store.ts`: `METER_CONFIGS` :41-72 and `meterViewFor` :110-131, the pattern for the new store; its percent unit is the `%` literal;
  - `database-details.page.ts:69-80` and :277-291: a page that issues another screen's read into that screen's own store.
- `ui/src/app/shell/meter.ts` (`app-meter`) and `ui/src/app/core/meter-state.ts:26-31` and :40-44.
- `ui/src/app/core/strings.ts`: append after :3489, before `} as const` at :3490. These values exist, so reuse their keys:

  | Key | Value |
  |---|---|
  | `openApiColumnSummary` | "Summary" |
  | `processColumnPid` | "Process ID" |
  | `tableColumnType` | "Type" |
  | `sslPromptGroupConnections` | "Connections" |
  | `webSessionListLabel` | "Web sessions" |
  | `statusSegmentInstance` | "Instance" |
  | `performanceHeading` | "Performance" |
  | `performanceRateUnit` | "/s" |
  | `performanceCacheUnit` | the cache-efficiency unit |
  | `performanceDiskReads`, `performanceDiskWrites` | "Disk reads", "Disk writes" |
  | `systemUsage*` | the labels of :1046-1076 |
  | `processDetailsGlobalReferences` | "Global references" |
  | `systemInfoUptime` | "Uptime" |
  | `processListLabel` | "Processes" |
  | `errorLogListLabel` | "Application errors" |

  Uniqueness is enforced at `strings.test.mjs:732`.
- `ui/src/styles/_components.scss` (7,306 lines): the meter rules are at :4899-5020. Append at the end.
- EXPERIENCE.md: :101, :375, :629, :845.
- Bundle:
  - `ui/angular.json:51-57`, pinned at `angular-json.test.mjs:384-385`;
  - `build-output.test.mjs:168-199` fails above the warning;
  - the last build was 2,076,894 B, which leaves about 30 KB.

**Rosters (additive):**

- `Test/ReadTool.cls` :93 (140 → 145) and :94 (names).
- `Test/SurfaceCoverage.cls` (the row format is :107's).
- `Test/Descriptor.cls` ReadShapes :67-121.
- `Test/Wire.cls:700`.
- `Test/WireSecurityRead.cls` :549, :556 and :559. The System usage principal test at :694-712 is the model.
- `Test/ReadSourceCorpus.cls` :110-116.
- `Test/ScreenRead.cls` :199-200.
- `ui/tools/navigation.test.mjs` :133-222 and :233-244.
- `ui/tools/navigation-wire.test.mjs` :90-181.
- `ui/src/app/shell/rail-wire.spec.ts` :87-178.
- `browser/namespaces.browser-spec.mjs:377-384` pins `slice(0, 6)`, so it is unaffected.

## Tasks & Acceptance

**Execution:**

**Server:**

- `src/OcuPilot/Port/AdminPort.cls`: append `Monitor/LICENSEUSAGE` to `BARETYPES`. Nothing else.
- `src/OcuPilot/Port/MonitorPort.cls`:
  - add `Invoke` per Boundaries, with parameters `SENSORSENDPOINT`, `SENSORSTYPE` and `PARTMETRICS = "cpuUsage:cpu_usage"`;
  - `Parse` takes the metric list, defaulting to `METRICS`;
  - `Performance` is unchanged;
  - the doc comment states the measured `^IRIS.Temp.SAM` write (Design Notes).
- `src/OcuPilot/Screen/Read.cls`:
  - admit a bare type when `rows` is declared, and extract the member after `Invoke`, per Boundaries;
  - in `PartsObject`, route a `monitor` part to `MonitorPortClass()`'s `Invoke` with the sensors endpoint.
- `src/OcuPilot/Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`: accept and refuse `rows` and the part's `port` identically, each with its own sentence. Regenerate `ui/src/app/core/screens.generated.ts`.
- New descriptors under `src/OcuPilot/Screen/Descriptor/`:
  - `LicenseSummaryTab.cls`, `LicenseProcessTab.cls`, `LicenseUserTab.cls` and `LicenseDistributedTab.cls`, declared per Boundaries;
  - `Dashboard.cls`, declared per Boundaries and the Meters table.

**Client:**

- `ui/src/app/areas/os-management/dashboard.store.ts` (new, framework-free): `DASHBOARD_GROUPS` (groups in order, each with its meters: field, label key, kind, unit, and the percent field) and pure view functions after `meterViewFor`.
- `ui/src/app/areas/os-management/dashboard.page.ts` (new, `OnPush`):
  - the seven groups as sections with headings, each a meter grid;
  - the refresh binding, `REFRESH_ACTION_ID` and destroy, as System usage does;
  - the Task manager group per Boundaries;
  - register it in `screen-outlet.ts` `DESCRIPTOR_PAGES`.
- `ui/src/app/core/strings.ts`: append the Fixed strings below, keyed `licenseUsage*` and `dashboard*`, each cited `/** EXPERIENCE.md:375 */`.
- `ui/src/styles/_components.scss`: append `.ocu-dashboard-*` rules. Use tokens only.

**Meters (Dashboard, in order):**

| Group (heading) | Field → label · kind · unit |
|---|---|
| Performance | `Sensors.cpuUsage` CPU · percent · `%`<br>`Dashboard.Performance.GlobalRefsPerSecond` Global references per second · value · /s<br>`.GlobalRefs` Global references · value<br>`.GlobalSetKill` Global updates · value<br>`.RoutineRefs` Routine references · value<br>`.LogicalRequests` Logical block requests · value<br>`.DiskReads` Disk reads · value<br>`.DiskWrites` Disk writes · value<br>`.CacheEfficiency` Cache efficiency · value · refs per block read or write |
| ECP and shadowing | `Dashboard.ECP.ECPClients` Application servers · status<br>`.ECPClientTraffic` Application server traffic · value · bytes/s<br>`.ECPServers` Data servers · status<br>`.ECPServerTraffic` Data server traffic · value · bytes/s<br>`.ShadowConnections` Shadow source · status<br>`.Shadows` Shadow server · status |
| System status | `Dashboard.Status.UpTime` Uptime · value<br>`.LastBackup` Last backup · value |
| System usage | `Dashboard.SystemUsage.DatabaseSpace` Database space · status<br>`.DatabaseJournal` Database journal · status<br>`.JournalSpace` Journal space · status<br>`.JournalEntries` Journal entries · value<br>`.LockTable` Lock table · status<br>`.WriteDaemon` Write daemon · status<br>`.Processes` Processes · value<br>`.CSPSessions` Web sessions · value |
| Errors and alerts | `Dashboard.Alerts.SeriousAlerts` Serious alerts · value<br>`.ApplicationErrors` Application errors · value |
| Licensing | `Dashboard.Licensing.LicenseLimit` License limit · value · license units<br>`.LicenseUse` Current license use · percent · `%`<br>`.LicenseUseHigh` Highest license use · percent · `%` |
| Task manager | Upcoming tasks' read (Boundaries) |

- Counts and rates are whole numbers with grouping. Cache efficiency and traffic show one decimal.

**Docs (in place; EXPERIENCE.md stays 993 lines):**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - :101: the archetype column, per the Q3 ruling;
  - :629: the meter row's Where column gains "Dashboard";
  - :845: add Dashboard to the Auto-refresh roster (Q4);
  - :375: append the strings with `[ADDED 2026-09-28 - Story 16.7]`, and a Where clause naming License usage's tabs and columns and the Dashboard's headings, labels and units.
- The new strings:
  - "License usage"
  - "By process", "By user", "Distributed"
  - "License unit use", "Local", "Login ID", "User ID", "Active time", "Units", "Grace time", "Maximum connections", "License units", "Server IP"
  - "The instance reports no license summary.", "No process holds a license unit.", "No user holds a license unit.", "The instance reports no license connections."
  - "How many license units are in use, and how close is that to the limit?", "Which processes and users hold license units right now?", "Is this instance connected to a license server?"
  - "Dashboard"
  - "ECP and shadowing", "System status", "Errors and alerts", "Licensing", "Task manager"
  - "CPU", "Routine references", "Application servers", "Application server traffic", "Data servers", "Data server traffic", "Shadow source", "Shadow server", "Last backup", "Database journal", "Serious alerts", "License limit", "Current license use", "Highest license use"
  - "bytes/s", "license units"
  - "The dashboard is unavailable."
  - "Is any dashboard meter in a warning or troubled state?", "How busy is the instance right now, and how much CPU is it using?", "Have serious alerts or application errors been raised?"

**Rosters** (each item above, additive):

- The five read tools, five coverage rows and five ReadShapes rows.
- The OS-management JSON in `Wire` and `WireSecurityRead`.
- The two navigation tests and `rail-wire.spec.ts`: two listed entries and five routes.
- Corpus cases, valid and refused, for `rows` and the `monitor` part, in both engines.
- `ScreenRead`'s field-drift sweep takes the four `rows` reads.

**Tests:**

- `src/OcuPilot/Test/LicenseUsage.cls` (new; fixture port answers):
  - the four declarations and the tab group;
  - each member is projected to rows;
  - `maxRows` = cap + 1 is sent, and truncation is reported;
  - a non-object answer, and a non-array member, each fail the read;
  - an empty member reads as zero rows.
- `src/OcuPilot/Test/Dashboard.cls` (new; `MonitorPortFixture` and canned parts):
  - the declaration;
  - `Sensors.cpuUsage` is merged;
  - the monitor part's fault or 403 fails the read, with sensor calls = 0 on the 403;
  - `Invoke` refuses another endpoint or type;
  - `Performance` still answers five members.
- `src/OcuPilot/Test/DashboardLive.cls` (new; in-process on the instance; no principals):
  - the Dashboard read answers every field, with CPU a number;
  - Summary answers 5 rows;
  - By process answers at least one row with a `PID`;
  - `LastAlertSent` is unchanged across a Dashboard read and a License read. Save it, kill it, read, assert undefined, and restore in `OnAfterOneTest`. This runs on throwaways only, and the class header says so.
- `src/OcuPilot/Test/WireSecurityRead.cls`: one method, over `osmgmt.dashboard` and `osmgmt.licensesummary`, following the Locks test.
  - `BOTHUSER` is refused naming `%Admin_Operate:USE`.
  - `OPERATEONLYUSER` is refused naming `%DB_IRISSYS:READ`.
  - `OPERATEUSER` reads both with 200.
- `ui/tools/dashboard-store.test.mjs` (new):
  - the groups and field order;
  - a value meter carries no state;
  - percent cut-offs at 84, 85 and 95;
  - an unknown status word shows as warning with the vendor's word.
- `ui/src/app/areas/os-management/dashboard.page.spec.ts` (new):
  - seven headings;
  - skeletons before the first tick;
  - the Task manager group's rows, its "Requires" line and its empty text;
  - no live region on a tick.
- `ui/browser/license-usage.browser-spec.mjs` (new):
  - the OS-management side bar reads 8 entries in order;
  - the tab strip shows its 4 tabs;
  - Summary shows 5 rows; By process shows rows with a Process ID;
  - By user and Distributed each show rows or their empty text;
  - the DW-1337 structural gate passes, wide and narrow, light and dark.
- `ui/browser/dashboard.browser-spec.mjs` (new):
  - seven group headings in order;
  - a CPU meter with `%` and a state word;
  - "Database space" reads "Normal" with the success class;
  - a value meter carries no word;
  - the structural gate passes in both themes.

**Acceptance Criteria:**

- **AC1.** Given a caller holding `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, when License usage opens on `ocupilot-ci`, then its strip shows Summary, By process, By user and Distributed, and each tab lists the instance's rows for that view with the declared columns. The By user and Distributed tabs show their empty text when the instance answers none.
- **AC2.** Given the same caller, when Dashboard renders, then the Performance, ECP and shadowing, System status, System usage, Errors and alerts, Licensing and Task manager groups draw in that order.
  - Every status meter and percent meter shows its state as a word and a color.
  - Every value meter shows its value and unit with no state color.
  - CPU is a percent meter.
- **AC3.** Given a principal holding `%DB_IRISSYS:READ` without `%Admin_Operate:USE`, when it calls either screen's read, then it is refused naming `%Admin_Operate:USE`, as System usage refuses it. A principal holding `%Admin_Operate:USE` without `%DB_IRISSYS:READ` is refused naming that pair.
- **AC4.** Given the SAM alert cursor `^IRIS.Temp.SAM("LastAlertSent")`, when Dashboard and License usage read, then the cursor is unchanged (DW-1116, AD-7).
- **AC5.** Given Dashboard's chip set to 5 s, when two ticks arrive, then the meters update silently. With no rate remembered, the chip reads off.
- **AC6 (Integration).** Given the agent on each screen, when it calls that screen's read tool, then the rows and values it gets are the ones the screen draws, and the screen context carries the same fields. Both screens pass the DW-1337 gate with no new allowance. The bundle stays under its warning or is re-based as Boundaries allow.

## Spec Change Log

- 2026-09-29, spec gate (lead): the plan's four rulings answered (A) each; the orchestrator approved AD-7's third named shape (the vendor's sensor baseline, rewritten by `PrometheusMetrics()`, never the alerts cursor). Spine amended: AD-7, AD-29, AD-36, AD-43. DW-1116 is to resolve at this story's adjudication by AC4's pin. DW-118 declined (Story 15.6 resolved it). Status `blocked` to `ready-for-dev`.

## Review Triage Log

### 2026-09-29 — Review pass

- verdicts: 21 findings — high 0, medium 1, low 11, false 9, maybe-false 0
- findings:
  - `[medium]` `[patch]` VG: the Dashboard page's fault paths (meter tooltip, dashed values, kept words, `aria-busy`, the refused tasks line) had no test — added a fault-before-success, a fault-after-success and a refused-tasks case to `dashboard.page.spec.ts`; mutation recorded under Verification.
  - `[low]` `[patch]` VG: `MonitorPort.Collect`'s raise branch was never run through `Invoke` — added a raising-collection leg (500 `INTERNAL`, logged once, namespace restored) to `Dashboard.TestAMonitorPartRefusalOrFaultFailsTheWholeRead`; mutation recorded.
  - `[low]` `[patch]` VG: a misspelt License field passed `TestEachMemberIsProjectedToRows`, and the `ScreenRead` sweep's floor did not require the four tabs — asserted each declared field is a key of the vendor row, and the sweep now asserts it checked all four tabs; mutation recorded.
  - `[false]` `[reject]` VG: AC6's tool-versus-route and structural clauses carry no `mutation:` line — Rule 19 asks one demonstrated mutation per AC; AC6's (context fields) is recorded and was re-demonstrated this pass.
  - `[low]` `[patch]` VG: "no other action" was asserted on the generated `SCREENS` entry — the spec now records every action the page registers and asserts Refresh alone.
  - `[low]` `[reject]` VG: the alert-cursor row's "older than the newest line" state is not set up — the absent state is the one any advancing read must write, and an older cursor needs a vendor-format value only the forbidden alerts read produces (absent on both instances).
  - `[false]` `[reject]` IA: bundle against the literal 2107kB — the warning in force is 2217kB, re-based under DW-1166 by Story 18.14; the build measures 2,160,665 B.
  - `[false]` `[reject]` IA: `app-meter`'s two inputs and `Parse`'s metric list touch what System usage and Home share — both default to the old behavior; System usage's and Home's specs and `MonitorPort`, `UiPerformanceWire` ran green, and `Parse`'s list is the spec's own task.
  - `[false]` `[reject]` IA: Operate-missing is pinned on the read route, not the agent tool — the route and the read tool both gate on the descriptor's pairs through `Screen.Gate`, and the `SECUREUSER` roster asserts both screens unavailable naming `%Admin_Operate:USE`.
  - `[low]` `[patch]` IA: the gated Task manager case did not assert "no fault stamp" — it now asserts no refused line and no meter tooltip.
  - `[false]` `[reject]` IA: the tasks read could be sent before the navigation map answers — `screen-outlet.ts` mounts no page until the map has answered, so the verdict is known when the page is built.
  - `[low]` `[reject]` IA: the Dashboard writes its tasks answer into Upcoming tasks' store — AD-5's cross-screen read, as Database details does; Upcoming's table draws a skeleton until its own read lands, and keeping the rows elsewhere needs a second store key or component state AD-19 forbids.
  - `[low]` `[reject]` IA: By user's empty state is pinned at the server, and the browser accepts rows or the empty text — whether a unit is held depends on the instance's sessions; the empty state is `ListPage`'s shared path.
  - `[low]` `[reject]` IA: "Not connected to license server" is asserted only on the fixture — pinning the vendor's localizable words on the live instance adds a fragile check; projection passes vendor values unchanged.
  - `[false]` `[reject]` IA: Malformed's "logged once" is not asserted — `Read.Execute` returns the status and the route writes it through `Api.Error.RenderInternal`, which logs once (AD-12).
  - `[false]` `[reject]` IA: the cut-offs are exercised on CPU only — both license meters are pinned percent-kind and take the same `meterStateFromPercent`.
  - `[low]` `[reject]` IA: the alert cursor's older state is not set up — as the VG row above.
  - `[false]` `[reject]` IA: Home's `/ui/performance` route is not requested — `UiPerformanceWire` exercises the route and ran green.
  - `[low]` `[reject]` IA: the Dashboard page never renders its empty text — the key is declared as the spec asks, and the page follows System usage, which shows a fault as meters with the tooltip.
  - `[false]` `[reject]` IA: every meter's tooltip is one generic text — that is System usage's contract, which the spec adopts.
  - `[low]` `[reject]` IA: `DashboardLive`'s throwaway-only rule is a doc comment — the spec forbids a new arming variable, and `OnAfterOneTest` restores the cursor.
- stage: `Wire` and `WireSecurityRead`'s OS management roster messages still counted eighteen screens — corrected to twenty-three, with the new screens named (messages only).

## Design Notes

**Ruling (lead, spec gate 2026-09-29; the orchestrator raised no objection, and approved the AD-7 amendment at the merge gate): (A) on Q1-Q4.** The spine is amended in the same commit: AD-36 (`source.rows`; one `MonitorPort` part), AD-43 (the set is nine), AD-7 (the sensor-baseline shape) and AD-29 (measured). EXPERIENCE.md :101 and :845 are this story's in-place edits. The plan's options, for the record:

- **Q1. AD-36: a list over one member of a bare-type answer.**
  - The problem: `Monitor` `LICENSEUSAGE` answers one object with four row arrays. Today's grammar issues a bare type only as a `part`, which merges as one row, so none of AC1's four views is expressible.
  - **(A), recommended:** `source.rows`, as in Boundaries. Suggested text: "A bare admin type whose answer is one object holding row arrays may be read as a list over one named member (`source.rows`). The read sends the vendor's `maxRows` as the cap plus one, and any other answer fails the read (License usage, Story 16.7)."
  - (B) A new source key on a port that calls `AdminPort` and returns one member: a port calling a port.
  - (C) Ship the summary only. This narrows AC1, so it is the owner's call.
- **Q2. AD-36 and AD-29: a `MonitorPort` part.**
  - The problem: CPU (`iris_cpu_usage`) exists only in the sensors, and 6.9's criteria leave CPU to this dashboard.
  - **(A), recommended:** a parts entry `{port: monitor, type: SENSORS, as}`, answered by `MonitorPort` behind its own gate. Both ports gate the same two pairs.
  - (B) A `monitor` source whose `Dashboard` endpoint composes `AdminPort`'s answer: a port calling a port.
  - (C) Draw CPU from `/ui/performance` beside the read. Screen and tool would then diverge, which AD-36 forbids.
  - (D) No CPU.
- **Q3. EXPERIENCE.md:101: License usage's archetype.** The row pairs four archetypes with five surfaces, and the epic context reads License usage as `meters`.
  - **(A), recommended:** a four-tab group of `detail` lists. `DetailPage` and `ListPage` give the strip, sort, filter and CSV with no new page. The classic page has the same four views.
  - (B) A `meters` page drawing four page-issued reads. It is more code in a 30 KB bundle margin, and the only license meter would be matched by a localized vendor label.
- **Q4. AD-43: Dashboard joins auto-refresh**, making the set nine. The classic page refreshes every 60 s, measured; the default stays off.
  - **(A), recommended:** join, and update AD-43 and EXPERIENCE.md:845 together.
  - (B) Read on open only.

**For the lead to record (apply and report):**

- **AD-7 / AD-29, measured on `ocupilot-ci` 2026-09-28:**
  - Each `PrometheusMetrics()` rewrites 24 `^IRIS.Temp.SAM` nodes (`pv`, `cpu`, `CPUState`, `LastCollection`) and never `LastAlertSent`.
  - AD-29's "(inference)" becomes this measurement. AD-7's derived-cache paragraph names it as a second instance.
  - AD-7 should add: "the vendor's SAM alerts read advances the shared `LastAlertSent` cursor and is never called (DW-1116)".
- **DW-1116**, recommended `resolved-by:16-7-license-usage-and-the-full-dashboard` at adjudication:
  - The errors-and-alerts group reads `DASHBOARDMAIN`'s counts.
  - None of `DASHBOARDMAIN`, the other `Monitor` types, `SYS.Stats.Dashboard.Sample()` or the classic page render wrote the cursor.
  - The positive control, `GET /api/monitor/alerts`, did.
  - AC4's test pins it.
- **DW-118** is declined: Story 15.6 resolved it, as 16.18 recorded.

**Measured, 2026-09-28** (scripts and answers are in `scratchpad/epic-16/16-7/`):

- **`LICENSEUSAGE`:**
  - It answers `{UsageByProcess, UsageByUser, Summary, ConnectionList}` from `%SYSTEM.License` `ProcessList`, `UserList`, `Summary` and `ConnectionList`.
  - It honours only `maxRows`, which caps every array and defaults to 1000.
  - It is synchronous and takes about 9 ms.
  - Over HTTP on `ocupilot-ci`, `%Admin_Operate:USE` alone read 200. `%DB_IRISSYS:READ` alone, and `%Admin_Manage:USE` alone, answered 403.
  - The screens also declare `%DB_IRISSYS:READ`, because `AdminPort` enters `%SYS` in process, as System usage declares it.
- **On `ocupilot`:**
  - Summary has 5 string rows; its `Distributed` column reads "Not connected to license server".
  - By process has 27-28 rows, all `System`.
  - By user and `ConnectionList` are `[]` under REST traffic. One terminal session added a row to each, with `ServerIP` 127.0.0.1.
  - The key is Community, "Concurrent User", 8 units, `KeyServer` "Single". The classic page disables Distributed there and hides every view on a Core Capacity key.
- **`DASHBOARDMAIN`** (`SYS.Metrics.GetMainMetrics`, whose status and message the endpoint drops):
  - The status words are present for `DatabaseSpace`, `DatabaseJournal`, `JournalSpace`, `LockTable`, `WriteDaemon` and the four ECP and shadow members.
  - `LicenseUse` and `LicenseUseHigh` are percentages (13 = 1 of 8 units).
  - The values are the Application Monitor's cached sample, as the classic page shows them.
  - Mapping ECP and shadow members to the classic captions follows both lists' order (inference).
- **Serious alerts and application errors:** Serious alerts equals `$SYSTEM.Monitor.Alerts()`, the clearable counter (inference). Application errors read 0 against older `^ERRORS` rows (inference: today's errors).

**Decisions:**

- **Meter kinds.** Status, percent and value are Story 6.9's reading of the same meter criterion, so a value meter carries no state.
- **Task manager uses Upcoming tasks' read** rather than `DASHBOARDMAIN`'s `UpcomingTasks`, which the grammar cannot project. That read is never wider than the caller's own pairs (AD-5).
- **Side bar 7 and 8.** Namespaces took 6 in Story 18.2. :164 is contended and is not reordered.
- **Summary rows sort by their label.** The vendor's order is not a field.

**Parity gaps, stated:**

- The API casts `SystemMonitor` to a boolean that reads `false` on both instances, so it is not drawn. This is a candidate IRIS defect report.
- `LastBackup`'s "never backed up" warning, Transactions and every per-meter message exist only in the vendor's dropped status.
- Most active processes and the drill-downs belong to Story 18.11.
- No license filters beyond `ListPage`'s, no Core Capacity note, and no License usage auto-refresh.

**Governing ADs:** AD-1, AD-2, AD-5, AD-7, AD-8, AD-11, AD-12, AD-16, AD-19, AD-20, AD-24, AD-26 (every `Monitor` type is synchronous), AD-27 (no new case), AD-29, AD-36, AD-39, AD-43, AD-44, AD-60, and NFR-1 (under 100 ms a read, plus one 60-70 ms collection).

**Integration ACs:**

- **Consumes:** `AdminPort` `Monitor` (6.9), `MonitorPort` (16.18), `TaskUpcomingList`'s read, `DetailPage`'s strip, `app-meter`, and the AD-43 framework.
- **Consumed-by:**
  - the `rows` shape: the four License tabs and their tools (AC1, AC6);
  - the monitor part: Dashboard and `osmgmt.dashboard.read` (AC2, AC6);
  - Story 18.11's drill-downs and 18.6's license pages, which sit beside these screens (inference).

**Contended, additive only:**

- `Read.cls` and `AdminPort.cls`. Epic 18's hunks are at `Read.cls` :424-442 and :703 and at `AdminPort.cls` :306-333 and :487-498; this story's are :292, :448-463 and :638-679, and :587.
- `screen-mirror.mjs`, `strings.ts`, `_components.scss`.
- EXPERIENCE.md :101, :375, :629 and :845. Epic 18 edits :164, :172, :378 and :479-480.
- The rosters listed above.

## Verification

**Commands:**

- `rsync -a --delete src/ /tmp/ocupilot-ci/src/`, then `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-16/compile.sh <changed paths>`, then `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>`, one class per call (loop). Run:
  - `LicenseUsage`, `Dashboard`, `DashboardLive`, `MonitorPort`, `SystemUsage`;
  - `ReadSourceCorpus`, `Descriptor`, `ReadTool`, `SurfaceCoverage`, `ScreenRead`;
  - `Wire` and `WireSecurityRead` (known residue: the task-history test).

  Expected: green.
- `cd ui && node tools/screen-mirror.mjs --check && node --test tools/dashboard-store.test.mjs tools/system-usage-store.test.mjs tools/meter-state.test.mjs tools/performance.test.mjs tools/screen-mirror.test.mjs tools/navigation.test.mjs tools/navigation-wire.test.mjs tools/strings.test.mjs tools/citations.test.mjs` (loop). Expected: green.
- `cd ui && npx ng test --include src/app/areas/os-management/dashboard.page.spec.ts --include src/app/areas/os-management/system-usage.page.spec.ts --include src/app/shell/detail-page.spec.ts --include src/app/shell/rail-wire.spec.ts` (loop). Expected: green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/license-usage.browser-spec.mjs browser/dashboard.browser-spec.mjs browser/system-usage.browser-spec.mjs browser/home-performance.browser-spec.mjs browser/namespaces.browser-spec.mjs` (loop). Expected: green in both themes.
- `cd ui && npm test` (once, before dev_complete). Expected: green, and the bundle stays under the warning or is re-based.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete). Expected: green apart from the known residue. The full browser suite is CI's.

**Planned mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | read the whole object instead of the `rows` member | `LicenseUsage` projection and the browser AC1 |
| AC2 | give `GlobalRefs` the status kind | `dashboard-store` "a value meter carries no state" |
| AC2 | drop the monitor part | `Dashboard` CPU merge, and the browser CPU meter |
| AC3 | drop `%DB_IRISSYS:READ` from `Dashboard.cls` | the `WireSecurityRead` refusal leg |
| AC4 | call the vendor alerts read in `MonitorPort.Invoke` (throwaway only) | `DashboardLive` cursor test |
| AC5 | `refreshes: false` on `Dashboard.cls` | the `dashboard.page.spec` refresh case |
| AC6 | drop `Sensors.cpuUsage` from `context.fields` | the `Dashboard` context case |

**Mutations demonstrated (Rule 19; each reverted, tree fingerprint unchanged):**

- mutation: `Read.Execute` keeps the whole `LICENSEUSAGE` answer instead of `RowsMember` → `LicenseUsage` (four of five methods, "answered something other than a list") and browser `license-usage` AC1 (no row renders) went red.
- mutation: `dashboard.store.ts` gives `Dashboard.Performance.GlobalRefs` the status kind → `dashboard-store` "a value meter carries no state" (and the field-kind roster) went red.
- mutation: the Dashboard's monitor part removed, with `Sensors.cpuUsage` dropped from its fields, filter, sort, table and context so the registry still validates → `Dashboard` `TestTheSensorsCpuIsMerged` (plus the declaration, context and refusal methods) and, against the unchanged deployed bundle, browser `dashboard` AC2 (the CPU meter never shows a word) went red.
- mutation: `%DB_IRISSYS:READ` removed from `Dashboard.cls` → `WireSecurityRead.TestTheDashboardAndLicenseUsagePairSetsAreEnforcedForARealPrincipal`, operate-only refusal leg, went red.
- mutation: `MonitorPort.Collect` calls the vendor alerts read (`SYS.Monitor.SAM.Sensors.Alerts()`, which needs a stub `%request`) on `ocupilot-ci` → `DashboardLive.TestTheAlertCursorIsUnchangedByTheDashboardAndLicenseReads` went red ("and leaves the cursor absent"); the cursor was killed back to its prior absent state afterwards.
- mutation: `refreshes: false` (rates `[]`) on `Dashboard.cls`, mirror regenerated → `dashboard.page.spec` refresh case and the `Dashboard` declaration test went red.
- mutation: `Sensors.cpuUsage` dropped from `Dashboard.cls` `context.fields` → `Dashboard.TestTheScreenContextCarriesTheReadsFields` went red.
- mutation: By process's `rows` set to `UsageByUser` → `LicenseUsage` declaration, projection and cap tests went red.
- mutation: `maxRows` sent as the cap rather than the cap plus one → `LicenseUsage.TestTheCapPlusOneIsSentAndTruncationIsReported` went red.
- mutation: `RowsMember` skips its element check → `LicenseUsage.TestAMalformedAnswerFailsTheWholeRead` ("an array of strings") went red.
- mutation: `MonitorPort.Invoke` drops its gate call → `Dashboard.TestAMonitorPartRefusalOrFaultFailsTheWholeRead` went red; drops its endpoint and type check → `Dashboard.TestInvokeRefusesAnotherEndpointOrType` went red.
- mutation: the percent warning cut-off moved from 85 to 86 in `meter-state.ts` → `dashboard-store` cut-off case went red.
- mutation: the Dashboard page's `[skeleton]` binding removed → `dashboard.page.spec` skeleton case went red.
- mutation: `dashboard.page.ts` hands every meter `null` in place of the page's fault text → `dashboard.page.spec`'s two read-fault cases went red.
- mutation: `MonitorPort.Collect`'s catch no longer restores `$NAMESPACE` (`MonitorPortFixture` recompiled) → `Dashboard.TestAMonitorPartRefusalOrFaultFailsTheWholeRead` went red at its raising-collection leg.
- mutation: `ScreenRead`'s field-drift sweep skips `rows` reads → its four License usage floor assertions went red.

## Auto Run Result

Status: done
Blocking condition: none

This pass (implement stage re-spawned 2026-09-29 over the killed stage's uncommitted work; `baseline_revision` recaptured at `225ecdc1`, the diff since it carrying the whole story):

- **Implemented:** `source.rows` (Read, Registry, mirror, corpus), the `monitor` part and `MonitorPort.Invoke` (with an empty AD-59 `Snippet`/`SnippetForm`, every branch a read), `AdminPort` `BARETYPES` `Monitor/LICENSEUSAGE`, the four License usage tab descriptors and `Dashboard`; `dashboard.store.ts`, `dashboard.page.ts` (registered in `DESCRIPTOR_PAGES`), `app-meter`'s default-off `text` and `skeleton` inputs, strings, styles; EXPERIENCE.md :101, :375, :629, :845 in place (993 lines); tests `LicenseUsage`, `Dashboard`, `DashboardLive`, a `WireSecurityRead` method, `dashboard-store.test.mjs`, `dashboard.page.spec.ts`, two browser specs, and the additive rosters (ReadTool 159, SurfaceCoverage, ReadShapes, Wire, WireSecurityRead, Navigation, the two navigation tests, `rail-wire.spec.ts`, ScreenRead's sweep).
- **Changed this pass:** the review patches in the triage log (three Dashboard page fault cases and a recorded-actions check; a raising-collection leg in `Test/Dashboard.cls`; a field-key assertion in `Test/LicenseUsage.cls`; the License floor in `Test/ScreenRead.cls`'s sweep), the `Wire`/`WireSecurityRead` roster messages, and the implementation subagent's two edits (a `ScreenRead` doc sentence; the page spec's refresh case firing two ticks).
- **Review:** 21 findings (verification-gap, intent-alignment); 5 patched (1 medium, 4 low), 0 deferred, 16 rejected (9 false, 7 low) with reasons in the triage log. Follow-up review recommended: false (one medium patched, no high).
- **Verification:** whole `src/` reloaded and compiled on `ocupilot-ci` with no error; the Verification classes green (WireSecurityRead only its known task-history residue); `screen-mirror --check` and the nine tool files (165 pass); the targeted vitest specs (40, then 11 for the patched page spec); `npm run build` 2,160,665 B (warning 2217kB), redeployed, and the five browser specs 18/18 in both themes; full `npm test` 1705 tool + 1805 component, green; the full ObjectScript sweep once, 360 classes and 2,736 tests with 6 failures, all residue: `WireSecurityRead` task history, `TaskHistory` 3, `PathPortInstance` overwrite, and `ProposalPrivilege.TestAMintRecordsItsArgumentPairs` (the throwaway's `%SYS` holds 1,025 application errors, over the delete's list cap; today's 90 are all `<FUNCTION>Load+44^Config.Devices.1`), plus 28 classes refusing on arming variables. Matrix Test Audit: every row has a passing test; Malformed's "logged once" is the route's `RenderInternal` (AD-12).
- **Mutations:** AC1, AC2, AC3, AC5 and AC6 re-demonstrated by the stage; AC4 and the rest by the implementation subagent in this run; the three new lines by the stage. Each reverted, tree fingerprint unchanged.
- **Outside the Code Map:** `ui/src/app/shell/meter.ts`, `meter.spec.ts`, `Test/Read/ReadFixture.cls`, `Test/ReadSource/Endpoint.cls`, `Test/Navigation.cls` (its count comment reflowed, a merge surface beside Epic 18's rosters), `ui/tools/screen-mirror.test.mjs`.
- **Residual risk:** the Dashboard writes its five-row tasks answer into Upcoming tasks' store, as Database details does for volumes; Upcoming's own read replaces it on open.
