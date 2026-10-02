---
title: 'Story 18.18: Journal settings'
type: 'feature'
created: '2026-10-02'
status: 'in-progress'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
baseline_revision: '79987ecf0e69e3fdcf964539a16d58bf141e4703'
---

<intent-contract>

## Intent

**Problem:** The classic Journal Settings page (System Administration, catalog SA-04) is still the only way to read or change where and how the instance journals. The admin API's `PUT /journal/settings` checks neither types nor directories and writes every key it carries, the write-image journal's at once. Making the alternate directory settable also makes DW-1950 reachable: a switch-directory proposal confirmed after the alternate stops being distinct answers 500 instead of a target-changed refusal.

**Approach:** OS management gains **Journal settings** (position 14), a form-page over the settings `GET`. Its Save and the agent's confirmed `osmgmt.journalsettings.update` are two callers of one merge tool through `JournalPort` (AD-55). The tool sends the settable set read fresh and never `ArchiveName`, `wijdir` or `targwijsz`. A directory comes only from the server-path picker and must already exist. Every shape is refused on its field before any vendor call. Task 0 observes the `PUT` on `ocupilot-b-ci` before anything is built. For DW-1950, a tool names the refusal its fresh read answers when the action's precondition no longer holds, and inside a confirm that refusal reads as the target having moved.

## Boundaries & Constraints

**Always:**

- **Task 0 runs first, on `ocupilot-b-ci` only, and halts on any contradiction** (Tasks › Task 0). It restores every setting it changes: `Config.Journal` and `Config.config` end byte-equal to S0, and journaling ends in S0's directory. It never sends `wijdir` or `targwijsz`. Purge counts are only raised and restored. No test deletes a journal file; the files its writes start are kept.
- **The screen.** One descriptor, `Screen/Descriptor/JournalSettings.cls`:

  | Route | Archetype | Pos | Entity type | Pairs | `classicPage` | `toolIdentifier` |
  | --- | --- | --- | --- | --- | --- | --- |
  | `os-management/journal-settings` | form-page | 14 | `journal-settings`, scope `instance`, id `{"kind":"single"}` | `%Admin_Manage:USE`, `%Admin_Journal:USE` (`ownPrivileges`, AD-8), `%DB_IRISSYS:READ` | `%CSP.UI.Portal.Journal` | `osmgmt.journalsettings` |

  - Its read is `{"port":"admin","endpoint":"Journal.Settings","type":"GET"}` over all 13 fields (the `AuditingConfig` model), so the form and `osmgmt.journalsettings.read` answer one read (AD-36). Context carries the 13 fields; none is secret.
  - The pairs are the classic page's own check: `%OnPreHTTP` requires `%Admin_Manage` and `%Admin_Journal` together (`irissys/%CSP/UI/Portal/Journal.cls:310-316`), while the API takes either.
  - Prompts, group `promptGroupCapacity`: "Where does this instance write its journal files?" · "When are old journal files purged?" · "Does a journal write error freeze the instance?"
  - No `classicLinkExemption`, no auto-refresh, no row action.
- **The tool.** `Screen/Tool/JournalSettingsUpdate.cls`, `osmgmt.journalsettings.update`:
  - A merge write (AD-4) through `JournalPort` (AD-52): `READTYPE` `GET`, `WRITETYPE` `PUT`, `SENDSBODY` 1. The target is the singleton: `IDRULES` `journal-settings:singleton` reads every id as `SYSTEM` (`EntityRef.cls:147`), and the agent's `Name` is described as that literal (`OAuthAuthorizationServerUpdate` keeps the same inherited `Name`).
  - `PERMITTEDFIELDS` `BackupsBeforePurge,DaysBeforePurge,FileSizeLimit,FreezeOnError,JournalFilePrefix,JournalcspSession,PurgeArchived,CompressFiles`. `EXCLUDEDFIELDS` `CurrentDirectory,AlternateDirectory,ArchiveName,wijdir,targwijsz`. `SettableFields` is those eight plus the arguments `primaryRoot`, `primaryPath`, `alternateRoot`, `alternatePath`. A directory is set only through its arguments, so the vendor receives a composed path under its own field and no caller names a path (AD-21's sixth case).
  - Pairs: `JournalSettings`' three; `%Admin_FileSystemAccess:USE` when a root is sent (`ArgumentPairs`, the `LocalDatabaseUpdate` model); `%DB_IRISSYS:WRITE` and `%Admin_Operate:USE` (measured; orchestrator merge gate 2026-10-02; AD-8). Each is refused by name before any port call. `CLASSICPAGES` is empty: the descriptor's own page performs the save (AD-44).
  - Governance: `osmgmt.journalsettings.update` joins `Baseline.cls` `true`, because it is an ordinary merge that erases nothing. If the story commits after 2026-10-04, the runner asks the owner first (AD-22).
- **The body.** The fresh `GET`'s ten settable keys (`CurrentDirectory`, `AlternateDirectory` and the eight above), with the change applied and `ArchiveName`, `wijdir` and `targwijsz` omitted (proposed AD-4 named exception). The merge copies the whole fresh read (`Mint.Merge`), so the tool's `MergeUpdate` drops the three before it merges, and the port drops them again before the `PUT`.
  - An unchanged directory is sent as read, unless Task 0 measures that a `PUT` carrying an unchanged directory starts a journal file. Then an unchanged directory is omitted too, under the same exception.
  - The classic Save's purge rule (`Journal.cls:198-208`) is applied in the merge, so the payload, the diff and the body agree: with an empty `ArchiveName`, `PurgeArchived` is sent false; with `PurgeArchived` true, both purge counts are sent 0.
- **Directories.** Each is a root and a relative name from the server-path picker.
  - `PathPort.Resolve(..., KINDDIRECTORY, ..., 0, 1)` resolves it as a vendor-writes directory, at the mint or the Save and again at the write. It refuses the manager directory itself (`PATH.MANAGERDIR`) and OcuPilot's served directory (`PATH.SERVED`), the owner's database-directory rule applied by analogy.
  - The resolved directory must already exist (`JOURNAL.DIRECTORY.ABSENT` on its path field), checked at the same two points. `PathPort` has no such check today.
  - A directory is never cleared: it is unchanged or picked.
- **Rules.** `Area/OsMgmt/JournalRules.cls` holds them once. Both callers refuse each on its field before any vendor call:
  - `FileSizeLimit`: a whole number from 1 to 4079 (`JOURNAL.FILESIZE.SHAPE`). The lower bound becomes 0 only if Task 0 measures that the vendor stores 0 (`irissys/Config/Journal.cls:80`, `MINVAL = 0`).
  - `DaysBeforePurge` from 0 to 100, `BackupsBeforePurge` from 0 to 10 (`JOURNAL.PURGE.SHAPE`; `Journal.cls:64-77`).
  - `JournalFilePrefix` matches `^[A-Za-z0-9_-]{0,64}$` (`JOURNAL.PREFIX.SHAPE`); the vendor refuses a dot (Task 0).
  - The four booleans are JSON booleans (`JOURNAL.BOOLEAN.SHAPE`).
  - A key outside `SettableFields` is refused 400 `PORT.FIELD.UNEXPECTED` on the Save; the agent's closed schema refuses it as `TOOL.ARGUMENTS`.
- **Consequence.** A write whose payload sends `FreezeOnError` true carries `JOURNAL.SETTINGS.FREEZE`: "With Freeze on error on, a journal write error blocks every process that journals until it is fixed." The form shows that sentence under the checkbox while it is checked.
- **DW-1950.**
  - `Screen/Tool/Write.cls` gains `Parameter PRECONDITIONCODES` (comma-separated, default empty) and `PreconditionCodes()`. `JournalSwitchDirectory` declares `JOURNAL.SWITCHDIR.NOOTHER`.
  - `Prohibited.Target` reads a refusal whose fault code is one of the tool's as it reads a 404: the target is not in the reviewed state, so the absent early-out applies. The confirm's fingerprint re-read refuses the same way and closes the row `target-changed` with 409 `PROPOSAL.TARGETCHANGED` (`Confirm.cls:374-387`).
  - The mint and the screen action still answer 409 `JOURNAL.SWITCHDIR.NOOTHER`.
- **Codes** go in `Api/JournalError.cls`, never `Api/Error.cls`, whose `JOURNAL.` dispatch already reaches them (`Error.cls:1224`, `:1421`).
- **Contended files are add-only.** Epic 19 is concurrent on slot A, so these files only gain lines or list members:
  - `Api/Router.cls`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Tool/Classification.cls`; `Screen/Gate.cls` is not edited;
  - `scripts/ci-throwaway.sh`, `ui/angular.json`, `ui/src/app/core/strings.ts`, EXPERIENCE.md; `ui/src/app/core/navigation.ts`, `ui/src/app/core/screen-actions.ts` and the spine are not edited;
  - the rosters `ReadTool`, `SurfaceCoverage`, `Wire`, `PortGate`, `Governance`, `GovernanceBaseline`, `ToolDispatch`, `ToolEmit`, `ToolRoundTrip`, `ClassicPageGate`, `MappingDescriptor` and `Test/Prohibited.cls`.

  One-line list members and roster counts are unioned and summed by whichever story reaches feature second. EXPERIENCE.md stays at 1001 lines, and every shifted `/** EXPERIENCE.md:n */` citation is updated. `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged.

**Never:**

- No write-image journal change, no archive-target choice or creation, no journaling start or stop, no `FreezeOnError` self-test.
- No caller path, no cleared directory, and no directory the instance does not hold.
- No journal record browser (Story 18.19), and no auto-refresh on Journal settings.
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses. No `Config.*` write in product code; test-only `%SYS` seeding is allowed.
- No deletion of a journal file by any test, and no archive target created by any test.
- No spine or epics.md edit in the implement stage. The runner writes the amendments in Design Notes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Read | Stock throwaway | Journal settings and `osmgmt.journalsettings.read` answer the same 13 fields. `ArchiveName`, `wijdir` and `targwijsz` render read-only. The side bar lists Journal settings 14th, after Journals. | none |
| Save | `FileSizeLimit` 1024 to 1000 | One `PUT` of the settable keys read fresh, with one diff row and none of the three shown-only keys in the body. Read-back `matches`. | none |
| Agent | The same change, proposed and confirmed | The card shows one row. The confirm sends the same body, emits the marker and reads back `matches`. | none |
| Moved since the mint | A sent key changes between mint and confirm | The confirm is refused and nothing is written | 409 `PROPOSAL.TARGETCHANGED` (existing) |
| Directory picked | Alternate set to an existing probe directory, on either caller | Stored as the resolved path; Journals' Switch directory then moves journaling there, and back | none |
| Directory refused | Primary: the manager root with an empty name; a missing name; a name under `csp/ocupilot/` | Refused on its field before any vendor call, at the mint or Save and again at the confirm | `PATH.MANAGERDIR` / `JOURNAL.DIRECTORY.ABSENT` / `PATH.SERVED` |
| Shapes | `FileSizeLimit` 5000 or 1.5; `DaysBeforePurge` 101; `BackupsBeforePurge` 11; prefix `a/b`; `FreezeOnError` as the string `"true"` | Refused on its field before any vendor call | `JOURNAL.FILESIZE.SHAPE`, `.PURGE.SHAPE`, `.PREFIX.SHAPE`, `.BOOLEAN.SHAPE` |
| Shown-only key | The Save body carries `wijdir`; the agent's arguments carry `ArchiveName` | Refused; nothing is sent | 400 `PORT.FIELD.UNEXPECTED` / 400 `TOOL.ARGUMENTS` |
| Purge rule | `PurgeArchived` true with `ArchiveName` empty; then, at the merge, a fresh read whose `ArchiveName` is set and `PurgeArchived` true | Sent false; then both counts sent 0 | none |
| Freeze on | `FreezeOnError` false to true | The card and the form state the consequence | none |
| Missing pair | No `%Admin_Journal:USE`; a measured extra pair absent; no `%Admin_FileSystemAccess:USE` with a root sent | Refused naming the pair, with zero port calls. The side bar lists the screen unavailable. | 403 `AUTH.NOPRIVILEGE` |
| DW-1950 | A switch-directory proposal minted with a distinct alternate; then a Save sets the alternate equal to the primary; then Confirm | The proposal closes `target-changed`, and nothing switches | 409 `PROPOSAL.TARGETCHANGED` |
| Integration | Stock throwaway (one directory): Save a distinct alternate, then Switch directory | Journaling moves to the alternate, and back | none |

</intent-contract>

## Code Map

**Vendor** (hidden classes exported read-only to `/tmp/epic-18-d6/185/vendor/`; re-export from `ocupilot-b-ci` if they are gone):

- `%Api.Admin.Endpoints.Journal.Settings`:
  - `ResourcesOR()` is `%Admin_Manage` or `%Admin_Journal` for `GET` and `PUT`.
  - `GET` answers 13 keys: `Config.Journal`'s eleven, then `wijdir` and `targwijsz` from `Config.config`, the four booleans as JSON booleans.
  - `PUT` copies only the keys present: `wijdir`/`targwijsz` go to `Config.config.Modify`, the rest to `Config.Journal.Modify`. A `Modify` failure answers 500.
  - `ValidateRequest` uses `RequestValidator` with `AllRequired` 0: it refuses an unknown key or an object where a literal belongs, and checks no type, range or directory (`%Api.Admin.Util.RequestValidator.cls`).
- `irissys/Config/Journal.cls`: ranges at :64-80; the directory setters' bodies are hidden. Story 18.5's Task 0 measured that each `Config.Journal.Modify` of a directory switched the journal file "to activate journal changes".
- The classic page `irissys/%CSP/UI/Portal/Journal.cls`: `RESOURCE` :21; `validate()` :128-140; `SaveData` :187-240, with the purge rule at :198-208 and `IsJrnDirAvailable` on both directories at :210-213 (`[Internal]`, not called here); `%OnPreHTTP` :310-316.
- Read-only on `ocupilot-b-ci` at plan, 2026-10-02: primary and alternate both `/durable/iris/mgr/journal/`; `ArchiveName` ""; `FileSizeLimit` 1024; purge 2 and 2; `CompressFiles` true; `wijdir` ""; `targwijsz` 0; current file `/durable/iris/mgr/journal/20261002.306`.

**Ports:**

- `Port/AdminPort.cls`: `MUTATINGTYPES` :416 lacks `Journal.Settings/PUT`, so today the port answers it 501 `PORT.NOTIMPLEMENTED` (:1042-1046); its doc :408-414. `BODYLESSTYPES` :432. `Fail` :2848 and `PROPERTYFAULTS` :2988 map a vendor 500.
- `Port/JournalPort.cls` (301 lines): `Invoke` :84-101 dispatches by endpoint and type; `SETTINGSENDPOINT` :34; `PRIMARYKEY`/`ALTERNATEKEY` :62-64; `State` :108, `SwitchDirectory` :178; `Normalized` :254, `SameDirectory` :263, `Text` :273, `Snippet` :291. Its `GET` and `PUT` branches for `Journal.Settings` are new here.
- `Port/DatabasePort.cls` :200-232 is the model for those branches: the `GET` answers the directory arguments as `null` (:209-210) so the merge can set them; the `PUT` strips them (:214), resolves the root through `PathPort` from the query (:216-217) and sets the vendor's field. `Without` :862; the 422 builders `Refused` and the violations list :770-783.
- `Port/PathPort.cls`: `Resolve(pRoot, pPath, pKind, pRootField, pPathField, .pResolved, .pHttp, .pFault, pOverwrite, pVendorWrites)` :269; `KINDDIRECTORY` :62; `PAIRS` :50; the manager-directory and served refusals :317-323. Codes in `Api/Error.cls`: `PATH.ROOT` :388, `PATH.NAME` :399, `PATH.MANAGERDIR` :452, `PATH.SERVED` :463. The file-parent existence model is `TaskTransferPort.cls:240`.

**Tool models:**

- `Screen/Tool/LocalDatabaseUpdate.cls`: `PERMITTEDFIELDS` and `EXCLUDEDFIELDS` with their methods, `VOLUMEARGUMENTS` :43, `SettableFields` :65-68, `InputSchema` (argument descriptions :102-103), `MergeUpdate` :109-116 (drops absent arguments), `DerivedFields` :128-135, `PortQuery` :138-148, `ArgumentPairs` :162-170.
- `Screen/Tool/OAuthAuthorizationServerUpdate.cls`: a singleton merge tool on the inherited `Name`/`name` id. `Screen/Tool/LanguageServerUpdate.cls:259-265`: a `Consequence` keyed on the payload.
- `Screen/Tool/Write.cls`: `PRECONDITIONFIELD` :105, `DerivedFields` :324, `MergeUpdate` :350, `PortQuery` :440, `ExcludedFields` :538, `PermittedFields` :550, `AdmittedFields` :728, `ArgumentProblem` :857; the closed input schema refuses an unknown argument. No refusal-code parameter exists.
- `Screen/Tool/JournalSwitchDirectory.cls`: `READTYPE` `DIRSTATE`, `FINGERPRINTSUBJECT` `CurrentFile,CurrentDirectory,OtherDirectory`.
- `Api/JournalError.cls` (59 lines): `Codes()` :38 and `ReasonFor` :51 gain every new code.
- `Kernel/Proposal/Mint.cls` `ConsequenceOf` :758-766 asks the tool's `Consequence(payload, privileged, effect)`. The client maps a consequence code in `ui/src/app/core/proposal-view.ts:257,275` (18.5's `JOURNAL.SWITCHDIRECTORY`).

**Save model:** `Area/OsMgmt/DatabaseSave.cls`:

- `Update` :208-264: settable keys only, else 400 `PORT.FIELD.UNEXPECTED`; the fresh read; the rules; `MergeUpdate`; `Prohibited` :284; `Send` :302 with `PortQuery` and `DerivedFields`; `PortViolations` :267 moves a port's field refusals into the form's 422; `ReadBack.ForSave`.
- `Gate` :407 adds the tool's argument pairs.
- The singleton Save is `Area/Security/OAuthAuthorizationServerSave.cls`: `TargetId()` :57-60, a route with no `:id` (`Router.cls:214`, wrapper :812).
- The rules shape is `Area/Permissions/ServiceRules.cls` (`Validate` :75, `Problem` :357); violations render through `Kernel/AgentRules.cls` `ViolationsJson` (:410-411). The `UrlMap` tail is `Router.cls:223`.

**Write path (DW-1950):**

- `Kernel/Proposal/Prohibited.cls` `Target` :3861-3903: a read answered 404 is absence (`If +$Get(tHttp) = 404 Quit`, :3886). Any other refusal is an error status, which `Operation.Gate` (`Operation.cls:392-398`) turns into "the prohibited set could not be read" and `Confirm` into 500 `INTERNAL`. The absent early-out is at :1081.
- `Kernel/Proposal/Confirm.cls`: `FingerprintMatches` :672-751 reads any refused re-read of a non-create as "the target moved" (:719-723), and its caller closes the row with 409 `PROPOSAL.TARGETCHANGED` (:374-387).
- `Kernel/Proposal/Mint.cls` :168-173 passes a fresh read's refusal through with its own code, which is why the mint keeps `JOURNAL.SWITCHDIR.NOOTHER`. `Kernel/Proposal/Draft.cls:88` asks the same set.

**Kernel registrations:**

- `Kernel/EntityType.cls:61` `TYPES` (44 entries); `Kernel/EntityRef.cls:59` `IDRULES`.
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250; `TYPEJOURNALFILE` :440; the type gate :1029; `PermittedChangeFields` :806-837; the `journal-file` arm :1191-1196; `DatabaseChangeFields` :2253, which lists arguments beside the fields; `ReviewedFewOnly` :2828.
- `Kernel/Governance/Baseline.cls:33-35`: the journal keys, alphabetical, so the new key follows :35.
- `Screen/Tool/Classification.cls`: entry format :6-29; `"compare": {"Directory": "unslashed"}` :540 is the directory model. `Screen/Tool/FieldLists.cls:93-107` holds `Journal.Settings`' 13 derived rows. Regenerate `ToolFields.cls` with `cd ui && node tools/field-lists.mjs`; `--check` runs in `prebuild`.
- `scripts/check-objectscript.py` and `ui/tools/screen-mirror.mjs` read `EntityType.cls` and `EntityRef.cls` themselves.

**Descriptor models:** `Screen/Descriptor/AuditingConfig.cls` (a listed form-page with a single-object `GET` read on a singleton), `Screen/Descriptor/JournalList.cls` (OS management conventions), `Screen/Area.cls:75` (OS management's set: `%Admin_Operate`, `%Admin_Manage`, `%DB_IRISSYS:READ`, which is why `%Admin_Journal` is an own pair).

**Client** (`ui/src/app/`):

- The singleton editor model is `areas/security/oauth-server-form.store.ts` (`open()` :601, `save()` :704) and its page. `areas/permissions/service-editor.page.ts` shows the violations (`ocu-form-summary` :95-97, per-field `aria-invalid` and `ocu-form-error` :139-150) and the sticky bar (:230-239). `core/violations.ts:35,67`; `core/form-dirty.ts:30`; `leaveFormGuard` is attached to every form-page route (`app.routes.ts:24-27,76-78`).
- The directory picker: `shell/server-path-picker.ts:49,108` (`store`, `kind`, `root`, `path`, `rootReason`, `pathReason`, `idPrefix`; output `changed {root, path, preselected?}`, where a `preselected` report is not a change, :36-40); `core/allowed-directories.ts:82`.
  - Model use: `areas/os-management/database-editor.page.ts:251-271,366` shows the current directory read-only with a Change button, draws the picker only while changing, and Cancel keeps it.
  - `database-editor.store.ts:390-402,517-520` sends the arguments only while changing.
- `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :130-191 (the journal pages :184-187, imports :62-63). Regenerate `core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`.
- `core/strings.ts` journal block :4365-4448, each key under its `/** EXPERIENCE.md:378 */` line; `ui/tools/strings.test.mjs:577` bounds the literals at 2100.
- `app.ts` sign-out resets :582-661 (`oauthServerForm.reset()` :637), stores injected near :306; pinned in `app.spec.ts` (:1210-1212 primes, :1369-1371 asserts).
- `ui/angular.json:54` `maximumWarning` 2495kB against a measured 2,494,043 bytes; pinned at `ui/tools/angular-json.test.mjs:423`, history rows :349-410.

**EXPERIENCE.md** (1001 lines): :164 the OS management side-bar row, ending "· Journals (Stage 2, Story 18.5: in System Operation, not Logs) |"; :301 and :631 the form-page strings and archetype; :364 the picker strings; :378 Fixed strings, where Story 18.5's journal strings sit. No line names Journal settings yet.

**Rosters.** Re-derive each from its class's red, never by hand:

- ObjectScript:
  - `Navigation` :484 (35) and :485 (the listed order);
  - `Wire` :707; `WireSecurityRead` :561, :568, :571; `WireAreaAnyScreen` :271;
  - `ReadTool` :93 (214) and :94; `Descriptor` `ReadShapes` :138-140 and the entity-type count :1715 (44);
  - `SurfaceCoverage` screens :156-158 and tools :293-295; `EndpointCoverage` probes (the `PUT /journal/settings` row with `refusal="1"`, the `PUT /oauth/authorization-server` model);
  - `ToolRoundTrip` `REFUSEEMPTY` :58 (`osmgmt.journalsettings.update:TOOL.ARGUMENTS`); `ClassicPageGate` `OWNPAIRS` :74; `MappingDescriptor` `CLASSICROSTER` :23;
  - `PortFixture` `MUTATINGTYPES` :21; `Test/Prohibited.cls` :232; `ToolEmit` :252-258 (reads `EXTRAPAIRS`); `Governance`, `GovernanceBaseline` and `ToolDispatch` only if their red names the key.
  - **`ToolWrite` :1203-1209, :1243-1246 and :1343-1356** name `Journal.Settings/PUT` as an endpoint whose PUT no tool issues. Re-point them to `Device.Settings` (`Port/AdminRoutes.cls:98`, `PUT /device/settings`, `Test/AdminInventory.cls:49`), which no tool issues and no epics.md story plans. Its width leg (:1323) then holds `MUTATINGTYPES` equal to the pairs the tools reach.
- Client:
  - `ui/tools/navigation.test.mjs` :202-203, :269, :282, :285-305;
  - `ui/tools/navigation-wire.test.mjs` :338 and :671-675; `shell/rail-wire.spec.ts` :343 and :737-742; `shell/area-verdict.spec.ts` :60-67 and :150-166;
  - `ui/tools/screen-mirror.test.mjs:2251-2276` (the `ownPrivileges` roster); `ui/tools/field-lists.test.mjs` :505-527, if a `compare` is declared.
- Browser (DW-1774): `journals.browser-spec.mjs:270-271` (length 13, `[12]` Journals), `license-usage.browser-spec.mjs:4-7,117,129-147`, `remote-databases.browser-spec.mjs:300-315`.

**Test models:**

- `Test/JournalProbe.cls` (591 lines):
  - directories: `DirectoryFor` :46 and `IsProbeDirectory` :58 for the `ocuprobe185` family, which `RemoveAll` :195 sweeps when empty;
  - state: `JournalSettings` :67 and `RestoreJournal` :126 (eleven `Config.Journal` properties, never the WIJ keys), `SeedAlternate` :97;
  - principals and calls: `SeedPrincipal` :165, `Run` :304, `RunAs` :338, `Snapshot` :437, `Diff` :532.
- `Test/JournalCountPort.cls` (a counting seam); `Test/SeamJournal*.cls` (tools on a seam port).
- `Test/JournalWrite.cls` (382 lines; `TestOneDirectoryIsRefusedOnBothCallers` :175-197); `Test/JournalWriteGate.cls` (257; the no-send leg :144-145); `Test/JournalDescriptor.cls` (200); `Test/JournalRead.cls` (239).
- `ui/browser/journals.browser-spec.mjs`: `iris()` :77, `journalState()` :93, the throwaway guard :107-115, `sideBarOf` :129, `assertStructure` :233 (DW-1337 in both themes).
- `ui/browser/local-databases.browser-spec.mjs`: `chooseManagerRoot` :456, `retype` :465, the picker leg :649, and the `PATH.MANAGERDIR` wait :522-528.

**CI:** `scripts/ci-throwaway.sh:461-467` (`OCUPILOT_ALLOW_JOURNAL`, `# classes: JournalWrite, JournalWriteGate, PathPortInstance`). `ui/tools/ci.test.mjs:2096,2159,2177` holds each `# classes:` line equal to the classes that declare the variable.

## Tasks & Acceptance

**Task 0: the implement stage's first task, before any tool, descriptor or form.** **Resumed 2026-10-02 after its step-5 halt, which the orchestrator ruled (Spec Change Log): steps 1-4 are measured (Design Notes › Measured at implement), and step 1's plumbing is parked in `_bmad-output/implementation-artifacts/spec-18-18-task0-plumbing.patch`; `git apply` it first, do not re-run the measurements, and continue at step 6, then the Execution tasks.** Run it on `ocupilot-b-ci` only; load with `/tmp/epic-18-d6/load-throwaway.sh`. Record every result under Design Notes › Measured at implement, and every AD sentence in `## Spec Change Log` for the runner.

1. **Plumbing.** `Port/AdminPort.cls` `MUTATINGTYPES` gains `Journal.Settings/PUT` with its sentence (add-only; never in `BODYLESSTYPES`), and `Test/PortFixture.cls:21` follows. `JournalPort` gets its `GET` and `PUT` branches (Execution). `Test/JournalProbe.cls` gains `SeedDirectory(suffix)`, which creates `DirectoryFor(suffix)`; every `PUT` below goes through its timed `Run("Journal.Settings", "PUT", , body)`.
2. **Snapshot S0** with `Snapshot`, and keep `JournalSettings()` for every restore.
3. **Measure**, restoring after each step with `RestoreJournal`:
   - a. A `PUT` of the fresh `GET`'s ten settable keys unchanged: whether any stored key changes, whether a journal file starts, the audit events (auditing on), the `messages.log` lines and the duration.
   - b. `PUT {FileSizeLimit:1000}` alone: no other key changes (the merge), and whether a file starts.
   - c. `AlternateDirectory` set to `SeedDirectory("set")`'s directory without its trailing slash: the stored spelling, and where journaling writes next.
   - d. `CurrentDirectory` set to that directory: the stored value and where journaling writes next. Restore.
   - e. `AlternateDirectory` set to a missing `DirectoryFor("none")`: whether the vendor stores, creates or refuses it. Restore, and remove the directory if the vendor created it.
   - f. Shapes: `FreezeOnError:"true"`, `FileSizeLimit` 0, 5000 and 1.5, `DaysBeforePurge` 101, `JournalFilePrefix` `"a/b"`: the vendor's answer and stored value for each.
   - g. `PurgeArchived:true` with `ArchiveName` "": the stored value.
   - h. Pairs, each through `RunAs` with the install namespace's code read: Journal settings' three pairs, then plus `%DB_IRISSYS:WRITE`. Run `GET` and `PUT {FileSizeLimit:1000}` for each, and `GET` with `%Admin_Journal:USE` alone.
4. **Cleanup proof:** S2 equals S0 except counters, the journal files the writes started (kept) and their `messages.log` lines. `Config.Journal` and `Config.config` are byte-equal, journaling writes in S0's directory, and every empty probe directory is removed.
5. **HALT** `blocked`, with blocking condition `intent gap: observation contradicts the plan: <what>` and nothing built, if:
   - any `PUT` erases or changes a key it did not send, or changes `wijdir` or `targwijsz`;
   - the settings `GET` or `PUT` answers 202, or cannot be reached through `AdminPort`;
   - a step needs a pair outside Journal settings' three, `%DB_IRISSYS:WRITE` and `%Admin_FileSystemAccess:USE`;
   - the vendor refuses a value `JournalRules` admits;
   - S2 differs from S0 beyond the declared differences.
6. **Otherwise, set from the record:**
   - the tool's extra pairs (`%DB_IRISSYS:WRITE` only if step h's `PUT` was refused without it);
   - the unchanged-directory rule (omit an unchanged directory only if step a started a file);
   - `FileSizeLimit`'s lower bound: 0 only if the vendor stored 0, and its sentence then reads "from 0 to 4079";
   - `compare`: `CurrentDirectory` and `AlternateDirectory` take `unslashed` if the stored spelling differs from the sent one only by a trailing separator;
   - the directory line on the form: shown only if steps c and d measured that a directory change starts a journal file;
   - the AD-15/AD-53 named case, if no vendor event records the `PUT`.

**Execution:**

- `src/OcuPilot/Port/JournalPort.cls`:
  - `GET` on `Journal.Settings` answers the vendor's object with `primaryRoot`, `primaryPath`, `alternateRoot` and `alternatePath` set to `null`, so the merge can set them (the `DatabasePort` :209-210 model).
  - `PUT` on `Journal.Settings`:
    - the body without `ArchiveName`, `wijdir`, `targwijsz` and the four arguments;
    - each root in the query resolved through `PathPort.Resolve(..., KINDDIRECTORY, "<x>Root", "<x>Path", ..., 0, 1)`, which refuses on its own codes;
    - a resolved directory that `%File.DirectoryExists` denies refused 422 `JOURNAL.VALIDATION` with the violation `JOURNAL.DIRECTORY.ABSENT` on its path field, the `Refused` model;
    - `CurrentDirectory`/`AlternateDirectory` set from what resolved;
    - the purge rule applied again; then `Call`.
  - `Snippet` mirrors the branch (AD-59): the script shows the composed body.
- `src/OcuPilot/Screen/Tool/JournalSettingsUpdate.cls` (new), per Boundaries: `DESCRIPTORCLASS`, `PORTCLASS`, `PERMITTEDFIELDS`, `EXCLUDEDFIELDS`, `DIRECTORYARGUMENTS`.
  - `SettableFields` and `InputSchema` (each field and argument described; `Name` the literal `SYSTEM`).
  - `MergeUpdate`: the fresh read without the three shown-only keys (and an unchanged directory, per Task 0) and without arguments not sent; then the kernel merge; then the purge rule.
  - `ArgumentProblem` runs `JournalRules.Problem`. `DerivedFields` sets the resolved directories, and `PortQuery` passes the arguments.
  - `PrivilegePairs` and `ArgumentPairs`; `Consequence` answers `JOURNAL.SETTINGS.FREEZE` for a payload whose `FreezeOnError` is true.
- `src/OcuPilot/Screen/Tool/Write.cls`: `Parameter PRECONDITIONCODES` and `PreconditionCodes()`, empty by default. `src/OcuPilot/Screen/Tool/JournalSwitchDirectory.cls` declares `PRECONDITIONCODES = "JOURNAL.SWITCHDIR.NOOTHER"`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only):
  - `Target`: after the 404 line, a refusal whose fault code the resolved tool's `PreconditionCodes()` names also quits with `pPresent` 0, through a new private helper.
  - `journal-settings` joins `COVEREDTYPES` and the type gate. A `TYPEJOURNALSETTINGS` parameter is added, and `PermittedChangeFields` answers the ten keys and the four arguments.
  - A `journal-settings` arm calls `ReviewedFewOnly`. There is no new predicate.
- `src/OcuPilot/Area/OsMgmt/JournalRules.cls` (new): `Validate(pArgs, pFresh, Output pViolations)` and `Problem` (the shapes, the booleans, the purge rule, and the directory refusals placed on their fields), the `ServiceRules` shape.
- `src/OcuPilot/Area/OsMgmt/JournalSave.cls` (new): `PUT /journal/settings` through the tool (AD-55), in `DatabaseSave.Update`'s order with the singleton target of `OAuthAuthorizationServerSave.TargetId()`. A diff with no row sends nothing (the `OAuthAuthorizationServerSave` :235 model). `PortViolations` takes `JOURNAL.*` and `PATH.*` rows. The answer is `{readBack}`.
- `src/OcuPilot/Api/Router.cls` (add-only): `<Route Url="/journal/settings" Method="PUT" Call="JournalSettingsUpdate"/>` at the `UrlMap` tail, and its thin wrapper.
- `src/OcuPilot/Api/JournalError.cls`: the codes below, each in `Codes()` and `ReasonFor`.
  - `JOURNAL.VALIDATION` (422): "The journal settings were refused."
  - `JOURNAL.DIRECTORY.ABSENT` (422): "That directory does not exist on the instance. Create it, then choose it."
  - `JOURNAL.FILESIZE.SHAPE` (422): "Enter a whole number of megabytes from 1 to 4079."
  - `JOURNAL.PURGE.SHAPE` (422): "Enter a whole number: up to 100 days, or up to 10 backups."
  - `JOURNAL.PREFIX.SHAPE` (422): "Use up to 64 letters, digits, hyphens or underscores."
  - `JOURNAL.BOOLEAN.SHAPE` (422): "Choose on or off."
- `src/OcuPilot/Screen/Descriptor/JournalSettings.cls` (new), per Boundaries.
- `src/OcuPilot/Kernel/EntityType.cls` gains `journal-settings`. `src/OcuPilot/Kernel/EntityRef.cls` `IDRULES` gains `journal-settings:singleton`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only): `"osmgmt.journalsettings.update": true` after :35.
- `src/OcuPilot/Screen/Tool/Classification.cls` (add-only): `osmgmt.journalsettings.update` over `fieldList` `Journal.Settings`, the ten settable fields `ordinary`, `compare` per Task 0. Then regenerate `ToolFields.cls`.
- `src/OcuPilot/Test/ToolWrite.cls`: re-point the three legs to `Device.Settings` (Code Map › Rosters).

**Client:**

- `ui/src/app/areas/os-management/journal-settings.store.ts` and `.page.ts` (new, each with a spec), on the `oauth-server-form` model.
  - `open()` issues the descriptor's declared read. `save()` sends `PUT /api/ocupilot/journal/settings` with the changed fields only, and a directory's two arguments only while that directory is being changed (the `database-editor` model).
  - One form, no tabs, with these controls:
    - the two directories, each read-only with Change, and the picker while changing;
    - `FileSizeLimit` and `JournalFilePrefix`;
    - `ArchiveName` read-only, "(none)" when empty;
    - `PurgeArchived`, disabled and unchecked while `ArchiveName` is empty; the two purge counts, disabled while `PurgeArchived` is checked;
    - the three checkboxes, with the Freeze on error consequence under its checkbox while checked;
    - `wijdir` and `targwijsz` read-only, as "The manager directory" for an empty `wijdir` and "Not set" for 0, with the shown-only hint.
  - The page keeps the sticky Save, the error summary, per-field reasons (the picker's `rootReason`/`pathReason` included) and the unsaved-changes guard; a `preselected` picker report is not a change. It publishes the change event on success.
- `ui/src/app/shell/screen-outlet.ts` registers the page in `DESCRIPTOR_PAGES`. `ui/src/app/app.ts` injects the store and resets it on sign-out, pinned in `app.spec.ts`. `ui/src/app/core/proposal-view.ts` maps `JOURNAL.SETTINGS.FREEZE` to its sentence. Regenerate `core/screens.generated.ts`.
- `ui/src/app/core/strings.ts` (add-only), each key cited to its EXPERIENCE.md line. New literals:
  - "Journal settings", "Primary journal directory", "Alternate journal directory", "Start a new journal file every (MB)", "Journal file prefix", "Archive target";
  - "Purge as soon as they are copied to the archive", "Purge after this many days", "Purge after this many backups";
  - "Freeze on error", "Journal web sessions", "Compress journal files";
  - "Write image journal directory", "Write image journal target size (MB)", "The manager directory", "Not set";
  - "Shown here only. Change it on the classic Journal Settings page.";
  - the Freeze on error consequence sentence;
  - "Saving a changed journal directory starts a new journal file.", only if Task 0 measured it;
  - the three prompts.

  Reuse the existing keys for Change, Cancel, Saved, "(none)", the leave guard and the picker strings. Raise `ui/tools/strings.test.mjs:577`'s bound of 2100 only if the new literals exceed it, with its history comment.
- `ui/angular.json`: if the build crosses 2495kB, re-base `maximumWarning` under DW-1166 to the measured initial total rounded up to the next kB, with its history row in `ui/tools/angular-json.test.mjs`. Stop and ask above 3800kB.
- EXPERIENCE.md, in place, keeping 1001 lines:
  - :164 gains "· Journal settings (Stage 2, Story 18.18)" after Journals.
  - :378 gains every new literal above and a usage clause: the fourteenth OS management entry, the form's labels, the shown-only hint, the consequence and the three prompts in "Capacity", tagged `[ADDED <date> - Story 18.18]`.
  - Then run `cd ui && npm run test:tools`.

**Rosters and CI.** Extend every roster in Code Map › Rosters. In `scripts/ci-throwaway.sh` (add-only), the `OCUPILOT_ALLOW_JOURNAL` comment gains "and changes its journal settings", and a `# classes:` line names the new armed classes. Keep `ui/tools/ci.test.mjs` equal.

**Tests:**

- `src/OcuPilot/Test/JournalSettingsWrite.cls` (new, `OCUPILOT_ALLOW_JOURNAL`), each leg on both callers and restoring S0:
  - the Save and the confirm of `FileSizeLimit`, asserting the body a recording seam saw (`Test/SeamJournalSettingsUpdate.cls` and `Test/JournalSettingsPort.cls`, the 18.5 `SeamJournal*` pattern): the settable set, none of the three shown-only keys, and read-back `matches`;
  - the alternate picked to a seeded probe directory, then Journals' Switch directory there and back (integration);
  - the purge rule's empty-archive branch on both callers, and its other branch at the merge over a fresh-read object whose `ArchiveName` is set;
  - the Freeze on error consequence on the card.
- `src/OcuPilot/Test/JournalSettingsRules.cls` (new, `OCUPILOT_ALLOW_JOURNAL`):
  - every shape row, the three directory refusals and the shown-only keys on both callers;
  - zero `PUT`s reach the seam; the directory refusals also at the confirm, after the directory is removed since the mint.
- `src/OcuPilot/Test/JournalWrite.cls` gains the DW-1950 leg: mint switch directory with `SeedAlternate`, Save the alternate equal to the primary, then confirm. Expect 409 `PROPOSAL.TARGETCHANGED`, the row closed `target-changed`, and no switch.
- `src/OcuPilot/Test/JournalWriteGate.cls` gains: no `%Admin_Journal:USE` on the Save and the mint; no `%Admin_FileSystemAccess:USE` with a root; a measured extra pair. Each refused by name with zero port calls.
- `src/OcuPilot/Test/JournalDescriptor.cls` gains the descriptor's pairs, own pair, position, prompts and classic page; the tool's kind, port, pairs, empty `CLASSICPAGES`, permitted and excluded fields; and switch directory's `PRECONDITIONCODES`.
- `src/OcuPilot/Test/JournalRead.cls` gains: the form's read and `osmgmt.journalsettings.read` answer the same 13 fields.
- `ui/browser/journal-settings.browser-spec.mjs` (new; seeds and restores over `docker exec`, refusing a non-throwaway like `journals.browser-spec.mjs`):
  - the side bar's fourteenth entry; the form's 13 fields with three read-only;
  - a `FileSizeLimit` Save and its restore;
  - the primary's `PATH.MANAGERDIR` refusal on the path field;
  - the DW-1337 structural gate in both themes.
- The journal page and store specs: the purge rule's disabling, the shown-only rendering, the arguments sent only while changing, violations on their fields, and the leave guard.

**Acceptance Criteria:**

- **AC0:** Given `ocupilot-b-ci`, when the implement stage starts, then Task 0's payloads, effects, pairs and audit events are recorded before any tool, descriptor or form exists, and S2 equals S0 apart from the declared differences. A contradiction halts the story.
- **AC1:** Given the instance's journal settings, when Journal settings opens and `osmgmt.journalsettings.read` runs, then both answer the same 13 fields, with the three shown-only fields read-only. The side bar lists Journal settings 14th under OS management, after Journals. A caller without `%Admin_Journal:USE` sees it listed unavailable, naming that pair.
- **AC2:** Given a change, when a person saves or the agent's proposal is confirmed, then one `PUT` sends the settable keys read fresh with the change applied, and the body carries none of `ArchiveName`, `wijdir` or `targwijsz`. The read-back reads `matches`.
- **AC3:** Given a directory field, when either caller sends a root and a name, then the directory is resolved at the mint or Save and again at the write. It is refused on its field when it is the manager directory, under OcuPilot's served directory, or missing. An existing one is stored, and Journals' Switch directory then moves journaling there.
- **AC4:** Given an out-of-range number, a bad prefix, a non-boolean flag, an undeclared key or a shown-only key, when either caller sends it, then it is refused on its field or as an unexpected key before any vendor call. The purge rule shapes every body.
- **AC5:** Given each declared pair, when the caller lacks it, then the Save, the mint and the confirm are refused 403 `AUTH.NOPRIVILEGE` naming that pair, with zero port calls.
- **AC6:** Given `FreezeOnError` sent true, when the card or the form shows the change, then it states the consequence.
- **AC7 (DW-1950):** Given a switch-directory proposal minted with a distinct alternate, when the alternate is made equal to the primary and the proposal is confirmed, then the confirm answers 409 `PROPOSAL.TARGETCHANGED`, closes the row `target-changed` and switches nothing. The mint and the screen action still answer `JOURNAL.SWITCHDIR.NOOTHER`.
- **AC8:** Given governance, when the story lands, then `osmgmt.journalsettings.update` is in `Baseline.cls`, `true`.
- **AC9:** Given the rosters, when the story lands, then:
  - every roster and pinned side-bar list includes the screen and its tools (DW-1774);
  - the screen has three prompts;
  - the DW-1337 gate holds in both themes;
  - EXPERIENCE.md reads 1001 lines.

## Spec Change Log

- 2026-10-02, orchestrator merge gate on the Task 0 step-5 halt (by=merge_gate, under the owner's standing grant), applied by the runner: the tool and the Save declare `%DB_IRISSYS:WRITE` and `%Admin_Operate:USE`, each refused by name before any port call (Boundaries pairs; AD-8 written), so OcuPilot never causes the measured half-applied write (stored, no new file); the narrower-than-classic audience follows the 18.15, 18.16 and 18.5 precedent. AD-4's `Journal.Settings` exception is written (omitted keys kept, measured). No AD-15/AD-53 case: every vendor `PUT` is audited. The prefix rule without a dot and `FileSizeLimit` from 0 stand. Evidence: the runner's four-row re-measure, `/tmp/epic-18-d6/1818-remeasure-out.txt`. Status reset to `in-progress`; Task 0 resumes at step 6.

- 2026-10-02, runner at the Task 0 halt (Rule 5 tier 1, and evidence for the orchestrator): the prefix rule drops the dot (`^[A-Za-z0-9_-]{0,64}$`, "Use up to 64 letters, digits, hyphens or underscores."), because the vendor refuses one (#7209 on `Config.Journal:JournalFilePrefix`, confirmed by the stage). `FileSizeLimit`'s lower bound becomes 0 by the spec's own step-10 rule (the vendor stored 0; `Config.Journal` declares `MINVAL = 0, MAXVAL = 4079`). The runner re-measured the changing settings `PUT` (`{FileSizeLimit: 1025}`, through `AdminPort`, `RunAs`, the plumbing patch applied and reverted) on `ocupilot-b-ci`: Journal settings' three pairs, 500 `<PROTECT>%SaveData+26^Config.Journal.1 ^SYS`, nothing stored; plus `%DB_IRISSYS:WRITE`, 500 `#1142 Error switching journal file: Operation requires %Admin_Operate:Use privilege` with the change STORED and no new file (a half-applied write); plus `%Admin_Operate:USE` alone, the same `<PROTECT>`, nothing stored; plus both, 200, stored, new journal file. Every row matches the handoff's; journal settings restored byte-equal after each row, probes removed, monitor 0 (evidence `/tmp/epic-18-d6/1818-remeasure-out.txt`). The extra `%Admin_Operate:USE` pair (HALT 2) waits for the orchestrator's ruling.

- 2026-10-02, implement Task 0 (HALT, step 5; Design Notes › Measured at implement). For the runner, pending the decision on the halt:
  - **Recommended intent amendments:** `JournalFilePrefix` matches `^[A-Za-z0-9_-]{0,64}$`, reason "Use up to 64 letters, digits, hyphens or underscores."; the tool and the Save also declare `%Admin_Operate:USE`, refused by name before any port call; `FileSizeLimit` from 0 to 4079.
  - **AD-4:** "the vendor keeps an omitted key (measured at Story 18.18's Task 0)", with no unchanged-directory clause.
  - **AD-8:** "`osmgmt.journalsettings.update` declares `%DB_IRISSYS:WRITE` and `%Admin_Operate:USE`, and PathPort's `%Admin_FileSystemAccess:USE` when it sends a root: with the screen's three pairs the vendor's save is refused `<PROTECT>`, and with `%DB_IRISSYS:WRITE` added it stores the change and then answers 500, its journal switch refused `#1142` (measured on `ocupilot-b-ci`, 2026-10-02)."
  - **AD-15, AD-53:** no case; the `PUT` records `%System/%System/ConfigurationChange`.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: `JournalPort` extends `AdminPort`, and every vendor call goes through `Call`. No vendor class is called, so no AD-27 case is needed: `IsJrnDirAvailable` is not used.
- AD-3: the 13 derived rows (`FieldLists.cls:93`) and a reviewed classification.
- AD-4: the settable set read fresh, less the named exception.
- AD-5, AD-36: one descriptor and a single-object `GET` read shared by the form and its tool.
- AD-6, AD-34, AD-51, AD-53, AD-55: one tool reached by two callers; the precondition codes.
- AD-8, AD-29: the own pair and the measured pairs.
- AD-10: `journal-settings` covered, reviewed-few only, with no new predicate.
- AD-13: the singleton. AD-14: the change event.
- AD-15, AD-53: an unaudited write is named, per Task 0.
- AD-21: the sixth case, vendor-writes and existing.
- AD-22: the baseline. AD-24: context fields. AD-39: the codes in `JournalError`, with vendor text logged and never sent.
- AD-43: no auto-refresh. AD-44: the classic page and empty `CLASSICPAGES`.
- AD-58: read-back with `compare`. AD-59: `Snippet` covers the `PUT` branch.

**Decisions:**

- **The directories are arguments, not fields.** A path the caller sends would break AD-21, so the directories ride `primaryRoot`/`primaryPath` and `alternateRoot`/`alternatePath`, exactly as a new volume directory rides `volumeRoot`/`volumePath`.
- **WIJ and the archive target are shown, never set.** A `wijdir` change activates at once and moves the file the instance recovers from after a crash (1.83 GB on the throwaway). The admin API has no read of archive targets to choose from. Both stay classic-portal actions; omitting them is safe because the vendor keeps an omitted key (Task 0 step 3b).
- **The existence check is OcuPilot's.** `PathPort` lets a missing directory normalize, and the vendor's `IsJrnDirAvailable` is `[Internal]`. A missing journal directory would leave the instance unable to start a file there, so the port refuses it at the write.
- **DW-1950 is fixed where it fails.** The prohibited set is the only confirm-time reader that treats a non-404 refusal as an error. A precondition refusal already answers the mint and the screen correctly, and the fingerprint re-read already reads it as "moved". A declared code list keeps the change narrow: a tool that names none behaves exactly as before.
- **The consequence keys on the payload,** because `Consequence` sees only the payload (`Mint.cls:758-766`). The card states it whenever the write leaves `FreezeOnError` on.
- **Journal settings stays in OS management,** after Journals, as Story 18.5 decided, although the classic page is in System Administration.

**Named limits:**

1. A directory the instance cannot write is the vendor's to refuse. OcuPilot checks only that it exists, and Task 0 records the vendor's answer for the cases it measures.
2. The Save does not hold the per-target lock, as no Save does yet (DW-1882).
3. A copy-out draft taken after the alternate stops being distinct renders a script the vendor answers 409, since the prohibited set reads the precondition refusal as absent.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate, and Task 0 confirms each `<measured>`):**

1. **AD-4, after `LanguageServer`'s exception:** "**`Journal.Settings` is a named exception to the complete body** [AMENDED <date>, Story 18.18 spec gate, Rule 20]: it omits `ArchiveName`, `wijdir` and `targwijsz`, which its tool shows and never sets, because the vendor writes every key it carries and a write-image journal key activates at once; the vendor keeps an omitted key (measured at Story 18.18's Task 0)<, and an unchanged directory, because a `PUT` carrying one starts a journal file — only if measured>."
2. **AD-8, after Story 18.5's paragraph:** "**Journal settings declares `%Admin_Journal:USE` as its own pair** beside OS management's set, because the classic page requires `%Admin_Manage` and `%Admin_Journal` together, while the admin API takes either; `osmgmt.journalsettings.update` declares <measured pairs> and PathPort's `%Admin_FileSystemAccess:USE` when it sends a root [AMENDED <date>, Story 18.18 spec gate, Rule 20]."
3. **AD-13, after the `journal-file` sentence:** "`journal-settings` is a singleton (Story 18.18) [AMENDED <date>, Story 18.18 spec gate, Rule 20]."
4. **AD-21, after the eighth case:** "Journal settings' two directories are sixth-case vendor-writes directories, named by a root and a relative name, which must already exist and are never cleared (Story 18.18) [AMENDED <date>, Story 18.18 spec gate, Rule 20]."
5. **AD-51, after Story 18.5's case:** "**A tool may name the codes its fresh read refuses with when the action's precondition no longer holds** (`PRECONDITIONCODES`, Story 18.18, DW-1950): the mint and a screen action answer that refusal as it is, and inside a confirm the prohibited set reads it as it reads a 404, so the fingerprint re-read closes the proposal target-changed. Switch directory names `JOURNAL.SWITCHDIR.NOOTHER` [AMENDED <date>, Story 18.18 spec gate, Rule 20]."
6. **AD-44, after Story 18.5's `CLASSICPAGES`:** "Story 18.18's settings update declares none: the descriptor's own page, `%CSP.UI.Portal.Journal`, performs it [AMENDED <date>, Story 18.18 spec gate, Rule 20]."
7. **AD-15 and AD-53:** a thirteenth case and a fourteenth gap, only if Task 0 finds the settings `PUT` unaudited.

**Integration ACs:**

- `JournalPort`'s settings branches and `JournalRules` are new. Their consumers in this story are the Journal settings Save and the agent's confirm (AC2-AC5 in `JournalSettingsWrite` and `JournalSettingsRules`, against the real throwaway).
- Journals' Switch directory consumes an alternate the Save set (the integration leg).
- `PRECONDITIONCODES` is consumed by the confirm path (AC7 in `JournalWrite`).

**Consumes:**

- 18.5's `JournalPort`, `JournalError`, `JournalProbe` and the switch tools;
- 18.1's `PathPort` and picker;
- 16.13's editor and the `DatabaseSave` and `OAuthAuthorizationServerSave` patterns;
- 16.17's read-back, 14.1's `Snippet`, 14.2's baseline.

**Consumed-by:**

- 18.12: the agent's tool parity.
- 18.19, which adds `journal-record` beside `journal-settings` in `TYPES`.

**Ledger inbox (Rule 17):** DW-1950 is addressed by the Boundaries' DW-1950 bullet, the matrix row, AC7 and the `JournalWrite` leg. DW-1774 is met by the pinned side-bar lists in Code Map › Rosters.

**Footprint (Rule 11).** Every contended file is edited add-only (Boundaries). Report these under `footprint_extensions`, since neither epic's `paths_hint` names them: `src/OcuPilot/Area/OsMgmt/JournalRules.cls` and `JournalSave.cls` (new), `ui/src/app/app.ts`, `ui/src/app/app.spec.ts`, and `scripts/ci-throwaway.sh`, `ui/angular.json` and EXPERIENCE.md (also add-only).

**Measured at implement (Task 0, `ocupilot-b-ci`, 2026-10-02; HALTED at step 5 on two conditions).** Every `PUT` went through `JournalProbe.Run` and `AdminPort` (wall clock, guard included) and was followed by `RestoreJournal`.

- **HALT 1 (the vendor refuses a value `JournalRules` admits):** a `JournalFilePrefix` holding `.` is refused 500 (`#7209`, `#5802` on `Config.Journal:JournalFilePrefix`) and nothing is stored: `.x`, `a.b-c_D9`, `.`. Stored: `-x`, `_x`, `Ab9-_` and 64 × `a`; refused: 65 × `a` and `a/b`. A stored prefix names the next file (`journal/-x20261002.435`).
- **HALT 2 (a step needs a pair outside the three, `%DB_IRISSYS:WRITE` and `%Admin_FileSystemAccess:USE`):** the `PUT` also needs `%Admin_Operate:USE`. Principals with the install namespace's code read plus:
  - the three pairs: `GET` 200; `PUT {FileSizeLimit:1000}` 500, `<PROTECT>%SaveData+26^Config.Journal.1`, nothing stored;
  - the three and `%DB_IRISSYS:WRITE`: **500 with the change stored** (`FileSizeLimit` 1000), `#1142` "Error switching journal file: Operation requires %Admin_Operate:Use privilege";
  - the three, `%DB_IRISSYS:WRITE` and `%Admin_Operate:USE`: 200, stored, a file started; the same set without `%Admin_Journal:USE`: 200;
  - `%Admin_Journal:USE` and `%DB_IRISSYS:READ`: `GET` 200, `PUT` 500 `#921` (`%Admin_Manage:USE`); `%Admin_Manage:USE` and `%DB_IRISSYS:READ`: `PUT` 500 `<PROTECT>`; `%Admin_Journal:USE` alone: `GET` 500 (`<PROTECT>` entering `%SYS`).
- **a.** A `PUT` of the ten settable keys as read: 200 in 0.002 s; nothing stored changed, no file started, no `messages.log` line, no audit row.
- **b.** `PUT {FileSizeLimit:1000}`: only that key changed, so the vendor keeps an omitted key; a file started; 0.15 s.
- **c.** `AlternateDirectory` sent without its trailing slash is stored with it. A file started in the primary, and the vendor wrote `iris.lck` into the alternate.
- **d.** `CurrentDirectory` set to that directory is stored with the slash, and journaling moved there at once (`ocuprobe185set/20261002.422`).
- **e.** A missing `AlternateDirectory` (`ocuprobe185none/`) is created by the vendor (with `iris.lck`), stored, 200. Restored, and the directory removed (its `iris.lck` first).
- **f.** `FreezeOnError:"true"`, `FileSizeLimit` 5000 and -1, `DaysBeforePurge` 101 and `BackupsBeforePurge` 11: 500, nothing stored, each logged at error severity by `AdminPort`. `FileSizeLimit` 0 is stored 0, `1.5` stored 1, and `"1000"` stored 1000.
- **g.** `PurgeArchived:true` with `ArchiveName` "": stored true, purge counts unchanged.
- **Audit:** every `PUT` that reaches `Config.Journal.Modify` records `%System/%System/ConfigurationChange` "Modify section Journal" under the caller, a refused one too (beside a `%System/%Security/Protect` row). No AD-15/AD-53 case is needed.
- **Step 4 (S2 against S0):** `Config.Journal` and `Config.config` byte-equal; journaling in `/durable/iris/mgr/journal/` (`20261002.446`); no probe principal; async task rows 348 as at S0. Differences: 30 new journal files; `ocuprobe185set/` keeps `20261002.422z` and the vendor's `iris.lck`; `messages.log` +139 lines; monitor state 2, cleared to 0 with `$SYSTEM.Monitor.Clear()`.
- **Step 6, from the record, for the re-plan:** extra pairs `%DB_IRISSYS:WRITE` and (HALT 2) `%Admin_Operate:USE`; an unchanged directory is sent as read (step a started no file); `FileSizeLimit`'s lower bound is 0 ("from 0 to 4079"); `compare` `unslashed` for both directories; the directory line is shown (c and d each started a file, as did b); no unaudited case.
- **Plumbing (step 1)** is parked in `_bmad-output/implementation-artifacts/spec-18-18-task0-plumbing.patch`; `git apply` it first. It holds `AdminPort` and `PortFixture` `MUTATINGTYPES`, `JournalPort`'s settings `GET` and `PUT` branches (`ResolveDirectory`, `PurgeRule`, `Snippet`), `JournalError`'s `VALIDATION` and `DIRECTORY.ABSENT`, and `JournalProbe.SeedDirectory`. Checked before parking: the `GET` answers the four arguments `null`, and a missing directory is 422 `JOURNAL.DIRECTORY.ABSENT` and the manager root `PATH.MANAGERDIR` on the path field, with no vendor call.
- **For the matrix:** the stock allowed root is the manager directory, and OcuPilot's served directory is `/durable/iris/csp/ocupilot/`, outside it, so a `csp/ocupilot` name under that root resolves to a missing directory, not `PATH.SERVED`. The served leg needs a root over the data directory, as `PathPortServed` seeds (inference, not run).

## Verification

**Setup (slot B):**

- Load with `/tmp/epic-18-d6/load-throwaway.sh` (no restart), never through the MCP loader.
- Every write lands on `ocupilot-b-ci` and is restored by `RestoreJournal`.
- Run one test class per call. Send the next only once the previous run has landed in `%UnitTest_Result`, and never re-submit after a client timeout.
- Arm each class per call with `docker exec -e OCUPILOT_ALLOW_JOURNAL=1`, plus `-e OCUPILOT_ALLOW_PRINCIPALS=1` where the class declares it.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expected: 0 failures each, totals checked against `%UnitTest_Result`.
  - The story's own classes: `JournalSettingsWrite`, `JournalSettingsRules`, `JournalWrite`, `JournalWriteGate`, `JournalDescriptor`, `JournalRead`.
  - The rosters: `ToolWrite` (which also holds `PortFixture`), `Navigation`, `Wire`, `WireSecurityRead`, `WireAreaAnyScreen`, `ReadTool`, `Descriptor`, `SurfaceCoverage`, `EndpointCoverage`, `ToolRoundTrip`, `ToolEmit`, `ClassicPageGate`, `MappingDescriptor`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `EntityRef`, `Inventory`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/journal-settings.browser-spec.mjs browser/journals.browser-spec.mjs browser/license-usage.browser-spec.mjs browser/remote-databases.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 1001.
- `(once, before dev_complete)`, expected green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards, `Config.Journal` and `Config.config` equal S0, journaling writes in S0's directory, and no empty probe directory or probe principal remains.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line here:

- AC1: the descriptor's read declares `Journal.File` → `JournalRead`'s settings leg goes red. `sideBarPosition` 0 with the mirror regenerated → `Navigation` and `navigation.test.mjs` go red.
- AC2: `MergeUpdate` keeps `wijdir` → `JournalSettingsWrite`'s body leg goes red.
- AC3: the port's `DirectoryExists` check is dropped → `JournalSettingsRules`' absent leg goes red. `pVendorWrites` is passed 0 → the manager-directory leg goes red.
- AC4: the purge rule is dropped → its leg goes red. The boolean shape is dropped → the `"true"` leg goes red.
- AC5: `%Admin_Journal:USE` is dropped from the descriptor → `JournalWriteGate` and `JournalDescriptor` go red.
- AC6: `Consequence` answers "" → the consequence leg goes red.
- AC7: the `Prohibited.Target` line is removed → `JournalWrite`'s DW-1950 leg goes red on 500 `INTERNAL`.
- AC8: the baseline key is dropped → `GovernanceBaseline` goes red.
- AC9: one of the descriptor's three prompts is removed → the registry refuses the descriptor and `JournalDescriptor` goes red.

## Auto Run Result

Status: blocked
Blocking condition: intent gap: observation contradicts the plan: (1) the vendor refuses a `JournalFilePrefix` containing "." (500, #7209/#5802 on `Config.Journal:JournalFilePrefix`; `.x`, `a.b-c_D9`, `.`), which `JournalRules`' `^[A-Za-z0-9._-]{0,64}$` admits; (2) the settings `PUT` needs `%Admin_Operate:USE`, outside the screen's three pairs, `%DB_IRISSYS:WRITE` and `%Admin_FileSystemAccess:USE`: with the three pairs it is refused `<PROTECT>` and nothing is stored; with `%DB_IRISSYS:WRITE` added the vendor stores the change and then answers 500 (#1142, its journal file switch requires `%Admin_Operate:Use`).

- Halted at Task 0 step 5 (both conditions are listed there). Nothing was built: no tool, descriptor, form, roster, test or client change; source files are at `baseline_revision`.
- Recorded: Design Notes › Measured at implement (every Task 0 step, S2 against S0) and the Spec Change Log (recommended amendments: prefix `^[A-Za-z0-9_-]{0,64}$` with "Use up to 64 letters, digits, hyphens or underscores."; the tool and the Save also declare `%Admin_Operate:USE`; `FileSizeLimit` from 0 to 4079; draft AD-4/AD-8 sentences; no AD-15/AD-53 case).
- Parked: Task 0's step-1 plumbing in `spec-18-18-task0-plumbing.patch` (`AdminPort`/`PortFixture` `MUTATINGTYPES`, `JournalPort` settings `GET`/`PUT`, two `JournalError` codes, `JournalProbe.SeedDirectory`); `git apply --check` passes on this tree.
- Stage verification (independent of the handoff's report): `Config.Journal.JournalFilePrefixIsValid(".x")` answers #7209 on the throwaway; `irissys/%SYS/Journal/System.cls:137` (`SwitchFile`) requires `%Admin_Operate:USE`. Throwaway end state read at halt: `Config.Journal` equals the plan-time values (both directories `/durable/iris/mgr/journal/`, `FileSizeLimit` 1024, purge 2/2, `CompressFiles` 1, prefix and archive empty), `wijdir` "" and `targwijsz` 0, journaling in `/durable/iris/mgr/journal/20261002.446`, no `OCUPROBE*` user, monitor state 0 (the handoff cleared it with `$SYSTEM.Monitor.Clear()`). Kept per the spec: about 30 journal files the writes started, `ocuprobe185set/` holding `20261002.422z` and the vendor's `iris.lck`, and 139 `messages.log` lines.
- Not run: tests, mutations, the client build and the full sweep (nothing to verify).
