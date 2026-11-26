---
title: 'Story 24.17: Managed alerts, logs, the system monitor and workflow (Batch 5: the Interoperability System Monitor and the README)'
type: 'feature'
created: '2026-11-26'
status: 'in-review'
baseline_revision: 'ee5bdb591f41c253c9ecc2f1e7059977d218d075'
review_loop_iteration: 0
followup_review_recommended: true
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-17-managed-alerts-logs-the-system-monitor-and-workflow-2.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-17-managed-alerts-logs-the-system-monitor-and-workflow-5.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The System monitor page issues the row read and three table reads together on each tick, and overlapping vendor calls may answer an idle instance.
    evidence: |-
      The vendor answers other processes as idle while one call holds its locks; the page's four reads are separate web requests (inference). No test issues overlapping reads with a production running.
    location: >-
      ui/src/app/areas/interoperability/interop-system-monitor.page.ts (tick)
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** OcuPilot has nothing for the classic Interoperability System Monitor (`%CSP.UI.Portal.EnsembleMonitor`), so the instance-wide view of running productions, their throughput, jobs and queues, and the instance's own status cannot be read, and the README's Interoperability paragraph names none of this story's five batches.

**Approach:** Batch 5, the story's last (Batch 1's split, item 5). **System monitor**, a `meters` screen, and three unlisted drill-downs, **Most active processes**, **Most active queues** and **Upcoming tasks**, each one instance-wide read through `InteropPort` of `%SYS.Ensemble.GetEnsMetrics`, the classic page's own call, made in `%SYS` inside `PurgeFrame` (AD-9's containment). No write. Then the README's Interoperability paragraph names what a person does on the five batches' screens. "Round-trips" means: with the probe production running and then stopped, each reader answers what the vendor answers at that moment.

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains `SystemMonitor`, `SystemMonitorProcesses`, `SystemMonitorQueues` and `SystemMonitorTasks`, each `LIST` only, none in `SEARCHENDPOINTS`, none in `IsAnyWrite`. Each makes one vendor call: `PurgeFrame` with a new kind `metrics` calls an overridable `VendorMetrics`, which saves `$NAMESPACE`, switches to `%SYS`, calls `##class(%SYS.Ensemble).GetEnsMetrics("", 0, .values, .status, .msg)` and restores, calling nothing of OcuPilot's while in `%SYS` (OcuPilot is not compiled there, measured at plan). The caller saves `$NAMESPACE` before the frame and restores it first on every path; a fault is logged after the restore with a fixed message and the vendor's codes alone.
- **Rows.** `SystemMonitor`: one row of the classic page's 25 scalar meters, named as the vendor names them (`EnsembleMonitor.cls:218-773`): `EnsNamespace`, `EnsProductionsRunning`, `EnsProductionsTroubled`, `EnsIncomingRequests`, `EnsLastIncomingRequest`, `EnsOutgoingRequests`, `EnsLastOutgoingRequest`, `Processes`, `EnsJobs`, `EnsVisitingJobs`, `UpTime`, `LastBackup`, `DatabaseSpace`, `DatabaseJournal`, `JournalSpace`, `JournalEntries`, `LockTable`, `WriteDaemon`, `EnsActiveQueues`, `SeriousAlerts`, `EnsAlerts`, `EnsErrors`, `LicenseLimit`, `LicenseUse`, `LicenseUseHigh`; each the vendor's value as text. The drill-downs parse the classic table meters' encoding (rows `^`, columns `;`, `HTMLTableMeter.cls:50-54`, `:110-112`): Processes `{Namespace, Item, Pid, Commands}` (`EnsBusyProcesses`, :412), Queues `{Namespace, Queue, Messages}` (`EnsBusyQueues`, :608), Tasks `{Task, ScheduledFor, Status}` (`UpcomingTasks`, :764); in the vendor's order, a row whose columns are all empty dropped; capped by `SYSTEMMONITORROWSMAX` (provisional 100), truncation reported (AD-36).
- **Gate (AD-29, AD-8), before any vendor call; never cached.** The pairs only, then no namespace test: the read is instance-wide, takes no namespace, and ignores the request's. Pairs (veto item 2): `%Ens_Portal:USE` and `%Ens_Dashboard:USE` (the Production monitor's `MONITORPAIRS`, `InteropPort.cls:260`; the classic page's `RESOURCE`, `EnsembleMonitor.cls:21`, and the vendor's `BasicChecks`, `Ensemble.cls:193`), and `%DB_IRISSYS:READ` (the switch to `%SYS`, AD-29's MonitorPort measurement), plus any pair Task 0 (b) measures.
- **Containment (AD-9).** `GetEnsMetrics` adds `%All` for a caller without it (`$$$AddAllRoleTemporaryInTry`, `Ensemble.cls:199`, `%sySecurity.inc:426`) in its own frame. OcuPilot runs it inside `PurgeFrame`'s `New $ROLES` and adds no role; `$ROLES`, `$USERNAME` and `$NAMESPACE` read the same afterwards on success, error status and raise. `scripts/check-objectscript.py` rule 6 is unchanged.
- **Faults.** A vendor error status answers 500 `INTERNAL` (403 `PORT.ACCESSDENIED` for `#940` or `<PROTECT>`, as `Statused`); never 200, no vendor text logged. No new error code.
- **Screens (AD-5, AD-43, AD-44).** `System monitor`: area `interoperability`, side bar 29, `meters`, scope `instance`, id `none`, entity `""`, no action, auto-refresh 5/10/30/60 s off by default as the Production monitor, `classicPage` `%CSP.UI.Portal.EnsembleMonitor`, tool `interop.systemmonitor`. The three drill-downs: side bar 0, `list`, scope `instance`, no refresh, no criterion, the same classic page, tools `interop.systemmonitorprocesses`, `.systemmonitorqueues`, `.systemmonitortasks`; the page draws each table from its drill-down's declared read and links its heading there.
- **README.** The Interoperability paragraph gains veto item 1's clauses, and `interop.test.mjs`'s paragraph assertion takes the same text. No `false` key: the switched-off count stays as the Baseline derives it.
- **Standing rules, each with its test.** No write tool: `ToolWrite` and `SurfaceCoverage` classify the four tools `read`, and `ConfirmNamespaceRoster`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline` run green unchanged. No proposal and no draft: `SnippetForm` answers `""` for the four endpoints (`InteropSystemMonitorRead`). Nothing of OcuPilot's while switched (`InteropSystemMonitorFrame`). `Api/Error.cls` and `InteropError.cls` unchanged. Caps named and boundary-tested; the vendor call's time bound measured with the 1.5x rule (Task 0 (d)). Fixtures move no id: the probe production is `Test/ProductionProbe`'s in USER, principals `OcuP2417m*`.

**Never:**

- A `New $ROLES` outside `PurgeFrame`, `Set $ROLES`, `AddRoles`; any `SYS.EnsMetrics`, `SYS.Metrics` or `%CSP.Util.*` call; any `EnsPortal.*` or `%CSP.UI.Portal.*` call in product code (the descriptors name the classic page as a string only).
- A vendor message (`msg`) or status word (`status`) carried beside the values (named limit, Decided in-stage 7).
- A write, a governance key, an entity type; any edit to `Kernel/Proposal/Prohibited.cls`, `EntityType.cls`, `Baseline.cls`; a spine edit.
- Batch 3a's file prohibitions, unchanged (`ui/angular.json`, `ui/vitest-base.config.mjs`, `ci-throwaway.sh` beyond one add-only `# classes:` line, Epic 21's three `shell/` files beyond add-only map entries).

## I/O & Edge-Case Matrix

The probe production is `ProductionProbe`'s in USER; HSCUSTOM runs none.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Read, both readers | Probe production running, then stopped | One row; the stable meters (`EnsProductionsRunning`, `EnsNamespace`, `LicenseLimit`, `UpTime`'s form) equal a vendor call made beside it; running counts USER, stopped does not | - |
| Drill-downs | The vendor's three tables | Rows parsed in order, padding dropped | - |
| Any scope | Read with scope USER, HSCUSTOM, and a namespace without interoperability | The same answer | - |
| Gate | No `%Ens_Dashboard:USE`; no `%Ens_Portal:USE`; no `%DB_IRISSYS:READ` | Refused before any vendor call | 403 naming the pair |
| Roles | Seam adds a role, then succeeds; then raises | `$ROLES`, `$USERNAME`, `$NAMESPACE` after equal before | - |
| Vendor error | Seam answers an error status | Never 200; no vendor text logged | 500 `INTERNAL` |
| Raise in `%SYS` | Seam switches to `%SYS` and raises | Namespace restored before the fault is logged | 500 `INTERNAL` |
| Cap | Cap seam 3: three rows, then four | Three; four listed as three with truncation, each drill-down | - |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `bf1dcdf71`). **(c)** marks a file Epic 21 changed beyond feature at plan: `README.md`, `Screen/Titles.cls`, `strings.ts`, `screens.generated.ts`, `screen-outlet.ts`, `ci-throwaway.sh`, `EXPERIENCE.md` and the rosters `ClassicPageGate`, `Descriptor`, `ReadDescriptions`, `ReadTool`, `StageTwoTools`, `SurfaceCoverage`, `ToolEmit`, `ToolRoundTrip`, `navigation.test.mjs`, `screen-mirror.test.mjs`. Add-only there; re-check before editing.

- **`Port/InteropPort.cls`** (16,217 lines): `ENDPOINTS` :128, `MONITORPAIRS` :260, `Endpoints` :1126, `Pairs` :1253 (Monitor branch :1287), `Serves` :1350, `Invoke` :1479 (the new branch goes before `Admit` :1494, as an instance gate of pairs only), `Admit` :1645, `Statused` :3806, `Deny` :3859, `LogFault` :3853, `SnippetForm` :7039, `PurgeFrame` :12348 (gains the kind; its doc names the unswitched entry for `metrics`), `VendorCodesStatus` (beside :12330), `LOGKIND*` :15942 (the `metrics` kind beside them), `LogMapped` :15996 (shape of a `MonitorMapped`), `VendorLogPurge` :16004 (shape of `VendorMetrics`), `AlertCap` :13227 (cap form).
- **Vendor (read-only, read at plan):** `irissys/%SYS/Ensemble.cls` (`GetEnsMetrics` :189-206, `BasicChecks` :273-316, `%All` skips the resource check :284); `irissys/%sySecurity.inc` :421-426; `irissys/SYS/EnsMetrics.cls` (`GetMainMetrics`, deployed: no body, measured `Deployed` 1); `irissys/%CSP/UI/Portal/EnsembleMonitor.cls` (`RESOURCE` :21, meters :218-773); `irislib/%CSP/Util/HTMLDashboardPane.cls` (`CalculatePropertyValues` :710-728, the call shape); `irislib/%CSP/Util/HTMLTableMeter.cls` :50-54, :110-112; `irislib/EnsPortal/Application.cls` :138 (the menu entry).
- **Descriptors (new):** `Screen/Descriptor/InteropSystemMonitor.cls` (siblings `Dashboard.cls`, the meters shape, and `InteropMonitorList.cls`, the area and pairs); `InteropSystemMonitorProcesses.cls`, `...Queues.cls`, `...Tasks.cls` (sibling `DashboardProcesses.cls`, Story 18.36's drill-down). Each declares `privileges` as veto item 2 and `ownPrivileges` `%Ens_Dashboard:USE` and `%DB_IRISSYS:READ`, as `InteropMonitorList.cls` :25 declares its own pair.
- **Client (`ui/src/app/`):** `areas/interoperability/interop-system-monitor.page.ts` and `.store.ts` with specs (siblings `areas/os-management/dashboard.page.ts` and `dashboard.store.ts`: groups, meter configs, a table drawn from another screen's read; `shell/meter.ts`; extend, or record why a copy reads better); the drill-downs on the shared list page; add-only `shell/screen-outlet.ts`, `core/strings.ts`; regenerate `screens.generated.ts` and `Screen/Titles.cls` with `ui/tools/screen-mirror.mjs`.
- **Tests (new):** `Test/InteropSystemMonitorSeam.cls` extending `InteropPort` (`VendorMetrics` modes: fixed values and tables, error status, raise after switching to `%SYS`, a role added then success or raise; caps lowered to three; `LogFault` captured with `$NAMESPACE`; a call counter); `InteropSystemMonitorRead` (both readers, vendor equality with the probe production running and stopped, drill-downs, caps, any scope, `SnippetForm`); `InteropSystemMonitorFrame` (roles, faults, restore, nothing logged while switched); `InteropSystemMonitorGate` (principals, armed by `OCUPILOT_ALLOW_PRINCIPALS`, one add-only `# classes:` line); each under 500 lines. Browser `ui/browser/interop-system-monitor.browser-spec.mjs` (siblings `dashboard.browser-spec.mjs`, `dashboard-drill-downs.browser-spec.mjs`).
- **Rosters (Rule 30; re-grep `interop.monitor`, `InteropMonitorList`, `osmgmt.activeprocesses`, `DashboardProcesses`, `ENDPOINTS` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src`, `scripts/`):** `ReadTool` (c), `ReadDescriptions` (c), `SurfaceCoverage` (c), `StageTwoTools` (c), `ToolEmit` (c), `ToolRoundTrip` (c), `ClassicPageGate` (c), `Descriptor` (c), `InteropDescriptor`, `InteropHostDescriptor` (`ENDPOINTS`), `InteropFloor` and `InteropFloorOwnPairs` (the four screens and tools per principal kind), `Navigation` (the Interoperability count and order), `ui/tools/interop.test.mjs` (the paragraph assertion :419-422), `screen-mirror.test.mjs` (c), `navigation.test.mjs` (c), `ci.test.mjs` (the arming roster). No new route: the reads reach the screen read and the derived read tools.
- **`README.md`** (c) :229-230; **EXPERIENCE.md** (c): one Fixed strings row after Batch 4's (:639) and "System monitor" in the auto-refresh list (:932), once ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci` only, auditing on; the probe production stopped and every principal removed after; record under Design Notes, Measured): (a) `GetEnsMetrics` called through a scratch frame shaped as the plan's (`New $ROLES`, switch to `%SYS`, call, restore), as `_SYSTEM`, `irisowner` and a principal without `%All` holding the veto item 2 pairs (plus `%DB_HSCUSTOM:R` to run code), with the probe production running and stopped: `$ROLES`, `$USERNAME`, `$NAMESPACE` after the call and after the frame; journal records by process id; the `^IRIS.Temp.SysMetrics` and `^IRIS.Temp.Ens*` nodes before and after (IRISTEMP is not journaled); audit rows (with a positive control); processes started during the call; (b) principals holding `%Ens_Portal:U,%Ens_Dashboard:U` without `%DB_IRISSYS:R`, with it, and without `%Ens_Dashboard:U`: the switch, the vendor's answer, and whether the classic page answers its meters over HTTP on 52777; name any further pair; (c) every `values`, `status` and `msg` member, idle and running, the three tables' encoding and row counts, and `pCount` 0 against 1; (d) the call's time, cold and warm, idle and running: within 5 s here (7.5 s on CI at 1.5 times). HALT `blocked` if `$ROLES`, `$USERNAME` or `$NAMESPACE` differs after the frame; if the call starts a process (AD-9: nothing is spawned from an escalated frame); if it journals a record or writes an audit row (`## Clarification Needed`); if (b) finds the classic page refused where the gate admits; if (c) finds a meter a veto string names absent (`intent gap: new string`); or if (d) does not fit.
- [ ] `src/OcuPilot/Port/InteropPort.cls` -- the four endpoints, the instance gate, `PurgeFrame`'s kind, `VendorMetrics`, the row and table builders, the cap -- the log purge family extended.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropSystemMonitor*.cls` -- the four screens.
- [ ] `ui/src/app/areas/interoperability/interop-system-monitor.*`, strings, outlet registrations; regenerate the mirror and titles; the EXPERIENCE.md row and list entry; `README.md` and `ui/tools/interop.test.mjs`'s assertion.
- [ ] `src/OcuPilot/Test/InteropSystemMonitor*.cls`, the browser spec, component specs, the `# classes:` line and the rosters the sweep names -- the matrix, either order.

**Acceptance Criteria:**

- **AC1 (read, both readers; Integration, Rule 1).** Given the probe production running in USER, when a person opens System monitor and the agent reads `interop.systemmonitor`, then each answers one row whose stable meters equal the vendor's answer read beside it, counting USER's production; and once it stops, neither counts it.
- **AC2 (drill-downs).** Given the vendor's three tables, when each drill-down is read by either reader, then it lists the vendor's rows in order without padding, and caps at its limit with truncation reported.
- **AC3 (gate).** Given a principal lacking any one pair, when it reads any of the four, then 403 names that pair and the vendor is not called.
- **AC4 (containment, AD-9).** Given the seam adds a role inside the vendor call, and given the real call as a principal without `%All`, when the read succeeds, fails and raises, then `$ROLES`, `$USERNAME` and `$NAMESPACE` read as before.
- **AC5 (faults, switched).** Given a vendor error status or a raise while in `%SYS`, when either reader reads, then the answer is 500, never 200, the namespace is restored before anything is logged, and no log line carries vendor text.
- **AC6 (no write, rosters).** Given the four read tools, when `ToolWrite`, `SurfaceCoverage`, `ReadTool`, `ClassicPageGate`, `ConfirmNamespaceRoster`, `DraftRegistry` and `GovernanceBaseline` run, then each is green, and `ReadTool` reddens with a tool's row removed.
- **AC7 (README).** Given the paragraph's new clauses, when `interop.test.mjs` runs, then the paragraph and the unchanged count hold, and it reddens with a clause dropped.
- **AC8 (browser).** Given a fresh instance, when a person opens System monitor and its Most active queues drill-down, then the Productions running meter shows the count the screen's read answers, and the drill-down's list opens answered.
- **AC9 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no principal remains and the probe production is as found.

## Spec Change Log

## Review Triage Log

### 2026-11-26 — Review pass

- verdicts: 17 findings — high 0, medium 4, low 9, false 2, maybe-false 2
- findings:
  - `[medium]` `[patch]` The vendor's `^SYS.EnsMetrics` lock release in `VendorMetrics` is unpinned — a second process now reads the running production while a first reader lives (`Frame.TestAnotherProcessStillReadsTheProductionWhileTheFirstReaderLives`, child mode `hold`); mutation run.
  - `[medium]` `[patch]` The page's own table store and its stale-answer and destroyed guards had no test — three page-spec cases added, each mutation run.
  - `[medium]` `[patch]` Thirteen of the 25 meter names were never compared with the vendor — `Read` now asserts each is a subscript of the vendor's own array; mutation run.
  - `[medium]` `[patch]` Nineteen label and kind bindings were unpinned on the client — the store test pins all 25 against the spec's labels; mutation run.
  - `[maybe-false]` `[defer]` Four vendor calls per refresh from the page may overlap and read idle — unverified; settled by four concurrent web reads with a production running.
  - `[low]` `[patch]` Header mutation lines naming runs that were not made, one that cannot hold — removed from the test headers and the browser spec; the spec's Verification carries the runs.
  - `[low]` `[reject]` A pending meter's value assertion passes when the element is absent — a status meter draws none before its answer by design, and the skeleton assertion beside it pins the state; the stricter form was tried and went red on value meters.
  - `[low]` `[reject]` `TestEveryNamespaceAnswersTheSame` makes three reads without waiting — the three answer from one snapshot (inference), so equality holds either way; a wait adds 33 seconds for no new failure.
  - `[low]` `[reject]` The case checks USER alone for a foreign production — the throwaway holds none elsewhere and the guard would add a namespace walk for no reachable case.
  - `[low]` `[reject]` Readiness is a fixed 11-second wait — the vendor's interval is a fixed 10 seconds, so a signal has nothing to wait on.
  - `[low]` `[reject]` The journal window can roll over during the call — one red in 6,900 tests, already recorded and handled by a rerun.
  - `[false]` `[reject]` The screen declares 60 seconds against the contract's 5/10/30/60 — the orchestrator's ruling, condition 2, replaces the contract's rates.
  - `[false]` `[reject]` The port carries no truncation signal — the family's convention is a caller asking one row beyond its cap, which `Read.TestEachDrillDownStopsAtItsNamedLimit` pins.
  - `[low]` `[reject]` Live equality covers 12 of 25 meters and the tables against the seam — the 13 names are now pinned against the vendor and the rest move between calls.
  - `[low]` `[reject]` The real web-request path with a production running is exercised by no test — measured over HTTP on 52777 and recorded under Measured; the in-process route test adds nothing the measurement does not show.
  - `[low]` `[reject]` The browser spec runs on an idle instance — the field-level pins are in the component and store tests.
  - `[maybe-false]` `[defer]` Four reads per refresh against one call per reader — grouped with the overlap entry above.

## Veto items

Each is the lead's to take to the veto gate; the recommended option is first.

1. **New user-facing strings, the README and EXPERIENCE.md** (reused, each read true here: "Most active processes" (`activeProcessesLabel`), "Upcoming tasks" (`taskUpcomingLabel`), "System usage" (`systemUsageLabel`), "Errors and alerts", "Licensing", "Task manager" (`dashboardGroup*`), "Processes" (`processListLabel`), "Uptime", "Last backup", "Database space", "Database journal", "Journal space", "Journal entries", "Lock table", "Write daemon", "Serious alerts", "License limit", "Current license use", "Highest license use", "Namespace" (`headerNamespaceLabel`), "Item", "Process ID", "Commands", "Queue", "Messages", "Task", "Scheduled for", "Status", "No process reports executed commands." (`activeProcessesEmpty`), `activeProcessesPrompt1`-`3`, `taskUpcomingListPrompt1`-`3`):
   - Labels: "System monitor" · "Most active queues". Groups: "Production throughput" · "Production jobs" · "System time" · "Production queues".
   - Meters: "Namespaces running productions" · "Productions running" · "Productions suspended or troubled" · "Incoming messages in the last 30 seconds" · "Last incoming message" · "Outgoing messages in the last 30 seconds" · "Last outgoing message" · "Active production jobs" · "Visiting production jobs" · "Active queues" · "Production alerts" · "Production errors".
   - Empty states: "The system monitor is unavailable." · "No production queue holds messages." · "No tasks are scheduled to run." (no agent phrase: nothing to create).
   - Prompts: "Is any production suspended or troubled?" · "How many messages came in and went out in the last 30 seconds?" · "Which production queues hold the most messages?" · "Which queues hold the most messages?" · "Is one queue holding far more messages than the others?" · "Which namespace's queues hold the most messages?"
   - README :229, after "archive old messages into another interoperability namespace;": "list managed alerts and each alert's history, and assign, unassign, close or reopen an alert, move its escalation level one step or set its next action time, each with a reason the alert's history keeps; list the business rule log and the business process log, and purge each by age; add, edit and remove workflow users and workflow roles, and add or remove a role's members; list workflow tasks and each user's worklist, and assign a task to a user or to no one, change its priority or cancel it; watch the system monitor, which shows the productions running in every namespace with their message counts, jobs, queues, errors and alerts beside the instance's own status, licensing and upcoming tasks;" `interop.test.mjs` :420 takes the same text.
   - EXPERIENCE.md :932, the auto-refresh list: "Production monitor, Queues, Jobs" becomes "Production monitor, System monitor, Queues, Jobs".
   - Alternative label: "Interoperability system monitor", since Logs already lists "System Monitor log", which is IRIS's own System Monitor.
2. **Security posture: stricter than the classic page.** `%Ens_Portal:USE`, `%Ens_Dashboard:USE` and `%DB_IRISSYS:READ`. The classic page asks `%Ens_Dashboard:USE` alone (`EnsembleMonitor.cls:21`, `Ensemble.cls:193`). `%Ens_Portal:USE` is held by both stock roles that list `%Ens_Dashboard` (`%EnsRole_Monitor`, `%EnsRole_Operator`, measured at plan). `%DB_IRISSYS:READ` is the switch to `%SYS` (AD-29, measured for MonitorPort); its public permission is empty here and `%EnsRole_Monitor` lacks it, so a holder of that role alone is refused unless Task 0 (b) shows the classic page refuses it too (inference). Every holder sees every namespace's productions, queues and processes, the license and the upcoming tasks, as the classic page shows them through the vendor's `%All`. Alternative: `%Ens_Dashboard:USE` and `%DB_IRISSYS:READ`.
3. **The vendor's escalation and bookkeeping.** `GetEnsMetrics` adds `%All` for itself in its own frame; OcuPilot contains it in `PurgeFrame` and adds no role. Each call journals the vendor's own `^SYS.EnsMetrics(...)` maintenance records (Task 0 (a): in IRISSYS with no production running, in the namespace's own database with one running; IRISTEMP untouched; no audit row), as each classic refresh does; they are not an OcuPilot write.
4. **AD amendments (story end, the lead writes them, add-only, `[AMENDED <date>, Story 24.17, Rule 20]`).** AD-9, after the second `New $ROLES` paragraph: "`PurgeFrame` also contains the Interoperability system monitor's read (Story 24.17): `%SYS.Ensemble.GetEnsMetrics` adds `%All` for itself in a frame of its own, and the frame gives the process's roles back on every exit, as it does for the purges. OcuPilot adds no role, and calls only the vendor while switched to `%SYS`." AD-62, the item after Batch 4's: "**The system monitor** (Story 24.17). `InteropPort` gains `SystemMonitor` and three drill-downs over one instance-wide call of `%SYS.Ensemble.GetEnsMetrics`, the classic Interoperability System Monitor's own, made in `%SYS` inside `PurgeFrame`, behind `%Ens_Portal:USE`, `%Ens_Dashboard:USE` and `%DB_IRISSYS:READ`. It takes no namespace, so item 3's interoperability test and item 2's database pair do not apply; its tables are cut at a named limit."

No new dependency; no destructive act; no governance key; nothing is written into another namespace by OcuPilot.

**Lead rulings at the spec gate (2026-11-26; filed as an INBOX veto item, binding unless the orchestrator reverses them).** Every veto item is kept as recommended:

- **V1:** kept, the label "System monitor", the meters, groups, empty states, prompts, the README paragraph and the EXPERIENCE.md change as quoted. If Task 0 (c) finds a meter a proposed string names absent, HALT; never reword in-stage.
- **V2:** kept, the stricter posture: `%Ens_Portal:USE`, `%Ens_Dashboard:USE` and `%DB_IRISSYS:READ`. Task 0 (b) records whether a holder of `%EnsRole_Monitor` alone, admitted by the classic page, is refused here; that is the stricter posture the ruling accepts, not a HALT.
- **V3:** kept. The vendor's `%All` is contained in `PurgeFrame` exactly as the purges' (the orchestrator accepted the `PurgeFrame` extension for Batch 2 on the same method and allowlist); any frame leak in Task 0 (a) is a HALT.
- **V4:** kept for story end; the lead writes the lines and reports them to the orchestrator.

**Orchestrator ruling after Task 0's halt at (a) (2026-11-26, veto, policy b9ff703e; ruled as U-159 was).** The `^SYS.EnsMetrics` journal records are the vendor's own maintenance records, written by the classic System Monitor's own call on every refresh: not an OcuPilot write into another namespace and not an AD-9 store. Binding conditions:

1. The story-end AD-9 line names `^SYS.EnsMetrics` (in IRISSYS with no production running, in the namespace's database with one running) as the known effect of the one vendor call. The tests allow exactly those SETs and fail on any other global, in IRISSYS or anywhere, and on any audit row. Task 0's frame checks (`$ROLES`, `$USERNAME`, `$NAMESPACE` unchanged; no process started) are kept as tests.
2. Each call writes, so OcuPilot never polls it faster than the classic page refreshes: either no automatic refresh (reads only when the person asks), or an interval no shorter than the classic System Monitor's default, read from its source and cited. The agent read is one call per tool invocation, never looped inside the tool.
3. With a production running, the call raises `<UNDEFINED>cspLink ... %request` outside a web request. The screen path (a REST request) has `%request`. The agent's turn runs in a background job (AD-7), not a CSP request: measure the turn-job path with a production running first. If the call raises there, the port handles it (for example a minimal request context, as Story 21.27 hoisted the null-device helper), with a test on the turn-job path; if no safe handling exists, HALT with `## Clarification Needed` before building the agent read.
4. Task 0's running-production leg and the read tests reach the real call through the HTTP route on 52777, or through the turn-job path of condition 3.

## Design Notes

**Decided in-stage (plan).**

1. Epic context reused as committed: only EXPERIENCE.md is newer (Batches 1 to 4's rows), read here directly; no recompile, since this dispatch commits the spec alone.
2. The read lives in `InteropPort` because `PurgeFrame` is the one admitted `New $ROLES` (AD-9, checker rule 6); `PurgeFrame` gains the kind `metrics`, entered unswitched, and `VendorMetrics` switches to `%SYS` itself, since `%SYS` cannot run OcuPilot's code.
3. Arguments: `pID` `""`, `pCount` 0, `pInterval` the vendor's default 10, as the classic page's first call (`HTMLDashboardPane.cls:389`, `:717`).
4. Instance-wide: scope `instance`; the four endpoints judge pairs only and never read the request's namespace.
5. The three tables are drill-downs with their own declared reads, so the agent reads them through the same contract (AD-36), as Story 18.36's Dashboard drill-downs; each calls the vendor once.
6. Field names are the vendor's meter properties; the table columns are the classic captions, `ConfigName` as `Item`, `PID` as `Pid`, `Time` as `ScheduledFor`.
7. Values only: the vendor's per-meter `status` and `msg` are not carried (named limit), as the System Dashboard carries its values.
8. Side bar 29, after Workflow worklist; drill-downs 0. Auto-refresh as the Production monitor, the classic page's own timer precedent.
9. No write, so no key, entity type, `Prohibited.cls` term or README count change.
10. Siblings (Rule 31): the log purge family (`PurgeFrame`, `VendorLogPurge`, `LogMapped`), `MONITORPAIRS`, `Dashboard`/`DashboardProcesses` (descriptors), `dashboard.page.ts`/`dashboard.store.ts`/`meter.ts` (client), Batch 2's `InteropLogPurgeSeam` (seam modes) and `ProductionProbe` (the probe production).

**Decided in-stage (implement).**

1. System monitor offers the one refresh rate 60 seconds, default off, in place of 5, 10, 30 and 60 (the orchestrator's condition 2; the classic page's own rate, `EnsembleMonitor.cls:227`). EXPERIENCE.md's auto-refresh bullet names System monitor and says it offers 60 s alone.
2. The vendor leaves an exclusive and a shared lock on `^SYS.EnsMetrics` after each call, and the vendor answers from its last call's counts inside 10 seconds (Measured). `VendorMetrics` gives both locks back unconditionally on every exit, with no read of `^$LOCK` (a principal without `%All` may not read it, inference), and the tests wait 11 seconds (`AgeSnapshot`) after any change of the production a read must see.
3. A caller with no web request gets a minimal `%request`, `%response` and unsaved `%session` for the call, made in `VendorMetrics` before the switch (condition 3). `PurgeFrame`'s kind is `metrics` (`LOGKINDMETRICS`); the frame and the checker's rule 6 entry are otherwise unchanged.
4. Both readers and the tests use the values only: no `status` or `msg` is carried. The page reads the row and each table once per read, four vendor calls, never at a rate above one per 60 seconds.
5. Existing strings are reused where the spec's quoted new one already exists: "Which queues hold the most messages?" is `interopQueuesPrompt1` (a duplicate value is refused by `strings.test.mjs`), and "Item", "Messages" and "Task" are `interopItemSettingsCriterionItem`, `interopItemTabMessages` and `proposalEntityTask`. The meter key naming the namespaces is `interopSystemMonitorMeterScopes`, since a key with "Namespace" in its name joins `strings.test.mjs`'s namespace-key roster.
6. The drill-downs' default sorts are Commands, Messages and Scheduled for (the text of the time, ascending), so a task list that crosses midnight is re-ordered by its text (inference: the vendor lists tasks by time to run).
7. `InteropSystemMonitorCapSeam` carries the lowered limit, since the one seam's `values` mode is also read at the shipped limit. The arming roster takes one add-only `# classes:` line naming the case class alone.
8. `ui/tools/screen-mirror.mjs` regenerated the mirror and `Titles.cls`; every other file was written with Edit or Write, except two in-place `sed` calls on a repo file (identical text) and `ui/tools/navigation.test.mjs` (a one-number change), which the report names.

**Measured at plan (`ocupilot-b-ci`, read-only).** `SYS.EnsMetrics` and `SYS.Metrics` are deployed (no source); OcuPilot is not compiled in `%SYS`; `/csp/sys` has no resource and no matching roles; `%DB_IRISSYS` and `%Ens_Dashboard` have no public permission; the roles listing `%Ens_Dashboard` are `%EnsRole_Monitor` (`%Ens_Dashboard:U,%Ens_MsgBank_Dashboard:U,%Ens_Portal:U`) and `%EnsRole_Operator`; IRISTEMP holds `^IRIS.Temp.SysMetrics` and `^IRIS.Temp.Ens*` globals. `node --test --test-name-pattern="README states the count" tools/interop.test.mjs` passes at "One hundred and five" (116 `false` keys less 11 person-only).

**Measured (Task 0, `ocupilot-b-ci`, 2026-11-26, auditing on; the idle legs by the first pass, the running and background-job legs by this one, and the footprint legs again by `InteropSystemMonitorFrame`).**

- (a) Frame as the plan shapes it: `$ROLES`, `$USERNAME` and `$NAMESPACE` equal before and after for `irisowner` and for a principal holding `%Ens_Portal:U,%Ens_Dashboard:U,%DB_IRISSYS:R,%DB_HSCUSTOM:R` and no `%All`, idle and with the probe production running (the principal's legs run in a child job through the port). The call starts no process, writes no audit row (positive control: a security resource created and deleted by the same process is seen by the same query) and leaves IRISTEMP's `^IRIS.Temp.SysMetrics*` and `^IRIS.Temp.Ens*` as found. Journal: every record the process wrote is a `^SYS.EnsMetrics` record, idle 5 and with the production running 31 in the test's run (the first idle call of a process writes none).
- The vendor's maintenance records are the ruled ones (U-177). **Two more findings, not in the plan:** each call leaves an exclusive and a shared lock on `^SYS.EnsMetrics` that only the end of a web request lets go of, and while a process holds them every other process reads the instance as idle (running 0, empty tables); and the vendor answers a call made within 10 seconds of its last one from the last one's counts, so a read that must see a production start or stop waits 10 seconds after the last call. The port gives its locks back on every exit and the tests wait.
- (b) Pairs: without `%DB_IRISSYS:R` the switch to `%SYS` raises `<PROTECT>`; without `%Ens_Dashboard:U` the vendor's own check answers `#940`; without `%Ens_Portal:U` (holding the other two) the vendor answers, so the portal's pair is the stricter posture the ruling accepts. No further pair. The classic page over HTTP was not tried (inference: its `RESOURCE` is `%Ens_Dashboard:USE`, `EnsembleMonitor.cls:21`, which the gate also asks).
- (c) The call answers the same 51 `values` members for `pCount` 0 and 1, idle and running; the 25 meters the row names are all present, each as text. Table meters: `EnsBusyProcesses` is `Namespace;Item;Pid;Commands` (`;[System];1879;712`, a system process has no namespace; counts may carry thousands separators, `1,200`), `EnsBusyQueues` is `Namespace;Queue;Messages` (`USER;OcuPilotProbeOp;0`, empty while no production runs) and `UpcomingTasks` is `Task;Time;Status` (`Mirror OAuth2 config sync task;13:55;Scheduled`); each has `^` between rows and no padding row in either state (the older `BusyProcesses` meter pads with `;0`, which the port does not read). Idle the call answers an empty `EnsBusyQueues`; running it answered the four queues of USER's probe production, five tasks, and the processes the vendor counts. The vendor's per-meter `status` and `msg` carry `LastBackup`, `Transactions` and six message names, and the port carries neither.
- (d) Time: 0.013 to 0.016 s per call idle (in process), and a whole route read, request to answer, in 0.05 s with the production running. Well within 5 s here and 7.5 s on CI.
- **Condition 3 (the agent's turn job):** with a production running, the call made in a background job (no web request) answers an error status naming `<UNDEFINED>cspLink ... %request`, then `%response`, then `%session`, with the tables empty. The port gives such a caller a minimal context of the vendor's own classes (`%CSP.Request`, `%CSP.Response` and an unsaved `%CSP.Session` made with no lock and no stored row), and the call answers 200 with the production counted and the probe queue listed; the context is dropped when the method ends and no session is stored. `InteropSystemMonitorFrame.TestABackgroundJobReadsWithAProductionRunning` pins it.
- **Condition 2 (refresh):** the classic System Monitor's own rate is 60 seconds: `Set tPane.RefreshRate = 60000` (`EnsembleMonitor.cls:227`, the page); its 10-second timer runs only when the portal's auto-refresh setting is on (`enableAutoRefresh`, `abstractRefreshable.cls:12`), which is not the default. System monitor therefore offers the 60-second rate alone, default off.

**Governing ADs (Rule 6):** AD-5, AD-8, AD-9, AD-16, AD-29, AD-36, AD-43, AD-44, AD-62. Not engaged: AD-3, AD-6, AD-7 (a read in its request), AD-10, AD-15, AD-22, AD-51 to AD-53, AD-56, AD-58, AD-59 (no write).

**Integration and linkage (Rules 1, 2).** Integration: AC1 (the derived read tool and the screen read consume the port against the real vendor). Consumes: the log purge family's frame, the Dashboard's meters client. Consumed-by: none in this story.

**Ledger inbox (Rule 17):** `LEDGER slice 24-17-managed-alerts-logs-the-system-monitor-and-workflow` empty at plan; `owned_ledger=0`.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropSystemMonitorRead`, then likewise `InteropSystemMonitorFrame`, `InteropSystemMonitorGate`, Batch 2's `InteropLogPurgeRefusals` (the shared frame), `ReadTool`, `SurfaceCoverage`, `ClassicPageGate`, `ConfirmNamespaceRoster`, `DraftRegistry`, `GovernanceBaseline`, `InteropFloor`, and every class the sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-system-monitor.browser-spec.mjs browser/dashboard-drill-downs.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** the Interoperability side bar; `InteropPort`'s `ENDPOINTS`; the read-tool, coverage, classic-page and floor rosters; `PurgeFrame`; `interop.test.mjs`'s README assertion; `screen-mirror.test.mjs`; the arming roster; the probe production in USER.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; a test that starts the probe production stops it and restores its items; principals are removed.

**Mutations** (as Batch 2's procedure). Each was applied on `ocupilot-b-ci`, run, reverted and compared with a copy taken before (`cmp`), and the tree reloaded with every subclass; the client one on a rebuilt, redeployed bundle.

- mutation: the row's Productions running read from `EnsJobs` in `SystemMonitorRow` -> `InteropSystemMonitorRead.TestTheRowEqualsTheVendorBesideItWithTheProbeProductionRunningAndStopped` and `TestTheDrillDownsListTheVendorsRowsInOrderWithoutPadding` red (AC1; the previous-call mutation the plan named does not exist in the port, so this is its equivalent on the row).
- mutation: the padding rows kept in `MonitorTableRows` -> `InteropSystemMonitorRead.TestTheDrillDownsListTheVendorsRowsInOrderWithoutPadding` red on all three tables (AC2).
- mutation: `%Ens_Dashboard:USE` dropped from `SYSTEMMONITORPAIRS` -> `InteropSystemMonitorGate.TestTheGateRefusesEachPrincipalBeforeAnyVendorCall` red on the principal without it, its four legs and the vendor-call count (AC3).
- mutation: `VendorMetrics` called outside `PurgeFrame` in `ReadMetrics` -> `InteropSystemMonitorFrame.TestTheRolesUserAndNamespaceAreTheSameAfterEveryExit` red on the administrator's two role legs and on the roles the later legs saw (AC4).
- mutation: the namespace restore moved after the log in `ReadMetrics` -> `InteropSystemMonitorFrame.TestAFaultIsLoggedAfterTheRestoreWithNoVendorText` red (the log line is written in `%SYS`, where OcuPilot is not compiled, and raises) (AC5).
- mutation: `interop.systemmonitortasks.read` removed from `ReadTool`'s roster -> `ReadTool.TestTheRegistryListsDescriptorReadsAndInheritedKinds` red (AC6).
- mutation: the system monitor clause dropped from the README -> `interop.test.mjs` "the README states the count" red (AC7).
- mutation: the Productions running meter bound to `Processes` in `interop-system-monitor.store.ts`, on a rebuilt and redeployed bundle -> `interop-system-monitor.browser-spec.mjs` first test red, and `interop-system-monitor-store.test.mjs` red (AC8; `EnsJobs`, the plan's field, reads 0 as does Productions running on an idle instance).
- mutation: the case's `OnAfterOneTest` no longer removes the probe production -> `InteropSystemMonitorRead` red on its after-test assertion and on the next test's start (AC9).
- mutation (review patches, run the same way): the two `Lock -` lines of `VendorMetrics` removed -> `InteropSystemMonitorFrame.TestAnotherProcessStillReadsTheProductionWhileTheFirstReaderLives` red; `EnsOutgoingRequests` misspelt in `SYSTEMMONITORMETERS` -> `InteropSystemMonitorRead.TestTheRowEqualsTheVendorBesideItWithTheProbeProductionRunningAndStopped` red; two meters' labels swapped in `interop-system-monitor.store.ts` -> `interop-system-monitor-store.test.mjs` "each meter shows the label and kind the spec places it under" red; the latest-read check, the destroyed check and the page's own table store each dropped in `interop-system-monitor.page.ts` -> the matching page-spec case red, one at a time, each reverted and `cmp`-identical.

## Auto Run Result

Status: in-review
Blocking condition: none.

**Implement pass (2026-11-26, after the orchestrator's ruling U-177).** Task 0's running-production leg through the HTTP route on 52777 and condition 3's background job are measured and recorded under Design Notes, Measured. Two things beyond the spec came of them: the port gives back the exclusive and shared lock the vendor leaves on `^SYS.EnsMetrics`, and a caller with no web request gets a minimal request context for the call. Built to the spec:

- **Port:** `InteropPort` gains the four endpoints, the instance gate of pairs alone, `SystemMonitorRow`, `MonitorTableRows`, `ReadMetrics`, the overridable `VendorMetrics` and `PurgeFrame`'s kind `metrics`; descriptors `InteropSystemMonitor` (side bar 29, `meters`, one 60-second rate) and the three drill-downs; mirror and `Titles.cls` regenerated.
- **Client:** `interop-system-monitor.page.ts` and `.store.ts` with specs, the outlet registration, 27 strings and EXPERIENCE.md's row and auto-refresh bullet; README's Interoperability paragraph and `interop.test.mjs`'s assertion, count unchanged.
- **Tests:** `InteropSystemMonitorCase`, `Seam`, `CapSeam`, `Child`, `Read` (7 tests), `Frame` (4), `Gate` (2); the browser spec; the rosters `ReadTool` (647 tools), `SurfaceCoverage`, `StageTwoTools`, `Descriptor`, `InteropDescriptor`, `InteropHostDescriptor`, `Navigation`, `screen-mirror.test.mjs`, `navigation.test.mjs` and one `# classes:` line.
- **Verified on `ocupilot-b-ci`:** the three new classes green in both orders; the full sweep, shards 1 to 17, 924 classes and 6,907 tests, green (shard 15 once red on the Frame class's own journal window, fixed and run again green); smoke 49 of 49; the browser spec and `dashboard-drill-downs` green on a rebuilt bundle; `npm test` (2,426 tool tests and 4,094 component tests), `npm run build`, `check-objectscript.py`, its harness and `lint-docs.sh` clean. Each AC has one mutation (Verification). USER holds no production and no `OcuP2417*` principal or role remains.

**Review pass (2026-11-26).** Seventeen findings, none high: four medium patched (lock release pinned by a second reader beside a living first one, the page's own-store and stale-answer guards, the 25 meter names against the vendor's array, the 25 label and kind bindings), one low patched (unrun mutation lines removed from test headers), two maybe-false deferred as one entry (overlapping vendor calls from the page's four reads), two false and seven low rejected with their reasons in the Review Triage Log. Re-verified after the patches: `InteropSystemMonitorFrame` (5 tests), `Read` (7), `Gate` (2), each green with one mutation red and reverted `cmp`-identical; `interop-system-monitor.page.spec.ts` (11) and the store test (7); `npm test` tools 2,427 and components 4,097 green; `check-objectscript.py` clean. Follow-up review recommended: four medium patches, and the new lock case depends on a second process's timing.

**Plan.** Batch 5: System monitor and its three drill-downs through `InteropPort`, one instance-wide `GetEnsMetrics` call each in `%SYS` inside `PurgeFrame`, and the README's Interoperability clauses for the five batches. Veto items 1 to 4; decided-in-stage list under Design Notes. Read-only check on `ocupilot-b-ci` (52777, 2026.2 build 221U); nothing was written to the instance.
