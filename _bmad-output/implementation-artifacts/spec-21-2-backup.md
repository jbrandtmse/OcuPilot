---
title: 'Story 21.2: Backup'
type: 'feature'
created: '2026-11-14'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Backup has no screen and no API in OcuPilot. An operator who wants to list the backup tasks, run one, read the history, keep the backup database list, or freeze and thaw writes for an external backup has to go to the classic portal's legacy CSP pages. The highest-consequence operation there, freeze, has no time limit: writes stay suspended until someone thaws them.

**Approach:** Add one gated port, `BackupPort`, and three OS management screens: Backup tasks, Backup history and Backup database list. History and run go through the harvested `BackupManage` body behind `HarvestPort` (AD-23). Freeze, thaw and the list writes are the port's own code. Every write is one operation with two callers (AD-53): a confirmed agent proposal and the screen's own action. Every governance key ships `false`. Every freeze carries a suspend limit the port enforces. Close DW-2560 in the same change: harvested body classes get a containment rule and a `PortGate` row kind.

This spec plans Story 21.2, Backup. The mirroring half is now Story 21.12 (runner ruling at the spec gate, 2026-11-14).

## Boundaries & Constraints

**Always:**

- `BackupPort` evaluates its declared pairs with `$System.Security.Check` before any vendor call (AD-29), and switches `$NAMESPACE` by save and restore (AD-16).
- The harvested body is `OcuPilot.Port.Harvest.Monitor.BackupManage`, copied from the sibling at `c6aad31`. Only the base class, the `..` rename and the doc comment change. `BackupPort` builds the body's JSON itself and sends only `{"action":"listHistory"}` or `{"action":"run","taskName":<name>,"jobbackup":1}`.
- A backup task, a database and a freeze limit are validated by the port before the vendor is called, and again at the write for both callers. A task is named from `Backup.Task:List`'s names and a database from `Config.Databases`. No caller value is a path (AD-21).
- A freeze calls `Backup.General.ExternalFreeze` with `WDSuspendLimit` set to the caller's limit, a whole number of seconds from 1 to `FREEZELIMITMAX`. It is refused before any vendor call when the limit cannot hold (see the matrix).
- Each write is action-style (AD-51), declares `BackupPort` (AD-52), and is minted, fingerprinted, confirmed once and audited (AD-6, AD-34, AD-15). Each reads its target back (AD-58) and emits one change event (AD-14).
- `Kernel/Governance/Baseline.cls` gets five keys, each `false`: `osmgmt.backuptasks.run`, `osmgmt.backuptasks.freeze`, `osmgmt.backuptasks.thaw`, `osmgmt.backupdatabases.add` and `osmgmt.backupdatabases.remove` (AD-22).
- Every read is bounded and reports truncation (AD-36).

**Never:**

- No restore, no `AbortBackup`, no task create, edit or delete, and no device, log-file, username or password argument anywhere.
- No mirroring screen, tool or port, and no new `PROHIBITED.*` predicate. `Prohibited.cls` gains only the backup entity types as covered types. The mirroring sibling owns AD-10's mirror arm.
- No `##class(OcuPilot.Port.Harvest.*)` or literal body-class name outside `HarvestPort`, `Port/Harvest/`, the body's declared area port and `src/OcuPilot/Test/` (DW-2560).
- No edit to the harvested body's code.
- No user-facing string that the spec gate has not ruled (see Design Notes).

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

- `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/Monitor.cls:1281-1489` -- `BackupManage`, read at `c6aad31` (read-only source). Its doc comment says there are no shipped tasks, which is wrong: `irissys/Wsback.int:375-380` defines four. Its freeze passes no `WDSuspendLimit` and takes a log file, and its thaw takes credentials. That is why only `listHistory` and `run` are reached through it.
- `src/OcuPilot/Port/HarvestPort.cls:50-80` -- `Invoke`'s contract (gate, handler check, stubs, outcome). `src/OcuPilot/Port/Harvest/Handler.cls` is the base. See `spec-21-1-the-harvest-seam.md` Design Notes for "Named limits": `SanitizeError` collapses a body's refusal to `INTERNAL`, so `BackupPort` validates first.
- `src/OcuPilot/Test/HarvestFixture.cls` -- how a verbatim body is held (base and `..` rename only).
- `irissys/Backup/General.cls:165` (`ExternalFreeze`, with `WDSuspendLimit` 10th), `:192` (`ExternalThaw`), `:235` (`StartTask`, `[Internal]`, which the body calls), `:336/:341` (`AddDatabaseToList`/`RemoveDatabaseFromList`, keyed by name per `Wsback.int:250-260`), `:399` (`DatabaseList`), `:417` (`IsWDSuspended`). Bodies are not exported. Behavior is measured in Task 0.
- `irissys/Backup/Task.cls:133` -- `List`, which returns the four built-ins first. `:110` -- `History`. The class has no SQL projection, measured: `Backup.Task` is not a table in `%SYS`.
- `irissys/%CSP/UI/Portal/Application.cls:405-421` -- the classic Backup menu needs `%Admin_Operate` and `%DB_IRISSYS` READ and WRITE. `:210-216` -- the SysAdmin Database Backup List.
- `src/OcuPilot/Port/DatabasePort.cls`, `src/OcuPilot/Screen/Tool/DatabaseAction.cls`, `src/OcuPilot/Screen/Tool/DatabaseCompact.cls` -- the sibling action-style write family (port `Invoke(endpoint, type, query, …)`, `STATE` read, `SCREENACTIONS`/`SCREENVALUES`, `ARGUMENT`, `FINGERPRINTSUBJECT`, `WRITERESOURCE`, `CLASSICPAGES`, `ArgumentProblem` through a rules class).
- Models:
  - Story 18.20, the ECP data servers screen: `Screen/Descriptor/EcpDataServerList.cls:21-74` (the XData: route, area, `sideBarPosition`, privileges, `entityType`, actions, `classicPage`, `read.source`, `toolIdentifier`), `Screen/Tool/EcpDataServerDelete.cls`, `Area/OsMgmt/EcpRules.cls`, `Api/EcpError.cls:16-24`, and its spec `spec-18-20-ecp-data-servers.md`. It touched 97 files.
  - Story 20.34, the cube build (commits `f60db04b4`, `acb0b6660`): the quicker model, a generic list page with two writes over a non-admin port.
- Write flow anchors:
  - `Screen/Tool/Write.cls`: `DESTRUCTIVE` :52, `READTYPE`/`WRITETYPE`/`SENDSBODY` :57-67, `FINGERPRINTSUBJECT`/`PRECONDITIONFIELD` :97/:105, `PORTCLASS` :114, `CLASSICPAGES` :124, `SCREENACTIONS` :167, `SCREENVALUES` :238, `READBACKFIELDS` :1035.
  - `Kernel/Proposal/Mint.cls:135` and `Confirm.cls:248`.
  - `Api/ScreenAction.cls:436,446`.
  - `ReadBack`: `nothingSent` :47, and `Running` :226 for a 202.
  - Tools are found by scanning the package (`Screen/Tool/Registry.cls:814`), so the registry needs no edit.
- New read source: `Screen/Read.cls:167-330` (a `SOURCE<x>` parameter) with the list at `:442`, and `Screen/Registry.cls:1223-1224,1316`.
- New entity types:
  - `Kernel/EntityType.cls:126` (`TYPES`);
  - `Kernel/EntityRef.cls:59` (`IDRULES`);
  - `Kernel/Proposal/Prohibited.cls`: `TYPE<X>` :285-757, `COVEREDTYPES` :282, the `Prohibits` list :1460, and the `PermittedChangeFields` and `PermittedCreateFields` branches :1200/:1340. Without these, every write is refused as uncovered.
- `Api/Error.cls:1233,1451` -- the code-prefix dispatch a new `BackupError` joins.
- Classic keys are compiled `%cspapp` classes (read from slot A's `%SYS`): `%cspapp.op.utilsysbackups`, `%cspapp.op.utilsysbackup`, `%cspapp.op.utilsysbackuplogs`, `%cspapp.mgr.utilsysbackupdatabases`. `JournalList.cls:48` is the precedent. `Test/Descriptor.cls:362-377` opens each one.
- `Kernel/Governance/Baseline.cls:6-29` -- one line per key in name order. A disabled key also joins `Test/GovernanceBaseline.cls:61-71`'s `DISABLED` roster. The test at `:21-36` fails for a write key with no line. That corrects `epic-21-context.md:26`'s "absent from the baseline".
- `Screen/Area.cls:83` -- the `os-management` area's pairs. Side-bar positions 1-22 are taken, so backup takes 23 to 25.
- Client: `ui/src/app/shell/screen-outlet.ts:54` (generic `list-page`). `shell/screen-action-handler.ts` has the rosters `SCREEN_ACTION_DESCRIPTORS` :70-110, `DESTRUCTIVE_ACTIONS` around :544, and `DESTRUCTIVE_CONSEQUENCES` :613. Also `core/strings.ts`, `core/screen-actions.ts`, `core/proposal-view.ts`, and `screens.generated.ts` (from `node tools/screen-mirror.mjs`).
- The roster tests a new screen and tool join:
  - `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `PortGate`
  - `ReadTool` :94, `ReadDescriptions` :35
  - `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`
  - `Descriptor`, `Navigation` :540-543, `ClassicPageGate`
  - `DraftRegistry` :71, `StageTwoTools`
  - `Wire`, `WireAreaAnyScreen`
  - client: `ui/tools/navigation.test.mjs`, `screen-mirror.test.mjs`, `proposal-view.test.mjs`, `shell/rail-wire.spec.ts`, `area-verdict.spec.ts`
  - `EndpointCoverage`, only if a route is added (none is planned).
- `src/OcuPilot/Test/PortGate.cls:22-48` -- the roster and its row kinds (`<vendor>`, `<table>`, `<stub>`, `<caller>`).
- `scripts/check-objectscript.py:656-737` -- `check_admin_api_containment`, the containment rule to model DW-2560's on. Its harness rows are in `scripts/test_check_objectscript.py:1188,1777`.
- `scripts/ci-throwaway.sh:594-754` -- the arming variables, plus the roster `ui/tools/ci.test.mjs` holds against them.
- `src/OcuPilot/Test/ProbeNamespace.cls:12,44` -- builds and removes a probe database in its own directory, used by the run test.

## Tasks & Acceptance

**Execution, batch 1 (server; commit when its loop commands are green):**

- Task 0, measure on `ocupilot-ci` and record under Design Notes before writing code:
  - the pair set, run as a least-privileged principal (AD-29);
  - the four classic keys from `NormalizePage`;
  - whether `WDSuspendLimit` resumes writes on this build, and the slack;
  - how `ExternalFreeze` detects a clustered system;
  - what `StartTask` answers for an unknown task and for a second run;
  - `AddDatabaseToList`'s answer for a duplicate and for `IRISTEMP`.
- `src/OcuPilot/Port/Harvest/Monitor.cls` -- new. It holds `BackupManage`, verbatim apart from the base class and the `..` rename. Its doc comment states the true contract.
- `src/OcuPilot/Port/BackupPort.cls` -- new. It has `PAIRS`, `WRITEPAIRS` and `FREEZELIMITMAX`, and the `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pResult, Output pHttpStatus, Output pFault)` branches `TASKS`, `HISTORY`, `DATABASES`, `STATE`, `RUN`, `FREEZE`, `THAW`, `ADD` and `REMOVE`. It also has `Snippet`/`SnippetForm` (AD-59), the overridable `GateClass`/`LogFault`, and a fixture seam for the clustered predicate.
- `src/OcuPilot/Area/OsMgmt/BackupRules.cls` -- new. The refusals in the matrix, asked by the mint and by the port.
- `src/OcuPilot/Api/BackupError.cls` -- new. The codes in the matrix, on the `EcpError` model.
- `src/OcuPilot/Screen/Descriptor/BackupTaskList.cls`, `BackupHistoryList.cls`, `BackupDatabaseList.cls` -- new. Each has its read, its classic page from Task 0, its pairs, and its row and command actions.
- `src/OcuPilot/Screen/Tool/BackupAction.cls` (an abstract base on `DatabaseAction`'s model), plus `BackupRun.cls`, `BackupFreeze.cls`, `BackupThaw.cls`, `BackupDatabaseAdd.cls` and `BackupDatabaseRemove.cls` -- new.
- Add-only rows, as Story 18.20 added them. Each tool declares `READBACKFIELDS` or none, since the port has no derived field list.
  - `Kernel/Governance/Baseline.cls` and `Test/GovernanceBaseline.cls`'s `DISABLED` roster;
  - `Screen/Read.cls` and `Screen/Registry.cls` (a `SOURCEBACKUP` read source);
  - `Kernel/EntityType.cls`, `Kernel/EntityRef.cls` and `Kernel/Proposal/Prohibited.cls` (the types `backup-task` and `backup-database`, covered, with no predicate);
  - `Api/Error.cls` (the `BACKUP.` prefix);
  - `Screen/Titles.cls`, regenerated.
- `scripts/check-objectscript.py` and `scripts/test_check_objectscript.py` -- DW-2560 containment. A body class under `Port/Harvest/` may be named only in `HarvestPort`, `Port/Harvest/`, its declared caller (`HARVEST_CALLERS`, here `OcuPilot.Port.Harvest.Monitor` → `src/OcuPilot/Port/BackupPort.cls`) and `src/OcuPilot/Test/`. The rule has harness rows for a hit and a miss.
- `src/OcuPilot/Test/PortGate.cls` -- add the `BackupPort=PAIRS;WRITEPAIRS` row, and a `<body>` row kind for `OcuPilot.Port.Harvest.Monitor`. A `<body>` row asserts that the class extends the base, defines no `Invoke`, and records nothing when it is called outside the port.
- `_bmad-output/implementation-artifacts/spec-21-1-the-harvest-seam.md:183` -- replace the "cannot be wired as a route past the port's gate" sentence with: "outside a `HarvestPort` call it records nothing and fails; what keeps a body behind the gate is the containment rule (DW-2560)."
- `scripts/ci-throwaway.sh`, `ui/tools/ci.test.mjs` -- `OCUPILOT_ALLOW_BACKUP_CONTROL`, with a roster row.
- `src/OcuPilot/Test/BackupRead.cls` (live-safe: three reads, the harvested history through the port, gate refusals, governance defaults); `BackupRules.cls` (every refusal row, live-safe); and `BackupWrite.cls` (armed). The write tests run, freeze, thaw, add and remove, by both callers. Each restores the list it found and thaws in `OnAfterOneTest`. The run test lists only a probe database it creates.

**Execution, batch 2 (client; commit when its loop commands are green):**

- The three screens on the generic `list-page`, with no custom page unless a dialog needs one: Run as a row action, Freeze writes (with its limit field) and Thaw writes on the tasks command bar, and Add database and Remove on the list screen. The files are `ui/src/app/areas/os-management/backup-*.ts` with their specs, `shell/screen-action-handler.ts`'s rosters, `core/strings.ts`, `core/screen-actions.ts`, `core/proposal-view.ts`, and `screens.generated.ts`, regenerated.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings go into Fixed strings.
- `ui/browser/backup.browser-spec.mjs` -- new. Each screen answers its rows. Freeze then thaw flips the frozen banner, and add then remove round-trips a probe database. It waits for the answered signal each time.

**Acceptance Criteria:**

- AC1. Given the three screens and five tools, when each read and each write runs through the OcuPilot API on `ocupilot-ci`, then it round-trips over its backing class: every matrix row from "Tasks read" to "List add / remove".
- AC2. Given the default baseline, when the agent proposes any of the five writes, then the governance gate refuses it. With the key set `true` it mints, and the confirm writes once with one audit marker and a `readBack`.
- AC3. Given any freeze, from either caller, when it is issued, then the vendor call carries `WDSuspendLimit` equal to the limit, which is from 1 to `FREEZELIMITMAX`, and writes resume without a thaw within that limit plus the measured slack. A freeze whose limit cannot hold is refused before any vendor call.
- AC4 (DW-2560). Given a file outside the allowed set that names `OcuPilot.Port.Harvest.Monitor`, when `check-objectscript.py` runs, then it fails, naming the file and the rule. `PortGate` is red for a `Port/Harvest/` class with no roster row.

## Spec Change Log

- 2026-11-14, spec gate: split ruled (Backup here, Mirroring to 21.12); retitled and re-keyed; freeze limit and strings ruled (Design Notes). Status reset to `draft` for a re-plan of the backup scope only.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-10: the backup half of the 2026-10-09 arm, the suspend limit.
- AD-22: keys ship `false`, and a person's screen write is not governed.
- AD-23: the harvested body.
- AD-29: `BackupPort`'s own gate.
- AD-21: no path, and names from fixed sources.
- AD-35: no credential.
- AD-36: bounded reads.
- AD-51, AD-52, AD-53, AD-56 (ii) and AD-58: action writes, two callers, read-back.
- AD-6, AD-34 and AD-15: proposal, transition and audit.
- AD-14: the change event.
- AD-5 and AD-44: descriptors and classic keys.
- AD-16 and AD-59: namespace and `Snippet`.

**Decided in-stage:**

- Only `listHistory` and `run` go through the harvested body. The body's freeze cannot carry a limit, and its other arms take a path or a credential. Editing the body would break AD-23's "only the base changes", so the port builds the body's JSON from a two-value allow-list. A test asserts that no other action reaches it.
- A run is always started in the background (`jobbackup` 1), so a request never waits for a backup to finish.
- None of the five tools is `DESTRUCTIVE` (none removes data). Freeze's proposal carries a consequence line, which is a proposed string.
- A person's own screen write asks no governance key. That is AD-22 as it stands ("No other person's write is asked"). The screen's freeze uses the same port limit.
- Read pairs follow the classic menu (`%Admin_Operate:USE`, `%DB_IRISSYS:READ` and `WRITE`) unless Task 0 measures more. Stricter than the classic menu is allowed; looser is not.

**Runner rulings at the spec gate (2026-11-14, unattended; veto item filed):**

- Split accepted: 21.2 is Backup (key `21-2-backup`); the mirroring criteria moved verbatim to Story 21.12 (`21-12-mirroring`), planned next. AD-10's "named at Story 21.2's spec gate" pointer for the mirror-removal code now means Story 21.12's gate; its text is not edited unattended.
- `FREEZELIMITMAX` = 600 seconds, the limit required on every freeze, no default.
- The proposed strings below are ruled as proposed; the per-code `BACKUP.*` reason sentences are written in plain language in this spec and fall under the same ruling. Add each to EXPERIENCE.md's string table in the implement stage if that table exists.
- Proposed spine edits (AD-29 Binds `BackupPort`; the freeze limit in AD-10's backup arm) stay proposals in these Design Notes for the owner's attended Update.

**Needs ruling at the spec gate (recommended answer first):**

- `FREEZELIMITMAX` = 600 seconds, with the limit required and no default. The reason: after 600 s of suspension, the vendor blocks processes that update the database (`ExternalFreezeTimeOut`'s default, `General.cls:96-103`). A longer freeze also stalls the instance. This is a numeric value with product meaning.
- Proposed strings (need ruling). None is in EXPERIENCE.md.
  - Titles: "Backup tasks" · "Backup history" · "Backup database list".
  - Columns: "Type" · "Last run" · "Status" · "Description" · "System task" · "Time" · "Databases" · "Database" · "Directory".
  - Actions: "Run" · "Freeze writes" · "Thaw writes" · "Add database" · "Remove".
  - Freeze field and its help: "Suspend limit (seconds)" · "Writes resume by themselves after this many seconds, from 1 to 600."
  - Frozen banner: "Database writes are frozen. Thaw them when the external backup finishes."
  - Empty list: "The list is empty, so a list backup includes every database except IRISTEMP."
  - Freeze consequence: "Database writes stop until you thaw them or the limit passes."
  - Run note: "The backup runs in the background; its result appears in Backup history."
  - One reason sentence per `BACKUP.*` code.

**Extend, don't copy (Rule 2/31):**

- `BackupAction` follows `DatabaseAction`'s shape, but it is a sibling, not a subclass. Its port, its `STATE` and its rules differ, and subclassing would couple the database disk operations to backup.
- `BackupError` follows `EcpError`.
- The client follows the ECP list files.

**Integration ACs:** BackupPort is consumed in this story by its five tools and three descriptors (AD-53's two callers). The matrix rows are its integration ACs, observed through the API and the browser spec.
**Consumed-by:** the mirroring sibling (its monitor reads backup history alongside) and Story 21.11 (undo across write tools) (inference).
**Consumes:** `HarvestPort` (21.1), `Kernel.Fault`, `Screen.Gate`, `Screen/Tool/Write`.

**DW-2560** is addressed by Task "check-objectscript.py", the `PortGate` row kind, the spec-21-1 correction and AC4.

**Proposed spine amendment (Rule 20, for the runner):**

- Add `BackupPort` to AD-29's Binds.
- AD-10's arm: "the bound is `FREEZELIMITMAX` seconds (ruled at Story 21.2's gate), enforced by `BackupPort` through `WDSuspendLimit`. A freeze is refused where the instance would ignore it (measured predicate)."
- If the split below is taken, AD-10's "its code is named at Story 21.2's spec gate" names the mirroring sibling instead.

## Verification

**Shared surfaces:** the governance baseline and its `DISABLED` roster, the entity types and `Prohibited`'s covered types, the read sources, the tool registry, the OS management rail and screen roster (`screens.generated.ts`), `PortGate`'s roster, `SurfaceCoverage` and `EndpointCoverage`, the checker's rule count, and `ci-throwaway.sh`'s arming roster. The implement stage greps `ui/browser`, `ui/tools`, `ui/src` specs and `src/OcuPilot/Test` for each, and every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.* Each write test asserts on its own probe database and restores the list and the frozen state it found.

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only. Never two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/f9329139-8fb8-421f-b2bb-04300ba71baf/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.BackupRead`, one per call, then each of these -- expected: green:
  - `BackupRules`, `BackupWrite`, `Harvest`
  - `PortGate`, `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`
  - `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`
  - `Descriptor`, `Navigation`, `ClassicPageGate`, `DraftRegistry`, `StageTwoTools`
  - `Wire`, `WireAreaAnyScreen`
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && npm run build` and `npm run test:components`. Then redeploy: `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. Then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/backup.browser-spec.mjs`. Expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC:**

- AC1: `BackupPort`'s `TASKS` branch drops the system tasks. Expected red: `BackupRead`'s four-built-ins test.
- AC2: `osmgmt.backuptasks.freeze` is set `true` in the baseline. Expected red: `BackupRead`'s governance-default test.
- AC3: `WDSuspendLimit` is passed as 0. Expected red: `BackupWrite`'s freeze-resumes-without-thaw test.
- AC4: `BackupPort.cls` is removed from `HARVEST_CALLERS`. Expected red: the checker over the shipped tree.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- the story is too large for one implement pass. Recommend a split into two sibling stories in Epic 21, and decide before implement.

- **21.2 "Backup"** takes:
  - AC1, verbatim;
  - AC3's backup half: every backup write is a confirmed proposal whose key defaults to disabled, and every freeze carries a bounded suspend limit;
  - the DW-2560 bullet.

  This spec is that plan, already complete: 3 screens, 5 write tools, 1 port, 1 harvested body, in 2 batches. On acceptance, retitle it, re-key it, set `status: draft` and re-dispatch, so step 2 keeps this intent contract.
- **21.12 "Mirroring"** (Rule 17's N.<M+1>) takes:
  - AC2, verbatim;
  - AC3's mirroring half: every mirroring write is a confirmed proposal whose key defaults to disabled, and only "remove a mirror together with its databases" joins AD-10's set, with its code named at that story's gate.

Why the split:

- Size, measured: Story 18.20 touched 97 files for one screen with four writes, and the backup half alone is three screens with five writes.
- Mirroring is 9 catalog rows: SA-43, SA-44, SA-45, SA-46, SA-47, SA-48, SA-49, SO-15, SO-16 and SO-17. Seven of them are L, against backup's 5 rows (S/M).
- `SYS.Mirror` alone has about 45 public methods.
- The harvest source holds only `MirrorStatus` and `HealthCheckMirror` for mirroring, so nearly all of it is new code.
- Its Task 0 is a study of its own. It has to find out whether `%Service_Mirror` and an ISCAgent are available on `ocupilot-ci`, and whether `CreateNewMirrorSet` can be undone there.
- Join, promote, demote and the async and DR members need a second instance, which the memory rule forbids. So most of that half could be verified only by refusal and by shape (inference).

Splitting moves an AC, which is a veto-window item. It also retitles a story (a sprint key change, Rule 5) and changes AD-10's "named at Story 21.2's spec gate" to the new sibling.

At the same gate, also rule on the two items under Design Notes, "Needs ruling": `FREEZELIMITMAX` and the proposed strings.
