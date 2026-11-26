---
title: 'Story 24.17: Managed alerts, logs, the system monitor and workflow (Batch 5: the Interoperability System Monitor and the README)'
type: 'feature'
created: '2026-11-26'
status: 'ready-for-dev'
baseline_revision: 'aeb9826d5a0c0dac22d426e6f7a44aef73093272'
review_loop_iteration: 0
followup_review_recommended: false
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-17-managed-alerts-logs-the-system-monitor-and-workflow-2.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-17-managed-alerts-logs-the-system-monitor-and-workflow-5.md'
warnings: ['oversized']
deferred: []
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

**Measured at plan (`ocupilot-b-ci`, read-only).** `SYS.EnsMetrics` and `SYS.Metrics` are deployed (no source); OcuPilot is not compiled in `%SYS`; `/csp/sys` has no resource and no matching roles; `%DB_IRISSYS` and `%Ens_Dashboard` have no public permission; the roles listing `%Ens_Dashboard` are `%EnsRole_Monitor` (`%Ens_Dashboard:U,%Ens_MsgBank_Dashboard:U,%Ens_Portal:U`) and `%EnsRole_Operator`; IRISTEMP holds `^IRIS.Temp.SysMetrics` and `^IRIS.Temp.Ens*` globals. `node --test --test-name-pattern="README states the count" tools/interop.test.mjs` passes at "One hundred and five" (116 `false` keys less 11 person-only).

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

**Mutations** (as Batch 2's procedure). Planned: AC1 `VendorMetrics` answers the previous call's values -> `InteropSystemMonitorRead` red (stopped leg); AC2 the padding rows kept -> `InteropSystemMonitorRead` red; AC3 `%Ens_Dashboard:USE` dropped from the pairs -> `InteropSystemMonitorGate` red; AC4 the vendor called outside `PurgeFrame` -> `InteropSystemMonitorFrame` red (role legs); AC5 the restore moved after the log -> `InteropSystemMonitorFrame` red; AC6 a tool's `ReadTool` row removed -> red; AC7 a README clause dropped -> `interop.test.mjs` red; AC8 the meter bound to `EnsJobs` -> the browser spec red; AC9 the probe production left running -> the case's after-all check red.

## Auto Run Result

Status: blocked
Blocking condition: Task 0 (a) HALT, `## Clarification Needed`: `%SYS.Ensemble.GetEnsMetrics` journals records. No product code was written.

**Task 0 (implement stage, `ocupilot-b-ci`, auditing on, scratch class `Scratch2417.Probe` since deleted, principals `OcuP2417m*` since deleted, probe production stopped, USER holds none).** (a) The frame as the plan shapes it (`New $ROLES`, switch to `%SYS`, call, restore): `$ROLES`, `$USERNAME` and `$NAMESPACE` equal before and after for `irisowner` (`%All,OcuPilotAdmin`) and for a principal holding `%Ens_Portal:U,%Ens_Dashboard:U,%DB_IRISSYS:R,%DB_HSCUSTOM:R` (role `OcuP2417mFullRole` only), idle; no process started (process list before and after equal); `^IRIS.Temp.SysMetrics*` and `^IRIS.Temp.Ens*` unchanged by the call (node counts and a checksum). **Journal: the call journals records.** Idle, the third of three calls from one process wrote 3 SETs of `^SYS.EnsMetrics`, `^SYS.EnsMetrics("BusyProcesses")` and `^SYS.EnsMetrics("BusyProcesses",<pid>)` into the IRISSYS database (`/durable/iris/mgr/`), the first of one call wrote none; with the probe production running, each call wrote 28 to 34 SETs of `^SYS.EnsMetrics(...)` (`Productions`, `Queues`, `JobCount`, `Count`, `Errors`, `Alerts`, `Previous`, `BusyProcesses`) into the USER database (`/durable/iris/mgr/user/`), for `irisowner` and for the principal alike. A control run with the same scratch code and no call journaled none. The call wrote no audit row (journal of `^IRIS.AuditD` by the process: none for `irisowner`; the principal's rows are its own login, the positive control). (b) Without `%DB_IRISSYS:R`: `<PROTECT>` at the switch to `%SYS`; without `%Ens_Dashboard:U`: `#940` from the vendor's own check; without `%Ens_Portal:U` (holding `%Ens_Dashboard:U,%DB_IRISSYS:R`): the vendor answers. The classic page over HTTP was not tried. (c) With no production running the call answers all of the 25 meters; the three tables read `EnsBusyProcesses` `;[System];1879;712`, `EnsBusyQueues` empty, `UpcomingTasks` `<task>;<time>;<status>^...`; `status` holds `LastBackup` and `Transactions`, `msg` six names. With the probe production running the call raised `<UNDEFINED>cspLink+9^%SYS.cspServer *%request` from a process with no web context (and the same for `%response`, `%session` once each was defined), after `EnsProductionsRunning` read 1, so the running leg's meters were not read here. (d) 0.013 to 0.016 s per call, cold and warm, idle and running. The run stopped at the journal finding.

**Plan.** Batch 5: System monitor and its three drill-downs through `InteropPort`, one instance-wide `GetEnsMetrics` call each in `%SYS` inside `PurgeFrame`, and the README's Interoperability clauses for the five batches. Veto items 1 to 4; decided-in-stage list under Design Notes. Read-only check on `ocupilot-b-ci` (52777, 2026.2 build 221U); nothing was written to the instance.
