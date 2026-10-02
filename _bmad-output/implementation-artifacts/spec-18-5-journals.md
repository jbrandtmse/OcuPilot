---
title: 'Story 18.5: Journals'
type: 'feature'
created: '2026-10-02'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot has no journal screens. The classic Journals page (System Operation) and the Journal Settings page (System Administration) are still the only way to list journal files, read a file's summary, check a file's integrity, switch the journal file or directory, browse a file's records, or change journal settings (catalog SA-04, SO-01 to SO-06). The admin API carries all seven, but it has four flaws. The record list answers half its `maxRows`. It runs its filter operator as code. It takes a journal file as a full path. And its settings `PUT` checks neither types nor directories.

**Approach:** OS management gains two listed screens:

- **Journals** (position 13): the file list. It has screen-level Switch file and Switch directory and a per-file Check integrity. Each file name opens **Journal file details**, which shows the summary and the file's databases and offers View records.
- **Journal settings** (position 14): a form-page editor.

**Journal records** is an unlisted record browser with server criteria, reached from a file through a screen arrival. A record opens the **journal record detail** dialog, which shows the values on this screen only.

How it is built:

- The port changes:
  - `AdminPort` gains a journal guard. It takes a file only by a name the instance's own list answers, sends the record filter's column and operator only from closed sets, and doubles the record list's `maxRows`.
  - A new `Port/JournalPort` (extends `AdminPort`) composes the switches' `STATE` read, builds the integrity body and resolves the settings directories through `PathPort`.
- **Task 0** observes every route, payload, duration, effect, pair and audit event on `ocupilot-b-ci` before anything is built, and restores the journal state it found.
- **DW-1797:** `PathPort`'s instance-file refusal also covers every directory the journal history lists and the write-image journal directory.
- The story is in three parts, so the orchestrator can split along them (Design Notes › Size):
  - **Part A:** Journals, file details, the switches, integrity, the guard and DW-1797.
  - **Part B:** settings.
  - **Part C:** the record browser and detail.

## Boundaries & Constraints

**Always:**

- **Task 0 runs first, on `ocupilot-b-ci` only, and halts on any contradiction** (Tasks › Task 0). It works on `OCUPROBE185*` objects it creates and removes. Every journal setting it changes is restored, and journaling ends in the directory it used at S0.
  - The journal files that its switches create are the instance's transaction record. No test ever deletes one, because `ByTimeReverseOrder` stops at the first missing file. They age out under the instance's own purge.
  - Purge settings are only ever raised and then restored, never lowered.
- **Screens.** Every one declares at least three suggested prompts from the closed group vocabulary (`Screen/Registry.cls` `PROMPTGROUPKEYS`). No `classicLinkExemption` is declared.

  | Descriptor | Route | Archetype | Pos | Entity type | Pairs | `classicPage` |
  | --- | --- | --- | --- | --- | --- | --- |
  | `JournalList` | `os-management/journals` | list | 13 | `journal-file`, id `Name` | `%Admin_Operate:USE`, `%DB_IRISSYS:READ` | `%cspapp.op.utilsysjournals` |
  | `JournalFileDetails` | `os-management/journals/:id` (parent `JournalList`) | detail | 0 | `journal-file` | as Journals | `%cspapp.op.utilsysjournalsummary` |
  | `JournalFileDatabaseList` | `os-management/journals/:id/databases` (parent `JournalList`) | list | 0 | `journal-file-database`, id `SFN` | as Journals | `%cspapp.op.utilsysjournalsummary` |
  | `JournalRecordList` | `os-management/journal-records` (not under `journals/`, where `:id` would match it) | list (server criteria) | 0 | `journal-record`, id `Address` | as Journals | `%cspapp.op.utilsysjournal` |
  | `JournalSettings` | `os-management/journal-settings` | form-page | 14 | `journal-settings` (singleton) | `%Admin_Manage:USE`, `%Admin_Journal:USE` (own pair, AD-8), `%DB_IRISSYS:READ` | `%CSP.UI.Portal.Journal` |

  Their `toolIdentifier`s are `osmgmt.journals`, `osmgmt.journalfile`, `osmgmt.journalfiledatabases`, `osmgmt.journalrecords` and `osmgmt.journalsettings`, each read tool being `<identifier>.read`. The classic page names are spelled as `%SYS.Portal.Resources.NormalizePage` answers them; Task 0 records each spelling. The settings pairs are the classic page's own check: `%OnPreHTTP` requires both `%Admin_Manage` and `%Admin_Journal` (`irissys/%CSP/UI/Portal/Journal.cls:310-316`).
- **Tools.** Each reaches its port and declares its pairs and `CLASSICPAGES` as below. Each is refused by name before any port call, and each `PrivilegePairs` ends in `Gate.WithClassicPages`.

  | Tool | Descriptor | Port | Kind | Write type | Fresh read / subject | Extra pairs | `CLASSICPAGES` |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | `osmgmt.journals.switchfile` | `JournalList` | `JournalPort` | action (AD-51), bodyless; literal id `current` | `Journal.Settings` `SWITCHFILE` | `STATE` / `CurrentFile` | `%DB_IRISSYS:WRITE` when Task 0 step 5 measures a refusal without it | `%cspapp.op.utilsysjournalproperties` |
  | `osmgmt.journals.switchdirectory` | `JournalList` | `JournalPort` | as above | `SWITCHDIR` | `STATE` / `CurrentFile,CurrentDirectory` | as switch file | `%cspapp.op.utilsysjournalswitchdirectory` |
  | `osmgmt.journals.integrity` | `JournalList` | `JournalPort` | action; port-built body (AD-51); queued (AD-26) | `Journal.File` `INTEGRITYCHECK` | `GET` / `FileGUID` | none expected; whatever Task 0 step 4 measures | `%cspapp.op.utilsysjournalintegrity` |
  | `osmgmt.journalsettings.update` | `JournalSettings` | `JournalPort` | merge (AD-4); id `instance` | `Journal.Settings` `PUT` | `GET` | `%Admin_FileSystemAccess:USE` when a directory root is sent; `%DB_IRISSYS:WRITE` when Task 0 step 6 measures a refusal without it | none (the descriptor's own page) |

  A measured extra pair is always one of these; any other pair halts the story (Task 0 step 9).

- **Journal files are named only by the instance's list** (proposed AD-21 eighth case).
  - On `Journal.File` `GET` and `INTEGRITYCHECK` and `Journal.Record` `LIST` and `GET`, `AdminPort` accepts `file` only when it equals, character for character, a `Name` that `Journal.File` `LIST` answers at that call. The list is read whole at every call and never cached.
  - Any other name is refused 404 `JOURNAL.FILE.UNLISTED` before that call. No refusal echoes the name.
  - On `Journal.Record` `LIST` an omitted or empty `file` reads the newest listed file.
- **The record filter is never code a caller writes.**
  - `matchColumnName` is one of `TimeStamp, ProcessID, TypeName, ExtTypeName, InTransaction, GlobalNode, DatabaseName, MirrorDatabaseName`. `matchOperator` is one of `=`, `'=`, `]]`, `']]`, `[`, `'[`. Anything else is refused 400 `JOURNAL.FILTER.SHAPE`. The vendor splices the operator into an `XECUTE` (`irissys/%SYS/Journal/Record.cls:593`), so this is enforced in the port as well as by the criteria's `options`.
  - The three are sent whole when `matchValue` is non-empty and dropped whole when it is empty. The vendor queues a partial triple anyway, unfiltered.
  - `initialOffset` is digits only, else 400 `JOURNAL.OFFSET.SHAPE`.
- **The record list's halving is the port's to absorb.** For `Journal.Record` `LIST`, `AdminPort` sends twice the `maxRows` it was asked. Truncation is still judged as size above the cap (`Screen/Read.cls:562`). The page always offers Next records from its last row, because rows a caller cannot read also spend the vendor's budget.
- **Record values are screen-only** (proposed AD-36 sentence).
  - `GET /journal/record` answers one record for the detail dialog, under `JournalRecordList`'s pairs and the file rule.
  - `NewValue`, `OldValue` and `GlobalReference` never reach a read tool, screen context, the model, the ledger or a log line. Each is cut at 1,000 characters ending in U+2026, and rendered as text.
  - The list's eight fields, `GlobalNode` among them, are ordinary, as the Locks list's references are.
- **Settings.**
  - The form shows all 13 template fields. Ten are settable: `CurrentDirectory`, `AlternateDirectory`, `BackupsBeforePurge`, `DaysBeforePurge`, `FileSizeLimit`, `FreezeOnError`, `JournalFilePrefix`, `JournalcspSession`, `PurgeArchived`, `CompressFiles`.
  - `ArchiveName`, `wijdir` and `targwijsz` are shown and never set, and are omitted from the body (proposed AD-4 named exception; reasons in Design Notes).
  - Each directory is chosen with the server-path picker (`primaryRoot`/`primaryPath`, `alternateRoot`/`alternatePath`). It is resolved through `PathPort` as a vendor-writes directory at the mint and again at the write, and it must already exist (`JOURNAL.DIRECTORY.ABSENT`). An unchanged directory is sent as read.
  - Rules:
    - `FileSizeLimit` is a whole number from 1 to 4079 (`JOURNAL.FILESIZE.SHAPE`; 0 is refused, inference).
    - `DaysBeforePurge` is a whole number from 0 to 100, and `BackupsBeforePurge` from 0 to 10 (`JOURNAL.PURGE.SHAPE`; `irissys/Config/Journal.cls:64-80`).
    - `JournalFilePrefix` matches `^[A-Za-z0-9._-]{0,64}$` (`JOURNAL.PREFIX.SHAPE`).
    - Booleans must be JSON booleans (`JOURNAL.BOOLEAN.SHAPE`).
    - The classic Save's rule holds (`Journal.cls:198-208`): with an empty `ArchiveName`, `PurgeArchived` is sent false; with `PurgeArchived` true, both purge counts are sent 0, and the form disables them.
- **Async.**
  - `Journal.Record` `LIST` is a self-queued read and needs no parameter (`AdminPort` `InvokeLocated` → `AwaitTask`).
  - `Journal.File` `INTEGRITYCHECK` joins `MUTATINGTYPES` and `QUEUEDWRITES`, with no secret in its body. Its finished console lines are read once, by the port's one poll. Past the bound it answers started (202, `continues`), with read-back `unchecked`.
  - No client reads `async-result`.
- **Governance.** All four keys join `Baseline.cls` `true`. No switch erases anything, the directory switch is undone by a second one, the check changes nothing, and the settings edit is an ordinary merge. If the story commits after 2026-10-04, the runner asks the owner first (AD-22).
- **Contended files are add-only.** Epic 19 is concurrent on slot A, so these files only gain lines or list members:
  - `Api/Router.cls`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Gate.cls` (not edited), `Screen/Tool/Classification.cls`;
  - `scripts/ci-throwaway.sh`, `ui/angular.json`, `ui/src/app/core/strings.ts`, `ui/src/app/core/navigation.ts`, EXPERIENCE.md;
  - the rosters `ReadTool`, `SurfaceCoverage`, `Wire`, `PortGate`, `Governance`, `GovernanceBaseline`, `ToolDispatch`, `ToolEmit`, `ToolRoundTrip`, `ClassicPageGate`, `MappingDescriptor` and `Test/Prohibited.cls`.

  One-line list members and roster counts are unioned and summed by whichever story reaches feature second. EXPERIENCE.md stays at 999 lines, and every shifted `/** EXPERIENCE.md:n */` citation is updated. New codes go in `Api/JournalError.cls`, never `Error.cls`. `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged.

**Never:**

- No journal purge, restore, profile, mirror or cluster journal view (catalog SO-13 to SO-15: P3, no route).
- No archive-target choice, WIJ change, journaling start or stop, or `FreezeOnError` self-test.
- No caller path. No `file` except a listed name. No filter column outside the eight, so neither `NewValue` nor `OldValue` is ever matchable.
- No auto-refresh on any journal screen. It would make AD-43's roster ten; a switch's change event re-reads the list.
- No client polling of `async-result`, no read of a task row outside the port, no write from a child job, and no listing from an escalated frame.
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses. No direct `Config.*`, `SYS.*` or `%SYS.Journal.*` write in product code; test-only `%SYS` seeding is allowed.
- No deletion of a journal file by any test.
- No spine or epics.md edit. The runner writes the amendments and corrections listed in Design Notes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| List (A) | Stock throwaway, about 110 files | Journals and `osmgmt.journals.read` answer the same rows: Name, Size, CreationTime, Reason, DataSize, newest first. The side bar lists Journals 13th and Journal settings 14th, both under OS management. | none |
| Details (A) | Open a file's name | The summary fields, with `PrevFile.File` and `NextFile.File`. Its databases list reads the same `GET`'s `Databases`. | none |
| Unlisted file (A, C) | `file=/tmp/x.001`, or a listed name with a trailing `z` | Refused before the vendor call for the target, on the details, the records, the record dialog and integrity | 404 `JOURNAL.FILE.UNLISTED` |
| Switch file (A) | Either caller; current file F | `SWITCHFILE` with no body. The list re-reads with a new newest file. The card and the dialog name F. | none |
| Switch moved (A) | Another switch happens between mint and confirm | The confirm is refused, because the fingerprint moved, and nothing switches | the proposal closes target-changed (`REASONTARGETCHANGED`, existing) |
| Switch directory, one directory (A) | `CurrentDirectory` equals `AlternateDirectory` (stock) | Refused. Nothing switches. | 409 `JOURNAL.SWITCHDIR.NOOTHER` |
| Switch directory (A) | Probe alternate `<mgr>ocuprobe185alt/` configured | The current file lands in the alternate. A second switch returns it to the primary. | none |
| Integrity, clean (A) | A closed file; flag Check every record off, then on | Queued `{CheckDetails:false|true}`. Then "Integrity check finished." and "No errors were found in <file>." | none |
| Integrity, errors (A, seam) | The seam answers two console lines | "Errors were found in <file>." and both lines, on the page and the card only. The tool result, ledger and context carry no line. | none |
| Integrity, started (A, seam) | The seam answers `PORT.TIMEOUT` | 202 `continues`, the still-running sentence, read-back `unchecked` | none |
| DW-1797 (A) | An overwriting file consumer names a file in the probe former journal directory, or in a WIJ directory seeded through the fixture | Refused like a journal file | `PATH.INSTANCE` (existing) |
| Settings Save (B) | `FileSizeLimit` 1024 to 1000 | `PUT` of the ten settable keys read fresh, with one diff row. The three shown-only keys are omitted. Read-back `matches`. | none |
| Settings directory (B) | Primary set to root `<mgr>`, name empty; or a missing name; or a name under `csp/ocupilot/` | Refused on the field before any vendor call | `PATH.MANAGERDIR` / `JOURNAL.DIRECTORY.ABSENT` / `PATH.SERVED` |
| Settings shapes (B) | `FileSizeLimit` 0 or 5000; `DaysBeforePurge` 101; prefix `a/b`; `FreezeOnError` sent as the string `"true"` | Refused on the field before any vendor call | `JOURNAL.FILESIZE.SHAPE`, `.PURGE.SHAPE`, `.PREFIX.SHAPE`, `.BOOLEAN.SHAPE` |
| Records (C) | Probe database `OCUPROBE185D` with 30 journaled sets of `^OcuProbe185`; cap 10 | `maxRows` 22 sent, 11 kept, 10 shown, truncated. Next records starts after the last row. | none |
| Records filter (C) | Column GlobalNode, operator `[`, value `OcuProbe185` | Only probe rows | none |
| Filter injection (C) | Operator `=1) x "set ^X=1" //`, or column `NewValue` | Refused before any vendor call: by the read's own criterion check through the screen and the tool, and by the port when `AdminPort` is reached directly | 400 `READ.CRITERION` (read) / `JOURNAL.FILTER.SHAPE` (port) |
| Partial triple (C) | Column and operator with no value | Sent unfiltered with no match keys | none |
| Unreadable database (C) | A principal with Journals' pairs and no `%DB_OCUPROBE185D:READ` (nor `%DB_OCUPILOT:READ`) | The probe and OcuPilot rows are absent from the list, and the dialog answers 404 for them | 404 `JOURNAL.RECORD.UNREADABLE` |
| Record detail (C) | Click a probe row | The dialog shows type, time, process, database, node and the values as text. `osmgmt.journalrecords.read` and screen context carry no value. | none |
| Missing pair | Each tool's declared extra pair missing | 403 naming it; zero port calls | `AUTH.NOPRIVILEGE` |
| Integration | Journals' actions, the details page's databases read, the record page's arrival, the settings Save | Each consumes `JournalPort` or `AdminPort`'s guard on the real throwaway and shows the effect named above | as above |

</intent-contract>

## Code Map

**Vendor** (hidden classes exported read-only to `/tmp/epic-18-d6/185/vendor/`; re-export from `ocupilot-b-ci` if they are gone):

- `Journal.Settings`:
  - GET and PUT take `%Admin_Manage` or `%Admin_Journal`; `SWITCHFILE` and `SWITCHDIR` take `%Admin_Operate` (`:14-21`).
  - GET answers 13 keys (`:29-49`).
  - **PUT merges.** It copies only the keys present (`:71-85`): `wijdir` and `targwijsz` go to `Config.config.Modify`, the rest to `Config.Journal.Modify`. It checks no types and no directories, and a `Modify` failure answers 500.
  - `SWITCHFILE` calls `RollToNextFile` (`:102-106`).
  - `SWITCHDIR` calls `GetTheOtherDirectory` and answers 409 when no other directory exists, otherwise swaps the primary and the alternate (`:109-122`; `irissys/%SYS/Journal/System.cls:81-126`). Both answer `{CurrentFile}`.
  - Routes: `Port/AdminRoutes.cls:116-120`.
- `Journal.File`, `%Admin_Operate` (`:10-13`):
  - Every type but `LIST` requires `file`, and `ValidateSemantics` answers 404 for a missing file.
  - `LIST` is `ByTimeReverseOrder` (`Name, Size, CreationTime, Reason, DataSize`), taking `maxRows`.
  - `GET` is the summary (`:82-146`).
  - `INTEGRITYCHECK` has `ShouldRunAsync` 1 and a required body `{CheckDetails}` (`:42-45`, `:149-163`). It answers `{}`, and its findings are the task's console lines (`AsyncTaskEndpoint.cls:81-93`; `AsyncTask.GetConsoleOutput`).
- `Journal.Record`, `%Admin_Operate`:
  - `LIST` (`POST /journal/file/records`) self-queues `Journal.ListTask`. That task runs `%SYS.Journal.Record:List` over the eight columns and increments its row counter twice per kept row (`ListTask.cls:72-93`). It skips rows on a database the caller's base roles cannot read.
  - `GET` takes `file` and `address` and answers 404 for an unreadable database (`Record.cls:78-145`).
- **Measured at plan, read-only, `ocupilot-b-ci`, 2026-10-02:**
  - Primary and alternate are both `/durable/iris/mgr/journal/`; the current file is `…/20261002.046`.
  - 110 files; closed files carry a `z` on disk; `wijdir` "" (the manager directory) and `targwijsz` 0; `IRIS.WIJ` 1.83 GB in `/durable/iris/mgr/`.
  - Timings: `GET /journal/settings` 0.015 s; `/files` (110 rows) 0.207 s; `/file` 0.037 s (86 `Databases`); `/file/record` 0.035 s.
  - `Config.Journal` ranges: `irissys/Config/Journal.cls:54-111`.
- Classic pages: `irissys/%CSP/UI/Portal/Journal.cls` (settings: `RESOURCE` :21, `SaveData` :187-240, `%OnPreHTTP` :310-316). The record browser is `irissys/%CSP/UI/System/OpenJournalPane.cls`: columns :400-407, operators and fields, page size 250 (:138), detail :567-620. The `%cspapp.op.*` pages are deployed stubs.

**`Port/AdminPort.cls`** (3,207 lines):

- Parameters: `TYPESUFFIXES` :123, `MUTATINGTYPES` :408, `BODYLESSTYPES` :424, `QUEUEDWRITES` :671, `SELFQUEUEDTYPES` :680, `ASYNCTIMEOUT` :776.
- Methods: `Invoke` :959, `InvokeLocated` :968 (a 202 with a Location goes to `AwaitTask` :1061), `IsQueuedWrite` :2386, `EndpointType` :2422, `Sequence` :2543 (a non-mutating `ShouldRunAsync` type is queued at :2591), `AwaitTask` :2641-2683 (returns `tAnswer.Result` only), `Snippet` :3015.
- `TYPEFAULTS` reads `Error.cls` parameters (:1101), so journal codes are raised with `Refuse` and `JournalError`'s reasons, never through `TYPEFAULTS`.

**Models:**

- `Port/DatabasePort.cls`: `COMPOSEDTYPES` :156, `State` :356, `Action` :437, started conversion :459-464, `Snippet`.
- `Port/RemoteDatabasePort.cls`: a port extending a port.
- `Screen/Tool/TaskManagerSuspend.cls`: a screen-level action on a literal id (`MANAGERID`), with `STATE`-like fields.
- `Screen/Tool/DatabaseIntegrityCheck.cls`: `POLLRESOURCE`, queued.
- `Screen/Tool/LocalDatabaseUpdate.cls`: `volumeRoot`/`volumePath` :10-51, `ArgumentPairs` :162-168, `PathPort.Resolve(...,KINDDIRECTORY,...,0,1)` :133.
- `Screen/Tool/ExplorerWrite.cls` `WriteOutput` :140: the `output` channel; `Kernel/Proposal/Operation.cls` `OutputOf` :189; `Confirm.cls` :520; `Api/ScreenAction.cls` :379.
- `Screen/Tool/Write.cls`: `PortQuery` :440, `ArgumentProblem` :809.

**Read grammar:**

- `Screen/Read.cls`:
  - `maxRows` set to cap+1 at :516 (also :386, :416, :432), with truncation at :562;
  - `SeedCriteria` :941-1012 (`vendorParam`, `default`, `options`);
  - secret fields are dropped for the screen and the tool alike (:284), so the record values cannot be `secretFields`.
- `Screen/Registry.cls`:
  - `ReadProblem` :1041, source keys :1068, port list :1071;
  - `CriteriaProblem` :1449; the parent-scoped rule takes exactly one criterion (:1506);
  - `RowsProblem` :2046-2066, which excludes `GET` today;
  - `CRITERIARESERVEDPARAMS` :1394, so the order criterion is `order`, not `direction`.
- `ui/tools/screen-mirror.mjs`: `rowsProblem` and the source-key list :1186.
- `Test/ReadSourceCorpus.cls`, `Test/CriteriaCorpus.cls`.
- Models:
  - parent-scoped single-object GET: `TaskRunList.cls` :70-78 and Task details;
  - server criteria: `AuditList.cls`, `areas/logs/audit.page.ts`/`audit.store.ts` (the detail dialog :123-127);
  - arrival: `core/screen-arrival.ts`, `areas/logs/log-hub.page.ts:617-620` (a person's arrival with criteria), `areas/tasks/history.page.ts:193-212`.

**Path:** `Port/PathPort.cls`:

- seams header :20-28; `Resolve` :266; the overwrite refusal at :341; `InstanceFile` :412;
- `InJournalDirectory` :516-532, which refuses when its read fails;
- `JournalDirectories` :636-656; `JournalSources` :664-679.

Tests: `Test/PathPortFixture.cls` :107-132; `Test/PathPortInstance.cls` `Journals()` :134, :266, :328, :369, :461; `Test/PathPortServed.cls` :240, :289. The history source is `%SYS.Journal.File:ByTimeReverseOrder` (`irissys/%SYS/Journal/File.cls:988-1027`), which follows header back-pointers across directories and stops at the first missing file.

**Kernel:**

- `Kernel/EntityType.cls:57` `TYPES` (42); `Kernel/EntityRef.cls:59` `IDRULES` (`auditing-configuration:singleton` is the model).
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250, the type gate :1012, `ReviewedFewOnly` :2781, `PermittedChangeFields` :791. 18.4's `database` entry is the permitted-action model.
- `Kernel/Governance/Baseline.cls` :21-56 (`osmgmt.*`).
- `Screen/Area.cls:75`: OS management's set is `%Admin_Operate`, `%Admin_Manage`, `%DB_IRISSYS:READ`, which is why `%Admin_Journal` is an own pair.

**Errors and routes:**

- `Api/Error.cls`: the `ReasonForViolation` chain :1409-1419, `ReasonForDatabase` :1516, `DatabaseViolationCodes` :1509, `ReasonForToolCode` :1222. `Api/LockError.cls` is the sibling model.
- `Api/Router.cls`: generic screen routes :142-144; 18.16's routes :138-141 and their wrappers; the Services form and Save :192-193, :1530-1542.
- Services editor model: `Area/Permissions/ServiceRules.cls`, `ServiceSave.cls`.

**Client** (`ui/src/app/`):

- `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :128-180.
- `shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :64-98, `UNDRAWN_ACTIONS` :260, `VALUE_FLAGS` :297, `ACTION_ADDRESS` :313, `DESTRUCTIVE_ACTIONS` :325, `WARNING_CONSEQUENCES` :435, `WARNING_VALUES` :467; Task Manager ids :185-202.
- `shell/command-bar.ts:784-792`, `core/screen-actions.ts:42-57,107,183`, `areas/tasks/task-schedule.page.ts:155` (screen-level actions).
- `shell/warning-dialog.ts` (one flag or one whole number).
- `areas/os-management/database-operation.ts` `operationLine` :17; `namespace-list.page.ts:166-176,212-251` (the running line).
- `areas/os-management/database-details.page.ts`/`.store.ts` (a detail page issuing another screen's read).
- `areas/permissions/service-editor.page.ts`/`.store.ts` (the editor); `areas/os-management/database-editor.store.ts:402` `setVolumeLocation` with `shell/server-path-picker.ts:108` (a directory picker).
- `core/turn.ts:431,470,1385` (the confirm's `output.lines`); `core/strings.ts` (18.16's block :3796, 18.4's :3947); `app.ts` sign-out resets :643-656, pinned in `app.spec.ts`.
- `ui/angular.json:54` `maximumWarning` 2459kB, against a measured 2,458,172 bytes (`ui/tools/angular-json.test.mjs:400-414`).

**EXPERIENCE.md** (999 lines):

- :164 the OS management side bar;
- :173 Dialogs;
- :377 the running and finished lines (18.4) and :516 the still-running sentence, both reused;
- :378 the Devices and Namespaces fixed strings, where this story's strings are appended;
- :651 the screens with server-side criteria;
- :523 the prompt groups.

**Rosters.** Re-derive each from its class's red, never by hand:

- ObjectScript:
  - `Navigation` :482-483, `Wire` :705, `WireSecurityRead` :558-568, `WireAreaAnyScreen` :105-111 and :271;
  - `ReadTool` :93-94, `Descriptor` `ReadShapes` :67 and the entity count :1712;
  - `SurfaceCoverage` XData, `EndpointCoverage` XData Probes :73, `ScreenRead` :208;
  - `ToolRoundTrip` :55, `ToolDispatch` :167, `Governance`, `GovernanceBaseline` :13, `ClassicPageGate` `Roster()`/`OWNPAIRS`, `MappingDescriptor` `CLASSICROSTER`;
  - `PortGate` :28, `AdminPortAsync` :91-93, `PortFixture` :21, `DraftRegistry`, `ToolEmit`, `Prohibited` (test) :615;
  - **`ToolWrite` :1196-1209, :1245, :1343-1355** name `Journal.Settings/PUT` as an unissued `TYPEPUT`. Part B re-points them to another endpoint that declares `TYPEPUT` and whose PUT no tool issues, read from `AdminPort`, as Story 9.8 did.
- Client: `ui/tools/navigation.test.mjs` :177, :197, :295-307; `navigation-wire.test.mjs` :215, :313, :645; `shell/rail-wire.spec.ts` :220, :318, :709.
- Browser: `license-usage.browser-spec.mjs:128-145` and `remote-databases.browser-spec.mjs:300` pin the full OS management list (DW-1774).

**CI:** `scripts/ci-throwaway.sh` arming blocks (`DATABASE_CONFIG` :457, `NAMESPACE_CONFIG` :439, `PRINCIPALS` :295); `ui/tools/ci.test.mjs:2086-2207`.

**Test models:**

- `Test/RemoteDatabaseProbe.cls` (`Snapshot`, `Diff`, timed `Run`, `RemoveAll`);
- `Test/DatabaseWriteProbe.cls` (probe database seeding);
- `NamespaceWriteGate.RunAs` :266;
- `Test/RemoteDatabaseListingPort.cls` (a seam port);
- `Test/DatabaseRecordPort.cls` `Call`;
- `ui/browser/remote-databases.browser-spec.mjs` (`docker exec` seeding; the DW-1337 gate).

## Tasks & Acceptance

**Scope after the split (orchestrator merge gate 2026-10-02, Rule 5): this story builds Part A only.** That is Task 0 steps 1, 2, 4, 5, 7 and 8 (step 3 is Story 18.19's, step 6 Story 18.18's), Execution A, AC0-AC6 and AC9-AC11, the Part A test classes (`JournalRead`, `JournalWrite`, `JournalIntegrity`, `JournalWriteGate`, `JournalDescriptor`, `PathPortInstance`, `PathPortServed`), and three descriptors (Journals, Journal file details, Journal file databases) with their nine prompts, strings and EXPERIENCE.md lines. **Execution B (AC7) moves to Story 18.18 and Execution C (AC8) to Story 18.19**: build neither, nor their descriptors, prompts, strings, EXPERIENCE.md lines, `JournalRecords` or `JournalSettingsWrite`; those stories' plans start from these sections. The guard's file rule may already name `Journal.Record`, which 18.19 consumes; the record filter's closed sets, the doubled `maxRows` and the settings `PUT` branch are 18.19's and 18.18's.

**Task 0: the implement stage's first task, before any tool, descriptor or form.** Run it on `ocupilot-b-ci` only. Load with `/tmp/epic-18-d6/load-throwaway.sh`. Record every result under Design Notes › Measured at implement, and every AD sentence in `## Spec Change Log` for the runner.

1. **Plumbing.**
   - `Port/AdminPort.cls` gets its Part A entries (Execution A, first bullet), so the types are reachable.
   - Write `src/OcuPilot/Test/JournalProbe.cls`, providing:
     - `Snapshot`: the current file and `GetState()`; `Config.Journal` and `Config.config` `wijdir`/`targwijsz`; the file count and newest five names; the probe directory listings; the `Api.Admin.Util.AsyncTask` row count; the monitor state; the `messages.log` and `alerts.log` line counts and ERROR #7846 count; and OcuPilot's own objects.
     - `Diff`, a timed `Run(endpoint, type, query, body)` through `AdminPort`, and `RunAs` (the `NamespaceWriteGate.RunAs` idiom).
     - `SeedProbeDatabase` (`OCUPROBE185D` in `<mgr>ocuprobe185d/`, with resource `%DB_OCUPROBE185D` and 30 sets of `^OcuProbe185`), `SeedAlternate` (test-only `Config.Journal.Modify` of `AlternateDirectory` to `<mgr>ocuprobe185alt/`, created first), `RestoreJournal` (`Config.Journal` back to S0) and `RemoveAll`.
2. **Read-only checks.** Record:
   - whether `LIST`'s first `Name` equals `GetCurrentFileName()`, and whether a closed file's name carries `z`;
   - durations of `LIST` (all), the largest file's `GET` and one record `GET`;
   - whether `Journal.File` `GET` with an extra `maxRows` answers 400;
   - the exact `NormalizePage` spellings of the seven classic pages;
   - whether `SWITCHFILE` and `SWITCHDIR` record a vendor audit event (auditing on);
   - `ByTimeReverseOrder` and `Config.config.Get` run as a principal holding only `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`.
3. **Records (Part C).** After `SeedProbeDatabase`, on the current file:
   - `LIST` with `maxRows` 10 and 40 (record kept rows);
   - with `initialOffset` set to a kept row's `Address`: whether that row is returned again (inclusive);
   - `reverse` 1;
   - a filter of GlobalNode `[` `OcuProbe185`, and a full-file scan with a filter that matches nothing (duration against `ASYNCTIMEOUT`);
   - the async-task row count after each read;
   - as `OcuProbe185T0User` (Journals' two pairs plus the install namespace's code read, without `%DB_OCUPROBE185D:READ`): the kept count for `maxRows` 40, the absence of probe and `OCUPILOT` rows, and `GET` of a probe record (expected 404).
4. **Integrity (Part A).** `INTEGRITYCHECK` with `{CheckDetails:false}` and then `true`, on the largest closed file:
   - the 202, the poll answer's members (which one holds the console lines), the duration, and the effects (expected: none beyond the task row, which the port removes);
   - the `RunAs` principal with Journals' two pairs: refused or not, and what each missing pair answers.
5. **Switches (Part A).**
   - `SWITCHFILE`: the new current file; duration; pairs as `RunAs` with Journals' pairs, then plus `%DB_IRISSYS:WRITE`.
   - `SWITCHDIR` with one directory: 409 as measured.
   - `SeedAlternate`, then `SWITCHDIR`: the current file is in `ocuprobe185alt/`. `SWITCHDIR` again: back to the primary. Pairs as for `SWITCHFILE`.
   - `RestoreJournal`.
6. **Settings (Part B).**
   - `PUT` of the fresh `GET`'s ten settable keys unchanged: no change, events recorded.
   - `PUT {FileSizeLimit:1000}` alone: merge confirmed, no other key changed. Restore it.
   - `PUT {CurrentDirectory:"<mgr>ocuprobe185none/"}` (absent): what the vendor stores, refuses or creates; the current file is unchanged. Restore it.
   - Whether `CurrentDirectory` is stored with a trailing slash when sent without one (this fixes `compare`).
   - Pairs as a principal holding `%Admin_Manage:USE`, `%Admin_Journal:USE` and `%DB_IRISSYS:READ`, then plus `%DB_IRISSYS:WRITE`.
   - Audit events.
7. **DW-1797.** After step 5, `ocuprobe185alt/` is a former journal directory. Record that `ByTimeReverseOrder` names its file, and the call's duration.
8. **Cleanup proof.** `RemoveAll` and `RestoreJournal`; then S2. S2 equals S0 except:
   - counters;
   - the new journal files the switches created (one in `ocuprobe185alt/`, kept);
   - `messages.log` lines about the switches.

   `Config.Journal` and `Config.config` are byte-equal to S0, and journaling writes in S0's directory.
9. **HALT** `blocked`, with blocking condition `intent gap: observation contradicts the plan: <what>` and nothing built, if:
   - any route used here cannot be reached through `AdminPort`; or `LIST`, `GET` or record `GET` answers 202; or `INTEGRITYCHECK` or records `LIST` does not answer 202;
   - `LIST`'s first `Name` is not the current file;
   - any read or `INTEGRITYCHECK` changes stored state other than the vendor's task row, or a task row outlives the port's read;
   - a header-level check of the largest file exceeds `ASYNCTIMEOUT`;
   - the `RunAs` principal lists, or reads by `GET`, a record on a database it cannot read (AD-9);
   - a second `SWITCHDIR` does not return journaling to the primary;
   - the settings `PUT` erases an omitted key;
   - any step needs a pair outside the tables plus `%DB_IRISSYS:WRITE`, such as `%Admin_Secure` or `%All`;
   - S2 differs from S0 beyond the declared differences.
10. **Otherwise, set from the record:**
    - each tool's extra pairs;
    - the doubling factor: 2 while the list halves, 1 if it does not;
    - the next-page rule: start at the last `Address`, and drop a first row equal to it when the offset was measured inclusive;
    - the console member that `AwaitTask` carries;
    - `CurrentDirectory`/`AlternateDirectory` `compare` (`unslashed` if the vendor appends `/`);
    - the classic page spellings;
    - the AD-15/AD-53 named cases for any write with no vendor event.

    If a records scan or a detail-level check exceeds `ASYNCTIMEOUT`, record it under Named limits; it is not a halt.

**Execution A: Journals, details, switches, integrity, the guard, DW-1797 (AC1-AC6, AC9, AC10):**

- `src/OcuPilot/Port/AdminPort.cls` (add-only):
  - `MUTATINGTYPES` gains `Journal.Settings/PUT`, `/SWITCHFILE`, `/SWITCHDIR` and `Journal.File/INTEGRITYCHECK`, each with its measured fact. `INTEGRITYCHECK` changes nothing and is admitted for the write path, as `Database.Actions/INTEGRITYCHECK` is.
  - `BODYLESSTYPES` gains `SWITCHFILE` and `SWITCHDIR`. `QUEUEDWRITES` gains `Journal.File/INTEGRITYCHECK`.
  - `CONSOLEDTYPES = "Journal.File/INTEGRITYCHECK"`: `AwaitTask` answers `{Result, console}` for a listed pair, taking the console from the poll answer's measured member and keeping at most 200 lines, the last replaced by U+2026 when cut.
  - `JOURNALFILETYPES`, `HALVEDROWTYPES`, `JOURNALMATCHCOLUMNS` and `JOURNALMATCHOPERATORS` hold the Boundaries' rules. A private `JournalGuard`, called by `Invoke` before `Sequence` for a listed pair, applies the file rule (one `Journal.File` `LIST` with `maxRows` 0), the newest-file default, the filter and offset rules, and the doubling. Each refusal goes through `Refuse` with `JournalError`'s reason.
  - `Snippet` renders the guard's `LIST` (AD-59).
- `src/OcuPilot/Port/JournalPort.cls` (new, extends `AdminPort`):
  - `COMPOSEDTYPES` `Journal.Settings/STATE` answers `{CurrentFile, CurrentDirectory}` from `Journal.File` `LIST` `maxRows` 1, the directory being the name's parent.
  - `INTEGRITYCHECK` builds `{CheckDetails}` from the tool's declared boolean and refuses a caller body. A `PORT.TIMEOUT` becomes started (`STARTEDHTTP`, the `DatabasePort` :459 model).
  - `SWITCHDIR`'s vendor 409 maps to `JOURNAL.SWITCHDIR.NOOTHER`.
  - The `PUT` branch is Part B's.
  - `Snippet` mirrors every branch.
- `src/OcuPilot/Port/PathPort.cls`, for **DW-1797**:
  - New seams `JournalHistoryDirectories(Output)` (the parent of every `ByTimeReverseOrder` `Name`) and `WijDirectory(Output)` (`Config.config` `wijdir`, with an empty value meaning `ManagerDirectory()`), each read in `%SYS` at every call.
  - `JournalDirectories` unions both with the three sources it reads today; a failed read still refuses.
  - Update the header seam list :20-28 and the `InstanceFile` doc :407-411. `Test/PathPortFixture.cls` gains `UseJournalHistory` and `UseWijDirectory`.
- Tools (`src/OcuPilot/Screen/Tool/`, new), per the Boundaries table:
  - `JournalSwitchFile.cls` and `JournalSwitchDirectory.cls` (the `TaskManagerSuspend` model: `MANAGERID`-style literal `current`, `ArgumentProblem` and `ScreenActionDelta` refusing any other id);
  - `JournalIntegrityCheck.cls`, with argument `CheckDetails` (boolean, default false), `SCREENVALUES` `integrity=CheckDetails`, `POLLRESOURCE` `%Admin_Operate`, and `WriteOutput` answering `{lines}` from the port (the `ExplorerWrite` :140 model). No line reaches `ToolResult`, the ledger or a log line.
  - Each has a `Consequence`:
    - switch file: "The instance closes <file> and starts a new journal file."
    - switch directory: "The instance starts writing its journal in the other configured journal directory."
    - integrity: "The instance reads <file>. Checking every record takes longer."
- `src/OcuPilot/Screen/Descriptor/JournalList.cls`, `JournalFileDetails.cls` and `JournalFileDatabaseList.cls` (new), per the Boundaries table:
  - Journals: fields `Name, Size, CreationTime, Reason, DataSize`; `rowActions` `switchfile`, `switchdirectory`, `integrity`; the name cell opens details.
  - Details: the single-object `GET` with route criterion `file`, and the scalar fields `CreationTime, FileCount, MaxSize, FileGUID, FirstRecordAddress, LastRecordAddress, End, EncryptionKeyID, MinTransFileCount, MinTransFileIndex, ClusterStartTime, PrevFile.File, NextFile.File`.
  - Databases: `{"port":"admin","endpoint":"Journal.File","type":"GET","rows":"Databases"}` with route criterion `file`, and fields `SFN, DatabasePathOrAlias`.
  - The fifteen prompts, three per descriptor (the two Execution B and C descriptors' included) [SPLIT 2026-10-02: this story ships the first three descriptors' nine; Journal records' and Journal settings' move to 18.19 and 18.18]:
    - Journals (Capacity): "Which journal file is the instance writing now?" · "How much space do the journal files use?" · "Why was the journal last switched?"
    - Journal file details (Troubleshooting): "When was this journal file created?" · "Which journal files come before and after this one?" · "Is this journal file encrypted?"
    - Journal file databases (Troubleshooting): "Which databases have records in this journal file?" · "How many databases does this journal file cover?" · "Does this journal file hold records for IRISSYS?"
    - Journal records (Troubleshooting): "Which processes wrote these journal records?" · "Which globals changed in these records?" · "Are any of these records inside a transaction?"
    - Journal settings (Capacity): "Where does this instance write its journal files?" · "When are old journal files purged?" · "Does a journal write error freeze the instance?"
- `src/OcuPilot/Screen/Registry.cls`, `Screen/Read.cls` and `ui/tools/screen-mirror.mjs`: `source.rows` is also admitted on a `GET` (proposed AD-36 sentence). It issues the `GET` once, without `maxRows` (or with it, if step 2 measured that `GET` takes it), and cuts to the cap; a 404 reads as no rows. Add a case to `Test/ReadSourceCorpus.cls`.
- `src/OcuPilot/Kernel/EntityType.cls` gains `journal-file`, `journal-file-database`, `journal-record` and `journal-settings`. `EntityRef.cls` `IDRULES` gains `journal-settings:singleton`. Mirror both through `screen-mirror.mjs` and `scripts/check-objectscript.py`'s type list.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only): `journal-file` and `journal-settings` join `COVEREDTYPES` with permitted entries (the 18.4 `database` model). `journal-settings` admits Part B's ten fields. No predicate.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only): the four keys, `true`.
- `src/OcuPilot/Api/JournalError.cls` (new; the `LockError` model) holds the codes and sentences below. `Api/Error.cls` gains only the dispatch lines in `ReasonForViolation` and `ReasonForToolCode` and a `JournalViolationCodes` call.
  - `JOURNAL.FILE.UNLISTED` (404): "This instance's journal file list does not name that file."
  - `JOURNAL.SWITCHDIR.NOOTHER` (409): "This instance has one journal directory. Set a different alternate directory in Journal settings first."
  - `JOURNAL.FILTER.SHAPE` (400): "Choose a column and a comparison from the lists."
  - `JOURNAL.OFFSET.SHAPE` (400): "Enter a record offset as a whole number."
  - `JOURNAL.RECORD.UNREADABLE` (404): "That record is not in this file, or its database is one you cannot read."
  - `JOURNAL.DIRECTORY.ABSENT` (422): "That directory does not exist on the instance. Create it, then choose it."
  - `JOURNAL.FILESIZE.SHAPE` (422): "Enter a whole number of megabytes from 1 to 4079."
  - `JOURNAL.PURGE.SHAPE` (422): "Enter a whole number: up to 100 days, or up to 10 backups."
  - `JOURNAL.PREFIX.SHAPE` (422): "Use up to 64 letters, digits, dots, hyphens or underscores."
  - `JOURNAL.BOOLEAN.SHAPE` (422): "Choose on or off."

**Execution B: Journal settings (AC7):**

- `src/OcuPilot/Screen/Tool/JournalSettingsUpdate.cls` (new):
  - `READTYPE` `GET`, `WRITETYPE` `PUT`, `SENDSBODY` 1, id `instance`.
  - `EXCLUDEDFIELDS` `ArchiveName,wijdir,targwijsz`. The directories are handled as `LocalDatabaseUpdate` handles `NewVolumeDirectory`: the arguments are `primaryRoot`/`primaryPath` and `alternateRoot`/`alternatePath`, and `ArgumentPairs` adds `%Admin_FileSystemAccess:USE` when a root is sent.
  - `ArgumentProblem` runs `JournalRules.Problem`.
  - `Consequence` applies when `FreezeOnError` turns true: "With Freeze on error on, a journal write error blocks every process that journals until it is fixed."
- `src/OcuPilot/Port/JournalPort.cls`, the `PUT` branch:
  - Resolve each sent root through `PathPort.Resolve(..., KINDDIRECTORY, ..., 0, 1)` and refuse a missing directory. Both happen at the write as well as at the mint.
  - Apply the purge rule, then send the complete settable set with the three shown-only keys omitted.
  - Map a vendor 500 to its field when its status names one.
- `src/OcuPilot/Area/OsMgmt/JournalRules.cls` (new): `Problem` (the shapes, types and purge rule from the Boundaries; a directory refusal on its field).
- `src/OcuPilot/Area/OsMgmt/JournalSave.cls` (new; the `ServiceSave` model): `PUT /journal/settings` through the tool (AD-55). Faults become violations on their fields.
- `src/OcuPilot/Screen/Descriptor/JournalSettings.cls` (new): a form-page with the single-object `GET` read of the 13 fields, its tool behind Save, and `ownPrivileges` `[%Admin_Journal:USE]`.
- `src/OcuPilot/Screen/Tool/Classification.cls`: entries for the ten settable fields (all ordinary; the directories' `compare` from step 6). Then regenerate `ToolFields.cls` with `cd ui && node tools/field-lists.mjs`.
- `src/OcuPilot/Test/ToolWrite.cls`: re-point the `Journal.Settings/PUT` legs (Code Map › Rosters).
- `src/OcuPilot/Api/Router.cls` (add-only): `PUT /journal/settings` and its thin wrapper.

**Execution C: the record browser and detail (AC8):**

- `src/OcuPilot/Screen/Descriptor/JournalRecordList.cls` (new):
  - read `{"port":"admin","endpoint":"Journal.Record","type":"LIST"}`, fields `Address, TimeStamp, ProcessID, TypeName, ExtTypeName, InTransaction, GlobalNode, DatabaseName`;
  - criteria (the `AuditList` model):
    - `file` (text, maxLength 1024);
    - `offset` → `initialOffset` (text, maxLength 20);
    - `order` → `reverse` (choice `0`/`1`, default `0`);
    - `column` → `matchColumnName` (choice of the eight, default `GlobalNode`);
    - `operator` → `matchOperator` (choice of the six, default `[`);
    - `value` → `matchValue` (text, maxLength 200);
  - no parent scope;
  - context fields as read, `secretFields` `[]`.
- `src/OcuPilot/Area/OsMgmt/JournalRecordDetail.cls` (new): `GET /journal/record?file=&address=`.
  - It gates on `JournalRecordList`'s pairs through `Screen.Gate`, checks that `address` is digits, and calls `AdminPort` `Journal.Record` `GET` (guarded).
  - It answers `{record}` with every vendor field, each value cut at 1,000 characters ending in U+2026. A vendor 404 answers `JOURNAL.RECORD.UNREADABLE`.
  - It is not a declared read, so no tool reaches it.
- `src/OcuPilot/Api/Router.cls` (add-only): `GET /journal/record` and its wrapper. `Test/EndpointCoverage.cls` gets the two new routes' probe rows.

**Client (AC1-AC8, AC11):**

- `ui/src/app/areas/os-management/`, each new file with its spec:
  - `journal-list.page.ts`, the `task-schedule.page.ts` model:
    - it registers screen-level Switch file and Switch directory, which `shell/command-bar.ts` draws add-only beside the Task Manager actions;
    - Check integrity is a row action behind the warning dialog with the flag "Check every record";
    - the running line becomes the finished line plus the verdict and, on errors, the lines, as text;
    - View records sets a `ScreenArrivals` arrival `{file: Name}` and navigates.
  - `journal-file-details.page.ts`/`.store.ts`: the summary, the databases screen's read (AD-5) and View records.
  - `journal-records.page.ts`/`.store.ts`:
    - the criteria form and "Records of <file>", or "Records of the current journal file" when the echo is empty;
    - Next records, per Task 0's next-page rule;
    - a row click opens `journal-record-dialog.ts`, which reads `/journal/record` and renders every value as text, never markup.
  - `journal-settings.page.ts`/`.store.ts`: the `service-editor` model, two `server-path-picker` directory changes (the `setVolumeLocation` model), the shown-only fields read-only, the purge counts disabled while `PurgeArchived` is checked, the sticky Save and the unsaved-changes guard.
  - `journal-actions.ts`.
- `shell/screen-outlet.ts`, `shell/screen-action-handler.ts` (the warning consequences and the integrity flag), `core/screen-actions.ts`, `core/strings.ts` (new keys with their `/** EXPERIENCE.md:n */`) and `app.ts` (store injection and sign-out reset, pinned in `app.spec.ts`), all add-only. Regenerate `core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`.
- `ui/angular.json`: re-base `maximumWarning` under DW-1166 to the measured initial total rounded up to the next kB, and update `ui/tools/angular-json.test.mjs:400-414`. Stop and ask above 3800kB.
- EXPERIENCE.md, in place, keeping 999 lines:
  - :164 gains "Journals (Stage 2, Story 18.5: in System Operation, not Logs) · Journal settings (Stage 2, Story 18.5)".
  - :173 gains "journal record detail (the journal record browser's, Story 18.5)". The warnings parenthetical gains "switch the journal file; switch the journal directory; check a journal file's integrity, carrying a check-every-record flag", tagged `[ADDED <date> - Story 18.5]`.
  - :378 gains every new label and sentence, the three consequences, the verdict lines "No errors were found in <file>." and "Errors were found in <file>.", "Records of the current journal file", "Next records", "No records match.", the empty states and the fifteen prompts.
  - :651 gains "Journal records".
  - Then run `cd ui && npm run test:tools`.

**Rosters and CI.**

- Extend every roster in Code Map › Rosters.
- In `scripts/ci-throwaway.sh` (add-only), add `OCUPILOT_ALLOW_JOURNAL` with its own `# classes:` line, because no narrower variable names "switches the journal and changes its settings". Add the probe-database classes to `DATABASE_CONFIG`'s `# classes:` line and the gate class to `PRINCIPALS`'s. Keep `ui/tools/ci.test.mjs` equal.

**Tests:**

- `src/OcuPilot/Test/JournalProbe.cls`: Task 0's helper. `RemoveAll` and `RestoreJournal` run before all tests, after each and after all.
- `Test/JournalRead.cls`:
  - Journals and its read tool answer one read; the details and the databases list;
  - the file rule on every guarded pair, with zero vendor calls for the target;
  - the newest-file default.
- `Test/JournalRecords.cls` (`DATABASE_CONFIG`, `PRINCIPALS`):
  - the doubling, the cap and truncation, Next records, the filter, the injection refusals, and the partial triple;
  - the unreadable-database principal;
  - the detail route's gate, cut and 404;
  - no value in the tool view or context.
- `Test/JournalWrite.cls` (`JOURNAL`), each leg on both callers:
  - switch file, the moved fingerprint, the one-directory refusal, and switch directory there and back;
  - integrity clean at both levels;
  - read-backs.
- `Test/JournalIntegrityPort.cls`, a seam port answering console lines or `PORT.TIMEOUT`. `Test/JournalIntegrity.cls` covers the errors and started legs, and asserts that no line reaches `ToolResult`, the ledger row or context.
- `Test/JournalSettingsWrite.cls` (`JOURNAL`): the Save and the agent's confirm; the complete set without the shown-only keys; the directory refusals; the shape refusals; the purge rule; the read-back.
- `Test/JournalWriteGate.cls`, with `JournalWriteGateProbe.cls` (`PRINCIPALS`): each declared pair refused by name, with zero port calls.
- `Test/JournalDescriptor.cls`: the five descriptors' pairs, prompts and classic pages, and the rows-on-GET grammar case.
- `Test/PathPortInstance.cls` gains the former-directory leg (live, after a seeded alternate switch) and the WIJ leg (through the fixture), beside :266 and :461.
- `ui/browser/journals.browser-spec.mjs`, seeding over `docker exec`:
  - the side bar's thirteenth and fourteenth entries;
  - the list; Switch file through its dialog and the new newest row; Switch directory refused on a stock throwaway;
  - Check integrity's finished verdict; details with databases;
  - View records with a probe filter and the record dialog;
  - the settings form's manager-directory refusal;
  - the DW-1337 structural gate in both themes.

**Acceptance Criteria:**

- **AC0:** Given every journal route on `ocupilot-b-ci`, when the implement stage starts, then Task 0's payloads, durations, effects, pairs and audit events are recorded before any tool, descriptor or form exists, and S2 equals S0 apart from the declared differences. A contradiction halts the story.
- **AC1:** Given the instance's journal files, when Journals opens and `osmgmt.journals.read` runs, then both answer the same rows newest first. The side bar lists Journals 13th and Journal settings 14th under OS management, and the Logs area lists neither.
- **AC2:** Given a listed file, when its details open, then the summary and its databases list read that file's `GET`. Given an unlisted name on any guarded route or tool, the answer is `JOURNAL.FILE.UNLISTED`, and the vendor is not called for it.
- **AC3:** Given current file F, when a person switches the file or the agent's proposal is confirmed, then `SWITCHFILE` is sent with no body and the list shows a new newest file after the change event. A switch made since the mint refuses the confirm.
- **AC4:** Given one configured directory, when either caller switches the directory, then it is refused `JOURNAL.SWITCHDIR.NOOTHER` and nothing switches. Given a distinct alternate, journaling moves there, and a second switch returns it.
- **AC5:** Given a listed file, when either caller checks its integrity, then the body is `{CheckDetails}` from the flag, the page shows the finished line and the verdict, and on errors the lines appear on the page and the card only. Past the bound, the answer is started.
- **AC6 (DW-1797):** Given a former journal directory and a WIJ directory, when an overwriting file consumer names a file in either, then `PathPort` refuses it as it refuses a journal file.
- **AC7:** Given Journal settings, when a person saves or the agent's proposal is confirmed:
  - the complete ten-key set is sent, read fresh, with the three shown-only keys omitted;
  - a directory comes only from the picker, and is refused when it is the manager directory, OcuPilot's served directory or a missing directory;
  - each shape and the purge rule refuse on their field before any vendor call;
  - the read-back reads `matches`.
- **AC8:** Given probe records, when Journal records opens from a file:
  - a page shows at most the cap from twice the cap plus two asked, marks truncation, and continues with Next records;
  - a filter column or operator outside the closed sets is refused, and a partial triple is sent unfiltered;
  - rows of an unreadable database are absent;
  - the record dialog shows values that no read tool, context or ledger row ever carries.
- **AC9:** Given each tool, when its caller lacks a declared pair, then it is refused `AUTH.NOPRIVILEGE` naming that pair, with zero port calls.
- **AC10:** Given governance, when the story lands, then Part A's three write keys (switch file, switch directory, check integrity) are in `Baseline.cls`, `true`; the settings key lands with Story 18.18.
- **AC11:** Given the rosters, when the story lands, then every roster and pinned side-bar list includes the new screens and tools, every screen has three prompts, the DW-1337 gate holds in both themes, and EXPERIENCE.md reads 999 lines.

## Spec Change Log

- 2026-10-02, spec gate (runner, Rule 5, by=merge_gate): the orchestrator approved the split. This story is Part A (Tasks & Acceptance › scope block; AC10's key count; the prompt and test lists). Part B is Story 18.18 "Journal settings" and Part C Story 18.19 "Journal record browser" in `epics.md`, each planned from this spec's sections. The runner writes only Part A's spine amendments now (Design Notes › 1 in part, 3 in part, 4 in part, 5, 6 in part, 7, 10 in part); amendment 2 (AD-8) follows Task 0, 8 (AD-4) is 18.18's, and the record filter and record values sentences of 1 and 6 are 18.19's.

- 2026-10-02, spec gate (runner, Rule 5 tier 1): epics.md's 18.5 block (:7184-7185) and `epic-18-context.md` corrected at origin. Was: "`switch-dir` takes no body, so it switches only to the alternate directory already configured. The specification agrees." Now: it swaps between the configured primary and alternate directories and answers 409 when they are the same (vendor source `System.cls:81-126`; Task 0 measures it). The record list's halving gains its cause (the counter steps twice per kept row, `ListTask.cls:88,93`), so doubling is exact only when no row is skipped. The split (Design Notes › Size) and the spine amendments wait for the orchestrator's decision.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: the guard sits in `AdminPort`, and `JournalPort` extends it. No vendor-class call is made, so no AD-27 case is needed.
- AD-3, AD-4: derived fields, and the settings' complete set less the named exception.
- AD-5, AD-36, AD-44: one descriptor per screen; rows on a `GET`; the classic pages and `CLASSICPAGES`; the own pair.
- AD-6, AD-34, AD-40, AD-51, AD-53, AD-55, AD-56 (ii): proposals, action subjects, two callers, and `SCREENVALUES`.
- AD-7, AD-9: an async read in a turn queues a vendor task row, as the audit list has since Release 1; nothing is spawned.
- AD-8, AD-29: pairs, the own pair, and the least-privileged runs.
- AD-10: the existing set; no new predicate.
- AD-11, AD-21, AD-24: the file rule (eighth case), the filter whitelist, the vendor-writes directories (sixth case) and DW-1797; values screen-only.
- AD-13, AD-14: four entity types; switches use the literal `current`.
- AD-15, AD-53: named cases per Task 0.
- AD-22: the baseline.
- AD-26: `QUEUEDWRITES` and the self-queued read.
- AD-39: the integrity lines join the fifth exception.
- AD-43: no auto-refresh.
- AD-58, AD-59: read-back and `Snippet`.

**Decisions:**

- **The file is an enum value, not a path.** Every journal route takes a full path. Accepting it only as the instance's own list spells it is what the seventh case did for a remote directory. A file copied elsewhere, or a non-journal file, is never opened.
- **The guard lives in `AdminPort`.** Reads reach `AdminPort` directly through `Screen/Read.cls`, so the guard must sit there to bind the screen and the tool alike. A new read port would mean a grammar change.
- **The switches act on `current`.** `STATE` reads only `Journal.File` (`%Admin_Operate`). The settings `GET` that names the other directory requires `%Admin_Manage` or `%Admin_Journal`, which the classic switch page (`%Admin_Operate`) does not. So the card says "the other configured journal directory", and the vendor's 409 is the precondition. That 409 comes before any switch (`Journal.Settings.cls:113-118`).
- **WIJ and the archive target are shown, never set.** A `wijdir` change activates at once and moves the file the instance recovers from after a crash, 1.83 GB here. Observing it needs a restart path the runner may not use on `ocupilot-b-ci`. The admin API has no read of archive targets to choose from. Both stay classic-portal actions. Omitting them is safe because the vendor keeps an omitted key (`:71-85`; Task 0 step 6).
- **Record values are screen-only** under the AD-48 reasoning: the payload has no schema and can hold patient data or a secret that a vendor body journaled (AD-26's 16.14 paragraph). `GlobalNode` stays ordinary, as lock references do.
- **Journals stays in System Operation** (catalog judgment, `feature-catalog.md:681`; AC2 of the story).

**Named limits:**

1. A caller who cannot read some databases gets fewer rows per page, and the list may read as complete while later records remain. Next records always continues (`ListTask.cls:80`, inference until Task 0 step 3).
2. A records scan or a detail-level check longer than `ASYNCTIMEOUT` (30 s) fails, or answers started. A started check's verdict is not kept, because the port reads a task's end once (AD-26). Task 0 records the durations.
3. Between the vendor's queue and the port's delete, a record list's rows and filter sit in the vendor's task row in `IRISLOCALDATA`, whose `READ` is public. Past the bound they stay until the 24-hour sweep (AD-37). This is a candidate IRIS defect, human-owned, like DW-1527.
4. `ByTimeReverseOrder` stops at the first missing file, so a former directory older than a gap is not refused. The full history's readers are `[Internal]` (`History.cls:332-379`).
5. The integrity error branch is pinned through the seam only; a corrupt listed file cannot be made safely.
6. `SWITCHFILE` with journaling disabled answers a vendor 500 (inference, `System.cls:60-74`), rendered as `INTERNAL`.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate, then Task 0 confirms each `<measured>`):**

1. **AD-21, after the seventh case:** "**The eighth is a journal file** [AMENDED <date>, Story 18.5 spec gate, Rule 20]. Every journal route takes a full path, so `AdminPort` accepts a `file` on `Journal.File` and `Journal.Record` only when it equals, character for character, a `Name` the instance's journal file list answers at that call (`Journal.File` `LIST`, `%SYS.Journal.File:ByTimeReverseOrder`), read whole and never cached, and refuses any other `JOURNAL.FILE.UNLISTED` before that call; an omitted file on the record list reads the newest. The record list's filter column and operator are taken only from closed sets, because the vendor splices the operator into code it executes (`%SYS.Journal.Record` `ZUFetch`). A journal setting's directory is a sixth-case vendor-writes directory that must already exist. The overwrite refusal also covers every directory a file the journal list names sits in, and the write-image journal's directory (`Config.config` `wijdir`, the manager directory when empty), read at call time (DW-1797)."
2. **AD-8, after 18.16's paragraph:** "**Story 18.5's journal tools** [AMENDED <date>, Story 18.5 implement, Rule 20]: <measured pairs per tool>. Journal settings declares `%Admin_Journal:USE` as its own pair beside OS management's set, because the classic page requires `%Admin_Manage` and `%Admin_Journal` together, while the admin API takes either."
3. **AD-44, after 19.13's `CLASSICPAGES`:** "**Story 18.5's `CLASSICPAGES`** [AMENDED <date>, Story 18.5 spec gate, Rule 20]: switch file `%cspapp.op.utilsysjournalproperties`, switch directory `%cspapp.op.utilsysjournalswitchdirectory`, the integrity check `%cspapp.op.utilsysjournalintegrity`, each Hidden and spelled as `NormalizePage` answers; the settings update, performed by its descriptor's own page, none."
4. **AD-26, after 18.15's queued write:** "**Story 18.5's queued write** [AMENDED <date>, Story 18.5 spec gate, Rule 20]: `QUEUEDWRITES` also names `Journal.File` `INTEGRITYCHECK`, which queues through `ShouldRunAsync()`, carries a port-built `{CheckDetails}` and changes nothing; its console lines are read once with its end. `Journal.Record` `LIST` is a self-queued read, and because the vendor's list counts each kept row twice the port asks twice the rows it needs."
5. **AD-51, after 19.13's case:** "Story 18.5's case: `JournalPort`, which builds `Journal.File` `INTEGRITYCHECK`'s body from the integrity tool's declared `CheckDetails` and answers the switches' fresh read through a port-composed `STATE` type [AMENDED <date>, Story 18.5 spec gate, Rule 20]."
6. **AD-36, after 18.14's paragraph:** "**A single-object `GET` may also be read as a list over one named member** (`source.rows`, Story 18.5's journal file databases): it issues the `GET` once and cuts to the cap, and a 404 reads as no rows. **A journal record's values are screen-only** (Story 18.5): `NewValue`, `OldValue` and `GlobalReference` reach the record dialog through `GET /journal/record` under the record browser's pairs, never a read tool, screen context, the model, the ledger or a log line, because the payload has no schema and can hold patient data or a secret a vendor body journaled (AD-48's reasoning) [AMENDED <date>, Story 18.5 spec gate, Rule 20]."
7. **AD-39, the fifth exception:** add "and a journal integrity check's console lines (Story 18.5)" [AMENDED <date>, Story 18.5 spec gate, Rule 20].
8. **AD-4, after `LanguageServer`'s exception:** "**`Journal.Settings` is a named exception to the complete body** [AMENDED <date>, Story 18.5 spec gate, Rule 20]: it omits `ArchiveName`, `wijdir` and `targwijsz`, which its tool shows and never sets, because the vendor writes every key it carries and a WIJ key activates at once; the vendor keeps an omitted key (measured at Story 18.5's Task 0)."
9. **AD-15 and AD-53**, only for a write that Task 0 step 2, 4, 5 or 6 finds unaudited.
10. **AD-13:** "`journal-settings` is a singleton; a `journal-file` id is the instance's own spelling of the file's name and is kept exactly" [AMENDED <date>, Story 18.5 spec gate, Rule 20].

**Corrections for the runner (Rule 5 tier 1, at their origin):**

- epics.md :7184 and `epic-18-context.md:33` say `switch-dir` "switches only to the alternate directory already configured". It swaps between the primary and the alternate, and answers 409 when they are the same (`System.cls:81-126`).
- The halving is a counter that steps twice per kept row (`ListTask.cls:88,93`), and doubling is exact only when no row is skipped.

**Size (multiple goals).** This is about twice Story 18.16, with seven surfaces in three independently shippable parts. The recommended split, the orchestrator's call:

- 18.5 keeps Part A.
- A new 18.18 "Journal settings" takes Part B.
- A new 18.19 "Journal record browser" takes Part C, which consumes Part A's guard.

Each part's Task 0 steps, tasks, tests and ACs are separable as marked: A is AC0-AC6, AC9-AC11; B is AC7; C is AC8. **Decided 2026-10-02 (orchestrator merge gate): split as recommended; 18.5 is Part A, Story 18.18 Part B, Story 18.19 Part C.**

**Integration ACs.** `JournalPort` and the `AdminPort` guard are new, and their consumers are in this story:

- Journals' actions (AC3-AC5 in `JournalWrite`, against the real throwaway);
- the details page's databases read (AC2);
- the record page's arrival and reads (AC8 in the browser spec);
- the settings Save (AC7).

The `PathPort` widening is consumed by every overwriting file consumer: 16.4's task export and 19.13's XML export (AC6).

**Consumes:**

- 18.1's `PathPort` and picker;
- 18.4's queued-write, started and running-line patterns;
- 16.11's screen-level actions;
- 16.9's `ScreenArrivals`;
- 19.2's `output` channel;
- 16.13's editor;
- 16.17's read-back, 14.1's `Snippet` and 14.2's baseline.

**Consumed-by:**

- 18.12: the agent's tool parity.
- Any later story taking a journal file, through the eighth case.

**Ledger inbox (Rule 17):** DW-1797 is addressed by Execution A's `PathPort` bullet, AC6 and the `PathPortInstance` legs.

**Contended files and footprint.** Every contended file is edited add-only (Boundaries). No footprint extension: every other file is new or in Epic 18's paths.

## Verification

**Setup (slot B):**

- Load with `/tmp/epic-18-d6/load-throwaway.sh` (no restart), never through the MCP loader.
- Every write lands on `ocupilot-b-ci`, on `OCUPROBE185*` objects and on journal state that `RestoreJournal` restores.
- Run one test class per call. Send the next only once the previous run has landed in `%UnitTest_Result`, and never re-submit after a client timeout.
- Arm each class per call with `docker exec -e OCUPILOT_ALLOW_JOURNAL=1`, plus `-e OCUPILOT_ALLOW_DATABASE_CONFIG=1` and `-e OCUPILOT_ALLOW_PRINCIPALS=1` where the class declares them.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expected: 0 failures each, with totals checked against `%UnitTest_Result`.
  - The story's own classes: `JournalRead`, `JournalWrite`, `JournalIntegrity`, `JournalWriteGate`, `JournalDescriptor`, `PathPortInstance`, `PathPortServed` (`JournalRecords` and `JournalSettingsWrite` moved to 18.19 and 18.18 at the split).
  - The rosters: `ReadSourceCorpus`, `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `ScreenRead`, `Navigation`, `Wire`, `WireSecurityRead`, `WireAreaAnyScreen`, `PortGate`, `AdminPortAsync`, `DraftRegistry`, `ToolRoundTrip`, `ToolWrite`, `ToolEmit`, `ToolDispatch`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ClassicPageGate`, `MappingDescriptor`, `Inventory`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/journals.browser-spec.mjs browser/license-usage.browser-spec.mjs browser/remote-databases.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 999.
- `(once, before dev_complete)`, expected green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards:
     - no `OCUPROBE185*` database, resource, principal or `^OcuProbe185` remains;
     - `Config.Journal` and `Config.config` equal S0;
     - journaling writes in S0's directory;
     - the async-task row count and the monitor state read as at S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line:

- AC1: the Journals read declares `Journal.File` `GET` in place of `LIST` → `JournalRead`'s one-read leg goes red.
- AC2: `JournalGuard` skips the file rule → `JournalRead`'s unlisted leg goes red on its zero vendor calls.
- AC3: `JournalSwitchFile.FINGERPRINTSUBJECT` is emptied → the build refuses it. The `STATE` read answers a constant → the moved-fingerprint leg goes red.
- AC4: `JournalPort` drops the 409 mapping → the one-directory leg goes red on its code.
- AC5: `WriteOutput` answers empty → the errors leg goes red. `ToolResult` carries `output` → the no-line leg goes red.
- AC6: `JournalDirectories` drops `JournalHistoryDirectories` → `PathPortInstance`'s former-directory leg goes red. Dropping `WijDirectory` turns the WIJ leg red.
- AC7: the port sends `wijdir` → the omission leg goes red. Dropping `DirectoryExists` → the absent leg goes red. Dropping the purge rule → its leg goes red.
- AC8:
  - the doubling is off → the cap leg goes red;
  - the operator check is dropped → the injection leg goes red (refused by the port, not merely by the criteria);
  - the triple rule is dropped → the partial leg goes red;
  - the record route also answered through a declared read → the no-value leg goes red.
- AC9: `%Admin_Journal:USE` is dropped from `JournalSettings`' pairs → `JournalWriteGate` and `JournalDescriptor` go red.
- AC10: a baseline key is dropped → `GovernanceBaseline` goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- Planned only; nothing implemented. The plan covers seven surfaces in three separable parts (A: Journals, file details, switches, integrity, the `AdminPort` guard and DW-1797; B: settings; C: the record browser and detail). The recommended split is in Design Notes › Size.
- Read-only grounding on `ocupilot-b-ci`: the hidden `Journal.*` endpoint sources (exported to `/tmp/epic-18-d6/185/vendor/`) and synchronous GETs. No write was made to any instance.
- Before the implement spawn, the runner writes the ten proposed spine amendments (Design Notes) and the two corrections at their origin (epics.md :7184 and `epic-18-context.md:33`).
