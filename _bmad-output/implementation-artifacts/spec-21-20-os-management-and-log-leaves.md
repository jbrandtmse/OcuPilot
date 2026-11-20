---
title: 'Story 21.20: OS management and log leaves'
type: 'feature'
created: '2026-11-15'
status: 'blocked'
baseline_revision: '57f19f9f8eef7d0b941614c3379901309447be1b'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-10-the-remaining-leaves-across-the-six-areas.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Three classic-portal leaves in OS management have no OcuPilot surface: canceling a running SQL query (OS-24), the Transactions view (OS-27), and the system alert state with its reset (LG-12). Two ledger entries this story owns are also open: the Devices list has no Delete row action (DW-1562), and `LogSourcePort.LocalFromUtc`'s direction cannot be falsified on UTC instances (DW-2479).

**Approach:** Each leaf joins the OS management slice beside its neighbour. Cancel becomes a row action on SQL activity, the write going through `SqlActivityPort`. Transactions and System alerts become two new list screens read through `MonitorPort`; the alert read and reset run harvested MCP bodies through `HarvestPort` (AD-23). Devices gains the License servers' Delete pattern. `LogSourcePort` gains the overridable offset seam that Story 23.7 gave the ledger. The work is planned as three batches, each committable on its own.

## Boundaries & Constraints

**Always:** One descriptor and one port per screen (AD-5, AD-52). Every write is one operation reached by two callers (AD-53): a confirmed proposal for the agent, a row action for a person. Every fresh read is fingerprinted, and every write is read back (AD-6, AD-58). Both new write keys join `Baseline.cls` as `true`. Every port gates first (AD-29). Neither the classic page's resource nor its row eligibility is loosened: `%Admin_Operate:USE` floors both new screens and the cancel, and a remote statement is never canceled. Reads are capped and report truncation (AD-36). Every user-facing string comes from EXPERIENCE.md through `strings.ts`.

**Never:** No new AD and no AD amendment. No new `Prohibited` arm: the two new entity types are covered types with no predicate. No edit to `InteropPort.cls` or `Timeline.cls` (Epic 24 holds uncommitted `InteropPort` edits). `scripts/ci-throwaway.sh` gets add-only edits. Nothing for DW-1856 (declined, Design Notes). `alerts.log` is never truncated. No write to slot A's `ocupilot`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cancel, local | probe statement running (`SqlActivityProbe.Start`) | `CancelQuery(ProcessID, StatementId, 2)`; on re-fetch the row is gone and the probe's process still exists; the agent's write carries one marker and a `readBack` | none |
| Cancel, remote row | row `Remote` true | no Cancel drawn (self-protection rule `sql-statement-remote`) | 409 `SQLACTIVITY.REMOTE` from both callers, before the vendor |
| Cancel, ended | the statement ended after the read | mint: absent row, 404 as every action write; confirm: changed or absent | vendor #6164 (not running) answers 409 `SQLACTIVITY.ENDED` |
| Device delete | a device the test created | typed-name dialog; the device is removed; the list re-fetches | the existing tool's refusals, unchanged |
| Transactions | monitor running | rows `{Kind, ProcessID, Seconds, Status}`, Local then Remote, each equal to the System Monitor's global at that read; a Local `ProcessID` opens Process details | none |
| Transactions, monitor off | `SYS.Metrics.SystemMonitorStatus()` not `OK` | no rows | 409 `MONITOR.NOTRUNNING` with its sentence |
| System alerts | any state | one row `{State, StateText, AlertCount, LastAlert}`, equal to `%SYSTEM.Monitor` at that read | none |
| Alerts reset | `AlertCount` > 0 | harvested `AlertsManage` runs `Clear()`; read-back gives `AlertCount` 0 and `State` 0; `alerts.log` keeps every line | a changed fingerprint refuses the confirm |
| Missing pair | caller lacking a declared pair | no read, no vendor call | 403 `PORT.ACCESSDENIED` naming the pair |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Descriptor/SqlActivityList.cls` -- route `os-management/sql-activity`, position 20, entity `sql-statement`, composite id `Server,ProcessID,StatementHash` (:35), `rowActions []`. Row fields include `Started`, `StatementId` and `Remote` (:38). `rowTarget … "unless": "Remote"` (:72). The doc comment at :11-12 says canceling comes later.
- `src/OcuPilot/Port/SqlActivityPort.cls` -- `PAIRS` (:34), gate before the read (:137), the fixed `CURRENTSTATEMENTS` statement (:54); any type other than `CurrentStatements`/`LIST` answers 501 (:145); the reading process's own row is skipped (≈:203). It has no write half.
- `irislib/%SYSTEM/SQL.cls:6072` -- `CancelQuery(pid, SQLStatementID, timeout=10) As %Status`. Measured on slot A: an unknown pid gives #6164 intErr 92 and a pid running no SQL gives #6164 intErr 98a. `irissys/%CSP/UI/Portal/SQL/CurrentStatements.cls:320-331,372-373,498-513` is the classic page: Cancel only on a local, still-running row; a 2 s timeout; `RESOURCE` `%Admin_Operate`.
- **Cancel sibling:** `Screen/Tool/BackgroundTaskCancel.cls` with `BackgroundTaskMint.cls`, which joins the composite id, and `Port/BackgroundTaskPort.cls` (`CONTROLTYPES` :55, `Find` :246, `Control` :295, `StateRefusal` :333).
- `Kernel/Proposal/Prohibited.cls` -- `COVEREDTYPES` (:282), the type list at :1498, `UncoveredWriteTools` (:1928). `Process`/`IsOcuPilotProcess` (:4314/:4380) is not extended (Design Notes).
- `Screen/Registry.cls:3138-3151` -- `SELFPROTECTIONRULES` and its doc. `system-pct-access` is the sibling: a row-field rule that the tool refuses before the vendor. Client side: `ui/src/app/core/self-protection.ts`, `ui/tools/self-protection.test.mjs`.
- **Devices (DW-1562):** `Screen/Descriptor/DeviceList.cls:39-45` (`rowActions []` and its doc), `Screen/Tool/DeviceDelete.cls` (no `SCREENACTIONS`). The sibling is `LicenseServerList.cls:35` with `LicenseServerDelete.cls:35` (`SCREENACTIONS "delete"`). `ui/src/app/shell/screen-action-handler.ts` has `SCREEN_ACTION_DESCRIPTORS` (license :107), `DESTRUCTIVE_ACTIONS` (:592) and `DESTRUCTIVE_CONSEQUENCES` (license :659); an unpublished consequence is not registered (DW-389). The typed-name dialog is `shell/typed-name-dialog.ts`. `Test/Descriptor.cls:2405-2475` pins zero row actions. `Test/DeviceWire.cls` is armed by `OCUPILOT_ALLOW_PRINCIPALS`.
- `src/OcuPilot/Port/MonitorPort.cls` -- `PAIRS` (:33), `ENDPOINTS` (:62), `Usage` (:520), which runs vendor class queries as the caller. Header :17-22 ("never calls the vendor's alerts read") means SAM's `Alerts()`. `ui/tools/screen-mirror.mjs:1156` parses `ENDPOINTS`.
- `irissys/%CSP/UI/Portal/Transactions.cls:121-186` -- the classic Transactions page. It reads `SYS.Metrics.SystemMonitorStatus()` (`OK` on slot A) and `^IRIS.Temp.SysMetrics("Transactions"|"ECPTransactions")`: the node holds the status (`OK`/`Warning`/else Troubled; both `OK` on slot A), and its children `(row,"pid")` and `(row,"secs")` hold up to five rows. It has no actions, and only a local pid links.
- **Alerts:** `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/Monitor.cls` is read-only. `SystemAlerts` (:132-188) reads `State()`, `Alerts()` and `GetAlerts`. `AlertsManage` (:925-985) takes `{"action":"reset"}`, calls `Clear()` and needs `UtcStamp` (:556). `irissys/%SYSTEM/Monitor.cls:24-75` holds `Clear()`, which sets the counter to 0 and the state to OK. On slot A: `State()` 1 and `Alerts()` 2. The dashboard's `SeriousAlerts` is another counter (0 on slot A).
- **Harvest seam:** `Port/HarvestPort.cls` `Invoke` (gate first, one render), whose doc at ≈:205-214 says no body is a write. `Port/Harvest/Handler.cls` is the base and `Port/Harvest/Monitor.cls` holds `BackupManage` only. `scripts/check-objectscript.py:754-758` (`HARVEST_CALLERS`) allows exactly one caller per body class. `Test/PortGate.cls:29` is `ROSTER`. The model write is `BackupPort.Run` (:527-548) with `Screen/Tool/BackupRun.cls`; `FIXEDID "SYSTEM"` comes from `BackupFreeze.cls:31`.
- **List-screen siblings:** `Screen/Descriptor/MetricsList.cls` (monitor source, `entityType ""`, `classicPage ""`, position 21); `DatabaseEncryption` (instance scope, `id none`, row actions). OS management uses positions 1 to 32 (32 is ISQL settings), and Epic 24 tops out at 25.
- **DW-2479:** `Port/LogSourcePort.cls:1871` `LocalFromUtc`, which converts inline with no seam; its seam list is at :73-82. `Kernel/Audit/Ledger.cls:957` `OffsetAtUtc`. `Test/LedgerClockProbe.cls` (`OFFSET 7200`) and `Test/LedgerClock.cls:72`, `TestTheConversionsMoveOppositeWays`. Callers outside the class: `Screen/Timeline.cls:138`, `Port/InteropPort.cls:3970`, `Test/InteropLookupRead.cls:110,150`.
- **Strings:** EXPERIENCE.md is at `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`; the OS management rows are :91-101 and SQL activity's strings are :603. Reusable as they are: "Cancel" (`actionCancel`), "Process ID", "Delete" (`actionDelete`). `ui/tools/strings.test.mjs:613` sets the literal cap at 4200.

## Tasks & Acceptance

**Execution.** Task 0 runs on `ocupilot-ci` and is recorded under Design Notes before any code. Each item is (inference) until measured:

- (a) A caller holding only `SqlActivityPort.PAIRS` cancels another user's probe statement through `CancelQuery`. The probe's process survives, and its statement ends with an error. If the cancel needs more than `PAIRS`, it is recorded as the tool's write pairs; a pair beyond `%Admin_Operate:USE` plus a `%DB_IRISSYS` permission is an HALT `intent gap`.
- (b) Which pairs `Clear()` needs: with `%DB_IRISSYS:READ`, then with `:WRITE`. After it, `State()` and `Alerts()` read 0, `alerts.log` has the same line count, and `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` stays green.
- (c) Whether a probe job's open transaction (`TSTART` plus a journaled set, held) appears in `^IRIS.Temp.SysMetrics("Transactions")`, and after how long. Whether a `PAIRS`-only caller reads that global and `SystemMonitorStatus()`.

### Batch 1: cancel and the Devices delete (server and client; commit when its loop is green)

- `src/OcuPilot/Port/SqlActivityPort.cls`
  - Add type `ROW`: one row by its composite key. Absent is 404, as `BackgroundTaskPort.Find`.
  - Add type `CANCEL`. It refuses a `Remote` row with 409 `SQLACTIVITY.REMOTE`. Otherwise it calls `$SYSTEM.SQL.CancelQuery(ProcessID, StatementId, ..#CANCELSECONDS)`, where `CANCELSECONDS = 2` as the classic page uses, and maps #6164 to 409 `SQLACTIVITY.ENDED`.
  - `WRITEPAIRS` takes Task 0 (a)'s pairs, gated first. The header drops "later catalog row".
- `src/OcuPilot/Api/SqlActivityError.cls` -- new, on `LockError`'s shape: `REMOTE`, `ENDED` and their reasons (the escalated strings).
- `src/OcuPilot/Screen/Tool/SqlActivityCancel.cls` -- new; extends `BackgroundTaskCancel`'s shape.
  - Identity: `TOOLNAME osmgmt.sqlactivity.cancel`, `DESCRIPTORCLASS SqlActivityList`, `PORTCLASS SqlActivityPort`, `ENDPOINTNAME CurrentStatements`.
  - Operation: `READTYPE ROW`, `WRITETYPE CANCEL`, `SENDSBODY 0`, `SCREENACTIONS "cancel"`, `DESTRUCTIVE 0`, `CHANGEACTION "canceled"`.
  - Fingerprint: `FINGERPRINTSUBJECT "ProcessID,StatementId,Started"`, `PRECONDITIONFIELD "StatementId"`.
  - Its mint joins the composite id as `BackgroundTaskMint` does: a subclass of it, or a shared helper if a subclass reads worse.
  - The read-back is the row's absence.
- `src/OcuPilot/Screen/Descriptor/SqlActivityList.cls` -- `rowActions [{"id":"cancel","selfProtection":"sql-statement-remote"}]`; doc comment updated.
- `src/OcuPilot/Screen/Registry.cls` -- add-only: `sql-statement-remote` in `SELFPROTECTIONRULES` and its doc (a row whose `Remote` reads true; reason `SqlActivityError.REASONREMOTE`; refused by the cancel's port).
- `src/OcuPilot/Screen/Tool/DeviceDelete.cls` -- `SCREENACTIONS "delete"`. `DeviceList.cls`: `rowActions [{"id":"delete","selfProtection":""}]` with its doc.
- Add-only rows:
  - `Kernel/Governance/Baseline.cls`: `osmgmt.sqlactivity.cancel` `true`.
  - `Kernel/Proposal/Prohibited.cls`: `sql-statement` in `COVEREDTYPES` and the :1498 list, with no predicate.
  - `Screen/Titles.cls`, regenerated.
- Client:
  - `ui/src/app/core/screen-actions.ts`: `SqlActivityList` `cancel` labeled "Cancel query".
  - `shell/screen-action-handler.ts`: `SqlActivityList` in `SCREEN_ACTION_DESCRIPTORS` and `WARNING_CONSEQUENCES`; `DeviceList` in `SCREEN_ACTION_DESCRIPTORS`, `DESTRUCTIVE_ACTIONS` and `DESTRUCTIVE_CONSEQUENCES`.
  - `core/self-protection.ts`, `core/strings.ts`, `core/screens.generated.ts`.
  - `core/proposal-view.ts`, only if the card needs the new codes.
- Tests:
  - `Test/SqlActivityCancel.cls`, new and live-safe on a throwaway. Each leg uses its own `SqlActivityProbe` job and stops it in `OnAfterOneTest`. Legs: both callers cancel and the process survives; a remote row is refused before the vendor (port seam); an ended statement answers `ENDED`; a `PAIRS`-less caller is refused; the governance key is `false`-refused.
  - `Test/DeviceWire.cls`: the Delete row action removes a device the test created.
  - `ui/browser/sql-activity.browser-spec.mjs`: a cancel leg (warning dialog, confirm, probe row gone).
  - `ui/browser/devices.browser-spec.mjs`: a delete leg that types the name and removes its own device.
  - The shared-surface rows under Verification.

### Batch 2: Transactions and System alerts (server and client; commit when its loop is green)

- `src/OcuPilot/Port/Harvest/Alerts.cls` -- new body class extending `Harvest.Handler`: harvested `SystemAlerts`, `AlertsManage` and `UtcStamp`, with their names, bodies and call sites kept (AD-23).
- `scripts/check-objectscript.py` -- add-only `HARVEST_CALLERS` entry: `Harvest.Alerts` maps to `Port/MonitorPort.cls`.
- `src/OcuPilot/Port/MonitorPort.cls`:
  - `ENDPOINTS` adds `Transactions` and `Alerts`.
  - `Transactions` `LIST`: when `SYS.Metrics.SystemMonitorStatus()` is not `OK`, 409 `MONITOR.NOTRUNNING`. Otherwise the rows of both global nodes as `{Kind:"Local"|"Remote", ProcessID, Seconds, Status}`, where `Status` is the node's value mapped as the classic page maps it. The global read sits behind an overridable `TransactionNodes` seam, and `MonitorRunning` is a seam too.
  - `Alerts` `LIST`: `HarvestPort.Invoke` of `Harvest.Alerts`/`SystemAlerts`, projected to one row without `alerts[]`.
  - `Alerts` `RESET`: the port's fixed body `{"action":"reset"}` to `AlertsManage`, under `WRITEPAIRS` from Task 0 (b).
  - The header's alerts sentence names SAM's `Alerts()`.
- `src/OcuPilot/Port/HarvestPort.cls` -- doc only: a harvested body may be a write when its port's tool is one.
- `src/OcuPilot/Api/MonitorError.cls` -- new: `NOTRUNNING` and its reason.
- `src/OcuPilot/Screen/Descriptor/TransactionList.cls` -- new, on `MetricsList`'s shape.
  - Source `{"port":"monitor","endpoint":"Transactions","type":"LIST"}`; route `os-management/transactions`, position 33; `entityType ""`; tool `osmgmt.transactions`.
  - Columns `Kind`, `ProcessID`, `Seconds`, `Status`; `rowTarget` Process details by `ProcessID`, `unless` `Kind` reads `Remote`.
  - `classicPage` `%CSP.UI.Portal.Transactions`; pairs `MonitorPort.PAIRS`.
- `src/OcuPilot/Screen/Descriptor/SystemAlertsList.cls` -- new.
  - Source `monitor`/`Alerts`/`LIST`; route `os-management/system-alerts`, position 34; entity `system-alerts`; scope `instance`; `id none`; tool `osmgmt.systemalerts`.
  - Columns `StateText`, `AlertCount`, `LastAlert`; `rowActions [{"id":"reset","selfProtection":""}]`; `classicPage ""` (no classic reset exists).
- `src/OcuPilot/Screen/Tool/SystemAlertsReset.cls` -- new, on `BackupRun`'s shape.
  - Identity: `TOOLNAME osmgmt.systemalerts.reset`, `DESCRIPTORCLASS SystemAlertsList`, `PORTCLASS MonitorPort`, `ENDPOINTNAME Alerts`.
  - Operation: `READTYPE LIST`, `WRITETYPE RESET`, `SENDSBODY 0`, `FIXEDID "SYSTEM"`, `SCREENACTIONS "reset"`, `DESTRUCTIVE 0`.
  - Fingerprint: `FINGERPRINTSUBJECT "State,AlertCount,LastAlert"`.
- Add-only rows:
  - `Baseline.cls`: `osmgmt.systemalerts.reset` `true`.
  - `Kernel/EntityType.cls`: `system-alerts`.
  - `Prohibited.cls`: `system-alerts` covered, with no predicate.
  - `Titles.cls`, regenerated.
  - `scripts/ci-throwaway.sh`: a new `OCUPILOT_ALLOW_ALERT_RESET` with `# classes: SystemAlertsWrite`, plus its `ui/tools/ci.test.mjs` roster.
- Client:
  - Both screens on the generic list page (inference: no new page component). `screen-actions.ts`: `reset` labeled "Reset alerts". `screen-action-handler.ts`: `SystemAlertsList` in `SCREEN_ACTION_DESCRIPTORS` and `WARNING_CONSEQUENCES`.
  - `strings.ts`, `screens.generated.ts`, and the mirror (`ui/tools/screen-mirror.mjs` reads `ENDPOINTS`).
- `EXPERIENCE.md` -- add-only: the two screens' rows in the OS management table, the Cancel query and Reset alerts actions, and the ruled strings in Fixed strings.
- Tests:
  - `Test/TransactionsRead.cls`, new and live-safe. A fixture's `TransactionNodes` supplies Local and Remote rows; the answer equals them, in order, with mapped `Status`. Monitor off gives 409. A live leg compares the answer with the global read at that moment. A `PAIRS`-less caller is refused.
  - `Test/SystemAlertsRead.cls`, new and live-safe. The row equals `State()`, `Alerts()` and `GetAlerts`' last line at that read. Gate refusal. The reset is driven through a seam and never reaches `Clear()`.
  - `Test/SystemAlertsWrite.cls`, new and armed. Both callers reset; the read-back is 0/0; `alerts.log`'s line count is unchanged; the key at `false` refuses.
  - `ui/browser/transactions.browser-spec.mjs`: the screen answers rows or its empty state after the answered signal.
  - `ui/browser/system-alerts.browser-spec.mjs`: the row; Reset alerts warns, confirms, and the row reads 0.

### Batch 3: DW-2479 (server; commit when its loop is green)

- `src/OcuPilot/Port/LogSourcePort.cls`:
  - Add the overridable `OffsetAtUtc(pUtcH) As %Integer`, which returns `##class(OcuPilot.Kernel.Audit.Ledger).OffsetAtUtc(pUtcH)`; this extends the ledger's helper rather than copying it.
  - `LocalFromUtc` adds that offset to the UTC instant, with output format unchanged.
  - The seam list (:73-82) names it.
- `src/OcuPilot/Test/LogSourceClockProbe.cls`: extends `LogSourcePort` with `OffsetAtUtc` fixed at 7200. `src/OcuPilot/Test/LogSourceClock.cls`, new: the probe's `LocalFromUtc("2026-03-01 10:00:00")` is `2026-03-01T12:00:00.000`, and the shipped offset equals the ledger's over the `LedgerClock` corpus.

**Acceptance Criteria:**

- AC1 (OS-24). Given a running probe statement on `ocupilot-ci`, when a person's Cancel query or the agent's confirmed `osmgmt.sqlactivity.cancel` runs, then the statement stops, its row is gone on the next read, and its process still runs. The agent's write records one AD-15 marker and a `readBack`; the person's records none. A remote row draws no Cancel, and both callers get 409 `SQLACTIVITY.REMOTE` before any vendor call.
- AC2 (DW-1562). Given a device the test created, when a person deletes it from the Devices list, then the typed-name dialog states the ruled consequence and the device is gone from the list and the configuration.
- AC3 (OS-27). Given the System Monitor is running, when the Transactions screen or `osmgmt.transactions` reads, then both answer the same rows, equal to the monitor's local and remote rows at that read. A Local row's Process ID opens Process details. With the monitor off, both answer 409 `MONITOR.NOTRUNNING`.
- AC4 (LG-12; Integration). Given `MonitorPort` consuming `Harvest.Alerts`, when System alerts or `osmgmt.systemalerts` reads, then one row equals `%SYSTEM.Monitor`'s state, count and last alert. When a person's Reset alerts or the agent's confirmed reset runs, then `Clear()` runs once, the screen re-fetches to count 0 and state OK, and `alerts.log` keeps every line.
- AC5. Given the default baseline, when the agent proposes either new write, then it mints and confirms. With its key `false`, the governance gate refuses it.
- AC6 (DW-2479). Given the probe's +2 h offset, when `LocalFromUtc` converts a UTC instant, then the result is two hours later; swapping the direction turns the test red.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-5, AD-8, AD-10, AD-12/AD-39, AD-14, AD-15, AD-21 (DW-1856 below), AD-23, AD-29, AD-36, AD-44, AD-51, AD-52, AD-53, AD-58.

**Consumed-by / Consumes (Rules 1-2):**

- `Port/Harvest/Alerts.cls` is consumed by `MonitorPort` and, through it, by the System alerts screen and `osmgmt.systemalerts`(`.reset`) (AC4).
- Consumes: `HarvestPort` (21.1), `SqlActivityProbe` (19.10), `Ledger.OffsetAtUtc` (23.7).
- No later story consumes the new screens.

**Extends (Rule 2/31):**

- `SqlActivityCancel` extends `BackgroundTaskCancel`'s shape.
- `SystemAlertsReset` extends `BackupRun`'s.
- `TransactionList` extends `MetricsList`'s.
- The Devices delete reuses License servers' pattern.
- `LogSourcePort.OffsetAtUtc` reaches the ledger's helper rather than copying it.
- `Harvest.Alerts` is a new body class rather than an addition to `Harvest.Monitor`. The reason is the checker's one-caller rule: `Harvest.Monitor`'s caller is `BackupPort`.

**Decided in-stage:**

- Transactions reads the classic page's own source (`SYS.Metrics.SystemMonitorStatus()`, `^IRIS.Temp.SysMetrics`), not `%SYS.Journal.Transaction:List`. That source keeps the remote rows and the status, so no scope is narrowed. Named limit: when a kind has no listed transaction, its status is not shown (inference: it reads `OK` then).
- System alerts sits in OS management, not Logs, because the log hub composes every listed Logs screen (`Screen/Timeline.cls:39-69`), and a member it cannot read fails the hub.
- Cancel and reset are not destructive, following the `BackgroundTaskCancel` and `AuditEventReset` precedents, so both keys ship `true`.
- Cancel adds no OcuPilot-process arm. The read already skips the reading process's own row. A cancel ends a statement, never a process, so AD-10's process arm, which judges terminate and suspend, does not reach it. `sql-statement` and `system-alerts` are covered types with no predicate, as Story 21.4's types are. If the gate wants such an arm, that is an AD-10 amendment and goes to the owner.
- The remote refusal is a `Registry` self-protection rule, on `system-pct-access`'s precedent.
- Positions 33 and 34. `classicPage ""` for System alerts.
- The epic context is reused as the runner instructed, although `epics.md` and the spine are newer by modification time.
- Contention: `stage-common.md` names Epic 22, but neither `origin/OCU-1-epic22` nor its worktree exists. Epic 24 is the concurrent epic. Its worktree holds uncommitted `InteropPort.cls` and `scripts/ci-throwaway.sh` edits, so `InteropPort` is untouched and the script is add-only.

**Declined DW-1856:** setting the four language-server paths changes AD-21's clause "shown, never set". It also needs a reworded caption, a choice for clearing a value, and a choice for overwriting `LogFile`. Each of those is an AD amendment or a new string, which no owner answer covers in this unattended run. Recommend the runner escalate it, with a re-own to 21.21 at the owner's word.

**DW-1562 and DW-2479 are addressed** in Batch 1 and Batch 3 (AC2, AC6).

**Strings, escalated for the spec gate's ruling** (proposed wording; nothing is used until ruled):

- Action labels: "Cancel query", "Reset alerts".
- Cancel warning: "Canceling stops this statement where it is. The process that ran it keeps running." (inference until Task 0 (a))
- `REASONREMOTE`: "This statement runs on another server and can be canceled only there."
- `REASONENDED`: "This statement is no longer running."
- Reset warning: "Resetting sets the alert count to 0 and the system state to OK. alerts.log keeps every entry."
- Device delete consequence: "Deleting this device removes it from this instance's configuration. This cannot be undone."
- Transactions:
  - Title and side-bar entry: "Transactions".
  - Columns: "Kind", "Seconds open", "Status", with "Process ID" reused.
  - Values: "Local", "Remote", "Normal", "Warning", "Troubled".
  - Empty state: "There are no open transactions."
  - `NOTRUNNING`: "Transaction data is not available because the System Monitor is not running."
  - Prompt: "Which process has held a transaction open longest?"
- System alerts:
  - Title and side-bar entry: "System alerts".
  - Columns: "State", "Alerts", "Last alert".
  - Values: "OK", "Warning", "Alert", "Hung".
  - Prompt: "Why is the system state not OK?"

**Runner ruling at the spec gate (2026-11-15):** DW-1856 is declined here and set decision-pending for the owner (an AD-21 change). The escalated strings and the in-stage choices are kept (veto U-66).

**Task 0, measured on `ocupilot-ci`** (each principal held exactly the grants named, plus READ on the code database):

- (a) A caller holding `SqlActivityPort.PAIRS` cancels another user's probe statement only with the SQL admin privilege `%CANCEL_QUERY` granted to its role. Without it `CancelQuery` answers `#5521 ... SQLCODE=-99 ... does not have the SQL Admin Privilege %CANCEL_QUERY required to cancel a query executed by another user`, and still does so with `%Admin_Manage:USE`, `%Admin_Secure:USE`, `%Development:USE` and `%DB_USER:WRITE` added. With it: the answer is OK, the statement ends with SQLCODE -456 "SQL query execution interrupted by user", its row is gone within 1 s, and the probe's process stays alive (state `HANG`). The warning's second sentence holds.
- (b) `Clear()` is refused `<PROTECT>` with `%Admin_Operate:USE` plus `%DB_IRISSYS:READ` or `:WRITE`. `%Admin_Manage:USE` alone clears (State 2 to 0, Alerts to 0); the harvested body's switch to `%SYS` also needs `%DB_IRISSYS:READ` (without it `<PROTECT>` on the namespace). `alerts.log` kept its size, and `smoke.sh` read 50/50 afterwards.
- (c) A local probe job holding `TSTART` plus a journaled set appeared in `^IRIS.Temp.SysMetrics("Transactions")` after 43 s as row 1 (`pid` the job, `secs` 30, node `OK`). A caller holding `MonitorPort.PAIRS` read the node, `SystemMonitorStatus()` (`OK`, from `%SYS`) and the row.

## Verification

Shared surfaces (each is in the `(loop)` set; the implement stage greps `ui/browser`, `ui/tools`, `ui/src` specs and `src/OcuPilot/Test` for the old shape):

- OS management rosters and pair-order counts: `Navigation` (64 to 66 screens, positions 33 and 34), `WireSecurityRead`, `WireAreaAnyScreen`, `ui/tools/navigation.test.mjs`.
- `Descriptor`, including the device row-action pin at :2475 and `EntityType.Count`.
- `TeardownGuard`.
- The read-source count.
- `ReadTool`'s size (445 to 449), `ReadDescriptions`, and `ToolWrite`'s counts.
- `Prohibited`, `ClassicPageGate`, `MappingDescriptor`, `SurfaceCoverage`, `StageTwoTools`, `ToolRoundTrip`, `PortGate`, `EndpointCoverage`, `GovernanceBaseline`.
- `LanguageServerWire` and its browser spec, which are unchanged and re-run.
- `self-protection.test.mjs`, `ci.test.mjs`, `screen-mirror`.
- The EXPERIENCE.md literal cap. If the ruled strings cross 4200, raise it to 4600 under its protocol.

Every test added or changed passes on a fresh environment, in either order. Each pinning test records `mutation:` lines here:

- AC1: drop the `Remote` refusal.
- AC2: drop `SCREENACTIONS`.
- AC3: swap the `Kind` mapping.
- AC4: skip `Clear()`.
- AC5: the key fallback.
- AC6: the offset's sign.

**Commands.** ObjectScript test runs are one call each, never two in one message.

- `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` (loop) -- expected: `LOADERRORS=0`, no compile error.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>` (loop), once for each of: `SqlActivityCancel`, `SqlActivityPort`, `SqlActivityDescriptor`, `DeviceDelete`, `DeviceWire`, `TransactionsRead`, `SystemAlertsRead`, `SystemAlertsWrite`, `MonitorPort`, `MetricsDescriptor`, `Harvest`, `HarvestWire`, `LogSourceClock`, `LogSource`, `LedgerClock`, and every shared-surface class above -- expected: all green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: within the 2500/4000 kB budgets.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>.browser-spec.mjs` (loop), one call per file: `sql-activity`, `devices`, `transactions`, `system-alerts`, `language-servers` -- expected: green.
- `cd ui && npm run test:tools` and `cd ui && npm run test:components` (loop) -- expected: green.
- `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep over `src/OcuPilot/Test` (once, before `dev_complete`), one class per call or batches sized from `ui/tools/ci-timings.json` to about 8 minutes -- expected: green. The full browser suite is left to CI (Rule 29).

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- Task 0 (a): canceling another user's statement needs the SQL admin privilege `%CANCEL_QUERY`, which is not a resource:permission pair, so `SqlActivityPort.PAIRS` and `WRITEPAIRS` cannot express it (measured on `ocupilot-ci`, Design Notes). The vendor answers #5521 / SQLCODE -99 with every pair tried. Needs an owner ruling: gate on `PAIRS` and map -99 to a 403 `SQLACTIVITY.*` code with a new ruled reason string (recommended, inference), or another approach; granting `%CANCEL_QUERY` to a role is a privilege grant. Also for Batch 2: `Clear()` needs `%Admin_Manage:USE` (+ `%DB_IRISSYS:READ`), a pair beyond `PAIRS`.

Work done: Task 0 (a), (b), (c) measured and recorded under Design Notes. No code written; Batches 1 to 3 not started.
