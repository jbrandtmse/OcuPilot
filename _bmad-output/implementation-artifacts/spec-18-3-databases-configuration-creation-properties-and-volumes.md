---
title: 'Story 18.3: Databases - configuration, creation, properties and volumes'
type: 'feature'
created: '2026-09-28'
status: 'ready-for-dev'
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

## Spec Change Log

- 2026-09-29, runner, before re-plan: the orchestrator split remote databases (SA-17, Part C) into Story 18.16 (Rule 5, 2026-09-28) and kept expand-volume and size-grow in 18.4. The intent contract drops Part C and adds DW-1080 (Database details' background tasks through `BackgroundTaskPort`), DW-1807 (`PATH.SERVED`), DW-1795 and DW-1796. Since the first plan, `PATH.INSTANCE` covers every file in every configured database and journal directory (DW-1790), and every file and vendor-writes directory under OcuPilot's served directory is refused `PATH.SERVED` (DW-1798, DW-1806). Status set to `draft` for the re-plan.

## Review Triage Log

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Re-planned; no product code changed.**

- Part C (remote databases) is gone: its tasks, tools, routes, codes, strings, literals, keys, tests and its proposed spine case. `DATABASE.REMOTE` on `update` stays.
- The inbox is planned: DW-1080 (AC8), DW-1795 and DW-1796 (AC9), DW-1807 (in AC1), and DW-1791 (kept). The Code Map is re-anchored to 18.14's landed names.
- New measurements are recorded under Design Notes.
- Probe objects created on `ocupilot-b-ci` and removed, with removal re-read:
  - databases `OCUPROBE183V` (with volume directory `ocuprobe183vx/`) and `OCUPROBE183W`, their directories;
  - configurations `OCUPROBE183D` and `OCUPROBE183M`, which made no directory;
  - role `OcuProbe183PP` and user `OcuProbe183PPUser`; role `OcuProbe183BG` and user `OcuProbe183BGUser`;
  - `BackgroundSeed`'s `OCUBGSEED` database, its `%DB_OCUBGSEED` resource and its paused compact (removed through `BackgroundSeed.Remove`).
  - Afterwards: no `OCUPROBE183*` or `OCUBGSEED` configuration, no probe directory, principal or resource, no database background task and no portal task row.

**For the runner:**

- Eight spine sentences are proposed under Design Notes (AD-8 twice, AD-10, AD-21 twice, AD-52, AD-44, AD-27).
- The story stays one story; the fallback split moves DW-1080 to 18.4.
- The footprint extends into Story 16.5's files; they are listed under Design Notes.
- A fourth `deferred:` item (the portal-only task list) is for harvest to 18.4.
- Recommended disposition for all five inbox entries: `resolved-by:18-3`.
