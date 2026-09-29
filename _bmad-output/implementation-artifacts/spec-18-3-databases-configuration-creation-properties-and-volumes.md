---
title: 'Story 18.3: Databases - configuration, creation, properties and volumes'
type: 'feature'
created: '2026-09-28'
status: 'draft'
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
    location: 'vendor %Api.Admin.Endpoints.Database.ConfigCRUD PUT'
  - summary: 'Vendor defect candidate: a POST /database-dir refused for lack of privilege leaves a directory and an unregistered IRIS.DAT that the API can neither delete (#57) nor create over'
    evidence: 'Measured on ocupilot-b-ci 2026-09-28 (plan probe, Step 9). OcuPilot refuses a caller without the declared pairs before any port call. Candidate IRIS defect report; human-owned.'
    severity: 'low'
    location: 'vendor %Api.Admin.Endpoints.Database.SysCRUD POST'
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

**Vendor, measured on `ocupilot-b-ci` 2026-09-28** (payloads and pairs in Design Notes; vendor source exported read-only):

- `Database.ConfigCRUD`:
  - routes `GET /databases` (`LIST`: `filter`, `localOnly`, `remoteOnly`), `GET|PUT|DELETE /database?name=`;
  - `ResourcesOR` `%Admin_Manage`;
  - template `{Server, Directory, StreamLocation, ClusterMountMode, MountAtStartup, MountRequired}` at `Screen/Tool/FieldLists.cls:20-27`.
- `Database.SysCRUD`:
  - routes `GET /database-dirs`, `POST|GET|PUT|DELETE /database-dir?dir=`, `GET /database-dir/volumes` (`VOLUMELIST`);
  - template (PUT only) `{MaxSize, ExpansionSize, NewVolumeThreshold, NewVolumeDirectory, ResourceName, NewGlobalIsKeep, GlobalJournalState, NewGlobalCollation, ClusterMountMode, ReadOnly}` at `FieldLists.cls:28-39`;
  - `RunPost` reads `{ResourceName, VolThreshold, BlockSize, Directory, GlobalJournalState, Encrypted, MirrorDBName, MirrorSetName, Size, EncryptionKeyID}`.
- Routes: `Port/AdminRoutes.cls:84-97`.
- Classic pages (exact spelling, `RESOURCE`):
  - `%CSP.UI.Portal.Databases` (%Admin_Manage), `.Database` (%Admin_Manage), `.DatabaseVolumes` (%Admin_Manage);
  - `.Dialog.DatabaseWizard` (%Admin_Manage), `.Dialog.DatabaseDelete` (%Admin_Manage:USE);
  - `.RemoteDatabases` (%Admin_Manage), `.Dialog.RemoteDatabase` (%Admin_Manage).
  - `%CSP.UI.Portal.RemoteDatabase` does not exist.
- `Security.Resource` `PUT` is the create path, as `Screen/Tool/ResourceCreate.cls` uses it (`WRITERESOURCE` `%Admin_Secure:USE` at `:44-46`).

**Port:**

- `Port/AdminPort.cls`: `MUTATINGTYPES` :309, `BODYLESSTYPES` :325, `VERIFIEDDELETES` :359, `QUEUEDWRITES` :492 (unchanged here), `PROPERTYFAULTS` :2319 (grammar :2292-2318), `Invoke` :758.
- `Test/PortFixture.cls:21` copies `MUTATINGTYPES`.
- `Port/AuditPort.cls` is the model for a subclass that builds a body (`Invoke` :69-104, `Snippet`/`SnippetForm` :371/:380). 18.14 adds `Port/NamespacePort.cls` on the same model; it was not on the branch at planning.
- `Port/PathPort.cls`:
  - `Resolve(pRoot, pPath, pKind, pRootField, pPathField, Output pResolved, Output pHttpStatus, Output pFault, pOverwrite, pVendorWrites)` :248.
  - Refusals: `PATH.NAME` :263/:291, `PATH.ROOT` :278, `PATH.MANAGERDIR` :296.
  - `PAIRS` :42 (`%Admin_FileSystemAccess:USE,%DB_IRISSYS:READ`); `DATABASEFILE = "IRIS.DAT"`.
  - It has no consumer yet; nothing in it tests whether a directory already holds an `IRIS.DAT`.

**Tools** (`Screen/Tool/`):

- `Write.cls`: `DESCRIPTORCLASS` :38, `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CHANGEACTION` :124, `CREATES` :141, `SCREENACTIONS` :157, `READANSWERS` :170, `SCREENVALUES` :201.
  - Methods: `DerivedFields` :301, `PortQuery` :417, `StateDiff` :463, `SettableFields` :493, `IdArgument`/`IdParam` :500/:507, `ExcludedFields` :515, `ScreenActionDelta` :584, `InputSchema` :674, `ArgumentProblem` :786.
  - `Base.cls`: `PrivilegePairs` :92, `ArgumentPairs` :123.
  - 18.14 adds `CLASSICPAGES` to `Write.cls` and `WithClassicPages` to `Screen/Gate.cls` (`ClassicResource` :242, `RequiredPairs` :106-122).
- Models: `NamespaceCreate.cls` (:15-45, `PrivilegePairs` :140-147), `NamespaceUpdate.cls`, `NamespaceDelete.cls` (:17-62, `StateDiff` :100-130), `ResourceCreate.cls`.
- `Classification.cls`: entry format at :469-484; `compare` grammar at :13-17. `ToolFields.cls` is regenerated by `cd ui && node tools/field-lists.mjs`.

**Kernel:**

- `Kernel/EntityType.cls:42` `TYPES`: 33 values, 36 after 18.14.
- `Kernel/EntityRef.cls:59` `IDRULES`: `database` has no rule.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250 (22 types); `OCUPILOTNAMESPACE` :353/:357; `Codes()` :489-492 (19; 20 after 18.14); `ReasonFor` :497-523;
  - `PermittedChangeFields` :600-624, `PermittedCreateFields` :712-731;
  - `Prohibits` :799-932 (type chain :808, `Created` :986); the `Namespace` predicate :1595-1624; `IsOwnNamespace` :1627-1632; `ReviewedFewOnly` :1856-1881.
  - No database predicate exists yet.
- `Kernel/State/Base.cls`: `DATABASENAME` "OCUPILOT" :70, `DBRESOURCE` :79.
- `Kernel/Proposal/Impact.cls`:
  - kinds :28-34, parts :36-50;
  - `Of` :105-172; the `namespace-delete` branch :149-155; `KindOf` :177;
  - `Guarded(descriptor, part, nameField, id, , matchField)` :304; `Databases` :320-335; `ListRows` :371 (gate, `Screen.Read.Execute`, a cut read unchecked); `Fill` :412.
  - `Api/ScreenImpact.cls:21-50` is the dialog's impact route.
- `Kernel/Governance/Baseline.cls`: namespace lines :24-26.

**Save routes:**

- `Area/OsMgmt/NamespaceRules.cls`: `Validate` :57-102, `HandleForm` :160-201, `Databases()` :302-326 (reads `Database.ConfigCRUD` `LIST` through the tool's port), `Gate` :374.
- `Area/OsMgmt/NamespaceSave.cls`: `Create` :115, `Update` :160, `PortViolations` :227, `Prohibited` :256, `Gate` :349.
- `Api/Router.cls`: namespace routes :119-122, wrappers :579-605.
- `Api/Error.cls`: the namespace block (`NAMESPACE.VALIDATION` :2529, codes :2534-2571, `NamespaceViolationCodes` :1456, `ReasonForNamespace` :1462-1471, dispatch :1397); PATH codes :387-452.

**Screens:**

- `Screen/Descriptor/NamespaceList.cls` :21-70 and `NamespaceForm.cls` :18-50 are the models.
- `TaskForm.cls` is a form-page whose bare route renders the wizard (`DESCRIPTOR_PAGES`) and whose id route renders the editor (`DESCRIPTOR_EDIT_PAGES`).
- Epic 6: `DatabaseList` (`os-management/databases`, position 4, `database` keyed by directory, `Database.SysCRUD` `LIST`, `%CSP.UI.Portal.OpDatabases`, `secondaryEntityTypes` empty); `DatabaseDetails`; `DatabaseVolumeList` (`VOLUMELIST`, criterion `dir`); `DatabaseFreeSpace`.
- `ResourceList` reads `Security.Resource` `LIST` with `%Admin_Secure:USE`.
- Registry: `Screen/Archetype.cls:66-83`; `AreaCoverageProblem` :797; `PROMPTGROUPKEYS` :2538.
- OS management's listed screens: 1 Processes, 2 Locks, 3 System usage, 4 Databases, 5 Devices, 6 Namespaces.

**Client:**

- Picker: `ui/src/app/shell/server-path-picker.ts`: `ServerPathPicker` :103, selector `app-server-path-picker`, inputs :105-123 (`store`, `kind`, `root`, `path`, `rootReason`, `pathReason`, `idPrefix`), output `changed` :126.
- `ui/src/app/core/allowed-directories.ts:59` `AllowedDirectoriesStore` (`load(api)`, `subscribe`, `state`).
- `ui/src/app/core/violations.ts` `violationsOf` :35, `reasonForField` :67. No page embeds the picker yet.
- Wizard: `ui/src/app/shell/form-stepper.ts:64-136` `FormStepper`; `areas/tasks/task-wizard.page.ts:49-314` and `task-wizard.store.ts` (`next()` posts to a check route, `:563-600`; `back()` :552).
- Namespace model: `areas/os-management/namespace-actions.ts:24-41`, `namespace-form.page.ts` (:122-149 selects, :152-164 form bar, :259-268 refusal action, :332-335 post-create navigation), `namespace-form.store.ts` (:281-297 `open`, :340-389 save, :504-509 bus).
- Shell:
  - `shell/screen-outlet.ts`: `DESCRIPTOR_PAGES` :114-146, `DESCRIPTOR_EDIT_PAGES` :158-167; `app.ts` :30-33 and :304-308, resets :609-611.
  - `shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :51-73, `IMPACT_ACTIONS` :193-197, `DESTRUCTIVE_CONSEQUENCES` :208-227, `TYPED_NAME_ROWS` :261-269, `openWithImpact` :653-677.
  - `shell/typed-name-dialog.ts:45`; `shell/screen-action-dialogs.ts:27-37`.
- `ui/src/app/core/impact.ts`: `ImpactKind` :14, `IMPACT_PARTS` :27-32, `PHRASES` :114-159, `impactLine` :193.
- Editor precedent: `database-details.page.ts:277-292` issues `DatabaseVolumeList`'s read (`createScreenRead`); `ui/src/styles/_components.scss:2991` `.ocu-form-bar`.
- Strings to reuse (`strings.ts`, values must stay unique, `strings.test.mjs:732`):
  - `tableColumnName` :357, `lockColumnDirectory` :1086, `taskHistoryColumnStatus` :899, `webAppColumnResource` :365, `statusSegmentServer` :93;
  - `databaseColumnMaxSize` :1102, `databaseDetailsExpansionSize` :1116, `databaseDetailsNewVolumeThreshold` :1118, `databaseDetailsNewVolumeDirectory` :1120, `databaseDetailsKeepNewGlobals` :1122, `databaseDetailsClusterMountMode` :1126, `databaseDetailsReadOnly` :1128, `databaseDetailsJournalNewGlobals` :1130;
  - `databaseVolumeListLabel` :1132, `systemInfoDatabase` 'Database' :1371, `processDetailsGroupGeneral` 'General' :1001, `taskStepError` :2186, `pathPicker*` :805-815.

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 993 lines):

- :164 OS management side bar; :173 Dialogs; :377 Databases literals; :378 Namespaces literals;
- :479 delete bodies; :481 kernel refusals; :577 impact phrases;
- :108/:626 wizard and stepper; :624/:625 form-page and tabs.

**Rosters naming OS management screens or the tool set** (re-derive from the code and from each class's red):

- ObjectScript:
  - `Test/Descriptor.cls` (`ReadShapes` :67-119, entity count :1700), `ReadTool.cls` :93-94, `SurfaceCoverage.cls` :54ff, `EndpointCoverage.cls` :192-195, `Navigation.cls` :338-339;
  - `Wire.cls:700`, `WireSecurityRead.cls` :549/:556/:559, `ScreenGrounding.cls`, `ProposalPrivilege.cls` :95-106;
  - `Prohibited.cls` :218 (covered types) and :672 (code count), `AuditingUpdate.cls:505`, `RefusalCopy.cls:107`;
  - `GovernanceBaseline.cls:10` (`DISABLED`), `Governance.cls` :20/:100, `ToolDispatch.cls:150`, `ToolEmit.cls` :206-212;
  - `ToolRoundTrip.cls:38` (`REFUSEEMPTY`), `ToolWrite.cls` :1225/:1250/:1293/:1297, `PortGate.cls:28`, `DraftRegistry.cls`;
  - 18.14's `MappingDescriptor` `CLASSICPAGES` roster and `ClassicPageGate`.
- Client:
  - `ui/tools/navigation.test.mjs` :150-163 and :229-253, `navigation-wire.test.mjs` :90-181/:440;
  - `ui/src/app/shell/rail-wire.spec.ts` :88-178, `home.page.spec.ts` :324-333, `ui/tools/self-protection.test.mjs` :253-266 (`KERNEL_REFUSALS`), `ui/browser/namespaces.browser-spec.mjs` :376-384 (`slice(0, 6)`, unaffected).

**Test models:**

- `Test/NamespaceWriteProbe.cls`, `NamespaceWrite.cls` (:21 arming; helpers :350-487), `NamespaceWriteGate.cls` with `NamespaceWriteGateProbe.cls` (`RunAs` :266-289, `Run` :29-47);
- `AcceptPort.cls`, `DeviceRecordPort.cls`, `GovernanceFixture.cls`, `PathPortFixture.cls`;
- `ui/browser/namespaces.browser-spec.mjs` (`irisSys` :70-85, cleanup :87-90/:181-186, DW-1337 :334-365/:541-555), `impact.browser-spec.mjs`;
- `ui/browser/databases.browser-spec.mjs:149` pins five cells per row, so Epic 6's list gains no row action.
- Arming: `scripts/ci-throwaway.sh` `OCUPILOT_ALLOW_NAMESPACE_CONFIG` :354-362 and `OCUPILOT_ALLOW_PRINCIPALS` :193-237, pinned by `ui/tools/ci.test.mjs` :1828-1939.

## Tasks & Acceptance

**Task 0: the implement stage's first task, before any code.** It runs on `ocupilot-b-ci` only, on `OCUPROBE183*` objects the step creates and removes. Record the results in Design Notes › Measured at implement.

1. Is a configuration name resolved without regard to case (`GET /database?name=ocuprobe183x` for `OCUPROBE183X`)? Yes keeps the id rule `foldcase`; no makes it verbatim (no rule).
2. Name corpus: which of `1AB`, `A.B`, `A B`, `A-B`, `A_B`, `%AB`, 64 and 65 characters does `PUT /database` accept? Set `DATABASE.NAME.SHAPE`'s pattern and reason to the accepted set.
3. Do these round trips change any stored value?
   - a `PUT /database` of the fresh `GET` body unchanged, including the `StreamLocation` `""` read back for the default;
   - a `PUT /database-dir` of the fresh `GET` body unchanged.
4. As a principal holding only `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, send `PUT /database-dir` once per settable field: `ReadOnly`, `GlobalJournalState`, `NewGlobalIsKeep`, `ResourceName` to an existing `%DB_*`, `NewVolumeThreshold`, `NewVolumeDirectory`. Any field the instance refuses adds its pair to `update`'s `ArgumentPairs`, and this plan's AD-8 sentence names it.
5. **HALT** `blocked`, blocking condition `observation contradicts the plan: <what>`, with nothing built, if a round trip in item 3 changes a stored value or `POST /database-dir` accepts a directory that already holds an `IRIS.DAT`.

**Execution, Part A: Local databases, the create wizard, the properties editor and the delete (AC1-AC6):**

- `src/OcuPilot/Kernel/EntityType.cls`, `Kernel/EntityRef.cls`, `ui/src/app/core/entity-ref.ts` -- append `database-configuration` to `TYPES`, and add `database-configuration:foldcase` (per Task 0) to `IDRULES` and `ENTITY_ID_RULES` -- configuration names are a second id space beside Epic 6's directory-keyed `database` (AD-13).
- `src/OcuPilot/Port/AdminPort.cls` -- add to `MUTATINGTYPES` (and `Test/PortFixture.cls:21`'s copy):
  - `Database.SysCRUD/POST`, `/PUT` and `/DELETE`;
  - `Database.ConfigCRUD/PUT` and `/DELETE`;
  - each with its measured fact in the doc comment.
  - Add the two `DELETE`s to `BODYLESSTYPES`.
- `src/OcuPilot/Port/DatabasePort.cls` (new, extends `AdminPort`, on the `AuditPort` model). It passes a `LIST` through unchanged, and `Snippet` and `SnippetForm` mirror every branch below (AD-59).
  - **Directory lookup.** On `Database.SysCRUD` `GET`/`PUT` it resolves `dir` from `name` through `Database.ConfigCRUD` `GET`. A configuration with a non-empty `Server` answers 409 `DATABASE.REMOTE` with no further call. A query that already carries `dir` passes through.
  - **The create.** A `Database.ConfigCRUD` `PUT` whose query carries `root` runs, in order:
    1. `PathPort.Resolve(root, path, "directory", "root", "path", …, 0, 1)`;
    2. refuse `DATABASE.DIRECTORY.INUSE` on `path` when `<resolved>IRIS.DAT` exists;
    3. when `ResourceName` is empty, `Security.Resource` `PUT ?name=%DB_<NAME>` with `{"Description": "", "PublicPermission": ""}` unless that resource exists. `AdminPort` completes the empty permission through its AD-27 named case, and `Security.Resource/PUT` is already in `MUTATINGTYPES` and `VERIFIEDWRITES`;
    4. `POST /database-dir` with the body the port builds, `{Directory, Size, GlobalJournalState, ResourceName}`, where `ResourceName` defaults to `%DB_<NAME>`;
    5. `PUT /database?name=` with the tool's body plus `Directory`.
    - If step 5 fails, it sends `DELETE /database-dir?dir=<resolved>` and answers step 5's fault with `detail.rolledBack` true or false.
  - **The file update's volume directory.** A `Database.SysCRUD` `PUT` whose query carries `volumeRoot` resolves `PathPort.Resolve(volumeRoot, volumePath, "directory", "volumeRoot", "volumePath", …, 0, 1)` and sets `NewVolumeDirectory` from it.
  - **The delete.** A `Database.ConfigCRUD` `DELETE` with query `name` and `DeleteFile`:
    - reads the configuration, then sends `DELETE /database?name=` and maps a 409 #429 to 409 `DATABASE.INUSE`;
    - then, only when that answered 2xx, `DeleteFile` is 1, `Server` is empty and no other `LIST` row carries the same `Directory` (ignoring case and a trailing slash), sends `DELETE /database-dir?dir=`;
    - answers `{fileDeleted}`. A failed file delete after a successful configuration delete answers 200 with `fileDeleted` 0 and logs the fault.
  - **Faults.** Vendor faults map through `PROPERTYFAULTS`: `Database.SysCRUD:896:@ResourceName=DATABASE.RESOURCE.SHAPE`, and `Database.SysCRUD:78:@path=DATABASE.DIRECTORY.INUSE` (the vendor's own refusal of an existing `IRIS.DAT`, kept as defense). Record each entry's measured fact.
- `src/OcuPilot/Api/Error.cls` -- add a `DATABASE.VALIDATION` block after the namespace block, with violation codes and reasons, `DatabaseViolationCodes`, `ReasonForDatabase`, and its `ReasonForViolation` dispatch:
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
- `src/OcuPilot/Area/OsMgmt/DatabaseRules.cls` (new, the `NamespaceRules` model):
  - **Name:** required; the Task 0 pattern; taken when a `LIST` `Name` matches ignoring case.
  - **Sizes:** `Size` an integer ≥1; `MaxSize`, `ExpansionSize` and `NewVolumeThreshold` integers ≥0.
  - **ResourceName:** empty (create only) or `^%DB_` and present in `ResourceList`'s read as the caller.
  - **Directory refusals:** `PATH.*` through `PathPort.Resolve`, then `DATABASE.DIRECTORY.INUSE`.
  - `HandleForm` answers `{requiredFields, rules, resources}`. `resources` holds the `%DB_*` names, only when the caller holds `%Admin_Secure:USE`; otherwise it is absent and `resourcesRefused` names the pair. With `?name=` it also answers `configuration` (the `updatemount` tool's fresh read) and `file` (the `update` tool's fresh read, `Directory` included; 404 `DATABASE.NAME.ABSENT` when absent).
  - `HandleCheck` (`POST /database/check`, `{step, values}`) answers `{violations}` for the step's fields, so the wizard's Next validates on the instance.
- `src/OcuPilot/Area/OsMgmt/DatabaseSave.cls` (new, the `NamespaceSave` model):
  - `Create`: gate, rules, prohibited set, send through the create tool, read-back.
  - `Update`: the body is `{configuration?, file?}` with changed fields only. For each group present, config first, it runs `updatemount`, then `update`, as `NamespaceSave.Update` does (a fresh read, then only that tool's settable keys; any other key is 400 `PORT.FIELD.UNEXPECTED`). It answers `{configuration, file}`, each carrying the outcome and read-back. A failed second group leaves the first applied and says so, as AD-56's two-write Save does.
- `src/OcuPilot/Api/Router.cls` -- add `GET /database/form`, `POST /database/check`, `PUT /database/:id` and `POST /database` with thin wrappers, sub-resource routes before `:id`, after the namespace quartet.
- `src/OcuPilot/Screen/Tool/` (new; `DESCRIPTORCLASS` `LocalDatabaseList`, `PORTCLASS` `DatabasePort`):
  - `LocalDatabaseCreate.cls` `osmgmt.localdatabases.create`:
    - `Database.ConfigCRUD`, `CREATES` 1, `READTYPE` `GET`, `WRITETYPE` `PUT`, `CHANGEACTION` `created`;
    - settable: no derived field (`ExcludedFields` names all six template fields; the port adds `Directory`), plus declared arguments `root` (required), `path`, `Size` (integer, default 1), `GlobalJournalState` (boolean, default true) and `ResourceName` (optional; empty creates `%DB_<NAME>`);
    - `PortQuery` passes the declared arguments;
    - `ArgumentProblem`/`DerivedFields` apply `DatabaseRules`, including `PathPort` and `IRIS.DAT` at the mint;
    - `PrivilegePairs`: list pairs + `%DB_IRISSYS:WRITE` + `%Admin_Secure:USE` + `%Admin_FileSystemAccess:USE`, then `WithClassicPages`;
    - `CLASSICPAGES` `%CSP.UI.Portal.Dialog.DatabaseWizard`.
  - `LocalDatabaseUpdateMount.cls` `osmgmt.localdatabases.updatemount`:
    - a merge `PUT` on `Database.ConfigCRUD`, sending the complete template set read fresh (AD-4);
    - settable `MountAtStartup, MountRequired, ClusterMountMode`;
    - `PrivilegePairs` + `%DB_IRISSYS:WRITE`; `ArgumentPairs` `%Admin_Operate:USE` when `MountRequired` is true;
    - `CLASSICPAGES` `%CSP.UI.Portal.Database`.
  - `LocalDatabaseUpdate.cls` `osmgmt.localdatabases.update`:
    - a merge `PUT` on `Database.SysCRUD` keyed by `Name` (the port resolves `dir`), sending the complete template set read fresh;
    - settable `MaxSize, ExpansionSize, ResourceName, NewGlobalIsKeep, GlobalJournalState, ReadOnly, NewVolumeThreshold`, plus declared arguments `volumeRoot` and `volumePath` for `NewVolumeDirectory`;
    - `ExcludedFields` `NewVolumeDirectory,NewGlobalCollation,ClusterMountMode`;
    - `ArgumentPairs`: `%Admin_Secure:USE` when `ResourceName` is sent, `%Admin_FileSystemAccess:USE` when `volumeRoot` is sent (plus any Task 0 item 4 pair);
    - `CLASSICPAGES` `%CSP.UI.Portal.Database,%CSP.UI.Portal.DatabaseVolumes`.
  - `LocalDatabaseDelete.cls` `osmgmt.localdatabases.delete`:
    - `Database.ConfigCRUD` `DELETE`, `SENDSBODY` 0, `DESTRUCTIVE` 1, `CHANGEACTION` `deleted`;
    - `SCREENACTIONS` `delete`, `SCREENVALUES` `delete=DeleteFile`; declared argument `DeleteFile` (boolean, required for the agent);
    - `READANSWERS`, `FINGERPRINTSUBJECT` and `REMOVALROWS` `Directory,MountAtStartup,MountRequired`; `PRECONDITIONFIELD` `Directory`;
    - `PrivilegePairs` + `%DB_IRISSYS:WRITE`; `CLASSICPAGES` `%CSP.UI.Portal.Dialog.DatabaseDelete`.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- add entries:
  - `osmgmt.localdatabases.create` and `.updatemount` over `Database.ConfigCRUD`;
  - `.update` over `Database.SysCRUD`;
  - every field `ordinary`; `Directory` and `NewVolumeDirectory` declare `compare` `unslashed`, since the vendor stores a directory with its trailing slash.
  - Then run `cd ui && node tools/field-lists.mjs` (AD-3).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `database-configuration` joins `COVEREDTYPES` and the type chain. Permitted change fields are the two update tools' settable fields; permitted create fields are the create's.
  - Add `OCUPILOTDATABASE` (`PROHIBITED.OCUPILOTDATABASE`) with its `REASON` (the `:481` sentence below), `Codes()` and `ReasonFor`.
  - A `Database` predicate. A target is own when its name, upper-cased, is `Kernel.State.Base` `DATABASENAME`, one of the seven system names (a parameter citing the classic dialog), or the `Globals` or `Routines` of `Namespace.Namespace` `GET` for `$NAMESPACE` read through the tool's port as the caller. A failed read refuses (fail closed).
  - A delete of an own target, or a change whose diff touches `Directory`, `Server`, `ResourceName` or `ReadOnly`, is refused `OCUPILOTDATABASE`. Everything else takes the reviewed-fields sweep. The predicate is stated over the effect, so a bodyless delete is covered (AD-53).
- `src/OcuPilot/Kernel/Proposal/Impact.cls` -- kind `database-delete` for `osmgmt.localdatabases.delete` (and Part C's delete):
  - part `namespaces`: `NamespaceList` rows whose `Globals`, `Routines` or `TempGlobals` equals the id ignoring case, plus each namespace in that read whose 18.14 global, routine or package mapping list has a row with `Database` equal to the id. Each list is read through `ListRows`; a refused or cut list makes the part unchecked with its pair.
  - part `applications`: `Guarded(WebAppList, "applications", "Name", <each namespace>, , "Namespace")` over the namespaces found. It renders nothing when that part is 0 or unchecked.
  - part `sharedFile`: `LocalDatabaseList` rows other than the target whose `Directory` equals the target's, compared as `DatabasePort` compares them.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- add, in name order: `"osmgmt.localdatabases.create": true`, `"osmgmt.localdatabases.delete": false`, `"osmgmt.localdatabases.update": true`, `"osmgmt.localdatabases.updatemount": true`.
- `src/OcuPilot/Screen/Descriptor/LocalDatabaseList.cls` (new, `list`):
  - route `os-management/local-databases`, `labelKey` `localDatabaseListLabel`, `sideBarPosition` 7, the two pairs;
  - entity `database-configuration`, scope `instance`, id `single`;
  - read `{admin, Database.ConfigCRUD, LIST, query {localOnly: "1"}}`; fields, filter and sort `Name, Directory, Status` (default `Name` ascending);
  - columns Name (`tableColumnName`, `name`), Directory (`lockColumnDirectory`, `identifier`), Status (`taskHistoryColumnStatus`, `text`);
  - `primaryAction` `create`, `rowActions` `[{delete, ""}]`, `emptyStateKey` `localDatabaseListEmpty`, `emptyAgentKey` `localDatabaseListEmptyAgent`;
  - `classicPage` `%CSP.UI.Portal.Databases`, `commandAliases` `["local databases","configure database","create database"]`, three `promptGroupGettingStarted` prompts, `toolIdentifier` `osmgmt.localdatabases`.
- `src/OcuPilot/Screen/Descriptor/LocalDatabaseForm.cls` (new, `form-page`): route `os-management/local-databases/edit`, `labelKey` `systemInfoDatabase`, position 0, the list's pairs, id `single`, `classicPage` `%CSP.UI.Portal.Database`, three prompts, `toolIdentifier` `osmgmt.localdatabaseform`.
- `src/OcuPilot/Screen/Descriptor/DatabaseList.cls` -- `secondaryEntityTypes` becomes `["database-configuration"]`, so Epic 6's list re-fetches after a create or delete (AD-14). It gains no action.
- Client (new, `ui/src/app/areas/os-management/`):
  - `database-actions.ts`: Create on Local databases, the `namespace-actions` model.
  - `database-wizard.page.ts` and `database-wizard.store.ts` (the `task-wizard` model, `FormStepper`):
    - Step "Name and directory": Name, then `app-server-path-picker` (`kind` directory) fed by an `AllowedDirectoriesStore` the page owns; `path` is prefilled with the name lower-cased until edited.
    - Step "Size and journaling": Initial size (MB) and Journal new globals, on by default.
    - Step "Resource": "Create the resource %DB_<NAME>" (default) or "Use an existing resource" with a select from `/database/form`'s `resources`. Without them, the choice is drawn disabled, naming the pair.
    - Next posts the step to `/database/check`. `reasonForField` maps `root`/`path` to the picker's `rootReason`/`pathReason`, and every other violation onto its field. Create posts `/database`, then replaces the route with the new database's editor.
  - `database-editor.page.ts` and `database-editor.store.ts` (the `namespace-form` model):
    - Group "General": Maximum size, Expansion size, Resource (select, or read-only with the pair's reason), Keep new globals, Journal new globals, Read only.
    - Group "Mounting": Mount at startup, Mount required at startup, Cluster mount mode.
    - Group "Volume files" (`databaseVolumeListLabel`): New volume threshold; New volume directory, shown as text with Change revealing the picker; and the `DatabaseVolumeList` rows through `createScreenRead` with criterion `dir`.
    - Directory and Name are read-only. A sticky Save sends `PUT /database/:id` with the changed groups only.
  - Register `LocalDatabaseForm` in `DESCRIPTOR_PAGES` (the wizard) and `DESCRIPTOR_EDIT_PAGES` (the editor); inject the actions and each store's `reset()` in `app.ts`.
- `ui/src/app/shell/screen-action-handler.ts`, `ui/src/app/shell/typed-name-dialog.ts`:
  - `LocalDatabaseList` joins `SCREEN_ACTION_DESCRIPTORS`, its `delete` joins `IMPACT_ACTIONS`, and `localDatabaseDeleteConsequence` joins `DESTRUCTIVE_CONSEQUENCES`.
  - Add `DELETE_OPTIONS` (descriptor to `{value, labelKey}`), holding `LocalDatabaseList` to `{DeleteFile, localDatabaseDeleteFileOption}`. The typed-name dialog renders that one optional checkbox, unchecked, above its field, and sends its state as the action's declared value (AD-56 (ii)).
- `ui/src/app/core/impact.ts` -- kind `database-delete` with parts `namespaces` (all four phrases), `applications` (`many`, `one`), and `sharedFile` (`many`, `one`, `unchecked`); 0 renders nothing.
- `ui/src/app/areas/os-management/namespace-form.page.ts` and `namespace-form.store.ts` -- SA-13's database step (Part D):
  - a "Create a database" link beside the Globals select opens the wizard, under the form's leave guard;
  - the store re-reads its database choices on a `database-configuration` `created` or `deleted` event, the `scope.ts:338-343` model.
- `ui/src/app/core/strings.ts` (append; each key cites its EXPERIENCE row): `localDatabaseListLabel`, `localDatabaseListEmpty`, `localDatabaseListEmptyAgent`, `localDatabaseFormRefusedAction`, `localDatabaseListPrompt1`-`3`, `localDatabaseFormPrompt1`-`3`, `databaseWizardStepName`, `databaseWizardStepSize` (the Resource step's title reuses `webAppColumnResource`), `databaseInitialSize`, `databaseResourceNew`, `databaseResourceExisting`, `databaseGroupMounting`, `databaseMountAtStartup`, `databaseMountRequired`, `databaseCreateLink`, `databaseDirectoryChange`, `localDatabaseDeleteConsequence`, `localDatabaseDeleteFileOption`, `databaseRefusalOcuPilot`, and the impact keys `impactNamespacesUse`, `impactNamespacesUseOne`, `impactNamespacesUseNone`, `impactNamespacesUseUnchecked`, `impactApplicationsInThem`, `impactApplicationsInThemOne`, `impactSharedFile`, `impactSharedFileOne`, `impactSharedFileUnchecked`.
- `EXPERIENCE.md`, edited in place and still 993 lines:
  - `:164`: the third cell gains "Local databases · Remote databases (Stage 2, Story 18.3)".
  - `:173`: "database" joins the delete confirmations.
  - `:377` gains these literals, its where-clause ending `[ADDED 2026-09-28 - Story 18.3]`:
    - "Local databases" · "No local databases on this instance." · "create a database" · "change this database";
    - "Name and directory" · "Size and journaling" · "Initial size (MB)" · "Create the resource <name>" · "Use an existing resource" (the Resource step's title is the Web applications row's "Resource");
    - "Mounting" · "Mount at startup" · "Mount required at startup" · "Create a database" · "Change";
    - "Also delete the database file and its volume files";
    - the list's prompts "Which databases does this instance define, and where are their files?" · "Which databases could a new namespace use?" · "What would deleting a database take with it?";
    - the form's prompts "Which resource guards this database?" · "Is this database journaled?" · "What changes if this database becomes read only?".
    - Where any of these literals already exists as a value in `strings.ts`, its key is reused, never duplicated (`strings.test.mjs:732`).
  - `:479`: "Deleting this database removes it from the instance's configuration. Its file stays unless you also delete it here. This cannot be undone."
  - `:481`: "OcuPilot or the instance itself depends on this database. It cannot be deleted, and its directory, resource and read-only setting cannot be changed."
  - `:577`: "<n> namespaces use it and must stop using it first: <names>" · "1 namespace uses it and must stop using it first: <names>" · "no namespace uses it" · "which namespaces use it was not checked" · "<n> web applications run in those namespaces: <names>" · "1 web application runs in those namespaces: <names>" · "<n> other databases share its file, which stays: <names>" · "1 other database shares its file, which stays: <names>" · "whether another database shares its file was not checked".
- `ui/src/app/core/screens.generated.ts` -- regenerate with `cd ui && node tools/screen-mirror.mjs` after each descriptor change.

**Execution, Part C: Remote databases, recommended to move (AC8):**

- `src/OcuPilot/Screen/Descriptor/RemoteDatabaseList.cls` (new, `list`):
  - route `os-management/remote-databases`, position 8, entity `database-configuration`;
  - read `Database.ConfigCRUD` `LIST` `{remoteOnly: "1"}`, fields `Name, Server, Directory, Status`; the Server column is `statusSegmentServer`;
  - create and delete; `classicPage` `%CSP.UI.Portal.RemoteDatabases`; `toolIdentifier` `osmgmt.remotedatabases`.
- `RemoteDatabaseForm.cls` (new, `form-page`, `os-management/remote-databases/edit`, `classicPage` `%CSP.UI.Portal.Dialog.RemoteDatabase`).
- Tools, each with `DESCRIPTORCLASS` `RemoteDatabaseList` and `PORTCLASS` `DatabasePort`:
  - `osmgmt.remotedatabases.create`: AD-54, `PUT /database {Server, Directory}`;
  - `osmgmt.remotedatabases.update`: merge;
  - `osmgmt.remotedatabases.delete`: `DELETE /database` only. `DatabasePort` never sends a file delete for a non-empty `Server`.
  - Each takes `%DB_IRISSYS:WRITE`. Create and update take `CLASSICPAGES` `%CSP.UI.Portal.Dialog.RemoteDatabase`; delete takes `%CSP.UI.Portal.Dialog.DatabaseDelete`.
  - The impact kind is `database-delete` with `sharedFile` empty.
  - Baseline: create and update `true`, delete `false`.
- **Validation (the proposed AD-21 seventh case):**
  - `Server` must be a `Name` of `ECP.DataServer` `GET /ecp/data-servers`.
  - `Directory` must equal, character for character, a directory of `GET /ecp/data-server/databases?name=<Server>`, read through `AdminPort` at the mint and again at the write; never free text.
  - The form reads that list only after a server is chosen, showing a running line (it took about 11 s here).
  - It is never a read tool's read.
- `DatabaseRules`, `DatabaseSave`, `Router.cls` (`GET /remote-database/form?server=`, `PUT /remote-database/:id`, `POST /remote-database`), `Error.cls` (`DATABASE.SERVER.ABSENT`, `DATABASE.REMOTEDIRECTORY.ABSENT`), client `remote-database-form.page.ts`/`.store.ts`, strings and EXPERIENCE literals ("Remote databases" · "No remote databases on this instance." · "Data server" · "Reading the data server's databases…"), and every roster above, again.

**Tests:**

- `src/OcuPilot/Test/DatabaseWriteProbe.cls` (new, not a test case; the `NamespaceWriteProbe` model):
  - probe databases `OCUPROBE183*` under `<mgr>ocuprobe183*`, created and removed through `AdminPort` (`POST`/`PUT`/`DELETE`, never `Config.Databases`);
  - test-only `%SYS` removal of `%DB_OCUPROBE183*` resources, their directories (`%File.RemoveDirectoryTree`) and any unregistered leftover;
  - probe namespaces `OCUPROBE183*`, one probe global mapping and `/csp/ocuprobe183*` applications (test-only);
  - `RemoveAll` by exact prefix and `CpfValid`.
- `src/OcuPilot/Test/DatabaseSaveFixture.cls`, `DatabaseActionFixture.cls`, `DatabaseConfirm.cls` (new seams on `DatabaseSave`, `ScreenAction` and `ConfirmFixture`, as 18.2's): the port is the one a test names in `^||OcuPilotDatabaseWritePort`, else `AcceptPort`.
- `src/OcuPilot/Test/DatabaseWrite.cls` (new; refuses unless `OCUPILOT_ALLOW_DATABASE_CONFIG` reads 1; `RemoveAll` before all, after each and after all, and a survivor fails the class). One method per matrix row, on both callers (the agent's mint and confirm; `DatabaseSave` and the screen-action route):
  - create, with its call order recorded by `DeviceRecordPort` and read back (mounted, journal state, resource);
  - the existing-resource create; the rolled-back create (a recording port that fails the configuration `PUT`);
  - the file and mounting edits, each sending its complete set;
  - the three delete shapes (with file, keeping it, shared file); the in-use delete, both direct and mapping-only;
  - the impact from `Impact.Of`, from `ScreenImpact` and on the proposal row, with the delete key enabled through `GovernanceFixture`. At the baseline the agent's delete is refused `GOVERNANCE.DISABLED` while the screen's proceeds.
  - The protected-target legs aim at `OCUPILOT`, the install namespace's routines database and `IRISSYS`, through `AcceptPort` on both callers, so a removed predicate shows as an accepted write and never as a deleted database.
- `src/OcuPilot/Test/DatabaseRefusals.cls` (new, same arming):
  - the name corpus;
  - `DATABASE.DIRECTORY.INUSE` on a probe database's directory and on `<mgr>irissecurity/`, with zero vendor calls;
  - `PATH.ROOT`, `PATH.NAME`, `PATH.MANAGERDIR` on the wizard route and the agent's mint;
  - a root dropped between mint and confirm, which refuses the confirm (`PathPortFixture`);
  - the bad and absent resource;
  - `DATABASE.REMOTE` from a probe remote configuration;
  - a key outside a group on each Save;
  - an edit of a database deleted since the read (the Save 404; the confirm `TARGETCHANGED`).
- `src/OcuPilot/Test/DatabaseWriteGate.cls` with `DatabaseWriteGateProbe.cls` (new, the `NamespaceWriteGate` model; refuses unless `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_DATABASE_CONFIG` read 1; calls counted through `DeviceRecordPort`):
  - A reader holding the two screen pairs reads the list, the form and the check route.
  - Each pair in the extra-pairs bullet above, when missing, is refused 403 naming it on both callers, with zero port calls, and nothing is left on disk or in the configuration.
  - A principal holding exactly the declared pairs creates, edits both groups, sets `MountRequired` (with `%Admin_Operate:USE`) and deletes a probe database on both callers (AD-29). A pair the instance still demands joins the tool and this class.
- `src/OcuPilot/Test/DatabaseDescriptor.cls` (new, stateless):
  - both declarations; the four tools' fields, kinds, pairs and `CLASSICPAGES`;
  - the Integration row: `osmgmt.localdatabases.read` answers the rows the list's read answers, all local.
- 18.14's `ClassicPageGate` and `MappingDescriptor` rosters gain the four tools with their pages.
- `scripts/ci-throwaway.sh` -- a new block `OCUPILOT_ALLOW_DATABASE_CONFIG: "1"`, commented as creating and deleting probe databases, their resources and directories, with `# classes: DatabaseRefusals, DatabaseWrite, DatabaseWriteGate`. `DatabaseWriteGate` also joins the principals block. A throwaway that predates the block is armed per call with `docker exec -e`.
- Rosters, re-derived from the code and from each class's red, never hand-counted: every roster the Code Map lists.
  - The entity count is one above 18.14's; the `Prohibited`/`AuditingUpdate` code counts one above 18.14's; `ReadTool` gains 5 (1 read, 4 writes).
  - `Navigation`'s OS management count gains 2; `GovernanceBaseline` `DISABLED` gains `osmgmt.localdatabases.delete`, as do `Governance`'s and `ToolDispatch`'s disabled sets.
  - `ToolEmit` admits the static extra pairs and argument pairs; `ToolWrite`'s `tOtherPorts` gains four `DatabasePort` tools and `REFUSEEMPTY` four entries; `PortGate` gains `DatabasePort`.
  - `EndpointCoverage` gains four routes, and `SurfaceCoverage` a row per descriptor and tool.
  - `KERNEL_REFUSALS` gains `OCUPILOTDATABASE`; the navigation, navigation-wire, rail-wire and home rosters gain `os-management/local-databases`.
- Client specs (new, on the task-wizard and namespace-form specs): `database-wizard.page.spec.ts`, `database-wizard.store.spec.ts`, `database-editor.page.spec.ts`, `database-editor.store.spec.ts`; plus `typed-name-dialog.spec.ts` (the option), `ui/tools/impact.test.mjs` and `screen-action-handler.spec.ts`.
- `ui/browser/local-databases.browser-spec.mjs` (new, the `namespaces` model; cleans up by exact probe name through `docker exec`):
  - AC1's wizard with a `PATH.*` refusal on the picker's field, then a create;
  - AC2's edit;
  - AC3's in-use advisory and delete with the file option;
  - AC4's advisory on `IRISSYS` (open and cancel only);
  - AC7's DW-1337 walk of the list, wizard, editor and dialog in both themes.

**Acceptance Criteria:**

- **AC1:** Given a holder of the Local databases pairs plus the create's pairs on `ocupilot-b-ci`, when they open OS management, then "Local databases" is its seventh side-bar entry and lists every local database configuration with its directory and status: the rows `osmgmt.localdatabases.read` answers, narrowed only by its cap.
  - When they create a probe database through the three-step wizard, choosing an allowed root and a subdirectory, it round-trips through `Security.Resource` `PUT`, `POST /database-dir` and `PUT /database` in that order. The database then reads mounted, journaled and guarded by `%DB_<NAME>`, and appears on Local databases and on Epic 6's Databases after the change event.
  - A taken name, a directory holding an `IRIS.DAT` and a `PATH.*` refusal are each shown on their field before any vendor call.
  - The agent's confirmed `osmgmt.localdatabases.create` does the same.
- **AC2:** Given a probe database, when its editor changes a General setting, a Mounting setting, the new volume threshold and the new volume directory (through the picker), and Saves, then each changed group round-trips through its endpoint (`PUT /database-dir`, `PUT /database`), sending that endpoint's complete set read fresh. The volume files section lists `DatabaseVolumeList`'s rows. The agent's confirmed `update` and `updatemount` do the same.
- **AC3:** Given a probe database that a probe namespace uses (directly, or only through a mapping) and in which a probe web application runs, when Delete is chosen on its row, then before anything is removed the typed-name dialog's advisory names the namespace and the application, and the delete is refused 409 `DATABASE.INUSE` with nothing removed.
  - Given an unused probe database, after the typed name and Delete with "Also delete the database file and its volume files" checked, the configuration, `IRIS.DAT` and its volume files are gone. Unchecked, only the configuration is gone.
  - A database whose file another configuration name shares keeps its file, and the advisory names the sharer.
  - The agent's proposal, with its key enabled, carries the same impact.
- **AC4:** Given `OCUPILOT`, the install namespace's globals or routines database, or `IRISSYS`, when either caller deletes it or changes its resource or read-only setting, then the write is refused `PROHIBITED.OCUPILOTDATABASE`, and the Delete dialog states that reason when it opens.
- **AC5:** Given least-privileged principals on the throwaway, when they call the database tools:
  - the two screen pairs read the list, the form and the check route;
  - each missing extra pair is refused 403 naming it before any port call, and no directory, file, configuration or resource is left;
  - a principal holding exactly the declared pairs writes on both callers;
  - a custom resource assigned to each `CLASSICPAGES` page refuses a caller without it (18.14's `ClassicPageGate`).
- **AC6:** Given the New Namespace form, when "Create a database" creates one, then on return the form's database choices include it without a reload (SA-13). The namespace delete stays unchanged, and SA-15's database delete is AC3's.
- **AC7:** Given the new screens, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays below 3800 kB; if it passes `maximumWarning` (2107 kB), the warning is re-based under DW-1166 together with `angular-json.test.mjs`'s literal.
- **AC8 (Part C, recommended to move):** Given an ECP data-server definition on the throwaway, when a remote database is created, edited and deleted from Remote databases (OS management's eighth entry) and by the agent, then each round-trips through `PUT|DELETE /database`, with its directory chosen from the data server's own list, and no file on this instance is touched.

## Spec Change Log

- 2026-09-29, runner, before re-plan: the orchestrator split remote databases (SA-17, Part C) into Story 18.16 (Rule 5, 2026-09-28) and kept expand-volume and size-grow in 18.4. The intent contract drops Part C and adds DW-1080 (Database details' background tasks through `BackgroundTaskPort`), DW-1807 (`PATH.SERVED`), DW-1795 and DW-1796. Since the first plan, `PATH.INSTANCE` covers every file in every configured database and journal directory (DW-1790), and every file and vendor-writes directory under OcuPilot's served directory is refused `PATH.SERVED` (DW-1798, DW-1806). Status set to `draft` for the re-plan.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: every call through `AdminPort` or `DatabasePort`, which extends it.
- AD-3: the create's and updates' derived fields; the create's POST-only keys are the port's.
- AD-4: each update sends its endpoint's complete set.
- AD-5, AD-36, AD-44: one descriptor per screen; the list and its tool read one read; the classic pages plus `CLASSICPAGES` (DW-1784).
- AD-6, AD-34, AD-40: proposal and confirm.
- AD-8, AD-29: pairs and extra pairs, argument pairs, the removal impact.
- AD-10: the new predicate. AD-13, AD-14: the new type and events.
- AD-15: the marker. AD-16: `%SYS` only through the port.
- AD-21: the sixth case for both directories, DW-1791, and Part C's proposed seventh.
- AD-22: the baseline. AD-39: violations.
- AD-51: the delete's declared subject. AD-53, AD-55: two callers. AD-54: the create's absence fingerprint. AD-56 (ii): `DeleteFile` as a declared value.
- AD-58: read-back. AD-59: `Snippet` for every `DatabasePort` branch.
- AD-26 is not engaged: no write in this story queues. `POST /database-dir` answered 201 synchronously.

**Measured on `ocupilot-b-ci`, 2026-09-28.** These are the plan's probes; every probe object was removed, and removal was re-checked by the lead.

- **Create:**
  - `POST /database-dir {Directory}` answers 201 and creates the directory, `IRIS.DAT`, `iris.lck` and `stream/`. It mounts the database under `%DB_%DEFAULT`, not journaled unless `GlobalJournalState:true`, and makes no resource and no configuration.
  - `PUT /database?name= {Directory}` answers 201 and adds only the configuration. `PUT /database` for a directory that does not exist also answers 201, reading `Unavailable`.
  - `ResourceName` not beginning `%DB_` is refused (500 #896 on `POST`; `<FUNCTION>` on `PUT`), and a refused `POST` leaves an empty directory. A `%DB_` name with no resource is accepted and never created.
- **DW-1791.** A second `POST /database-dir` on a directory holding `IRIS.DAT` answers 500, mounted (#60) or dismounted (#78), and the data survives. `PUT /database` naming another database's directory answers 201: a synonym, with a logged warning.
- **Updates.** Both `PUT`s are upserts that keep omitted fields. A `PUT /database` without `Directory` for a new name creates an entry at the manager directory (IRISSYS's file).
- **Delete.**
  - `DELETE /database` answers 409 #429 while any namespace uses the database, directly or only through a mapping. It touches no file and leaves a kept file mounted.
  - `DELETE /database-dir` never refuses for configuration names or namespaces. It dismounts and deletes `IRIS.DAT` and every volume file, and keeps the directories, `stream/`, `iris.dbdir` and the `%DB_*` resource.
  - The classic dialog deletes the file only when asked (`DeleteDatFile`, unchecked), hides that option when synonyms exist, and refuses the seven system databases by name.
- **Pairs:**
  - Reads, `PUT /database-dir` and `DELETE /database-dir` need `%Admin_Manage:USE` and `%DB_IRISSYS:READ`.
  - `POST /database-dir`, `PUT /database` and `DELETE /database` also need `%DB_IRISSYS:WRITE`. A refused `POST` leaves an `IRIS.DAT` the API cannot remove.
  - `MountRequired:true` also needs `%Admin_Operate:USE` (#921).
  - `%Operator` gets 403 with `errors: []` on `/databases`, `/database-dirs`, `/database` and `/volumes` (the reported claim, confirmed), and 200 on `GET /database-dir`.
  - `/database-dirs` is a plain array of 14 (confirmed).
- **Async.** Expand-volume, modify-size, truncate and info answer 202. Their `Location` is a v1 `async-result` path, and the poll carries no progress figure. One expand was read once and its row deleted; #7846 appeared 0 times.
- **Remote.** A remote configuration is created without a live ECP link. `GET /ecp/data-server/databases` blocked about 11 s and opened an ECP connection attempt, and `%Service_ECP` was left disabled. A data server a remote database uses cannot be deleted (409 #423).
- The throwaway's instance state read `alert` before these probes, from an `alerts.log` entry at 16:06 (inference). The probes added two severity-2 #455 lines from the `MountRequired` refusal.

**Decisions:**

- **Two lists, two keys.**
  - Local databases (configuration, keyed by name, `%CSP.UI.Portal.Databases`) sits beside Epic 6's Databases (operations, keyed by directory, `OpDatabases`), as the classic portal separates them.
  - The new type `database-configuration` keeps AD-13's identity single-spelled. Epic 6's list declares it secondary, so it re-fetches.
  - Positions 7 and 8 are appended, so 18.2's pinned six stay.
- **One create tool, one port sequence.** The resource first (Conventions), then the file, then the configuration. `DatabasePort` rolls back the file it created if the configuration fails. A resource it created is left: it guards nothing, and its role is granted to nobody.
- **Two update tools, one Save.** Each tool covers one endpoint and its own complete set. The Save sends the changed groups in order, as AD-56's two-write Save does. `update` is keyed by name and the port finds the directory.
- **Delete stays one write.** The vendor refuses it while in use, so OcuPilot never deletes a namespace for it; the advisory names the namespaces and applications instead. The file follows only on request and never while shared, which closes the vendor's unguarded file delete for OcuPilot's callers.
- **DW-1791 lives in the database rules, not in `PathPort`.** Only a database create is disqualified by an existing `IRIS.DAT`, and the vendor refuses it too (measured). No `PathPort` change is needed; AD-21 gains one sentence (below).
- **Expand-volume and size grow go to 18.4's OS-21**, which the epic context lets whichever story lands first own. 18.4 keeps them directory-keyed and disabled, and 18.3 queues nothing.
- **Governance:** delete `false` (preamble); create, both updates and Part C's create and update `true` (through 2026-10-04).
- **Not in this story:** rename (no API), encryption (18.7), mirror and block size, `StreamLocation` and `NewGlobalCollation` edits, and disk operations (18.4).

**Recommended split (Rule 5, for the runner; nothing is dropped here).** Part A (AC1-AC7) is one reviewable story, about 18.2's size plus the wizard and `DatabasePort`. **Recommend moving Part C (AC8, SA-17 remote databases) to a new Story 18.16, "Remote databases".** It needs its own AD-21 case (a directory on another server, chosen from a read that opens an ECP connection and blocks about 11 s), a data-server read on the mint path, and three more tools and two screens. Its measurements are recorded above for that plan.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate):**

1. **AD-8, after 18.14's paragraph:** "**Story 18.3's database tools declare pairs beyond their screen's set** [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]: the create, the mounting update and the delete declare `%DB_IRISSYS:WRITE`, because a principal holding only the Local databases screens' `%Admin_Manage:USE` and `%DB_IRISSYS:READ` was answered `<PROTECT>` on `POST /database-dir`, `PUT /database` and `DELETE /database`, and a refused `POST` left an `IRIS.DAT` the admin API could not remove (measured on `ocupilot-b-ci`, 2026-09-28). The create also declares `%Admin_Secure:USE`, because the vendor makes no `%DB_<NAME>` resource and the port creates or checks it, and `PathPort`'s `%Admin_FileSystemAccess:USE`. The mounting update declares `%Admin_Operate:USE` when it sets `MountRequired` (refused #921 without it), and the file update declares `%Admin_Secure:USE` when it sends a resource name and `%Admin_FileSystemAccess:USE` when it sends a new volume directory. Each is refused by name before any port call."
2. **AD-8, after the namespace impact paragraph:** "**A database delete names its impact too** [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]: the namespaces that use it through their globals, routines or temporary database or a mapping, read through the Namespaces list's and the mapping lists' declared reads, which the vendor's delete refuses while any remains (409 #429, measured on `ocupilot-b-ci`, 2026-09-28); the web applications that run in them, read through the Web applications list's read; and the other configuration names that share its file, which keeps the file."
3. **AD-10, a new bullet after OcuPilot's own mappings:** "**OcuPilot's and the instance's own databases** [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]: deleting, or changing the directory, server, resource or read-only setting of, OcuPilot's own database, the globals or routines database of the namespace OcuPilot's API runs in, or one of the seven databases the classic Delete Database dialog refuses (`IRISAUDIT`, `IRISSYS`, `IRISLIB`, `IRISLOCALDATA`, `IRISTEMP`, `IRISMETRICS`, `IRISSECURITY`) is refused `PROHIBITED.OCUPILOTDATABASE`, from either caller. The vendor's own file delete does not refuse a database in use (measured on `ocupilot-b-ci`, 2026-09-28), so these are refused on the write path. Every other database delete or change is permitted, the delete at the destructive treatment with its removal impact."
4. **AD-21, at the end of the sixth case:** "A database create also refuses, in its own rules and before any vendor call, a directory that already holds an `IRIS.DAT`; the vendor's `POST /database-dir` refuses it too, leaving the file intact, while its `PUT /database` accepts a second configuration name for that directory, which the create never sends alone (measured on `ocupilot-b-ci`, 2026-09-28) [AMENDED 2026-09-28, Story 18.3 spec gate, DW-1791, Rule 20]."
5. **AD-52, a new paragraph:** "**A declared port may sequence several admin API calls for one write** [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]. `DatabasePort`'s database create resolves its directory through `PathPort`, creates the `%DB_<NAME>` resource unless the tool names an existing one (`Security.Resource` `PUT`), creates the file (`Database.SysCRUD` `POST`, a body the port builds from the tool's declared size, journal state and resource and the resolved directory), then sends the create's own `Database.ConfigCRUD` `PUT`, deleting the file it created if that `PUT` fails. Its delete sends `DELETE /database` and, only when asked, when that succeeded and when no other configuration name shares the directory, `DELETE /database-dir`. The proposal, fingerprint, gates, marker and ledger row are the one write's."
6. **AD-44, appended to the DW-1784 paragraph:** "Story 18.3's: the database create `%CSP.UI.Portal.Dialog.DatabaseWizard`, the mounting update `%CSP.UI.Portal.Database`, the file update `%CSP.UI.Portal.Database` and `%CSP.UI.Portal.DatabaseVolumes`, and the delete `%CSP.UI.Portal.Dialog.DatabaseDelete` [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]."
7. **Part C only, if kept: AD-21, a seventh case:** "The seventh is a remote database's directory [AMENDED 2026-09-28, Story 18.3 spec gate, Rule 20]: a directory on an ECP data server, never on this instance, chosen from that server's own database list (`ECP.DataServer` `GET /ecp/data-server/databases`), read through `AdminPort` at the mint and again at the write, and accepted only when it equals one of that list's directories character for character, never as free text. The read opens an ECP connection when none is open (measured on `ocupilot-b-ci`, 2026-09-28: about 11 s against a server whose ECP service was off), so it is a form's and a write's read, never a read tool's."

**Integration ACs:**

- AC1: `LocalDatabaseList` and `osmgmt.localdatabases.read` answer one read (AD-36); pinned in `DatabaseDescriptor`.
- AC1: the create consumes `PathPort.Resolve`, with the resolved path reaching the vendor as `Directory` (`DatabaseWrite`, recording port), and the picker with its page-owned store, where a `PATH.*` reason renders on its field (browser spec).
- AC3: the delete's impact consumes `NamespaceList`'s, the three mapping lists' and `WebAppList`'s declared reads through their own gates; pinned in `DatabaseWrite` and the browser spec.
- AC2: the editor consumes `DatabaseVolumeList`'s read.

**Consumes:**

- 18.1: `PathPort.Resolve`, `app-server-path-picker` and `AllowedDirectoriesStore`.
- 18.2: `NamespaceList`'s read and `NamespaceForm`.
- 18.14: the three mapping lists, `CLASSICPAGES`, `WithClassicPages` and `ClassicPageGate`. They are not on this branch at planning; if 18.14's implementation changes the names, the runner tells the implement stage.
- Earlier stories: `WebAppList`'s and `ResourceList`'s reads, Epic 6's `DatabaseVolumeList` read, 16.19's impact, 16.17's read-back, 14.1's `Snippet`, 14.2's baseline and `GovernanceFixture`, and Epic 9's `FormStepper`.

**Consumed-by:**

- 18.4: its disk operations and OS-21's expand act on the databases this story creates.
- 18.12: the agent's grown tool set.
- 18.13: the own-database predicate must keep holding under a multi-namespace install.
- 18.15: enable-interop's ENSTEMP and SECONDARY databases appear on Local databases (inference).
- 18.16: remote databases, if split.

**Ledger inbox:** DW-1791 is addressed by `DATABASE.DIRECTORY.INUSE` in `DatabaseRules`, with AD-21 amendment 4 and `DatabaseRefusals`' legs; the recommended adjudication is `resolved-by:18-3`. DW-1774 is met by the roster tasks.

**Contended with Epic 16, all add-only:**

- `Error.cls`, `Router.cls`, `Baseline.cls`, `strings.ts`, EXPERIENCE.md, the rosters, `ci-throwaway.sh` and `ci.test.mjs`, `screen-action-handler.ts`, `typed-name-dialog.ts`.
- `screens.generated.ts` and `ToolFields.cls` are regenerated.
- Not touched: `Area.cls`, `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/Proposal/Mint.cls`, `PathPort.cls`.

## Verification

**Setup (slot B):**

- Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`.
- Every database write happens there, on `OCUPROBE183*` objects only. `server: "ocupilot-slot-b"` reaches the dev instance, never the throwaway, so no MCP tool writes a database.
- One test class per call; send the next only once the previous has landed in `%UnitTest_Result`.
- Arm the new classes per call with `docker exec -e OCUPILOT_ALLOW_DATABASE_CONFIG=1`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time, for each of these classes -- expected: 0 failures each, the totals checked against `%UnitTest_Result`:
  - the story's own: `DatabaseWrite`, `DatabaseWriteGate`, `DatabaseRefusals`, `DatabaseDescriptor`, `ClassicPageGate`, `MappingDescriptor`;
  - the rosters and shared suites: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Prohibited`, `AuditingUpdate`, `RefusalCopy`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `ToolWrite`, `ToolRoundTrip`, `DraftRegistry`, `PortGate`, `ProposalPrivilege`, `EntityRef`, `Navigation`, `Wire`, `WireSecurityRead`, `ScreenGrounding`, `ImpactRoute`, `Envelope`, `PathPort`, `NamespaceWrite`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/local-databases.browser-spec.mjs browser/databases.browser-spec.mjs browser/impact.browser-spec.mjs browser/namespaces.browser-spec.mjs` -- expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh` -- expected: clean, and `wc -l` on EXPERIENCE.md reads 993.
- `(once, before dev_complete)` -- expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).
  1. The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time.
  2. `cd ui && npm test && npm run build`.
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
  4. Afterwards, no `OCUPROBE183*` configuration, `ocuprobe183*` directory, `%DB_OCUPROBE183*` resource or gate principal remains.

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line. Predicate mutations run only against `AcceptPort`.

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC1 | `LocalDatabaseCreate` drops `CREATES` | `DatabaseWrite`'s taken leg (the upsert is minted) |
| AC1 | `DatabasePort` skips the resource step | `DatabaseWrite`'s create read-back (resource absent) |
| AC1 | `DatabaseRules` skips the `IRIS.DAT` check | `DatabaseRefusals`' DW-1791 legs (a vendor call is recorded) |
| AC1 | `LocalDatabaseList` read drops `Directory` | `DatabaseDescriptor`'s Integration leg; `ReadTool` |
| AC2 | `LocalDatabaseUpdate` sends only changed keys | `DatabaseWrite`'s complete-set leg |
| AC3 | `DatabasePort` sends the file delete when shared | `DatabaseWrite`'s shared-file leg (file gone) |
| AC3 | `KindOf` omits `database-delete` | `DatabaseWrite`'s impact leg; the browser advisory |
| AC4 | The `OCUPILOTDATABASE` arm is removed | `DatabaseWrite`'s protected legs (an accepted write is recorded) |
| AC5 | The create drops `%DB_IRISSYS:WRITE` | `DatabaseWriteGate` (the port is called) |
| AC5 | `LocalDatabaseDelete` empties `CLASSICPAGES` | `ClassicPageGate`'s delete leg; `MappingDescriptor`'s roster |
| AC6 | The namespace form store ignores the event | `namespace-form.store.spec.ts` |
| AC7 | A wizard step label drawn in `--ocu-surface` | the DW-1337 legs, in both themes |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Planned; no product code changed.**

- Part A (AC1-AC7) and Part C (AC8) are specified in build order, with Task 0 as the implement stage's first step.
- The stage gate was observed on `ocupilot-b-ci` (Design Notes › Measured): the create, update, delete, volumes, remote and least-privileged probes, and the classic page names.
- Every probe object was removed, and the lead re-checked: no `OCUPROBE183*` database or namespace, no `ocuprobe183*` directory, no probe resource, user, role or application, no ECP definition, and no probe async row.
  - The probe objects were databases A to J, R, Y and Z, their files and directories, `%DB_OCUPROBE183B`, `OcuProbe183Custom`, namespaces `OCUPROBE183NS`/`NS2` with one mapping, `/csp/ocuprobe183`, data server `OCUPROBE183DS`, `OcuProbe183Reader`, `OcuProbe183User`, `OcuProbe183Op`, and one expand task (read once, row deleted).

**For the runner:**

- Seven spine amendments are proposed as exact text (Design Notes); the seventh applies only if Part C stays.
- The recommended split moves Part C to a new Story 18.16.
- Expand-volume and size grow are assigned to 18.4's OS-21.
- Three vendor defect candidates are in `deferred:` for harvest as human-owned reports.
- DW-1791's recommended disposition is `resolved-by:18-3`.
- The throwaway's `alert` state predates this run (inference).
