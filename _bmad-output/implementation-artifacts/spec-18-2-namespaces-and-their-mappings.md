---
title: 'Story 18.2: Namespaces and their mappings'
type: 'feature'
created: '2026-09-28'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot create, edit or delete a namespace, which are catalog rows SA-03 and SA-11 to SA-15 (mappings and copy-mappings are Story 18.14's). The classic Namespaces and Delete Namespace pages are the only way. The admin API carries every step (observed on `ocupilot-b-ci`), with two hazards:

- Its namespace delete also deletes every web application bound to the namespace.
- Nothing stops a caller from deleting or repointing OcuPilot's own namespace.

**Approach:** The story adds a Namespaces list to OS management with a create and edit form, and a Delete whose typed-name dialog lists the web applications deleted with the namespace and the databases that stay (AD-8's removal impact).

Every write is one derived tool that both callers reach (AD-53, AD-55). The kernel refuses deleting or repointing OcuPilot's install namespace (AD-10).

**Scope, decided by the orchestrator at the spec gate (2026-09-28, Rule 5):** the planned Part B (global, routine and package mappings with the `%`-global guard, and async copy-mappings) moved to Story 18.14 with epic AC2 and AC3; SA-13's enable-interop is routed there as DW-1776. This story is the former Part A only.

## Boundaries & Constraints

**Always:**

- **Screens.** Every screen is in `os-management` with the pairs `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, which the area already covers.
- **Extra tool pairs.** Tools declare the measured extras and refuse by name before any port call:
  - every namespace write: `%DB_IRISSYS:WRITE`;
  - `osmgmt.namespaces.delete`: also `%Admin_Secure:USE`;
- **Write kinds:**
  - A create is AD-54: it fingerprints the name's absence, because both PUTs are upserts.
  - An edit is AD-4: it sends the complete set read fresh.
  - A delete sends no body and is `DESTRUCTIVE`.
- **Delete impact.** A namespace delete carries AD-8's impact, computed at mint and again when the dialog opens:
  - the web applications whose `Namespace` equals the target, ignoring case, read through `WebAppList`'s declared read;
  - the target's own globals, routines and temporary databases, which stay.
  - A part the caller cannot read is reported unchecked, naming the pair.
- **Kernel refusals (AD-10), from either caller:**
  - `PROHIBITED.OCUPILOTNAMESPACE` refuses deleting, or changing the `Globals` or `Routines` database of, OcuPilot's install namespace or `%SYS`.
  - The install namespace is the `NameSpace` of OcuPilot's own API application, read at the write.
- **Identity:** `namespace`: scope `instance`, id `Name`, rule `foldcase`.
- **Contended files are edited add-only.** EXPERIENCE.md is edited in place and stays at 993 lines. `screens.generated.ts` is regenerated, never hand-merged.

**Never:**

- No enable-interop.
- No namespace rename.
- No web-application create.
- No inline database create (18.3).
- No database delete in the namespace delete.
- No `maxRows` on a namespace `DELETE`.
- No `%Api.Admin.*` name outside `AdminPort`.
- No direct `Config.Namespaces` write.
- No mapping screen, mapping write or copy-mappings (Story 18.14).
- No server-path field. A namespace names databases, so 18.1's `PathPort` is not consumed.
- No spine edit. The runner writes the amendments.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Create | `OCUPROBE182X` over `USER`, `USER` | 201; the row reads `TempGlobals` `IRISTEMP`; no web application or mapping is created | none |
| Create, name taken | An existing name, in any case | Refused on Name at mint and at Save; no `PUT` is sent | `NAMESPACE.NAME.TAKEN` |
| Bad name | `A.B`, `1AB`, `A B`, `A$B`, or 65 characters | Refused on Name; no vendor call | `NAMESPACE.NAME.SHAPE` |
| Unknown database | Globals `NOSUCHDB` | Refused on that field | `NAMESPACE.GLOBALS.ABSENT` |
| Edit | Routines changed | The complete `{Globals, Routines, TempGlobals}` is sent; the diff shows one row | none |
| Delete with bound apps | A probe namespace with two bound apps | The dialog lists both as deleted with it and its databases as staying; afterwards the namespace, its mappings and both apps are gone, and the databases remain | none |
| Own namespace | Delete, or a Globals/Routines change, on the install namespace or `%SYS` | Refused; the dialog advisory states the reason when it opens | `PROHIBITED.OCUPILOTNAMESPACE` |
| Delete without `%Admin_Secure:USE` | A principal lacking the pair | 403 names the pair before any port call; the namespace still exists | `AUTH.NOPRIVILEGE` |
| Write without `%DB_IRISSYS:WRITE` | Any namespace write | 403 names the pair; no vendor call | `AUTH.NOPRIVILEGE` |
| Integration | The Namespaces list and its read tool; the delete's impact reading `WebAppList`'s read | The same rows (AD-36); the impact names the bound applications | Same gate |

</intent-contract>

## Code Map

**Vendor, read and observed on `ocupilot-b-ci` (detail under Design Notes):**

- Routes in `%Api.Admin.Dispatch.v2` (UDL 253-257, 307-324):
  - `GET /namespaces` (`Namespace.Namespace` LIST: `filter`, `maxRows`);
  - `GET|PUT|DELETE /namespace?name=`;
  - `POST /namespace/copy-mappings` (MAPPINGS, body only);
  - `GET /namespace/{global|routine|package}-mappings?namespace=`;
  - `GET|PUT|DELETE /namespace/{kind}-mapping?namespace=&name=`;
  - `GET /async-result?id=`.
- `GET /databases` (`Database.ConfigCRUD` LIST) answers `{Name, Directory, Server, …}`. It is the database-name source for the forms.
- Classic pages, all present: `%CSP.UI.Portal.Namespaces`, `.Namespace`, `.NamespaceEdit`, `.Mappings.Global`, `.Mappings.Routine`, `.Mappings.Package`, and `.Dialog.NamespaceDelete`.

**Port:**

- `src/OcuPilot/Port/AdminPort.cls`:
  - `MUTATINGTYPES` :302, `BODYLESSTYPES` :318, `VERIFIEDDELETES` :348 and `QUEUEDWRITES` :481 (exactly `Security.Audit.Record/COPY,Security.Audit.Record/PURGE`);
  - `SPLITQUERIES` :506 splits on `/`, so it cannot carry a subscripted global name;
  - `ASYNCTIMEOUT` 30 s :565; `Sequence` refuses a queued write :2103; `AwaitTask` :2141; `SnippetForm` :2469.
- `src/OcuPilot/Port/AuditPort.cls`: the model for a port extending AdminPort — `STARTEDHTTP` :44, the timeout-to-started conversion at :97-102, the body built by the port at :347, and `Snippet`/`SnippetForm` at :371 and :380.

**Tools** (`src/OcuPilot/Screen/Tool/`):

- `Write.cls`: parameters `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CREATES` :141, `SCREENACTIONS` :157 and `SCREENVALUES` :201; hooks `ArgumentProblem` :786, `StateDiff` :463, `PortQuery` :417 and `IdArgument`/`IdParam` :500/:507.
- `DeviceCreate.cls` :17-49,159-166 (the extra `%DB_IRISSYS:WRITE`), `DeviceUpdate.cls` and `DeviceDelete.cls` :17-53: the three shapes to copy.
- `AuditCopy.cls` :14-17,64: an action with a port-built body plus the poll pair.
- `ErrorDeleteMint.cls` / `ErrorDelete.cls` :89-162: argument parts joined into a composite id.
- `FieldLists.cls` :131-146 already holds all four `Namespace.*` templates; no regeneration is needed.
- `Classification.cls` holds one hand-written entry per body-sending tool (grammar :6-29, devices :443-468). `ToolFields.cls` is regenerated by `cd ui && node tools/field-lists.mjs`.

**Kernel:**

- `Kernel/Proposal/Mint.cls`: fresh read :166-168, the create inversion :171-195, the effects and consequence :317-333, `ConsequenceOf` :739.
- `Kernel/Proposal/Impact.cls`: kind parameters :20-30, `Of` :92, `KindOf` :157, `Guarded` :282 (it filters on `Resource`), `ListRows` :332.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250, `Codes()` :470, `ReasonFor` :478;
  - `PermittedChangeFields` :580, `PermittedCreateFields` :691;
  - the `Prohibits` type chain :788, `Created` :960, `WeakensByEffect` :1131, `Changed` :2730, `Target` :2776;
  - `ServesOcuPilot` :2871 and `Recorded` :2900, which are OcuPilot's roster applications.
- `Kernel/EntityType.cls:40` (`TYPES`, 32 entries).
- `Kernel/EntityRef.cls`: `IDRULES` :59, `IDRULENAMES` :64, `NormalizedId` :245.
- `Kernel/EntityId.cls:74,81` (`JoinComposite`, `SplitComposite`, joined by `$Char(1)`).
- `Kernel/State/Base.cls`: `DATABASENAME` :70, `MAPPINGPATTERN="OcuPilot*"` :86. `Install/Installer.cls` `EnsureMapping` :2855-2881; `Install/Roster.cls` :105-151.
- `Kernel/Governance/Baseline.cls` :17-96 (e.g. `"osmgmt.devices.delete": true`, `"security.auditing.purge": false`).

**Screens:**

- `Screen/Descriptor/DeviceList.cls`, `DeviceForm.cls` and `WalletSecretList.cls`; the last is parent-scoped with one route-id criterion.
- `Screen/Read.cls`: the object-read seeding of its route id :395-404, the LIST branch :435-447, `SeedCriteria` :767.
- `Screen/Registry.cls`: the parent-scoped one-criterion rule :1413-1436, `SELFPROTECTIONRULES` :2530, `PROMPTGROUPKEYS` :2538.
- `Screen/Area.cls:121`: OS management's pairs.

**Save routes:**

- `Area/OsMgmt/DeviceSave.cls` (`Create` :115, `Update` :160, `PortViolations` :232, `Prohibited` :248) and `DeviceRules.cls`.
- `Api/Router.cls`: the device routes :113-116, their handlers :530-554, the default scope :1213.
- `Api/Error.cls`: violation codes of the form `ENTITY.FIELD.KIND`, e.g. `DEVICE.NAME.TAKEN` :2345.

**Client:**

- Actions and pages: `ui/src/app/areas/os-management/device-actions.ts` :24-40, `device-form.page.ts` and `.store.ts`, `ui/src/app/areas/security/wallet-actions.ts` :36-46 (Create carries its parent as a query parameter).
- `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :112-141; `app.ts` :297-299,597-598.
- `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :50, `VALUE_ACTIONS` :139, `IMPACT_ACTIONS` :188, `DESTRUCTIVE_CONSEQUENCES` :203, `SCOPED_TARGETS` :229, `openWithImpact` :538,646-670.
- `ui/src/app/shell/screen-action-dialogs.ts` :22-33; `ui/src/app/core/impact.ts` :14-29,141-171.
- `ui/src/app/areas/security/audit-copy-dialog.ts`, and `auditing-config.page.ts` :172,533-540,596-619 (the running line, `sendFor`, `continued()`).
- `ui/src/app/core/scope.ts` (`ScopeService` :141, `runLoad` :320); `ui/src/app/core/shortcuts.ts` :10-16,33 (`os-management/namespaces` is already listed first).
- `strings.ts`: impact phrases :3031-3087 (EXPERIENCE.md:577); audit-copy strings :2650-2658. Reuse these keys: `headerNamespaceLabel`, `tableColumnName`, `tableColumnType`, `systemInfoDatabase`, `oauthResourceServerTabMappings`, `auditDatabaseCopyConfirm`, `auditDatabaseStillRunning`, `actionCreate`, `actionDelete`. Every value must be unique (`strings.test.mjs:708`).

**EXPERIENCE.md rows to extend in place:**

- `:164`: OS management side bar.
- `:173`: Dialogs.
- `:378`: the Devices Fixed-strings row, which gains the new literals.
- `:479`: delete bodies.
- `:481`: kernel refusals.
- `:577`: impact phrases.

**Rosters:**

- `Test/ReadTool.cls` :93-94,112; `Test/SurfaceCoverage.cls` (device rows :73,123,143-145); `Test/EndpointCoverage.cls` (device probes :184-187);
- `Test/Descriptor.cls` (`ReadShapes` :67-118; entity count :1699); `Test/Prohibited.cls` :218,589,672; `Test/GovernanceBaseline.cls` :53-65;
- `Test/ToolWrite.cls:1192`, `Test/PortFixture.cls:21`, `Test/AdminPortAsync.cls:85-94`, `Test/DraftRegistry.cls` :101-124,193;
- `Test/Navigation.cls` :328-353; `Test/Wire.cls:697`; `Test/WireSecurityRead.cls` :548,555,558; `Test/ScreenGrounding.cls` :66-84; `Test/RefusalCopy.cls`;
- client: `ui/tools/navigation.test.mjs` :150-159, `navigation-wire.test.mjs` :90-165, `ui/src/app/shell/rail-wire.spec.ts` :122-160, `ui/tools/self-protection.test.mjs` :253-263 (`KERNEL_REFUSALS`), `home.page.spec.ts` :1010-1090 (`shortcutScreens()[0]` becomes Namespaces);
- `scripts/ci-throwaway.sh` arming blocks :172-345, held against `ui/tools/ci.test.mjs` :1818-1990.
- No browser spec pins the OS management side bar (grepped `ocu-side-bar-label`); the pins are the files above (DW-1774).

**Test models:**

- `Test/DeviceWriteGate.cls` (`ARMINGVARIABLE` :20, `RunAs` :226-249, `EnsurePrincipals` :274-304, and a recording port).
- `Test/DeviceProbe.cls` (`PREFIX` :10, `RemoveAll` :100, `CpfValid` :128) and `Test/DeviceWire.cls` :68-111.
- `ui/browser/device-editor.browser-spec.mjs` :57-110 (cleanup through `docker exec`), `oauth-resource-server-editor.browser-spec.mjs` :127-157 (the DW-1337 helper), `audit-copy-purge.browser-spec.mjs` :96-150.

## Tasks & Acceptance

**Execution — Part A, namespaces (AC1-AC3):**

- `src/OcuPilot/Kernel/EntityType.cls`, `Kernel/EntityRef.cls` -- append `namespace` to `TYPES`; add `namespace:foldcase` to `IDRULES` -- the vendor resolves a namespace name without case and stores it in upper case, measured.
- `src/OcuPilot/Port/AdminPort.cls` -- add `Namespace.Namespace/PUT` and `/DELETE` to `MUTATINGTYPES`, `/DELETE` to `BODYLESSTYPES` and to `VERIFIEDDELETES`, each with its measured fact in the doc comment -- routes the writes through the port's lists.
- `src/OcuPilot/Screen/Tool/NamespaceCreate.cls`, `NamespaceUpdate.cls`, `NamespaceDelete.cls` (new, on the device model):
  - `osmgmt.namespaces.create`: `CREATES`, `PUT`.
  - `osmgmt.namespaces.update`: a merge `PUT`.
  - `osmgmt.namespaces.delete`: `DELETE`, `SENDSBODY` 0, `DESTRUCTIVE`, `SCREENACTIONS` `delete`; `FINGERPRINTSUBJECT` and `READANSWERS` are `Globals,Routines,TempGlobals`, and `PRECONDITIONFIELD` is `Globals`.
  - Pairs as in Always. `ArgumentProblem` applies `NamespaceRules`.
  - `DESCRIPTORCLASS` is `NamespaceList`.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- add create and update entries: `Globals`, `Routines` and `TempGlobals` are ordinary -- then run `cd ui && node tools/field-lists.mjs` -- AD-3.
- `src/OcuPilot/Screen/Descriptor/NamespaceList.cls` (new; a list):
  - route `os-management/namespaces`, `sideBarPosition` 6, `entityType` `namespace`, scope `instance`, id `single`;
  - read `{admin, Namespace.Namespace, LIST}` with fields, filter and sort `Name, Globals, Routines, TempGlobals` (default `Name` ascending), paging `cap`;
  - columns Name (`name`), "Globals database", "Routines database", "Temporary database";
  - `emptyStateKey` "No namespaces on this instance.", `emptyAgentKey` "create a namespace" (also the create refusal's action slot, as "create a device" is);
  - `primaryAction` `create`, `rowActions` `[delete]`;
  - `classicPage` `%CSP.UI.Portal.Namespaces`, `commandAliases` `["namespaces","configure namespace"]`;
  - three `promptGroupGettingStarted` prompts; `toolIdentifier` `osmgmt.namespaces`.
- `src/OcuPilot/Screen/Descriptor/NamespaceForm.cls` (new; `form-page`):
  - route `os-management/namespaces/edit`, position 0, id `single`, same pairs;
  - `classicPage` `%CSP.UI.Portal.NamespaceEdit` (it also replaces `.Namespace`);
  - three prompts; `toolIdentifier` `osmgmt.namespaceform`.
- `src/OcuPilot/Area/OsMgmt/NamespaceRules.cls`, `NamespaceSave.cls` (new, on the `DeviceRules`/`DeviceSave` model):
  - Name: required; matches `^[%A-Za-z][A-Za-z0-9_-]{0,63}$`, measured (pin it with a corpus against the instance); taken when an existing name matches ignoring case.
  - Globals and Routines: required. Each named database, and TempGlobals when sent, must be a `Name` in `Database.ConfigCRUD` `LIST`, read through `AdminPort` as the caller.
  - `/namespace/form` answers the rules and those database names; `/namespace/name` answers the taken check.
- `src/OcuPilot/Api/Router.cls` -- add `GET /namespace/form`, `GET /namespace/name`, `PUT /namespace/:id` and `POST /namespace` with thin wrappers -- following the device quartet's order.
- `src/OcuPilot/Api/Error.cls` -- add these codes, each with its reason:
  - `NAMESPACE.NAME.REQUIRED`: "Name the namespace."
  - `NAMESPACE.NAME.SHAPE`: "A namespace name starts with a letter or %, then letters, digits, _ or -, at most 64 characters."
  - `NAMESPACE.NAME.TAKEN`: "This instance already has a namespace with that name. Choose a different one."
  - `NAMESPACE.NAME.ABSENT`: "This instance has no namespace with that name."
  - `NAMESPACE.GLOBALS.REQUIRED` and `NAMESPACE.ROUTINES.REQUIRED`: "Choose a database."
  - `NAMESPACE.{GLOBALS,ROUTINES,TEMPGLOBALS}.ABSENT`: "No database on this instance has that name."
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - add `namespace` to `COVEREDTYPES` and the :788 chain, with permitted create and change fields `Globals, Routines, TempGlobals`;
  - add `OCUPILOTNAMESPACE` with its `REASON`, `Codes()` and `ReasonFor` line, evaluated for create, change and delete.
- `src/OcuPilot/Kernel/Proposal/Impact.cls`:
  - add kind `namespace-delete` for `osmgmt.namespaces.delete`;
  - part `boundApplications`: `WebAppList` rows whose `Namespace` equals the id, ignoring case (generalize `Guarded`'s match field);
  - part `databases`: the distinct `Globals`, `Routines` and `TempGlobals` of the fresh read.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- add `"osmgmt.namespaces.create": true`, `"osmgmt.namespaces.update": true` and `"osmgmt.namespaces.delete": false`.
- `ui/src/app/areas/os-management/namespace-actions.ts`, `namespace-form.page.ts`, `namespace-form.store.ts` (new, the device model):
  - Create on the list;
  - database fields are native selects from `/namespace/form`;
  - an edit shows the name read-only;
  - register in `DESCRIPTOR_PAGES`, and add actions and `reset()` in `app.ts`.
- `ui/src/app/shell/screen-action-handler.ts`:
  - add `NamespaceList` to `SCREEN_ACTION_DESCRIPTORS`, and `delete` to `IMPACT_ACTIONS`;
  - add its consequence to `DESTRUCTIVE_CONSEQUENCES`.
- `ui/src/app/core/impact.ts` -- add kind `namespace-delete` with parts `boundApplications` and `databases` and their phrases.
- `ui/src/app/core/scope.ts` and `app.ts` -- on a `namespace` change event with action created or deleted, the shell's namespace list re-reads -- the switcher offers a new namespace, and never a deleted one.
- `ui/src/app/core/shortcuts.ts` -- correct the comment's count of unbuilt rows (seven becomes six).
- `ui/src/app/core/strings.ts` (append, citing the EXPERIENCE row) and `EXPERIENCE.md`, in place, 993 lines:
  - `:164`: the third cell gains "Namespaces (Stage 2, Story 18.2); its editor opens the namespace's global, routine and package mapping lists".
  - `:173`: "namespace" joins the delete list.
  - `:378`, the literals:
    - "Namespaces"; "Globals database"; "Routines database"; "Temporary database"; "No namespaces on this instance."; "create a namespace"; "change this namespace";
    - the six prompts:
      - "Which databases does each namespace use for its globals and routines?"
      - "Which namespaces share a database?"
      - "What would deleting a namespace take with it?"
      - "Which database should a new namespace use for its globals?"
      - "What changes if this namespace reads its routines from another database?"
      - "Which web applications run in this namespace?"
    - The where-clause ends `[ADDED 2026-09-28 - Story 18.2]`.
  - `:479`: "Deleting this namespace also deletes its mappings and every web application that runs in it. Its databases stay. This cannot be undone."
  - `:481`: "OcuPilot or the instance itself runs in this namespace. It cannot be deleted, and its globals and routines databases cannot be changed."
  - `:577`:
    - "<n> web applications run in it and are deleted with it: <names>"
    - "1 web application runs in it and is deleted with it: <names>"
    - "no web application runs in it"
    - "which web applications run in it was not checked"
    - "it uses <n> databases, which stay: <names>"
    - "it uses 1 database, which stays: <names>"
- `ui/tools/screen-mirror.mjs` -- run `node tools/screen-mirror.mjs` to regenerate `screens.generated.ts`.

**Execution — Part B, mappings and copy (AC4-AC5):**

- `Kernel/EntityType.cls`, `Kernel/EntityRef.cls`, `ui/tools/screen-mirror.mjs` and the client mirror `ui/src/app/core/entity-ref.ts`:
  - add `global-mapping`, `routine-mapping` and `package-mapping`;
  - add rule `foldcase-firstpart`, which lower-cases only the part before the first `$Char(1)`, and give it to all three types;
  - the mirror implements the rule, or the build fails.
- `src/OcuPilot/Screen/Read.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`:
  - A parent-scoped admin `LIST` whose composite id's first part is named like its one criterion's `param` gets that criterion's value seeded onto every row under that part, before projection — the object read's seeding at :395-404, extended to a list.
  - Registry and mirror both refuse the part when it is absent from `read.fields` (AD-36 amendment below).
- `src/OcuPilot/Port/NamespacePort.cls` (new; extends `AdminPort`, on the `AuditPort` model):
  - On the three mapping endpoints, it splits a `$Char(1)` composite `name` into `namespace` and `name`. Anything but two non-empty parts answers 404 `PORT.NOTFOUND` with no vendor call.
  - On `Namespace.Namespace` `MAPPINGS`, it builds `{SourceNamespace, DestinationNamespace}` from the target id and `PortQuery`'s `source`, and sends no query.
  - It converts `PORT.TIMEOUT` on that pair to started (202).
  - `Snippet` and `SnippetForm` mirror every branch.
- `src/OcuPilot/Port/AdminPort.cls`:
  - add the mapping `PUT` and `DELETE` for all three endpoints, and `Namespace.Namespace/MAPPINGS`, to `MUTATINGTYPES`;
  - add the mapping `DELETE`s to `BODYLESSTYPES` and `VERIFIEDDELETES`;
  - add `Namespace.Namespace/MAPPINGS` to `QUEUEDWRITES`.
- `src/OcuPilot/Screen/Tool/`, nine new mapping tools, `osmgmt.{globalmappings,routinemappings,packagemappings}.{create,update,delete}`:
  - `PORTCLASS` is `NamespacePort`.
  - The agent's arguments are `Namespace`, `Name` and the fields. The id is `JoinComposite(Namespace, Name)`, in a mint class on the `ErrorDeleteMint` model; the screen sends the row key.
  - A delete is destructive.
  - Add six `Classification` entries: `Database` and `LockDatabase` ordinary, `Collation` ordinary. Then regenerate `ToolFields`.
- `src/OcuPilot/Screen/Tool/NamespaceCopyMappings.cls` (new) -- `osmgmt.namespaces.copymappings`:
  - AD-51 action; `PORTCLASS` `NamespacePort`; `READTYPE` `GET`; `WRITETYPE` `MAPPINGS`; `SENDSBODY` 0;
  - `SCREENACTIONS` `copy-mappings`, `SCREENVALUES` `copy-mappings=SourceNamespace`;
  - `FINGERPRINTSUBJECT` `Globals,Routines`;
  - `ArgumentProblem` refuses an absent or same source (`NAMESPACE.SOURCE.ABSENT` / `.SAME`);
  - `StateDiff` shows the source;
  - pairs as in Always.
- `src/OcuPilot/Screen/Descriptor/`, six new descriptors:
  - `GlobalMappingList`, `RoutineMappingList`, `PackageMappingList`:
    - lists at `os-management/namespaces/{global,routine,package}-mappings`, position 0, `parentScope` `os-management/namespaces`;
    - one criterion `{param:"namespace"}`; id composite `["namespace","Name"]`; `secondaryEntityTypes` `["namespace"]`;
    - fields: global `namespace, Name, Database, LockDatabase, Collation`; routine `namespace, Name, Type, Database`; package `namespace, Name, Database`;
    - columns: Name (`name`), then Database ("Database"), and for globals "Lock database" and "Collation", for routines Type; the `namespace` field is carried, not shown;
    - `emptyStateKey` "This namespace has no global mappings." (routine, package alike), `emptyAgentKey` "map a global" / "map routines" / "map a package";
    - primary `create`, row `delete`;
    - `classicPage` `%CSP.UI.Portal.Mappings.Global` / `.Routine` / `.Package`;
    - `toolIdentifier` `osmgmt.globalmappings` / `osmgmt.routinemappings` / `osmgmt.packagemappings`.
  - `GlobalMappingForm`, `RoutineMappingForm`, `PackageMappingForm`: `form-page` at `<list route>/edit`, the same id and classic page.
  - Each of the six has three prompts. `NamespaceList` gains row action `copy-mappings`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - cover the three types, with fields `Database, LockDatabase, Collation`;
  - add `OCUPILOTMAPPING`: mapping writes, and copy-mappings, whose source's three lists are read at the write and which fails closed on a cut list;
  - add effect `EFFECTSYSTEMGLOBAL` `MAPPING.SYSTEMGLOBAL` for a global-mapping create or change whose name begins with `%`. `Mint.cls:317-333` asks for it on a create too, for this type only.
- `src/OcuPilot/Area/OsMgmt/MappingRules.cls`, `MappingSave.cls`, `Api/Router.cls`, `Api/Error.cls`:
  - Routes: `GET /mappings/:kind/form`, `GET /mappings/:kind/name`, `PUT /mappings/:kind/:id`, `POST /mappings/:kind`, where `kind` is `global`, `routine` or `package`.
  - Codes and reasons:
    - `MAPPING.NAME.REQUIRED`: "Name what to map."
    - `MAPPING.NAME.SHAPE`: "The instance does not accept that name. A routine type suffix is written in capitals, as in _MAC."
    - `MAPPING.NAME.TAKEN`: "This namespace already has that mapping."
    - `MAPPING.NAME.SUBSCRIPTS`: "Delete this global's subscript-level mappings first."
    - `MAPPING.DATABASE.REQUIRED`: "Choose a database."
    - `MAPPING.{DATABASE,LOCKDATABASE}.ABSENT`: "No database on this instance has that name."
    - `MAPPING.COLLATION.VALUE`: "Collation is a whole number."
    - `NAMESPACE.SOURCE.ABSENT`: "This instance has no namespace with that name."
    - `NAMESPACE.SOURCE.SAME`: "Choose a namespace other than this one."
  - The vendor's refusal of a name (#5854, #448) maps to `MAPPING.NAME.SHAPE` through `PortViolations`.
- `Kernel/Governance/Baseline.cls` -- add nine mapping lines, all `true`, and `"osmgmt.namespaces.copymappings": true`.
- Client, Part B:
  - `ui/src/app/areas/os-management/mapping-actions.ts`, `mapping-form.page.ts`, `mapping-form.store.ts` (one page for all three form descriptors):
    - Create carries `?namespace=`, on the Wallet model.
    - The `%` line appears under Name while the name begins with `%`.
  - `copy-mappings-dialog.ts` (the `audit-copy-dialog` model):
    - a select of the other namespaces, taken from the Namespaces read;
    - the consequence line and Copy;
    - while the request runs, the running line; then the outcome, then Close.
  - `screen-action-handler.ts`:
    - a `copy-mappings` value action and pending kind for the dialog;
    - `SCOPED_TARGETS` for the three lists, asking for the mapping name;
    - `DESTRUCTIVE_CONSEQUENCES` for the three deletes.
  - `namespace-form.page.ts`: in edit mode, a "Mappings" line linking the three lists at `<route>/<encoded namespace>`.
- `strings.ts` and `EXPERIENCE.md`, in place:
  - `:173`: "global, routine and package mapping" joins the delete list, and "copy mappings (Story 18.2)" joins the dialogs.
  - `:378` gains:
    - "Global mappings"; "Routine mappings"; "Package mappings"; "Global mapping"; "Routine mapping"; "Package mapping"; "Lock database"; "Collation";
    - "This namespace has no global mappings."; "This namespace has no routine mappings."; "This namespace has no package mappings.";
    - "map a global"; "map routines"; "map a package"; "change this mapping";
    - "Copy mappings";
    - "Copies every mapping of the chosen namespace into this one. A mapping this namespace already has under the same name is replaced; its other mappings stay.";
    - "Copying mappings from <namespace> on the instance since <time>"; "Copied the mappings of <namespace>.";
    - "This maps a system global. Code in this namespace that uses it reads the mapped database instead of the system's own.";
    - 18 prompts, three per screen:
      - global list: "Which globals does this namespace read from another database?", "Is any system global mapped in this namespace?", "Which database holds this namespace's mapped globals?"
      - routine list: "Which routines does this namespace run from another database?", "Which routine mappings use a wildcard?", "Where do this namespace's mapped routines come from?"
      - package list: "Which packages does this namespace load from another database?", "Is any package here mapped to a database outside this namespace?", "Which database does this package load from here?"
      - global form: "What does mapping a global to another database change?", "When should a global mapping name a subscript range?", "What does a global mapping's lock database do?"
      - routine form: "What does mapping routines to another database change?", "How do I map only one routine type?", "Can a routine mapping use a wildcard?"
      - package form: "What does mapping a package to another database change?", "Does a package mapping include its subpackages?", "Which database should this package mapping name?"
  - `:479`:
    - "This namespace stops reading these globals from the mapped database and reads its default database again. No data is deleted. This cannot be undone."
    - "This namespace stops running these routines from the mapped database. The routines themselves stay. This cannot be undone."
    - "This namespace stops loading this package's classes from the mapped database. The classes themselves stay. This cannot be undone."
  - `:481`: "Mappings whose names begin with OcuPilot hold OcuPilot's own globals and code. They cannot be added, changed or removed in the namespace OcuPilot runs in, or in %ALL."

**Tests (both parts; stateful classes are armed under a new `OCUPILOT_ALLOW_NAMESPACE_CONFIG` block in `scripts/ci-throwaway.sh`):**

- `src/OcuPilot/Test/NamespaceProbe.cls` (new) -- the `DeviceProbe` model:
  - prefix `OCUPROBE182`, over the existing `USER` databases; it creates no database;
  - `RemoveAll` runs before all tests, after each test and after all tests, and a survivor fails the class;
  - it checks the CPF is still valid.
- `src/OcuPilot/Test/NamespaceWrite.cls` (new, Part A) -- one method per Part A matrix row, on both callers:
  - create, taken, bad name, unknown database, edit;
  - delete with two bound probe apps, which are both gone afterwards;
  - the impact parts, and the read-back.
  - Every leg aimed at the install namespace or `%SYS` runs through a recording port, so a removed predicate records a call instead of deleting (the `DeviceWriteGate` precedent).
- `src/OcuPilot/Test/NamespaceWriteGate.cls` (new, Part A) -- the `DeviceWriteGate` model:
  - the reader holds the two screen pairs;
  - the writer lacks `%DB_IRISSYS:WRITE`, and the deleter lacks `%Admin_Secure:USE`: each is refused 403 naming the pair, with zero port calls, and the namespace survives;
  - it also measures the form's `Database.ConfigCRUD` read with the reader (inference: the reader's pairs suffice). A pair the instance demands beyond these is added to the tool and recorded here.
- `src/OcuPilot/Test/MappingWrite.cls` and `Test/NamespaceCopy.cls` (new, Part B):
  - every Part B matrix row;
  - the seeded read, for rows and ids;
  - `NamespacePort`'s split;
  - `QUEUEDWRITES` admitting the copy;
  - the started path, through a port seam with a zero bound (the `AuditPort` test precedent).
- Rosters, re-derived from the code, never hand-counted:
  - `ReadTool`, `SurfaceCoverage` (one row per descriptor and tool), `EndpointCoverage` (eight routes);
  - `Descriptor` (`ReadShapes`, entity count, per-screen legs, the seeding rule), `EntityRef` (the new rule), `Prohibited`, `RefusalCopy`, `GovernanceBaseline` (the `false` set gains namespace delete);
  - `ToolWrite` and `PortFixture`, `AdminPortAsync`, `DraftRegistry`;
  - `Navigation`, `Wire`, `WireSecurityRead`, `ScreenGrounding`, `Envelope`;
  - client: `navigation.test.mjs`, `navigation-wire.test.mjs`, `rail-wire.spec.ts`, `self-protection.test.mjs` (`KERNEL_REFUSALS` gains `OCUPILOTNAMESPACE` and `OCUPILOTMAPPING`), `impact.test.mjs`, `screen-mirror.test.mjs`, `screen-action-handler.spec.ts`, `home.page.spec.ts`.
- Component specs: `namespace-form.page.spec.ts` and `.store.spec.ts`, `mapping-form.page.spec.ts` and `.store.spec.ts`, and `copy-mappings-dialog.spec.ts`, each on the device and typed-name host patterns.
- `ui/browser/namespaces.browser-spec.mjs` (Part A) and `ui/browser/namespace-mappings.browser-spec.mjs` (Part B):
  - model them on `device-editor.browser-spec.mjs`, with cleanup through `docker exec` by exact probe name;
  - AC1 or AC4, AC2 or AC5, and the AC6 DW-1337 helper in both themes;
  - the install-namespace leg only opens and cancels the Delete dialog.

**Acceptance Criteria:**

- **AC1:** Given a holder of the Namespaces pairs on `ocupilot-b-ci`, when they open OS management, then "Namespaces" is the sixth side-bar entry. It lists every namespace with its globals, routines and temporary databases — the rows `osmgmt.namespaces.read` answers, narrowed only by its cap.
  - When they create a namespace from Create, then it round-trips through `PUT /namespace`: 201, with the row present after the change event. A taken name is refused before any `PUT`.
  - When they change its routines database on its editor, then the Save sends the complete set.
  - The agent's confirmed `osmgmt.namespaces.create` and `.update` do the same, and the switcher then offers the new namespace.
- **AC2:** Given a probe namespace with two bound web applications, when Delete is chosen on its row, then before anything is removed the typed-name dialog's advisory lists both applications as deleted with it and its databases as staying. The agent's proposal carries the same impact.
  - After the typed name and Delete, the namespace, its mappings and both applications are gone, and every database remains.
  - Deleting OcuPilot's install namespace or `%SYS`, or changing its globals or routines database, is refused `PROHIBITED.OCUPILOTNAMESPACE` from either caller. The dialog states that reason when it opens.
- **AC3:** Given least-privileged principals on the throwaway, when they call the namespace tools, then:
  - the two screen pairs read the list and the form's database choices;
  - a write without `%DB_IRISSYS:WRITE`, and a delete without `%Admin_Secure:USE`, are each refused 403 naming that pair before any port call;
  - after the refused delete, the namespace still exists.
- **AC4:** Given a probe namespace, when its editor's Mappings links open its global, routine and package mapping lists, then each lists that kind's mappings — its read tool's rows, each row's id carrying the namespace.
  - Create, edit (from the name cell) and Delete (with the typed name) round-trip for both callers, and an edit sends the complete set.
  - A global mapping whose name begins with `%` is permitted at the strongest confirmation: the agent's card is destructive and states the system-global consequence, and the form states it under Name.
  - A mapping whose name begins with OcuPilot, in the install namespace or `%ALL`, is refused `PROHIBITED.OCUPILOTMAPPING`.
  - A base global delete while subscript mappings exist, and a lower-case routine type suffix, are refused on Name before any port call.
- **AC5:** Given two probe namespaces, when Copy mappings is chosen on the destination's row and a source is picked, then:
  - the dialog shows "Copying mappings from <source> on the instance since <time>" while the request runs, then "Copied the mappings of <source>.";
  - the destination holds the source's mappings, with its same-named ones replaced and its others kept;
  - the write took AdminPort's async path, admitted by `QUEUEDWRITES`, and the agent's confirmed `osmgmt.namespaces.copymappings` answers the same;
  - a copy still running past the port's bound is recorded applied and marked, and says "Still running on the instance. It finishes in the background.";
  - the matrix's three bad-source and own-namespace cases are refused before any task is queued.
- **AC6:** Given the new screens, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays below 3800 kB; if it passes `maximumWarning` (2106 kB), the warning is re-based under DW-1166 together with `angular-json.test.mjs`'s literal.

## Spec Change Log

- 2026-09-28, spec gate (runner): the orchestrator split the story (Rule 5, by=merge_gate): Part B, the mappings and copy-mappings (epic AC2 and AC3), moved to Story 18.14 with SA-13's enable-interop (DW-1776). The intent block above was cut to Part A and the spec set to `draft` for a re-plan of Part A only. The Part B research (payloads, amendments, tasks) stays in this file's history at commit `f473ce9b` for 18.14's plan. Also approved at the gate: namespace delete joins the baseline disabled.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27: the admin API through AdminPort, and `NamespacePort`, which extends it.
- AD-3: derived field lists.
- AD-4: an edit sends the complete set.
- AD-5, AD-36, AD-44: one descriptor per screen; the list and its tool read one read; each declares its classic page.
- AD-6, AD-34: proposal and confirm.
- AD-8: pairs, the extra pairs, removal impact.
- AD-10: the two new predicates.
- AD-13, AD-14: new types, rules and change events.
- AD-15: the agent marker.
- AD-16: `%SYS` reached only through the port.
- AD-21: no path field, so `PathPort` is not consumed.
- AD-22: baseline lines.
- AD-26: the queued copy.
- AD-29: the port gate.
- AD-39: violations.
- AD-51: the copy action.
- AD-52: the declared port.
- AD-53, AD-55: two callers of one tool.
- AD-54: creates.
- AD-58: read-back.
- AD-59: `Snippet`.

**Measured on `ocupilot-b-ci`, 2026-09-28** (the stage gate's observed payloads; every probe object was removed):

- **Namespace create and edit.** `PUT /namespace?name=N` with `{"Globals":"USER","Routines":"USER"}` answers 201 `{Globals, Routines, TempGlobals:"IRISTEMP"}`.
  - The create has no side effects: no web application, mapping or database is made.
  - `{}` gives 400 #40301, and `Library` gives 400 #40307.
  - An unknown database gives 500 #420. `.`, a leading digit, a space or `$` gives 500 #457. 65 characters gives #7201.
  - `_`, `-`, a leading `%` and lower case are accepted; lower case is stored in upper case.
  - A second `PUT` is 200, and fields the body omits are kept. The `PUT` is an upsert.
- **Namespace delete.** `DELETE /namespace?name=N` answers 200. It removes the namespace, its mappings and every web application bound to it. It never deletes a database, and it is never refused because an application references the namespace.
- **Mappings.** For each kind, `PUT …-mapping?namespace=&name=` answers 201 on create and 200 on edit, keeping omitted fields.
  - The global template is `{Database, LockDatabase, Collation}`; routine and package are `{Database}`.
  - `DELETE` answers 200, and 404 #421 when the mapping is absent.
  - Creating `G("a"):("m")` also creates `G` on the namespace's default database.
  - `DELETE G` while a subscript mapping exists gives 500 #451.
  - `%`-named globals and packages are accepted: the vendor has no guard, and neither does the classic page.
  - `X_mac` creates `X_MAC` and then answers 500.
- **Copy-mappings.** `POST /namespace/copy-mappings {"SourceNamespace","DestinationNamespace"}` answers 202 with a location.
  - The poll reads `{State, TaskName, Console, FailureReason, Result:{}, TimeQueued, TimeStarted, TimeFinished}`. There is no progress field; the task finished within 2 s.
  - The copy merges, and the source wins on a same name.
  - An absent source still gets 202, then `Failed` #420.
- **Pairs.** Reads need `%Admin_Manage:USE` and `%DB_IRISSYS:READ`.
  - Every write also needs `%DB_IRISSYS:WRITE`; without it, `<PROTECT>` and nothing changes.
  - Delete also needs `%Admin_Secure:USE`. Without it the answer is 500 **after** the namespace is deleted, and bound apps are orphaned.
  - Copy also needs `%Admin_Operate:USE` (the poll). The poll is owner-only.

**Decisions:**

- **Placement.** OS management, beside Databases, at `sideBarPosition` 6, since the positions 1-5 are taken. Mappings are unlisted lists reached from the namespace editor, because a list's name cell reaches its editor or one child list, never three (`data-table.ts:605-613`). They reach the agent by route and command box.
- **Delete wizard.** It is the typed-name dialog with AD-8's impact advisory, as the classic `Dialog.NamespaceDelete` is one dialog. A stepper would offer no choice, because the vendor always deletes bound applications and never deletes databases. Deleting the databases too is 18.3's delete, not chained here.
- **The `%`-global guard.** The harvested rule (execute-mcp `Config.cls:557-560`) refuses a base `%`-global create unless `force=true`. Under the owner's 2026-09-23 direction to permit powerful actions behind confirmation, `force` becomes AD-10's strongest confirmation, the privilege-grant idiom. No request field bypasses anything.
  - Coverage widens from base names to every `%` name, because the vendor creates the base mapping for a subscript (measured for a non-`%` global; for `%` it is inference).
  - Edit is covered too; the sibling has no edit.
  - If the owner wants a ban instead, it becomes a third kernel predicate.
- **Mapping identity.** The vendor rows carry no namespace, and the mint's fresh read sends one id parameter, so the id is the composite `[namespace, Name]`. The read seeds the namespace, and `NamespacePort` splits the id on `$Char(1)`. `SPLITQUERIES` splits on `/`, which a global subscript can contain.
- **Governance.** Namespace delete joins as `false`, per the preamble. Mapping deletes join as `true`: a mapping delete is reversible by re-creating it, and it deletes no data. Copy joins as `true`: it merges and removes nothing. Both keep the destructive or strongest-confirmation treatment.
- **Not in this story, for the runner to confirm with the owner (Rule 5, ask first):**
  - SA-13's `POST /namespace/enable-interop`: an async queued write whose payload this plan did not observe, because it writes interoperability code into the namespace's databases and needs a probe database. Recommended: the split-off Part B story, or 18.12.
  - SA-13's inline create-database: this is 18.3's wizard. 18.3 adds the step to `NamespaceForm`.
  - SA-13's create web app: the API makes none; Web applications' own Create does.
  - SA-15's optional database delete: 18.3.

**Recommended split (for the runner to take to the owner; nothing is dropped).** Keep Part A (AC1-AC3 with AC6) as Story 18.2, and make Part B (AC4, AC5 with AC6) its own story after it, e.g. "Namespace mappings and copy-mappings".

- Part A is 3 write tools, 2 screens, one impact kind and one predicate.
- Part B is 10 write tools, 6 screens, a read-contract extension, an id rule, a new port and a queued write.
- Together they are about four times 18.1's surface, and 18.1 was already `oversized`.
- If the story stays whole, implement Part A, then Part B, each part's verification green before the next.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate):**

- **AD-8, after the device case in its first clause:** "Story 18.2's cases [AMENDED 2026-09-28, Story 18.2 spec gate, Rule 20]: the namespace and mapping tools declare `%DB_IRISSYS:WRITE`, since `Config.Namespaces` and `Config.Map*` write `^SYS("CONFIG",…)` in the system database, and a principal holding only the screens' `%Admin_Manage:USE` and `%DB_IRISSYS:READ` was answered `<PROTECT>` on every write (measured on `ocupilot-b-ci`, 2026-09-28). `osmgmt.namespaces.delete` also declares `%Admin_Secure:USE`, because the vendor's delete removes every web application bound to the namespace through `Security.Applications`, and a caller without that pair was answered 500 after the namespace was already deleted, its applications left behind."
- **AD-8, second clause:** "The third: `osmgmt.namespaces.copymappings` declares `%Admin_Operate:USE`, the `AsyncResult` gate the port polls the queued `Namespace.Namespace` `MAPPINGS` through (Story 18.2)."
- **AD-10, a new bullet:** "**OcuPilot's install namespace and its mappings** [AMENDED 2026-09-28, Story 18.2 spec gate, Rule 20]: deleting, or changing the `Globals` or `Routines` database of, the namespace OcuPilot's own API application runs in, or `%SYS`, is refused `PROHIBITED.OCUPILOTNAMESPACE`. The vendor's delete removes every web application bound to the namespace (measured), and the routines database is the code that answers OcuPilot's addresses and the routine its privileged applications pin (AD-9). Creating, changing or deleting, in that namespace or in `%ALL`, a global, routine or package mapping whose name begins with `OcuPilot`, ignoring case, and a copy of mappings into either namespace that would carry one, is refused `PROHIBITED.OCUPILOTMAPPING`: such a mapping moves OcuPilot's protected globals out of its database (AD-9) or lets other code answer for its classes. It is the same serving-path self-protection family."
- **AD-26, the `QUEUEDWRITES` paragraph:** "…and `Namespace.Namespace` `MAPPINGS` (Story 18.2, copy-mappings, `{SourceNamespace, DestinationNamespace}`, no secret) [AMENDED 2026-09-28, Story 18.2 spec gate, Rule 20]."
- **AD-36:** "**A parent-scoped list may carry its parent's key on its rows** [AMENDED 2026-09-28, Story 18.2 spec gate, Rule 20]: where the vendor's list answers rows without the parent's key (a namespace's mapping lists), the read seeds its one criterion's value onto each row under the composite id's first part, which is named like the criterion, before projection — the single-object `GET`'s seeding of its route id, applied to a list — so the row's id carries the namespace its write addresses."
- **AD-51, the port-built body list:** "…and `NamespacePort`, which builds `Namespace.Namespace` `MAPPINGS`'s body from the destination (the target) and the tool's declared `SourceNamespace` (Story 18.2) [AMENDED 2026-09-28, Story 18.2 spec gate, Rule 20]."

**Vendor defect candidates, for the runner to ledger:**

1. A namespace delete without `%Admin_Secure` answers 500 after deleting, and orphans the bound applications.
2. `maxRows` on a namespace `DELETE` limits how many bound applications are deleted.
3. A routine mapping with a lower-case type suffix is created, then answers 500.
4. Client-input errors answer 500 (#420, #457, #448, #451, #5854, `<SUBSCRIPT>`).
5. The v2 async `Location` header points at `/v1/async-result`.
6. Copy-mappings does no pre-check (202, then `Failed`).
7. A mapping list for an absent namespace answers 200 `[]`.
8. A subscript mapping's list row shows collation 0, and its `GET` shows 5.

Known defects DW-1527 and DW-1640 do not bear on this story.

**Integration ACs:**

- AC1 and AC4: each list and its read tool read one read, and the Integration matrix row covers them.
- AC4: the mapping tools consume the seeded rows' ids through `NamespacePort`.
- AC2: the impact consumes `WebAppList`'s read.

**Consumed-by:**

- 18.3: the database delete's impact reads `NamespaceList`'s `Globals`, `Routines` and `TempGlobals`, and its create wizard adds an inline step to `NamespaceForm`.
- 18.12: the agent's grown tool set.
- 18.13: multi-namespace install, which the install-namespace predicate must keep holding.

**Consumes:**

- `AdminPort` (`Namespace.*`, `Database.ConfigCRUD` `LIST`).
- `WebAppList`'s read.
- 16.19's impact.
- 16.17's read-back.
- 14.1's `Snippet`.
- The typed-name dialog.
- `ScopeService`.

**Ledger:** no entries are owned (the inbox was empty).

- DW-1774 is addressed by the roster tasks above.
- DW-1770 is not relied on, because no path is taken.

**Contended with Epic 16, all edited add-only:** `Error.cls`, `Router.cls`, `Baseline.cls`, `strings.ts`, EXPERIENCE.md, the rosters, `ci-throwaway.sh` and `ci.test.mjs`, and `screens.generated.ts` (regenerated).

**Not touched:** `Area.cls` (OS management already covers the pairs); `scripts/check-objectscript.py`.

## Verification

**Setup (slot B):**

- Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`. Namespace and mapping writes happen there only, on `OCUPROBE182*` objects.
- Run one test class per call.
- Before any browser run, run `cd ui && npm run build`, then `docker cp ui/dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` set.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time:
  - Part A: `NamespaceWrite`, `NamespaceWriteGate`, `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Prohibited`, `RefusalCopy`, `GovernanceBaseline`, `ToolWrite`, `DraftRegistry`, `EntityRef`, `Navigation`, `Wire`, `WireSecurityRead`, `ScreenGrounding`, `Envelope`.
  - Part B adds: `MappingWrite`, `NamespaceCopy`, `AdminPortAsync`.
  - Expected: 0 failures each, with totals checked against `%UnitTest_Result`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/namespaces.browser-spec.mjs`, and in Part B `browser/namespace-mappings.browser-spec.mjs`, then `browser/impact.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>`, then `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 993.
- `(once, before dev_complete)`:
  - the full ObjectScript sweep on `ocupilot-b-ci`, one class per call;
  - `cd ui && npm test && npm run build`;
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
  - Expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line. The predicate mutations run only against the recording port.

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC1 | The create drops the absence fingerprint | `NamespaceWrite`'s taken leg (upsert) |
| AC1 | `NamespaceList` takes `sideBarPosition` 0 | `navigation.test.mjs`; the browser spec's side-bar leg |
| AC2 | `KindOf` omits `namespace-delete` | `NamespaceWrite`'s impact leg; the browser dialog advisory |
| AC2 | The `OCUPILOTNAMESPACE` arm is removed | `NamespaceWrite` (the recording port records a call) |
| AC3 | `%Admin_Secure:USE` is dropped from the delete's pairs | `NamespaceWriteGate` (the port is called) |
| AC4 | The read seeds no namespace | `Descriptor`'s seeding leg; `MappingWrite`'s id leg |
| AC4 | `EFFECTSYSTEMGLOBAL` is never answered | `MappingWrite`'s `%` leg (the card is not destructive) |
| AC4 | The `OCUPILOTMAPPING` arm is removed | `MappingWrite` (recording port) |
| AC5 | `MAPPINGS` is removed from `QUEUEDWRITES` | `NamespaceCopy` (refused); `AdminPortAsync` |
| AC5 | The started conversion is removed | `NamespaceCopy`'s zero-bound leg |
| AC6 | A header label is drawn in `--ocu-surface` | The DW-1337 legs in both themes |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only. Part A (namespaces) and Part B (mappings and copy) are specified together. Design Notes recommends splitting Part B out and lists five spine amendments for the runner to write at the spec gate.
