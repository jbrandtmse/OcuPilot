---
title: 'Story 18.4: The deferred disk operations'
type: 'feature'
created: '2026-09-29'
status: 'in-progress'
baseline_revision: '5b1bde51dc7fc45238cb45b6a5cc006c6834a9aa'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: 'Vendor defect candidates in Database.Actions on 2026.2: mount without %Admin_Secure:USE answers 500 #356 (resource unknown) while the audit row says #921; a queued action refused for privilege answers 202 and fails only in the task; modify-size silently no-ops a shrink and silently clamps above MaxSize (logging a severity-2 alert); an integrity check on a non-database directory reports both "No Errors were found." and "Errors found in 1 globals"; a NewVolumeDirectory naming another database''s directory or volume directory is refused 500 (#576, #575), not 4xx; deleting an AsyncTaskSysBackground row as an object leaves its %SYS.BackgroundTask row (the trigger is SQL-only)'
    evidence: 'Measured on ocupilot-b-ci 2026-09-29 by this plan''s probe (Design Notes, Measured). OcuPilot guards each on its own side: pairs refused before any port call, size and target rules before any vendor call, the volume-directory rule before the PUT. Candidate IRIS defect report; human-owned.'
    severity: 'low'
    location: 'vendor %Api.Admin.Endpoints.Database.Actions'
  - summary: >-
      Decision for the runner or owner: osmgmt.databasedetails.dismount declares %Admin_Manage:USE beyond Database details' pairs, against the intent's "dismount and truncate: Database details' pairs only".
    evidence: |-
      PROHIBITED.OCUPILOTDATABASE's dismount arm reads the install namespace and the database configurations through the port as the caller (Namespace.Namespace GET, Database.ConfigCRUD LIST), whose ResourcesOR is %Admin_Manage alone (measured on ocupilot-b-ci), and a failed read refuses; without the pair an Operate-only holder is refused PROHIBITED after a port call on every dismount. Declared under AD-8's endpoint clause (OWNSETRESOURCE); AD-8's 18.4 paragraph and the intent's pair line need the runner's amendment, or a Manage-free own-set read (an AD-27 named case) if the owner wants Operate-only dismounts.
    location: >-
      src/OcuPilot/Screen/Tool/DatabaseDismount.cls
    severity: medium
  - summary: >-
      The Integrity log's error branch is unverified: no test renders the report of a check that found errors through the real Display^Integrity capture.
    evidence: |-
      Every live leg runs a clean check, and the fixture replaces IntegrityReport wholesale; that an error line begins "****" is taken from the fixture (inference). Settled by a check over a database with a deliberately damaged block, or a hand-built vendor output global, on a throwaway.
    location: >-
      src/OcuPilot/Port/LogSourcePort.cls IntegrityReport
    severity: medium (unverified)
  - summary: >-
      Canceling a compact through %SYS.BackgroundTask kills the admin API worker running it, and that caller's AsyncTask row then stays Running (observed on ocupilot-b-ci).
    evidence: |-
      BackgroundTaskPort controls a Database row (a task no portal or own admin row holds, such as another user's admin API compact) through %SYS.BackgroundTask, as AD-27's 18.4 case states, so its cancel leaves that user's task row Running until someone deletes it; DatabaseActionProbe.RemoveAll cancels the same way, so a test failing between its pause and its settle can leave one. Candidate vendor defect; the product path for an own admin row cancels through AsyncResult.
    location: >-
      src/OcuPilot/Port/BackgroundTaskPort.cls Control
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot shows databases (Epic 6) and configures them (18.3), but cannot mount, dismount, truncate, compact, defragment, grow or add a volume to one, or check its integrity. The classic portal is still the only way (catalog rows OS-16 to OS-22 and SA-18's save-and-expand). The admin API carries each operation, but six of the eight queue on the instance, and the vendor guards none of OcuPilot's own or the system databases (measured).

**Approach:**

- Database details (Epic 6, keyed by directory) gains Mount, Dismount, Truncate, Compact and Defragment, the classic Database details page's operations.
- The Local databases editor (18.3) gains a size grow on Save and Add a volume, the classic Database and Database volumes pages' operations.
- Databases gains Check integrity, a three-step flow (databases, globals, report), and an Integrity log. Together they replace `Dialog.Integ`, `Dialog.IntegOutput`, `Dialog.IntegLog` and `Dialog.IntegLogContent`.
- Every operation is one derived write tool both callers reach (AD-53, AD-55), through `DatabasePort`'s new `Database.Actions` branch, which builds each vendor body (AD-51).
- Each queued operation shows a running line, then "finished" or "Still running on the instance. It finishes in the background." (orchestrator ruling: progress is a running line).
- The kernel refuses dismounting OcuPilot's and the system databases (AD-10).
- All eight write keys join the governance baseline disabled.
- Inbox: admin-API compacts and defragments are listed on Database details (DW-1821); a new volume directory that is another database's directory or volume directory is refused (DW-1791).

## Boundaries & Constraints

**Always:**

- **Read once (AD-26).** A finished async task is read exactly once, by the port's in-request await, and its row deleted (`AdminPort.ForgetTask`). No client or screen reads `async-result`, so no two views poll one task. Past the port's bound a queued write answers started (HTTP 202, `continues`), never `PORT.TIMEOUT`, and its read-back is `unchecked` (`running`).
- **Pairs (AD-8, AD-29), declared per tool and refused by name before any port call** (measured, Design Notes):
  - mount: Database details' `%Admin_Operate:USE`, `%DB_IRISSYS:READ`, plus `%Admin_Secure:USE`;
  - dismount: Database details' pairs plus `%Admin_Manage:USE`, which the self-protection check's read of the protected set needs (DW-1847, decided by=merge_gate 2026-09-29; an Operate-only dismount is DW-1850, routed to range-end-cleanup);
  - truncate: Database details' pairs only;
  - compact and defragment: plus `%DB_IRISSYS:WRITE`, and `%DB_<resource>:READ` for the target's `ResourceName`, read through the port;
  - integrity: the Databases list's `%Admin_Manage:USE`, `%DB_IRISSYS:READ`, plus `%Admin_Operate:USE` (`ResourcesOR`, and the poll) and `%DB_IRISSYS:WRITE`;
  - grow: Local databases' `%Admin_Manage:USE`, `%DB_IRISSYS:READ`, plus `%Admin_Operate:USE` (the poll);
  - expand: the same set (the vendor answers #921 without `%Admin_Operate:USE`).
  - Each tool then unions `Gate.WithClassicPages` over its `CLASSICPAGES` (AD-44).
- **No caller path (AD-21).** A tool names a database by an id the instance lists, never a path. The fresh read (`STATE`) answers 404 for a directory the instance does not configure as a database. Vendor bodies are built by the port from declared, non-secret arguments. An integrity check never sends an empty `Databases` array: the vendor reads that as "every database".
- **Every predicate over the effect (AD-10, AD-53).** `PROHIBITED.OCUPILOTDATABASE` also refuses a dismount of any database whose directory is an own database's directory, on both callers, inside the confirm's transition.
- **Governance:** `osmgmt.databasedetails.{mount,dismount,truncate,compact,defragment}`, `osmgmt.databases.integrity` and `osmgmt.localdatabases.{grow,expand}` join `Baseline.cls` `false`. The screen's caller is never gated by them (AD-22, AD-53).
- **Contended files are add-only.** EXPERIENCE.md is edited in place and stays 993 lines. `screens.generated.ts` is regenerated, never hand-merged.

**Never:**

- No cluster or mirror catch-up mount options, no `MaxProcesses` or `PartialCheck`, and no stop-after-error: the admin API has none, and none is exposed.
- No free-space progress figure on screen. The running line is the ruling.
- No client polling of `async-result`, and no read of a task row outside the port.
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses. No direct `SYS.Database` or `Config.Databases` write in product code; test-only `%SYS` seeding is allowed.
- No global-name picker (no globals read exists; the step takes names).
- No change to the Databases list's row cells: its five-cell pin stands.
- No spine edit: the runner writes the amendments.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Dismount | Probe DB mounted; Dismount, then confirm the warning | `POST /database-dir/dismount?dir=`, no body; the page's properties re-read Dismounted; a `DatabaseChange` audit row | none |
| Mount | Probe DB dismounted; Mount with "Mount read-only" checked | Body `{"ReadOnly":true}`; the database reads mounted read-only. Unchecked sends `{}` | none |
| Wrong state | Mount a mounted DB; dismount, truncate, compact or defragment a dismounted one; truncate, compact or defragment a read-only-mounted one | Refused at the mint, the confirm and the screen action, before any vendor call | 409 `DATABASE.MOUNTED`, `DATABASE.DISMOUNTED`, `DATABASE.READONLY` |
| Truncate | `TargetSize` 0, then 60 on an 80 MB DB | Body `{"TargetSize":n}`; queued; size reads 60 after the change event | none |
| Truncate target | `TargetSize` at or above the current size, negative, or not whole | Refused on `TargetSize`, no vendor call | `DATABASE.TARGETSIZE.SHAPE` |
| Compact | `TargetFreeSpace` 30 with 41 MB free | Body `{"TargetFreeSpace":30}`; queued; the running line, then finished | none |
| Compact target | Above the database's free space (fresh read) | Refused on `TargetFreeSpace` at the mint and again at the write | `DATABASE.TARGETFREE.SHAPE` |
| Defragment | Probe DB mounted | No body; queued; the running line, then finished | none |
| Started | Any queued operation still running at the port's bound (recording port answers `PORT.TIMEOUT`) | 202, `continues` true; the line reads "Still running on the instance. It finishes in the background."; read-back `unchecked` `running`; the task row is not read | none |
| Grow | Editor Size 120 on a 95 MB DB, Save | Group `size` sends `POST /database-dir/modify-size?dir=` `{"Size":120}` after the other groups; Size reads 120 | none |
| Grow refused | Size at or below the current size, or above a non-zero `MaxSize` | Refused on `Size` before any vendor call | `DATABASE.GROWSIZE.SHAPE` |
| Add a volume | Editor saved, Add a volume, Initial size 5 | `POST /database-dir/expand-volume?dir=` `{"InitialSize":5}`; the volume files section re-reads and lists the new volume in the configured new volume directory | `DATABASE.INITIALSIZE.SHAPE` for 0, a fraction, or above a non-zero threshold |
| Volume directory collision (DW-1791) | The file update's `volumeRoot`/`volumePath` naming another database's directory, or another database's volume directory | Refused on `volumePath` at the mint, the confirm and the Save; no vendor call; the vendor's #576/#575 also map there | `DATABASE.DIRECTORY.INUSE` |
| Integrity, one DB | Check integrity: probe DB A; Globals `OcuProbe184A` | Body `{"Databases":[{"Directory":A,"Globals":["OcuProbe184A"]}]}`; the Report step shows the check's report from the Integrity log's read | none |
| Integrity, set | A and B, no globals | Target id `["<A>","<B>"]` (canonical: deduplicated, sorted); body carries both directories | `DATABASE.GLOBALS.ONEDATABASE` if globals are given for two |
| Integrity refused | A dismounted member; no member; a bad global name | Refused before any vendor call | `DATABASE.DISMOUNTED` (naming it), `DATABASE.INTEGRITY.DATABASES`, `DATABASE.GLOBALS.SHAPE` |
| Integrity log | After two checks | Newest check first in the check select, labeled by start time and state; its report lines shown; a running check reads "This check is still running." | none |
| Protected dismount | Dismount of `OCUPILOT`'s, the install namespace's routines, or `IRISSYS`'s directory | Refused on both callers; the dialog states the reason when it opens | `PROHIBITED.OCUPILOTDATABASE` |
| Missing pair | Each declared extra pair missing, per tool | 403 naming it; zero port calls | `AUTH.NOPRIVILEGE` |
| Governance | Baseline keys; the agent's mint of each tool | Refused, while the screen's action proceeds | `GOVERNANCE.DISABLED` |
| Admin-API compact (DW-1821) | A paused compact started through `osmgmt.databasedetails.compact` | Database details' Background tasks section lists it for its directory; Background tasks lists it once | none |

</intent-contract>

## Code Map

**Measured vendor** (`ocupilot-b-ci`; payloads, pairs and audit events in Design Notes). `%Api.Admin.Endpoints.Database.Actions` is hidden; the probe's exports are in `/private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-18-recover/probe-18-4/` (re-export from the throwaway if gone).

- Types, all `POST /v2/database-dir/<op>`: `MOUNT`, `DISMOUNT`, `TRUNCATE`, `COMPACT`, `DEFRAGMENT`, `EXPANDVOL` (`expand-volume`), `MODIFYSIZE` (`modify-size`), `INTEGRITYCHECK`. Routes: `Port/AdminRoutes.cls:84-91`.
- Query: every type but `INTEGRITYCHECK` takes `dir`. `ResourcesOR`: `%Admin_Manage` for `EXPANDVOL` and `MODIFYSIZE`, `%Admin_Operate` for the rest.
- `ShouldRunAsync()` is 1 for `TRUNCATE`, `MODIFYSIZE` and `EXPANDVOL`. `COMPACT`, `DEFRAGMENT` and `INTEGRITYCHECK` queue themselves in `Run()`. `MOUNT` and `DISMOUNT` are synchronous.
- `EXPANDVOL` creates its volume in the database's configured `NewVolumeDirectory`; the body carries no directory.
- Inventory row: `Test/AdminInventory.cls:43` (`queues="1" mutating="0"`, no template).
- Integrity output: `SYS.BackgroundIntegrity` (`[Hidden]`, extends `%SYS.BackgroundTask`). Its `Query ListIntegrityTasks()` is public (`ID, StartTime, RunningState, HasEnded, FinalStatus, DatabaseList, ...`). `GetOutputGlobal()` names `^SYS.BackgroundIntegrityResults(<id>, ...)`. The admin API's own `Database.AsyncTaskIntegrity.CaptureDisplay` renders the report with `Display^Integrity(bgTask.GetOutputGlobal(), flags, dirsum)`. No file is written, and the admin API has no read of a past check.
- `%SYS.BackgroundTask:DatabaseList` (`irissys/%SYS/BackgroundTask.cls:911-920`) lists every compact and defragment; its `Database` is upper-cased. The vendor task row `%Api.Admin.Endpoints.Database.AsyncTaskSysBackground` stores `SysBGTaskId` (property, line 12 of the export).
- Classic pages, spelled exactly:
  - `%CSP.UI.Portal.Dialog.DBActions` (mount; `%Admin_Operate`);
  - `%CSP.UI.Portal.DatabaseDetails` (dismount inline);
  - `%CSP.UI.Portal.Background.Dialog.DatabaseTruncate`, `.DatabaseCompact`, `.DatabaseDefragment`;
  - `%CSP.UI.Portal.Dialog.ExpandVolume`, `%CSP.UI.Portal.DatabaseVolumes`, `%CSP.UI.Portal.Database` (size);
  - `%CSP.UI.Portal.Dialog.Integ`, `%CSP.UI.Portal.Dialog.IntegOutput`, `%CSP.UI.Portal.Dialog.IntegLog`, `%CSP.UI.Portal.Dialog.IntegLogContent`;
  - `%CSP.UI.Portal.OpDatabases` (the integrity buttons).

**Ports:**

- `Port/AdminPort.cls`:
  - `MUTATINGTYPES` :341, `BODYLESSTYPES` :357, `QUEUEDWRITES` :556 (doc :545-555), `PROPERTYFAULTS` :2567;
  - `InvokeLocated` :832, whose 202 + `Location` branch at :923 has no queued-write check;
  - `PollTask` :1242, `ForgetTask` :1260, `SweepOwnTasks` :1317, `AsyncTimeout` :1347 (`ASYNCTIMEOUT` 30 :640);
  - `IsQueuedWrite` :2165, `Sequence` :2299 (queued refusal :2346-2349), `Snippet` :2752.
  - `Test/PortFixture.cls:21` copies `MUTATINGTYPES`. `Test/AdminPortAsync.cls` :51 and :86 pin the refusal and the exact `QUEUEDWRITES`.
- Started conversion model: `AuditPort.Invoke` :96-101 and `NamespacePort.Invoke` :108-114 (`IsQueuedWrite` plus `PORT.TIMEOUT` becomes `STARTEDHTTP` 202). Port-built bodies: `AuditPort.Body` :347, `NamespacePort.CopyBody` :181. Port-composed read type: `ProcessPort` `RECIPIENTS`.
- `Port/DatabasePort.cls`:
  - `Call` :92 calls `AdminPort.Invoke` by class name, so a test port overrides `Call`, not `AsyncTimeout`;
  - `Invoke` :104, whose fallthrough at :146 is where the new branch goes;
  - `DirectoryOf` :234, `HoldsDatabase` :257, `SameDirectory` :322, `Refused` :344, `Snippet` :395.
- `Port/BackgroundTaskPort.cls` (extends `AdminPort`): `PAIRS` :65, `Rows` :167, `Listed` :262, `Control` :277, `PortalRows` :334, `WithDatabases` :377, `TaskDatabases` :394, `KeepRunning` :433, `AdminRows` :448, `PortalControl` :487, `Snippet` :527.
- `Port/LogSourcePort.cls`: `SOURCES` :86, `PairsFor` :437, `FileFor` :577, `Page` :664 (`pFile`), `Resolve` :2862, `RotatedName` :2887, `Files` :2926.
- `Port/PathPort.cls`: `Resolve` :266. `DatabaseDirectories` appends every database's volume directories (18.3), and is reused for DW-1791.

**Tools and screens:**

- `Screen/Tool/Write.cls`: `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CLASSICPAGES` :124, `CHANGEACTION` :134, `SCREENACTIONS` :167, `READANSWERS` :180, `SCREENVALUES` :217, `PortQuery` :440, `ArgumentProblem` :809.
- Pair helpers: `Base.PrivilegePairs` :92, `ArgumentPairs` :123; `Gate.WithClassicPages` :131.
- Models:
  - `AuditCopy.cls` / `AuditPurge.cls`: action writes, `POLLRESOURCE`/`WRITERESOURCE`, `Consequence`;
  - `NamespaceCopyMappings.cls`: queued, `CLASSICPAGES`;
  - `LocalDatabaseUpdateMount.cls`: `ArgumentPairs` from a stored value read through the port;
  - `ProcessBroadcast.cls`: a set target.
  - `Test/ToolEmit.cls:158` expects `POLLRESOURCE`/`WRITERESOURCE` parameter names.
- Descriptors (`Screen/Descriptor/`):
  - `DatabaseDetails.cls`: pairs :80, `rowActions` :88, id `composite [Directory]`;
  - `DatabaseList.cls`: `primaryAction` :71, archetype `list (two views)`, pairs Manage + IRISSYS READ;
  - `LocalDatabaseList.cls`: `secondaryEntityTypes` :35, `rowActions` :40;
  - `OAuthServerTab.cls`: a detail screen whose own tools name it;
  - `LogSystemMonitorViewer.cls` / `LogMessageViewer.cls`: the log-viewer model (read `{port: logsource, endpoint, type: LIST}`, fields `time, severity, text`).
- `Screen/Registry.cls`: `SELFPROTECTIONRULES` :2561 (unchanged), `MultiSelectProblem` :3489 (not used).
- `Kernel/EntityRef.cls:59` `IDRULES` (`database` has no rule; `process:integerset` is the set precedent).
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250 (28 types, no `database`), `OCUPILOTDATABASE` :374, `REASON` :379, `SYSTEMDATABASES` :383, `Prohibits` :937 (covered check :944, dispatch chain :948 and :1031-1034), `Database` :1857, `OwnDatabaseNames` :1917, `OwnDatabaseDirectories` :1937, `SkippedFields` :3587.
- `Kernel/Governance/Baseline.cls`: `osmgmt.databases*` keys go between :20 and :21.
- `Api/DatabaseError.cls`: codes :13-82, `ViolationCodes` :85, `ReasonFor` :92. `Error.cls` is at the compiler's parameter limit, so new codes go here.
- `Api/Router.cls`: `/database/check` :128, `/database/:id` :129, `/screens/:screen/action` :131, `/logs/messages/files` :139.
- `Api/ScreenAction.cls`: :338-340, :356 (`continues`). `Kernel/Proposal/Confirm.cls`: :471-485. `Kernel/Proposal/ReadBack.cls`: `Running()` :198.
- `Area/OsMgmt/DatabaseRules.cls`: `DirectoryViolations` :186, `HandleCheck` :289, `StepFields` :330.
- `Area/OsMgmt/DatabaseSave.cls`: `GROUPS` :28, `Update` :202.

**Client** (`ui/src/app/`):

- `areas/os-management/database-details.page.ts`: sections :150-242, `loadTasks` :398, `comparableDirectory` :65. It has no actions, no dialog host and no refusal banner today.
  - Model: `process-details.page.ts` (`ScreenActionHandler` :140, `selectShown` :190-228, dialogs :111-121, banner :72-77).
  - `shell/command-bar.ts:415-445` draws a screen's `rowActions` for the selection.
- `shell/screen-action-handler.ts`:
  - tables `SCREEN_ACTION_DESCRIPTORS`, `UNDRAWN_ACTIONS`, `VALUE_FLAGS`, `WARNING_CONSEQUENCES`, `ACTION_ADDRESS`, `DESTRUCTIVE_ACTIONS`;
  - methods `startFor`, `send` / `sendFor`, `continued()`.
  - `shell/warning-dialog.ts` draws a verb, a consequence and Proceed (button-primary). `shell/screen-action-dialogs.ts` hosts it.
- Value-dialog precedents: `areas/security/audit-purge-dialog.ts` (a number field), `shell/broadcast-dialog.ts`, `shell/typed-name-dialog.ts` (one flag).
- Running-line models:
  - `areas/os-management/namespace-list.page.ts:62,125,154-174`;
  - `areas/security/auditing-config.page.ts:172,533-541,596-622`;
  - `core/strings.ts` `auditDatabaseStillRunning` :2658.
- Wizard models: `shell/form-stepper.ts`, `areas/os-management/database-wizard.page.ts` and `.store.ts` (`next()` :366 posts `/database/check`).
- Editor: `areas/os-management/database-editor.page.ts` / `.store.ts` (groups, `setVolumeLocation`, sticky Save).
- Log viewer: `areas/logs/log-viewer.page.ts` (the file select :149-160, Raw :175-180) and `log-viewer.store.ts:30-47` (`SOURCES`: `tailPath`, `filesPath`).
- Wiring: `shell/screen-outlet.ts` (`DESCRIPTOR_PAGES` :118-157); `app.ts` (sign-out resets :592-627); `areas/os-management/database-actions.ts` (a primary action that navigates to a wizard).
- `core/strings.ts` reuse: `databaseInitialSize` :3636, `databaseListLabel` :1094, `processColumnGlobals` 'Globals' :407, `taskHistoryColumnStatus` :899, `lockColumnDirectory` :1086, `taskStartTime` :2136. Values are unique (`ui/tools/strings.test.mjs:743`).

**EXPERIENCE.md** (993 lines): :98 Database details, :173 Dialogs, :377 Databases literals, :481 kernel refusals, :516 the still-running sentence, :617 `confirm-dialog`, :626 `stepper`, :627 `log-viewer`.

**Rosters** (re-derive each from its class's red):

- ObjectScript:
  - `ReadTool:93` (159 tools, 98 writes), `Navigation:340` (20 OS management screens), `Descriptor:67` (`ReadShapes` 55) and :1710 (39 types);
  - `SurfaceCoverage`, `EndpointCoverage` (138), `PortGate:28` (20 ports, unchanged);
  - `MappingDescriptor:16` `CLASSICROSTER` (15);
  - `Prohibited:218` (28 types), :603 (`UncoveredWriteTools` empty), :686 (23 codes, unchanged);
  - `AuditingUpdate:505`, `GovernanceBaseline:11`, `Governance:17-23,104`, `ToolDispatch:151`;
  - `ToolRoundTrip:44` (`REFUSEEMPTY`), `ToolWrite:1253,1323,1325`, `DraftRegistry`, `AdminPortAsync:86`.
- Client:
  - `ui/tools/navigation.test.mjs:133-237` (83 built);
  - `navigation-wire.test.mjs:91-236` and `shell/rail-wire.spec.ts:88-235` (19 OS management entries each);
  - `ui/tools/self-protection.test.mjs:253-288` (the refusal sentence, verbatim).
- CI: `scripts/ci-throwaway.sh` `OCUPILOT_ALLOW_DATABASE_CONFIG` block :377-386 and PRINCIPALS block :193-248; `ui/tools/ci.test.mjs:1828-1909`.

**Test models:**

- `Test/DatabaseWriteProbe.cls` (`OCUPROBE183` prefix; `Add` :74, `Mounted` :211, `RemoveAll` :371);
- `DatabaseRecordPort` (`Call` :20, `FailOn` :60), `DatabaseAcceptPort`, `DatabaseProhibitedFixture`, `DatabaseActionFixture`, `GovernanceFixture`;
- `NamespaceStartedPort` / `NamespaceStartedAction` (started legs);
- `BackgroundSeed.cls` (`PausedCompact` :113);
- `ui/browser/local-databases.browser-spec.mjs` (`irisSys` :117, `seedIris` :136, `cleanupLines` :166);
- `background-tasks.browser-spec.mjs` (`seedPausedCompact` :44).

## Tasks & Acceptance

**Task 0: the implement stage's first task, before any code.** Run it on `ocupilot-b-ci` only, on `OCUPROBE184*` objects it creates and removes. Record the results in Design Notes › Measured at implement.

1. As a principal holding only `%Admin_Operate:USE` and `%DB_IRISSYS:READ`: run `SYS.BackgroundIntegrity:ListIntegrityTasks` in `%SYS`, and capture `Display^Integrity(<task>.GetOutputGlobal(), 1, 0)` then `(…, 0, 1)` for a finished probe check, as `Database.AsyncTaskIntegrity.CaptureDisplay` does.
   - Record the pair set actually needed.
   - Record whether the task row, its `^SYS.BackgroundIntegrityResults` node count or any global outside `^IRIS.Temp*` scratch keyed by the process changes.
2. `EXPANDVOL` on a probe database whose `NewVolumeDirectory` is empty: where the volume file lands.
3. `Database.SysCRUD` `GET` and `INFO` for a probe database: which fields carry mounted, mounted read-only, size, maximum size, free space, resource, new volume directory and threshold. Name the `STATE` read's sources from them.
4. **HALT** `blocked`, blocking condition `observation contradicts the plan: <what>`, with nothing built, if:
   - item 1 needs any pair beyond those two, or changes stored state;
   - item 2 creates a file outside the database's own or new volume directory.

**Execution, Part A: the port, the tools, the kernel (AC1-AC5, AC8, AC9):**

- `src/OcuPilot/Port/AdminPort.cls` and `Test/PortFixture.cls:21`:
  - Add the eight `Database.Actions/<TYPE>` pairs to `MUTATINGTYPES`, each with its measured fact.
  - Add `DISMOUNT` and `DEFRAGMENT` to `BODYLESSTYPES`.
  - Append `Database.Actions/TRUNCATE`, `/COMPACT`, `/DEFRAGMENT`, `/EXPANDVOL`, `/MODIFYSIZE` and `/INTEGRITYCHECK` to `QUEUEDWRITES`. No body carries a secret.
  - Add `SELFQUEUEDTYPES` = `Database.Actions/COMPACT,Database.Actions/DEFRAGMENT,Database.Actions/INTEGRITYCHECK` (measured). `Sequence` refuses a mutating request of such a type that is not in `QUEUEDWRITES` before `Run()`, as it does for `ShouldRunAsync()`, so AD-26's "every other queued write is refused" holds for both entries.
- `src/OcuPilot/Port/DatabasePort.cls`, a new `Database.Actions` branch before :146. `Snippet` mirrors every branch (AD-59).
  - **`STATE`**, a port-composed read type (the `RECIPIENTS` model). With `dir`, or `name` resolved through `DirectoryOf`, it answers one object `{Directory, Mounted, ReadOnly, Size, MaxSize, FreeSpace, ResourceName, NewVolumeDirectory, NewVolumeThreshold}`, drawn from `Database.SysCRUD` `GET`/`INFO` per Task 0 item 3. A directory the instance does not configure is 404.
  - For an integrity set (`dir` beginning `[`), `STATE` answers `{Directory: <canonical set>, Dismounted: <members not mounted, comma-joined, or "">}`, one `GET` per member.
  - **Writes.** A caller body is refused (500 `INTERNAL`, the `AuditPort` rule). The port builds the vendor body from the tool's declared arguments in the query:
    - `MOUNT`: `{"ReadOnly":true}` when asked, else `{}`;
    - `TRUNCATE`: `{TargetSize}`; `COMPACT`: `{TargetFreeSpace}`; `EXPANDVOL`: `{InitialSize}`; `MODIFYSIZE`: `{Size}`;
    - `INTEGRITYCHECK`: `{Databases:[{Directory, Globals?}]}` from the canonical set, with no `dir`. An empty set is refused before any call.
    - `DISMOUNT` and `DEFRAGMENT` send no body.
    - `name` resolves to `dir` for `MODIFYSIZE` and `EXPANDVOL`.
  - **Faults and started.** Vendor 409 #19 maps to 409 `DATABASE.MOUNTED`. An `IsQueuedWrite` pair whose call answers `PORT.TIMEOUT` answers `$$$OK`, HTTP 202, with an empty result (the `NamespacePort` conversion).
- `src/OcuPilot/Api/DatabaseError.cls`, add-only codes and sentences:
  - `DATABASE.MOUNTED` (409) "This database is already mounted."
  - `DATABASE.DISMOUNTED` (409) "This database is dismounted. Mount it first."
  - `DATABASE.READONLY` (409) "This database is mounted read-only, so its file cannot be changed."
  - `DATABASE.TARGETSIZE.SHAPE` "Enter 0, or a whole number of megabytes smaller than the current size."
  - `DATABASE.TARGETFREE.SHAPE` "Enter a whole number of megabytes, from 0 to the database's free space."
  - `DATABASE.GROWSIZE.SHAPE` "Enter a whole number of megabytes larger than the current size and no larger than the maximum size."
  - `DATABASE.INITIALSIZE.SHAPE` "Enter a whole number of megabytes, 1 or more, and no larger than the new volume threshold when one is set."
  - `DATABASE.INTEGRITY.DATABASES` "Choose at least one database to check."
  - `DATABASE.GLOBALS.SHAPE` "Enter global names, one per line, each starting with a letter or %."
  - `DATABASE.GLOBALS.ONEDATABASE` "Globals can be chosen only when one database is checked."
  - `PROPERTYFAULTS` gains `Database.SysCRUD:575:@volumePath` and `:576:@volumePath` = `DATABASE.DIRECTORY.INUSE` (DW-1791, measured).
- `src/OcuPilot/Area/OsMgmt/DatabaseRules.cls`:
  - Rules for `TargetSize`, `TargetFreeSpace`, `Size`, `InitialSize` and `Globals` (names matching `^%?[A-Za-z][A-Za-z0-9.]{0,30}$`, no `^`, globals only with one database), each against the `STATE` read.
  - `HandleCheck` gains step `globals`.
  - `DirectoryViolations` also refuses a new volume directory that holds an `IRIS.DAT`, or that equals (`SameDirectory`) another database's directory or volume directory from `PathPort.DatabaseDirectories`, other than the target's own (DW-1791).
- `src/OcuPilot/Area/OsMgmt/DatabaseSave.cls` -- `GROUPS` gains `size:OcuPilot.Screen.Tool.LocalDatabaseGrow`, written last and only when `Size` changed.
- Tools (`src/OcuPilot/Screen/Tool/`, new). All are action writes: `SENDSBODY` 0, `DESTRUCTIVE` 0, `PORTCLASS` `DatabasePort`, endpoint `Database.Actions`, `READTYPE` `STATE`, `CHANGEACTION` `updated`. Each declares its arguments and `ArgumentProblem` through `DatabaseRules`, and each `PrivilegePairs` ends with `Gate.WithClassicPages`. A screen sends only the values `SCREENVALUES` declares (AD-56 (ii)): `mount=ReadOnly`, `truncate=TargetSize`, `compact=TargetFreeSpace`, `integrity=Globals`, `expand=InitialSize`. `Globals` also joins the integrity tool's `READANSWERS`, so its subject can name it.

  | Class | Tool | Descriptor | `WRITETYPE` | Arguments | `FINGERPRINTSUBJECT` | Extra pairs | `CLASSICPAGES` |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | `DatabaseMount` | `osmgmt.databasedetails.mount` | `DatabaseDetails` | `MOUNT` | `ReadOnly` (boolean, default false) | `Mounted` | `%Admin_Secure:USE` | `%CSP.UI.Portal.Dialog.DBActions` |
  | `DatabaseDismount` | `.dismount` | `DatabaseDetails` | `DISMOUNT` | none | `Mounted` | none | none (the details page's own) |
  | `DatabaseTruncate` | `.truncate` | `DatabaseDetails` | `TRUNCATE` | `TargetSize` (integer, required) | `Mounted,ReadOnly,Size` | none | `%CSP.UI.Portal.Background.Dialog.DatabaseTruncate` |
  | `DatabaseCompact` | `.compact` | `DatabaseDetails` | `COMPACT` | `TargetFreeSpace` (integer, required) | `Mounted,ReadOnly` | `%DB_IRISSYS:WRITE`; `%DB_<ResourceName>:READ` through `ArgumentPairs` | `%CSP.UI.Portal.Background.Dialog.DatabaseCompact` |
  | `DatabaseDefragment` | `.defragment` | `DatabaseDetails` | `DEFRAGMENT` | none | `Mounted,ReadOnly` | as compact | `%CSP.UI.Portal.Background.Dialog.DatabaseDefragment` |
  | `DatabaseIntegrityCheck` | `osmgmt.databases.integrity` | `DatabaseList` | `INTEGRITYCHECK` | `Globals` (array, optional) | `Dismounted,Globals` | `%Admin_Operate:USE` (`POLLRESOURCE`), `%DB_IRISSYS:WRITE` | `%CSP.UI.Portal.Dialog.Integ,%CSP.UI.Portal.Dialog.IntegOutput` |
  | `LocalDatabaseGrow` | `osmgmt.localdatabases.grow` | `LocalDatabaseList` | `MODIFYSIZE` | `Size` (integer, required) | `Size,MaxSize` | `%Admin_Operate:USE` (`POLLRESOURCE`) | `%CSP.UI.Portal.Database` |
  | `LocalDatabaseExpand` | `osmgmt.localdatabases.expand` | `LocalDatabaseList` | `EXPANDVOL` | `InitialSize` (integer, required) | `Mounted,NewVolumeDirectory,NewVolumeThreshold` | `%Admin_Operate:USE` | `%CSP.UI.Portal.DatabaseVolumes,%CSP.UI.Portal.Dialog.ExpandVolume` |

  - Each queued tool also declares `POLLRESOURCE` `%Admin_Operate` where its screen's set lacks it.
  - The mint and the confirm refuse a state its precondition forbids: 409 `DATABASE.MOUNTED` (mount), `DATABASE.DISMOUNTED` (every other), `DATABASE.READONLY` (truncate, compact, defragment).
- `src/OcuPilot/Kernel/EntityRef.cls` -- `IDRULES` gains `database:directoryset`:
  - A value beginning `[` is a JSON array of directories. Its canonical form keeps each first spelling, drops later ones that `DatabasePort.SameDirectory` matches, and sorts the rest.
  - A one-member array reads as that member.
  - Any other value is kept exactly, so Database details' ids are unchanged.
  - Mirror the rule in the client's entity-rule code; `screen-mirror.mjs` refuses an unknown rule.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `database` joins `COVEREDTYPES` and the dispatch chain, reaching `Database` with the type.
  - For `database` with write type `DISMOUNT`, refuse when the target directory `SameDirectory`-matches `OwnDatabaseDirectories`. A failed read refuses.
  - Every other `database` write is permitted: an empty `PermittedChangeFields` entry, with arguments skipped as today.
  - `REASON` and EXPERIENCE.md :481 read: "OcuPilot or the instance itself depends on this database. It cannot be deleted or dismounted, and its directory, resource and read-only setting cannot be changed."
- `src/OcuPilot/Kernel/Proposal/Impact.cls` -- `KindOf` answers kind `database-dismount`, with no parts, for `osmgmt.databasedetails.dismount`. `ScreenImpact` then answers only the prohibited set's refusal for a protected target, and nothing for any other.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- between :20 and :21 and in name order, the eight keys, each `false`.
- `src/OcuPilot/Screen/Descriptor/`:
  - `DatabaseDetails.cls`: `rowActions` `mount`, `dismount`, `truncate`, `compact`, `defragment`; replace the doc comment :64-66.
  - `DatabaseList.cls`: `primaryAction` `integrity`; `DatabaseIntegrity`'s route is its target.
  - `LocalDatabaseList.cls`: `rowActions` gains `expand`, drawn by the editor only (`UNDRAWN_ACTIONS`); `secondaryEntityTypes` `["database"]`, so its Status re-reads after a mount or dismount (AD-14).

**Execution, Part B: the inbox (AC10, AC11; DW-1791's rule is in Part A):**

- `src/OcuPilot/Port/BackgroundTaskPort.cls` (DW-1821):
  - `Rows` adds source `database`: each `DatabaseList` row that has not ended and whose `ID` no portal row's `SysBGTaskId` carries, mapped to `{Source, Id, Task: DisplayType, Namespace: "", Status: RunningState, Details: "", ErrorCount: "", StartTime, Database}`.
  - An own admin row whose vendor task row is an `AsyncTaskSysBackground` is linked through its stored `SysBGTaskId`. That row carries the task's `Database` while it runs, and its database row is dropped, so a task is listed once.
  - `Control` reaches a database row through `PortalControl` (the documented `%SYS.BackgroundTask` `Cancel`, `Pause` and `Resume`).
  - `Snippet` mirrors the new branch.
- `src/OcuPilot/Test/BackgroundTaskFixture.cls` -- `ArmDatabaseRows(json)` and `ArmTaskLinks(json)` overriding the two new reads.
- `ui/src/app/areas/os-management/database-details.page.ts` -- the Background tasks section also re-reads on a `database` change event for its directory.

**Execution, Part C: the integrity flow and log (AC6, AC7):**

- `src/OcuPilot/Port/LogSourcePort.cls` -- source `integrity`, pairs `%Admin_Operate:USE` and `%DB_IRISSYS:READ` (Task 0 item 1):
  - `Files` answers the checks `ListIntegrityTasks` holds, newest first, at most 50: `{name: <ID>, time: StartTime, state: RunningState, ended: HasEnded}`.
  - `Page` with `file` = a check id (`^[0-9]{1,10}$`, else `LOG.FILE`) renders that check's report, as `CaptureDisplay` does, into a temporary stream it pages. No `file` means the newest.
  - A check that has not ended answers no lines and `running` true.
  - `Rows` answers the newest check's lines as `{time: StartTime, severity: error for a line the report marks "****", else info, text}`.
  - A test pins the query's columns and the report's first line (AD-29's internal-reader rule).
- `src/OcuPilot/Api/Router.cls` -- `GET /logs/integrity/files` and `GET /logs/integrity`, beside :139, with thin wrappers.
- `src/OcuPilot/Screen/Descriptor/DatabaseIntegrity.cls` (new, `form-page`):
  - route `os-management/databases/integrity`, `labelKey` `databaseIntegrityLabel`, position 0, the Databases list's pairs;
  - entity `database`, id `single`, `classicPage` `%CSP.UI.Portal.Dialog.Integ`, three prompts, `toolIdentifier` `osmgmt.databaseintegrity`.
- `src/OcuPilot/Screen/Descriptor/DatabaseIntegrityLog.cls` (new, `log-viewer`):
  - route `os-management/databases/integrity-log`, `labelKey` `databaseIntegrityLogLabel`, position 0, the pairs above;
  - read `{port: logsource, endpoint: integrity, type: LIST}`, fields `time, severity, text`;
  - `classicPage` `%CSP.UI.Portal.Dialog.IntegLog`, three prompts, `toolIdentifier` `osmgmt.integritylog`, which gives the read tool `osmgmt.integritylog.read`.
- `ui/src/app/areas/os-management/database-integrity.page.ts` and `.store.ts` (new, on `FormStepper`):
  - **Databases:** a checklist of the Databases list's declared read (Directory and Status, Check all), at least one checked.
  - **Globals:** "Only these globals", enabled only with one database checked. Next posts step `globals` to `/database/check`.
  - **Report:** Check integrity sends `sendFor(DatabaseList, 'integrity', <JSON array>, {Globals})`, then shows the running line.
    - On finish, it issues the Integrity log's declared read and shows the newest check's report (start time and lines on the code surface).
    - On `continues`, it shows the still-running sentence.
    - Either way, "Open the integrity log".
  - The page opens clean. Its leave guard arms only after an edit and disarms after the send.
- `ui/src/app/areas/logs/log-viewer.store.ts` / `.page.ts` -- a `SOURCES` entry for the Integrity log (`tailPath` `/api/ocupilot/logs/integrity`, `filesPath` `/api/ocupilot/logs/integrity/files`). The check select labels each entry "<time> · <state>". A running check reads `databaseIntegrityRunning`; none reads `databaseIntegrityNone`.

**Client, Parts A and B:**

- `ui/src/app/shell/warning-dialog.ts` -- optional inputs: an advisory, a flag (`flagLabel`), and a whole-number field (`fieldLabel`, `fieldHint`, `fieldId`). It emits `{flag?, value?}`. A missing or non-whole value keeps Proceed `aria-disabled` with its reason.
- `ui/src/app/shell/screen-action-handler.ts`:
  - `DatabaseDetails` joins `SCREEN_ACTION_DESCRIPTORS`.
  - `WARNING_CONSEQUENCES` gains its five actions.
  - A new `WARNING_VALUES` map holds `mount` to flag `ReadOnly`, `truncate` to `TargetSize` and `compact` to `TargetFreeSpace`; `confirmPending` sends them as `values`.
  - `dismount` joins `IMPACT_ACTIONS`. `startFor` reads the impact before it opens the warning dialog for an action in both tables, and draws a refusal as that dialog's advisory.
- `ui/src/app/core/impact.ts` -- kind `database-dismount`, with no parts.
- `ui/src/app/areas/os-management/database-details.page.ts`:
  - selects its one row after each read (the `process-details` model);
  - hosts `app-screen-action-dialogs` and the refusal banner;
  - after a send, shows `databaseOperationRunning`, then `databaseOperationFinished` or `auditDatabaseStillRunning`, and re-reads its properties.
- `ui/src/app/areas/os-management/database-editor.page.ts` / `.store.ts`:
  - General gains "Size (MB)", sent as group `size`.
  - Volume files gains "Add a volume": a warning dialog with the Initial size field, sending `expand`. It is `aria-disabled` "Save your changes before adding a volume." while the form is dirty.
- `ui/src/app/areas/os-management/database-actions.ts` -- Databases' "Check integrity" navigates to the flow.
- `shell/screen-outlet.ts`, `app.ts` -- register `DatabaseIntegrity` in `DESCRIPTOR_PAGES` and reset its store at sign-out.

**Strings and EXPERIENCE.md, for Parts A-C:**

- `ui/src/app/core/strings.ts`, appended. Each key cites its EXPERIENCE row, and a value that already exists reuses its key.
  - Labels:
    - the action labels Mount, Dismount, Truncate, Compact, Defragment;
    - "Check integrity", "Integrity check", "Integrity log", "Report", "Only these globals", "Add a volume", "Size (MB)", "Mount read-only".
  - Consequences:
    - `databaseMountConsequence` "Mounting makes this database available again to every namespace that uses it."
    - `databaseDismountConsequence` "Dismounting this database stops every process from reading or writing it until it is mounted again."
    - `databaseTruncateConsequence` "Truncating returns the unused space at the end of the database's file to the operating system. No data is removed."
    - `databaseCompactConsequence` "Compacting moves the database's free space to the end of its file, where Truncate can return it."
    - `databaseDefragmentConsequence` "Defragmenting can grow the database to make room while it works, and it cannot be paused."
    - `databaseExpandConsequence` "The new volume file is created in the database's new volume directory."
  - Fields:
    - "Target file size (MB)" with hint "0 returns all unused space. Otherwise enter less than the current size.";
    - "Target free space at end of file (MB)" with hint "Enter a number from 0 to the database's free space.";
    - "One name per line. Leave empty to check every global."
    - "Globals can be chosen when one database is checked."
  - Running line: `databaseOperationRunning` "<operation> running on the instance since <time>", `databaseOperationFinished` "<operation> finished."
  - Flow and log:
    - "Open the integrity log", "Save your changes before adding a volume.";
    - `databaseIntegrityRunning` "This check is still running.", `databaseIntegrityNone` "This instance holds no integrity check.";
    - three prompts per new descriptor (Design Notes).
- EXPERIENCE.md, in place (still 993 lines; `cd ui && npm run test:tools` after):
  - :98 gains "; mount, dismount, truncate, compact and defragment" with `[AMENDED 2026-09-29, Story 18.4]`;
  - :173 names the operation warnings, Add a volume and the integrity flow;
  - :377 gains the literals above, its where-clause ending `[ADDED 2026-09-29 - Story 18.4]`;
  - :481 is the sentence above;
  - :617 adds dismount to the non-destructive warnings;
  - :626 adds the integrity check to the stepper row;
  - :627 adds the Integrity log to the log-viewer row.
- `ui/src/app/core/screens.generated.ts` -- regenerate with `cd ui && node tools/screen-mirror.mjs`.

**Tests:**

- `src/OcuPilot/Test/DatabaseActionProbe.cls` (new, extends `DatabaseWriteProbe`, prefix `OCUPROBE184`):
  - `Fill(name, mb)` writes and half-kills probe globals by extended reference, test-only;
  - `PausedAdminCompact(name, .guid, .taskId)` queues a compact through `DatabasePort` and pauses it through `%SYS.BackgroundTask`;
  - `RemoveAll` also removes its `%SYS.BackgroundTask` and `SYS.BackgroundIntegrity` rows by probe directory.
- `src/OcuPilot/Test/DatabaseActions.cls` (new; refuses unless `OCUPILOT_ALLOW_DATABASE_CONFIG` reads 1; `RemoveAll` before all, after each and after all). One method per Part A matrix row, on both callers (the agent's mint and confirm with the key enabled through `GovernanceFixture`; the screen action):
  - each operation's recorded call and body (`DatabaseRecordPort`), then its real effect read back;
  - the three state refusals, the target rules and the started leg (a recording port answering `PORT.TIMEOUT`: 202, `continues`, `unchecked` `running`, no `PollTask` after);
  - the governance leg, and `Snippet` per branch.
- `src/OcuPilot/Test/DatabaseActionsGate.cls` with `DatabaseActionsGateProbe.cls` (new; also refuses unless `OCUPILOT_ALLOW_PRINCIPALS` reads 1; the `DatabaseWriteGate` model):
  - each missing declared pair is refused 403 naming it, with zero port calls;
  - a principal holding exactly each tool's pairs writes on both callers;
  - a custom resource on each `CLASSICPAGES` page refuses (`ClassicPageGate`).
- `src/OcuPilot/Test/DatabaseActionsProhibited.cls` (new, `OCUPILOT_ALLOW_DATABASE_CONFIG`):
  - a dismount of `OCUPILOT`'s, the install namespace's routines and `IRISSYS`'s directories through `DatabaseAcceptPort` on both callers is refused with `Writes()` empty;
  - a failed own-set read refuses;
  - a probe database's dismount through a `DatabaseProhibitedFixture` own name is refused, and mount, truncate and compact of a protected directory are not.
- `src/OcuPilot/Test/DatabaseIntegrity.cls` (new; `OCUPILOT_ALLOW_DATABASE_CONFIG` and `OCUPILOT_ALLOW_PRINCIPALS`):
  - the one-DB and set checks, and the set id canonicalization;
  - the refusals (an empty set sends no call);
  - the log's `Files`, `Page` and `Rows` for the check just run;
  - `LOG.FILE` on a bad id;
  - the Task 0 principal's read;
  - the pin on `ListIntegrityTasks`' columns.
- `src/OcuPilot/Test/DatabaseGrowExpand.cls` (new; `OCUPILOT_ALLOW_DATABASE_CONFIG`):
  - the grow through `PUT /database/:id` group `size` and through the tool, and its refusals;
  - Add a volume and its refusals;
  - DW-1791's two collisions on `volumePath` at the Save, the mint and the confirm with no vendor call, and the two `PROPERTYFAULTS` entries through `AdminPort.Invoke` on probe objects.
- `src/OcuPilot/Test/AdminPortAsync.cls` -- the exact `QUEUEDWRITES`; a test subclass without the six refuses each self-queuing type before `Run()`.
- `Test/BackgroundTasks.cls` (fixture legs: a database row, a linked admin row listed once, a portal row unchanged) and `BackgroundTasksLive.cls` (a live paused admin compact listed once, with its `Database`) (DW-1821).
- `scripts/ci-throwaway.sh`, add-only:
  - the `OCUPILOT_ALLOW_DATABASE_CONFIG` `# classes:` line gains `DatabaseActions, DatabaseActionsGate, DatabaseActionsProhibited, DatabaseGrowExpand, DatabaseIntegrity`;
  - the principals line gains `DatabaseActionsGate` and `DatabaseIntegrity`.
- Rosters, re-derived from the code and each class's red:
  - `ReadTool` +9 (1 read, 8 writes); `Navigation` OS management +2; `Descriptor` `ReadShapes` +1;
  - `Prohibited` covered types +1, codes unchanged; `CLASSICROSTER` +7;
  - `GovernanceBaseline`, `Governance` and `ToolDispatch` disabled sets +8;
  - `REFUSEEMPTY` +8; `ToolWrite` `MUTATINGTYPES` +8;
  - `EndpointCoverage` +2 routes; `SurfaceCoverage` a row per descriptor and tool; `AdminPortAsync`;
  - the navigation, navigation-wire and rail-wire rosters +2; `KERNEL_REFUSALS`' sentence.
- Client specs:
  - new: `database-integrity.page.spec.ts`, `database-integrity.store.spec.ts`, `warning-dialog.spec.ts`;
  - extended: `database-details.page.spec.ts`, `screen-action-handler.spec.ts`, `database-editor.page.spec.ts` / `.store.spec.ts`, `log-viewer.page.spec.ts`, `app.spec.ts` (the reset), and the entity-rule test.
- `ui/browser/database-operations.browser-spec.mjs` (new; the `local-databases` model; `OCUPROBE184*` seeded and removed over `docker exec`):
  - AC1's five operations on Database details, each with its dialog and running line;
  - AC3's grow and Add a volume;
  - AC6's flow to the report and AC7's log;
  - AC5's advisory on `IRISSYS`'s directory (open and cancel only);
  - AC12's DW-1337 walk of the new screens and dialogs in both themes.

**Acceptance Criteria:**

- **AC1:** Given a probe database on `ocupilot-b-ci` and a holder of Database details' pairs plus each tool's pairs, when Dismount, Mount (plain and read-only), Truncate, Compact and Defragment are confirmed in their dialogs on Database details, then:
  - each sends its `POST /database-dir/<op>?dir=` with the body the matrix names;
  - the page shows the running line, then "<operation> finished.";
  - the properties re-read to show the change;
  - the instance records its `DatabaseChange` audit row.
  - The agent's confirmed tool, with its key enabled, does the same.
- **AC2:** Given a queued operation (truncate, compact, defragment, integrity, grow, expand), when it finishes within the port's bound, then the port read the task once and deleted its row. When it is still running at the bound, then both callers answer started: "Still running on the instance. It finishes in the background.", read-back `unchecked`, and no later read of that task. No `ERROR #7846` is logged.
- **AC3:** Given a probe database in the Local databases editor, when Size is raised and Saved, then `modify-size` sends the new size and it reads back. When Add a volume is confirmed with an initial size, then `expand-volume` creates a volume file in the database's new volume directory, and the volume files section lists it. Add a volume is `aria-disabled`, with its reason, while the form is dirty.
- **AC4:** Given each state or argument the matrix refuses, when either caller sends it, then it is refused with the matrix's code on the named field or envelope, before any vendor call.
- **AC5:** Given `OCUPILOT`, the install namespace's globals or routines database, or a system database, when either caller dismounts it, then the write is refused `PROHIBITED.OCUPILOTDATABASE` and the Dismount dialog states that reason when it opens. Mount, truncate, compact and defragment of those databases stay permitted.
- **AC6:** Given Databases, when Check integrity runs over one probe database with a global named, and then over two, then:
  - the vendor receives the matrix's body;
  - the Report step shows the finished check's report;
  - a check still running at the bound shows the still-running sentence and "Open the integrity log".
- **AC7:** Given checks the instance holds, when the Integrity log opens, then it lists them newest first and shows the selected check's report. A running check reads "This check is still running." `osmgmt.integritylog.read` answers the newest check's lines. A principal holding only `%Admin_Operate:USE` and `%DB_IRISSYS:READ` reads it.
- **AC8:** Given the governance baseline, when the agent mints any of the eight tools, then it is refused `GOVERNANCE.DISABLED`, while the screen's caller proceeds.
- **AC9:** Given least-privileged principals, when they call each tool, then:
  - each missing declared pair is refused 403 naming it, with zero port calls;
  - a principal holding exactly the declared pairs writes on both callers;
  - a custom resource on each `CLASSICPAGES` page refuses a caller without it.
- **AC10 (DW-1821):** Given a paused compact started through `osmgmt.databasedetails.compact`, when Database details opens for its directory, then its Background tasks section lists that task, read through Background tasks' declared read. Given the same task, when Background tasks opens, then it lists the task exactly once.
- **AC11 (DW-1791):** Given a probe database, when either caller sets its new volume directory to another database's directory or to another database's volume directory, then the write is refused `DATABASE.DIRECTORY.INUSE` on `volumePath` with no vendor call.
- **AC12:** Given the new screens and dialogs, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays below 3800 kB; if it passes `maximumWarning` (2217 kB), the warning is re-based under DW-1166 with `angular-json.test.mjs`'s literal.

**Review patches (implement-stage review, 2026-09-29).** Each new or changed pinning test gets its `mutation:` line in `## Verification`.

- R1 (AC2): `DatabaseActions` gains a started leg over a real queued task: `DatabaseQueuedPort` (seam `^||OcuPilotDatabaseWritePort`) with a poll counter, a defragment or compact of a filled probe database answered started. Assert: 200 `continues`, read-back `unchecked` `running`; the port's poll count does not grow after the answer; the async task row still exists after the answer; `Settle` then reads it once and forgets it; `SecondReads` unchanged.
- R2 (AC2): `DatabaseActionProbe.SecondReads` answers -1 when `messages.log` does not exist, and each caller asserts the before count is 0 or more.
- R3 (AD-59): `TestThePortsOwnReadBodiesAndScripts` gains name-keyed `MODIFYSIZE` and `EXPANDVOL` legs whose context payload carries `Directory`: one step to `/database-dir/modify-size?dir=` or `/expand-volume?dir=` with its body.
- R4 (AD-59): `BackgroundTasks.TestTheScriptRendersBothBranches` gains a `Database` row: the `%SYS.BackgroundTask` call on its own id.
- R5 (AC4): `DatabaseRecordPort.FailOn` takes an optional status (default 500). A new leg: a vendor 409 on a dismounted probe's mount answers 409 `DATABASE.MOUNTED` with its sentence.
- R6 (AD-14): `DatabaseDescriptor` pins `LocalDatabaseList`'s secondary entity type `database`.
- R7 (AC6): `DatabaseIntegrity` gains a leg over the `globals` step check, run the way the route runs it. An empty set, a bad name and globals over two databases each answer their violation on their field, with no vendor call.
- R8 (AC2, AC4): `database-details.page.spec.ts` and `database-editor.page.spec.ts` each gain a `continues` leg (the still-running sentence) and a 409 leg (the refusal's sentence).
- R9 (AC3): Add a volume's field gets a hint, `databaseInitialSizeHint` "Enter a number of 1 or more, up to the new volume threshold when one is set.". It is a Fixed strings literal on EXPERIENCE.md :377, in place. Proceed names it while the field holds no whole number. The browser spec's expectation follows.
- R10 (AC3, intent's running line): when a Save answers `continues`, the editor shows `auditDatabaseStillRunning` until the next edit or Save. The Save button's own in-flight indicator is its running line.
- R11 (AC4): the mint's integrity refusal for dismounted members names them (`DatabaseRules.ActionProblem`).
- R12 (AC10): `DatabaseActions` gains a live leg: a compact started through `DatabasePort` and paused (`DatabaseActionProbe.PausedAdminCompact`). `BackgroundTaskPort.Rows` lists it once, on its admin row, with its `Database`. The leg then cancels, settles and forgets the task, and `SecondReads` is unchanged.
- R13 (AC9): `DatabaseActionsGate` gains defragment without `%DB_IRISSYS:WRITE` on both callers, and the grow's agent confirm without `%Admin_Operate:USE`.

**Rework 1 (2026-09-29, decisions before review):**

- [ ] [Owner] The owner's database-directory rule (orchestrator relay 2026-09-29, stated at AD-21's sixth case): a database directory is always required and never left for the vendor to default, and nothing is written into IRISSYS's directory (the manager directory). In this story it binds Add a volume (`osmgmt.localdatabases.expandvolume` or its name here) and any other operation that places a file: refuse, by name and before any vendor call, a database whose configured `NewVolumeDirectory` is empty (the vendor would otherwise pick the directory) and one whose effective new-volume directory is the manager directory. Pin both on both callers (the agent's mint and the screen action) with tests that go red when the refusal is removed, and record the `mutation:` lines.
- [ ] [Decision] DW-1847 (option A, by=merge_gate): dismount keeps `%Admin_Manage:USE` (the intent's pair line and AD-8 are amended). Pin that an Operate-only holder (Database details' pairs without `%Admin_Manage:USE`) is refused with the missing pair named (the declared-pairs refusal, e.g. 403 naming `%Admin_Manage:USE`) before any port call, on both callers, and never `PROHIBITED.OCUPILOTDATABASE`; mutation recorded.
- [ ] [Ledger] DW-1848: the Integrity log's error branch -- render a report that found errors through the real `Display^Integrity` capture (a hand-built vendor output row or a deliberately damaged probe block, on `ocupilot-b-ci` only, removed afterwards), and pin the error lines; if it cannot be produced on 2026.2, say so with evidence under Design Notes and close it there.

## Spec Change Log

- 2026-09-29, runner, rework 1 (pre-review): feature merged forward (`d9f84f52`); three decisions arrived before code review -- the owner's directory rule, DW-1847 (dismount keeps `%Admin_Manage:USE`; intent pair line amended), and DW-1848 kept in-story. Status set to `in-progress` for one pass over those items.

## Review Triage Log

### 2026-09-29 — Review pass

- verdicts: 27 findings — high 0, medium 10, low 13, false 3, maybe-false 1
- findings:
  - `[medium]` `[patch]` The started leg's "no task was polled" could not fail (its port never reached the vendor) — R1: a started leg over `DatabaseQueuedPort` counting polls, the row held after the 202, one settle; mutation run 143.
  - `[medium]` `[patch]` `SecondReads` comparisons had no floor — R2: -1 on a missing log, each caller asserts 0 or more; mutation run 139.
  - `[low]` `[patch]` The grow and Add a volume scripts' directory fallback was untested (it works: the payload keeps the fingerprint subject, which carries `Directory`) — R3; mutation run 142.
  - `[low]` `[patch]` `BackgroundTaskPort.Snippet`'s Database-row branch was untested — R4; mutation run 137.
  - `[low]` `[patch]` The mount's vendor 409 mapping was untested — R5; mutation run 142.
  - `[low]` `[patch]` `LocalDatabaseList`'s `database` secondary type was unpinned — R6; mutation run 136.
  - `[medium]` `[patch]` The `globals` step check was untested on the server — R7; mutation run 139.
  - `[maybe-false]` `[defer]` The integrity report's error branch never runs in a test — needs a check over a damaged database; deferred, medium (unverified).
  - `[medium]` `[patch]` No test rendered the still-running line or the refusal on Database details or in the editor — R8 page-spec legs, each with its mutation.
  - `[low]` `[reject]` AC1's audit clause and AC2's and AC10's paths had no mutation line — each AC carries one (Rule 19 scopes per AC); AC2's and AC10's clauses gained pinning tests under R1 and R12.
  - `[low]` `[patch]` `PausedAdminCompact` and `DatabaseQueuedPort`'s seams ran in no test — used by R1 and R12, three helper defects fixed.
  - `[medium]` `[patch]` The Save's `continues` had no consumer — R10: the editor shows the still-running sentence.
  - `[medium]` `[reject]` Dismount declares `%Admin_Manage:USE` against the intent's pair line — the fix is to edit this spec: the kernel's own-set read answers `ResourcesOR` `%Admin_Manage` alone (measured), so AD-8's endpoint clause and AD-29, which the intent's pairs bullet cites, require it; runner amendment and owner decision in `deferred:`.
  - `[medium]` `[patch]` Add a volume's Proceed named no reason — R9: `databaseInitialSizeHint`.
  - `[low]` `[reject]` The protected-database permitted leg used an empty diff — each tool's argument is in its fingerprint subject, which `SkippedFields` removes before the sweep; the truncate leg runs a real diff.
  - `[low]` `[reject]` Wrong-state codes differ per caller (mint 400 with the sentence, confirm `PROPOSAL.TARGETCHANGED`) — each refuses before any vendor call; those envelopes are AD-6's and AD-51's existing contracts.
  - `[low]` `[patch]` The mint's integrity refusal did not name the dismounted member — R11; mutation run 139.
  - `[low]` `[reject]` Governance integration covers five tools at confirm — `ToolDispatch` and `GovernanceBaseline` pin all eight keys through the one gate.
  - `[false]` `[reject]` The vendor route appears only in scripts — the port calls the vendor in process (AD-1, AD-2); the record seam is the wire.
  - `[medium]` `[patch]` DW-1821's live leg started the compact over raw HTTP — R12: started through `DatabasePort` and paused; mutation run 142.
  - `[low]` `[patch]` No missing-pair leg for defragment's `%DB_IRISSYS:WRITE` or the grow's agent confirm — R13; mutation run 145.
  - `[low]` `[reject]` `Dialog.IntegLogContent` is declared nowhere — AD-44's multi-page union binds write tools; a screen declares one classic page, IntegLog here.
  - `[false]` `[reject]` Changes beyond the intent's surface — each is a Tasks item or required; the panel leg moved because Databases' bar is two lines at 1280 docked, paused or not (90 px measured both ways).
  - `[medium]` `[reject]` Dismount's pairs (the auditor's reading R2) — grouped with the dismount row above.
  - `[false]` `[reject]` `TaskLinks` reads task rows outside the port — `BackgroundTaskPort` extends `AdminPort` and reads a stored property, never `async-result`, as Design Notes plan.
  - `[medium]` `[patch]` The grow on Save showed no still-running line — grouped with R10.
  - `[low]` `[reject]` The Report step shows the newest check, not one by id — the Tasks item says so; only a check another caller starts in the same instant differs.

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: every vendor call goes through `DatabasePort`, `BackgroundTaskPort` (both extend `AdminPort`) or `LogSourcePort`.
- AD-26: `QUEUEDWRITES`, `SELFQUEUEDTYPES`, the one poller, and "started" past the bound.
- AD-8, AD-29: measured pairs, extra and argument pairs.
- AD-10, AD-53: the dismount arm, over the effect. AD-13: `database:directoryset`. AD-14: the change events and Local databases' secondary type.
- AD-15, AD-53: the named no-event cases. AD-16: `%SYS` by save and restore.
- AD-21: no caller path; DW-1791. AD-22: the baseline.
- AD-36, AD-5: the log's declared read, and pages issuing other screens' reads.
- AD-39: the violations. AD-43: Database details' refresh pause (unchanged). AD-44: `CLASSICPAGES`.
- AD-51: action writes, declared subjects, port-built bodies, and the `STATE` read type.
- AD-53, AD-55, AD-56 (ii): two callers and declared values. AD-58: `unchecked` for a 202. AD-59: `Snippet`.

**Measured on `ocupilot-b-ci`, 2026-09-29, this plan** (probe window 15:28-15:39; objects under Auto Run Result):

- **Sync:**
  - Dismount answers 200 `{}` in about 1 s, including for an already dismounted database or one a namespace uses. The vendor refuses only the manager's database (#345).
  - Mount `{}` answers 200. A body is required (415 #40330 without one). An already mounted database answers 409 #19. `{"ReadOnly":true}` mounts read-only. An unknown key is 400 #40307.
- **Queued (202, v1 `Location`):**
  - Truncate finishes in under 0.1 s with `Result` `{}`. A target at or above the size is a silent no-op. On a dismounted database it fails `<PROTECT>`.
  - Compact `{TargetFreeSpace}` takes about 0.4 s and moves free space but not the size. On a dismounted database it fails `<NOTOPEN>`.
  - Defragment takes 1.3-1.8 s and grew the database 60 to 90 MB. It accepts any body.
  - Expand `{InitialSize}` creates `IRIS-000n.VOL` in the configured `NewVolumeDirectory`; 0 fails #644.
  - Modify-size grows onto the last volume. A shrink is a silent no-op. Above `MaxSize` it silently clamps and logs a severity-2 `[Database.MaxSize]` line.
  - Integrity `{Databases:[{Directory, Globals}]}` takes about 1.3 s. Its report is only in the task's `Console` and in `^SYS.BackgroundIntegrityResults`, which outlives `ForgetTask`. No file is written. The admin API has no read of a past check.
- **Progress:** running polls of compact, defragment and integrity carry `ProgressTotal`/`ProgressCurrent`. Not built: the running line is the orchestrator's ruling (cycle log 2026-09-28).
- **Pairs:**
  - dismount and truncate: `%Admin_Operate:U`, `%DB_IRISSYS:R`;
  - mount: also `%Admin_Secure:U` (500 #356 without it; the audit row says #921);
  - compact and defragment: also `%DB_IRISSYS:RW` and `%DB_<db>:R`;
  - integrity: `%Admin_Operate:U`, `%DB_IRISSYS:RW`;
  - modify-size: `%Admin_Manage:U`, `%DB_IRISSYS:R` (its poll needs Operate);
  - expand: Manage, Operate and `%DB_IRISSYS:R`.
  - A refusal inside a queued task still answers 202 and fails in `FailureReason`.
- **Audit:** mount, dismount, truncate, compact, defragment and modify-size each write `%System/%System/DatabaseChange`, as the caller. Expand-volume, integrity-check and a `PUT` of `NewVolumeDirectory` write none.
- **DW-1791:** `NewVolumeDirectory` naming another database's directory is 500 #576; naming another database's volume directory is 500 #575. Expand-volume takes no directory. Database B stayed intact.
- **DW-1821:** an admin-API compact or defragment makes a `%SYS.BackgroundTask` row (`Database`, `RunningState`, progress) but no portal row. The caller's `AsyncResult` list row carries no directory. The vendor task row stores `SysBGTaskId`.
- **Read-once:** every probe task was read once and its row deleted; #7846 was counted 0 before and after.

**Measured at implement** (Task 0, `ocupilot-b-ci`, 2026-09-29 17:45-17:50 UTC; probe database `OCUPROBE184A`, role `OcuProbe184R`, user `OcuProbe184User`, all removed):

- **Item 1, the integrity log's read.** A principal holding exactly `%Admin_Operate:USE` and `%DB_IRISSYS:READ` ran `SYS.BackgroundIntegrity:ListIntegrityTasks` in `%SYS` (columns `ID, StartTime, RunningState, HasEnded, FinalStatus, DatabaseList, ListOfGlobalLists, MaxProcesses, PartialCheck, PID`) and `Display^Integrity(<task>.GetOutputGlobal(), 1, 0)` then `(…, 0, 1)` for a finished probe check. `%DB_IRISSYS:READ` alone also succeeds; `%Admin_Operate:USE` alone is refused `<PROTECT>` on the query. So the vendor needs only the second pair; the first is the port's declared gate. The task row and its `^SYS.BackgroundIntegrityResults` node count (3) were unchanged, and the journal after the mark held only the sign-in's own audit and `^SECURITY("UsersD")` rows for that process. A global name is sent without `^` (`"OcuProbe184A"`, reported as `Global: OcuProbe184A`). No HALT.
- **Item 2, a volume with no new volume directory.** `NewVolumeDirectory` cannot be empty: `SYS.Database` sets it to the database's own directory at creation, and a `PUT` of `""` reads back as that directory. `EXPANDVOL` `{InitialSize: 1}` created `IRIS-0001.VOL` in the database's own directory; no other file changed outside the database directory. No HALT.
- **Item 3, the `STATE` sources.** `GET`: `MaxSize`, `ResourceName`, `NewVolumeDirectory`, `NewVolumeThreshold`, and `ReadOnly` (the configured attribute only; a read-only mount leaves it false). `INFO` (queued, read once by the port): `Mounted`, `Size`, `MaxSize`, `AvailableSpace` (MB, equal to `SYS.Database.GetFreeSpace`; 0 when dismounted), `EndFree` (`""` when dismounted or read-only), and `ReadOnlyReason` (`"DB was mounted read-only by user"`, `"DB has read-only attribute"`, `""` otherwise). So `STATE.ReadOnly` is `ReadOnlyReason` non-empty, and `FreeSpace` is `AvailableSpace`.
- #7846 was counted 0 in `messages.log` and `alerts.log` before and after.

**Decisions:**

- **Split by the classic page and its resource.** The Operate-gated operations of the classic Database details page (mount, dismount, truncate, compact, defragment) sit on Database details, by directory. Size and volumes sit in the Local databases editor, by name: the classic `%CSP.UI.Portal.Database` and `DatabaseVolumes` are `%Admin_Manage` pages, and their vendor types need Manage. The integrity check sits on Databases, the classic `OpDatabases`.
- **Dialog weight.** None of the operations removes data, so none takes a typed name. Each takes the warning dialog (button-primary with a consequence), because each is disruptive. The value-carrying ones add one field or flag to that dialog rather than a new component per operation.
- **The integrity target is a set of directories, as a `database` id.** AD-13 already lets an id name a set (Story 16.6's pids). A JSON array cannot collide with an absolute directory, and plain ids stay exactly as Epic 6 reads them.
- **The integrity log reads the vendor's own record.** The admin API keeps a check's report only in its task result, which the port may read once, and writes no file. `SYS.BackgroundIntegrity` keeps every check, whatever started it, until its row is deleted. `LogSourcePort` renders it with the same `Display^Integrity` call the admin API's own `CaptureDisplay` makes. So one reader serves the flow's report, a check finished past the bound, and the classic's own checks, and no task row is ever read twice.
- **Globals take names, not a picker.** No OcuPilot read lists a database's globals, and System Explorer is Stage 3.
- **Size is a Save group; Add a volume is its own action.** The classic edits size on Save and expands from the volumes page. Add a volume acts on the saved configuration, so it waits for a clean form.
- **Fingerprints.** Each subject omits free space and other moving counters (AD-51). The compact and truncate targets are re-validated at the write instead.
- **DW-1791 lives in the database rules**, as 18.3's create half does. `PathPort.DatabaseDirectories` already lists every volume directory.
- **DW-1821 goes through `BackgroundTaskPort`.** That port already reads `DatabaseList`, and linking an own admin row by `SysBGTaskId` is what keeps one task one row. The link reads a stored property of the vendor task row and makes no `AsyncResult` call, so it adds no #7846 (inference; `DatabaseActions`' started leg and `BackgroundTasksLive` count #7846 before and after).
- **The epic context's path inferences do not hold.** The integrity check writes no output file, so it is no `file` consumer. Its log is no `source` consumer. Expand-volume takes no directory: its directory is 18.3's file update's `volumeRoot`/`volumePath`, already a `PathPort` consumer.
- **Governance:** all eight keys are `false` (owner, `c242eac4`).

**Size.** One story in three parts. If the gate wants it smaller, Part C (the integrity flow, its log, AC6 and AC7) separates cleanly into its own story. Only `DatabaseIntegrityCheck` and its Databases action would move with it.

**Prompts:**

- Integrity check: "Which databases can I check for integrity?" · "What does an integrity check read?" · "Can an integrity check run while a database is in use?"
- Integrity log: "Did the last integrity check find any errors?" · "Which databases did the last check cover?" · "When did the last integrity check run?"

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate):**

1. **AD-8, after Story 18.3's paragraph:** "**Story 18.4's disk operations declare pairs beyond their screen's set** [AMENDED 2026-09-29, Story 18.4 spec gate, Rule 20]. Each was measured on `ocupilot-b-ci`, 2026-09-29, and each is refused by name before any port call:
   - mount `%Admin_Secure:USE`: the vendor's mount looks up the database's resource and is refused #921 without it;
   - compact and defragment `%DB_IRISSYS:WRITE`, since their `%SYS.BackgroundTask` row is saved in IRISSYS, and `%DB_<resource>:READ` on the target;
   - the integrity check `%DB_IRISSYS:WRITE` and `%Admin_Operate:USE`;
   - the size grow and Add a volume `%Admin_Operate:USE`, for the poll, and for the vendor's own check on the volume."
2. **AD-10, the own-databases bullet:** replace "deleting, or changing the directory, …" with "deleting or dismounting, or changing the directory, …". Append: "A dismount is matched by directory against those databases' directories [AMENDED 2026-09-29, Story 18.4 spec gate, Rule 20]."
3. **AD-13, after the `process` sentence:** "A `database` id may name a set of directories as a JSON array (Story 18.4's integrity check). Its rule keeps each first spelling, drops the later spellings `DatabasePort.SameDirectory` matches, and sorts the rest; a one-member array reads as that directory, and any other value is kept exactly [AMENDED 2026-09-29, Story 18.4 spec gate, Rule 20]."
4. **AD-15's named-case list and AD-53's named gap, each:** "The sixth is Add a volume (`Database.Actions` `EXPANDVOL`), and the seventh the integrity check (`INTEGRITYCHECK`). Neither records an event with auditing on, and neither does setting a new volume directory (measured on `ocupilot-b-ci`, 2026-09-29) [AMENDED 2026-09-29, Story 18.4 spec gate, Rule 20]."
5. **AD-21, Story 18.3's additions:** "A new volume directory is refused the same way when it holds an `IRIS.DAT`, or is another database's directory or volume directory. The vendor answers each 500 (#576, #575), and expand-volume takes no directory (measured on `ocupilot-b-ci`, 2026-09-29) [AMENDED 2026-09-29, Story 18.4 spec gate, DW-1791, Rule 20]."
6. **AD-26, after Story 18.14's paragraph:** "**Story 18.4's queued writes** [AMENDED 2026-09-29, Story 18.4 spec gate, Rule 20]:
   - `QUEUEDWRITES` also names `Database.Actions` `TRUNCATE`, `COMPACT`, `DEFRAGMENT`, `EXPANDVOL`, `MODIFYSIZE` and `INTEGRITYCHECK`. Each body is built by `DatabasePort` and carries no secret.
   - `TRUNCATE`, `EXPANDVOL` and `MODIFYSIZE` queue through `ShouldRunAsync()`; the other three queue themselves in `Run()` (`SELFQUEUEDTYPES`).
   - The port refuses a mutating self-queuing type that is not named, before `Run()`, as it does the other entry.
   - No screen reads `async-result`."
7. **AD-27, after Story 18.3's extension:** "Story 18.4 extends it [AMENDED 2026-09-29, Story 18.4 spec gate, DW-1821, Rule 20]:
   - the port also lists each `DatabaseList` task that has not ended and has no portal row, naming its database, and controls it through the same `%SYS.BackgroundTask` methods;
   - it links one of the caller's own admin rows to its background task through the vendor task row's stored `SysBGTaskId`, so a task started through the admin API is listed once, with its database."
8. **AD-44, appended:** "Story 18.4's `CLASSICPAGES`: mount `%CSP.UI.Portal.Dialog.DBActions`; truncate, compact and defragment their `%CSP.UI.Portal.Background.Dialog.Database*` dialogs; the integrity check `%CSP.UI.Portal.Dialog.Integ` and `.IntegOutput`; the size grow `%CSP.UI.Portal.Database`; Add a volume `%CSP.UI.Portal.DatabaseVolumes` and `.Dialog.ExpandVolume`; dismount, performed by `%CSP.UI.Portal.DatabaseDetails` itself, none [AMENDED 2026-09-29, Story 18.4 spec gate, Rule 20]."
9. **AD-51, a case:** "Story 18.4's case: `DatabasePort` builds `Database.Actions` bodies from the disk tools' declared arguments, and answers their fresh read through a port-composed `STATE` type, as `ProcessPort` answers `RECIPIENTS` [AMENDED 2026-09-29, Story 18.4 spec gate, Rule 20]."
10. **Design Paradigm, `LogSourcePort`'s list:** add "Story 18.4's integrity check log, read through `SYS.BackgroundIntegrity` and rendered with the `Display^Integrity` call the admin API's own integrity task makes, because the admin API keeps a check's report only in its one-read task result".

**Integration ACs:**

- AC1 and AC6: every tool consumes `DatabasePort`'s `STATE` read and its `Database.Actions` branch (recording port and live instance).
- AC6: the flow consumes the Databases list's and the Integrity log's declared reads (AD-5), pinned in the page spec and the browser spec.
- AC10: Database details consumes `BackgroundTaskPort`'s database rows through Background tasks' read (`BackgroundTasksLive`, browser spec).
- AC11: `DatabaseRules` consumes `PathPort.DatabaseDirectories`.

**Consumes:**

- 18.3: `DatabasePort`, `DatabaseRules`, `DatabaseSave`, the editor, `PROHIBITED.OCUPILOTDATABASE`, `DatabaseWriteProbe` and its record, accept and prohibited fixtures.
- 16.5 and 18.3: `BackgroundTaskPort`.
- 18.14: `CLASSICPAGES` and the started conversion.
- 16.6: the set id.
- 16.20: the log viewer's file select.
- 12.3: `AuditPort`'s action-write model.
- Epic 6: Databases and Database details.

**Consumed-by:**

- 18.15: enable-interop's queued write reuses `SELFQUEUEDTYPES`/`QUEUEDWRITES` and the read-once rule.
- 18.5: journal integrity (`Journal.File`, self-queued) meets `SELFQUEUEDTYPES`.
- 18.12: the grown tool set.
- 18.13: the dismount arm must keep holding.

**Ledger inbox (Rule 17):**

- DW-1791: addressed by `DatabaseRules`' volume-directory refusal, the `PROPERTYFAULTS` entries, AC11 and amendment 5. Recommended: `resolved-by:18-4`.
- DW-1821: addressed by `BackgroundTaskPort`'s database rows and admin-row link, AC10 and amendment 7. Recommended: `resolved-by:18-4`.

**Contended files and footprint:**

- Contended with Epic 16, edited add-only: `Baseline.cls`, `Router.cls`, `strings.ts`, EXPERIENCE.md, the rosters, `ci-throwaway.sh`, `ci.test.mjs`, `screen-action-handler.ts`. `screens.generated.ts` is regenerated.
- 16.5's `BackgroundTaskPort` and its tests, and 16.20's `log-viewer` files, are extended add-only (a footprint extension for the runner to report).
- Not touched: `Error.cls`, `Area.cls`, `Screen/Read.cls`, `Kernel/Proposal/Mint.cls`, `typed-name-dialog.ts`.

## Verification

**Setup (slot B):**

- Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`.
- Every disk operation runs there, on `OCUPROBE184*` objects only. `server: "ocupilot-slot-b"` reaches the dev instance, never the throwaway, so no MCP tool performs one.
- One test class per call; send the next only once the previous has landed in `%UnitTest_Result`.
- Arm per call with `docker exec -e OCUPILOT_ALLOW_DATABASE_CONFIG=1`, adding `-e OCUPILOT_ALLOW_PRINCIPALS=1` for `DatabaseActionsGate`, `DatabaseIntegrity` and `BackgroundTasksLive`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expected: 0 failures each, totals checked against `%UnitTest_Result`.
  - The story's own: `DatabaseActions`, `DatabaseActionsGate`, `DatabaseActionsProhibited`, `DatabaseGrowExpand`, `DatabaseIntegrity`, `AdminPortAsync`, `BackgroundTasks`, `BackgroundTasksLive`, `DatabaseWrite`, `DatabaseRefusals`, `DatabaseDescriptor`, `ClassicPageGate`, `MappingDescriptor`.
  - Rosters and shared suites: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Prohibited`, `AuditingUpdate`, `RefusalCopy`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `ToolWrite`, `ToolRoundTrip`, `DraftRegistry`, `DraftPorts`, `PortGate`, `ProposalPrivilege`, `EntityRef`, `ImpactRoute`, `Navigation`, `Wire`, `Envelope`, `Inventory`, `LogSource`, `LogSourceFiles`, `LogOlderFilesWire`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/database-operations.browser-spec.mjs browser/databases.browser-spec.mjs browser/local-databases.browser-spec.mjs browser/background-tasks.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 993.
- `(once, before dev_complete)` Expected: green with a non-zero count. CI runs the full browser suite (Rule 29).
  1. The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time.
  2. `cd ui && npm test && npm run build`.
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
  4. Afterwards: no `OCUPROBE184*` configuration, `ocuprobe184*` directory, `%DB_OCUPROBE184*` resource, gate principal, probe `%SYS.BackgroundTask` or `SYS.BackgroundIntegrity` row, or async task remains.

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line. Run predicate mutations only against `DatabaseAcceptPort`.

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC1 | `DatabasePort` sends `{}` for a read-only mount | `DatabaseActions`' mount leg (not read-only) |
| AC1 | `DatabaseDetails` drops `compact` from `rowActions` | `database-details.page.spec.ts`; the browser compact leg |
| AC2 | the `Database.Actions` branch drops the started conversion | `DatabaseActions`' started leg (503 `PORT.TIMEOUT`) |
| AC2 | `QUEUEDWRITES` drops `Database.Actions/TRUNCATE` | `DatabaseActions`' truncate leg (refused as queued); `AdminPortAsync` |
| AC3 | `DatabaseSave` drops the `size` group | `DatabaseGrowExpand`' Save leg |
| AC4 | `DatabaseRules` accepts a `TargetSize` at the current size | `DatabaseActions`' target leg (a vendor call recorded) |
| AC4 | the precondition ignores `Mounted` | `DatabaseActions`' state legs |
| AC5 | the dismount arm is removed | `DatabaseActionsProhibited` (a write recorded) |
| AC6 | the port sends `Databases` without `Globals` | `DatabaseIntegrity`' one-DB leg |
| AC6 | the `directoryset` rule keeps order | `DatabaseIntegrity`' canonical leg; the entity-rule test |
| AC7 | `LogSourcePort` answers the oldest check first | `DatabaseIntegrity`' log leg; `log-viewer.page.spec.ts` |
| AC8 | a key enters the baseline `true` | `GovernanceBaseline`; `DatabaseActions`' governance leg |
| AC9 | `DatabaseCompact` drops `%DB_IRISSYS:WRITE` | `DatabaseActionsGate` (the port is called) |
| AC9 | `DatabaseMount` empties `CLASSICPAGES` | `ClassicPageGate`; `MappingDescriptor` |
| AC10 | `Rows` skips the database rows | `BackgroundTasks`' database-row leg; `BackgroundTasksLive` |
| AC10 | the admin-row link is dropped | `BackgroundTasks`' listed-once leg |
| AC11 | `DirectoryViolations` skips the volume-directory test | `DatabaseGrowExpand`' DW-1791 legs |
| AC12 | the warning dialog's field label drawn in `--ocu-surface` | the DW-1337 legs, in both themes |

Demonstrated on `ocupilot-b-ci`, each ObjectScript mutation loaded with its subclasses, each client mutation over a rebuilt and redeployed bundle where a browser spec reads it, and each reverted byte-identical and reloaded:

- mutation: `DatabasePort.ActionBody` drops the mount's `ReadOnly` → `DatabaseActions.TestDismountAndMountOnBothCallers` and `TestThePortsOwnReadBodiesAndScripts` red (run 72).
- mutation: `DatabaseDetails` drops `compact` from `rowActions`, mirror regenerated → `database-details.page.spec`'s five-operations leg red; over a rebuilt bundle, `database-operations.browser-spec` AC1 red at the command bar.
- mutation: `DatabasePort.Action`'s started conversion removed → `DatabaseActions.TestAnOperationStillRunningAtTheBoundHasStarted` alone red, 503 `PORT.TIMEOUT` (run 73).
- mutation: `Database.Actions/TRUNCATE` out of `AdminPort.QUEUEDWRITES` → `DatabaseActions`' truncate and started tests red, 500 `INTERNAL` (run 79); `AdminPortAsync.TestOnlyTheNamedQueuedWritesAreAdmitted` red (run 80).
- mutation: `DatabaseSave.GROUPS` drops `size` → `DatabaseGrowExpand`'s Save test red, 400 `PORT.FIELD.UNEXPECTED` (run 81).
- mutation: `DatabasePort.ActionViolations` admits a truncate target equal to the size (the rule sits there, not in `DatabaseRules`) → `DatabaseActions.TestTheArgumentRulesRefuseBeforeAnyVendorCall` alone red, a write recorded (run 74); admitting a grow to the size → `DatabaseGrowExpand.TestTheGrowRulesRefuseBeforeAnyVendorCall` red (run 115).
- mutation: `ActionViolations` ignores `Mounted` → `DatabaseActions.TestTheStatesAnOperationForbidsAreRefused` alone red, writes recorded (run 75).
- mutation: `Prohibited`'s dismount arm removed → both `DatabaseActionsProhibited` dismount tests red, writes recorded (run 85); the arm refusing every type → `TestTheOtherOperationsOfAProtectedDatabaseArePermitted` alone red (run 118); a failed own-set read ignored → `TestAnOwnProbeAndAFailedOwnSetReadAreRefused` alone red (run 119).
- mutation: `ActionBody` sends no `Globals` → `DatabaseIntegrity.TestOneDatabaseAndASetAreCheckedOnBothCallers` alone red (run 76); sends one member of a set → the same test alone red (run 112); an empty set admitted → `TestTheRefusalsSendNoCall` alone red (run 111).
- mutation: `DatabasePort.ParsedMembers` keeps order → `DatabaseIntegrity`'s set and canonical tests red (run 77), `EntityRef.TestTheIdRuleTableIsDeclaredAndIsWhatNormalizationApplies` red (run 78); `entity-ref.ts` keeps order → `entity-ref.test.mjs`'s directoryset test red; the flow store sends the checked order → `database-integrity.store.spec`'s canonical-set test red, and over a rebuilt bundle the browser AC6 leg red.
- mutation: `LogSourcePort.IntegrityChecks` oldest first → `DatabaseIntegrity`'s log and set tests red (run 95), and the browser AC6 and AC7 legs red; `log-viewer.page.ts` reverses the checks → `log-viewer.spec`'s Integrity-log leg red. Every line `info` → `TestTheLogsShapesOverArmedChecks` alone red (run 113); `INTEGRITYPAIRS` without Operate → `TestTheOperateReaderReadsTheLogOverTheWire` alone red (run 114).
- mutation: `osmgmt.databasedetails.compact` true in `Baseline` → `GovernanceBaseline.TestThePurgeIsTheOneDisabledLine` red (run 86), `DatabaseActions.TestAtTheBaselineTheAgentIsRefusedAndTheScreenProceeds` red (run 87).
- mutation: `DatabaseCompact.WRITERESOURCE` "" → both `DatabaseActionsGate` tests red, the declared-pairs principal refused 403 naming `:WRITE` (run 88); `DatabaseMount.WRITERESOURCE` "" → `DatabaseDescriptor.TestTheDiskOperationsDeclareTheirTypesArgumentsAndPairs` red (run 120).
- mutation: `DatabaseMount.CLASSICPAGES` "" → `ClassicPageGate`'s assigned-page and roster tests red (run 89), `MappingDescriptor.TestTheClassicPagesRosterIsTheDeclaringTools` red (run 90).
- mutation: `BackgroundTaskPort.Rows` skips the database rows → `BackgroundTasks.TestADatabaseTaskIsListedOnceWithItsDatabase` alone red (run 91); `BackgroundTasksLive` stays green (run 92), since its live admin API compact is linked to its own row and pinned by the next line.
- mutation: `BackgroundTaskPort.Linked` drops `TaskLinks` → `BackgroundTasks`' listed-once test red (run 93), `BackgroundTasksLive.TestAnAdminApiCompactIsListedAndPausedThroughAsyncResult` red, the admin row naming no database (run 94).
- mutation: `DatabaseRules.DirectoryViolations` skips the volume-directory test → `DatabaseGrowExpand.TestAVolumeDirectoryInUseIsRefused` red on its mint legs (run 82); `DatabasePort`'s own refusal removed → the same test red on its confirm (run 83). The Save leg holds under either, and under both still answers 422 on `volumePath` (run 84) (inference: the vendor's #575/#576 through `PROPERTYFAULTS`). `PROPERTYFAULTS` without `576` → `TestTheVendorsVolumeFaultsLandOnVolumePath` red (run 117); `ActionBody` sends no `InitialSize` → `TestAddAVolumeOnBothCallers` red (run 116).
- mutation: the self-queued refusal removed from `AdminPort.Sequence` → `AdminPortAsync.TestAnUnadmittedDiskOperationIsRefusedBeforeItQueues` red, the legs reaching the endpoint (run 121); the refusal ignoring `QUEUEDWRITES` → `DatabaseActions.TestCompactAndDefragmentAreQueuedAndFinish` alone red (run 122).
- mutation: `warning-dialog.ts` draws `.ocu-field-label` in `--ocu-surface`, rebuilt and redeployed → `database-operations.browser-spec`'s AC1 (Truncate) and AC3 (Add a volume) dialog walks red at 1.04:1 light and 1.08:1 dark.
- mutation: `IMPACT_ACTIONS` drops Database details, rebuilt → the browser AC5 leg red (no advisory); the editor store sends the file group beside a size → the browser AC3 leg red at the sent body.
- mutation: `command-bar.ts` and `command-box.ts` draw a primary action's row twin → `command-bar.spec` and `command-box.spec` drawn-once tests red.
- mutation: each client spec's own named mutation (the app reset, the report parse, `selectShown`, the change-bus subscription, Size in the file group, Add a volume while dirty, `absorbApplied`, the globals offer, the step check, `SCREEN_ACTION_DESCRIPTORS`, the mount's `WARNING_VALUES`, `IMPACT_ACTIONS`, `continues`, the dialog's flag and Proceed, `IMPACT_PARTS`) → its own named test red.
- mutation: `AdminPort.AwaitTask` forgets the task at its bound → `DatabaseActions.TestAStartedOperationLeavesItsTaskToTheWorker` red, the row gone at the answer, and `TestAPausedAdminCompactIsListedOnceOnItsAdminRow` red, its admin row gone (run 143).
- mutation: `DatabaseActionProbe.SecondReads` reads a missing file → `DatabaseIntegrity.TestOneDatabaseAndASetAreCheckedOnBothCallers` red at its before count, -1 (run 139, beside the next two, each red in its own test).
- mutation: `DatabaseRules.Validate` skips `IntegrityViolations` → `DatabaseIntegrity.TestTheGlobalsStepAnswersEachViolationOnItsField` red on all three cases (run 139).
- mutation: `DatabaseRules.ActionProblem` names no dismounted member → `DatabaseIntegrity.TestTheRefusalsSendNoCall` red at the mint's dismounted leg (run 139).
- mutation: `DatabasePort.Snippet` ignores the payload's directory → `DatabaseActions.TestThePortsOwnReadBodiesAndScripts` red on its `MODIFYSIZE` and `EXPANDVOL` legs (run 142, beside the next two, each red in its own test).
- mutation: `DatabasePort.Action` drops the mount's 409 mapping → `DatabaseActions.TestAVendorConflictOnAMountIsTheMountedRefusal` red, `PORT.CONFLICT` (run 142).
- mutation: `BackgroundTaskPort.Linked` drops `TaskLinks` → `DatabaseActions.TestAPausedAdminCompactIsListedOnceOnItsAdminRow` red, the compact listed on a database row (run 142).
- mutation: `BackgroundTaskPort.Snippet` drops its database branch → `BackgroundTasks.TestTheScriptRendersBothBranches` alone red, the database row reading the job log (run 137).
- mutation: `LocalDatabaseList` declares no secondary entity type → `DatabaseDescriptor.TestTheListIsOsManagementsSeventhEntryKeyedByName` alone red (run 136).
- mutation: `DatabaseDefragment.WRITERESOURCE` "" and `LocalDatabaseGrow.POLLRESOURCE` "" → `DatabaseActionsGate.TestEachMissingPairIsRefusedBeforeAnyPortCall` red on the defragment legs and on the grow's Save and agent confirm, and `TestExactlyTheDeclaredPairsWriteOnBothCallers` red on its defragment legs (run 145).
- mutation: `operationLine` answers "" for `continues` → the still-running legs of `database-details.page.spec` and `database-editor.page.spec` red; `savedText` ignores `continues` → the editor's continuing-Save leg red; the expand's `hintKey` dropped → the editor's Add a volume leg red at its hint; then `actionRefusal` answers "" → the details' 409 leg red, and `onAddVolume` without `setRefusal` → the editor's 409 leg red.
- mutation: the expand's `hintKey` dropped, rebuilt and redeployed → `database-operations.browser-spec`'s AC3 red at the hint.
- mutation: `DataTable.menuItems` lists a primary action's row twin → `data-table.spec`'s Story 18.4 menu-column test red; the same drawing is what `databases.browser-spec`'s five-cell pin refused.
- mutation: `ScreenRead`'s logsource roster left at eight → `TestEveryDeclaredLogSourceReadFieldIsAKeyOfTheLiveRow` red at 9 in the full sweep (run 417); corrected to nine, green (run 521).

## Auto Run Result

Status: done
Blocking condition: none

**Implement (2026-09-29, baseline `5b1bde51`).** Parts A-C as planned: eight action-style disk tools through `DatabasePort`'s `Database.Actions` branch and its `STATE` read, the dismount arm of `PROHIBITED.OCUPILOTDATABASE`, `SELFQUEUEDTYPES`, the `directoryset` rule, DW-1791 and DW-1821, the Check integrity flow and the Integrity log, the warning dialog's advisory, flag and field, and the eight keys in `Baseline.cls` `false`.

- **For the runner (amendments, Rule 5/20):** `osmgmt.databasedetails.dismount` also declares `%Admin_Manage:USE`, the pair the dismount arm's own-set read needs (`Namespace.Namespace` `GET`, `Database.ConfigCRUD` `LIST`, measured). AD-8's 18.4 paragraph and the intent's "dismount and truncate: Database details' pairs only" need that case; the owner call is in `deferred:`.
- **Deviations from Tasks, each verified:** Check integrity is also a declared row action, because the action route admits only row actions. The command bar, the command box and `data-table.ts` draw an action declared as both once, as the primary, so the Databases rows keep five cells (the pin is restored). `DatabaseSave.Send` sends no body for a body-less tool. The truncate-target rule lives in `DatabasePort.ActionViolations`, which `DatabaseRules` asks. `panel.browser-spec`'s paused-chip leg moved to the Free-space view: Databases' General bar is two lines at 1280 docked whether the chip is paused or not (90 px, measured). `ScreenRead`'s logsource roster is nine.
- **Task 0:** recorded under Design Notes › Measured at implement; no HALT. The log needs only `%DB_IRISSYS:READ` from the vendor, and a volume lands in the database's own directory.
- **Files:**
  - Server: `Api/DatabaseError.cls`, `Api/Router.cls`, `Area/OsMgmt/DatabaseRules.cls`, `Area/OsMgmt/DatabaseSave.cls`, `Kernel/EntityRef.cls`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Impact.cls`, `Kernel/Proposal/Prohibited.cls`, `Port/AdminPort.cls`, `Port/BackgroundTaskPort.cls`, `Port/DatabasePort.cls`, `Port/LogSourcePort.cls`.
  - Descriptors: `DatabaseDetails`, `DatabaseList`, `LocalDatabaseList`, and the new `DatabaseIntegrity` and `DatabaseIntegrityLog`.
  - Under `Screen/Tool/`, the new base `DatabaseAction` and its eight tools.
  - 43 test classes (17 new).
  - Client: the Database details, editor, integrity flow and log-viewer pages and stores, `warning-dialog.ts`, `screen-action-handler.ts`, `command-bar.ts`, `command-box.ts`, `data-table.ts`, `entity-ref.ts`, `impact.ts`, `strings.ts`, `screens.generated.ts`, their specs, the screen mirror and six `ui/tools` tests, and `angular.json`.
  - Browser: `database-operations`, `databases`, `panel`.
  - Also EXPERIENCE.md (993 lines) and `ci-throwaway.sh`'s class lines.
- **Review:** 27 findings. 14 entries patched (7 medium, 7 low) as R1-R13 plus the row-menu fix. 3 deferred to `deferred:`. The rest rejected with reasons in the Review Triage Log.
- **Verification on `ocupilot-b-ci`:**
  - Story classes green through run 151.
  - Full ObjectScript sweep, runs 152-520: 369 classes and 3025 tests, one failure. `ScreenRead`'s logsource roster read 9 against 8; it was corrected and re-run green (run 521).
  - Client: `npm test` 1701 tools and 1880 components; `npm run build` passes.
  - Browser specs `database-operations`, `databases`, `local-databases` and `background-tasks`: 16/16.
  - The DW-1337 structural walk: 12/12, no violation outside the baseline.
  - `smoke.sh`: 49/49.
  - `check-objectscript` and `lint-docs` are clean.
- **Rosters, re-derived from the instance:** 168 tools (106 writes), baseline 106 keys (11 disabled), 85 descriptors, 39 entity types, 29 covered Prohibited types, 23 Prohibited codes unchanged.
- **Bundle:** 2,226,872 bytes. `maximumWarning` is re-based to 2338 kB under DW-1166.
- **Read once:** #7846 reads 0 before and after, in `messages.log` and `alerts.log`.
- **Cleanup:** no `OCUPROBE184*` configuration, directory, resource, user, role, background task, integrity check or `%DB_OCUGATE184` remains. `DatabaseActionsGate`'s least-privileged principals left 773 finished async rows that `ForgetTask` may not delete (DW-1137; AD-37's sweep takes them after 24 h). They were removed by hand.
- **Follow-up review recommended** (true; patched 7 medium, 7 low, 0 high). The dismount pair awaits the runner's amendment. R1's started leg relies on a 20 MB defragment outlasting the port's single poll, which a faster host could finish first.
- **Residual risks:** canceling a Database-source row through `%SYS.BackgroundTask` leaves its admin API row Running (in `deferred:`). The integrity report's error branch is unverified (in `deferred:`).

**Plan (2026-09-29):** the stage gate's payloads were observed on `ocupilot-b-ci` before any form was planned (Design Notes › Measured). Task 0 closes three questions the plan could not settle: the integrity log's least-privileged read, where a volume lands with no new volume directory, and the `STATE` read's field sources.

- Probe objects created on `ocupilot-b-ci` and removed, with removal re-read:
  - databases `OCUPROBE184A` and `OCUPROBE184B`, with their configurations, resources `%DB_OCUPROBE184A` and `%DB_OCUPROBE184B` and their roles;
  - directories `ocuprobe184a/`, `ocuprobe184b/`, `ocuprobe184a-vol/`, `ocuprobe184a-vol2/` and `ocuprobe184-notadb/`;
  - namespace `OCUPROBE184NS`, role `OcuProbe184R` and user `OcuProbe184User`;
  - about 40 async task rows, each read once and deleted;
  - `%SYS.BackgroundTask` rows 15-30 with their integrity output globals.
- Afterwards: no `OCUPROBE184*` configuration, database, resource, role, user, namespace or directory remains, and no async task or `%SYS.BackgroundTask` row since 15:28. #7846 was counted 0.
