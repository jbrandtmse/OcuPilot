---
title: 'Story 21.2: Backup'
type: 'feature'
created: '2026-11-14'
status: 'ready-for-dev'
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

## Spec Change Log

- 2026-11-14, spec gate: split ruled (Backup here, Mirroring to 21.12); retitled and re-keyed; freeze limit and strings ruled (Design Notes). Status reset to `draft` for a re-plan of the backup scope only.

## Review Triage Log

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

**Proposed spine amendment (Rule 20, for the owner's attended Update):** add `BackupPort` to AD-29's Binds; AD-10's backup arm: "the bound is `FREEZELIMITMAX` (600) seconds, enforced by `BackupPort` through `WDSuspendLimit`; a freeze is refused where the instance would ignore it (measured predicate)."

## Verification

**Shared surfaces:** the governance baseline and its `DISABLED` roster, the entity types and `Prohibited`'s covered types, the read sources, the tool registry, the OS management rail and screen roster (`screens.generated.ts`), `PortGate`'s roster, `SurfaceCoverage`, the checker's rule count, and `ci-throwaway.sh`'s arming roster. The implement stage greps `ui/browser`, `ui/tools`, `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.* Each write test asserts on its own probe database and restores the list and the frozen state it found.

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only. Never two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/f9329139-8fb8-421f-b2bb-04300ba71baf/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.BackupRead`, one per call, then each of `BackupRules`, `BackupWrite`, `Harvest`, `PortGate`, `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `Descriptor`, `Navigation`, `ClassicPageGate`, `DraftRegistry`, `StageTwoTools`, `Wire`, `WireAreaAnyScreen` -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && npm run build` and `npm run test:components`; redeploy `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/backup.browser-spec.mjs` -- expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC:**

- AC1: `BackupPort`'s `TASKS` branch drops the system tasks -> red: `BackupRead`'s four-built-ins test.
- AC2: `osmgmt.backuptasks.freeze` set `true` in the baseline -> red: `BackupRead`'s governance-default test.
- AC3: `WDSuspendLimit` passed as 0 -> red: `BackupWrite`'s freeze-resumes-without-thaw test.
- AC4: `BackupPort.cls` removed from `HARVEST_CALLERS` -> red: the checker over the shipped tree.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
