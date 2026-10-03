---
title: 'Story 18.19: Journal record browser'
type: 'feature'
created: '2026-10-02'
status: 'in-progress'
baseline_revision: 'b72bb7dadafcb1022f8e9a86242d71a75b636b1f'
baseline_commit: 'b72bb7dadafcb1022f8e9a86242d71a75b636b1f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic journal record browser (`%cspapp.op.utilsysjournal`, catalog SO-01 to SO-06's record view) is still the only way to read a journal file's records. The admin API carries it, with three flaws:

- The record list (`POST /journal/file/records`) answers half its `maxRows`.
- It splices the filter operator into code it executes (`irissys/%SYS/Journal/Record.cls:593`).
- Its rows and the record detail can carry journaled values (patient data, a secret a vendor body journaled).

Story 18.5 Part A built the journal-file guard that already names `Journal.Record`, and Journal file details. Part C (the record browser and detail) was split into this story at the orchestrator's merge gate on 2026-10-02.

**Approach:** OS management gains **Journal records**, an unlisted server-criteria list at `os-management/journal-records`. It is reached from Journal file details' View records by a screen arrival carrying the file, and continues with Next records.

- `AdminPort`'s guard gains the record rules:
  - the filter's column and operator come only from the classic page's closed sets;
  - a filter with an empty value is sent with no filter at all;
  - an offset or address is digits only;
  - the record list is asked twice the rows the read needs.
- A row opens the **journal record detail** dialog. It reads `GET /journal/record`, a screen-only route that is not a declared read, so record values reach that dialog and nowhere else.
- The read tool `osmgmt.journalrecords.read` answers the list's eight fields only.
- Task 0 observes the record routes on `ocupilot-b-ci` before anything is built.

## Boundaries & Constraints

**Always:**

- **Task 0 runs first, on `ocupilot-b-ci` only, and halts on any contradiction** (Tasks › Task 0).
  - It works on an `OCUPROBE185D` probe database it creates and removes.
  - It never switches the journal, changes a journal setting or deletes a journal file. The probe's journal records stay in the journal file.
  - It never sends an operator or column outside the closed sets below.
- **The screen.** One descriptor, `Screen/Descriptor/JournalRecordList.cls`, with no `classicLinkExemption`, no `parentScope`, no row or primary action, and no auto-refresh:

  | Route | Archetype | Pos | Entity type, id | Pairs | `classicPage` | `toolIdentifier` |
  | --- | --- | --- | --- | --- | --- | --- |
  | `os-management/journal-records` (not under `journals/`, where `journals/:id` would match it) | `list (server criteria)` | 0 | `journal-record`, composite `[Address]` | `%Admin_Operate:USE`, `%DB_IRISSYS:READ` (Journals' set, unless Task 0 rules otherwise) | `%cspapp.op.utilsysjournal` | `osmgmt.journalrecords` |

  - Its read is `{"port":"admin","endpoint":"Journal.Record","type":"LIST"}` over `Address, TimeStamp, ProcessID, TypeName, ExtTypeName, InTransaction, GlobalNode, DatabaseName`. Context carries the same eight fields, and none is secret.
  - It declares six criteria, in this order:

    | Criterion | Sent as | Kind | Options and default |
    | --- | --- | --- | --- |
    | `file` | `file` | text, maxLength 1024 | — |
    | `offset` | `initialOffset` | text, maxLength 20 | — |
    | `order` | `reverse` | choice | `0`, `1`; default `0` |
    | `column` | `matchColumnName` | choice | `TimeStamp, ProcessID, TypeName, ExtTypeName, InTransaction, GlobalNode, DatabaseName, MirrorDatabaseName`; default `GlobalNode` |
    | `operator` | `matchOperator` | choice | `=`, `'=`, `]]`, `']]`, `[`, `'[`; default `[` |
    | `value` | `matchValue` | text, maxLength 200 | — |

    Each criterion carries a `hint` (Execution › the grammar).
  - Prompts, group `promptGroupTroubleshooting`: "Which processes wrote these journal records?" · "Which globals changed in these records?" · "Are any of these records inside a transaction?"
- **The record rules live in the port** (proposed AD-21 sentence), so the screen, the tool and any direct caller of `AdminPort` meet the same refusal.
  - On `Journal.Record` `LIST`, a non-empty `matchColumnName` outside the eight columns, or a non-empty `matchOperator` outside the six operators, is refused 400 `JOURNAL.FILTER.SHAPE`.
  - A non-empty `matchValue` with an empty column or operator is refused the same way.
  - An empty `matchValue` drops all three keys.
  - `initialOffset` on `LIST`, and `address` on `GET`, must match `^[0-9]{1,20}$`, else 400 `JOURNAL.OFFSET.SHAPE`. An empty `initialOffset` is not sent. An empty `address` is refused.
  - Each refusal comes before any vendor call, the guard's file-list read included. No refusal echoes the value.
  - The screen and the tool also refuse a column or operator outside the options before the port: the screen 400 `READ.CRITERION`, through the read's own criterion check, and the tool 400 `TOOL.ARGUMENTS`, through its schema's `enum` (`Screen/Tool/Read.cls:210`).
- **The halving is the port's to absorb** (proposed AD-26 sentence). On `Journal.Record` `LIST`, `AdminPort` sends `maxRows` multiplied by the factor Task 0 sets (2 while the list halves). Truncation is still judged as rows above the cap (`Screen/Read.cls:575`).
- **Next records** continues from the read's own rows, never from a cursor the browser invents.
  - The next offset is the highest `Address` plus 1 in file order, or the lowest minus 1 in reverse order. Task 0 confirms the vendor reads an offset inclusively and snaps a non-record address to the nearest record (`GetAddressNear`, `Record.cls:274-279`).
  - Next records is offered whenever the page holds at least one row.
- **Record values are screen-only** (proposed AD-36 sentence).
  - `NewValue`, `OldValue` and `GlobalReference` reach the journal record detail dialog through `GET /journal/record` only. They never reach a read tool, screen context, the model, the ledger or a log line.
  - The dialog keeps the record in page-local state, never in the screen store.
  - The route answers every string value cut at 1,000 characters ending in U+2026. The page renders it as text, never markup.
  - The list's eight fields, `GlobalNode` among them, are ordinary, as the Locks list's lock references are.
- **The file is a listed name** (AD-21's eighth case, as built).
  - The detail route takes `file` and `address`, and its `file` must be a name the journal list answers (`JOURNAL.FILE.UNLISTED` otherwise).
  - An omitted `file` on the list reads the newest file. A page opened without a file first issues Journals' own declared read with `maxRows` 1 (AD-5) and searches that file by name, so every row and dialog names its file.
- **Contended files are add-only.** Epic 19 is concurrent on slot A, so these files only gain lines or list members:
  - `Api/Router.cls`;
  - `scripts/ci-throwaway.sh`, `ui/angular.json`, `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs`, EXPERIENCE.md;
  - the rosters `ReadTool`, `SurfaceCoverage`, `Wire`, `WireSecurityRead`, `Navigation`, `Descriptor`, `EndpointCoverage`, `ScreenRead`, `CriteriaCorpus`.

  These files are not edited at all: `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Gate.cls`, `Screen/Tool/Classification.cls`, `ui/src/app/core/navigation.ts`, `ui/src/app/core/screen-actions.ts`, `ui/src/app/shell/command-box.ts` and the spine.

  One-line list members and roster counts are unioned and summed by whichever story reaches feature second. EXPERIENCE.md stays at 1003 lines, and every shifted `/** EXPERIENCE.md:n */` citation is updated. New codes go in `Api/JournalError.cls`, never `Api/Error.cls`. `screens.generated.ts` is regenerated, never hand-merged.

**Never:**

- No write tool, governance key, proposal, change event, read-back or `Snippet` change: this story is read-only.
- No filter column outside the eight. No operator outside the six, on any path, Task 0 included.
- No per-row detail call (`rowGet`) for values. No value in a list row, the tool's view, screen context, the ledger, a log line or the screen store.
- No caller path. No side-bar or command-box entry: the screen is unlisted. No auto-refresh.
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses. No `%SYS.Journal.*` call in product code. Test-only `%SYS` seeding is allowed.
- No journal switch, journal setting change or journal file deletion by any test.
- No spine or epics.md edit in the implement stage. The runner writes the amendments in Design Notes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Arrival | Journal file details of the current file F → View records | The page reads "Records of F", runs one search with `file` F, and shows rows of the eight fields. `osmgmt.journalrecords.read` with `file` F answers the same rows. | none |
| Cold open | `os-management/journal-records` with no arrival (reload, deep link, agent navigation without `file`) | Journals' read (`maxRows` 1) names the newest file N, then the search runs with `file` N | none |
| Cap and halving | 30 journaled sets of `^OcuProbe185` in `OCUPROBE185D`; filter GlobalNode `[` `OcuProbe185`; cap 10 | `maxRows` 22 sent, 11 kept, 10 shown, truncated | none |
| Next records | The page above → Next records | The next 10 probe rows, the first after the previous page's highest `Address`; in order `1`, before its lowest | none |
| Filter | GlobalNode `[` `OcuProbe185` | Every row's `GlobalNode` contains `OcuProbe185` | none |
| Empty value | Column and operator at their defaults, no value | Sent with no match key; rows of every global | none |
| Injection, screen or tool | Operator `=1) x "set ^X=1" //`, or column `NewValue` | Refused before any vendor call | 400 `READ.CRITERION` (screen) / `TOOL.ARGUMENTS` (tool) |
| Injection, port | The same, `AdminPort.Invoke` directly; or a value with no operator | Refused before any vendor call, the file-list read included | 400 `JOURNAL.FILTER.SHAPE` |
| Offset or address shape | `offset` `12a`; route `address` `-1` | Refused before any vendor call | 400 `JOURNAL.OFFSET.SHAPE` |
| Unreadable database | A principal with the screen's pairs and no `%DB_OCUPROBE185D:READ` | No probe row in the list; the dialog for a probe address is refused | 404 `JOURNAL.RECORD.UNREADABLE` |
| Record detail | Click a probe row | The dialog shows type, time, process, database, global node and reference, and old and new values as text. A 1,500-character value ends in U+2026 at 1,000. A value `<b>x</b>` renders literally. | none |
| Values contained | After the list read, the tool read and the dialog | The tool result, the screen read answer, the screen-context payload, the ledger rows and `messages.log` carry no seeded value marker | none |
| Unlisted file | Route `file=/tmp/x.001` | Refused before the vendor call for the record | 404 `JOURNAL.FILE.UNLISTED` |
| Missing pair | Route as a caller without `%Admin_Operate:USE` | Refused naming the pair, zero port calls | 403 `AUTH.NOPRIVILEGE` |
| Scan past the bound | A filter scan longer than `ASYNCTIMEOUT` (30 s) | The read fails, and the page shows the refusal strip | 503 `PORT.TIMEOUT` |

</intent-contract>

## Code Map

**Vendor** (hidden classes exported read-only to `/tmp/epic-18-d6/185/vendor/`; re-export from `ocupilot-b-ci` if they are gone):

- `%Api.Admin.Endpoints.Journal.Record`, `ResourcesOR()` `%Admin_Operate`.
  - `RunList` reads `file` (required; a missing file answers 404), `matchColumnName`, `matchOperator`, `matchValue`, `reverse` (default 0), `initialOffset` and `maxRows` (default 1000).
  - A partial triple sets 400, and then `AddToAsyncQueue` overwrites `sc` and queues the task anyway.
  - It self-queues `Journal.ListTask` and answers 202.
  - `RunGet` takes `file` and `address`, answers 404 for a missing file or record, and `ObjToJson` answers:
    - top level: `TypeName, ExtTypeName, PrevAddress, NextAddress, TimeStamp, InTransaction, ProcessID, JobID, RemoteSystemID, ECPSystemID`;
    - `SetKill {ClusterSequence, Collation, DatabaseName, GlobalNode, GlobalReference, MirrorDatabaseName, NewValue, NumberOfValues, OldValue}`, `{}` for a record that is no set or kill;
    - `VectorSetKill {VecIndex, VecType}`.
  - `HasDBPermission` checks READ on the record's database with the caller's base roles (`New $Roles`) and answers 404 when it fails.
- `%Api.Admin.Endpoints.Journal.ListTask.RunTask` runs `%SYS.Journal.Record:List` over exactly the eight columns, so a list row never carries a value.
  - It increments its row counter twice per kept row and once per row on an unreadable database. Doubling is therefore exact only when no row is skipped.
  - It flushes partial results into its task row at 1, 5, 25 … rows. `AsyncTaskList.GetResult` keys each row by those column names.
- `irissys/%SYS/Journal/Record.cls`:
  - offset semantics `:400-402` (Address ≥ offset in order 0, ≤ in order 1) and `:447-450`;
  - `GetAddressNear` `:274-279`;
  - the operator spliced into `x "s %match=(..."` at `:593`.
- The classic page `irissys/%CSP/UI/System/OpenJournalPane.cls`:
  - the eight match columns `:362-372` and six operators `:373-381`, labels `:309-323`;
  - page size 250 `:138`; the columns shown `:400-407`; the row loop `:422-470`.
- Task tables: the vendor's task row is in `IRISLOCALDATA` (`%DB_IRISLOCALDATA` public `R`, read on `ocupilot-b-ci` at plan). `AddToAsyncQueue` saves it from `%SYS` code. Story 18.5's integrity check queued with Journals' two pairs alone (measured).
- Read on `ocupilot-b-ci` at plan (read-only, 2026-10-02): current file `/durable/iris/mgr/journal/20261003.318`; 848 listed files; no `OCUPROBE185D`; one journal directory.

**Port** — `Port/AdminPort.cls` (3,389 lines):

- Journal parameters `:713-734`: `JOURNALFILETYPES` already lists `Journal.Record/LIST,Journal.Record/GET`, and `JOURNALNEWESTTYPES` lists `Journal.Record/LIST`.
- `ASYNCTIMEOUT` `:830`.
- `InvokeLocated` `:1022`; the guard call `:1062` (`If ..IsJournalFileType(...)`).
- `JournalGuard` `:2513-2546`; `IsJournalFileType` `:2499`.
- `Sequence` `:2695`: a non-mutating self-queued type queues and is polled.
- `AwaitTask` `:2795`: logs a failed task's `FailureReason` and `PORT.TIMEOUT`.
- `ForgetTask` `:1472`: deletes only with WRITE on the task global. `SweepOwnTasks` `:1536`.
- `Snippet` `:3179` has one caller, `Kernel/Proposal/Draft.cls:217`, and a read does not reach it.

**Read grammar:**

- `Screen/Read.cls`:
  - `maxRows` set to cap+1 `:521`; truncation `:575`; the rows cut `:589`; projection to the declared fields minus secrets `:577-592`;
  - `SeedCriteria` `:954-1020`: an omitted criterion takes its `default`; an empty one is not sent; a choice outside `options` is refused `READ.CRITERION`; text has no content check;
  - `IsAbsence` `:1337`; the applied `criteria` echo `:606`.
- `Screen/Registry.cls`:
  - `CriteriaProblem` `:1449`; allowed criterion keys `:1525-1527`; `CRITERIARESERVEDPARAMS` `:1394`;
  - a parent-scoped read takes exactly one criterion `:1497`, which is why this screen has no `parentScope`;
  - `sort` is required `:1313`; `PROMPTGROUPKEYS` `:2740`.
- `Screen/Archetype.cls:67` `list (server criteria)`; `Screen/Tool/Navigate.cls:56` (only this archetype takes arrival criteria).
- `Screen/Tool/Read.cls` `AddCriteria` `:142-180`: a text criterion is described as "a comma-separated list of names", wrong for `file`, `offset` and `value`, which is why `hint` is added.
- `ui/tools/screen-mirror.mjs` `criteriaProblem` `:1670-1701`, kinds `:1641`, reserved `:1649`, allowed keys `~:1732`.
- `Test/CriteriaCorpus.cls`, `ui/tools/screen-mirror.test.mjs:1249-1279` (the `withCriteria` roster).

**Descriptor models:**

- `Screen/Descriptor/AuditList.cls`: a server-criteria list; criteria `:150-162`, an entry's shape `:158`.
- `Screen/Descriptor/JournalFileDatabaseList.cls`: OS management conventions, `table`, `emptyStateKey`, prompts.
- `Screen/Area.cls:75`: OS management's set.

**Detail route model:** `Area/OsMgmt/RemoteDatabaseRules.cls` `HandleDirectories` `:189-218`, a screen-only GET:

- gate `:251-258`: `Screen.Gate.Evaluate(..#DESCRIPTORCLASS, .tFailedPair)`, else `Kernel/Denial.Envelope`;
- `Api.Response.JSON`; port faults through `Area/OsMgmt/DatabaseRules.cls:547` `RenderRead`;
- route `Api/Router.cls:139`, wrapper `:709-712`. The UrlMap tail is `:224-225`.
- `Test/EndpointCoverage.cls` probe rows, the `:213` model: every route needs exactly one (`:445`).

**Kernel:** `Kernel/EntityType.cls:63` `TYPES` (45; `journal-*` doc lines `:51-56`). `scripts/check-objectscript.py:1038` and `screen-mirror.mjs:143` read it, and `Test/Descriptor.cls:1718` pins 45. No `EntityRef` rule: a `journal-record` id keeps its spelling.

**Errors:** `Api/JournalError.cls`: nine codes, `Codes()` `:76`, `ReasonFor` `:89`. `Api/Error.cls` already dispatches `JOURNAL.` at `:1224` and `:1421`. `Test/JournalDescriptor.cls:179` pins `Codes()` at 9.

**Client** (`ui/src/app/`):

- `areas/os-management/journal-file-details.page.ts` (316 lines): the template `:54-121`; the doc comment `:46` says "The page carries no action"; the file criterion `:167`; the row `:236-239`.
- The page-local link model is `areas/tasks/details.page.ts:109-120,287-290,311-316`.
- Server-criteria page models:
  - `areas/tasks/history.page.ts`: search state in a `WeakMap` per `ScreenStore`, `heldFor` `:68-74`; the arrival `:193-212`; the run dialog `:138-148`;
  - `areas/logs/audit.page.ts`: the criteria form `:75-105,262-275`; the arrival `:198-223`; the `:id` dialog `:123-147,228-231,368-373`;
  - `areas/system-explorer/code-list.page.ts` (a generic criteria form; a model only, never imported across slices).
- `core/screen-read.ts:165-193` (`screenReadPath`, `criteriaParams`).
- `core/screen-arrival.ts:17-67`: provided in `main.ts:255,281`, injected `{optional: true}`.
- `areas/logs/log-hub.page.ts:617-622` sets an arrival and navigates.
- `core/navigation.ts:696-717` (`withQuery`, `entityUrl`).
- `app.routes.ts:82`: every screen with an id kind other than `none` gets `<route>/:id`.
- `shell/data-table.ts:655-664`: a list with `parentScope` `''` and no detail screen links its name cell to its own `/:id`.
- `shell/dialog.ts` (`app-dialog`).
- `shell/screen-outlet.ts`: `ARCHETYPE_PAGES` `:105-117`, where `list (server criteria)` defaults to `AuditPage`; `DESCRIPTOR_PAGES` `:135-205`, journal entries `:189-194`, Epic 19's from `:195`.
- `core/strings.ts`:
  - Story 18.5's block `:4385-4468`, 18.18's `:4543-4590`, `} as const` `:4591`;
  - reusable keys: `auditColumnTime`, `proposalEntityProcess`, `tableColumnType`, `processDetailsInTransaction`, `systemInfoDatabase`, `auditDialogClose`, `auditCriteriaSearch`, `errorLogColumnValue`.
- `ui/tools/strings.test.mjs:576-579`: the literal bound is 2100, about 2095 in use.
- `ui/angular.json:54` `maximumWarning` is 2572kB against a measured 2,571,157 bytes, so this story crosses it; pinned at `ui/tools/angular-json.test.mjs:442`, last history row `:427-429`.

**EXPERIENCE.md** (1003 lines):

- `:164` the OS management side bar: unchanged, since the screen is unlisted;
- `:173` Dialogs;
- `:378` Fixed strings, where Stories 18.5 and 18.18 sit;
- `:523` prompt groups;
- `:655` the screens with server-side criteria;
- `:803` the server-criteria archetype row ("row → detail dialog").

**Rosters.** Re-derive each from its class's red, never by hand:

- ObjectScript:
  - `ReadTool:93` (220) and `:94` (names);
  - `Descriptor` `ReadShapes` `:67-144` and the entity count `:1718` (45);
  - `SurfaceCoverage` screens `:161-164`;
  - `EndpointCoverage` probes;
  - `Navigation:485` (36) and `:486-487`;
  - `Wire:709-712`; `WireSecurityRead:561,568,571`;
  - `ScreenRead:208`: the exclusion list. The live sweep would need journal activity, which a fresh instance does not promise;
  - `JournalDescriptor:179`.
- Derived sweeps the read tool enters with no edit: `ToolRoundTrip` (`{}` reads the newest file), `ToolDispatch`, `ToolEmit`.
- Unaffected, because they skip position 0 or count write tools only:
  - `WireAreaAnyScreen:232`, `LanguageServerWire:271`;
  - `ClassicPageGate`, `MappingDescriptor`, `GovernanceBaseline`, `Governance`, `DraftRegistry`, `PortGate`, `Inventory`.
- Client:
  - `ui/tools/navigation.test.mjs` `builtScreens()` `:124-280` (unlisted screens included; the message `:278`);
  - the hand fixtures `ui/tools/navigation-wire.test.mjs:155-167` and `shell/rail-wire.spec.ts:150-165`, which follow `Wire.cls`;
  - `ui/tools/screen-mirror.test.mjs:1249-1279`.
- Browser: no side-bar pin changes. The language-servers AC5 leg and every `ocu-side-bar-label` spec count listed entries only.

**Test models:**

- `Test/JournalProbe.cls`: prefix `OCUPROBE185` `:19`, `DirectoryFor` `:50`, `SeedPrincipal(user, role, resources)` `:179`, `RemoveAll` `:209`, `Run` `:379`, `RunAs` `:413`, `Snapshot` `:512`, `Diff` `:607`, `LineCount` `:637`, `LinesAfter` `:652`.
- `Test/BackgroundSeed.cls:61` creates a database with its `%DB_` resource in `%SYS`.
- `Test/JournalCountPort.cls` counts vendor calls at `HoldsResource`; `Guard()` exposes the guard.
- `Test/JournalRead.cls` has `READFIXTURE` and the arming via `JOURNALVARIABLE` `:19,:40`.
- `ui/browser/journals.browser-spec.mjs`: `iris()` `:79-92`, the throwaway guard `:112-121`, `assertStructure(page, route, dialog)` `:240-268`.
- `ui/browser/audit.browser-spec.mjs:665` (a row opens a read-only dialog that traps focus and closes on Escape).

**CI:** `scripts/ci-throwaway.sh`:

- `OCUPILOT_ALLOW_DATABASE_CONFIG` `:463`, its `# classes:` lines `:454-462`;
- `OCUPILOT_ALLOW_PRINCIPALS` `:301`, lines `:217-300`.
- `ui/tools/ci.test.mjs:2096,2159,2177` holds each `# classes:` set equal to the classes whose parameter names the variable.

## Tasks & Acceptance

**Task 0: the implement stage's first task, before any descriptor, rule or page.** Run it on `ocupilot-b-ci` only, and load with `/tmp/epic-18-d6/load-throwaway.sh` (no restart). Record every result under Design Notes › Measured at implement, and every AD sentence in `## Spec Change Log` for the runner.

Story 18.5's Task 0 already measured these, so they are not re-run: the classic page's `NormalizePage` spelling `%cspapp.op.utilsysjournal`; `LIST`'s first `Name` is the current file; one record `GET` takes 0.237 s; a listed name plus `z` is `JOURNAL.FILE.UNLISTED`.

1. **Plumbing (test code only).** `Test/JournalProbe.cls` gains:
   - `SeedProbeDatabase(pArmed, Output pFile, pCount = 30)`: refused unarmed.
     - It creates the resource `%DB_OCUPROBE185D` first, then `<mgr>ocuprobe185d/` and the journaled database `OCUPROBE185D` (`SYS.Database.CreateDatabase` with `GlobalJournalState` 3, HSCUSTOM's value), in `%SYS` with explicit save and restore.
     - It sets `^|"^^<dir>"|OcuProbe185(i)` to `"OcuProbe185Value-"_i` for each `i`, one of them 1,500 characters long and one the text `<b>x</b>`.
     - `pFile` is `GetCurrentFileName()` after the sets.
   - `RemoveProbeDatabase()`, which `RemoveAll` also calls.

   The timed calls go through `Run(endpoint, type, query)` and `RunAs`.
2. **S0** with `Snapshot`, plus the async task row count, the `messages.log` and `alerts.log` line counts, and the monitor state.
3. **Measure** on `pFile`, with the filter GlobalNode `[` `OcuProbe185` unless a step says otherwise:
   - a. `LIST` `maxRows` 10 and 40: the kept rows (expected 5 and 20). Each row's keys must be exactly the eight columns.
   - b. `initialOffset` equal to a kept row's `Address`: is that row first? With `Address`+1, is the next row first? In `reverse` 1, with `Address` and with `Address`−1.
   - c. Each of the six operators once and each of the eight columns once, with a plausible value: answered and finished, and what matched.
   - d. The partial triple (column and operator, no value), sent as is: the answer, and whether a task row is left. Remove a row that is left.
   - e. Durations against `ASYNCTIMEOUT`:
     - `LIST` `maxRows` 2002 with no filter;
     - a filter that matches nothing, over `pFile`;
     - a filter that matches nothing, over the largest listed file.
   - f. The async task row count after each read: the port removes the row for `_SYSTEM`.
   - g. `GET` of a probe record and of a record that is no set or kill: the answer's keys and the duration.
   - h. Principals from `SeedPrincipal`, each holding the install namespace's code read:
     - (i) Exactly the screen's two pairs. Measure `LIST` `maxRows` 40 (the kept count, and no probe row), `GET` of a probe record (expected 404), and `GET` of a record on IRISSYS (expected 200). Remove the finished task row the principal leaves.
     - (ii) Each of the two pairs removed in turn: the answer to each.
     - (iii) Only if (i) is refused: each candidate extra alone (`%DB_IRISLOCALDATA:WRITE`, `%DB_IRISTEMP:WRITE`, `%DB_IRISSYS:WRITE`, `%Admin_Manage:USE`), recording which one admits the call.
   - i. Whether `LIST` or `GET` records a vendor audit event, with auditing on.
4. **Cleanup proof:** `RemoveProbeDatabase`, `RemoveAll`, then S2. S2 equals S0 except:
   - counters;
   - the probe's journal records, which stay in the journal file;
   - `messages.log` lines;
   - the monitor state, cleared with `$SYSTEM.Monitor.Clear()` when it moved.
5. **HALT** `blocked`, with blocking condition `intent gap: observation contradicts the plan: <what>` and nothing built, if:
   - `LIST` does not answer 202, `GET` answers 202, or either route cannot be reached through `AdminPort`;
   - a list row carries `NewValue`, `OldValue` or `GlobalReference`;
   - any read changes stored state other than the vendor's task row, or `_SYSTEM`'s task row outlives the port's read;
   - principal (i) lists or reads by `GET` a record on a database it cannot read (AD-9);
   - any read needs a pair beyond the screen's two (record step h(iii)'s evidence first, for the orchestrator's ruling);
   - the vendor refuses a column or operator of the closed sets;
   - S2 differs from S0 beyond the declared differences.
6. **Otherwise, set from the record:**
   - the factor in `HALVEDROWTYPES`: 2 while the list halves, 1 if it does not;
   - the next-page rule: highest `Address`+1 and lowest −1 when step b measured the snap. Otherwise, the page and the hint keep the last `Address`, and the page drops a first row equal to it;
   - the `offset` hint's text;
   - the dialog's field list from step g;
   - Named limit 2's durations.

   A scan longer than `ASYNCTIMEOUT` is a named limit, not a halt.

**Execution (server):**

- `src/OcuPilot/Port/AdminPort.cls` (add-only):
  - New parameters:
    - `JOURNALMATCHCOLUMNS` and `JOURNALMATCHOPERATORS`, the closed sets;
    - `JOURNALMATCHPARAMS = "matchColumnName,matchOperator,matchValue"`;
    - `JOURNALOFFSETPARAMS = "Journal.Record/LIST=initialOffset,Journal.Record/GET=address"`;
    - `HALVEDROWTYPES = "Journal.Record/LIST=2"` (the factor from Task 0).
  - A private `JournalRecordRules`, called from `InvokeLocated` before `JournalGuard` for the pairs those parameters name. It applies the Boundaries' record rules and the doubling to the query copy `tQuery`. Each refusal goes through `Refuse` with `JournalError`'s reason. Doc comments state the rules.
- `src/OcuPilot/Api/JournalError.cls`: three codes, each in `Codes()` and `ReasonFor`. They are envelope reasons, not client strings (the Story 18.5 precedent).
  - `JOURNAL.FILTER.SHAPE` (400): "Choose a column and a comparison from the lists, and a value to compare."
  - `JOURNAL.OFFSET.SHAPE` (400): "Enter a record offset as a whole number."
  - `JOURNAL.RECORD.UNREADABLE` (404): "That record is not in this file, or its database is one you cannot read."
- `src/OcuPilot/Kernel/EntityType.cls`: `journal-record` joins `TYPES`, with its doc line.
- `src/OcuPilot/Screen/Descriptor/JournalRecordList.cls` (new), per the Boundaries:
  - `entityLabelKey` `aboutJournalRecord`;
  - `sort` over the eight fields, default `Address` `asc`;
  - `filter` `GlobalNode, DatabaseName, TypeName`;
  - `paging` `cap`;
  - the `table` columns:

    | Field | Label | Kind |
    | --- | --- | --- |
    | `Address` | "Offset" | name |
    | `TimeStamp` | `auditColumnTime` | — |
    | `ProcessID` | `proposalEntityProcess` | — |
    | `TypeName` | `tableColumnType` | — |
    | `ExtTypeName` | "Extended type" | — |
    | `InTransaction` | `processDetailsInTransaction` | — |
    | `GlobalNode` | "Global node" | — |
    | `DatabaseName` | `systemInfoDatabase` | — |

  - `emptyStateKey` reads "No records match.", and `emptyNextKey` is `tableReadOnlyEmptyNext`.
  - Each criterion's `hint`:
    - `file`: the file as Journals lists it (`osmgmt.journals.read` `Name`), omitted for the current file.
    - `offset`: a whole-number record address, its record included; continue after a page with the highest `Address` plus 1, or in order `1` the lowest minus 1, per Task 0.
    - `order`: `0` lists in file order from the offset or the start; `1` lists in reverse, from the offset or the end.
    - `column`: compared only when a value is given.
    - `operator`: names each symbol (`=` equals, `'=` does not equal, `]]` sorts after, `']]` does not sort after, `[` contains, `'[` does not contain).
    - `value`: omitted for no filter.
- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Screen/Tool/Read.cls` (**the grammar**, proposed AD-36 sentence):
  - A criterion may declare `hint`, a non-empty string of at most 300 characters, refused identically by the two validators otherwise.
  - `Read.AddCriteria` publishes it in place of the kind's first sentence. A choice keeps its `enum`, and the omit/default sentence still follows.
  - The page never shows it.
  - `Test/CriteriaCorpus.cls` gains a valid case and two refused cases (not a string; over 300).
- `src/OcuPilot/Area/OsMgmt/JournalRecordDetail.cls` (new; the `RemoteDatabaseRules.HandleDirectories` model). `HandleGet()` serves `GET /journal/record?file=&address=`:
  1. It gates on `Screen.Gate.Evaluate("OcuPilot.Screen.Descriptor.JournalRecordList", .tFailedPair)`, refusing with `Kernel/Denial.Envelope` and zero port calls.
  2. It calls `AdminPort.Invoke("Journal.Record", "GET", …)`, so the port's address rule and the guard apply.
  3. It maps the port's `PORT.NOTFOUND` to 404 `JOURNAL.RECORD.UNREADABLE`. Any other fault, `JOURNAL.FILE.UNLISTED` included, renders as it is.
  4. It answers `{record}`: the vendor's top-level scalars with `SetKill`'s and `VectorSetKill`'s members flattened in, every string cut at 1,000 characters ending in `$Char(8230)`.
  5. It logs nothing of the answer.

  It is not a declared read, so no tool reaches it. Its port is a `PORTCLASS` parameter (default `OcuPilot.Port.AdminPort`), so a test subclass counts calls through `JournalCountPort`, as `JournalRead`'s `READFIXTURE` does.
- `src/OcuPilot/Api/Router.cls` (add-only): `<Route Url="/journal/record" Method="GET" Call="JournalRecord"/>` at the UrlMap tail, and its one-line wrapper.
- `src/OcuPilot/Test/JournalProbe.cls`: Task 0's helpers.

**Client:**

- `ui/src/app/areas/os-management/journal-records.page.ts` (new, with a spec; no `.store.ts`). It follows the `history.page.ts` model, its search state in a `WeakMap` per `ScreenStore` inside the page file, so `refresh.reset()` drops it at sign-out and `app.ts` needs no line.
  - **Opening:** it takes a `ScreenArrivals` arrival for its route. Without a `file`, it first issues Journals' declared read with `maxRows` 1 and uses its first row's `Name`. Then it runs one search.
  - **The criteria form:** heading "Records of <file>". `offset` and `value` are text inputs. `order`, `column` and `operator` are selects with labeled options:
    - order: "Oldest first", "Newest first";
    - column: "Time", "Process", "Type", "Extended type", "In transaction", "Global node", "Database", "Mirror database";
    - operator: "equals", "does not equal", "sorts after", "does not sort after", "contains", "does not contain".
  - **Search and Next records:** a Search button. Next records sets `offset` from the read's own rows, per the Boundaries, and searches again.
  - **The table and the dialog:**
    - The shared table renders the rows. A name cell opens `<route>/<Address>`.
    - On a route id, the page opens `app-dialog` titled "Journal record <offset>". It `GET`s `/api/ocupilot/journal/record?file=<file>&address=<id>` and renders each field as a text label and value (`pre` for the values).
    - It shows a refusal's reason, such as `JOURNAL.RECORD.UNREADABLE`.
    - It keeps the record in a page-local signal cleared on close, never in the store.
    - Close returns to the list route with the criteria kept.
- `ui/src/app/areas/os-management/journal-file-details.page.ts`:
  - A page-local "View records" link (the `tasks/details.page.ts:109-120` model) inside `@if (showFields)`. It sets the arrival `{route: 'os-management/journal-records', criterion: '', criteria: {file: <Name>}}` and navigates with `withQuery`; a modified click is left to the browser.
  - The doc comment at `:46` is corrected to name it. `ScreenArrivals` is injected `{optional: true}`, and the spec provides it.
- `ui/src/app/shell/screen-outlet.ts` registers `JournalRecordList` in `DESCRIPTOR_PAGES` after `:194` (before Epic 19's entries), so the archetype's `AuditPage` never serves it.
- `ui/src/app/core/strings.ts` (add-only, after `:4590`), each key under its `/** EXPERIENCE.md:n */` line.
  - New literals: "Journal records", "journal record", "View records", "Records of <file>", "Next records", "No records match.", "Offset", "Order", "Oldest first", "Newest first", "Column", "Comparison", "Extended type", "Global node", "Mirror database", the six operator labels, "Journal record <offset>", "Global reference", "New value", "Old value", "Previous record", "Next record", and the three prompts.
  - Reuse the keys named in the Code Map.
  - Raise `ui/tools/strings.test.mjs:577`'s bound by the literals added, with its history comment.
- Regenerate `ui/src/app/core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`.
- `ui/angular.json`: re-base `maximumWarning` under DW-1166 to the measured initial total rounded up to the next kB, with its history row in `ui/tools/angular-json.test.mjs`. Stop and ask above 3800kB.
- EXPERIENCE.md, in place, keeping 1003 lines, then run `cd ui && npm run test:tools`:
  - `:173` gains "journal record detail (Story 18.19)" after "audit event detail";
  - `:378` gains "; and Journal records (Story 18.19): …" with every literal above and the three prompts in "Troubleshooting", tagged `[ADDED <date> - Story 18.19]`;
  - `:655`'s list gains "Journal records".

**Rosters and CI:**

- Extend every roster in Code Map › Rosters, and add `JournalRecordList` to `ScreenRead:208`'s exclusion with its one-line reason.
- In `scripts/ci-throwaway.sh` (add-only), add a `# classes: JournalRecordDetail, JournalRecords` line under `OCUPILOT_ALLOW_DATABASE_CONFIG` and another under `OCUPILOT_ALLOW_PRINCIPALS`. Keep `ui/tools/ci.test.mjs` equal.

**Tests:**

- `src/OcuPilot/Test/JournalRecords.cls` (new; parameters for `OCUPILOT_ALLOW_DATABASE_CONFIG` and `OCUPILOT_ALLOW_PRINCIPALS`). `OnBeforeAllTests` seeds through `SeedProbeDatabase` and keeps `pFile`; `OnAfterAllTests` removes it. Its legs:
  - the cap leg: the screen's read and the tool at cap 10 answer the same 10 probe rows, truncated, each carrying exactly the eight fields (this replaces `ScreenRead`'s live sweep for the screen);
  - Next records in both orders: the next 10, none repeated;
  - the filter;
  - the empty-value leg, where a recording seam on the `JournalCountPort` model sees no match key;
  - the injection and shape refusals on the screen, the tool and `AdminPort`, each with zero vendor calls;
  - the unreadable-database principal, through `RunAs`;
  - no seeded value marker in the tool result or the screen read answer. The ledger and the transcript keep only a tool's call and result (`Kernel/Agent/Loop.cls:604-609`), so this leg stands for them;
  - `{}` on the tool answers 200 over the newest file.
- `src/OcuPilot/Test/JournalRecordDetail.cls` (new; the same arming). Its legs:
  - the route's gate, with zero port calls;
  - the address shape;
  - the unlisted file;
  - a probe record's values, the 1,500-character cut and `<b>x</b>` verbatim;
  - the unreadable principal's 404 `JOURNAL.RECORD.UNREADABLE`;
  - no marker in `messages.log` after the route (`LinesAfter`), and no `Journal.Record` tool in the registry.
- `src/OcuPilot/Test/JournalDescriptor.cls`:
  - the descriptor's route, archetype, position 0, pairs, classic page, entity type, prompts and no parent scope;
  - the criteria, with options equal to `AdminPort`'s `JOURNALMATCHCOLUMNS` and `JOURNALMATCHOPERATORS`, the defaults and every `hint`;
  - `Codes()` reads 12, and each new code reads its sentence.
- `ui/src/app/areas/os-management/journal-records.page.spec.ts`:
  - the arrival's file, and the cold open's Journals read;
  - the labeled options;
  - Next records' offset in both orders;
  - the dialog's request, text rendering and refusal;
  - Close keeps the criteria;
  - the screen-context payload after the dialog opens carries no value.
- `ui/src/app/areas/os-management/journal-file-details.page.spec.ts`: View records sets the arrival and navigates.
- `ui/browser/journal-records.browser-spec.mjs` (new; seeds and removes the probe database over `docker exec`, refusing a non-throwaway as `journals.browser-spec.mjs` does):
  - Journals → the current file's details → View records names the file;
  - the probe filter, then Next records;
  - a probe row's dialog shows the values as text and closes on Escape;
  - the DW-1337 structural gate in both themes, on the list and on the dialog.

**Acceptance Criteria:**

- **AC0:** Given `ocupilot-b-ci`, when the implement stage starts, then Task 0's payloads, halving, offset semantics, operator and column acceptance, durations, pairs and audit events are recorded before any descriptor, rule or page exists, and S2 equals S0 apart from the declared differences. A contradiction halts the story.
- **AC1:** Given a journal file, when a person chooses View records on its details, or the page opens with no file, then the page names the file it reads, and the page and `osmgmt.journalrecords.read` answer the same rows of the eight fields through one read.
- **AC2:** Given more probe records than the cap, when the page or the tool reads them, then at most the cap rows are shown from twice the cap plus two asked, truncation is marked, and Next records continues after the page's last record in either order.
- **AC3:** Given a filter column or operator outside the closed sets, a value with no column or operator, or an offset or address that is not a whole number, when any caller sends it, then it is refused before any vendor call. A filter with an empty value is sent with no match key.
- **AC4:** Given a caller with the screen's pairs and no READ on a database, when that caller lists records or opens one, then no row of that database is listed and its record is refused `JOURNAL.RECORD.UNREADABLE`.
- **AC5:** Given a listed row, when the person opens it, then the dialog shows the record's fields and values as text, each cut at 1,000 characters. The route refuses a caller without the screen's pairs by name, with zero port calls, and an unlisted file `JOURNAL.FILE.UNLISTED`.
- **AC6:** Given seeded record values, when the list, the read tool and the dialog have run, then no tool result, screen read answer, screen-context payload, ledger row or log line carries any of them.
- **AC7:** Given the rosters, when the story lands:
  - every roster includes the screen, its read tool, its entity type and its route;
  - the screen has three prompts and no side-bar entry;
  - the DW-1337 gate holds in both themes;
  - EXPERIENCE.md reads 1003 lines.

### Review Findings

Code review, 2026-10-03 (`full-opus`; four layers; 38 rows, 13 entries after grouping, 15 rejected).

- [x] [Review][Patch] (med) An offset or address above 4294967295 passed the digit rule and the vendor's list failed `<VALUE OUT OF RANGE>`: 500 `INTERNAL` with a logged error, measured. `JOURNALMAXADDRESS` now refuses it `JOURNAL.OFFSET.SHAPE` before any vendor call [src/OcuPilot/Port/AdminPort.cls:2659]
- [x] [Review][Patch] (med) In order 1 the read tool sorted the newest rows ascending before the context cap cut them, so the offset hint's next page skipped every row the cut dropped. The `order` hint now tells the caller to send `direction` `desc` with 1; `TestTheToolInReverseOrderKeepsTheNewestRowsUnderTheContextCap` pins it at a context cap of 10 [src/OcuPilot/Screen/Descriptor/JournalRecordList.cls:60]
- [x] [Review][Patch] (low) An `InTransaction` filter compares the journal's 0 or 1, while rows read `true` or `false`, so a filter on `true` matched nothing (measured). The `value` hint says so [src/OcuPilot/Screen/Descriptor/JournalRecordList.cls:63]
- [x] [Review][Patch] (low) A cold open's Journals answer overwrote a file an arrival had named while it was in flight. It now sets the file only while none is named, pinned by a page-spec leg [ui/src/app/areas/os-management/journal-records.page.ts:219]
- [x] [Review][Patch] (low) QA's browser refusal leg was titled AC4, passed `?file=` the page never reads, asserted only a non-empty reason, and asserted a value-freedom that could not fail at address 1. It is now an AC5 leg asserting the route's own `JOURNAL.RECORD.UNREADABLE` sentence after a cold reload [ui/browser/journal-records.browser-spec.mjs:313]
- [x] [Review][Patch] (low) A failed `SetReadable` precondition let the next assertion pass on an unfiltered list. Both callers now stop after it [src/OcuPilot/Test/JournalRecordDetail.cls:209]
- [x] [Review][Patch] (low) The Verification evidence predated QA's changes: both journal classes, both journal browser specs and the client tiers were re-run on the final tree (Verification › Code review)
- [x] [Review][Patch] (low) Reverse-order Next records on the instance had no recorded mutation. Recorded: run 4451 [src/OcuPilot/Test/JournalRecords.cls:179]
- [x] [Review][Patch] (low) The record route's answer, which carries record values, could be stored by the browser's HTTP cache. It now sends `Cache-Control: no-store`, pinned over the wire [src/OcuPilot/Area/OsMgmt/JournalRecordDetail.cls:63]
- [x] [Review][Patch] (low) The tool's offset refusal had no test of its own. The tool now meets `JOURNAL.OFFSET.SHAPE` with zero vendor calls [src/OcuPilot/Test/JournalRecords.cls:362]
- [x] [Review][Defer] (low) Newest first draws its newest records oldest first, the descriptor's default sort [ui/src/app/shell/data-table.ts:924] — deferred: DW-1979, routed to `burndown` at adjudication
- [x] [Review][Defer] (low) The record dialog's body is empty for about 1.7 s while the record loads [ui/src/app/areas/os-management/journal-records.page.ts:430] — deferred: DW-1980 `wontfix-accepted`
- [x] [Review][Defer] (low) The text criteria carry no `maxlength`; the patch was measured but does not fit the merged 2611kB bundle budget, a contended line [ui/src/app/areas/os-management/journal-records.page.ts:278] — deferred: DW-1981, routed to `burndown` at adjudication

Rejected:

- `low` A dialog reloaded while Journals' read faults stays open with no refusal, and the heading names no file: a fault on a cold reload of a record route, rare, and the shell's fault banner already shows it.
- `low` No URL carries the file, so a reloaded or shared record route reads the newest file: the cold open reads the newest file by design (matrix row "Cold open"; AD-11 keeps criteria out of the URL).
- `low` `SeedProbeDatabase` does not check that journaling is on: a stock instance journals, and every leg fails loudly on its row counts if it does not.
- `false` A sparse filter over a full-size file is likely to time out: a non-matching scan of the 591 MB current file took 6.9 s on `ocupilot-b-ci`; canceling at the bound is AD-26's existing port behavior.
- `low` Named limit 1 still reads "(inference until Task 0)": the fix is a spec edit.
- `low` A failed seed leaves the probe database behind: the next seed removes it first, and CI runs on fresh instances.
- `low` Next records after a faulted search takes the earlier rows: Next sends the form as shown, as the first review adjudicated.
- `low` A journal switch between the seed and `SetReadable` would flake the readable legs: only a midnight or size switch inside a few seconds reaches it.
- `false` Order 1 from a block's first record minus 1 may land on a block start: measured at four block boundaries, the list answered the previous record each time.
- `low` Task 0's cleanup showed `alerts.log` +1, undeclared: its cause, h(ii)'s 500, is recorded; the fix is a spec edit.
- `low` The matrix row names a refusal strip where the shell's banner draws the timeout: the fix is a spec edit, as the first review found.
- `low` With the file omitted, the tool cannot keep paging one file across a journal switch: named limit 4, and the switch inside one turn is rare.
- `false` The dialog shows 13 fields, not every field: the matrix row's fields and the literal list's labels are all shown.
- `false` "Journal record" is capitalized against the spec's literal: it matches EXPERIENCE.md and the `aboutJournalFile` precedent.
- `false` `AdminPort` names the vendor's `Fetch`, not `ZUFetch`: `Fetch` (`Record.cls:381`) also executes the operator.

### Rework 1 (CI)

- [ ] [CI] browser shard 1/3 of run 37127676205 (`6344e34f`): `ui/browser/journal-records.browser-spec.mjs` "AC5, AC7: a seeded record opens the dialog, which shows its values as text and closes on Escape" failed at `:304` (numbered as at `9becc6df`) with `failed to find element matching selector "#ocu-journal-records-value"`, read at once after the dialog is gone. Closing moves from `journal-records/:id` to `journal-records`, two route entries, so `ScreenOutlet` and the page are created afresh and the form renders on a later change-detection pass (inference). The leg passes on `ocupilot-b-ci`. Make the leg wait for the form before reading it, and check every other leg that reads the page right after a route change.

## Spec Change Log

- For the runner (AD-26, no factor correction): in the Story 18.19 paragraph, replace "Story 18.19's Task 0 confirms it" with "measured again at Story 18.19's Task 0 on `ocupilot-b-ci`, 2026-10-03: 4, 10, 40 and 2002 gave 2, 5, 20 and 1001".
- 2026-10-03, runner (rework 1, trigger=ci): re-opened for the `[CI]` item under Tasks & Acceptance; nothing else changes.

## Review Triage Log

### 2026-10-03 — Review pass

- verdicts: 21 findings — high 0, medium 7, low 2, false 12, maybe-false 0
- findings:
  - `[medium]` `[patch]` The read tool's hinted descriptions are unpinned (the choice sentence and the default sentence) — `JournalDescriptor` now asserts `order`'s whole description and `file`'s hint alone; mutation run 3995.
  - `[medium]` `[patch]` AC4's principal legs pass on an empty list or a blanket refusal — `JournalProbe.SetReadable` writes a record on the database every probe principal reads; the principal lists it (`JournalRecords`) and opens it 200 (`JournalRecordDetail`); mutation run 3997.
  - `[medium]` `[patch]` AC6's log leg passes when `messages.log` cannot be read — asserts the line count is read; mutation run 3996 (grouped with the window finding below).
  - `[low]` `[patch]` The no-argument tool test compares two answers that can both be empty — asserts the newest file answers rows.
  - `[medium]` `[patch]` "The record is never in the screen store" is unpinned — the page spec asserts the store keeps the three list rows and no value; vitest mutation recorded.
  - `[medium]` `[patch]` The Final tree evidence predated the final tree — re-run after the patches: the full ObjectScript sweep, a rebuilt and redeployed bundle (2,587,710 bytes, 2588kB unchanged) with both journal browser specs, `npm test`; the Final tree line rewritten.
  - `[low]` `[reject]` The hint branch's datetime description says "1 hours" and drops the time-part sentence — no hinted datetime criterion exists, so no caller meets it, and a correct fix means deciding what a hint replaces for a datetime, more than a direct correction.
  - `[false]` `[reject]` No test reads the ledger — a ledger row keeps only a tool's call and result (`Kernel/Agent/Loop.cls:604-609`), and the tool result is asserted value-free.
  - `[medium]` `[patch]` The `messages.log` window covered the route only, not the list and tool reads — the window now also runs the screen read and the read tool over the seeded records.
  - `[false]` `[reject]` Screen context is checked over stubbed rows — the payload is the real `assembleScreenContext` over the store's rows after the page's read, and those rows' value-freedom is pinned on the instance.
  - `[medium]` `[patch]` The record is never in the screen store, untested at that surface — grouped with the store finding above.
  - `[false]` `[reject]` The scan past the bound uses a canned poll and checks the fault, not a rendered banner — the throwaway's longest scan is 13.9 s (Task 0 e), and a 503 is a server fault the shell's fault banner draws from the refresh's fault (`core/fault.ts`, `fault-banner.wire.spec.ts`).
  - `[false]` `[reject]` The unreadable list is tested at `AdminPort`, not the screen or the tool — both call `AdminPort.Invoke` in the caller's own process with no escalation, so they meet the same vendor skip.
  - `[false]` `[reject]` Next records takes the form's current order — the offset follows the spec's rule for the order the next search sends, and the page spec pins it.
  - `[false]` `[reject]` 22 sent is asserted on an unfiltered read and 11 kept is never observed — the doubling is per request type whatever the filter, truncation with 10 shown needs an 11th kept row, and the low-privilege shortfall is named limit 1.
  - `[false]` `[reject]` Two values in contended files change — the bundle re-base and the strings bound are the spec's own tasks and the lead's sanctioned exceptions.
  - `[false]` `[reject]` A modified View records click opens the newest file — the spec leaves a modified click to the browser.
  - `[false]` `[reject]` The tool's echo reads an omitted file as empty — named limit 4.
  - `[false]` `[reject]` A two-pair principal leaves finished task rows and one Protect audit event — recorded at Task 0 h(i) and named limit 3; the tests remove those rows.
  - `[false]` `[reject]` A direct port caller without `%DB_IRISSYS:READ` gets 500 — every caller (screen, tool, route) gates on that pair first; only test code calls the port directly.
  - `[false]` `[reject]` The diff cannot show that Task 0 ran first — not a defect of the change; the order is recorded under Measured at implement.

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: the record rules sit in `AdminPort` beside the guard. No vendor class is called, so no AD-27 case is needed.
- AD-5, AD-36, AD-44: one descriptor with one read for the screen and the tool. The page issues Journals' read to name the newest file. The classic page is declared.
- AD-7, AD-9: an async read in a turn queues a vendor task row through the vendor's own work queue, as the audit list has since Release 1. OcuPilot spawns nothing, and the port is never called from an escalated frame.
- AD-8, AD-29: the screen keeps Journals' set unless Task 0 rules otherwise.
- AD-11, AD-24, AD-60: `GlobalNode` and the other row fields reach the model as bounded, sanitized tool-result content.
- AD-13: the `journal-record` id.
- AD-14, AD-43, AD-58, AD-59: no write, so no change event, read-back or `Snippet`; no auto-refresh.
- AD-21: the eighth case, as built, and the closed filter sets.
- AD-26, AD-37: the self-queued read, the doubled `maxRows`, and the task row's sweep.
- AD-36, AD-48: values screen-only; the criterion `hint`.
- AD-39: the codes in `JournalError`; vendor text logged, never sent.

**Decisions:**

- **No parent scope.** A parent-scoped read takes exactly one criterion (`Registry.cls:1497`), and the browser needs six. A parent scope would also stop the name cell opening the dialog (`data-table.ts:662`). The file therefore travels as a criterion through an arrival.
- **The dialog is the `:id` route,** as the audit list's is. It fetches the record because the list rows deliberately hold no values. Its id is the address within the file the page reads.
- **Next records reads the page's highest or lowest address, not its last displayed row,** because the table's client sort can reorder rows.
- **`hint` is added** because the read tool would otherwise describe `file`, `offset` and `value` as "a comma-separated list of names" (`Read.cls:172`). A model cannot page or filter from that.
- **The rules are checked before the guard's list read,** so a refused filter costs no vendor call at all.
- **Values are screen-only under AD-48's reasoning.** The payload has no schema, and it can hold patient data or a secret a vendor body journaled (AD-26's Story 16.14 paragraph). `GlobalNode` stays ordinary, as Story 18.5 decided and as lock references are.

**Named limits:**

1. A caller who cannot read some databases gets fewer rows per page, because each skipped row spends one count of the vendor's budget. The list may read as complete while later records remain. A page whose every scanned record is unreadable shows none, and Next records cannot continue past it (inference until Task 0).
2. A filter scan longer than `ASYNCTIMEOUT` (30 s) fails `PORT.TIMEOUT`. Task 0 records the durations.
3. Between the vendor's queue and the port's delete, the page's rows (`GlobalNode` among them) and the filter value sit in the vendor's task row in `IRISLOCALDATA`, which every user can read. A caller who cannot delete the row leaves it there until the 24-hour sweep (AD-37). This is a candidate IRIS defect, human-owned, like DW-1527.
4. With the file omitted, the tool's `criteria` echo reads `file` as empty. The tool's `hint` says that an omitted file reads the current file.
5. A value longer than 1,000 characters is shown cut. The dialog has no full view.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate, and Task 0 confirms each `<measured>`):**

1. **AD-21, after the eighth case:** "**The record list's filter is never code a caller writes** [AMENDED <date>, Story 18.19 spec gate, Rule 20]. On `Journal.Record` `LIST`, `AdminPort` takes `matchColumnName` only from the classic page's eight columns and `matchOperator` only from its six operators, because the vendor splices the operator into code it executes (`%SYS.Journal.Record` `ZUFetch`). It refuses anything else `JOURNAL.FILTER.SHAPE` before any vendor call. It sends the three filter keys together or not at all. It takes `initialOffset`, and the record `GET`'s `address`, only as digits. `NewValue`, `OldValue` and `GlobalReference` are never matchable."
2. **AD-26, after Story 18.5's queued write:** "**Story 18.19's self-queued read** [AMENDED <date>, Story 18.19 spec gate, Rule 20]: `Journal.Record` `LIST` queues itself and is polled like the audit list. Because the vendor's list counts each kept row twice and each row it skips once, the port sends <measured factor> times the rows the read asks. That is exact only when no row is skipped. Its rows and filter sit in the vendor's task row until the port deletes it or AD-37's sweep does."
3. **AD-36, after Story 18.5's paragraphs:** "**A journal record's values are screen-only** (Story 18.19) [AMENDED <date>, Story 18.19 spec gate, Rule 20]: `NewValue`, `OldValue` and `GlobalReference` reach the journal record detail dialog through `GET /journal/record`, under the record browser's pairs and AD-21's eighth case. They never reach a read tool, screen context, the model, the ledger or a log line, because the payload has no schema and can hold patient data or a secret a vendor body journaled (AD-48's reasoning). The record list's eight fields, `GlobalNode` among them, are ordinary row fields. Its paging is the offset criterion. **A criterion may declare `hint`**, one sentence the read tool publishes as that criterion's description in place of its kind's generic one. The screen never shows it."
4. **AD-13, after the `journal-settings` sentence:** "A `journal-record` id is the record's `Address` within the file its list read, kept exactly. It names no write target (Story 18.19) [AMENDED <date>, Story 18.19 spec gate, Rule 20]."
5. **AD-44, after Story 18.18's sentence:** "Story 18.19's Journal records declares the classic record browser `%cspapp.op.utilsysjournal` (Hidden, spelled as `NormalizePage` answers, measured at Story 18.5's Task 0). It has no write tool, so it declares no `CLASSICPAGES` [AMENDED <date>, Story 18.19 spec gate, Rule 20]."
6. **AD-8:** written only if Task 0 halts on a pair beyond the screen's two and the orchestrator rules it.

**Measured at implement** (Task 0 on `ocupilot-b-ci`, 2026-10-03; current file `20261003.318`, 848 listed files; no halt):

- **S0:** 362 snapshot lines, 445 async task rows, monitor state 0. The seed wrote 30 SET records from address 112952296; a row's `GlobalNode` reads `^OcuProbe185(i)` and its `DatabaseName` `/durable/iris/mgr/ocuprobe185d/`.
- **a.** `maxRows` 4, 10, 40 and 2002 kept 2, 5, 20 and 1001 rows: the list halves, factor 2. Every row's keys are exactly the eight columns.
- **b.** The offset is inclusive in both orders. `Address`+1 in order 0 and `Address`−1 in order 1 snap to the next and previous record, so the next-page rule is the highest `Address`+1, or the lowest −1.
- **c.** Each of the six operators (on `GlobalNode`) and each of the eight columns answered 200 and finished: `=` `^OcuProbe185(1)` matched 1 row, `[` `OcuProbe185` the probe rows, `MirrorDatabaseName` `=` `none` none, the rest capped pages.
- **d.** The partial triple sent as is answered 200 with rows of every global: the vendor's 400 is overwritten when it queues, and `[` with an empty value matches every record. No task row was left.
- **e.** Each read's wall clock includes the guard's list read, 1.67 s alone over 848 files: a filtered page 1.7 to 3.0 s; `maxRows` 2002 unfiltered 1.73 s; a filter matching nothing over `pFile` (113 MB) 2.1 to 2.9 s, and over the largest listed file (236 MB) 13.9 s, under `ASYNCTIMEOUT`.
- **f.** The async task rows read 445 before and after every read by the `%All` session: the port deleted each row.
- **g.** A probe record's `GET` answered 200 in 1.66 s with the Code Map's keys: `InTransaction` boolean, `ProcessID` a string, `NewValue` the whole 1,500 characters. A BeginTrans record answered `SetKill` `{}` and `VectorSetKill` `{}`. A non-record address answered 404 `PORT.NOTFOUND`: the `GET` does not snap.
- **h.** (i) With exactly the screen's two pairs, the probe-filtered list answered 0 rows and the unfiltered one 19, all on IRISSYS, one unreadable row spending one count (named limit 1, measured). A probe record's `GET` answered 404 `PORT.NOTFOUND` and an IRISSYS record's 200. The principal left two finished task rows, removed as objects. Its process's halt logged one `%System/%Security/Protect` event: the vendor's work-queue cleanup could not write IRISLOCALDATA, and the queue node was gone afterwards. (ii) Without `%Admin_Operate:USE`: 403 `PORT.ACCESSDENIED` with no vendor work. Without `%DB_IRISSYS:READ`: 500 `INTERNAL` (`<PROTECT>` switching to `%SYS`). (iii) was not run.
- **i.** With auditing on, neither `LIST` nor `GET` recorded a vendor event.
- **Cleanup:** S2 equals S0 but for `messages.log` +4 and `alerts.log` +1 lines (h(ii)'s logged refusal) and the monitor state 0 to 1, cleared to 0 with `$SYSTEM.Monitor.Clear()`. No `OCUPROBE185*` database, resource or principal remains.
- **Set from the record:** `HALVEDROWTYPES` factor 2; the next-page rule above; the dialog's fields are the `GET`'s top-level scalars and `SetKill`'s and `VectorSetKill`'s members.

**Integration ACs:**

- The guard's record rules are consumed by the records page and by `osmgmt.journalrecords.read` (AC1-AC3, `JournalRecords` against the real throwaway).
- The detail route is consumed by the dialog (AC5, the browser spec and `JournalRecordDetail`).
- Journal file details' View records consumes `ScreenArrivals` and opens the records page on its file (AC1, the browser spec).

**Consumes:**

- 18.5's `AdminPort` journal guard (AD-21's eighth case), `JournalError`, `JournalProbe` and Journal file details;
- 16.9's `ScreenArrivals`; 11.11's navigation criteria;
- 6.11's other-screen read (AD-5);
- the audit list's and Task history's server-criteria page and dialog patterns.

**Consumed-by:** 18.12, the agent's tool parity.

**Ledger inbox (Rule 17):** empty (`ledger.sh slice 18-19-journal-record-browser` answered nothing).

**Footprint (Rule 11).** Every contended file is edited add-only (Boundaries). Report these under `footprint_extensions` if Epic 18's `paths_hint` does not name them: `src/OcuPilot/Area/OsMgmt/JournalRecordDetail.cls` (new), `src/OcuPilot/Screen/Registry.cls`, `src/OcuPilot/Screen/Tool/Read.cls`, `ui/tools/screen-mirror.mjs`, `scripts/ci-throwaway.sh`, `ui/angular.json`, `ui/tools/strings.test.mjs` and EXPERIENCE.md.

**For the runner (Rule 5 tier 1, at its origin):** EXPERIENCE.md `:655` lists the server-criteria screens as "Audit database viewer, Task history". It omits Agent ledger and System Explorer's lists, which already use the archetype. This story appends Journal records only, because the line is contended with Epic 19. The runner corrects the rest at origin or routes it.

## Verification

**Setup (slot B):**

- Load with `/tmp/epic-18-d6/load-throwaway.sh` (no restart), never through the MCP loader.
- Every write lands on `ocupilot-b-ci`, on `OCUPROBE185*` objects.
- Run one test class per call. Send the next only once the previous run has landed in `%UnitTest_Result`, and never re-submit after a client timeout.
- Arm each class per call with `docker exec -e OCUPILOT_ALLOW_DATABASE_CONFIG=1 -e OCUPILOT_ALLOW_PRINCIPALS=1`, plus `-e OCUPILOT_ALLOW_JOURNAL=1` for a class that declares it.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expected: 0 failures each, totals checked against `%UnitTest_Result`.
  - The story's own classes: `JournalRecords`, `JournalRecordDetail`, `JournalDescriptor`, `JournalRead`, `CriteriaCorpus`.
  - The rosters: `ReadTool`, `Descriptor`, `SurfaceCoverage`, `EndpointCoverage`, `ScreenRead`, `Navigation`, `Wire`, `WireSecurityRead`, `ToolRoundTrip`, `ToolDispatch`, `ToolEmit`, `ReadSourceCorpus`, `AdminPortAsync`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/journal-records.browser-spec.mjs browser/journals.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 1003.
- `(once, before dev_complete)`, expected green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards, no `OCUPROBE185*` database, resource or principal remains, and the async task row count and the monitor state read as at S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line here:

- AC1: the descriptor's read declares `Journal.File` `LIST` → `JournalRecords`' one-read leg goes red. The page skips the Journals read on a cold open → the page spec's cold-open leg goes red.
- AC2: `HALVEDROWTYPES` is emptied → the cap leg goes red (6 rows, not truncated). Next records sends the last `Address` unchanged → the Next records leg goes red on a repeated row.
- AC3: `JournalRecordRules` drops the operator check → the `AdminPort` injection leg goes red. It drops the empty-value rule → the empty-value leg goes red. It drops the digit check → the offset leg goes red.
- AC4: the route maps `PORT.NOTFOUND` to `PORT.NOTFOUND` → `JournalRecordDetail`'s unreadable leg goes red on its code.
- AC5: the route skips the cut → the 1,500-character leg goes red. The gate call is removed → the gate leg goes red on its zero port calls.
- AC6: the descriptor's read adds a `rowGet` merging `NewValue` → the no-marker leg goes red.
- AC7: `sideBarPosition` 1 with the mirror regenerated → `Navigation` and `navigation.test.mjs` go red. One prompt is removed → `JournalDescriptor` goes red.

Recorded (each reverted byte-identical, the throwaway reloaded from the reverted tree). Each run id was read back from `%UnitTest_Result` on `ocupilot-b-ci`, and each vitest, node and browser leg was re-applied and observed red on the final tree, with the bundle rebuilt and redeployed for each browser leg:

- mutation: the descriptor's read declares `Journal.File` `LIST` → `JournalRecords.TestTheScreenAndItsToolReadTheCapThroughOneRead` red, with five other legs (run 3760)
- mutation: `recordsRead` skips Journals' read when no file is named → page spec "a cold open first issues Journals' read" red, with the dialog leg, whose request names the newest file (vitest)
- mutation: `HALVEDROWTYPES` emptied → `JournalRecords.TestTheScreenAndItsToolReadTheCapThroughOneRead` red, "ten rows of the cap, truncated", with three other legs (run 3759)
- mutation: `nextOffset` answers the highest or lowest address unchanged → page spec "Next records" red alone (vitest), and the browser AC2 leg red after rebuild and redeploy, the eleventh record never shown
- mutation: `JournalRecordRules` drops the comparison check → `JournalRecords.TestInjectionAndShapeAreRefusedBeforeAnyVendorCall` red alone, on the port's injection case (run 3761)
- mutation: `JournalRecordRules` drops the empty-value removal → `JournalRecords.TestAnEmptyValueSendsNoMatchKey` red alone (run 3762)
- mutation: `JournalRecordRules` drops the digit check → `JournalRecords.TestInjectionAndShapeAreRefusedBeforeAnyVendorCall` red alone, on the offset and address cases (run 3763)
- mutation: `JournalRecordDetail.RenderRefusal` renders `PORT.NOTFOUND` as it is → `JournalRecordDetail.TestARecordOnAnUnreadableDatabaseIsRefusedUnreadable` red alone (run 3764)
- mutation: `JournalRecordDetail.Cut` answers its value whole → `JournalRecordDetail.TestARecordAnswersItsFieldsAndValuesCutAtOneThousand` red alone (run 3765)
- mutation: the route's gate call removed → `JournalRecordDetail.TestTheRouteRefusesACallerWithoutThePairsWithZeroPortCalls` red alone, on its refusal and its zero port calls (run 3766)
- mutation: the descriptor's read gains `SetKill.NewValue` and a `rowGet` merging it, and `JOURNALNEWESTTYPES` gains `Journal.Record/GET` so the detail `GET` reads the newest file → `JournalRecords.TestNoRecordValueReachesTheToolOrTheScreenRead` red on its four marker assertions (the screen read and the tool view each carry the value and the markup), with two other legs (run 3989)
- mutation: `HALVEDROWTYPES` emptied → `JournalRecords.TestAnEmptyValueSendsNoMatchKey` red on "asked ... 22 for the cap of 10", with four other legs (run 3987)
- mutation: `AdminPort.AwaitTask` answers 200 at the bound instead of refusing → `JournalRecords.TestAScanPastTheBoundIsRefusedTimeout` red alone (run 3988)
- mutation: `recordsRead` answers an empty ok for a faulted read → page spec "a read past the async bound is the screen's PORT.TIMEOUT fault" red alone (vitest)
- mutation: `loadRecord` reads without waiting for the page to name its file → page spec "a reload on a record's route" red alone (vitest)
- mutation: `JournalRecordDetail.Cut` drops its surrogate step → `JournalRecordDetail.TestARecordAnswersItsFieldsAndValuesCutAtOneThousand` red alone, on the pair's leg (run 3991)
- mutation: the read tool's hinted choice description drops its default sentence → `JournalDescriptor.TestJournalRecordsCriteriaAreThePortsClosedSets` red alone, on the described choice (run 3995)
- mutation: `JournalRecordDetail.HandleGet` logs the record's new value → `JournalRecordDetail.TestTheRouteAnswersOverTheWireLogsNoValueAndNoToolReachesIt` red alone, on its log leg (run 3996)
- mutation: the AC4 principal also holds `%DB_OCUPROBE185D:R` (the read AD-9 never escalates to; the skip itself is the vendor's `HasDBPermission`, so no OcuPilot line can be mutated for it) → `JournalRecords.TestAPrincipalWhoCannotReadADatabaseListsNoneOfItsRows` red alone (run 3997)
- mutation: the page appends the open record to the store's rows → page spec "neither the screen store nor the screen-context payload carries the record's values" red alone (vitest)
- mutation: the page writes the open record's `NewValue` into a row's `GlobalNode` in the store → page spec "the screen-context payload carries none of the record's values" red alone (vitest); appending the whole record to the store's rows leaves it green, because context keeps only the eight declared fields
- mutation: `sideBarPosition` 1, mirror regenerated → `navigation.test.mjs` "a side bar lists only built screens" and "OS management lists ..." red, and `Navigation.TestThePayloadCarriesEveryAreaWithAVerdict` red (run 3769)
- mutation: the third prompt removed → `JournalDescriptor.TestJournalRecordsIsAnUnlistedServerCriteriaList` red alone (run 3768)
- mutation: Journal file details' `onViewRecords` sets no arrival → details spec "View records" red alone (vitest), and the browser AC1 leg red after rebuild and redeploy, on "no cold-open read of Journals was needed"
- mutation: `useArrival` keeps the form's values for criteria an arrival omits → page spec "an arrival for another file" red alone (vitest)
- mutation: the dialog renders values through `[innerHTML]` → browser AC5 leg red after rebuild and redeploy, on "the markup value is shown as text"
- mutation: `JournalProbe.RequireJournaled` demands journal state 4 instead of 3 → `JournalRecordDetail.TestARecordOnAnUnreadableDatabaseIsRefusedUnreadable` red alone (run 4443)
- mutation: `loadRecord` sets no refusal for a faulted read → browser `AC5: a reloaded record route on an address that holds no record shows the route's refusal in the dialog` red alone, after rebuild and redeploy
- mutation: `JournalRecordDetail.RenderRefusal` renders `PORT.NOTFOUND` as it is → that browser leg red alone, on the reason's equality (code review)
- mutation: `JournalRecordRules` removes `initialOffset` whatever it holds → `JournalRecords.TestNextRecordsContinuesInBothOrders` red in both orders, with three other legs (run 4451)
- mutation: the `JOURNALMAXADDRESS` bound removed → `JournalRecords.TestInjectionAndShapeAreRefusedBeforeAnyVendorCall` red on its two cases above the bound (run 4450)
- mutation: the `order` hint's direction clause removed → `JournalRecords.TestTheToolInReverseOrderKeepsTheNewestRowsUnderTheContextCap` red alone (run 4457)
- mutation: `JournalRecordDetail.HandleGet` sends no `Cache-Control` → `JournalRecordDetail.TestTheRouteAnswersOverTheWireLogsNoValueAndNoToolReachesIt` red alone (run 4452)
- mutation: the cold open sets the newest file whatever the search names by then → page spec "an arrival while a cold open waits for Journals' read" red alone (vitest)
- (QA) `ui/browser/journal-records.browser-spec.mjs` gained the refusal leg; `src/OcuPilot/Test/JournalProbe.cls` gained `RequireJournaled`, called by `SetReadable`

Final tree, `ocupilot-b-ci` (loaded with `load-throwaway.sh`, 0 compile errors), after the review patches: the full ObjectScript sweep (runs 3998-4422, read back from `%UnitTest_Result`) ran 425 classes and 3,490 tests, 3,488 passed. The story's classes: `JournalRecords` 9/9 (run 4149), `JournalRecordDetail` 5/5 (4148), `JournalDescriptor` 13/13 (4145), `JournalRead` 6/6 (4147), `ReadTool` 28/28 (4287), `Descriptor` 60/60 (4080), `SurfaceCoverage` 4/4 (4334), `EndpointCoverage` 2/2 (4099), `ScreenRead` 30/30 (4313), `Navigation` 14/14 (4208), `Wire` 20/20 (4414), `ToolRoundTrip` 2/2 (4361), `ToolDispatch` 18/18 (4357), `ToolEmit` 11/11 (4359), `AdminPortAsync` 6/6 (4002). Two failures, both in methods this story does not touch, from the throwaway's age (inference; both pass in CI): `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` (Task history past 1,000 rows, run 4417, red since run 3130) and `Retention.TestAnEntryAgesByItsOwnDefinitionAndTheLedgerByTheLongest` ("this instance holds no expired row another suite created", run 4299). `npm test`: tools 1780/1780, components 2226/2226; `npm run build` passes; initial bundle 2,587,710 bytes (`maximumWarning` 2588kB); rebuilt bundle redeployed, then `journal-records.browser-spec.mjs` 3/3 and `journals.browser-spec.mjs` 5/5; `smoke.sh` 50/50; `check-objectscript.py` 0 problems; `lint-docs.sh` clean; EXPERIENCE.md 1003 lines. End state: no `OCUPROBE185*` database, resource, directory, namespace or principal, and no readable probe global; journal settings as found, journaling in `/durable/iris/mgr/journal/`; 0 agent definitions, 0 policy rows; 442 async task rows (445 at S0; none left by this story's classes); monitor 2, cleared to 0 with `$SYSTEM.Monitor.Clear()`.

Code review, 2026-10-03, `ocupilot-b-ci` loaded with `load-throwaway.sh` (0 compile errors), each mutation reverted byte-identical and reloaded: `JournalRecords` 10/10 (run 4458), `JournalRecordDetail` 5/5 (4454), `JournalDescriptor` 13/13 (4456), `JournalRead` 6/6 (4449), `Descriptor` 60/60 (4448); `npm run test:tools` 1780/1780, `npm run test:components` 2232/2232; `npm run build` passes under `maximumWarning` 2611kB; rebuilt bundle redeployed, then `journal-records.browser-spec.mjs` 4/4 and `journals.browser-spec.mjs` 5/5; `check-objectscript.py` 0 problems. End state: no `OCUPROBE185*` database, resource or principal; journaling in `/durable/iris/mgr/journal/`, settings as found; 442 async task rows; monitor cleared to 0.

## Auto Run Result

Status: done
Blocking condition: none

**Inherited and re-verified.** The previous implement pass died at the account limit; its tree was committed as `b174ebc5`. This pass read that diff against every Task, Boundary, matrix row and AC and found the implementation complete. It confirmed every recorded mutation run (3759-3769) in `%UnitTest_Result`, corrected three of those lines to what failed, and re-demonstrated the vitest, node and browser mutation legs on the final tree. Task 0 was not re-run.

**Added or corrected in this pass:**

- `Test/ReadTool.cls`, `Test/Descriptor.cls`, `Test/JournalProbe.cls`: restored a word and a space the WIP had deleted, so the contended edits are add-only.
- `Area/OsMgmt/JournalRecordDetail.cls`: `Cut` keeps one character fewer where it would keep half a surrogate pair (was the one deferred item).
- `journal-records.page.ts`: a dialog opened before the page names its file (a reload on a record's route) waits for the cold open's file, instead of asking for a record of no file.
- Matrix coverage: `JournalRecords.TestAScanPastTheBoundIsRefusedTimeout` with a page-spec leg for the scan-past-the-bound row; the vendor is asked 22 rows for cap 10 (`JournalCountPort.SentValue`).
- Review patches: the hinted descriptions pinned; AC4 positives through a readable record (`JournalProbe.SetReadable`); the `messages.log` window covers the list and tool reads and proves the file is read; the newest-file read is non-empty; the store is pinned value-free.
- AC6's mutation re-demonstrated so the marker assertions themselves go red (run 3989).
- Bundle re-measured at 2,587,710 bytes; the history row updated, `maximumWarning` unchanged at 2588kB.

**Review:** 21 findings (medium 7, low 2, false 12). 5 entries patched (7 medium findings grouped into them, plus 1 low), 0 deferred. Rejected: 1 low (the hint branch's datetime wording, which no criterion uses) and 12 false, each with its reason in the Review Triage Log.

**Verification:** the Final tree line above. Full sweep 3,488 of 3,490 passed; both failures are in untouched methods and come from the throwaway's age (inference). Browser specs ran on the rebuilt, redeployed bundle. Smoke passed 50/50.

**Follow-up review: recommended.** Five medium entries were patched. Unverified risk: the AC4 readable-record legs write a journaled global into the install namespace's routines database. They assume that database is journaled on a fresh CI instance, which was measured only on this throwaway.

**Residual risks:** named limits 1-5 stand. The 30 s scan bound is shown only through a lowered bound, because the longest measured scan is 13.9 s.
