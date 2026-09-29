---
title: 'Story 18.3: Databases - configuration, creation, properties and volumes'
type: 'feature'
created: '2026-09-28'
status: 'done'
baseline_revision: '6d9e451104e0e8937421904c4e7fcd79b0015058'
baseline_commit: '6d9e451104e0e8937421904c4e7fcd79b0015058'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: 'Vendor defect candidate: DELETE /database-dir deletes a mounted database file for a principal holding only %Admin_Manage:USE and %DB_IRISSYS:READ, even while other configuration names and namespaces still use that file'
    evidence: 'Measured on ocupilot-b-ci 2026-09-28 (plan probe, Step 6 and Step 9). OcuPilot sends it only after the configuration delete succeeds and no other configuration name shares the file. Candidate IRIS defect report; human-owned.'
    severity: 'low'
    location: 'vendor %Api.Admin.Endpoints.Database.SysCRUD DELETE'
  - summary: 'Vendor defect candidate: PUT /database for a new name without Directory creates an entry pointing at the manager directory, which is IRISSYS own file'
    evidence: 'Measured on ocupilot-b-ci 2026-09-28 (plan probe, Step 5, probe OCUPROBE183Y, removed with Config.Databases.Delete). The create always sends the resolved Directory. Candidate IRIS defect report; human-owned.'
    severity: 'low'
    location: 'vendor %Api.Admin.Endpoints.Database.SysCRUD PUT'
  - summary: 'Vendor defect candidate: a POST /database-dir refused for lack of privilege leaves a directory and an unregistered IRIS.DAT that the API can neither delete (#57) nor create over'
    evidence: 'Measured on ocupilot-b-ci 2026-09-28 (plan probe, Step 9). OcuPilot refuses a caller without the declared pairs before any port call. Candidate IRIS defect report; human-owned.'
    severity: 'low'
    location: 'vendor %Api.Admin.Endpoints.Database.SysCRUD POST'
  - summary: 'Database details lists only the background tasks the classic Background tasks page holds: a compact or defragment started through the admin API (18.4 Database.Actions), ^DATABASE or %SYS.BackgroundTask.Start() has no portal row, so it carries no Database and is not listed'
    evidence: 'EnumerateTasks reads ^IRIS.Temp.MgtPortalTask only (irissys/%CSP/UI/System/BackgroundTask.cls:1195-1256), while %SYS.BackgroundTask:DatabaseList lists every compact and defragment (irissys/%SYS/BackgroundTask.cls:911-920). Read in the vendor source at the re-plan (inference until 18.4 queues one).'
    severity: 'med'
    location: 'src/OcuPilot/Port/BackgroundTaskPort.cls PortalRows'
  - summary: 'Pre-existing CI flake (Story 16.5, DW-1802): the ~2 s seeded compact of BackgroundSeed.PausedCompact can end between a pause test''s resume, mint and confirm; the retry narrows the mint-to-confirm window only'
    evidence: 'CI run 36588987899 answered TARGETCHANGED (inference: the compact ended before the confirm); the resumed compact runs 1.4-1.9 s on ocupilot-b-ci. Feature run 36530303753 ran dc34dc4a, before 6bcc6d3b widened Settled to 30 s: a DW-1819 sighting, not this.'
    severity: 'med'
    location: 'src/OcuPilot/Test/BackgroundSeed.cls PausedCompact'
---

<intent-contract>

## Intent

**Problem:** OcuPilot shows databases read-only (Epic 6). It cannot create, configure or delete one, so the classic pages are still the only way to do that. Those pages are Local Databases, the Database Wizard, the Database properties and volumes pages, and the Delete Database dialog (catalog rows SA-16 and SA-18 to SA-21). The admin API carries every step (measured on `ocupilot-b-ci`, Design Notes), with hazards OcuPilot must close itself:

- The vendor creates no `%DB_<NAME>` resource.
- `DELETE /database-dir` deletes a database's file even while namespaces and other configuration names still use it.
- Nothing stops a caller from deleting OcuPilot's own database or the instance's system databases.

**Approach:**

- Add **Local databases** to OS management, keyed by configuration name beside Epic 6's directory-keyed Databases.
- A three-step create wizard picks its directory through 18.1's `PathPort` and picker.
- A properties editor covers the configuration entry, the database file's settings and its volume settings.
- Delete uses a typed-name dialog. Its advisory names the namespaces and web applications that depend on the database, and the database shares its file with no other configuration name before the file may go.
- Every write is one derived tool that both callers reach (AD-53, AD-55), sequenced by a new `DatabasePort`.
- The kernel refuses deleting or repointing OcuPilot's databases and the system databases (AD-10).
- Database details gains a **background tasks** section: the tasks running against that database, read through Epic 16's `Port/BackgroundTaskPort`, never a second port (DW-1080).
- **Remote databases** (SA-17) is Story 18.16's, not this story's (orchestrator, Rule 5, 2026-09-28).

## Boundaries & Constraints

**Always:**

- **Screens** sit in `os-management` with the pairs `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, which the area already covers (`Screen/Area.cls:109`).
- **Extra tool pairs.** Each tool declares the measured extras and refuses a caller without them by name before any port call:
  - create: `%DB_IRISSYS:WRITE`, `%Admin_Secure:USE` and `%Admin_FileSystemAccess:USE`;
  - `updatemount`: `%DB_IRISSYS:WRITE`, plus `%Admin_Operate:USE` when it sets `MountRequired` true;
  - `update`: `%Admin_Secure:USE` when it sends `ResourceName`, and `%Admin_FileSystemAccess:USE` when it sends a new volume directory;
  - delete: `%DB_IRISSYS:WRITE`.
  - Each write tool then applies 18.14's `WithClassicPages` union over its `CLASSICPAGES`.
- **Write kinds:**
  - The create is AD-54: it fingerprints the name's absence, because `PUT /database` is an upsert.
  - The two updates are AD-4: each sends its endpoint's complete set, read fresh.
  - The delete sends no body and is `DESTRUCTIVE`.
- **Paths (AD-21's sixth case).** Two directory fields take a `root` and a relative `path`, resolved through `PathPort.Resolve(…, "directory", …, pOverwrite=0, pVendorWrites=1)` at the mint and again at the write: the create's directory and a new volume directory. The resolved path is sent only under the vendor's own field (`Directory`, `NewVolumeDirectory`), never as a settable field. The create also refuses a directory that already holds an `IRIS.DAT` (DW-1791). A directory under OcuPilot's served directory is refused `PATH.SERVED`, rendered on the field (DW-1807). `PathPort`'s instance-file set also covers each database's additional volume directories (DW-1795), and its database-directory read is pinned against a non-default configuration (DW-1796).
- **Resource first (Conventions › IRIS security objects).** Where the create is not told to use an existing `%DB_*` resource, `DatabasePort` creates `%DB_<NAME>` before the database file. A `ResourceName` is accepted only when it begins with `%DB_` and names a resource that exists.
- **The delete's order.** `DELETE /database` goes first; the vendor refuses it while any namespace uses the database. Only after it succeeds, and only when the caller chose to delete the file, the database is local and no other configuration name shares its directory, does `DELETE /database-dir` follow.
- **The delete's impact (AD-8)**, computed at mint and again when the dialog opens:
  - the namespaces that use the database through `Globals`, `Routines`, `TempGlobals` or a mapping;
  - the web applications that run in those namespaces;
  - the other configuration names that share its file.
  - A part the caller cannot read is reported unchecked, naming the pair.
- **Kernel refusal (AD-10), from either caller.** `PROHIBITED.OCUPILOTDATABASE` refuses deleting, or changing `Directory`, `Server`, `ResourceName` or `ReadOnly` of, any of these, compared by name without regard to case:
  - `OCUPILOT`;
  - the `Globals` or `Routines` database of OcuPilot's install namespace, read at the write;
  - the seven databases the classic Delete dialog refuses: `IRISAUDIT`, `IRISSYS`, `IRISLIB`, `IRISLOCALDATA`, `IRISTEMP`, `IRISMETRICS`, `IRISSECURITY`.
- **Identity:** a new entity type `database-configuration`, scope `instance`, id `Name`, rule `foldcase` (Task 0 confirms it).
- **Governance:** `osmgmt.localdatabases.delete` joins the baseline `false`; every other new write key joins it `true`.
- **Contended files are edited add-only.** EXPERIENCE.md is edited in place and stays 993 lines. `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged.

**Never:**

- No rename; the admin API has none.
- No database-size grow (`/modify-size`) and no expand-volume: both are Story 18.4's (OS-21), and the expand tool is 18.4's.
- No mount, dismount or other disk operation (18.4).
- No encryption fields (`Encrypted`, `EncryptionKeyID`: 18.7).
- No mirror fields, no `BlockSize`, no `StreamLocation` or `NewGlobalCollation` edit.
- No namespace delete chained into the database delete, nor a database delete chained into the namespace delete (SA-15 is this delete).
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses.
- No direct `Config.Databases`, `SYS.Database` or `Security.Resources` write in product code (test-only `%SYS` seeding is allowed).
- No free-text path and no client copy of the segment rule.
- No spine edit; the runner writes the amendments.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Create | `OCUPROBE183A`, root `<mgr>`, path `ocuprobe183a`, Size 1, journal on, no resource named | In order, `Security.Resource` `PUT %DB_OCUPROBE183A`, `POST /database-dir {Directory, Size, GlobalJournalState, ResourceName}`, then `PUT /database?name= {Directory}`. The database reads mounted, journaled and guarded by `%DB_OCUPROBE183A`, and appears on both lists after the change event. | none |
| Existing resource | `ResourceName` `%DB_USER` | No resource is created; the file is guarded by `%DB_USER` | none |
| Name taken or bad | A present name in another case; `1AB`, `A.B`, `A B` or 65 characters | Refused on Name before any vendor call | `DATABASE.NAME.TAKEN`, `DATABASE.NAME.SHAPE` |
| Directory holds a database (DW-1791) | path naming a probe database's directory, or `irissecurity` | Refused on `path` at the mint, at the confirm and at the Save; no vendor call | `DATABASE.DIRECTORY.INUSE` |
| Path refusals | root not allowed; `../x`; `<mgr>` itself; a directory under `csp/ocupilot/` | Refused on the named field | `PATH.ROOT`, `PATH.NAME`, `PATH.MANAGERDIR`, `PATH.SERVED` |
| Bad resource | `ResourceName` `OcuProbe183Custom`, or `%DB_NOSUCH` | Refused on `ResourceName`; no vendor call | `DATABASE.RESOURCE.SHAPE`, `DATABASE.RESOURCE.ABSENT` |
| Config PUT fails after POST | The vendor refuses the config `PUT` | `DatabasePort` deletes the file it created and answers the fault with `detail.rolledBack` true or false | the vendor's fault, normalized |
| Edit file settings | Expansion size changed | The complete `Database.SysCRUD` template set, read fresh, is sent to `PUT /database-dir?dir=`; the diff shows one row | none |
| Edit mounting | Mount required at startup turned on | The complete `Database.ConfigCRUD` set is sent; without `%Admin_Operate:USE` the edit is refused 403 naming it | `AUTH.NOPRIVILEGE` |
| Volume settings | New volume threshold, and a new volume directory through the picker | Sent within `update`'s complete set; the volume files section re-reads | `PATH.*` on the volume fields |
| Remote target of `update` | `update` names a remote configuration | Refused; nothing is sent | `DATABASE.REMOTE` |
| Delete, in use | A probe database used by a probe namespace (directly, or only through a mapping) running `/csp/ocuprobe183` | The advisory names the namespace and the application before anything is removed. Confirm is refused, and nothing is deleted. | `DATABASE.INUSE` (409) |
| Delete with file | An unused probe database, file option on | The configuration, `IRIS.DAT` and its volume files are gone; the directory and `%DB_*` resource remain | none |
| Delete keeping file | File option off | Only the configuration is gone; the file remains | none |
| Shared file | Two configuration names over one directory, file option on | Only the configuration is deleted; the advisory names the sharer; the answer carries `fileDeleted` false | none |
| Protected target | Delete, or a `ResourceName`/`ReadOnly` change, on `OCUPILOT`, the install namespace's databases or `IRISSYS` | Refused on both callers; the dialog states the reason when it opens | `PROHIBITED.OCUPILOTDATABASE` |
| Missing pair | Create without `%DB_IRISSYS:WRITE`, `%Admin_Secure:USE` or `%Admin_FileSystemAccess:USE`; delete without `%DB_IRISSYS:WRITE` | 403 names the pair; zero port calls; no directory, file, configuration or resource is left | `AUTH.NOPRIVILEGE` |
| Background tasks | Database details for a probe database with a background task running against it | The section lists that task, read through `BackgroundTaskPort`; a caller lacking the port's pairs sees the section unchecked, naming the pair | none |
| Integration | Local databases list and `osmgmt.localdatabases.read`; the create through `PathPort` and the picker; the delete's impact through `NamespaceList`, the mapping lists and `WebAppList` | The same rows (AD-36); a `PATH.*` reason on the picker's field; the impact names the dependents | Same gates |

</intent-contract>

## Code Map

**Vendor** (measured on `ocupilot-b-ci`; payloads and pairs are in Design Notes; the `%Api.Admin` classes are absent from the export):

- `Database.ConfigCRUD`: `GET /databases` (`LIST`: `filter`, `localOnly`, `remoteOnly`), `GET|PUT|DELETE /database?name=`; `ResourcesOR` `%Admin_Manage`; template `{Server, Directory, StreamLocation, ClusterMountMode, MountAtStartup, MountRequired}` at `Screen/Tool/FieldLists.cls:20-27`.
- `Database.SysCRUD`: `GET /database-dirs`, `POST|GET|PUT|DELETE /database-dir?dir=`, `GET /database-dir/volumes` (`VOLUMELIST`); PUT template `{MaxSize, ExpansionSize, NewVolumeThreshold, NewVolumeDirectory, ResourceName, NewGlobalIsKeep, GlobalJournalState, NewGlobalCollation, ClusterMountMode, ReadOnly}` at `FieldLists.cls:28-39`; `RunPost` reads `{ResourceName, VolThreshold, BlockSize, Directory, GlobalJournalState, Encrypted, MirrorDBName, MirrorSetName, Size, EncryptionKeyID}`. Routes at `Port/AdminRoutes.cls:92-97`.
- Classic pages, spelled exactly, with their `RESOURCE`: `%CSP.UI.Portal.Databases`, `.Database`, `.DatabaseVolumes`, `.Dialog.DatabaseWizard` (each `%Admin_Manage`), `.Dialog.DatabaseDelete` (`%Admin_Manage:USE`); Database details' `.DatabaseDetails` (`%Admin_Operate`) draws its tasks through `RunningInDatabase`.
- `irissys/SYS/Database.cls`: `NewVolumeDirectory` :220 (a different directory joins `VolumeDirectoryList` on save), `VolumeDirectoryList As %List [ReadOnly]` :295, `Query VolumeFiles` :1241.
- `irissys/%SYS/BackgroundTask.cls`: `Query DatabaseList()` :911-920 is public (`ID, StartTime, DisplayType, Database, RunningState, HasEnded, ProgressTotal, ProgressCurrent`); `RunningInDatabase` :899 is `[Final, Internal]` and stays unused. `irissys/%CSP/UI/System/BackgroundTask.cls:1191` `EnumerateTasks` has no database column; its `SysBGTaskId` is `DatabaseList`'s `ID`.
- `Security.Resource` `PUT` creates a resource (`Screen/Tool/ResourceCreate.cls:44`); `AdminPort` completes an empty `PublicPermission` through `CLASSCOMPLETEDTYPES` :427 (AD-27).

**Ports:**

- `Port/AdminPort.cls`:
  - `MUTATINGTYPES` :323 (no `Database.*` entry yet), `BODYLESSTYPES` :339, `VERIFIEDDELETES` :373, `VERIFIEDWRITES` :413, `QUEUEDWRITES` :538 (unchanged here);
  - `PROPERTYFAULTS` :2538 (grammar :2505-2511), `Invoke` :804, `Snippet` :2723.
  - `Test/PortFixture.cls:21` copies `MUTATINGTYPES`.
- `Port/NamespacePort.cls` (`Invoke` :79, `SnippetForm` :187, `Snippet` :196) and `Port/AuditPort.cls` (:69, :371, :380) are the model for a subclass that builds or sequences calls.
- `Port/PathPort.cls`:
  - `Resolve` :266. Its order is `PATH.NAME` :281, `PATH.ROOT` :286-298, containment :301-312, then, for a vendor-writes directory, `PATH.MANAGERDIR` :314 and `PATH.SERVED` :318. Every refusal names `pPathField` except ROOT.
  - `InstanceFile` :412; `InDatabaseDirectory` :489 (any file directly in a listed directory, or under a stream location).
  - `DatabaseDirectories` :539-573: `Config.Databases:List` with flags 1 in `%SYS`, the `:` skip :551, `StreamLocation` :552-555, no cache, and on failure empty lists :568-571 so the refusal fails closed. `PAIRS` :47.
- `Test/PathPortFixture.cls`: `UseDatabaseDirectories` :72 replaces the reader whole; `Snapshot`, `SetUp` and `Restore` :183-275 set the instance's real `%GUIFileSelector` roots.
- `Port/BackgroundTaskPort.cls`: `PAIRS` :60, `Invoke` :89, `Rows` :158, `Listed()` :244-251 (strips `SysBGTaskId`), `PortalRows` :316-354 (`EnumerateTasks` in `%SYS`), `AdminRows` :361, `Snippet` :440.

**Tools** (`Screen/Tool/`):

- `Write.cls`: `DESCRIPTORCLASS` :38, `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CLASSICPAGES` :124, `CHANGEACTION` :134, `CREATES` :151, `SCREENACTIONS` :167, `READANSWERS` :180, `SCREENVALUES` :217.
  - Methods: `DerivedFields` :324, `PortQuery` :440, `StateDiff` :486, `SettableFields` :516, `ExcludedFields` :538, `ScreenActionDelta` :607, `InputSchema` :697, `ArgumentProblem` :809.
  - `Base.cls`: `PrivilegePairs` :92, `ArgumentPairs` :123. `Screen/Gate.cls`: `RequiredPairs` :106, `WithClassicPages(pPairs, pPages)` :131.
- Models: `NamespaceCreate.cls` (`PrivilegePairs` :146, `CLASSICPAGES` :48), `NamespaceUpdate.cls` (:89, :39), `NamespaceDelete.cls` (:17-65; each delete declares its own `REMOVALROWS`), and `NamespaceCopyMappings.cls`, the model for `DeleteFile`: `SCREENVALUES` :56, the argument in `READANSWERS` :59 and `FINGERPRINTSUBJECT` :66, `PortQuery` :126, `ScreenActionDelta` :175.
- `Classification.cls`: grammar :6-23; `compare` vocabulary :13-17 (`unslashed` among it); namespace and mapping entries :469-524. `ToolFields.cls` is regenerated by `cd ui && node tools/field-lists.mjs`.

**Kernel:**

- `Kernel/EntityType.cls:51` `TYPES` (38). `Kernel/EntityRef.cls:59` `IDRULES` (no `database` rule). The client's `ENTITY_ID_RULES` is generated into `screens.generated.ts`.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250 (27), `OCUPILOTNAMESPACE` :353/:357, `OWNNAMESPACEFIELDS` :361, `OCUPILOTMAPPING` :418, `Codes()` :588 (22), `ReasonFor` :596;
  - `PermittedChangeFields` :702, `PermittedCreateFields` :815, `Prohibits` :903 (type dispatch :995-1002);
  - `Namespace` :1734, `IsOwnNamespace` :1775 (compares names only), `ReviewedFewOnly` :2344.
  - Nothing reads the install namespace's databases yet.
- `Kernel/State/Base.cls:70` `DATABASENAME` "OCUPILOT".
- `Kernel/Proposal/Impact.cls`:
  - kinds :28-34, parts :36-50, `DATABASEDESCRIPTOR` :66;
  - `Of` :105 (the `namespace-delete` branch :149), `KindOf` :177, `Guarded` :304, `Fill` :412;
  - `ListRows` :371 is Private and sends no criteria to `Screen.Read.Execute(pDescriptor, pMaxRows, .pResult, .pHttp, .pFault, .pCriteria)` (`Screen/Read.cls:275`); a truncated read is unchecked.
  - `Api/ScreenImpact.cls:21` is the dialog's impact route (`Api/Router.cls:129`).
- `Kernel/Governance/Baseline.cls`: osmgmt keys :21-40; `osmgmt.localdatabases.*` go between :26 and :27.

**Save routes:**

- `Area/OsMgmt/NamespaceRules.cls`: `Validate` :57, `HandleForm` :160, `HandleName` :207, `Databases` :302, `Gate` :374.
- `Area/OsMgmt/NamespaceSave.cls`: `Create` :115, `Update` :160, `PortViolations` :227, `Prohibited` :256, `Gate` :349.
- `Area/Task/TaskRules.HandleCheck` behind `POST /tasks/check` (`Router.cls:172`, wrapper :1411) is the step-check model.
- `Api/Router.cls`: namespace and mapping routes :119-126, wrappers :586-638.
- `Api/Error.cls`: PATH block :382-465; `ReasonForViolation` dispatch :1410-1411; `NamespaceViolationCodes` :1470, `ReasonForNamespace` :1499; namespace block :2564-2620, mapping block :2626-2674.

**Screens:**

- `Screen/Descriptor/`:
  - `NamespaceList.cls`: read :51-53 carries `Globals, Routines, TempGlobals`. `NamespaceForm.cls` is a form-page with no read.
  - `GlobalMappingList.cls`, `RoutineMappingList.cls`, `PackageMappingList.cls`: each reads `Namespace.<Kind>Mappings` `LIST` with criterion `namespace`, rows carrying `Database`.
  - `DatabaseList.cls`: route :55, position 4, `database` keyed by directory :64, `secondaryEntityTypes` `[]` :65, `OpDatabases` :79.
  - `DatabaseDetails.cls`: pairs `%Admin_Operate:USE, %DB_IRISSYS:READ` :80, id `Directory` :85. Its doc comment :5-7 still calls the tasks unreachable.
  - `DatabaseVolumeList.cls`: `VOLUMELIST`, criterion `dir`, `%Admin_Manage:USE`.
  - `BackgroundTaskList.cls`: route `tasks/background`; pairs :36, equal to Database details'; `classicPage` `%CSP.UI.Portal.BackgroundTaskList` :56; eight fields :46/:60; source port `background`, no criteria.
  - `ResourceList.cls:61`, `WebAppList.cls:91`.
- `Screen/Read.cls`: the background branch :331-340. `Screen/Registry.cls:1424` refuses criteria on a background read.
- `Screen/Area.cls:109` OS management's pairs. `Archetype.cls:70` form-page. OS management lists 1 Processes, 2 Locks, 3 System usage, 4 Databases, 5 Devices, 6 Namespaces.

**Client** (`ui/src/app/`):

- `shell/screen-outlet.ts`: `DESCRIPTOR_PAGES` :116 (TaskForm to the wizard :147), `DESCRIPTOR_EDIT_PAGES` :166. `app.ts`: action injections :306-319, sign-out resets :561-621.
- `shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :55, `FLAGGED_ACTIONS` :188, `IMPACT_ACTIONS` :216, `DESTRUCTIVE_CONSEQUENCES` :231, `confirmPending(flag)` :455-460, `open()` :607 (`flagLabel` :631), `openWithImpact` :687, `send` :728, `flag()` :828.
  - `shell/typed-name-dialog.ts` draws one optional checkbox (:70-75) and emits its state (`confirmed` :112).
  - Today a checked flag swaps the action id; no action sends a dialog value.
- `core/impact.ts`: `ImpactKind` :14, `IMPACT_PARTS` :27, `PHRASES` :114, `whyUnchecked` :165, `impactLine` :193.
- Picker and wizard:
  - `shell/server-path-picker.ts:103` (inputs :105-123, output `changed` :126), not yet embedded by any page; `core/allowed-directories.ts:59`; `core/violations.ts` (`violationsOf` :35, `reasonForField` :67).
  - `shell/form-stepper.ts:96`; `areas/tasks/task-wizard.page.ts:116` (`onNext` :221, post-create navigation :241) and `task-wizard.store.ts` (`next()` :563 posts to `/tasks/check` and keeps the step's violations through `stepOfField`).
- Namespace model (`areas/os-management/`): `namespace-actions.ts:25-40`; `namespace-form.page.ts` (database selects :141-167, form bar :180-192, refusal :288-297, post-create :384-387); `namespace-form.store.ts` (database choices :467, `publish` :504-508, no bus subscription). `core/scope.ts:339-344` re-reads on a change event.
- `areas/os-management/database-details.page.ts`: `VOLUMES_ROUTE` :45; the volume section :141-172; the sibling screen and its store :208/:219-220; `loadVolumes` :277-292, which is one-shot, and whose refusal names no pair. Pair-naming precedents: `core/privileges.ts:226` `uncheckedLine`, `core/navigation.ts:828` `screenVerdict`, `shell/detail-page.ts:100-107`.
- `core/strings.ts` keys to reuse (values stay unique, `ui/tools/strings.test.mjs:738`):
  - `tableColumnName` :357, `webAppColumnResource` :365, `taskHistoryColumnStatus` :899, `processDetailsGroupGeneral` :1001, `lockColumnDirectory` :1086;
  - `databaseColumnMaxSize` :1102, `databaseDetails*` :1116-1130, `databaseVolumeListLabel` :1132, `systemInfoDatabase` :1371;
  - `pathPicker*` :805-815, `taskStepError` :2186, `backgroundTaskListLabel` :3465, `proposalEntityTask` :1732, `taskStartTime` :2136.

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 993 lines):

- :98 Database details; :164 OS management side bar; :173 Dialogs; :371 Background tasks literals; :377 Databases literals; :378 Namespaces literals;
- :479 delete bodies; :481 kernel refusals; :577 impact phrases; :624-626 form-page, tabs, stepper.
- No PATH.* sentence is published there; `Error.cls` holds them.

**Rosters** (current values; re-derive each from its class's red, never by hand):

- ObjectScript:
  - `Descriptor` (`ReadShapes` :67-125, 54 reads; entity count :1705 = 38), `ReadTool:93` (153), `SurfaceCoverage` :54-235, `EndpointCoverage` :73-222;
  - `Navigation:339` (18 OS management screens), `Wire:700`, `WireSecurityRead` :551/:558/:561, `ProposalPrivilege:95`;
  - `Prohibited` :218 (27 types) and :672 (22 codes), `AuditingUpdate:505` (22), `RefusalCopy:108`;
  - `GovernanceBaseline:10` (`DISABLED`), `Governance:20`, `ToolDispatch:150`, `ToolEmit`;
  - `ToolRoundTrip:43` (`REFUSEEMPTY`), `ToolWrite` :1250/:1263/:1297, `PortGate:28` (19 ports), `DraftRegistry:46`;
  - `MappingDescriptor:16` (`CLASSICROSTER`, 10 tools), `ClassicPageGate` `Roster()` :262, `BackgroundTasks:74` (eight fields).
- Client: `ui/tools/navigation.test.mjs` :150-171 and :241-250, `navigation-wire.test.mjs` :103-220, `ui/src/app/shell/rail-wire.spec.ts` :100-219, `ui/tools/self-protection.test.mjs` `KERNEL_REFUSALS` :253-275.
- Browser: `ui/browser/namespaces.browser-spec.mjs` :378-385 pins `slice(0, 6)` and is unaffected. `databases.browser-spec.mjs:149` pins five cells per row, so Epic 6's list gains no action.
- CI: `scripts/ci-throwaway.sh` PRINCIPALS :193-243 and NAMESPACE_CONFIG :360-371; `ui/tools/ci.test.mjs` :1818-1927 derives the rosters from the `# classes:` lines.

**Test models:**

- `Test/NamespaceWriteProbe.cls`, `NamespaceWrite.cls` (arming :21), `NamespaceWriteGate.cls` (`RunAs` :266) with `NamespaceWriteGateProbe.cls` (`Run` :29), `MappingWriteGate.cls`;
- `AcceptPort.cls`, `DeviceRecordPort.cls`, `GovernanceFixture.cls`;
- `PathPortServed.cls` (`Deployed` :108 restricts the roots to the served directory and its parent), `PathPortInstance.cls` (oracle `LocalDatabases` :97-119, the reader pin :450-456);
- `BackgroundSeed.cls` (`Directory` :44, `PausedCompact` :113, `Tasks` :210, `Remove` :238; armed by `OCUPILOT_ALLOW_PRINCIPALS`), `BackgroundTaskFixture.cls`;
- `ui/browser/namespaces.browser-spec.mjs` (`irisSys` :71, cleanup :87-93 and :181-186, DW-1337 :338/:541), `background-tasks.browser-spec.mjs` (seeds `BackgroundSeed` over `docker exec`).

## Tasks & Acceptance

**Task 0: the implement stage's first task, before any code.** It runs on `ocupilot-b-ci` only, on `OCUPROBE183*` objects the step creates and removes. Record the results in Design Notes › Measured at implement.

1. Is a configuration name resolved without regard to case (`GET /database?name=ocuprobe183x` for `OCUPROBE183X`)? Yes keeps the id rule `foldcase`; no makes it verbatim (no rule).
2. Name corpus: which of `1AB`, `A.B`, `A B`, `A-B`, `A_B`, `%AB`, 64 and 65 characters does `PUT /database` accept? Set `DATABASE.NAME.SHAPE`'s pattern and reason to the accepted set.
3. Do these round trips change any stored value?
   - a `PUT /database` of the fresh `GET` body unchanged, including the `StreamLocation` `""` read back for the default;
   - a `PUT /database-dir` of the fresh `GET` body unchanged.
4. As a principal holding only `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, send `PUT /database-dir` once per settable field: `ReadOnly`, `GlobalJournalState`, `NewGlobalIsKeep`, `ResourceName` to an existing `%DB_*`, `NewVolumeThreshold`, `NewVolumeDirectory`. A field the instance refuses adds its pair to `update`'s `ArgumentPairs` and to spine amendment 1.
5. **HALT** `blocked`, blocking condition `observation contradicts the plan: <what>`, with nothing built, if a round trip in item 3 changes a stored value or `POST /database-dir` accepts a directory that already holds an `IRIS.DAT`.

**Execution, Part A: Local databases, the create wizard, the properties editor and the delete (AC1-AC7):**

*Kernel and port:*

- `src/OcuPilot/Kernel/EntityType.cls`, `Kernel/EntityRef.cls` -- append `database-configuration` to `TYPES` and `database-configuration:foldcase` (per Task 0) to `IDRULES` -- configuration names are a second id space beside Epic 6's directory-keyed `database` (AD-13). The client rule arrives with `screens.generated.ts`.
- `src/OcuPilot/Port/AdminPort.cls` and `Test/PortFixture.cls:21`:
  - add `Database.SysCRUD/POST`, `/PUT`, `/DELETE` and `Database.ConfigCRUD/PUT`, `/DELETE` to `MUTATINGTYPES`, each with its measured fact in the doc comment;
  - add the two `DELETE`s to `BODYLESSTYPES`.
- `src/OcuPilot/Port/DatabasePort.cls` (new, extends `AdminPort`, on the `NamespacePort` model). A `LIST` passes through unchanged. `Snippet` and `SnippetForm` mirror every branch below (AD-59).
  - **Directory lookup.** On `Database.SysCRUD` `GET`/`PUT` it resolves `dir` from `name` through `Database.ConfigCRUD` `GET`. A configuration with a non-empty `Server` answers 409 `DATABASE.REMOTE` and makes no further call. A query that already carries `dir` passes through.
  - **The create.** A `Database.ConfigCRUD` `PUT` whose query carries `root` runs, in order:
    1. `PathPort.Resolve(root, path, "directory", "root", "path", …, 0, 1)`;
    2. refuse `DATABASE.DIRECTORY.INUSE` on `path` when `<resolved>IRIS.DAT` exists (DW-1791);
    3. when `ResourceName` is empty, `Security.Resource` `PUT ?name=%DB_<NAME>` with `{"Description": "", "PublicPermission": ""}`, unless that resource exists;
    4. `POST /database-dir` with the body the port builds, `{Directory, Size, GlobalJournalState, ResourceName}`, where `ResourceName` defaults to `%DB_<NAME>`;
    5. `PUT /database?name=` with the tool's body plus `Directory`.
    - If step 5 fails, it sends `DELETE /database-dir?dir=<resolved>` and answers step 5's fault with `detail.rolledBack` true or false. A resource it created stays: it guards nothing, and its role is granted to nobody.
  - **The file update's volume directory.** A `Database.SysCRUD` `PUT` whose query carries `volumeRoot` resolves `PathPort.Resolve(volumeRoot, volumePath, "directory", "volumeRoot", "volumePath", …, 0, 1)` and sets `NewVolumeDirectory` from it.
  - **The delete.** A `Database.ConfigCRUD` `DELETE` with query `name` and `DeleteFile`:
    - reads the configuration, sends `DELETE /database?name=`, and maps a 409 #429 to 409 `DATABASE.INUSE`;
    - only when that answered 2xx, `DeleteFile` is 1, `Server` is empty and no other `LIST` row carries the same `Directory` (ignoring case and a trailing slash), sends `DELETE /database-dir?dir=`;
    - answers `{fileDeleted}`. A failed file delete after a successful configuration delete answers 200 with `fileDeleted` 0 and logs the fault.
  - **Faults** map through `PROPERTYFAULTS`: `Database.SysCRUD:896:@ResourceName=DATABASE.RESOURCE.SHAPE`, and `Database.SysCRUD:78:@path=DATABASE.DIRECTORY.INUSE` (the vendor's own refusal, kept as defense). Record each entry's measured fact.
- `src/OcuPilot/Api/Error.cls` -- a `DATABASE.VALIDATION` block after the mapping block, with `DatabaseViolationCodes`, `ReasonForDatabase` and a `DATABASE.` dispatch beside :1410-1411:
  - `DATABASE.NAME.REQUIRED` "Name the database."
  - `DATABASE.NAME.SHAPE` "A database name starts with a letter, then letters, digits, _ or -, at most 64 characters." (Task 0 may correct the rule and the sentence together.)
  - `DATABASE.NAME.TAKEN` "This instance already has a database with that name. Choose a different one."
  - `DATABASE.NAME.ABSENT` "This instance has no database with that name."
  - `DATABASE.DIRECTORY.INUSE` "That directory already holds a database. Choose another directory."
  - `DATABASE.SIZE.SHAPE` "Enter a whole number of megabytes, 1 or more."
  - `DATABASE.MAXSIZE.SHAPE`, `DATABASE.EXPANSIONSIZE.SHAPE`, `DATABASE.NEWVOLUMETHRESHOLD.SHAPE` "Enter a whole number of megabytes, 0 or more."
  - `DATABASE.RESOURCE.SHAPE` "A database's resource name starts with %DB_."
  - `DATABASE.RESOURCE.ABSENT` "No resource on this instance has that name."
  - Envelope codes: `DATABASE.INUSE` (409) "Namespaces still use this database. Delete them or point them at another database first." and `DATABASE.REMOTE` (409) "This database's file is on another server. Change its settings there."

*Rules, Save and routes:*

- `src/OcuPilot/Area/OsMgmt/DatabaseRules.cls` (new, the `NamespaceRules` model):
  - **Name:** required; the Task 0 pattern; taken when a `LIST` `Name` matches ignoring case.
  - **Sizes:** `Size` an integer of at least 1; `MaxSize`, `ExpansionSize` and `NewVolumeThreshold` integers of at least 0.
  - **ResourceName:** empty (create only), or beginning `%DB_` and present in `ResourceList`'s read as the caller.
  - **Directories:** `PATH.*` through `PathPort.Resolve`, every `PATH.SERVED` and `PATH.MANAGERDIR` among them, then `DATABASE.DIRECTORY.INUSE`.
  - `HandleForm` answers `{requiredFields, rules, resources}`. `resources` holds the `%DB_*` names, only when the caller holds `%Admin_Secure:USE`; otherwise it is absent and `resourcesRefused` names the pair. With `?name=` it also answers `configuration` (the `updatemount` tool's fresh read) and `file` (the `update` tool's fresh read, `Directory` included; 404 `DATABASE.NAME.ABSENT` when absent).
  - `HandleCheck` (`POST /database/check`, `{step, values}`, the `TaskRules.HandleCheck` model) answers `{violations}` for the step's fields, so the wizard's Next validates on the instance.
- `src/OcuPilot/Area/OsMgmt/DatabaseSave.cls` (new, the `NamespaceSave` model):
  - `Create`: gate, rules, prohibited set, the create tool, read-back.
  - `Update`: the body is `{configuration?, file?}` with changed fields only. For each group present, configuration first, it runs `updatemount`, then `update`, as `NamespaceSave.Update` does: a fresh read, then only that tool's settable keys; any other key is 400 `PORT.FIELD.UNEXPECTED`. It answers `{configuration, file}`, each with its outcome and read-back. A failed second group leaves the first applied and says so, as AD-56's two-write Save does.
- `src/OcuPilot/Api/Router.cls` -- `GET /database/form`, `POST /database/check`, `PUT /database/:id` and `POST /database`, after the mapping routes (:126), sub-resources before `:id`, with thin wrappers.

*Tools* (`src/OcuPilot/Screen/Tool/`, new; `DESCRIPTORCLASS` `LocalDatabaseList`, `PORTCLASS` `DatabasePort`; each `PrivilegePairs` ends with `Gate.WithClassicPages(tPairs, ..#CLASSICPAGES)`):

- `LocalDatabaseCreate.cls` `osmgmt.localdatabases.create`:
  - `Database.ConfigCRUD`, `CREATES` 1, `READTYPE` `GET`, `WRITETYPE` `PUT`, `CHANGEACTION` `created`;
  - no derived settable field (`ExcludedFields` names the six template fields; the port adds `Directory`), plus declared arguments `root` (required), `path`, `Size` (integer, default 1), `GlobalJournalState` (boolean, default true) and `ResourceName` (optional; empty creates `%DB_<NAME>`); `PortQuery` passes them;
  - `ArgumentProblem`/`DerivedFields` apply `DatabaseRules`, `PathPort` and the `IRIS.DAT` test at the mint;
  - pairs: the list's + `%DB_IRISSYS:WRITE` + `%Admin_Secure:USE` + `%Admin_FileSystemAccess:USE`; `CLASSICPAGES` `%CSP.UI.Portal.Dialog.DatabaseWizard`.
- `LocalDatabaseUpdateMount.cls` `osmgmt.localdatabases.updatemount`:
  - a merge `PUT` on `Database.ConfigCRUD`, sending the complete template set read fresh (AD-4); settable `MountAtStartup, MountRequired, ClusterMountMode`;
  - pairs + `%DB_IRISSYS:WRITE`; `ArgumentPairs` `%Admin_Operate:USE` when `MountRequired` is true; `CLASSICPAGES` `%CSP.UI.Portal.Database`.
- `LocalDatabaseUpdate.cls` `osmgmt.localdatabases.update`:
  - a merge `PUT` on `Database.SysCRUD` keyed by `Name` (the port resolves `dir`), sending the complete template set read fresh;
  - settable `MaxSize, ExpansionSize, ResourceName, NewGlobalIsKeep, GlobalJournalState, ReadOnly, NewVolumeThreshold`, plus declared arguments `volumeRoot` and `volumePath` for `NewVolumeDirectory`; `ExcludedFields` `NewVolumeDirectory,NewGlobalCollation,ClusterMountMode`;
  - `ArgumentPairs`: `%Admin_Secure:USE` when `ResourceName` is sent, `%Admin_FileSystemAccess:USE` when `volumeRoot` is sent, plus any Task 0 item 4 pair; `CLASSICPAGES` `%CSP.UI.Portal.Database,%CSP.UI.Portal.DatabaseVolumes`.
- `LocalDatabaseDelete.cls` `osmgmt.localdatabases.delete` (the `NamespaceDelete` shape, with `NamespaceCopyMappings`' value handling):
  - `Database.ConfigCRUD` `DELETE`, `SENDSBODY` 0, `DESTRUCTIVE` 1, `CHANGEACTION` `deleted`;
  - `SCREENACTIONS` `delete`, `SCREENVALUES` `delete=DeleteFile`; declared argument `DeleteFile` (boolean, required for the agent), passed by `PortQuery` and shown by `StateDiff` as a card row;
  - `READANSWERS` `Directory,Server,MountAtStartup,MountRequired,DeleteFile`; `FINGERPRINTSUBJECT` `Directory,Server,DeleteFile`; `PRECONDITIONFIELD` `Directory`; `REMOVALROWS` `Directory,MountAtStartup,MountRequired`;
  - pairs + `%DB_IRISSYS:WRITE`; `CLASSICPAGES` `%CSP.UI.Portal.Dialog.DatabaseDelete`.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- entries for the create and `updatemount` over `Database.ConfigCRUD` and `update` over `Database.SysCRUD`; every field `ordinary`; `Directory` and `NewVolumeDirectory` declare `compare` `unslashed`, since the vendor stores a directory with its trailing slash. Then `cd ui && node tools/field-lists.mjs` (AD-3).

*Kernel rules:*

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `database-configuration` joins `COVEREDTYPES` and the type dispatch. Permitted change fields are the two update tools' settable fields; permitted create fields are the create's.
  - `OCUPILOTDATABASE` (`PROHIBITED.OCUPILOTDATABASE`) with its `REASON` (the `:481` sentence below), `Codes()` and `ReasonFor`.
  - A `Database` predicate, stated over the effect so a bodyless delete is covered (AD-53). The own set comes from an overridable `OwnDatabaseNames()`: `Kernel.State.Base` `DATABASENAME`, the seven system names (a parameter citing the classic dialog), and the `Globals` and `Routines` of `Namespace.Namespace` `GET` for `$NAMESPACE`, read through the tool's port as the caller at the write. A failed read refuses.
  - Refused: a delete of a target whose name, upper-cased, is in the own set; a change whose diff touches `Directory`, `Server`, `ResourceName` or `ReadOnly` of such a target; and an `update` touching `ResourceName` or `ReadOnly` whose resolved directory equals an own database's `Directory` (one `Database.ConfigCRUD` `LIST` at the write, compared ignoring case and a trailing slash), because that change reaches the protected file through a second configuration name. Everything else takes the reviewed-fields sweep.
- `src/OcuPilot/Kernel/Proposal/Impact.cls` -- kind `database-delete` for `osmgmt.localdatabases.delete`; `ListRows` gains an optional criteria argument passed to `Screen.Read.Execute`:
  - part `namespaces`: `NamespaceList` rows whose `Globals`, `Routines` or `TempGlobals` equals the id ignoring case, plus each namespace of that read whose global, routine or package mapping list (criterion `namespace`) has a row whose `Database` equals the id. A refused or cut list makes the part unchecked with its pair.
  - part `applications`: `Guarded(WebAppList, "applications", "Name", <each namespace>, , "Namespace")` over the namespaces found; it renders nothing when that part is 0 or unchecked.
  - part `sharedFile`: `LocalDatabaseList` rows other than the target whose `Directory` equals the target's, compared as `DatabasePort` compares them.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- between :26 and :27, in name order: `"osmgmt.localdatabases.create": true`, `"osmgmt.localdatabases.delete": false`, `"osmgmt.localdatabases.update": true`, `"osmgmt.localdatabases.updatemount": true`.

*Descriptors:*

- `src/OcuPilot/Screen/Descriptor/LocalDatabaseList.cls` (new, `list`):
  - route `os-management/local-databases`, `labelKey` `localDatabaseListLabel`, `sideBarPosition` 7, the two pairs;
  - entity `database-configuration`, scope `instance`, id `single`;
  - read `{admin, Database.ConfigCRUD, LIST, query {localOnly: "1"}}`; fields, filter and sort `Name, Directory, Status` (default `Name` ascending);
  - columns Name (`tableColumnName`, `name`), Directory (`lockColumnDirectory`, `identifier`), Status (`taskHistoryColumnStatus`, `text`);
  - `primaryAction` `create`, `rowActions` `[{delete, ""}]`, `emptyStateKey` `localDatabaseListEmpty`, `emptyAgentKey` `localDatabaseListEmptyAgent`;
  - `classicPage` `%CSP.UI.Portal.Databases`, `commandAliases` `["local databases","configure database","create database"]`, three `promptGroupGettingStarted` prompts, `toolIdentifier` `osmgmt.localdatabases`.
- `src/OcuPilot/Screen/Descriptor/LocalDatabaseForm.cls` (new, `form-page`): route `os-management/local-databases/edit`, `labelKey` `systemInfoDatabase`, position 0, the list's pairs, id `single`, `classicPage` `%CSP.UI.Portal.Database`, three prompts, `toolIdentifier` `osmgmt.localdatabaseform`.
- `src/OcuPilot/Screen/Descriptor/DatabaseList.cls` -- `secondaryEntityTypes` becomes `["database-configuration"]`, so Epic 6's list re-fetches after a create or delete (AD-14). It gains no action.

*Client* (`ui/src/app/`):

- `areas/os-management/database-actions.ts` (new, the `namespace-actions` model): Create on Local databases.
- `areas/os-management/database-wizard.page.ts` and `database-wizard.store.ts` (new, the `task-wizard` model on `FormStepper`):
  - Step "Name and directory": Name, then `app-server-path-picker` (`kind` directory) fed by an `AllowedDirectoriesStore` the page owns. `path` is prefilled with the name lower-cased until edited.
  - Step "Size and journaling": Initial size (MB), and Journal new globals, on by default.
  - Step "Resource": "Create the resource %DB_<NAME>" (default) or "Use an existing resource" with a select from `/database/form`'s `resources`. Without them the choice is drawn disabled, naming the pair.
  - Next posts the step to `/database/check`. `reasonForField` maps `root` and `path` to the picker's `rootReason` and `pathReason` (every `PATH.*` code, `PATH.SERVED` included, DW-1807) and every other violation onto its field. Create posts `/database`, then replaces the route with the new database's editor.
- `areas/os-management/database-editor.page.ts` and `database-editor.store.ts` (new, the `namespace-form` model):
  - Group "General": Maximum size, Expansion size, Resource (select, or read-only naming the pair), Keep new globals, Journal new globals, Read only.
  - Group "Mounting": Mount at startup, Mount required at startup, Cluster mount mode.
  - Group "Volume files" (`databaseVolumeListLabel`): New volume threshold; New volume directory as text, with Change revealing the picker (`volumeRoot`/`volumePath` violations on its fields); and `DatabaseVolumeList`'s rows through `createScreenRead` with criterion `dir`.
  - Name and Directory are read-only. A sticky Save sends `PUT /database/:id` with the changed groups only.
- `shell/screen-outlet.ts`, `app.ts` -- `LocalDatabaseForm` joins `DESCRIPTOR_PAGES` (the wizard) and `DESCRIPTOR_EDIT_PAGES` (the editor); inject the actions and each store's `reset()`.
- `shell/screen-action-handler.ts`:
  - `LocalDatabaseList` joins `SCREEN_ACTION_DESCRIPTORS`, its `delete` joins `IMPACT_ACTIONS`, and `localDatabaseDeleteConsequence` joins `DESTRUCTIVE_CONSEQUENCES`.
  - A new `VALUE_FLAGS` map (descriptor, action, `{value, labelKey}`) holds `LocalDatabaseList` `delete` to `{DeleteFile, localDatabaseDeleteFileOption}`. `flag()` reads its label, so the typed-name dialog draws its one checkbox, unchecked. For such an action `confirmPending(flag)` sends `values: {DeleteFile: flag}` and keeps the action id (AD-56 (ii)). `typed-name-dialog.ts` is unchanged.
- `core/impact.ts` -- kind `database-delete` with parts `namespaces` (all four phrases), `applications` (`many`, `one`) and `sharedFile` (`many`, `one`, `unchecked`); 0 renders nothing.
- `areas/os-management/namespace-form.page.ts`, `namespace-form.store.ts` -- SA-13's database step: a "Create a database" link beside the Globals select opens the wizard under the form's leave guard, and the store re-reads its database choices on a `database-configuration` `created` or `deleted` event (the `scope.ts:339-344` model).

**Execution, Part B: the ledger inbox (AC8, AC9; DW-1807 and DW-1791 are inside Part A):**

- `src/OcuPilot/Port/PathPort.cls` (DW-1795, DW-1796):
  - Extract the row admission at :551 into `ClassMethod LocalDirectory(pDirectory As %String) As %Boolean` (empty, or beginning `:`, answers 0) and call it there.
  - Add an overridable `ClassMethod VolumeDirectories(pDirectory As %String, Output pDirectories As %List) As %Status`: `SYS.Database.%OpenId(pDirectory)`'s `VolumeDirectoryList`, each normalized with its trailing separator. A directory holding no `IRIS.DAT` answers none: it has no volumes, and its own directory is already listed. Any other failure is an error.
  - `DatabaseDirectories` appends each admitted database's volume directories to `pDirectories`; an error there empties both lists as today, so `InDatabaseDirectory` refuses (fail closed). `InDatabaseDirectory` is unchanged: its "directly in" test already covers `IRIS-nnnn.VOL` and `iris.dbdir`. Doc comments say what each reads.
- `src/OcuPilot/Test/PathPortFixture.cls` -- `FailVolumeDirectories()`, overriding only `VolumeDirectories`, so a leg fails the reader's inner read while the real `Config.Databases` read runs.
- `src/OcuPilot/Test/PathPortInstance.cls` -- its `LocalDatabases` oracle (:97-119) reads `VolumeDirectoryList` the same way and skips what `LocalDirectory` skips, so the reader pin at :450-456 compares like with like.
- `src/OcuPilot/Port/BackgroundTaskPort.cls` (DW-1080):
  - Add a Private overridable `TaskDatabases(Output pDatabases)` that runs `%SYS.BackgroundTask:DatabaseList` in `%SYS` (AD-16) once per `LIST` and keeps `ID` to `Database` for each row with `HasEnded` 0.
  - Each portal row carries `Database`: its `SysBGTaskId`'s entry, as the vendor answers it (upper case), else `""`. Each admin row carries `""`. A failed read fails the whole read (AD-36). `Listed()` emits `Database`; `Snippet` is unchanged.
- `src/OcuPilot/Screen/Descriptor/BackgroundTaskList.cls` -- `Database` joins `read.fields` and `context.fields`, with no column and no filter.
- `src/OcuPilot/Test/BackgroundTaskFixture.cls` -- `ArmDatabases(json)` overriding `TaskDatabases`.
- `src/OcuPilot/Screen/Descriptor/DatabaseDetails.cls` -- replace the doc comment's :5-7 claim with the section's source.
- `ui/src/app/areas/os-management/database-details.page.ts`:
  - A section "Background tasks" (`backgroundTaskListLabel`) after Volume files. It resolves the `tasks/background` screen with its own store, as `loadVolumes` does, and issues that screen's declared read with `maxRows` 1000, on open, on an id change and on Refresh.
  - It shows the rows whose `Database` equals the route's directory, compared ignoring case and a trailing slash, with columns Task (`proposalEntityTask`), Status (`taskHistoryColumnStatus`) and Started (`taskStartTime`).
  - None reads `databaseTasksNone`. A truncated answer adds `databaseTasksTruncated`. A caller whose `navigation.screenVerdict('tasks/background')` is denied, or whose read answers 403, sees `uncheckedLine` naming the failed pair, and no read is sent when the verdict is already denied.

*Strings and EXPERIENCE.md, for Parts A and B:*

- `ui/src/app/core/strings.ts` (append; each key cites its EXPERIENCE row; a literal that already exists as a value reuses its key, never a duplicate):
  - `localDatabaseListLabel`, `localDatabaseListEmpty`, `localDatabaseListEmptyAgent`, `localDatabaseFormRefusedAction`, `localDatabaseListPrompt1`-`3`, `localDatabaseFormPrompt1`-`3`;
  - `databaseWizardStepName`, `databaseWizardStepSize` (the Resource step's title reuses `webAppColumnResource`), `databaseInitialSize`, `databaseResourceNew`, `databaseResourceExisting`, `databaseGroupMounting`, `databaseMountAtStartup`, `databaseMountRequired`, `databaseCreateLink`, `databaseDirectoryChange`;
  - `localDatabaseDeleteConsequence`, `localDatabaseDeleteFileOption`, `databaseRefusalOcuPilot`, `databaseTasksNone`, `databaseTasksTruncated`;
  - the impact keys `impactNamespacesUse`, `impactNamespacesUseOne`, `impactNamespacesUseNone`, `impactNamespacesUseUnchecked`, `impactApplicationsInThem`, `impactApplicationsInThemOne`, `impactSharedFile`, `impactSharedFileOne`, `impactSharedFileUnchecked`.
- EXPERIENCE.md, edited in place and still 993 lines:
  - `:98`: "properties, volume files and the background tasks running against it; auto-refresh", its bracket replaced by `[AMENDED 2026-09-28, Story 18.3, DW-1080: read through the Background tasks screen's read]`.
  - `:164`: the third cell gains "Local databases (Stage 2, Story 18.3)".
  - `:173`: "database" joins the delete confirmations.
  - `:377` gains these literals, its where-clause ending `[ADDED 2026-09-28 - Story 18.3]`:
    - "Local databases" · "No local databases on this instance." · "create a database" · "change this database";
    - "Name and directory" · "Size and journaling" · "Initial size (MB)" · "Create the resource <name>" · "Use an existing resource";
    - "Mounting" · "Mount at startup" · "Mount required at startup" · "Create a database" · "Change";
    - "Also delete the database file and its volume files";
    - "No background task is running against this database." · "Only the newest <n> background tasks were checked.";
    - the list's prompts "Which databases does this instance define, and where are their files?" · "Which databases could a new namespace use?" · "What would deleting a database take with it?";
    - the form's prompts "Which resource guards this database?" · "Is this database journaled?" · "What changes if this database becomes read only?".
  - `:479`: "Deleting this database removes it from the instance's configuration. Its file stays unless you also delete it here. This cannot be undone."
  - `:481`: "OcuPilot or the instance itself depends on this database. It cannot be deleted, and its directory, resource and read-only setting cannot be changed."
  - `:577`: "<n> namespaces use it and must stop using it first: <names>" · "1 namespace uses it and must stop using it first: <names>" · "no namespace uses it" · "which namespaces use it was not checked" · "<n> web applications run in those namespaces: <names>" · "1 web application runs in those namespaces: <names>" · "<n> other databases share its file, which stays: <names>" · "1 other database shares its file, which stays: <names>" · "whether another database shares its file was not checked".
- `ui/src/app/core/screens.generated.ts` -- regenerate with `cd ui && node tools/screen-mirror.mjs` after each descriptor change.

**Tests:**

- `src/OcuPilot/Test/DatabaseWriteProbe.cls` (new, not a test case; the `NamespaceWriteProbe` model):
  - probe databases `OCUPROBE183*` under `<mgr>ocuprobe183*`, created and removed through `AdminPort` (`POST`, `PUT`, `DELETE`; never `Config.Databases`);
  - test-only `%SYS` removal of `%DB_OCUPROBE183*` resources, their directories (`%File.RemoveDirectoryTree`) and any unregistered leftover;
  - probe namespaces `OCUPROBE183*`, one probe global mapping, `/csp/ocuprobe183*` applications and one probe remote configuration (test-only `%SYS` seeding);
  - `RemoveAll` by exact prefix, and `CpfValid`.
- `src/OcuPilot/Test/DatabaseSaveFixture.cls`, `DatabaseActionFixture.cls`, `DatabaseConfirm.cls` (new seams on `DatabaseSave`, `ScreenAction` and `ConfirmFixture`, as 18.2's): the port is the one a test names in `^||OcuPilotDatabaseWritePort`, else `AcceptPort`.
- `src/OcuPilot/Test/DatabaseWrite.cls` (new; refuses unless `OCUPILOT_ALLOW_DATABASE_CONFIG` reads 1; `RemoveAll` before all, after each and after all, and a survivor fails the class). One method per matrix row, on both callers (the agent's mint and confirm; `DatabaseSave` and the screen-action route):
  - the create, its call order recorded by `DeviceRecordPort` and read back (mounted, journal state, resource);
  - the existing-resource create, and the rolled-back create (a recording port that fails the configuration `PUT`);
  - the file and mounting edits, each sending its complete set, the new volume directory through `volumeRoot`/`volumePath`;
  - the three delete shapes (with file, keeping it, shared file), and the in-use delete, direct and mapping-only;
  - the impact from `Impact.Of`, from `ScreenImpact` and on the proposal row, with the delete key enabled through `GovernanceFixture`; at the baseline the agent's delete is refused `GOVERNANCE.DISABLED` while the screen's proceeds;
  - the protected-target legs against `OCUPILOT`, the install namespace's routines database and `IRISSYS`, through `AcceptPort` on both callers, so a removed predicate shows as an accepted write, never as a changed or deleted database;
  - the synonym leg through `DatabaseProhibitedFixture` (new, the `MappingProhibitedFixture` model, whose `OwnDatabaseNames` adds a probe database): a resource change sent through a probe synonym over that probe database's directory is refused on both callers. No configuration name is ever created over a real protected database's directory.
- `src/OcuPilot/Test/DatabaseRefusals.cls` (new; refuses unless `OCUPILOT_ALLOW_DATABASE_CONFIG` and `OCUPILOT_ALLOW_PRINCIPALS` read 1):
  - the name corpus;
  - `DATABASE.DIRECTORY.INUSE` on a probe database's directory and on `<mgr>irissecurity/`, with zero vendor calls (DW-1791);
  - `PATH.ROOT`, `PATH.NAME` and `PATH.MANAGERDIR` on the wizard's check route and the agent's mint;
  - `PATH.SERVED` on `path` from both callers, with the allow-list restricted to the served directory and its parent as `PathPortServed.Deployed` does, snapshotted before and restored after, and zero vendor calls (DW-1807);
  - a root dropped between mint and confirm refuses the confirm;
  - the bad and absent resource; `DATABASE.REMOTE` from the probe remote configuration;
  - a key outside a group on each Save; an edit of a database deleted since the read (the Save's 404, the confirm's `TARGETCHANGED`).
- `src/OcuPilot/Test/DatabaseWriteGate.cls` with `DatabaseWriteGateProbe.cls` (new, the `NamespaceWriteGate` model; refuses unless `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_DATABASE_CONFIG` read 1; calls counted through `DeviceRecordPort`):
  - a reader holding the two screen pairs reads the list, the form and the check route;
  - each extra pair, when missing, is refused 403 naming it on both callers, with zero port calls and nothing left on disk or in the configuration;
  - a principal holding exactly the declared pairs creates, edits both groups, sets `MountRequired` (with `%Admin_Operate:USE`) and deletes a probe database on both callers (AD-29). A pair the instance still demands joins the tool and this class.
- `src/OcuPilot/Test/DatabaseDescriptor.cls` (new, stateless): both declarations; the four tools' fields, kinds, pairs and `CLASSICPAGES`; the Integration row, where `osmgmt.localdatabases.read` answers the rows the list's read answers, all local.
- `src/OcuPilot/Test/PathPortDatabases.cls` (new; refuses unless `OCUPILOT_ALLOW_DATABASE_CONFIG` reads 1; probe databases through `DatabaseWriteProbe`, the volume file through test-only `SYS.Database.NewVolume`; every resolution an overwrite through the real reader, never `UseDatabaseDirectories`):
  - **volume directory (DW-1795):** a probe database's new volume directory `<mgr>ocuprobe183pv-vol/`. Its `IRIS-0001.VOL` and `iris.dbdir` are refused `PATH.INSTANCE`; a file in a subdirectory of it resolves.
  - **stream location (DW-1796 i):** a probe database whose `StreamLocation` is `<mgr>ocuprobe183ps-streams/`. A file there is refused, while one in its directory's `stream/` resolves. After the location is cleared in the same process, the two answers swap.
  - **never kept (DW-1796 iii):** a file directly in a probe database's directory is refused. After its configuration is deleted with the file kept, the same resolution in the same process resolves.
  - **failure (DW-1796 iii):** with `FailVolumeDirectories()`, an unrelated existing file under `<mgr>ocuprobe183pq/sub/` is refused, and without it the file resolves.
  - **colon (DW-1796 ii):** `LocalDirectory` answers 0 for `":mirror:M:DB"`, `":ds:X"` and `""`, and 1 for a real directory. The instance cannot be configured with such a directory; see Measured.
- `src/OcuPilot/Test/BackgroundTasks.cls` (fixture legs; nine fields and context equal to them) and `BackgroundTasksLive.cls` (live) (DW-1080):
  - through `ArmDatabases`, a portal row whose task runs against a directory carries it; an ended task, a row with no task and an admin row carry `""`; a failed `DatabaseList` read fails the read;
  - live, `BackgroundSeed.PausedCompact`'s row carries `BackgroundSeed.Directory()`, compared ignoring case.
- `ClassicPageGate`'s roster and `MappingDescriptor`'s `CLASSICROSTER` gain the four tools with their pages.
- `scripts/ci-throwaway.sh` -- a block `OCUPILOT_ALLOW_DATABASE_CONFIG: "1"`, commented as creating and deleting probe databases, their resources and directories, `# classes: DatabaseRefusals, DatabaseWrite, DatabaseWriteGate, PathPortDatabases`. `DatabaseRefusals` and `DatabaseWriteGate` also join the principals block. A throwaway that predates the block is armed per call with `docker exec -e`.
- Rosters, re-derived from the code and each class's red, never hand-counted: every roster the Code Map lists.
  - The entity count is one above 38, `Prohibited` and `AuditingUpdate` code counts one above 22, and `ReadTool` gains 5 (1 read, 4 writes).
  - `Navigation`'s OS management count gains 2. `GovernanceBaseline` `DISABLED` gains `osmgmt.localdatabases.delete`, as do `Governance`'s and `ToolDispatch`'s disabled sets.
  - `ToolEmit` admits the extra and argument pairs. `ToolWrite`'s other-port tools gain four `DatabasePort` tools, `REFUSEEMPTY` four entries, and `PortGate` `DatabasePort`.
  - `EndpointCoverage` gains four routes, and `SurfaceCoverage` a row per descriptor and tool. `Descriptor`'s `ReadShapes` gains `LocalDatabaseList` and `BackgroundTaskList`'s ninth field.
  - `KERNEL_REFUSALS` and `RefusalCopy` gain `OCUPILOTDATABASE`. The navigation, navigation-wire and rail-wire rosters gain `os-management/local-databases` and `os-management/local-databases/edit`.
- Client specs:
  - new: `database-wizard.page.spec.ts` (a stubbed check answer's `PATH.SERVED` renders as the picker's `pathReason`), `database-wizard.store.spec.ts`, `database-editor.page.spec.ts`, `database-editor.store.spec.ts`;
  - extended: `database-details.page.spec.ts` (the filter ignoring case and slash, none, truncated, and a denied verdict and a 403 each naming the pair with no read sent for the first), `screen-action-handler.spec.ts` (`DeleteFile` travels as a value, the action id kept), `namespace-form.store.spec.ts` (the event re-read), `ui/tools/impact.test.mjs`.
- `ui/browser/local-databases.browser-spec.mjs` (new, the `namespaces` model; cleans up by exact probe name through `docker exec`):
  - AC1's wizard, with `PATH.MANAGERDIR` (subdirectory cleared) rendered under the picker's field, then a create;
  - AC2's edit; AC3's in-use advisory, and the delete with the file option; AC4's advisory on `IRISSYS` (open and cancel only);
  - AC8's section on Database details for `BackgroundSeed`'s paused compact, seeded and removed over `docker exec -e OCUPILOT_ALLOW_PRINCIPALS=1`;
  - AC7's DW-1337 walk of the list, wizard, editor, dialog and the new section, in both themes.

**Acceptance Criteria:**

- **AC1:** Given a holder of the Local databases pairs plus the create's pairs on `ocupilot-b-ci`, when they open OS management, then "Local databases" is its seventh side-bar entry and lists every local database configuration with its directory and status, the rows `osmgmt.localdatabases.read` answers, narrowed only by its cap.
  - When they create a probe database through the three-step wizard from an allowed root and a subdirectory, the calls run `Security.Resource` `PUT`, `POST /database-dir` and `PUT /database`, in that order. The database then reads mounted, journaled and guarded by `%DB_<NAME>`, and appears on Local databases and on Epic 6's Databases after the change event.
  - A taken name, a directory holding an `IRIS.DAT`, and each `PATH.*` refusal (`PATH.SERVED` included) render on their field before any vendor call.
  - The agent's confirmed `osmgmt.localdatabases.create` does the same.
- **AC2:** Given a probe database, when its editor changes a General setting, a Mounting setting, the new volume threshold and the new volume directory (through the picker), and Saves, then each changed group round-trips through its endpoint (`PUT /database-dir`, `PUT /database`), sending that endpoint's complete set read fresh. The volume files section lists `DatabaseVolumeList`'s rows. The agent's confirmed `update` and `updatemount` do the same.
- **AC3:** Given a probe database that a probe namespace uses (directly, or only through a mapping) and in which a probe web application runs, when Delete is chosen on its row, then the typed-name dialog's advisory names the namespace and the application before anything is removed, and the delete is refused 409 `DATABASE.INUSE` with nothing removed.
  - Given an unused probe database, after the typed name and Delete with "Also delete the database file and its volume files" checked, the configuration, `IRIS.DAT` and its volume files are gone. Unchecked, only the configuration is gone.
  - A database whose file another configuration name shares keeps its file, and the advisory names the sharer.
  - The agent's proposal, with its key enabled, carries the same impact.
- **AC4:** Given `OCUPILOT`, the install namespace's globals or routines database, or `IRISSYS`, when either caller deletes it or changes its resource or read-only setting, or changes the resource of a second configuration name over its directory, then the write is refused `PROHIBITED.OCUPILOTDATABASE`, and the Delete dialog states that reason when it opens.
- **AC5:** Given least-privileged principals on the throwaway, when they call the database tools, then:
  - the two screen pairs read the list, the form and the check route;
  - each missing extra pair is refused 403 naming it before any port call, and no directory, file, configuration or resource is left;
  - a principal holding exactly the declared pairs writes on both callers;
  - a custom resource assigned to each `CLASSICPAGES` page refuses a caller without it (`ClassicPageGate`).
- **AC6:** Given the New Namespace form, when "Create a database" creates one, then on return the form's database choices include it without a reload (SA-13). The namespace delete stays unchanged; SA-15's database delete is AC3's.
- **AC7:** Given the new screens and section, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays below 3800 kB; if it passes `maximumWarning` (2217 kB), the warning is re-based under DW-1166 together with `angular-json.test.mjs`'s literal.
- **AC8 (DW-1080):** Given a probe database with a paused background compact started through the classic Background tasks page's own task runner (`BackgroundSeed`), when Database details opens for its directory, then its Background tasks section lists that task with its status and start time, read through the Background tasks screen's declared read and `BackgroundTaskPort`. A database with none reads "No background task is running against this database.", and a caller refused that read sees the section "Not checked (requires <pair>)".
- **AC9 (DW-1795, DW-1796):** Given a probe database whose new volume directory holds a volume file, when an overwriting file consumer resolves that file through `PathPort.Resolve`, then it is refused `PATH.INSTANCE`. Given a probe database whose stream location, or whose configuration, changes between two resolutions in one process, the second resolution follows the change. A failed volume read refuses, and a directory beginning `:` is never listed.

**Review patches (2026-09-29, first review pass; tests only unless a test exposes a defect):**

- [x] P1 `DatabaseRefusals.TestADirectoryHoldingADatabaseIsRefused` -- a confirm leg: mint a create, then give its directory an `IRIS.DAT` (a probe database's), then confirm through `DatabaseRecordPort`: 422 `path:DATABASE.DIRECTORY.INUSE`, `Writes()` empty, no `%DB_<NAME>` resource. Mutation: `DatabasePort.Create` skips `HoldsDatabase`.
- [x] P2 `DatabaseWrite.TestTheRoutesAnswerOverTheWire` -- a two-group `PUT /database/:id` whose `configuration` succeeds and whose `file` is refused (e.g. an absent `ResourceName`): the refusal carries `detail.applied` `["configuration"]` and the mounting change is stored. Mutation: `DatabaseSave.Answer` drops `applied`.
- [x] P3 `DatabaseWrite` -- `DatabasePort`'s answer branches: a failed file delete after a deleted configuration answers 200 with `fileDeleted` 0 and the configuration gone; a failed configuration `LIST` keeps the file (no `Database.SysCRUD/DELETE` recorded); a failed rollback answers `detail.rolledBack` false; the shared-file leg asserts the port's `fileDeleted` 0. `DatabaseRecordPort.FailOn` may take several pairs and fail a `LIST`.
- [x] P4 `DraftPorts` (or `DatabaseWrite`) -- `DatabasePort.Snippet`'s step order: a create with and without `ResourceName`, a delete with `DeleteFile` true and false. Mutation: `Snippet` drops the resource step or the file-delete step.
- [x] P5 `DatabaseWrite.TestTheProtectedDatabasesAreRefusedOnBothCallers` -- the delete leg loops over all seven `SYSTEMDATABASES` through `DatabaseAcceptPort`; and a leg pins that `Prohibited.OwnDatabaseNames` adds both the `Globals` and the `Routines` name, through a port that answers `Namespace.Namespace` with two different names.
- [x] P6 `DatabaseWrite` -- the delete impact names a namespace that uses the probe database only through a routine mapping, and one only through a package mapping (impact only). Mutation: `Impact`'s `MAPPINGDESCRIPTORS` drops `RoutineMappingList`.
- [x] P7 `database-details.page.spec.ts` -- an id change re-reads the Background tasks section for the new directory. Mutation: drop the id-change `loadTasks`.
- [x] P8 `DatabaseRefusals` (or `RefusalCopy`) -- `Error.ReasonForViolation(code)` equals `PathPort`'s own sentence for every `PATH.*` code. Mutation: drop the `PATH.ROOT` arm of `ReasonForPath`.
- [x] P9 `DatabaseRefusals.TestARemoteDatabaseIsRefused` -- with the probe remote configuration present, `LocalDatabaseList`'s read and `osmgmt.localdatabases.read` answer no remote row (replacing the unfalsifiable "all local" claim in `DatabaseDescriptor`). Mutation: the list's read drops `localOnly`.
- [x] P10 `DatabaseWrite` -- a create minted while its name is absent and confirmed after a probe configuration of that name was added is refused (the sibling `ResourceCreate.TestATakenNameRefusesTheMintAndAConfirmTakenSince` model), with no file, resource or configuration change. Replace the first `mutation:` line with a mutation that this leg turns red.
- [x] P11 `database-editor.store.spec.ts` -- the partial-failure stub carrying `detail.applied` answers a status the server sends for it (422, or 403 `PROHIBITED.*`), not 403 `AUTH.NOPRIVILEGE`.

**Review patches (2026-09-29, second review pass, implement-2):**

- [x] Q1 `DatabasePort.Snippet` (AD-59: the script makes the change the card reviewed) -- a delete with `DeleteFile` true answers no step (the draft is 409 `PROPOSAL.NODRAFT`), because the write deletes the file only when no other configuration name shares its directory, read at the write, and a script cannot carry that; `DeleteFile` false stays one `DELETE /database` step. The create's resource step creates `%DB_<NAME>` only when `Security.Resources.Exists` answers 0 (the write's `EnsureResource` never modifies an existing resource), as a `DatabasePort` step. Doc comment and `DraftPorts.TestDatabasePort` follow; the resource-step mutation line stays true or is re-recorded.
- [x] Q2 `DraftPorts.TestDatabasePort` -- a file edit by name renders one `PUT /database-dir?dir=<payload Directory>` whose body carries no `Directory`, `volumeRoot` or `volumePath`. Mutation: the file-edit branch of `Snippet` falls through to the admin port's script.
- [x] Q3 `DatabaseProhibitedFixture` + `DatabaseWrite` -- switches that fail `OwnDatabaseNames` and, separately, `OwnDatabaseDirectories`; through `DatabaseAcceptPort` on both callers, a probe database's delete (names read failing) and its `ResourceName` change (directories read failing) are refused 403 `PROHIBITED.OCUPILOTDATABASE` with `Writes()` empty. Mutation: `Prohibited.Database` carries on with an empty own set when `OwnDatabaseNames` fails.
- [x] Q4 `DatabaseRefusals` -- the file edit's `volumeRoot`/`volumePath`: a root not allowed and `../x` are refused on those fields at the Save and at the mint, with no write; and a volume root dropped from the allow-list between mint and confirm refuses the confirm `PATH.ROOT` with nothing sent. Mutation: `LocalDatabaseUpdate.PortQuery` drops `volumeRoot`.
- [x] Q5 `PathPortDatabases` -- with a probe configuration whose directory holds no `IRIS.DAT` (a configuration only), an unrelated overwrite under `<mgr>ocuprobe183pq/sub/` still resolves. Mutation: `VolumeDirectories` drops its no-`IRIS.DAT` early answer.
- [x] Q6 `DatabaseRefusals` -- the three `Database.SysCRUD` `PROPERTYFAULTS` entries, through `AdminPort.Invoke` on probe objects: `POST /database-dir` on a probe database's directory answers `path:DATABASE.DIRECTORY.INUSE`, and one with `ResourceName` `OcuProbe183Custom` answers `ResourceName:DATABASE.RESOURCE.SHAPE`; the vendor's errors on this build are measured first, and a code the vendor also answers that leaves the mapping unapplied joins `PROPERTYFAULTS` with its measured fact. Mutation: drop the `:60` entry.
- [x] Q7 `DatabaseWrite.TestTheThreeDeleteShapes` -- the with-file leg's probe carries a second volume file (test-only `SYS.Database`), and that file is gone after the delete; and `TestACreateRunsTheResourceTheFileAndTheConfigurationInOrder` asserts the recorded bodies' keys: `POST /database-dir` `{Directory, Size, GlobalJournalState, ResourceName}`, `PUT /database` `{Directory}`.
- [x] Q8 `database-details.page.spec.ts` -- a tasks read answering 500 shows the refusal with Retry and no "none" line, and Retry reads the tasks again. Mutation: drop `tasksFaultSignal.set(true)`.
- [x] Q9 `ui/src/app/app.spec.ts` sign-out test -- a value set in `DatabaseWizard` and in `DatabaseEditor` is cleared by the teardown. Mutation: drop `this.databaseWizard.reset()`.
- [x] Q10 `DatabaseDescriptor.TestTheReadToolAnswersTheListsRowsAllLocal` -- the assertion and doc comment claim only what the class can fail on (no local configuration is left out); the remote half is `DatabaseRefusals.TestARemoteDatabaseIsRefused`'s. `DatabaseRefusals.TestARemoteDatabaseIsRefused` -- floors: the read tool resolves and each read answers at least one row before the absence assertions.
- [x] Q11 `ReadTool` -- the second assertion's message names ninety-eight write tools and the class tools' current count.

### Review Findings

Code review, 2026-09-29, `full-opus`, six layers (Blind Hunter and Edge Case Hunter each over the server and client halves, Verification Gap, Acceptance Auditor): 91 rows, 29 entries after grouping (high 1, medium 11, low 17). Every patch below was applied in this pass and verified on `ocupilot-b-ci`.

- [x] [Review][Patch] [high] A mounting edit of a database whose `MountRequired` is stored true answered 500 INTERNAL to a principal holding the tool's declared pairs, because the complete set (AD-4) carries the stored `true` and the vendor answers #921 without `%Admin_Operate:USE` (AD-8, AD-29; measured, run 382). `ArgumentPairs` now declares the pair when the write sends `MountRequired` true, the stored value read through the tool's port, and the Save's gate passes the target's name [src/OcuPilot/Screen/Tool/LocalDatabaseUpdateMount.cls:110, src/OcuPilot/Area/OsMgmt/DatabaseSave.cls:113]
- [x] [Review][Patch] [med] The editor's Change could not be withdrawn: with one allowed root the picker's preselected root marked the form dirty and every later Save sent `volumeRoot` with an empty path, refused or setting an unintended volume directory; Cancel beside the picker now keeps the current one [ui/src/app/areas/os-management/database-editor.store.ts:354]
- [x] [Review][Patch] [med] Verification gaps closed in new class `DatabaseWriteDetail` and existing ones: the create's file size and its resource's empty public permission on both callers, the create's and the delete's card rows, the read-back verdicts of a create and a new volume directory, the impact matching a namespace by `Globals`, `Routines` and `TempGlobals` alone, the form read's `resources`, a remote configuration's delete with the file option sending no file delete, and a mounting edit of a deleted database refused `TARGETCHANGED` (the file-edit leg's "did not re-create it" could not fail) [src/OcuPilot/Test/DatabaseWriteDetail.cls, src/OcuPilot/Test/DatabaseRefusals.cls:300, :350]
- [x] [Review][Patch] [low] The check route's resource step answered 500 when the resource read was refused; `ResourceViolation` now keeps the port's fault, and the reader's resource and name steps are pinned at 403 [src/OcuPilot/Area/OsMgmt/DatabaseRules.cls:157, src/OcuPilot/Test/DatabaseWriteGate.cls:113]
- [x] [Review][Patch] [low] A file edit sending `volumePath` without `volumeRoot` passed every rule and wrote nothing its card showed; it is refused `PATH.ROOT` on `volumeRoot` [src/OcuPilot/Area/OsMgmt/DatabaseRules.cls:112]
- [x] [Review][Patch] [low] The delete's applications part read checked and empty when its namespaces part was unchecked; it now carries the same unchecked reason [src/OcuPilot/Kernel/Proposal/Impact.cls:179]
- [x] [Review][Patch] [low] `ToolEmit` dropped its own-write-pair expectation for every tool with no `WRITERESOURCE`; it now exempts only `osmgmt.localdatabases.update` [src/OcuPilot/Test/ToolEmit.cls:214]
- [x] [Review][Patch] [low] `DatabaseError`'s codes had no sweep; `DatabaseDescriptor.TestEveryDatabaseCodeIsSaidAndListed` holds each code's sentence and `ViolationCodes()` against the class [src/OcuPilot/Test/DatabaseDescriptor.cls]
- [x] [Review][Patch] [low] A Save of both groups showed the file group's read-back only; it shows the one that does not match [ui/src/app/areas/os-management/database-editor.store.ts:410]
- [x] [Review][Patch] [low] The wizard's `ResourceName` reason under the new-resource choice was referenced by no `aria-describedby` [ui/src/app/areas/os-management/database-wizard.page.ts:444]
- [x] [Review][Patch] [low] `VALUE_FLAGS.labelKey` is typed `keyof typeof STRINGS` [ui/src/app/shell/screen-action-handler.ts:223]
- [x] [Review][Patch] [low] `local-databases.browser-spec.mjs`'s `after` removes the probes even when the seed's removal fails [ui/browser/local-databases.browser-spec.mjs:270]
- [x] [Review][Patch] [low] Doc and name corrections: `Impact`'s header, `HandleForm`'s `Name` key, the `HandleUpdate` comment, `typed-name-dialog.ts`'s flag sentence, the arming comment's data server, and `Governance`/`ToolDispatch` test names that said "Two" [src/OcuPilot/Kernel/Proposal/Impact.cls:3, scripts/ci-throwaway.sh:377]
- [x] [Review][Defer] [med] The New Namespace form's Create a database leaves the form, dropping typed values, and lands on the database editor; AC6 holds through the form's next open [ui/src/app/areas/os-management/namespace-form.page.ts] -- deferred: DW-1824, decision-pending (product call)
- [x] [Review][Defer] [med, unverified] A new volume directory naming another database's directory resolves; whether the vendor collides volume files there is unmeasured [src/OcuPilot/Area/OsMgmt/DatabaseRules.cls:112] -- deferred: DW-1791 occurrence, residual noted for 18.4
- [x] [Review][Defer] [low] An accepted editor Save re-opens through `reset()`, losing focus [ui/src/app/areas/os-management/database-editor.store.ts:400] -- deferred: DW-1825, wontfix-accepted
- [x] [Review][Defer] [low] `DatabaseWrite.cls` is 764 lines [src/OcuPilot/Test/DatabaseWrite.cls] -- deferred: DW-1826, wontfix-accepted

Rejected (layer: BS/BC blind server/client, ES/EC edge server/client, VG, AA):

- false: A2's `ResourceName` half (AA) -- a reader holding only the screens' pairs saved a file edit whose complete set carried the unchanged `ResourceName` (run 384); BS22 -- `DatabaseDirectories`' doc states the unaligned lists; BC8 -- no rule refuses a flag field; BC11 -- the spec's Never excludes those edits; BC18 -- a browser spec's own oracle is deliberate; VG `DatabaseWrite.cls:172` -- dropping `CREATES` still reddens that test.
- closed by the triage log, no new evidence: BS2/BC5 `fileDeleted` unsurfaced; BS19 the delete-with-file draft; BS24 remote delete/mount; BC4/EC1 a tasks 403 with no pair (still unreachable: the section's pairs are the port's); BC20 unchecked applications render nothing.
- spec-bound: BS5 per-namespace mapping reads; BS10 a refused second group leaves the first applied; BS16 own-database fields and set; BS18 a rolled-back create keeps its resource and directory; BS21 per-call volume reads failing closed; BC6 the delete sentence; BC10 field labels; BC14 the tasks section's store and no criterion; BC16 its column keys; BC23 task actions.
- low, unlikely and more than a direct correction: BS7/ES14/BS8 create-body ordering and stray keys; BS9/ES4/ES5/ES6 empty bodies, keys or groups; BS11/ES8 a non-boolean journal state; BS13/ES11 a configuration whose file is unreadable; BS25 duplicated defaults; BC7 the new-resource label when it exists; BC15/EC2 overlapping tasks reads; BC19 `dependsOnNothing`; BC21 a form read missing a group; BC22 a volumes 403; BC24 duplicated constants; BC25 other editor spec paths; EC3 a blank existing-resource choice; EC4 a stale path refusal until Next; ES2 `applied` lost on a 500; ES12 a file delete under a running task; AA4 the native `disabled` radio (form-input precedent); AA6 any 409 read as in use; VG `:78` (the port refuses first).
- theoretical: BS4 a lock-database-only mapping; BS6 `#60` on a file edit; BS15/ES7 over 1,000 resources; BS17/ES10 a same-name create inside one POST; BS20/ES13 symlinked synonyms; EC7 two database events out of order; AA3 a resource deleted between mint and confirm.

**Rework 1 (2026-09-29, CI):**

- [x] [CI] browser shard 1/3 (run 36573329469 on `b43a0a2d`): `a11y-structural-invariants.browser-spec.mjs` 12/12 failed in its hook, `Waiting failed: 30000ms exceeded` in `structural-walk.mjs` `goInApp` -- `database-wizard.page.ts`/`database-wizard.store.ts` -- opening the create wizard marks the form dirty with nothing typed: `server-path-picker.ts` preselects the single allowed root and emits `changed`, and `DatabaseWizard.setLocation` records that as an edit (`change('path')` sets `FormDirty`). Leaving the wizard then raises the unsaved-changes guard, the walk's next in-app navigation is canceled and the URL restored (measured by the runner on `ocupilot-b-ci`: after `local-databases/edit` then `namespaces/edit`, the walk asking for `namespaces/package-mappings/edit` stood at `local-databases/edit`). The fix must make the picker's one preselection of a single root leave the wizard clean while any user change of root or path still marks it dirty; pin it (a store or page spec: open, preselect, not dirty; then a user change, dirty) with a demonstrated mutation, and re-run `a11y-structural-invariants.browser-spec.mjs` (both themes) against a rebuilt and redeployed bundle on `ocupilot-b-ci`. Check the editor's Change picker under the same rule (its preselection follows an explicit Change, so dirty there is intended).

### Review Findings (rework 1)

Code review, 2026-09-29, `full-opus`, four layers over `8692236c..11682150` (Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor): 14 findings, 4 kept after grouping (all low, all patched), 0 high or medium. The `[CI]` item's fix holds: the wizard opens clean and a user's change of root or path marks it dirty (re-run in review: `a11y-structural-invariants` 12/12 on `ocupilot-b-ci`, `main-JT27HVRD.js`, 83 of 83 walked; components 1841/1841 after the patches). The flag changes no other consumer: the editor passes only `root` and `path`, and Epic 16's task dialogs rebuild `{root, path}` on submit.

- [x] [Review][Patch] [low] The picker's doc names the flag but not a form's duty to hold a `preselected` report without marking itself dirty; the next form that draws the picker on open would open dirty again [ui/src/app/shell/server-path-picker.ts:37]
- [x] [Review][Patch] [low] The picker spec's mutation comment named the select's assertion, not the `changes` one [ui/src/app/shell/server-path-picker.spec.ts:165]
- [x] [Review][Patch] [low] `preselectRoot` clearing a `root` refusal (Next pressed before the allow-list arrived) was untested; a store leg pins it [ui/src/app/areas/os-management/database-wizard.store.spec.ts:94]
- [x] [Review][Patch] [low] Rule 19: no recorded mutation showed `preselectRoot` holding the root that Next and Create send, or the store's path half of the user-change leg; both are recorded under `## Verification`

Rejected:

- false: the flag reaching Epic 16's `submitted` values (the dialogs emit a fresh `{root, path}`); the store comment "the first test goes red" (true as written); legs without in-file mutation comments (the `## Verification` line is the record); `preselectRoot`'s early return untested (removing it adds one notify, nothing visible).
- outside the rework, not high: `structural-walk.mjs` `goInApp` reports a guard-canceled navigation as a 30 s timeout.
- spec or lead bookkeeping: the bundle line's 2217 kB warning, the triage log's doubled row, the oversized spec's growth, the cycle-log order.

**Rework 2 (2026-09-29, CI):**

- [x] [CI] instance shard 2/3 (run 36588987899 on `f13a007c`): `BackgroundTasksLive.TestTheAgentsConfirmPausesACompact` red -- the confirm answered `PROPOSAL.TARGETCHANGED` (then: not paused, no ledger row, no marker). It passed on `b43a0a2d` and `8692236c`, and nothing server-side changed after `8692236c`, so the failure is timing-dependent. This story added `Database` to every Background tasks row (`BackgroundTaskPort.WithDatabases`/`TaskDatabases`/`KeepRunning`, the list descriptor's fields), which the write tools' fresh read carries into their fingerprint. Find which value moved between the mint and the confirm for a just-resumed compact (for example `Database` read from `%SYS.BackgroundTask:DatabaseList` lagging or changing against the portal row, or a moving `Details` counter that predates this story), and fix it at its cause: a fingerprint subject carries no value that moves while the target's own state does not (AD-51), and a task's `Database` must read the same for the task's life or stay out of the subject. Pin it with a test that goes red on the moving value (on `ocupilot-b-ci`, `BackgroundTasksLive` or a recording fixture) and a demonstrated mutation; then run `BackgroundTasks`, `BackgroundTasksLive` (at least three times, one run at a time) and `database-details.page.spec.ts`. If the cause predates this story, say so with evidence and still fix it here only if it is inside the Background tasks footprint this story already extended.

### Review Findings (rework 2)

Code review, 2026-09-29, `full-opus`, four layers over `6d9e4511..822c0e3f` (Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor): 33 rows, 5 entries after grouping (0 high, 1 medium, 4 low); every patch applied, one low accepted (DW-1830). The `[CI]` item holds: `FINGERPRINTSUBJECT` is `Status` alone on all three tools and the confirm digests that projection (`Mint.cls:274`, `Confirm.cls:687`); every retry exit asserts, so a repeatable refusal still goes red; the new leg reddens when `Database` enters the subject. Re-run after the patches: `BackgroundTasksLive` 427, 7/7.

- [x] [Review][Patch] [med] DW-1829 and this spec's `deferred:` item cited run 36530303753 for a 30 s `Settled` race; that run ran `dc34dc4a`, before `6bcc6d3b` widened the wait (a DW-1819 sighting). Both corrected; the open cause is DW-1802's race (occurrence appended) [deferred-work.md DW-1829, DW-1802]
- [x] [Review][Patch] [low] A red after the last attempt could not tell a lost race from a regression; the message now carries the compact's state [src/OcuPilot/Test/BackgroundTasksLive.cls:305]
- [x] [Review][Patch] [low] Doc corrections: at most `AGENTATTEMPTS` compacts in all, not re-seeds; a compact that ends before the mint is not retried; the moving-value mutation reads "every confirm is refused"; `ProposeAndConfirmPause` returns 0 only for the seed, turn or mint [src/OcuPilot/Test/BackgroundTasksLive.cls:285-293, :314]
- [x] [Review][Patch] [low] `## Verification`'s stale "latest runs green" clause removed; the Cause bullet's claim about the CI run labeled (inference)
- [x] [Review][Defer] [low] `BackgroundTasksLive.cls` is 537 lines -- DW-1830, wontfix-accepted

Rejected: the resume-to-mint and re-read-to-`Pause()` windows and the sibling screen test's resume-then-pause (DW-1802's root cause, carried by DW-1829; the last is outside the rework); the `Done` check unpinned (it sets only how fast a repeatable refusal reds; run 413 read "attempt 1"); `AGENTATTEMPTS` of 0 (theoretical); the new leg's mutation shared with the subject-declaration leg (it also pins the confirm's projection); spec bookkeeping (run 420's forcing, triage-row labels, the lead's `[x]` item wording, repeated figures).

## Spec Change Log

- 2026-09-29, runner, rework 2: CI run 36588987899 was red on `f13a007c` (`BackgroundTasksLive`, one [CI] item under Tasks & Acceptance); status set to `in-progress`.
- 2026-09-29, runner, rework 1: CI run 36573329469 was red on `b43a0a2d` (the structural walk, one [CI] item under Tasks & Acceptance); status set to `in-progress` for one rework iteration. The code review's patches are committed with the rework commit.
- 2026-09-29, runner, before re-plan: the orchestrator split remote databases (SA-17, Part C) into Story 18.16 (Rule 5, 2026-09-28) and kept expand-volume and size-grow in 18.4. The intent contract drops Part C and adds DW-1080 (Database details' background tasks through `BackgroundTaskPort`), DW-1807 (`PATH.SERVED`), DW-1795 and DW-1796. Since the first plan, `PATH.INSTANCE` covers every file in every configured database and journal directory (DW-1790), and every file and vendor-writes directory under OcuPilot's served directory is refused `PATH.SERVED` (DW-1798, DW-1806). Status set to `draft` for the re-plan.

- 2026-09-29, runner, recovery: the first implement stage was killed by an account quota limit after its first review pass and patches P1-P11. Its uncommitted work was saved as a patch, the tree reset, DW-1814 committed alone (63c34657), and feature (Epic 16 through 16.6) merged in (baa7701d); the patch was re-applied with nine three-way list conflicts resolved by the runner. Status reset to `in-progress`: the tree holds that partial implementation, to be completed and verified, not trusted.

## Review Triage Log

### 2026-09-29 — Review pass

- verdicts: 22 findings — high 0, medium 9, low 8, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) `DatabasePort.Create`'s own `IRIS.DAT` refusal at the confirm is untested; the rules refuse first everywhere else — P1: a confirm leg in `DatabaseRefusals`, mutation recorded.
  - `[medium]` `[patch]` (verification-gap) `DatabaseSave`'s `detail.applied`, which the editor consumes, is untested on the server — P2: a two-group partial-failure leg over the wire, mutation recorded.
  - `[medium]` `[patch]` (verification-gap) `DatabasePort`'s failed-file-delete, failed-`LIST` and failed-rollback branches are untested — P3: `TestAFailedLaterStepIsAnsweredAsFarAsItLanded`; `DatabaseRecordPort.FailOn` takes several pairs and reads.
  - `[medium]` `[patch]` (verification-gap) `DatabasePort.Snippet`'s create and delete scripts are unpinned (AD-59) — P4: `DraftPorts.TestDatabasePort`, mutation recorded.
  - `[low]` `[patch]` (verification-gap) only `OCUPILOT`, one install database and `IRISSYS` of the own set are exercised, and `Globals` is indistinguishable from `Routines` on this instance — P5: the delete leg loops all seven system names through `DatabaseAcceptPort`; a leg arms distinct `Globals` and `Routines` names.
  - `[medium]` `[patch]` (verification-gap) the impact's routine and package mapping lookups are unpinned — P6: `TestTheImpactNamesRoutineAndPackageMappingUsers`, mutation recorded.
  - `[low]` `[patch]` (verification-gap) Database details' id-change re-read is untested — P7: an id-change leg in `database-details.page.spec.ts`, mutation recorded.
  - `[low]` `[patch]` (verification-gap) `ReasonForViolation`'s `PATH.*` sentences are mostly unpinned — P8: `TestEachPathCodeCarriesThePortsSentence` over all eight codes, mutation recorded.
  - `[medium]` `[patch]` (verification-gap) `DatabaseDescriptor`'s "all local" assertion cannot fail with no remote configuration present — P9: `TestARemoteDatabaseIsRefused` asserts the list's read and `osmgmt.localdatabases.read` omit the probe remote row, mutation recorded.
  - `[low]` `[reject]` (verification-gap) the `LocalDirectory` call site in the reader is not pinned — spec-decided (Design Notes: the instance cannot hold a `:` row, so the predicate is pinned); a row-injecting seam would add complexity for an unreachable case.
  - `[medium]` `[patch]` (verification-gap) the `CREATES` mutation went red at the mint for the wrong reason and no leg confirms a create whose name was taken after its mint — P10: `TestANameTakenSinceTheMintRefusesTheConfirm`; its mutation replaces the `CREATES` line.
  - `[false]` `[reject]` (verification-gap) AC sub-clauses without their own `mutation:` line, and three browser legs not re-run under mutation — Rule 19 asks one demonstrated mutation per AC, and each of AC1-AC9 has at least one observed red.
  - `[low]` `[patch]` (verification-gap) `database-editor.store.spec.ts` stubs a 403 `AUTH.NOPRIVILEGE` carrying `applied`, which the server never sends (pairs are checked before any group) — P11: the stub answers 422 `DATABASE.VALIDATION` with `applied`.
  - `[medium]` `[defer]` (intent-alignment) the section lists only tasks with a classic portal row; admin-API compacts are not attributed — already the fourth `deferred:` item from the plan (AD-27 amendment); not re-added.
  - `[false]` `[reject]` (intent-alignment) an in-use delete relies on the vendor's 409 — the intent's own "The delete's order" says the vendor refuses it; the mapping-only case is pinned in `TestAnInUseDeleteIsRefusedAndRemovesNothing`.
  - `[false]` `[reject]` (intent-alignment) the kernel refuses a resource or read-only change through a second name, and a failed read refuses — the AD-10 amendment and the spec's "A failed read refuses" state both.
  - `[low]` `[reject]` (intent-alignment) the agent's mint names the field and sentence, not the `DATABASE.*` code — the agent path's refusal convention (AD-39); no user-facing defect, and the field is asserted.
  - `[low]` `[patch]` (intent-alignment) `fileDeleted` false is asserted nowhere — grouped with P3: the shared-file leg asserts the port's `fileDeleted` 0; the screen action's answer shape is the generic one the spec leaves unchanged.
  - `[low]` `[reject]` (intent-alignment) `delete` and `updatemount` do not refuse a remote configuration named by the agent — the matrix scopes `DATABASE.REMOTE` to `update`; each is a legitimate configuration write under the same gates, and 18.16 reuses the delete; reopen_if an agent proposal on a remote configuration misleads (18.16's scope).
  - `[false]` `[reject]` (intent-alignment) EXPERIENCE.md :98's bracket was replaced rather than added to — the spec's task directs "its bracket replaced by".
  - `[medium]` `[patch]` (intent-alignment) the confirm-time `DATABASE.DIRECTORY.INUSE` is untested — grouped with P1.
  - `[false]` `[reject]` (intent-alignment) the "Create a database" link, the two-write Save with `detail.applied`, and the rolled-back create keeping its resource are outside the intent text — each is a spec task (AC6; `DatabaseSave`; `DatabasePort`'s create).

### 2026-09-29 — Review pass (implement-2)

- verdicts: 25 findings — high 0, medium 7, low 12, false 4, maybe-false 2
- findings:
  - `[medium]` `[patch]` (verification-gap) a failed `OwnDatabaseNames` or `OwnDatabaseDirectories` read is untested, so AD-10's fail-closed refusal could fail open unseen — Q3: fixture switches and `DatabaseWrite.TestAFailedOwnSetReadRefuses` on both callers, mutation recorded.
  - `[medium]` `[patch]` (verification-gap) the file edit's `volumeRoot`/`volumePath` refusals and their re-resolution at the write are untested — Q4: `DatabaseRefusals.TestTheVolumeDirectoryRefusalsLandOnTheirFields`, mutation recorded.
  - `[medium]` `[patch]` (verification-gap) `VolumeDirectories`' answer for a configured directory with no `IRIS.DAT` is untested — Q5: `PathPortDatabases.TestAConfigurationWithNoFileRefusesNothing`, mutation recorded.
  - `[low]` `[patch]` (verification-gap) the file edit's script is unpinned (AD-59) — Q2: a `DraftPorts.TestDatabasePort` leg, mutation recorded.
  - `[low]` `[patch]` (verification-gap) Database details' failed tasks read and its Retry are untested — Q8: a spec leg, mutation recorded.
  - `[medium]` `[patch]` (verification-gap) the sign-out teardown's two database store resets are untested — Q9: `app.spec.ts`, each reset's mutation recorded.
  - `[medium]` `[patch]` (verification-gap) the three `Database.SysCRUD` `PROPERTYFAULTS` entries are never exercised — Q6: `DatabaseRefusals.TestTheFileEndpointsFaultsLandOnTheirFields` on probe directories; the vendor answered #70/#60/#73 and #70/#18/#78, each carrying a mapped code, so the parameter is unchanged; mutation recorded.
  - `[low]` `[reject]` (verification-gap) the delete impact's unchecked namespaces part is untested on the server — reachable only through a custom resource on a mapping list's classic page or a list past its cap, and a test needs principals and page assignment; reopen_if a caller holding the delete's pairs reads an advisory that omits a mapping-only user without an unchecked note.
  - `[low]` `[patch]` (verification-gap) `DatabaseDescriptor`'s "no data server" half cannot fail where no remote configuration exists — Q10: the assertion and doc claim only that no local configuration is left out.
  - `[low]` `[patch]` (verification-gap) `TestARemoteDatabaseIsRefused`'s absence assertions have no floor — Q10: the read tool resolves and each read answers rows first.
  - `[false]` `[reject]` (verification-gap) AC sub-clauses without their own `mutation:` line — carried: Rule 19 asks one per AC, and AC1-AC9 each have an observed red.
  - `[maybe-false]` `[reject]` (verification-gap) a 403 on the tasks read with no `detail.failedPair` would show the "none" line — every 403 path found (`ScreenRead`'s gate, `BackgroundTaskPort.GateRefusal`, `AdminPort.Denied`) sets `failedPair`; if one did not, only low: settle by a tasks-read 403 whose detail lacks it.
  - `[low]` `[reject]` (verification-gap) a configuration `PUT` without `root` or `Directory` reaches the vendor's manager-directory upsert — no shipped caller sends one (`root` required, the mounting edit sends its fresh `Directory`); reopen_if a caller composes a configuration `PUT` without `Directory`.
  - `[low]` `[reject]` (intent-alignment) an unchecked applications part renders nothing on the advisory — the phrase set is the spec's (`EXPERIENCE.md:577`), and the part is only non-empty when namespaces already make the vendor refuse the delete; reopen_if a deleter lacking `%Admin_Secure:USE` needs the application list to act.
  - `[false]` `[reject]` (intent-alignment) "no vendor call" is tested as "no vendor write" — the name look-up and resource read are the rules' own inputs and cannot be skipped; the refused rows send no write, which `Writes()` asserts.
  - `[low]` `[reject]` (intent-alignment) the agent's mint answers field and sentence, not the `DATABASE.*` code — carried: AD-39's agent refusal convention.
  - `[maybe-false]` `[reject]` (intent-alignment) argument pairs follow the arguments, so an edit on a database whose stored `MountRequired` is true sends it without `%Admin_Operate:USE` — whether the vendor's #921 fires on an unchanged true is unmeasured; if it does, only low: the vendor refuses with nothing changed; settle by that edit as a principal without the pair.
  - `[medium]` `[patch]` (intent-alignment) the delete's script sent `DELETE /database-dir` whether or not the file is shared, and the create's script modified an existing `%DB_<NAME>` (AD-59: a script making a change the card did not review) — Q1: a delete with its file answers no step (409 `PROPOSAL.NODRAFT`), and the resource step creates only when absent; mutation re-recorded.
  - `[medium]` `[defer]` (intent-alignment) the Background tasks section lists portal rows only — carried: the fourth `deferred:` item.
  - `[low]` `[reject]` (intent-alignment) `delete` and `updatemount` accept a remote configuration named by the agent — carried.
  - `[false]` `[reject]` (intent-alignment) the directory arm, the "Create a database" link, the two-group Save, the rolled-back create's resource, the four routes and the `DatabaseList` read are outside the intent — carried: each is a spec task or amendment.
  - `[low]` `[patch]` (intent-alignment) "its volume files are gone" is not tested with a volume file — Q7: the delete legs' probes carry a second volume file, gone with the file option and kept without it.
  - `[low]` `[patch]` (intent-alignment) the create row's exact bodies are not asserted — Q7: the recorded `POST` and `PUT` bodies' keys are asserted, mutation recorded.
  - `[false]` `[reject]` (intent-alignment) a protected target is minted before the confirm refuses it — the kernel refuses at the confirm and at the draft for every tool (AD-10); no protected write is sent.
  - `[low]` `[reject]` (intent-alignment) a least-privileged principal's mint is never exercised, only its confirm — the mint's gate is the kernel's, pinned for these tools by `ProposalPrivilege` and `ToolEmit`; reopen_if a tool's mint admits a caller its confirm refuses.

### 2026-09-29 — Review pass (rework 1)

- verdicts: 6 findings — high 0, medium 0, low 3, false 3, maybe-false 0
- findings:
  - `[low]` `[patch]` (verification-gap) the store's user-change leg reads dirty whether or not `preselectRoot` dirties, so it does not pin the order it names, and no `mutation:` line names it — both halves now assert clean after `preselectRoot`; `preselectRoot` marking dirty reddens it, mutation line updated.
  - `[low]` `[patch]` (verification-gap) the "a user's change of root marks dirty" half has no `mutation:` line — `setLocation` dirtying only on a path change reddens the store's root half and the page's several-roots leg; line recorded.
  - `[false]` `[reject]` (verification-gap) the `[CI]` item is ticked with no browser result recorded — the stage ran the three browser specs after the redeploy and records them under `## Auto Run Result` at finalize; the fix is a spec edit.
  - `[false]` `[reject]` (intent-alignment) the item's browser finish line has no recorded result — same as the row above: 12/12, 6/6 and 5/5 on `main-JT27HVRD.js`, recorded at finalize.
  - `[false]` `[reject]` (intent-alignment) the diff widens 18.1's shared picker beyond the two wizard files the item names — the lead's dispatch allows the picker telling a preselection apart; the flag is optional, and the editor and Epic 16's task dialogs bind `root` and `path` only, with no emission-shape assertion (`git grep` on `OCU-1-epic16`).
  - `[low]` `[patch]` (intent-alignment) the editor's dirty-after-Change is pinned only in its store spec, not through the picker's labeled report — `database-editor.page.spec.ts`' AD-21 leg asserts clean before Change and dirty after the preselection; `setVolumeLocation` not dirtying reddens it, mutation line recorded.

### 2026-09-29 — Review pass (rework 2)

- verdicts: 9 findings — high 0, medium 0, low 6, false 3, maybe-false 0
- findings:
  - `[low]` `[patch]` (verification-gap) `EndedBeforeTheConfirm` retries any `TARGETCHANGED` whose task reads Done afterwards, so a fresh read that failed as the task ended is retried too, against its doc's "any other refusal fails at once" — both doc comments now state exactly what is checked; the port read never failed in 104,731 one-row reads across three compacts' ends (stage probe).
  - `[low]` `[reject]` (verification-gap) the spec omits run 420 (the one retry) and the `database-details.page.spec.ts` run, and 417-419 may predate the saved text — the fix is a spec edit: run 420 was a forced race, the component spec ran 16/16, and three runs after the final save are recorded at finalize.
  - `[low]` `[reject]` (verification-gap) three attempts reduce the race rather than remove it; a larger seed would remove it (inference) — every one of 8 unforced local runs (417-419, 421-425) paused on attempt 1, and the fix is `BackgroundSeed.cls` (Epic 16's) doubling every seeded test's fill and disk.
  - `[false]` `[reject]` (intent-alignment) no test goes red on the value that moved (`Status` Running to Done) — that refusal is correct and pinned by `BackgroundTasks.TestTheFingerprintRefusesAMovedStatus`; the new fixture test pins the measured boundary read (`Running` with `Database` "" in 2 of 3 probes).
  - `[low]` `[reject]` (intent-alignment) the cause is asserted in a doc comment with no evidence — the fix is a spec edit; the timings and the probe are recorded under `## Auto Run Result`.
  - `[low]` `[patch]` (intent-alignment) a failed `WithDatabases` read is a route to `TARGETCHANGED` that is neither tested nor ruled out, and the retry can admit it — grouped with the first row: 0 failures in 104,731 reads at the boundary, and the doc no longer claims to tell the two apart.
  - `[false]` `[reject]` (intent-alignment) the added per-read query may widen the mint-to-confirm window — a one-row read costs about 0.11 ms with both queries (about 35,000 in 4 s), against a window of about 0.5 s.
  - `[low]` `[reject]` (intent-alignment) no `database-details.page.spec.ts` run is recorded — the fix is a spec edit; it ran 16/16, recorded at finalize.
  - `[false]` `[reject]` (intent-alignment) the criterion is now met by any one of three compacts — the successful attempt asserts the same four outcomes; a retry replaces only a seed whose compact ended before its confirm.

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: every vendor call goes through `AdminPort` or a port extending it: `DatabasePort`, `PathPort`'s reads, and `BackgroundTaskPort` (AD-27's Story 16.5 case, extended by amendment 8).
- AD-3: the create's and updates' derived fields; the create's POST-only keys are the port's.
- AD-4: each update sends its endpoint's complete set.
- AD-5, AD-36, AD-44: one descriptor per screen; the list and its tool share one read; Database details issues the Background tasks screen's declared read under that screen's own gate; the classic pages plus `CLASSICPAGES` (DW-1784).
- AD-6, AD-34, AD-40: proposal and confirm.
- AD-8, AD-29: pairs, extra and argument pairs, the removal impact.
- AD-10: the new predicate. AD-13, AD-14: the new type and events. AD-15: the marker. AD-16: `%SYS` by explicit save and restore.
- AD-21: the sixth case for both directories, DW-1791, DW-1795's volume directories, and `PATH.SERVED` (DW-1806, DW-1807).
- AD-22: the baseline. AD-39: violations.
- AD-51: the delete's declared subject. AD-53, AD-55: two callers. AD-54: the create's absence fingerprint. AD-56 (ii): `DeleteFile` as a declared value.
- AD-58: read-back. AD-59: `Snippet` for every `DatabasePort` branch.
- AD-26 is not engaged: no write here queues, and `POST /database-dir` answered 201 synchronously.

**Measured on `ocupilot-b-ci`, 2026-09-28, first plan.** Every probe object was removed, and removal was re-checked by the lead.

- **Create:**
  - `POST /database-dir {Directory}` answers 201 and creates the directory, `IRIS.DAT`, `iris.lck` and `stream/`. It mounts the database under `%DB_%DEFAULT`, not journaled unless `GlobalJournalState:true`, and makes no resource and no configuration.
  - `PUT /database?name= {Directory}` answers 201 and adds only the configuration. `PUT /database` for a directory that does not exist also answers 201, reading `Unavailable`.
  - `ResourceName` not beginning `%DB_` is refused (500 #896 on `POST`; `<FUNCTION>` on `PUT`), and a refused `POST` leaves an empty directory. A `%DB_` name with no resource is accepted and never created.
- **DW-1791.** A second `POST /database-dir` on a directory holding `IRIS.DAT` answers 500, mounted (#60) or dismounted (#78), and the data survives. `PUT /database` naming another database's directory answers 201: a synonym, with a logged warning.
- **Updates.** Both `PUT`s are upserts that keep omitted fields. A `PUT /database` without `Directory` for a new name creates an entry at the manager directory (IRISSYS's file).
- **Delete:**
  - `DELETE /database` answers 409 #429 while any namespace uses the database, directly or only through a mapping. It touches no file and leaves a kept file mounted.
  - `DELETE /database-dir` never refuses for configuration names or namespaces. It dismounts and deletes `IRIS.DAT` and every volume file, and keeps the directories, `stream/`, `iris.dbdir` and the `%DB_*` resource.
  - The classic dialog deletes the file only when asked (`DeleteDatFile`, unchecked), hides that option when synonyms exist, and refuses the seven system databases by name.
- **Pairs:**
  - Reads, `PUT /database-dir` and `DELETE /database-dir` need `%Admin_Manage:USE` and `%DB_IRISSYS:READ`.
  - `POST /database-dir`, `PUT /database` and `DELETE /database` also need `%DB_IRISSYS:WRITE`. A refused `POST` leaves an `IRIS.DAT` the API cannot remove.
  - `MountRequired:true` also needs `%Admin_Operate:USE` (#921).
  - `%Operator` gets 403 with `errors: []` on `/databases`, `/database-dirs`, `/database` and `/volumes` (the reported claim, confirmed), and 200 on `GET /database-dir`. `/database-dirs` is a plain array of 14 (confirmed).
- **Async (for 18.4).** Expand-volume, modify-size, truncate and info answer 202. Their `Location` is a v1 `async-result` path, and the poll carries no progress figure. One expand was read once and its row deleted; #7846 appeared 0 times.
- **Remote (for Story 18.16).** A remote configuration is created without a live ECP link. `GET /ecp/data-server/databases` blocked about 11 s and opened an ECP connection attempt, and `%Service_ECP` was left disabled. A data server a remote database uses cannot be deleted (409 #423).

**Measured on `ocupilot-b-ci`, 2026-09-28, this re-plan** (probe objects listed and removed under Auto Run Result):

- **Volume directories (DW-1795).**
  - Setting a database's `NewVolumeDirectory` to another directory adds it to `VolumeDirectoryList` on save and creates it holding `iris.dbdir`. `SYS.Database.NewVolume` then puts `IRIS-0001.VOL` there, which `VolumeFiles` lists as volume 1.
  - `SYS.Database.%OpenId` reads `VolumeDirectoryList` for a dismounted database, and for a principal holding only `PathPort`'s `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`.
  - It fails `#6046` for a configured directory with no `IRIS.DAT`.
- **The `:` skip (DW-1796).** `Config.Databases.Create` stores a `:ds:` or `:mirror:` directory as a relative path under the manager directory (`/durable/iris/mgr/:ds:X/`), so this instance cannot be configured with a directory beginning `:`.
- **Background tasks (DW-1080).**
  - A principal holding only `%Admin_Operate:USE` and `%DB_IRISSYS:READ` reads `%SYS.BackgroundTask:DatabaseList`.
  - `BackgroundSeed.PausedCompact`'s task answered `ID` 5, `Database` `/DURABLE/IRIS/MGR/OCUBGSEED/` (upper case), `PAUSED` and `HasEnded` 0.
  - `EnumerateTasks` answered its row with `SysBGTaskId` 5 and status "Paused".

**Measured at implement (Task 0), on `ocupilot-b-ci`, 2026-09-29.** No HALT condition met.

1. `GET /database?name=` resolves a configuration name without regard to case (`OCUPROBE183X`, `ocuprobe183x` and `OcuProbe183x` each answered 200), and `PUT /database?name=ocuprobe183x` updated the existing entry (200). A new lower-case name is stored upper-cased. The id rule stays `foldcase`.
2. `PUT /database` accepted `A-B`, `A_B` and 64 characters (201), and refused a leading digit, `.`, a space and a leading `%` (500 #42) and 65 characters (500 #7201, `MAXLEN` 64). `DATABASE.NAME.SHAPE`'s rule and sentence stand as planned.
3. A `PUT /database` and a `PUT /database-dir` of the fresh `GET` body, unchanged, each answered 200 and left every stored value equal (`GET`, `Config.Databases.Get` and `SYS.Database` read before and after).
4. A principal holding only `%Admin_Manage:USE` and `%DB_IRISSYS:READ` changed `ReadOnly`, `GlobalJournalState`, `NewGlobalIsKeep`, `NewVolumeThreshold`, `NewVolumeDirectory`, `MaxSize` and `ExpansionSize` through `PUT /database-dir` (200, stored). `ResourceName` was refused (500 #822) and accepted once `%Admin_Secure:USE` was added, the pair `update` already declares. No pair is added.
5. `POST /database-dir` on a directory holding a mounted `IRIS.DAT` answered 500 (#70, #60) and left the file. A `NewVolumeDirectory` set once stays in `VolumeDirectoryList` after `NewVolumeDirectory` is set back.

Probe objects created and removed: database `OCUPROBE183X` (directory `ocuprobe183x/`, volume directory `ocuprobe183x-vol/`), configurations `OCUPROBE183-B`, `OCUPROBE183_B`, `OCUPROBE183L` and the 64-character name (no directory), resources `%DB_OCUPROBE183X` and `%DB_OCUPROBE183Z`, role `OcuProbe183T0` and user `OcuProbe183T0User`. Afterwards no `OCUPROBE183*` configuration, directory, resource or principal remained.

**Decisions:**

- **Two lists, two keys.** Local databases (configuration, keyed by name, `%CSP.UI.Portal.Databases`) sits beside Epic 6's Databases (operations, keyed by directory, `OpDatabases`), as the classic portal separates them. The new type `database-configuration` keeps AD-13's identity single-spelled, and Epic 6's list declares it secondary, so it re-fetches. Position 7 is appended, so 18.2's pinned six stay.
- **One create tool, one port sequence.** The resource comes first (Conventions), then the file, then the configuration. `DatabasePort` rolls back the file it created if the configuration fails.
- **Two update tools, one Save.** Each tool covers one endpoint and its own complete set, and the Save sends the changed groups in order. `update` is keyed by name, and the port finds the directory.
- **Delete stays one write.** The vendor refuses it while in use, so OcuPilot never deletes a namespace for it; the advisory names the namespaces and applications instead. The file follows only on request and never while shared, which closes the vendor's unguarded file delete for OcuPilot's callers.
- **Protected databases compare names, as the intent says, and also refuse a resource or read-only change through a second configuration name over one of their directories.** That change reaches the protected file itself (AD-10 by effect, AD-53). A synonym's delete stays permitted: the file stays while it is shared.
- **DW-1791 lives in the database rules, not in `PathPort`.** Only a database create is disqualified by an existing `IRIS.DAT`, and the vendor refuses it too (measured).
- **DW-1807 needs no new product code.** `PathPort.Resolve` already refuses `PATH.SERVED` on `path`, and the wizard maps every `path` violation to the picker. The plan adds the mapping, an instance leg and a component leg. The browser leg renders `PATH.MANAGERDIR`, which the default roots reach; `PATH.SERVED` needs the allow-list changed, which the instance leg does and restores.
- **DW-1795 lives in `PathPort`, because the instance-file set is its.** A volume directory holds a database's files exactly as its directory does. The read goes through `SYS.Database` in `%SYS`, beside the `Config.Databases` read: the admin API's `VOLUMELIST` needs `%Admin_Manage:USE`, outside `PAIRS`, and one call per database. A directory with no `IRIS.DAT` is skipped rather than failed, because an operator can configure a database whose file does not exist (measured), and failing there would refuse every overwrite on the instance.
- **DW-1796 is pinned on the real reader**, with probe databases whose configuration changes between two reads in one process. The colon skip is pinned on an extracted predicate, since the instance cannot hold such a row. The failure leg goes through a seam that fails only the inner volume read, so the reader's own propagation is under test.
- **DW-1080 is a row field, not a criterion.**
  - A criterion on a background read is refused by `Screen/Registry.cls:1424`, and would need an AD-21 amendment and a new criterion on the list and its tool. The field needs one vendor query in the port.
  - The field is filled only while the task has not ended, so the section's filter is one equality and never a localized status word.
  - Database details' pairs equal Background tasks', so the only reachable refusal of the section's read is a custom resource on `%CSP.UI.Portal.BackgroundTaskList` (`Gate.RequiredPairs`). The page renders any refusal as unchecked, naming the pair.
  - A task with no portal row is not listed (the `deferred:` item, for 18.4).
- **Expand-volume and size grow are 18.4's** (OS-21). 18.3's volume view shows the files and settings and queues nothing.
- **Governance:** delete `false` (preamble); create and both updates `true` (through 2026-10-04).
- **Not in this story:** rename (no API), encryption (18.7), mirror and block size, `StreamLocation` and `NewGlobalCollation` edits, disk operations (18.4), and remote databases (18.16).

**Size.** One reviewable story. Part A is about 18.2's size plus the wizard and `DatabasePort`. Part B adds one `PathPort` read with its test class, and one Background tasks field with a Database details section. If the gate wants it smaller, DW-1080 (the port field, the section and AC8) separates cleanly to 18.4, whose compact and defragment are what the section lists; nothing else does.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate):**

1. **AD-8, after 18.14's paragraph:** "**Story 18.3's database tools declare pairs beyond their screen's set** [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]: the create, the mounting update and the delete declare `%DB_IRISSYS:WRITE`, because a principal holding only the Local databases screens' `%Admin_Manage:USE` and `%DB_IRISSYS:READ` was answered `<PROTECT>` on `POST /database-dir`, `PUT /database` and `DELETE /database`, and a refused `POST` left an `IRIS.DAT` the admin API could not remove (measured on `ocupilot-b-ci`, 2026-09-28). The create also declares `%Admin_Secure:USE`, because the vendor makes no `%DB_<NAME>` resource and the port creates or checks it, and `PathPort`'s `%Admin_FileSystemAccess:USE`. The mounting update declares `%Admin_Operate:USE` when it sets `MountRequired` (refused #921 without it), and the file update declares `%Admin_Secure:USE` when it sends a resource name and `%Admin_FileSystemAccess:USE` when it sends a new volume directory. Each is refused by name before any port call."
2. **AD-8, after the namespace impact paragraph:** "**A database delete names its impact too** [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]: the namespaces that use it through their globals, routines or temporary database or through a global, routine or package mapping, read through the Namespaces list's and the three mapping lists' declared reads, which the vendor's delete refuses while any remains (409 #429, measured on `ocupilot-b-ci`, 2026-09-28); the web applications that run in them, read through the Web applications list's read; and the other configuration names that share its file, which keeps the file."
3. **AD-10, a new bullet after OcuPilot's own mappings:** "**OcuPilot's and the instance's own databases** [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]: deleting, or changing the directory, server, resource or read-only setting of, OcuPilot's own database, the globals or routines database of the namespace OcuPilot's API runs in (read at the write), or one of the seven databases the classic Delete Database dialog refuses (`IRISAUDIT`, `IRISSYS`, `IRISLIB`, `IRISLOCALDATA`, `IRISTEMP`, `IRISMETRICS`, `IRISSECURITY`), compared by name without regard to case, is refused `PROHIBITED.OCUPILOTDATABASE`, from either caller, and so is a resource or read-only change sent through another configuration name over one of their directories, which reaches the same file. The vendor's own file delete does not refuse a database in use (measured on `ocupilot-b-ci`, 2026-09-28), so these are refused on the write path. Every other database delete or change is permitted, the delete at the destructive treatment with its removal impact."
4. **AD-21, at the end of the sixth case (DW-1791):** "A database create also refuses, in its own rules and before any vendor call, a directory that already holds an `IRIS.DAT`; the vendor's `POST /database-dir` refuses it too, leaving the file intact, while its `PUT /database` accepts a second configuration name for that directory, which the create never sends alone (measured on `ocupilot-b-ci`, 2026-09-28) [AMENDED 2026-09-28, Story 18.3 spec gate, DW-1791, Rule 20]."
5. **AD-21, after the DW-1790 sentence (DW-1795):** "It also covers every file directly in each configured local database's additional volume directories (`SYS.Database` `VolumeDirectoryList`, which a new volume directory joins when it is saved), read at call time; a configured directory holding no `IRIS.DAT` has none, and any other failure to read them refuses (measured on `ocupilot-b-ci`, 2026-09-28) [AMENDED 2026-09-28, Story 18.3 spec gate, DW-1795, Rule 20]."
6. **AD-52, a new paragraph:** "**A declared port may sequence several admin API calls for one write** [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]. `DatabasePort`'s database create resolves its directory through `PathPort`, refuses one that holds an `IRIS.DAT`, creates the `%DB_<NAME>` resource unless the tool names an existing one (`Security.Resource` `PUT`), creates the file (`Database.SysCRUD` `POST`, a body the port builds from the tool's declared size, journal state and resource and the resolved directory), then sends the create's own `Database.ConfigCRUD` `PUT`, deleting the file it created if that `PUT` fails. Its delete sends `DELETE /database` and, only when asked, when that succeeded and when no other configuration name shares the directory, `DELETE /database-dir`. The proposal, fingerprint, gates, marker and ledger row are the one write's."
7. **AD-44, appended to the DW-1784 paragraph:** "Story 18.3's: the database create `%CSP.UI.Portal.Dialog.DatabaseWizard`, the mounting update `%CSP.UI.Portal.Database`, the file update `%CSP.UI.Portal.Database` and `%CSP.UI.Portal.DatabaseVolumes`, and the delete `%CSP.UI.Portal.Dialog.DatabaseDelete` [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]."
8. **AD-27, appended to Story 16.5's case (DW-1080):** "Story 18.3 extends it [AMENDED 2026-09-28, Story 18.3 spec gate, DW-1080, Rule 20]: under the same gate the port also reads the public `%SYS.BackgroundTask:DatabaseList` and names, on a portal row whose task has not ended, the directory of the database that task runs against (`Database`), so Database details lists those tasks through the Background tasks screen's declared read (AD-5) and no second reader exists; a task with no portal row, such as one started through the admin API or `^DATABASE`, is not named (inference from the vendor source)."

**Integration ACs:**

- AC1: `LocalDatabaseList` and `osmgmt.localdatabases.read` answer one read (AD-36), pinned in `DatabaseDescriptor`.
- AC1: the create consumes `PathPort.Resolve`, with the resolved path reaching the vendor as `Directory` (`DatabaseWrite`, recording port). The picker, with its page-owned store, renders a `PATH.*` reason on its field (browser spec, wizard spec).
- AC2: the editor consumes `DatabaseVolumeList`'s read.
- AC3: the delete's impact consumes `NamespaceList`'s, the three mapping lists' and `WebAppList`'s declared reads through their own gates, pinned in `DatabaseWrite` and the browser spec.
- AC8: Database details consumes `BackgroundTaskPort` through the Background tasks screen's declared read, against a real seeded task (browser spec, `BackgroundTasksLive`).
- AC9: every overwriting file consumer consumes `PathPort`'s extended instance-file set. None ships yet, so `PathPortDatabases` exercises `Resolve` itself.

**Consumes:**

- 18.1: `PathPort.Resolve`, `app-server-path-picker`, `AllowedDirectoriesStore`, `PathPortFixture`.
- 18.2: `NamespaceList`'s read and `NamespaceForm`.
- 18.14: the three mapping lists, `CLASSICPAGES`, `WithClassicPages`, `ClassicPageGate`, and the `NamespacePort` and `MappingProhibitedFixture` models.
- 16.5: `BackgroundTaskPort`, the Background tasks read, `BackgroundSeed`.
- Earlier stories: `WebAppList`'s and `ResourceList`'s reads, Epic 6's `DatabaseVolumeList` read, 16.19's impact, 16.17's read-back, 14.1's `Snippet`, 14.2's baseline and `GovernanceFixture`, and Epic 9's `FormStepper`.

**Consumed-by:**

- 18.4: its disk operations and OS-21's expand act on the databases this story creates, and its compact and defragment are the tasks AC8's section lists (see `deferred:`).
- 18.12: the agent's grown tool set.
- 18.13: the own-database predicate must keep holding under a multi-namespace install.
- 18.15: enable-interop's ENSTEMP and SECONDARY databases appear on Local databases (inference).
- 18.16: remote databases reuse `DatabasePort`'s delete and `DATABASE.REMOTE` (inference).
- Every later overwriting file consumer (16.4, 18.4's integrity output, 18.5) meets `PathPort`'s extended set.

**Ledger inbox (Rule 17):**

- DW-1791: addressed by `DATABASE.DIRECTORY.INUSE` in `DatabaseRules` and `DatabasePort`, amendment 4, and `DatabaseRefusals`' legs. Recommended: `resolved-by:18-3`.
- DW-1795: addressed by `PathPort.VolumeDirectories`, amendment 5, and `PathPortDatabases`' volume leg. Recommended: `resolved-by:18-3`.
- DW-1796: addressed by `PathPortDatabases`' stream, never-kept, failure and colon legs and the oracle fix. Recommended: `resolved-by:18-3`.
- DW-1807: addressed by the wizard's field mapping, `DatabaseRefusals`' `PATH.SERVED` leg and the wizard spec leg. Recommended: `resolved-by:18-3`.
- DW-1080: addressed by the `Database` field, the Database details section, amendment 8 and AC8. Recommended: `resolved-by:18-3`, with the portal-only limit harvested from `deferred:` to 18.4.
- DW-1774: met by the roster tasks.

**Contended files and footprint:**

- Contended with Epic 16, edited add-only: `Error.cls`, `Router.cls`, `Baseline.cls`, `strings.ts`, EXPERIENCE.md, the rosters, `ci-throwaway.sh` and `ci.test.mjs`, `screen-action-handler.ts`. `screens.generated.ts` and `ToolFields.cls` are regenerated.
- Story 16.5's files, extended add-only as the dispatch directs (a footprint extension for the runner to report): `Port/BackgroundTaskPort.cls`, `Screen/Descriptor/BackgroundTaskList.cls`, `Test/BackgroundTasks.cls`, `Test/BackgroundTasksLive.cls`, `Test/BackgroundTaskFixture.cls`.
- Not touched: `Area.cls`, `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/Proposal/Mint.cls`, `typed-name-dialog.ts`.

## Verification

**Setup (slot B):**

- Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`.
- Every database write happens there, on `OCUPROBE183*` objects only (and `BackgroundSeed`'s own, which it creates and removes). `server: "ocupilot-slot-b"` reaches the dev instance, never the throwaway, so no MCP tool writes a database.
- One test class per call; send the next only once the previous has landed in `%UnitTest_Result`.
- Arm the new classes per call with `docker exec -e OCUPILOT_ALLOW_DATABASE_CONFIG=1`, adding `-e OCUPILOT_ALLOW_PRINCIPALS=1` for `DatabaseRefusals`, `DatabaseWriteGate`, `BackgroundTasksLive` and the `PathPort*` classes.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time, for each class below -- expected: 0 failures each, with totals checked against `%UnitTest_Result`:
  - the story's own: `DatabaseWrite`, `DatabaseWriteGate`, `DatabaseRefusals`, `DatabaseDescriptor`, `PathPortDatabases`, `PathPortInstance`, `PathPort`, `PathPortServed`, `BackgroundTasks`, `BackgroundTasksLive`, `ClassicPageGate`, `MappingDescriptor`;
  - the rosters and shared suites: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Prohibited`, `AuditingUpdate`, `RefusalCopy`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `ToolWrite`, `ToolRoundTrip`, `DraftRegistry`, `PortGate`, `ProposalPrivilege`, `EntityRef`, `Navigation`, `Wire`, `WireSecurityRead`, `ScreenGrounding`, `ImpactRoute`, `Envelope`, `NamespaceWrite`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/local-databases.browser-spec.mjs browser/databases.browser-spec.mjs browser/namespaces.browser-spec.mjs browser/background-tasks.browser-spec.mjs` -- expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh` -- expected: clean, and `wc -l` on EXPERIENCE.md reads 993.
- `(once, before dev_complete)` -- expected: green with a non-zero count; CI runs the full browser suite (Rule 29):
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards, no `OCUPROBE183*` configuration, `ocuprobe183*` directory, `%DB_OCUPROBE183*` resource, gate principal or `OCUBGSEED` database remains, and the `%GUIFileSelector` allow-list reads as before.

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line. Predicate mutations run only against `AcceptPort`.

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC1 | `LocalDatabaseCreate` drops `CREATES` | `DatabaseWrite`'s taken leg (the upsert is minted) |
| AC1 | `DatabasePort` skips the resource step | `DatabaseWrite`'s create read-back (resource absent) |
| AC1 (DW-1791) | `DatabaseRules` skips the `IRIS.DAT` check | `DatabaseRefusals`' DW-1791 legs (a vendor call is recorded) |
| AC1 (DW-1807) | the wizard store drops `path` violations | `database-wizard.page.spec.ts`' `PATH.SERVED` leg; the browser `PATH.MANAGERDIR` leg |
| AC2 | `LocalDatabaseUpdate` sends only the changed keys | `DatabaseWrite`'s complete-set leg |
| AC3 | `DatabasePort` sends the file delete when shared | `DatabaseWrite`'s shared-file leg (file gone) |
| AC3 | `KindOf` omits `database-delete` | `DatabaseWrite`'s impact leg; the browser advisory |
| AC3 | `confirmPending` swaps the action instead of sending `DeleteFile` | `screen-action-handler.spec.ts`; the browser delete-with-file leg |
| AC4 | the `OCUPILOTDATABASE` arm is removed | `DatabaseWrite`'s protected legs (an accepted write is recorded) |
| AC4 | the directory arm is removed | `DatabaseWrite`'s synonym leg |
| AC5 | the create drops `%DB_IRISSYS:WRITE` | `DatabaseWriteGate` (the port is called) |
| AC5 | `LocalDatabaseDelete` empties `CLASSICPAGES` | `ClassicPageGate`'s delete leg; `MappingDescriptor`'s roster |
| AC6 | the namespace form store ignores the event | `namespace-form.store.spec.ts` |
| AC7 | a wizard step label drawn in `--ocu-surface` | the DW-1337 legs, in both themes |
| AC8 | `TaskDatabases` keeps ended tasks | `BackgroundTasks`' ended-task leg |
| AC8 | the section compares directories with case | `database-details.page.spec.ts`; the browser AC8 leg |
| AC9 (DW-1795) | `DatabaseDirectories` skips `VolumeDirectories` | `PathPortDatabases`' volume leg |
| AC9 (DW-1796) | the reader ignores a configured `StreamLocation` | the stream leg |
| AC9 (DW-1796) | the reader keeps its answer in `^||` | the never-kept leg |
| AC9 (DW-1796) | `DatabaseDirectories` drops a `VolumeDirectories` error | the failure leg |
| AC9 (DW-1796) | `LocalDirectory` answers 1 for a leading `:` | the colon leg |

- Every line below was re-observed on 2026-09-29 on `ocupilot-b-ci`, each mutation reverted byte-identical and its class reloaded with subclasses: runs 38-60 before the container's last recreation, runs 365-378 on the recreated one (its full sweep is runs 1-363).
- mutation: the confirm's create re-read in `Confirm` reads the name as absent (`tPresent` 0) → `DatabaseWrite.TestANameTakenSinceTheMintRefusesTheConfirm` red (run 41): the confirm was not refused and a file and resource were made.
- mutation: `DatabasePort.Create` skips `EnsureResource` → `DatabaseWrite.TestACreateRunsTheResourceTheFileAndTheConfigurationInOrder` red (run 38; call order and resource read-back).
- mutation: `DatabaseRules.DirectoryViolations` skips the `IRIS.DAT` test → `DatabaseRefusals.TestADirectoryHoldingADatabaseIsRefused` red (run 39; step-check and mint legs).
- mutation: the wizard store drops `path` violations → `database-wizard.page.spec.ts`' `PATH.SERVED` and `DATABASE.DIRECTORY.INUSE` legs red; the browser `PATH.MANAGERDIR` leg was not run under this mutation.
- mutation: `LocalDatabaseUpdate.MergeUpdate` narrows the payload to the changed keys → `DatabaseWrite.TestTheEditsSendTheirCompleteSets` red (run 42).
- mutation: `DatabasePort.Delete` deletes the file although shared → `DatabaseWrite.TestTheThreeDeleteShapes` red (run 43).
- mutation: `Impact.KindOf` drops `database-delete` → `DatabaseWrite.TestTheImpactNamesTheNamespacesAndApplications` red (run 44); `core/impact.ts` giving `database-delete` no parts → `impact.test.mjs`' Story 18.3 leg red. The browser advisory was not run under this mutation.
- mutation: `confirmPending` sends the delete without `DeleteFile` → `screen-action-handler.spec.ts`' Story 18.3 leg red; the browser delete-with-file leg was not run under this mutation.
- mutation: `Prohibited.Database`'s own-name arm removed → `DatabaseWrite.TestTheProtectedDatabasesAreRefusedOnBothCallers` red (run 46), each write recorded by `DatabaseAcceptPort` and none sent.
- mutation: `Prohibited.Database`'s directory arm removed → `DatabaseWrite.TestAResourceChangeThroughASecondNameOverAnOwnFileIsRefused` red (run 47).
- mutation: `LocalDatabaseCreate.PrivilegePairs` drops `%DB_IRISSYS:WRITE` → `DatabaseWriteGate.TestEachMissingPairIsRefusedBeforeAnyPortCall` red (run 48).
- mutation: `LocalDatabaseDelete` empties `CLASSICPAGES` → `ClassicPageGate`'s agent-caller and declared-set tests red (run 49), and `MappingDescriptor.TestTheClassicPagesRosterIsTheDeclaringTools` red (run 50).
- mutation: the namespace form store ignores the `database-configuration` event → `namespace-form.store.spec.ts`' AC6 leg red.
- mutation: `.ocu-form-step-label` drawn in `--ocu-surface`, rebuilt and redeployed → `local-databases.browser-spec`'s AC7 leg red, 1:1 contrast on `os-management/local-databases/edit` in light and dark.
- mutation: `BackgroundTaskPort.KeepRunning` keeps ended tasks → `BackgroundTasks.TestAPortalRowNamesTheDatabaseItsTaskRunsAgainst` alone red (run 51).
- mutation: `comparableDirectory` keeps case → `database-details.page.spec.ts`' listing, truncated, Refresh and id-change legs red; rebuilt and redeployed, `local-databases.browser-spec`'s AC8 leg red.
- mutation: `DatabaseDirectories` skips `VolumeDirectories` → `PathPortDatabases.TestAVolumeDirectorysFilesAreTheInstances` and `TestAFailedVolumeReadRefuses` red (run 52).
- mutation: the reader ignores a configured `StreamLocation` → `PathPortDatabases.TestAConfiguredStreamLocationIsFollowed` alone red (run 53).
- mutation: the reader keeps its answer in `^||` → `PathPortDatabases.TestTheReaderKeepsNothing` red, with the stream, volume and failure legs (run 54).
- mutation: `DatabaseDirectories` drops a `VolumeDirectories` error → `PathPortDatabases.TestAFailedVolumeReadRefuses` alone red (run 55).
- mutation: `LocalDirectory` answers 1 for a leading `:` → `PathPortDatabases.TestAColonDirectoryIsNeverListed` alone red (run 56).
- mutation: `DatabasePort.Create` skips `HoldsDatabase` → `DatabaseRefusals.TestADirectoryHoldingADatabaseIsRefused` alone red (run 40): the confirm's resource write was sent.
- mutation: `DatabaseSave.Answer` drops `applied` from a violations refusal → `DatabaseWrite.TestTheRoutesAnswerOverTheWire` alone red (run 57).
- mutation: `DatabasePort.Snippet` drops the resource step → `DraftPorts.TestDatabasePort` alone red (run 365).
- mutation: `Impact`'s `MAPPINGDESCRIPTORS` drops `RoutineMappingList` → `DatabaseWrite.TestTheImpactNamesRoutineAndPackageMappingUsers` alone red (run 45).
- mutation: the id-change handler drops `loadTasks` → `database-details.page.spec.ts`' id-change leg alone red.
- mutation: `Error.ReasonForPath` drops its `PATH.ROOT` arm → `DatabaseRefusals.TestEachPathCodeCarriesThePortsSentence` alone red (run 59).
- mutation: the Local databases list's read sends `localOnly` `0` → `DatabaseRefusals.TestARemoteDatabaseIsRefused` alone red (run 60).
- mutation: `DatabasePort.Snippet`'s file-edit branch falls through to the admin port's script → `DraftPorts.TestDatabasePort` alone red (run 366): the step carried no `?dir=` query, and the read's own names in its body.
- mutation: `Prohibited.Database` carries on with an empty own set when `OwnDatabaseNames` fails → `DatabaseWrite.TestAFailedOwnSetReadRefuses` red (run 370, the method alone): neither delete was refused, and a write reached `DatabaseAcceptPort`.
- mutation: `DatabasePort.FileBody` adds `VolThreshold` → `DatabaseWrite.TestACreateRunsTheResourceTheFileAndTheConfigurationInOrder` red on its two body-key assertions alone (run 371, the method alone).
- mutation: `LocalDatabaseUpdate.PortQuery` drops `volumeRoot` → `DatabaseRefusals.TestTheVolumeDirectoryRefusalsLandOnTheirFields` red (run 373, the method alone): the confirm was not refused `PATH.ROOT`, and a write was sent.
- mutation: `PROPERTYFAULTS` drops `Database.SysCRUD:60` → `DatabaseRefusals.TestTheFileEndpointsFaultsLandOnTheirFields` red (run 374, the method alone). The vendor answered the mounted probe directory's `POST` with #70, #60 and #73, a dismounted one's with #70, #18 and #78, and `OcuProbe183Custom` with #896, so no code joins `PROPERTYFAULTS`.
- mutation: `PathPort.VolumeDirectories` drops its no-`IRIS.DAT` early answer → `PathPortDatabases.TestAConfigurationWithNoFileRefusesNothing` red (run 378, the method alone).
- mutation: `loadTasks` drops `tasksFaultSignal.set(true)` → `database-details.page.spec.ts`' 500 leg alone red.
- mutation: `App.verifyWhenSignedIn` drops `this.databaseWizard.reset()` → `app.spec.ts`' sign-out test red on the wizard's name; dropping `this.databaseEditor.reset()` → red on the editor's name.
- mutation (code review): `LocalDatabaseUpdateMount.ArgumentPairs` answers nothing when the arguments leave `MountRequired` out → `DatabaseWriteGate.TestAStoredMountRequiredNeedsTheOperatePair` alone red (run 385).
- mutation (code review): `FileBody` always sends `DEFAULTSIZE`, `EnsureResource` makes the resource public, `LocalDatabaseCreate.DerivedFields` adds no `Directory`, `LocalDatabaseDelete.StateDiff` answers no rows, `LocalDatabaseUpdate.DerivedFields` sets no `NewVolumeDirectory`, `NAMESPACEUSEFIELDS` holds `Globals` alone, `DatabaseRules.Resources` drops its `%DB_` filter → each targeted `DatabaseWriteDetail` assertion red (run 399) and `DraftPorts.TestDatabasePort`'s size leg (run 400); `ViolationCodes` drops `RESOURCEABSENT` → `DatabaseDescriptor.TestEveryDatabaseCodeIsSaidAndListed` red (run 401).
- mutation (code review): `DatabasePort.Delete` drops its `Server` clause → `DatabaseRefusals.TestARemoteDatabaseIsRefused` red, and the volume rule reverts to `volumeRoot` alone → `TestTheVolumeDirectoryRefusalsLandOnTheirFields` red (run 402); `ResourceViolation` drops the port's fault → `DatabaseWriteGate`'s reader leg red, 500 (run 403); client: `keepVolumeDirectory` keeps the root, the read-back pick reverts to the file group's, the wizard's `describedby` drops the reason → each new spec leg red. Every mutation reverted byte-identical; latest runs green: `DatabaseWrite` 398, `DatabaseRefusals` 404, `DatabaseWriteGate` 405, `DatabaseWriteDetail` 406, `DraftPorts` 407, `DatabaseDescriptor` 408.
- mutation (rework 1): the wizard page's `onLocation` hands the picker's preselection to `setLocation` → `database-wizard.page.spec.ts`' single-root leg alone red (the form dirty on open).
- mutation (rework 1): `DatabaseWizard.preselectRoot` marks the form dirty → `database-wizard.store.spec.ts`' preselection leg and its user-change leg (clean after the preselection) red, and the page's single-root leg red.
- mutation (rework 1, review): `DatabaseWizard.setLocation` marks the form dirty only when the path differs → `database-wizard.store.spec.ts`' user-change leg (root half) and `database-wizard.page.spec.ts`' several-roots leg red.
- mutation (rework 1, review): `DatabaseEditor.setVolumeLocation` notifies without marking the form dirty → `database-editor.page.spec.ts`' AD-21 leg red on the dirty-after-Change assertion.
- mutation (rework 1): the picker reports its preselection without `preselected` → `server-path-picker.spec.ts`' loading-to-ready and preselection legs and the page's single-root leg red; the picker marks a typed name `preselected` → the picker's preselection and change legs and the page's single-root and edited-path legs red. Each reverted byte-identical.
- mutation (rework 1, code review): `DatabaseWizard.preselectRoot` drops its `clearFieldViolation('root')` → `database-wizard.store.spec.ts`' refused-root leg alone red; `preselectRoot` holds no root → the store's preselection leg and `database-wizard.page.spec.ts`' two AC1 legs (check and create bodies) red; `setLocation` marks the form dirty only when the root differs → the store's user-change leg (path half) and the page's single-root leg red. Each reverted byte-identical.
- mutation (rework 2): `BackgroundTaskCancel.FINGERPRINTSUBJECT` adds `Database` → `BackgroundTasks.TestAMovedDatabaseIsStillTheTaskReviewed` red, the confirm refused `PROPOSAL.TARGETCHANGED` with no pause sent, beside `TestTheToolsAreActionWritesOverTheScreensOwnPairs`' subject leg (run 411). The same subject left `BackgroundTasksLive` 7/7 (run 412).
- mutation (rework 2): that subject, with `WithDatabases` setting `Database` to `$ZHorolog` on every read → `BackgroundTasksLive.TestTheAgentsConfirmPausesACompact` red on attempt 1 and not retried, the compact still running, beside `TestASeededPortalCompactIsListedPaused`' database leg (run 413).
- mutation (rework 2): `BackgroundTaskPort.PortalControl` answers `$$$OK` in place of `Pause()` → `TestTheAgentsConfirmPausesACompact` red on "and the compact is paused" alone, beside `TestTheScreensActionsResumePauseAndCancelACompact`' pause legs (run 415). Each reverted byte-identical.

## Auto Run Result

Status: done
Blocking condition: none

**Rework 2 (2026-09-29, CI): the agent's pause test survives a compact that ends before its confirm.**

- **Cause:** the value that moved is `Status`, Running to Done: the seeded compact ended between the mint and the confirm (inference), and the refusal is AD-51's correct answer. The three Background tasks tools fingerprint `Status` alone (`BackgroundTaskCancel.FINGERPRINTSUBJECT`, Story 16.5, 73f7b3b8), so neither `Database` nor `Details` was ever in the subject. It predates this story: the test, the ~2 s seed and the subject are 16.5's.
- **Evidence (`ocupilot-b-ci`):** once resumed, the compact runs 1.4-1.9 s, while the mint returns about 0.39 s and the confirm about 0.93 s after the resume; CI runs this class about twice as slowly (31-35 s against 14-16 s) (inference: CI's confirm can outlast the compact). The failure reproduces exactly: confirming after the compact ended answers `TARGETCHANGED` with the row reading Done. A stage probe read the one-row port read in a loop across three compacts' ends: 104,731 reads, 0 failures, about 0.11 ms each with both queries; `Database` read the same directory from the resume until the task ended, then `""`, and in 2 of 3 runs one read at the boundary saw `Running` with `Database` `""`.
- **Fix (test-only, inside this story's Background tasks files):** `BackgroundTasksLive.TestTheAgentsConfirmPausesACompact` re-seeds, at most `AGENTATTEMPTS` (3) times, only when the confirm was refused `TARGETCHANGED` and the compact reads Done; any other refusal fails at once. New `BackgroundTasks.TestAMovedDatabaseIsStillTheTaskReviewed` pins that the measured boundary read, `Database` moving while `Status` reads Running, does not refuse the confirm. No product code changed.
- **Files:** `src/OcuPilot/Test/BackgroundTasksLive.cls` (the bounded retry, `ProposeAndConfirmPause`, `EndedBeforeTheConfirm`); `src/OcuPilot/Test/BackgroundTasks.cls` (the new test and `DatabaseOf`); this spec.
- **Review (follow-up pass, two layers):** 9 findings (high 0, medium 0, low 6, false 3). 2 lows patched as one entry (the two doc comments now state that the retry check reads Done afterwards and does not tell a moved status from a failed read); 4 lows and 3 false rejected, reasons in the triage log. Nothing deferred by review; the implement pass added one `deferred:` item, the older seed flake of run 36530303753 (`BackgroundSeed.cls`, Epic 16's). Follow-up review: not recommended, no high patched.
- **Mutations:** three `mutation (rework 2)` lines under `## Verification` (runs 411, 413, 415); a forced race (run 420) was retried and paused on attempt 2.
- **Verification** on `ocupilot-b-ci`, totals from `%UnitTest_Result`: after the final save, `BackgroundTasksLive` runs 423, 424 and 425, 7/7 each, one at a time; `BackgroundTasks` run 426, 12/12. Before the doc patch: `BackgroundTasksLive` 417-419, 421 and 422, 7/7 each; every unforced run paused on attempt 1. `database-details.page.spec.ts` 16/16. `check-objectscript` 0 problems; `lint-docs` clean. No probe object, seed database, task or global is left.
- **Residual:** three attempts shrink the race rather than remove it; a seed that outlasts the window would remove it, in Epic 16's `BackgroundSeed.cls`. `BackgroundTasksLive.cls` is 537 lines, over the ~500-line guideline.

**Rework 1 (2026-09-29, CI): the create wizard no longer opens dirty.**

- **Change:** the picker's one preselection of a single root is reported with `preselected: true` (an optional field on `ServerPath`; `changed` still fires, so the editor's contract is kept). The wizard page sends that report to a new `DatabaseWizard.preselectRoot`, which holds the root without marking the form dirty or counting as a path edit. Every user change still goes through `setLocation` and marks the form dirty. The editor is unchanged: after an explicit Change, its preselection marks the form dirty, as intended.
- **Files:** `ui/src/app/shell/server-path-picker.ts` (the flag) and its spec; `database-wizard.store.ts` (`preselectRoot`) and its spec; `database-wizard.page.ts` (routes the flagged report) and its spec; `database-editor.page.spec.ts` (dirty after Change, pinned at page level).
- **Review (follow-up pass, two layers):** 6 findings (high 0, medium 0, low 3, false 3). The 3 lows were patched, all in tests: the store's user-change leg now asserts clean after the preselection, the root half has a recorded mutation, and the editor's dirty-after-Change is pinned. The 3 false findings were rejected; reasons are in the triage log. Nothing was deferred. Follow-up review: not recommended, because no high was patched.
- **Mutations:** six mutations on five `mutation (rework 1…)` lines under `## Verification`. Each was applied, observed red and reverted byte-identical.
- **Verification** on `ocupilot-b-ci`, against the rebuilt and redeployed bundle (`main-JT27HVRD.js`):
  - `a11y-structural-invariants.browser-spec.mjs` passed 12/12. It walked 83 of 83 screens, with every visit settled and 0 violations, across its light 1280 px, light 720 px and dark 1280 px passes. The dark-only contrast liveness leg is green.
  - `local-databases.browser-spec.mjs` passed 6/6, including AC7's walk in light and dark.
  - `namespaces.browser-spec.mjs` passed 5/5.
  - The client tier, after the review patches: `npm run test:tools` 1699/1699 and `npm run test:components` 1840/1840 (137 files). `client-lint` and `lint-docs` are clean.
- **Bundle:** initial 2.19 MB (main 2,019,043 B, styles 174,097 B), under 3800kB. No contended file changed, and no ObjectScript changed.
- **Residual:** a future picker consumer that must ignore the preselection has to read `preselected` itself.

**Implement-2 (2026-09-29): the recovered partial implementation completed, verified and reviewed.**

- **Found already in the tree:** every task, matrix row and patch P1-P11. Changed: the editor's second prompt reuses `databaseDetailsPrompt2` (`LocalDatabaseForm.cls`, `strings.ts`, EXPERIENCE.md :377 in place, 993 lines), `screens.generated.ts` regenerated.
- **Review patches Q1-Q11** (second review pass): `DatabasePort.Snippet` answers no step for a delete with its file and creates `%DB_<NAME>` only when absent (AD-59); new legs `DatabaseWrite.TestAFailedOwnSetReadRefuses`, `DatabaseRefusals.TestTheVolumeDirectoryRefusalsLandOnTheirFields` and `TestTheFileEndpointsFaultsLandOnTheirFields`, `PathPortDatabases.TestAConfigurationWithNoFileRefusesNothing`; extended `DraftPorts.TestDatabasePort`, `TestTheThreeDeleteShapes` (a second volume file), the create's body keys, `database-details.page.spec.ts` (500 and Retry), `app.spec.ts` (sign-out resets), `DatabaseDescriptor`/`TestARemoteDatabaseIsRefused` floors, `ReadTool`'s message. Each changed pin's mutation is recorded under `## Verification`.
- **Review:** 25 findings (high 0, medium 7, low 12, false 4, maybe-false 2); 12 patched (6 medium, 6 low), 1 carried defer (the fourth `deferred:` item), 12 rejected with reasons in the triage log. Follow-up review: not recommended; every patch but Q1 is a test, and Q1's one product change is pinned by `DraftPorts` and `DraftRegistry`, each run in full.
- **Rosters, read from the instance:** 39 entity types, 83 descriptors, 159 production tools (98 writes, 61 reads), 23 `Prohibited` codes over 28 covered types, governance baseline 98 keys (3 disabled: `osmgmt.localdatabases.delete`, `osmgmt.namespaces.delete`, `security.auditing.purge`), 20 OS management screens, 20 ports, 14 tools declaring classic pages.
- **Full ObjectScript sweep** (once, on `ocupilot-b-ci` recreated from this tree): 363 classes, 2979 tests, 0 failures, runs 1-363, totals read from `%UnitTest_Result`. After the patches, the latest run of every class: 363 classes, 2983 tests, 0 failures (runs 1-381; patched classes re-run in full at 367-381).
- **Client and gates:** `npm run test:tools` 1699/1699, `npm run test:components` 1832/1832, `client-lint`, `check-objectscript` (0 problems), `lint-docs` clean; the story's four browser spec files 16/16 on the redeployed bundle; `smoke.sh` 49/49.
- **Bundle:** initial 2.19 MB (main 2,018,233 B, styles 174,097 B), under `angular.json`'s 2217kB warning and far under 3800kB.
- **Throwaway:** afterwards no `OCUPROBE183*` configuration, namespace or application, no `ocuprobe183*` directory, `%DB_OCUPROBE183*` resource, gate principal or `OCUBGSEED` database; the `%GUIFileSelector` allow-list unset, as on a fresh instance.
- **Residual:** `DatabaseWrite.cls` is about 760 lines, above the 500-line guideline for a test class. `DatabaseRules` checks a named resource with `Security.Resource` `GET` as the caller rather than the Resources list's read (same port, same gate).

**Re-plan (2026-09-28):**

- Probe objects created on `ocupilot-b-ci` and removed, with removal re-read:
  - databases `OCUPROBE183V` (with volume directory `ocuprobe183vx/`) and `OCUPROBE183W`, their directories;
  - configurations `OCUPROBE183D` and `OCUPROBE183M`, which made no directory;
  - role `OcuProbe183PP` and user `OcuProbe183PPUser`; role `OcuProbe183BG` and user `OcuProbe183BGUser`;
  - `BackgroundSeed`'s `OCUBGSEED` database, its `%DB_OCUBGSEED` resource and its paused compact (removed through `BackgroundSeed.Remove`).
  - Afterwards: no `OCUPROBE183*` or `OCUBGSEED` configuration, no probe directory, principal or resource, no database background task and no portal task row.
