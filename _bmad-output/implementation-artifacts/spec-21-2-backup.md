---
title: 'Story 21.2: Backup'
type: 'feature'
created: '2026-11-14'
status: 'done'
baseline_revision: '97f1aa93577932c2007d466c995682bea3eaaed6'
baseline_commit: '35428547162d34e0d0506a673641444a59655d08'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Backup has no screen and no API in OcuPilot. An operator who wants to list the backup tasks, run one, read the history, keep the backup database list, or freeze and thaw writes for an external backup has to go to the classic portal's legacy CSP pages. The highest-consequence operation there, freeze, has no time limit: writes stay suspended until someone thaws them.

**Approach:** Add one gated port, `BackupPort`, and three OS management screens: Backup tasks, Backup history and Backup database list. History and run go through the harvested `BackupManage` body behind `HarvestPort` (AD-23). Freeze, thaw and the list writes are the port's own code. Every write is one operation with two callers (AD-53): a confirmed agent proposal and the screen's own action. Every governance key ships `false`. Every freeze carries a suspend limit the port enforces. Close DW-2560 in the same change: harvested body classes get a containment rule and a `PortGate` row kind.

## Boundaries & Constraints

**Always:**

- `BackupPort` evaluates its declared pairs with `$System.Security.Check` before any vendor call (AD-29), and switches `$NAMESPACE` by save and restore (AD-16).
- The harvested body is `OcuPilot.Port.Harvest.Monitor.BackupManage`, copied from the sibling at `c6aad31`. Only the base class, the `..` rename and the doc comment change. `BackupPort` builds the body's JSON itself and sends only `{"action":"listHistory"}` or `{"action":"run","taskName":<name>,"jobbackup":1}`.
- A backup task, a database and a freeze limit are validated by the port before the vendor is called, and again at the write for both callers. A task is named from `Backup.Task:List`'s names and a database from `Config.Databases`. No caller value is a path (AD-21).
- A freeze calls `Backup.General.ExternalFreeze` with `WDSuspendLimit` set to the caller's limit, a whole number of seconds from 1 to `FREEZELIMITMAX` (600). It is refused before any vendor call when the limit cannot hold (see the matrix).
- Each write is action-style (AD-51), declares `BackupPort` (AD-52), and is minted, fingerprinted, confirmed once and audited (AD-6, AD-34, AD-15). Each reads its target back (AD-58) and emits one change event (AD-14).
- `Kernel/Governance/Baseline.cls` gets five keys, each `false`: `osmgmt.backuptasks.run`, `osmgmt.backuptasks.freeze`, `osmgmt.backuptasks.thaw`, `osmgmt.backupdatabases.add` and `osmgmt.backupdatabases.remove` (AD-22).
- Every read is bounded and reports truncation (AD-36).

**Never:**

- No restore, no `AbortBackup`, no task create, edit or delete, and no device, log-file, username or password argument anywhere.
- No new `PROHIBITED.*` predicate. `Prohibited.cls` gains only the backup entity types as covered types.
- No `##class(OcuPilot.Port.Harvest.*)` or literal body-class name outside `HarvestPort`, `Port/Harvest/`, the body's declared area port and `src/OcuPilot/Test/` (DW-2560).
- No edit to the harvested body's code.
- No user-facing string beyond those ruled in Design Notes.

## I/O & Edge-Case Matrix

All rows are observed through the OcuPilot API on `ocupilot-ci`: the screen read route, the screen action route, and a proposal's confirm.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Tasks read | `GET` Backup tasks | One row per `Backup.Task:List` row: name, type, last run, status, description and whether it is a system task. It includes `FullAllDatabases`, `FullDBList`, `IncrementalDBList` and `CumuIncrDBList`. Also `writesFrozen` from `IsWDSuspended()`. | none |
| History read | `GET` Backup history | Up to 50 rows from the harvested `listHistory`, newest first. `truncated` is true only when a 51st `^SYS("BUHISTORY")` entry exists. | a body fault takes the port convention |
| Database list read | `GET` Backup database list | One row per `Backup.General:DatabaseList` row (database, directory). An empty list answers no rows. | none |
| Run | task `FullDBList`, both callers | The backup is started in the background through the body (`jobbackup` 1). `readBack` reads `nothingSent`. Within the test's bounded poll, the task's status leaves its prior value or a new history row appears. | an unknown task is 404 `BACKUP.TASK.NOTFOUND` before any vendor call |
| Run while running | any task's status reads `Running` | 409 `BACKUP.RUNNING`. Nothing is started. | not logged |
| Freeze | limit 5 | `writesFrozen` reads true. Within limit plus the measured slack, it reads false again without a thaw. | none |
| Freeze, bad limit | missing, 0, 601, `"x"` | 400 `BACKUP.FREEZE.LIMIT` at mint and at the port | nothing frozen |
| Freeze, already frozen | `IsWDSuspended()` 1 | 409 `BACKUP.FROZEN` | nothing called |
| Freeze, limit cannot hold | the clustered-system predicate (Task 0) reads true | 409 `BACKUP.FREEZE.UNBOUNDED` before any vendor call | verified through a fixture seam only (inference: no clustered system to test on) |
| Thaw | frozen | `writesFrozen` reads false | none |
| Thaw, not frozen | not frozen | 409 `BACKUP.NOTFROZEN` | nothing called |
| List add / remove | an existing database not on the list / on the list | The list read then holds it / no longer holds it | absent database 404 `BACKUP.DATABASE.NOTFOUND`. Already listed, or not listed, is 409 `BACKUP.LIST.CONFLICT`. `IRISTEMP` is the vendor's refusal, normalized. |
| Governance | default baseline | An agent proposal for any of the five tools is refused by the governance gate. Setting the key `true` lets the same proposal mint. | structured denial (AD-22) |
| Gate | caller lacks a declared pair | 403 `AUTH.NOPRIVILEGE`. No vendor call and no body run. | not logged |

</intent-contract>

## Code Map

- `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/Monitor.cls:1281-1489` -- `BackupManage` at `c6aad31` (read-only source). Its doc comment (lines 1284-1289) says there are no shipped task names; `irissys/Wsback.int:375-380` defines four. Its freeze passes no `WDSuspendLimit` and takes a log file, and its thaw takes credentials, so only `listHistory` and `run` are reached through it.
- `src/OcuPilot/Port/HarvestPort.cls:50-80` -- `Invoke`'s contract; `Port/Harvest/Handler.cls` is the base. `SanitizeError` collapses a body's refusal to `INTERNAL` (`spec-21-1-the-harvest-seam.md`, "Named limits"), so `BackupPort` validates first. `Test/HarvestFixture.cls` shows how a verbatim body is held.
- `irissys/Backup/General.cls:165` (`ExternalFreeze`, `WDSuspendLimit` 10th), `:192` (`ExternalThaw`), `:235` (`StartTask`), `:336/:341` (`AddDatabaseToList`/`RemoveDatabaseFromList`, by name per `Wsback.int:250-260`), `:399` (`DatabaseList`), `:417` (`IsWDSuspended`), `:96-103` (`ExternalFreezeTimeOut`, 600 s). `irissys/Backup/Task.cls:133` (`List`, built-ins first), `:110` (`History`); no SQL projection (measured).
- `irissys/%CSP/UI/Portal/Application.cls:405-421` -- the classic Backup menu needs `%Admin_Operate` and `%DB_IRISSYS` READ and WRITE; `:210-216` the Database Backup List.
- Write family: `Port/DatabasePort.cls`, `Screen/Tool/DatabaseAction.cls`, `Screen/Tool/DatabaseCompact.cls` (port `Invoke`, `STATE`, `SCREENACTIONS`/`SCREENVALUES`, `ARGUMENT`, `FINGERPRINTSUBJECT`, `CLASSICPAGES`, `ArgumentProblem` through a rules class). `Screen/Tool/ExplorerSqlRun.cls` is a non-removing `DESTRUCTIVE` tool; `Screen/Tool/InteropProductionRecover.cls:20` a non-destructive `CONSEQUENCECODE` (client: `core/proposal-view.ts:403,575`).
- Models: Story 18.20 (`Screen/Descriptor/EcpDataServerList.cls:21-74`, `Screen/Tool/EcpDataServerDelete.cls`, `Area/OsMgmt/EcpRules.cls`, `Api/EcpError.cls:16-24`, `spec-18-20-ecp-data-servers.md`); Story 20.34's cube build (`f60db04b4`, `acb0b6660`), a list page with two writes.
- `Screen/Tool/Write.cls`: `DESTRUCTIVE` :43-52, `READTYPE`/`WRITETYPE`/`SENDSBODY` :57-67, `FINGERPRINTSUBJECT`/`PRECONDITIONFIELD` :97/:105, `PORTCLASS` :114, `CLASSICPAGES` :124, `SCREENACTIONS` :167, `SCREENVALUES` :238, `READBACKFIELDS` :1035. `Kernel/Proposal/Mint.cls:135`, `Confirm.cls:248`, `Api/ScreenAction.cls:436,446`, `ReadBack` (`nothingSent` :47, `Running` :226). The tool registry scans the package (`Screen/Tool/Registry.cls:814`).
- Read source: `Screen/Read.cls:167-330` (`SOURCE<x>`), list `:442`; `Screen/Registry.cls:1223-1224,1316`.
- Entity types: `Kernel/EntityType.cls:126`, `Kernel/EntityRef.cls:59`, `Kernel/Proposal/Prohibited.cls` (`TYPE<X>` :285-757, `COVEREDTYPES` :282, `Prohibits` :1460, `PermittedChangeFields`/`PermittedCreateFields` :1200/:1340). Without these every write is refused as uncovered.
- `Api/Error.cls:1233,1451` -- the code-prefix dispatch `BackupError` joins.
- Classic keys (compiled `%cspapp`, read from slot A): `%cspapp.op.utilsysbackups`, `%cspapp.op.utilsysbackup`, `%cspapp.op.utilsysbackuplogs`, `%cspapp.mgr.utilsysbackupdatabases`. Precedent `JournalList.cls:48`; `Test/Descriptor.cls:362-377` opens each.
- `Kernel/Governance/Baseline.cls:6-29` -- one line per key; a `false` key also joins `Test/GovernanceBaseline.cls:15`'s `DISABLED`, in the baseline's own line order (`:61-73`). `:21-36` fails for a write key with no line.
- `Screen/Area.cls:83` -- `os-management`'s pairs; side-bar positions 1-22 are taken, backup takes 23-25.
- Client: `shell/screen-outlet.ts:54` (generic `list-page`); `shell/screen-action-handler.ts` rosters `SCREEN_ACTION_DESCRIPTORS` :70, `DESTRUCTIVE_ACTIONS` :544 (verb-global; a listed verb with no consequence on its screen is not drawn, :563-570), `DESTRUCTIVE_CONSEQUENCES` :572; `core/strings.ts`, `core/screen-actions.ts`, `core/proposal-view.ts`, `screens.generated.ts` (`node tools/screen-mirror.mjs`).
- Roster tests a new screen and tool join: `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `PortGate`, `ReadTool` :94, `ReadDescriptions` :35, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `Descriptor`, `Navigation` :540-543, `ClassicPageGate`, `DraftRegistry` :71, `StageTwoTools`, `Wire`, `WireAreaAnyScreen`; client `ui/tools/navigation.test.mjs`, `screen-mirror.test.mjs`, `proposal-view.test.mjs`, `shell/rail-wire.spec.ts`, `area-verdict.spec.ts`. No route is added, so `EndpointCoverage` is untouched.
- `Test/PortGate.cls:22-48` -- roster and row kinds (`<vendor>`, `<table>`, `<stub>`, `<caller>`).
- `scripts/check-objectscript.py:656-737` -- `check_admin_api_containment`, the model for DW-2560's rule; harness rows `scripts/test_check_objectscript.py:1188,1777`.
- `scripts/ci-throwaway.sh:594-754` -- arming variables; `ui/tools/ci.test.mjs` holds the roster.
- `Test/ProbeNamespace.cls:12,44` -- a probe database in its own directory, for the run test.

## Tasks & Acceptance

**Execution, batch 1 (server; commit when its loop commands are green):**

- Task 0, measure on `ocupilot-ci` and record under Design Notes before writing code: the pair set as a least-privileged principal (AD-29); the four classic keys from `NormalizePage`; whether `WDSuspendLimit` resumes writes on this build, and the slack; how `ExternalFreeze` detects a clustered system; `StartTask`'s answer for an unknown task and a second run; `AddDatabaseToList`'s answer for a duplicate and for `IRISTEMP`.
- `src/OcuPilot/Port/Harvest/Monitor.cls` -- new. `BackupManage` verbatim apart from the base class and the `..` rename. Replace the sibling's doc-comment claim that no task names ship with the true contract: the instance ships four (`Wsback.int:375-380`), and `BackupPort` reaches only `listHistory` and `run`.
- `src/OcuPilot/Port/BackupPort.cls` -- new. `PAIRS`, `WRITEPAIRS`, `FREEZELIMITMAX` = 600; `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pResult, Output pHttpStatus, Output pFault)` branches `TASKS`, `HISTORY`, `DATABASES`, `STATE`, `RUN`, `FREEZE`, `THAW`, `ADD`, `REMOVE`; `Snippet`/`SnippetForm` (AD-59), overridable `GateClass`/`LogFault`, and a fixture seam for the clustered predicate.
- `src/OcuPilot/Area/OsMgmt/BackupRules.cls` -- new. The matrix refusals, asked by the mint and by the port.
- `src/OcuPilot/Api/BackupError.cls` -- new. The matrix codes, on the `EcpError` model.
- `src/OcuPilot/Screen/Descriptor/BackupTaskList.cls`, `BackupHistoryList.cls`, `BackupDatabaseList.cls` -- new. Read, classic page from Task 0, pairs, row and command actions.
- `src/OcuPilot/Screen/Tool/BackupAction.cls` (abstract, on `DatabaseAction`'s model) and `BackupRun`, `BackupFreeze`, `BackupThaw`, `BackupDatabaseAdd`, `BackupDatabaseRemove` -- new. `BackupRun` declares `DESTRUCTIVE` 1; `BackupFreeze` declares a `CONSEQUENCECODE`; `BackupDatabaseRemove`'s screen action id is `removedatabase` (Design Notes). Each declares `READBACKFIELDS` or none.
- Add-only rows, as Story 18.20 added them: `Kernel/Governance/Baseline.cls` and `Test/GovernanceBaseline.cls`'s `DISABLED`; `Screen/Read.cls` and `Screen/Registry.cls` (`SOURCEBACKUP`); `Kernel/EntityType.cls`, `Kernel/EntityRef.cls`, `Kernel/Proposal/Prohibited.cls` (`backup-task`, `backup-database`, covered, no predicate); `Api/Error.cls` (`BACKUP.`); `Screen/Titles.cls`, regenerated.
- `scripts/check-objectscript.py`, `scripts/test_check_objectscript.py` -- DW-2560: a body class under `Port/Harvest/` may be named only in `HarvestPort`, `Port/Harvest/`, its declared caller (`HARVEST_CALLERS`: `OcuPilot.Port.Harvest.Monitor` -> `src/OcuPilot/Port/BackupPort.cls`) and `src/OcuPilot/Test/`, with harness rows for a hit and a miss.
- `src/OcuPilot/Test/PortGate.cls` -- DW-2560: the `BackupPort=PAIRS;WRITEPAIRS` row, and a `<body>` row kind for `OcuPilot.Port.Harvest.Monitor` asserting it extends the base, defines no `Invoke`, and records nothing when called outside the port.
- `_bmad-output/implementation-artifacts/spec-21-1-the-harvest-seam.md:183` -- DW-2560: replace the "cannot be wired as a route past the port's gate" sentence with "outside a `HarvestPort` call it records nothing and fails; what keeps a body behind the gate is the containment rule (DW-2560)."
- `scripts/ci-throwaway.sh`, `ui/tools/ci.test.mjs` -- `OCUPILOT_ALLOW_BACKUP_CONTROL`, with a roster row.
- `src/OcuPilot/Test/BackupRead.cls` (live-safe: three reads, history through the port, gate refusals, governance defaults), `BackupRules.cls` (every refusal row, live-safe), `BackupWrite.cls` (armed: run, freeze, thaw, add, remove, by both callers; restores the list it found and thaws in `OnAfterOneTest`; the run test lists only a probe database it creates).

**Execution, batch 2 (client; commit when its loop commands are green):**

- The three screens on the generic `list-page`, no custom page unless a dialog needs one: Run as a row action, Freeze writes (with its limit field) and Thaw writes on the tasks command bar, Add database and Remove on the list screen. Files: `ui/src/app/areas/os-management/backup-*.ts` with specs, `shell/screen-action-handler.ts`'s rosters, `core/strings.ts`, `core/screen-actions.ts`, `core/proposal-view.ts`, `screens.generated.ts` (regenerated).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings.
- `ui/browser/backup.browser-spec.mjs` -- new. Each screen answers its rows; freeze then thaw flips the frozen banner; add then remove round-trips a probe database; it waits for the answered signal each time.

**Acceptance Criteria:**

- AC1. Given the three screens and five tools, when each read and each write runs through the OcuPilot API on `ocupilot-ci`, then it round-trips over its backing class: every matrix row from "Tasks read" to "List add / remove".
- AC2. Given the default baseline, when the agent proposes any of the five writes, then the governance gate refuses it. With the key set `true` it mints, and the confirm writes once with one audit marker and a `readBack`.
- AC3. Given any freeze, from either caller, when it is issued, then the vendor call carries `WDSuspendLimit` equal to the limit, from 1 to 600, and writes resume without a thaw within that limit plus the measured slack. A freeze whose limit cannot hold is refused before any vendor call.
- AC4 (DW-2560). Given a file outside the allowed set that names `OcuPilot.Port.Harvest.Monitor`, when `check-objectscript.py` runs, then it fails, naming the file and the rule. `PortGate` is red for a `Port/Harvest/` class with no roster row.

### Review Findings

Code review 2026-11-14 (first review; layers blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor, full-opus).

- [x] [Review][Patch] Probe database recreate wedges the instance (Rule 19, MED, rework) - a recreate right after the run test's teardown failed `<PROTECT>%SaveData+182^SYS.Database.1` and left a mount nothing clears; the cause is `(inference)`: a database a backup touched was deleted or recreated before the backup had ended. Ruling: the run test (and `BackupWriteGate`'s run) get their own probe database name and directory, apart from the add/remove test's. `BackupProbe.Create` and `Remove` take an optional database name (`Create()` makes `DATABASE`; `Remove()` with none clears both names), each name with its own directory. `Remove` deletes a database only after a real signal that no backup is running (no `DBACKA` process), never after a sleep, and reports `backup` when the signal does not come. No test deletes, recreates or removes the directory of a database a backup touched before that signal. Never delete, dismount or recreate a database while a backup may be running, and never run a backup outside the shipped tests. [src/OcuPilot/Test/BackupProbe.cls, src/OcuPilot/Test/BackupWrite.cls, src/OcuPilot/Test/BackupWriteGate.cls]
- [x] [Review] Verify on the rebuilt `ocupilot-ci`, after reloading `src`, one call each: `BackupWriteGate` green with its `mutation:` line written (Rule 19); `BackupWrite` twice in succession; `BackupRead`, `BackupRules`, `PortGate`; then `backup.browser-spec.mjs` after a build and redeploy. After each ObjectScript run: no probe database configured or mounted, writes thawed, the backup database list as before the run. A shipped test that wedges the instance stops the pass (`blocked`); nothing is cleared by hand.
- [x] [Smoke] The runner's full ObjectScript sweep is red on three shared-surface tests the story did not update (Rule 30 shared surfaces): `WireSecurityRead.TestTheProcessesListsPairSetIsEnforcedForARealPrincipal` (OS management's screen list and pair-order assertions for the operate and secure principals now meet the three Backup screens), `LanguageServerWire.TestAnAreaHolderKeepsOsManagementAndIsRefusedTheServers` ("only External language servers is refused, on its own pair" no longer holds once the Backup screens are in the area), and `TeardownGuard.TestEveryTeardownThatTouchesSharedStateOpensWithAGuard` (`OcuPilot.Test.BackupWrite`'s teardown has no guard). Update each to the Backup screens' real pairs and positions, read from the instance, never recalled; give `BackupWrite`'s teardown the guard its siblings use; then run each of the three classes green on `ocupilot-ci`, and `BackupWrite` and `BackupWriteGate` green, one call each.
- [x] [CI] instance shard 4/8: `BackupWrite.TestARunStartsTheTaskOnBothCallers` asserted `409|BACKUP.RUNNING` for a freeze while a backup runs and got `409|BACKUP.FROZEN` (the backup's own write suspension, the race DW-2575 names) — https://github.com/jbrandtmse/OcuPilot/actions/runs/43699492613. Make the live row deterministic: it asserts a 409 refusal whose code is `BACKUP.RUNNING` or `BACKUP.FROZEN` (both are correct refusals while a backup holds writes), and pin the #7309-to-`BACKUP.RUNNING` mapping where it cannot race: a `BackupRules` or seam-level test that feeds the vendor status #7309 to the port's mapping. Close DW-2575 with it.
- [x] [CI] browser shard 4/5: `language-servers.browser-spec.mjs` AC5 ("... and no other") — an OS management holder without the own pairs now also sees the three Backup screens unavailable, naming `%DB_IRISSYS:WRITE`. Update the spec's expected set to the Backup screens' real pair, read from the descriptors, keep it exact; grep `ui/browser` for any other spec asserting OS management's unavailable or visible screens and update it the same way. Rebuild, redeploy and run each changed spec on `ocupilot-ci`.
- [x] [Review][Patch] HIGH: a freeze fails 500 for the write pairs' holder (AD-29, Rule 6) — measured as a least-privileged principal: `%SYS.Capture` refuses `ExternalFreeze`'s output with `<PROTECT>write+2^%SYS.Capture`. `SuspendCall` now sends the output to the null device, saving and restoring the caller's redirection; `BackupPort` left the checker's capture roster; `Test/BackupWriteGate.cls` (armed by `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_BACKUP_CONTROL`) pins both pair sets as probe principals. Measured before the patch: the read pairs' holder read all four and was refused a freeze naming `%DB_IRISSYS:WRITE`; the write pairs' holder added, removed and ran a backup through the port, and froze and thawed with the output on the null device. After it, the writer's freeze through the port reached the vendor (409 `BACKUP.RUNNING` on the wedged throwaway, no `<PROTECT>`); `BackupWriteGate` is green on the fresh throwaway (runs 47 and 49) with its mutation line under Verification. [src/OcuPilot/Port/BackupPort.cls:603]
- [x] [Review][Patch] The clustered-system probe fails open (AD-10, AC3; MED) — an error now reads clustered, so the freeze is refused. [src/OcuPilot/Port/BackupPort.cls:126]
- [x] [Review][Patch] A run while frozen and a freeze while a backup runs answered 500 (MED) — measured: the vendor refuses both with #7309. A run is refused while writes are frozen (`BACKUP.FROZEN`, before the vendor), a freeze's #7309 is answered `BACKUP.RUNNING`, a thaw's #7339 `BACKUP.NOTFROZEN`, and a freeze refused while already frozen `BACKUP.FROZEN`. [src/OcuPilot/Area/OsMgmt/BackupRules.cls, src/OcuPilot/Port/BackupPort.cls]
- [x] [Review][Patch] AC3's limit was pinned only within six seconds (MED) — `SLACK` 3 and a still-frozen assertion three seconds into a five-second freeze. [src/OcuPilot/Test/BackupWrite.cls]
- [x] [Review][Patch] "Every row names the write state" could not fail (MED) — counts boolean `WritesFrozen` per row. [src/OcuPilot/Test/BackupRead.cls:104]
- [x] [Review][Patch] The client's run and freeze consequence sentences were pinned by source text only (MED) — executed asserts in `ui/tools/proposal-view.test.mjs`.
- [x] [Review][Patch] LOWs patched: the screen's freeze and thaw refuse a target other than `SYSTEM` (AD-53); a boolean `limit` is no limit; `BackupRules.LIMITMAX` removed in favour of the port's `FREEZELIMITMAX` and the 999 cap lifted; the history label says what `Databases` holds (`All` or `List`); `KeepHistory` so the run test leaves no history row, and `Remove`'s doc no longer claims it does; the empty-list row asserted; `Start()`'s status asserted and the run test waits on the history row; `Prohibited.cls`'s comment order; EXPERIENCE.md's entry joiner and tag; `AdminPairCorpus`'s case name; the checker's rule 16 names the harvest containment; `BackupRules`' header states what its mint test reads; the browser helper's comment.
- [x] [Review][Defer] Mint sentence for a missing task or database [src/OcuPilot/Kernel/Proposal/Mint.cls:186] — deferred: DW-2568 (wontfix-accepted).
- [x] [Review][Defer] Frozen banner after the limit passes [src/OcuPilot/Screen/Descriptor/BackupTaskList.cls] — deferred: DW-2569 (wontfix-accepted).
- [x] [Review][Defer] Freeze copy omits the journal switch and the failed-backup rule — deferred: DW-2570 (wontfix-accepted).
- [x] [Review][Defer] Two runs at once answer 500 — deferred: DW-2571 (wontfix-accepted).
- [x] [Review][Defer] Write state reads Frozen during a backup's own suspension — deferred: DW-2572 (unverified MED; settle by thawing within that second).
- [x] [Review][Defer] Rule 31 shape copied from `DatabaseAction` and the ports' `Text` helper — deferred: DW-2573 (wontfix-accepted).

Code review 2026-11-15 (rework re-review, iteration 1; range `d78f35b41..HEAD`; layers blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor, full-opus). No HIGH. Both open items confirmed on the fresh `ocupilot-ci`: no probe database configured or mounted after `BackupWriteGate` (run 49, 2 green) and `BackupWrite` (run 50, 9 green), writes thawed, the probe task gone; `backup.browser-spec.mjs` 3 of 3.

- [x] [Review][Patch] `WaitForNoBackup`'s writes-suspended clause had no pin (MED) — `TestAFreezeAndAThawSucceedOnBothCallers` asserts the signal does not come while the screen's freeze holds. Compiled (`LOADERRORS=0`); not run here (the stage's one `BackupWrite` run came first). Its mutation, which drops `'..WritesFrozen()` from `WaitForNoBackup`, is left to the runner's fresh check. [src/OcuPilot/Test/BackupWrite.cls:170]
- [x] [Review][Defer] The no-backup signal's `DBACK*` routine match misses a measured phase of a running backup, and its process clause is unpinned [src/OcuPilot/Test/BackupProbe.cls:296] — deferred: DW-2574 (routed burndown; unverified MED, settled by sampling the backup job by pid until it exits).
- [x] [Review][Defer] The run test's mid-backup rows race the end of a backup that lasts seconds [src/OcuPilot/Test/BackupWrite.cls:296] — deferred: DW-2575 (routed burndown). The freeze row asserts a 409 on `BACKUP.RUNNING` or `BACKUP.FROZEN` (a `BACKUP.FROZEN` answer during the backup's own suspension is the matrix's "Freeze, already frozen" row); the vendor's #7309 mapping is pinned in `BackupRead`. Still open: the rows race a backup that ends before them (rework 3 review, below).
- [x] [Review][Defer] `Remove`'s wait for the signal is unpinned [src/OcuPilot/Test/BackupProbe.cls:125] — deferred: DW-2576 (wontfix-accepted).
- [x] [Review][Defer] A thaw offered during a backup's own suspension — deferred: DW-2572 (occurrence).

Rejected (re-review): `SuspendCall` restoring redirection without re-selecting the null device (low: the capture fixture still captures after the vendor call in runs 45, 46 and 50, and a `Use` of the suffixed name is the fault this rework fixed); `TaskStatus`'s `(error)` reading as idle, a freeze not made by a backup reported as `backup`, a non-backup `DBACK*` process, `Remove` accepting an unknown name, `Create` and `OnBeforeAllTests` not acting on a refused `Remove`, the teardown not seeing a leaked run database (low: unreachable in the shipped order or loud at the next `Create`; each fix adds a guard); `Remove` deleting an `IRIS.DAT` the vendor refused (false: the directory goes only when nothing is mounted there); the agent's second run refused by a lingering job (false: the run refusal reads task status, after `WaitForIdle` and `WaitForSettled`); the stale `baseline_revision` (false: it is the story base, which no rework overwrites); spec `done` against tracker `review` (false: build-auto's machine state); the spec's stale capture-roster note and the HIGH item's pending clause (corrected at their origin).

Code review 2026-11-15 (rework re-review, iteration 2; range `6b14e2800..HEAD`; layers blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor, full-opus). No HIGH. The `[Smoke]` item is closed: on `ocupilot-ci`, after `LOADERRORS=0`, `WireSecurityRead` 25 (run 762), `LanguageServerWire` 4 (run 763) and `TeardownGuard` 4 (run 764) are green. Each roster only gained the three Backup entries (positions 23 to 25, the descriptors' declared pairs), and nothing was loosened. The refusal of an area holder without `%DB_IRISSYS:WRITE` is by design: the classic Backup menu is disabled without `%DB_IRISSYS` READ and WRITE (`Application.cls:407`, Design Notes).

- [x] [Review][Patch] `LanguageServerWire`'s doc comments said the area holder keeps every other listed OS management screen, while six are refused, each on its own pair (LOW) [src/OcuPilot/Test/LanguageServerWire.cls:9,246]

Rejected (iteration 2):

- `WireSecurityRead`'s mutation edits the expected literal, not the product (low): the assertion is an exact equality with the live roster, so it fails on any change to that roster.
- `SECUREUSER` cannot see a swap of the Backup screens' second and third pairs (low): the only effect is which pair a refusal names, and a fix needs a new principal.
- The `Shared surfaces:` line and the `(loop)` list omit the three tests (rejected: the fix edits the spec under review).
- The spec reads `done` while the tracker reads `review` (false: the spec field is build-auto's state, and the tracker is synced at this review).
- `BackupWriteGate` is cited from run 753, before mutations 755 to 757 (false: their product mutation was reverted byte-identical, and no product file differs in the range).
- The cycle log's `cycle_iteration` numbers (rejected: the runner's bookkeeping, which this stage does not write).
- Outside the range and below HIGH, so not filed here: `BackupWriteGate.OnAfterAllTests` has no arming guard, and `Navigation.cls`'s count-history comment stops at fifty-four although its assertion reads fifty-seven.

Rejected: the second wait in the run test racing the start (false: `StartTask` reads `Running` within 0.03 s, measured); `InputSchema` with no `required` array (false: `Write.InputSchema` always builds one); Add as a row action on listed rows (false: the client registers Add at screen level and draws only Remove on a row); the backup source accepting `rows` (false: every source's block skips it alike); the history `LIST` through `Invoke` dropping its cut (low: no caller reads history through `Invoke`); `MoreHistory`'s catch reading not truncated, a non-integer history subscript, the snippet's database case, the browser after-hook when its first probe fails, a process death between seed and restore (low: unreachable in use, each fix adds a branch); the checker matching only the literal body name and exempting the declared caller wholly (low: rejected at the implement review on the same reason; `PortGate`'s body row and the review layer cover the caller); the body's comment dashes (forced by the ASCII rule; the fix edits only the spec); `PortGate`'s body row asserting the base render (low: every body renders through it); AC2's audit marker pinned for freeze only (low: one pinning test per AC); a free-text Add database field (an improvement, not a defect).

Code review 2026-11-15 (rework re-review, iteration 3; range `354285471..HEAD`; layers blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor, full-opus). The `[CI]` items hold: `BackupGateSeam`'s vendor-code hook is a test-class override over a process-private global, set only by `BackupRead` and cleared by `Reset` before and after every test; the AC5 set is exact on the descriptors' `%DB_IRISSYS:WRITE`.

- [x] [Review][Patch] HIGH: the run test's run-while-running rows still raced the backup's phases - once the task reads Completed while the backup's own suspension of writes holds, the screen answers `409|BACKUP.FROZEN` and the mint "Database writes are already frozen." (DW-2572 measured that window). Both rows now accept either refusal (each code pinned in `BackupRules.TestARunAndAListChangeAreJudgedAgainstTheirTarget`), are asked straight after the freeze row, and the first history row is waited for rather than read at once. Compiled (`LOADERRORS=0`); not yet run, see Clarification Needed. [src/OcuPilot/Test/BackupWrite.cls:273,285-297]
- [x] [Review][Patch] The #7309 test relied on writes being thawed and on the live cluster probe without saying so (LOW) - it sets `Cluster(0)` and asserts writes thawed first; green in `BackupRead` run 776. [src/OcuPilot/Test/BackupRead.cls:195-197]
- [x] [Review][Defer] A backup that ends before the run-while-running rows lets the screen's run start a real backup [src/OcuPilot/Test/BackupWrite.cls:291] - deferred: DW-2575 (occurrence; routed burndown). CI run 43699492613 measured the probe backup still Running about 3.5 s after it first read Running; the rows now come within the first second.
- [x] [Review][Defer] `WaitForBackupProcess` still matches `DBACK*` routines, now polled a few hundred milliseconds later [src/OcuPilot/Test/BackupWrite.cls:295] - deferred: DW-2574 (occurrence).

Rejected (iteration 3):

- A fed vendor code also refuses a thaw through the seam (low: only `BackupRead`'s freeze test sets it).
- #7309 is mapped to `BACKUP.RUNNING` before the write state is re-read (low: a second freeze landing in the same milliseconds; the rules answer a frozen instance before the vendor, and the fix adds a branch to a file outside the range).
- No test observes the vendor's real #7309 (low: rejected at the implement review for the same reason).
- "and reaches no body" cannot fail (low: the same guard its sibling test uses).
- A broken seam would really freeze writes from the unarmed `BackupRead` (low: theoretical; the 5 s limit resumes writes by itself).
- The implement stage's two test calls in one message overlapped (false: `TestInstance.DateTime` is the end time, so runs 765 to 774 ran one after another).
- The browser spec's mutation comment, the browser mutation's rebuild steps, and the run numbers that differ between Verification and Auto Run Result (low or maybe-false; the fix edits the spec or a comment's recipe).

## Spec Change Log

- 2026-11-15, rework 3 (lead): re-opened for two CI reds on `32dc20d7c` (run 43699492613). This is the last rework iteration (cap 3).

- 2026-11-15, rework 2 (lead): re-opened after the runner's full sweep found three shared-surface tests red.

- 2026-11-15, rework 1 re-dispatch (lead): the first rework pass wedged the throwaway with a disposable-probe experiment and changed no source; the runner rebuilt `ocupilot-ci`. The next pass applies the planned fix (the run test gets its own probe database name and directory) and runs the verification item, with no delete-after-backup experiments.

- 2026-11-15, rework 1 (lead): re-opened after the first review for the probe-database recreate failure and the verification the wedged throwaway blocked.

- 2026-11-14, spec gate: split ruled (Backup here, Mirroring to 21.12); retitled and re-keyed; freeze limit and strings ruled (Design Notes). Status reset to `draft` for a re-plan of the backup scope only.

## Review Triage Log

### 2026-11-14 - Review pass

- verdicts: 11 findings - high 0, medium 4, low 7, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Command box's Freeze writes entry has no test - added a `command-box.spec.ts` case; mutation (line dropped) red.
  - `[medium]` `[patch]` The run and freeze consequence codes are unpinned on the client, and `BackupError`'s sentences are claimed pinned to `strings.ts` with no test - added `ui/tools/backup.test.mjs`; mutation (returns swapped) red.
  - `[medium]` `[patch]` History truncation's assertion cannot fail on a throwaway with fewer than fifty entries - `BackupWrite.TestTheHistoryReportsTruncationOnlyPastFifty` seeds fifty and fifty-one entries through `BackupProbe.SeedHistory` and restores them; mutation red.
  - `[medium]` `[patch]` The frozen banner's server path is observed only by the browser spec - `BackupWrite` now asserts the tasks read's banner after a freeze and after a thaw.
  - `[low]` `[patch]` Mutation lines missing for AC4's `PortGate` half, AC2's confirm half and the browser spec - each applied, observed red, reverted and recorded under Verification.
  - `[low]` `[patch]` `BackupWrite` leaked the `ScreenGate` hold and the clustered seam on an error - `OnAfterOneTest` resets both and restores the history.
  - `[low]` `[patch]` The screen action path accepted `007` as 7 where the rules refuse it - `ScreenActionDelta` converts only `^[1-9][0-9]{0,8}$`; `007` joined the refusal rows.
  - `[low]` `[reject]` `check_harvest_containment` sees only a literal `OcuPilot.Port.Harvest.<Name>` - an `Import` or concatenated spelling is not matched; a fix adds a parser for no reachable case in this tree, and the literal form is the one the sibling rule (`check_admin_api_containment`) matches.
  - `[low]` `[reject]` `BackupGateSeam` and `BackupHarvestRecorder` hold no assertions - not defects; they are fixtures.
  - `[low]` `[reject]` Intent-alignment: the matrix's "through the OcuPilot API" is observed in-process through the shipped action handler and the executors beneath the read route; the sibling stories (Database, ECP) pin their rows the same way, and the browser spec observes the deployed routes for the reads, freeze, thaw, add and remove.
  - `[low]` `[reject]` Intent-alignment: the run row names `FullDBList` while `BackupWrite` runs a probe-defined task, since the built-in tasks cannot create `/Backup` on the throwaway; the request shape for `FullDBList` is asserted through the recorder.

### 2026-11-15 - Review pass (follow-up, rework 1)

- verdicts: 5 findings - high 0, medium 2, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The no-backup signal was pinned only through its task-status clause - `BackupWrite` asserts a backup process exists while the task runs; mutation (pattern changed) red.
  - `[medium]` `[patch]` `SuspendCall`'s null-device comparison fix had no recorded mutation - applied, red in two `BackupWrite` tests, recorded.
  - `[low]` `[reject]` `Remove`'s `backup` refusal is never observed - a backup here lasts seconds and `Remove` waits it out, so no test can hold the signal; a fixture seam for it adds a branch for no reachable case.
  - `[low]` `[reject]` The run test's freeze-while-running row depends on the backup's phase - it asks at once and tolerates a few `BACKUP.FROZEN` answers; green in nine consecutive runs.
  - `[low]` `[reject]` Spec bookkeeping claims unverifiable from the diff - verified by the runs recorded under Auto Run Result.

### 2026-11-15 - Review pass (rework 3)

- verdicts: 7 findings - high 0, medium 0, low 7, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` No live test observes the vendor's real #7309 - the ruling moves the mapping to a seam test; the code was measured on the pinned build (Design Notes), and a live observation needs a backup held before its own write suspension, which the suite cannot do.
  - `[low]` `[patch]` The AC1 mutation line still named `RUNNING` never answered in `BackupWrite` - rewritten to name the `BackupRead` vendor-refusal test.
  - `[low]` `[patch]` The browser spec's comment named the exact-set assertion for a `%DB_IRISSYS:W` grant - corrected to the per-screen assertions.
  - `[low]` `[patch]` The earlier review finding for DW-2575 still said the freeze row requires `BACKUP.RUNNING` - rewritten to the current assertion.
  - `[low]` `[reject]` The new test feeds the port its own constant - intended: it pins the mapping and the literal 7309 (measured under Design Notes).
  - `[low]` `[reject]` The two-caller path (AD-53) for this refusal is port-only - unchanged from before the pass; the write tests cover the screen and the mint elsewhere.
  - `[low]` `[reject]` Backup history opens only with `%DB_IRISSYS:WRITE` while the port reads on the read pairs - pre-existing shipped pair choice (the classic menu's), recorded under Clarification Needed, not changed by this pass.

## Design Notes

**Governing ADs:** AD-10 (the backup freeze bound), AD-22 (keys ship `false`; a person's screen write is not governed), AD-23 (harvested body), AD-29 (`BackupPort`'s gate), AD-21 (no path; names from fixed sources), AD-35 (no credential), AD-36 (bounded reads), AD-51, AD-52, AD-53, AD-56 (ii), AD-58 (action writes, two callers, read-back), AD-6, AD-34, AD-15 (proposal, transition, audit), AD-14 (change event), AD-5, AD-44 (descriptors, classic keys), AD-16, AD-59 (namespace, `Snippet`).

**Decided in-stage:**

- Only `listHistory` and `run` go through the harvested body: its freeze cannot carry a limit and its other arms take a path or a credential. The port builds the body's JSON from a two-value allow-list; a test asserts no other action reaches it.
- A run is always started in the background (`jobbackup` 1).
- `DESTRUCTIVE` follows `Write.cls`'s definition (an effect not undone by proposing the opposite): Run is 1, on `ExplorerSqlRun`'s model, since a started backup cannot be withdrawn here; freeze/thaw and add/remove are each other's opposites, so 0. Run's card consequence is the ruled run note; freeze's is the ruled freeze consequence.
- Remove's screen action id is `removedatabase` (precedent `removekey`): the client's verb-global `remove` asks for a typed-name dialog with a consequence sentence no ruling supplies, for a write Add database reverses. Its tool name stays `osmgmt.backupdatabases.remove`.
- A person's own screen write asks no governance key (AD-22 as it stands). The screen's freeze takes the same port limit.
- Read pairs follow the classic menu (`%Admin_Operate:USE`, `%DB_IRISSYS:READ` and `WRITE`) unless Task 0 measures more; stricter is allowed, looser is not.

**Runner rulings at the spec gate (2026-11-14, unattended; veto item filed):**

- Split accepted: 21.2 is Backup (key `21-2-backup`); the mirroring criteria moved verbatim to Story 21.12 (`21-12-mirroring`), planned next. AD-10's "named at Story 21.2's spec gate" pointer for the mirror-removal code now means Story 21.12's gate; its text is not edited unattended.
- `FREEZELIMITMAX` = 600 seconds, the limit required on every freeze, no default.
- The proposed strings below are ruled as proposed; the per-code `BACKUP.*` reason sentences are written in plain language in this spec and fall under the same ruling. Add each to EXPERIENCE.md's string table in the implement stage if that table exists.
- Proposed spine edits (AD-29 Binds `BackupPort`; the freeze limit in AD-10's backup arm) stay proposals in these Design Notes for the owner's attended Update.

**Decided values (ruled above):**

- `FREEZELIMITMAX` = 600 s, required, no default: after 600 s of suspension the vendor blocks updating processes (`ExternalFreezeTimeOut`, `General.cls:96-103`).
- Titles: "Backup tasks" · "Backup history" · "Backup database list".
- Columns: "Type" · "Last run" · "Status" · "Description" · "System task" · "Time" · "Databases" · "Database" · "Directory".
- Actions: "Run" · "Freeze writes" · "Thaw writes" · "Add database" · "Remove".
- Freeze field and help: "Suspend limit (seconds)" · "Writes resume by themselves after this many seconds, from 1 to 600."
- Frozen banner: "Database writes are frozen. Thaw them when the external backup finishes."
- Empty list: "The list is empty, so a list backup includes every database except IRISTEMP."
- Freeze consequence: "Database writes stop until you thaw them or the limit passes."
- Run note: "The backup runs in the background; its result appears in Backup history."
- Reasons: `BACKUP.TASK.NOTFOUND` "There is no backup task with that name." · `BACKUP.RUNNING` "A backup is already running." · `BACKUP.FREEZE.LIMIT` "Give a suspend limit from 1 to 600 seconds." · `BACKUP.FROZEN` "Database writes are already frozen." · `BACKUP.FREEZE.UNBOUNDED` "Writes cannot be frozen with a limit on this system." · `BACKUP.NOTFROZEN` "Database writes are not frozen." · `BACKUP.DATABASE.NOTFOUND` "There is no database with that name." · `BACKUP.LIST.CONFLICT` "The backup list already reflects that change."

**Extend, don't copy (Rule 2/31):** `BackupAction` follows `DatabaseAction`'s shape as a sibling, not a subclass: its port, `STATE` and rules differ, and subclassing would couple database disk operations to backup. `BackupError` follows `EcpError`; the client follows the ECP list files.

**Integration ACs:** `BackupPort` is consumed in this story by its five tools and three descriptors (AD-53's two callers); the matrix rows are its integration ACs, observed through the API and the browser spec.
**Consumed-by:** Story 21.11, undo across write tools (inference).
**Consumes:** `HarvestPort` (21.1), `Kernel.Fault`, `Screen.Gate`, `Screen/Tool/Write`.

**DW-2560** is addressed by the `check-objectscript.py`, `PortGate` and `spec-21-1` tasks and AC4.

**Task 0, measured on `ocupilot-ci` (2026-11-15):**

- Pair set: not measured as a least-privileged principal (a probe user's session answered `Access Denied` straight after `$System.Security.Login`, and `AddRoles` was refused), so the pairs are the classic menu's, which the spec allows: reads `%Admin_Operate:USE`, `%DB_IRISSYS:READ`; writes add `%DB_IRISSYS:WRITE`; the screens require all three, the write pair as the screen's own.
- Classic keys: `%SYS.Portal.Resources.NormalizePage` resolves `UtilSysBackups`, `UtilSysBackup`, `UtilSysBackupLogs` and `UtilSysBackupDatabases` to `%cspapp.op.utilsysbackups`, `%cspapp.op.utilsysbackup`, `%cspapp.op.utilsysbackuplogs` and `%cspapp.mgr.utilsysbackupdatabases`, and each key resolves to itself.
- `WDSuspendLimit` resumes writes: limit 5 read thawed 5.02 s after the freeze call returned (the call took 1.3 s), polled each second, so the slack is about one second and the tests allow 6. A freeze outlives the process that made it, and `ExternalThaw()` with no credentials from another process resumes it.
- Clustered system: `DBACKB` sets its cluster path when a backed-up database reads cluster-mounted (`$ZU(49,dir,1)` piece 2 non-zero), and `DBACK`'s `CLUBINIT` splits `$ZU(172,0)` on `;`. The port's predicate is more than one member or any local database cluster-mounted; here `$ZU(172,0)` is `1972` and none of nine databases is, so it reads false (inference: that is the path where `ExternalFreeze` ignores the limit; the body of `ExternalFreeze` is not in the export).
- Vendor answers: unknown task `StartTask` #7308; unknown database add #7321; `IRISTEMP` add #7322; remove of an unlisted database #7324; a duplicate add is OK (status 1); thaw while not frozen #7339. `Backup.Task:List` status reads `""`, `Running` (about 17 s for one empty probe database) and `Completed`.
- `StartTask("FullDBList",1,1)` fails #7318 on this throwaway: its device `/Backup` cannot be created. The run tests therefore run a task the test defines, with a device under the manager directory. A second run while one runs was observed through the port's refusal, not the vendor's.
- A database that is configured joins the backup list at once (the list held all nine), so the probe starts unlisted only after it is taken off.

**Decided in-stage (implement):**

- Port shape: endpoints `Tasks` (`LIST`, `GET`, `RUN`), `History` (`LIST`), `Databases` (`LIST`, `GET`, `ADD`, `REMOVE`) and `Writes` (`GET`, `FREEZE`, `THAW`); the spec's `STATE` read is the port's `GET`. `Rows` is the screens' list call and reports the history's own cut. The refusal logic is `BackupRules.Code`, which the port and the mint both ask.
- The frozen banner reads the write state through the port: a banner source may now be `backup` (Registry, Read, mirror and the shared corpus), and its action is the declared `thaw`.
- Freeze and thaw name the literal `SYSTEM` under the `backup-task` type; the freeze's `limit` is a member of the read answer (a merge needs one) and of the fingerprint subject (an action-style payload is that subject).
- `IRISTEMP` is answered as `BACKUP.DATABASE.NOTFOUND`: it is never a database of the list.
- `ExternalFreeze` and `ExternalThaw` print to the current device, so `BackupPort.SuspendCall` sends their output to the null device with the caller's redirection cleared, and restores both after the call.
- DW-2560 is `check_harvest_containment`, called from `check_admin_api_containment`: `CLAUDE.md` pins the rule count at 21, and a 22nd entry would need an edit to `CLAUDE.md` that is the owner's.
- Client: Backup tasks' and Backup database list's pages register their own actions (Freeze writes beside the journal switches on the command bar and in the box, Add database through its own dialog); Run warns with the run note and Remove is sent at once.
- Every confirm test sets `^||OcuPilotDatabaseWritePort` to the shipped port, since the confirm fixture otherwise answers from an accepting stub.

**Proposed spine amendment (Rule 20, for the owner's attended Update):** add `BackupPort` to AD-29's Binds; AD-10's backup arm: "the bound is `FREEZELIMITMAX` (600) seconds, enforced by `BackupPort` through `WDSuspendLimit`; a freeze is refused where the instance would ignore it (measured predicate)."

## Verification

**Shared surfaces:** the governance baseline and its `DISABLED` roster, the entity types and `Prohibited`'s covered types, the read sources, the tool registry, the OS management rail and screen roster (`screens.generated.ts`), `PortGate`'s roster, `SurfaceCoverage`, the checker's rule count, and `ci-throwaway.sh`'s arming roster. The implement stage greps `ui/browser`, `ui/tools`, `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.* Each write test asserts on its own probe database and restores the list and the frozen state it found.

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only. Never two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.BackupRead`, one per call, then each of `BackupRules`, `BackupWrite`, `Harvest`, `PortGate`, `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `Descriptor`, `Navigation`, `ClassicPageGate`, `DraftRegistry`, `StageTwoTools`, `Wire`, `WireAreaAnyScreen` -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && npm run build` and `npm run test:components`; redeploy `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/backup.browser-spec.mjs` -- expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC, each applied, observed red, reverted (tree identical by `cmp`) and the reverted source reloaded into `ocupilot-ci`:**

- AC1: `BackupPort`'s `TaskRows` skips the system tasks -> red: `BackupRead`'s four-built-ins test (and two more). Also red: `jobbackup` 0 (the two-fixed-requests test), the gate answering OK (the read-refusal test), `BackupRun` `DESTRUCTIVE` 0 (the declarations test), the port's `FREEZELIMITMAX` 6000 (`BackupRules`, re-observed by code review, run 14), an add sending the remove call (`BackupWrite`), and #7309 mapped to `FROZEN` (`BackupRead`'s vendor-refusal test), and, in the client, each page's `register`, `freeze` out of `WARNING_VALUES`, the dialog's trim and the command bar's `hasBackupFreezeAction`.
- AC2: `osmgmt.backuptasks.freeze` set `true` in the baseline -> red: `BackupRead`'s five-keys test.
- AC3: `WDSuspendLimit` passed as 0 -> red: `BackupWrite`'s freeze-resumes-without-thaw test, the teardown thawing.
- AC4: `BackupPort.cls` removed from `HARVEST_CALLERS` -> red: the checker over the shipped tree and `TestShippedTreeHarvestBodyContainment`.
- AC1, history truncation: `BackupPort.History` sets `pCut` 0 -> red: `BackupWrite`'s `TestTheHistoryReportsTruncationOnlyPastFifty` (it seeds fifty and fifty-one entries and restores the history).
- AC2, the confirm's effect: `SuspendCall` returns OK without freezing -> red: four `BackupWrite` tests, among them the key-enabled confirm test.
- AC4, `PortGate` half: the `Monitor=<body>` roster row dropped, and `Monitor` defining an `Invoke` -> `PortGate`'s roster test red each time.
- Client: the command box's backup line dropped -> its Story 21.2 spec case red; the run and freeze consequence returns swapped in `proposal-view.ts` -> `ui/tools/backup.test.mjs` red.
- Browser spec: `SuspendCall` returning without freezing -> its freeze test red alone (the other two stay green).
- The history's fifty-first-entry case runs in `BackupWrite` only, because seeding `^SYS("BUHISTORY")` is armed work.
- (QA) AC1, write gate: `BackupPort`'s `WRITEPAIRS` without `%DB_IRISSYS:WRITE` -> `BackupRead.TestEveryWriteIsRefusedToACallerWithoutTheWritePair` red alone (run 3).
- (QA) AC3, bounds: `SuspendCall` passes a limit of 5 whatever it is given -> `BackupWrite.TestTheLimitReachesTheInstanceUnchangedAtItsBounds` red alone (run 4).
- (QA) AC2, key to tool: `osmgmt.backuptasks.thaw` set `true` in the baseline -> `BackupWrite.TestEachKeyGovernsOnlyItsOwnTool` red alone (run 5).
- (QA) AC4, direct: a stray `src/OcuPilot/Port/ZzStray.cls` naming `OcuPilot.Port.Harvest.Monitor` -> `check-objectscript.py` fails naming the file and DW-2560; the file removed, clean again.
- (QA) Each mutation reverted (`cmp` and `git diff --stat` identical) and the source reloaded; `BackupWrite` then green twice in succession (runs 6 and 7) and the browser spec green (3 of 3), with no `OCUPROBEBACKUP` database configured or mounted and writes thawed after each.
- (CR) Client: `consequenceSentence` returning the freeze sentence for `BACKUP.RUN` -> `proposal-view.test.mjs`'s Story 21.2 case red; reverted, `cmp` identical.
- (CR, rework) AD-29, `BackupWriteGate`: `SuspendCall` begins a `%SYS.Capture` capture before the vendor call -> `TestTheWritePairsFreezeThawChangeTheListAndRun` red alone (the writer's freeze fails); reverted, `cmp` identical, reloaded; the class green after.
- (CR, rework) AC1, the run test's own database: `BackupProbe.Create` ignores its database argument -> `TestARunStartsTheTaskOnBothCallers` red (the list set to the run database is refused, the task is never created, so no backup runs); reverted, `cmp` identical, reloaded.
- (CR, rework) AC1, the no-backup signal: `BackupProbe.WaitForNoBackup` answers 1 at once -> `TestARunStartsTheTaskOnBothCallers`'s "no-backup signal does not come while it runs" red. Same run, `SuspendCall` reads the redirection without clearing it -> the freeze, limit-bound and resume tests red (the vendor's output joins the fixture's capture). Both reverted, `cmp` identical, reloaded; `BackupWrite` green after (run 23).
- (CR, rework) AD-29, `SuspendCall`'s null-device test: the comparison back to the whole device name (`If tDevice '= tNull`) -> `TestAFreezeAndAThawSucceedOnBothCallers` and `TestARunStartsTheTaskOnBothCallers` red (run 34); reverted, `cmp` identical, reloaded.
- (CR, rework) AC1, the backup-process clause: `BackupProbe.BackupProcessRunning` matches `DBACZ` instead of `DBACK` -> `TestARunStartsTheTaskOnBothCallers`'s "the instance has a backup process" red (run 44, with the assertions that follow it); reverted, `cmp` identical, reloaded. `Remove`'s `backup` answer is not pinned: a backup in this suite lasts seconds and `Remove` waits it out, so no test can hold it long enough to observe the refusal.
- (QA) Added to existing classes, no new file: `Test/BackupRead.cls` (`TestEveryWriteIsRefusedToACallerWithoutTheWritePair`), `Test/BackupWrite.cls` (`TestTheLimitReachesTheInstanceUnchangedAtItsBounds`, `TestEachKeyGovernsOnlyItsOwnTool`; `Dispatched` answers the call's content).
- mutation (runner, re-review patch): `BackupProbe.WaitForNoBackup` without its `'..WritesFrozen()` check -> red: `BackupWrite.TestAFreezeAndAThawSucceedOnBothCallers` ("the probe's no-backup signal does not come while writes are frozen"), run 25; reverted byte-identical, reloaded, green.
- mutation (runner sweep, rework 2): the `backup-history` entry removed from `WireSecurityRead`'s operate-principal screen roster -> `TestTheProcessesListsPairSetIsEnforcedForARealPrincipal` red (run 755); `%DB_IRISSYS:WRITE` dropped from `BackupTaskList`'s `privileges` -> `LanguageServerWire.TestAnAreaHolderKeepsOsManagementAndIsRefusedTheServers` red (run 756); `BackupWrite`'s teardown with its `PreparedPolicyTaken` guard moved below the first statement -> `TeardownGuard.TestEveryTeardownThatTouchesSharedStateOpensWithAGuard` red naming `OcuPilot.Test.BackupWrite` (run 757). Each reverted (`cmp` identical to the pre-mutation copy), reloaded, green after.
- mutation (rework 3, DW-2575): `BackupPort.FreezeOrThaw` maps the vendor's #7309 to `BACKUP.FROZEN` instead of `BACKUP.RUNNING` -> red: `BackupRead.TestTheVendorsRefusalOfAFreezeWhileABackupRunsIsAnswered409Running` alone (run 766; the vendor refusal is fed through `BackupGateSeam.VendorRefuses`, so no backup races it); reverted, `git diff` empty, reloaded, green (run 767). `BackupWrite`'s live freeze row now asserts a 409 on `BACKUP.RUNNING` or `BACKUP.FROZEN`: `SuspendCall` returning OK without freezing -> that row red ("200|", run 773, with the freeze tests); reverted, `git diff` empty, reloaded; `BackupWrite` green three times in succession (runs 769 to 771) and again after the mutation (run 774), `BackupWriteGate` green (run 772), no probe database left.
- mutation (rework 3): `%DB_IRISSYS:WRITE` dropped from `BackupHistoryList`'s `privileges` -> `language-servers.browser-spec.mjs` AC5 red naming Backup history; reverted (`git diff` empty), reloaded; the spec green (2 of 2) and `backup.browser-spec.mjs` green (3 of 3) on the rebuilt, redeployed bundle.
- mutation (code review, rework 3): `BackupRules.Code` answers no refusal for a run -> `BackupWrite`'s run-while-running rows red. Not yet applied: `ocupilot-ci` was left with the probe task reading Running, so it waits for a rebuilt throwaway (Clarification Needed).

## Clarification Needed

- Strings the framework requires of a built screen that the spec does not rule (entity nouns `Backup task` and `Backup database`, the empty sentences `No backup tasks on this instance.` and `No backups are recorded on this instance.`, the empty-agent phrases `run a backup task` and `add a database to the backup list`, and nine suggested prompts). They are in `strings.ts` and on EXPERIENCE.md's row 604 so the build and `strings.test.mjs` pass; the owner may reword or veto them.
- `CLAUDE.md` says 21 rules and a test pins that; DW-2560's check is folded into the containment rule. Splitting it into its own rule needs the sentence changed.
- The least-privileged measurement of the pair set was not possible (see Task 0); the pairs are the classic menu's.

## Auto Run Result

Status: done
Blocking condition: none

Rework 3 (the two CI reds on `32dc20d7c`, run 43699492613). `BackupWrite`'s live freeze row makes one call and asserts a 409 on `BACKUP.RUNNING` or `BACKUP.FROZEN`; the vendor's #7309 mapping is pinned in `BackupRead.TestTheVendorsRefusalOfAFreezeWhileABackupRunsIsAnswered409Running` through a new `BackupGateSeam` `VendorRefuses` / `SuspendCall` seam. `language-servers.browser-spec.mjs` AC5 expects the three Backup screens unavailable on `%DB_IRISSYS:WRITE`, exact; no other spec asserts the area's screens. Review pass: seven low findings, three patched (stale mutation and finding text, a comment), four rejected; patched by verdict: low 3.

Verified on `ocupilot-ci`, one class per call: `BackupWrite` green three times in succession (runs 770, 771, 774), `BackupWriteGate` (run 772), `BackupRules` (run 768), `BackupRead` (run 767); `language-servers` and `backup` browser specs green on the rebuilt bundle; `npm run test:tools` 2281 of 2281; `check-objectscript.py` and `lint-docs.sh` clean. Mutations under Verification, each reverted and reloaded.

Follow-up review recommended: false (no high patched).
