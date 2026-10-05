---
title: 'Story 19.17: The DocDB browser'
type: 'feature'
created: '2026-10-05'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-9-documatic-and-docdb.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer covers code and SQL but not the instance's document databases. The vendor reaches them only through `/api/docdb`, which OcuPilot never calls (AD-1), and the in-process `%SYSTEM.DocDB` checks neither the DocDB service nor `%DocDB_Admin`.

**Approach:** Add a Document databases screen to System Explorer. It lists the databases of the route's namespace, creates one from a name and drops one, through a new port `Port/DocDbPort`. The port calls `%SYSTEM.DocDB` in process as the signed-in user, after repeating the vendor's gate. When the service is disabled, the read and both writes refuse 409 `DOCDB.SERVICE.DISABLED`, and the screen and the agent both say so. The agent gets `explorer.docdb.read`, plus two confirmed writes: `explorer.docdb.create` (key `true`) and `explorer.docdb.delete` (destructive, key `false`).

## Boundaries & Constraints

**Always:**

- **The port's gate (AD-29), in this order, before any vendor call:**
  1. `%Development:USE`, `%DocDB_Admin:USE` and `%Service_DocDB:USE`, through `Screen.Gate.EvaluateRequired`. A refusal is 403 naming the failed pair.
  2. The namespace: the query's namespace, which defaults to `Kernel.Scope.Current()`, with its shape checked.
  3. The namespace's pairs. A read requires `AtelierPort.NamespacePairs(ns)`. A create or drop requires `AtelierPort.WritePairs(ns)` plus WRITE on the namespace's globals-database resource, taken from `AtelierPort.DatabaseResources`. Each pair counts once.
  4. The name's rules, for a typed call.
  5. The service: `$$CheckServiceStatus^%SYS.DOCDB(name, ns)`. Any answer other than 1 is 409 `DOCDB.SERVICE.DISABLED`.
  6. Only then the vendor call. It runs in the target namespace, switched by explicit save and restore (AD-16). The restore is the first line of every `Catch`, and no `OcuPilot.*` class is called while switched.
- **The port's types:**

  | Type | Answers |
  |---|---|
  | `LIST` (endpoint `Databases`) | rows `{Name, Class, DocumentType, Resource}` from `GetAllDatabases()` and one `GetDatabase` per surviving name, cut at the query's `maxRows` |
  | `DATABASE` | one database's row plus `Namespace`; an absent name is 404 `PORT.NOTFOUND`, unlogged |
  | `CREATE` | `CreateDatabase(Name)`, no document type and no resource |
  | `DROP` | `DropDatabase(name)`; an answer of 0 is 404 `PORT.NOTFOUND` |

- **Name rules** (measured, Design Notes):
  - The name must match `^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$`.
  - Its class name must be at most 220 characters. `ClassNameOf(name)` is the name itself when it is qualified, and `ISC.DM.<name>` otherwise.
  - A name that fails either rule is refused 422 `DOCDB.NAME.INVALID`, on `Name`.
  - A name is also refused 422 `DOCDB.NAME.MAPPED`, on `Name`, when the namespace keeps the class's package in another database (`%SYS.Namespace.GetPackageDest` differs from `GetRoutineDest`).
- **Vendor answers map, never sent (AD-39):**
  - #25051 → 409 `DOCDB.NAME.TAKEN`.
  - #25070 → 409 `DOCDB.CLASS.TAKEN`. CREATE also refuses this before the vendor call, when `%Dictionary.ClassDefinition` holds `ClassNameOf(Name)`.
  - #25053 → 422 `DOCDB.NAME.INVALID`.
  - `<PROTECT>`, #5883 → 403 `PORT.ACCESSDENIED`.
  - Anything else → 500 `INTERNAL`, logged.
- **Entity type `docdb-database`, rule `foldcase`** (AD-13): the instance resolves names in any case.
  - A create sends the name exactly as typed. Its composed payload is `{Name, Namespace}`, the namespace the mint read in, and `PortQuery` carries it, as in `ExplorerWrite`.
  - A drop's fresh read answers the stored `Name` and `Namespace`.
- **The tools:**
  - **Create** `explorer.docdb.create`: `CREATES` 1, absence fingerprint (AD-54), `READBACKFIELDS` `Name`, `CHANGEACTION` `created`, reached by the screen through an AD-55 Save route.
  - **Delete** `explorer.docdb.delete`: action-style (AD-51), `READTYPE` `DATABASE`, `FINGERPRINTSUBJECT` `Name,Class,Namespace`, `DESTRUCTIVE` 1, `SCREENACTIONS` `delete`, `CHANGEACTION` `deleted`.
  - **Both:** advertised, `PORTCLASS` DocDbPort, `IdArgument` `Name`. Pairs: the screen's set plus WRITE on the routines- and globals-database resources of `Scope.Current()`, each once, as `ExplorerWrite.PrivilegePairs` does.
- **Self-protection (AD-10):** a create or drop whose `ClassNameOf` begins with `OcuPilot` in any case is refused `PROHIBITED.OCUPILOTCODE`, from either caller. The check is the kernel's `Code`, run through a `docdb-database` arm.
- **Strings:** every new sentence lives once, in `strings.ts`, in EXPERIENCE.md's Fixed strings and, for a refusal, in `DocDbError.cls`, pinned equal by `self-protection.test.mjs`.
- **Styling:** `--ocu-*` tokens only. The DW-1337 structural gate holds in both themes.

**Never:**

- An HTTP call to `/api/docdb`, or naming any `%Api.DocDB*` class.
- Enabling `%Service_DocDB` anywhere but a throwaway, and only through an armed fixture that restores it.
- Repeating the vendor's `CheckAccess "W"` on a drop (DW-2084).
- A `type` or `resource` argument on create, or any write to `Security.DocDBs`.
- Documents, find, properties or indexes (DT-01's other rows).
- A new code in `Api/Error.cls`.
- A classic link.
- An edit to `DESTRUCTIVE_ACTIONS`, `data-table.ts` or `list-page.ts`.
- `ToolFields`, `FieldLists` or `Classification` entries.

## I/O & Edge-Case Matrix

Measured on `ocupilot-a2-ci` in USER (Design Notes › Measured).

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | service enabled; `OcuProbe1917A`, `OcuProbe1917.Q` | rows `OcuProbe1917A` / `ISC.DM.OcuProbe1917A` / `""` / `""`, and `OcuProbe1917.Q` / `OcuProbe1917.Q`; the tool answers the same rows | None |
| Service disabled | stock state | 409 `DOCDB.SERVICE.DISABLED` on read, create and drop; no `%SYSTEM.DocDB` call; one vendor `AccessDenied` audit row each; the screen shows the sentence | Strip on screen; tool result carries the reason |
| Pair missing | principal without `%DocDB_Admin:USE` (or `%Service_DocDB:USE`, or the namespace's READ, or the write pairs) | 403 naming that pair; no service check, so no audit row | Refusal as today |
| Create | `OcuProbe1917A` from the dialog | 201, class `ISC.DM.OcuProbe1917A` exists, row shown, `readBack` reads `matches` | None |
| Case variant | `ocuprobe1917a` while `OcuProbe1917A` exists | agent: mint refused (present); Save: 409 `DOCDB.NAME.TAKEN`; nothing created | Reason on the dialog |
| Bad names | `a_b`, `1x`, `x.`, `%X`, a 214-character unqualified name | Save: 422 `DOCDB.NAME.INVALID` on `Name`; agent: mint refused with the rule's text; no vendor call | Field violation |
| Mapped package | `Ens.OcuProbe` in USER | Save: 422 `DOCDB.NAME.MAPPED` on `Name`; agent: mint refused by the fresh read's 422 | Field violation |
| Class taken | `ISC.DM.OcuProbe1917A` while `OcuProbe1917A` exists | 409 `DOCDB.CLASS.TAKEN`, nothing created | Reason on the dialog |
| Own code | create `OcuPilot.X` or `ocupilot.y`; drop a database whose class is `OcuPilot.*` | `PROHIBITED.OCUPILOTCODE`, nothing written | Kernel sentence |
| Drop | `OCUPROBE1917A` (typed-name dialog, or the agent's confirmed proposal) | the one database dropped: class, data global and row gone; `readBack` gone; target ref `ocuprobe1917a` | None |
| Governance | agent proposes a drop; baseline `explorer.docdb.delete` `false` | refused at dispatch (structured result); the screen's Drop still works | AD-22 |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` or `ui/` unless they are given in full. Line numbers were read at HEAD `35252b82`.

- **Read path:**
  - `Screen/Read.cls`: `SOURCE*` parameters :154-251 with their seams (`AtelierPortClass` :243, `EncryptionPortClass` :255); `Execute` :338; port allow-list :358.
    - Atelier dispatch :443-458 is the template: `tQuery("namespace")=Kernel.Scope.Current()` :453.
    - Encryption dispatch :459-472; answer :626-635; truncation :601.
  - `Api/ScreenRead.cls` `Handle` :46-86 passes a port fault's code and detail to `Api.Error.Render` (:1840).
  - `Screen/Registry.cls` `ReadProblem` :1112:
    - source keys :1139, port allow-list and its "nine sources" sentence :1142-1143;
    - path and background per-port rules :1169-1208, the model for docdb's;
    - criteria ports :1551-1552 (docdb is not added: it has no criteria);
    - `OwnPrivilegesProblem` :791, `AreaCoverageProblem` :847, `PROMPTGROUPKEYS` :2839.
  - `tools/screen-mirror.mjs`: `SOURCE_*` :933-947, `READ_SOURCE_PORTS` :948, `readProblem` :1192 (allow-list :1210, sentence :1212-1214, path :1239, background :1257); generated union :3338.
- **Ports:**
  - `Port/AtelierPort.cls`: `PAIRS` :75, `DatabaseResources` :677, `NamespacePairs` :725, `WritePairs` :746; `Invoke` :830 (gate :840, namespace :847-861); `Deny` :3107, `Refuse` :3115, `SnippetForm` :3136, `Snippet` :3158.
  - `Port/EncryptionPort.cls` `Absent` :532-537 is the 404 `PORT.NOTFOUND` idiom.
  - `Kernel/Scope.cls` `Current` :36.
  - `Screen/Gate.cls` requires every pair (:261-292); no pair set expresses an OR.
- **Tools:**
  - `Screen/Tool/Write.cls` parameters: `DESCRIPTORCLASS` :38, `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CHANGEACTION` :134, `CREATES` :151, `SCREENACTIONS` :167, `READANSWERS` :180.
  - `Screen/Tool/Write.cls` methods: `ComposeCreate` :337, `PortQuery` :440, `SettableFields` :536, `IdArgument` :543, `IdParam` :550, `ArgumentProblem` :877.
  - `Screen/Tool/ExplorerWrite.cls` is the template for the namespace in the payload (`PortQuery`), the per-namespace WRITE pair (`PrivilegePairs`) and the `InputSchema` description.
  - `ExplorerDelete.cls` is the destructive action-style template (`StateDiff` :37, `ReadBackGone` :53).
  - `LanguageServerCreate.cls` and `LanguageServerDelete.cls` give the one-name shape.
- **Kernel:**
  - `Kernel/Proposal/Mint.cls`: create path :164-196, absence fingerprint :259-268 (`AbsenceState` :671-676); `Confirm.cls` :705-717.
  - `Kernel/Proposal/ReadBack.cls`: `KindOf` :206; `Compared` :246 reads only the `ToolFields` rows (`Rows` :511), so today a create with no such row reads `unchecked`.
  - `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250; type parameters through :473; `Prohibits` :1094 (uncovered :1101, condition :1105); class arm :1131-1144; `Code` :2060; `IsOcuPilotCode` :2184.
  - `Kernel/EntityType.cls` `TYPES` :77; `Kernel/EntityRef.cls` `IDRULES` :59 (`foldcase` :83).
  - `Kernel/Governance/Baseline.cls`: the explorer keys are :167-178.
- **Save route:**
  - `Area/OsMgmt/LanguageServerSave.cls`: `HandleCreate` :56 and `Create` :118 (gate, rules, prohibited, `ComposeCreate`, send, `ReadBack.ForSave`).
  - `Api/Router.cls`: the explorer routes :235-243 and thin wrappers such as `ExplorerSqlData` :1786.
- **Errors:**
  - `Api/AtelierError.cls` is the structure: `CODE` and `REASONCODE` pairs, with status and slug in the doc comment.
  - `Api/EncryptionError.cls` `ReasonFor` :98.
  - `Api/Error.cls` `CONFLICT` :35; the `ReasonForToolCode` prefix lines :1224-1227. It holds 989 parameters, so add none.
- **Descriptors:**
  - `Screen/Area.cls:80` gives system-explorer `%Development:USE`.
  - `Screen/Descriptor/LicenseServerList.cls` is the list + create + delete shape.
  - `ExplorerClassList.cls` gives scope `namespace` and the prompt group `webAppPromptGroupCode`.
  - `ExplorerSearch.cls:16-17,49` is the `classicPage ""` wording.
- **Client:**
  - `src/app/shell/list-page.ts`: `refusalText` is a row action's only. `data-table.ts:232-236` draws a read refusal as "request refused" with no reason.
  - The read's fault is `RefreshService.fault()` / `.descriptor()` (`core/fault.ts` `Fault.code` :54).
  - Wrapper and dialog templates:
    - `areas/permissions/resource-list.page.ts`: `<app-list-page />` plus a dialog;
    - `areas/os-management/namespace-list.page.ts:131-140`: a page registering its actions;
    - `areas/os-management/copy-mappings-dialog.ts`: a 105-line one-field dialog.
  - `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :145-242 (Explorer :224-241).
  - `shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :64-108; `DESTRUCTIVE_ACTIONS` :379 already holds `delete`; `DESTRUCTIVE_CONSEQUENCES` :407-445 (without an entry no Delete is drawn); `TYPED_NAME_ROWS` defaults to the row key (:994-1006).
  - `core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS` :151-239.
  - `core/strings.ts`: last key :5646, `} as const` :5647.
- **Budgets:**
  - `tools/strings.test.mjs:585-588` caps Fixed strings at 2,700, with 2,607 used (measured by the test's extractor). `:820-865` pins every `EXPERIENCE.md:n` citation.
  - `angular.json:54` sets 2910kB (`:55` 4000kB); pinned at `tools/angular-json.test.mjs:511`.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`): side-bar line :159; closed dialog set :173; last Fixed-strings row :601.
- **Test templates:**
  - `Test/AtelierPort.cls:317-365` pins a vendor routine (`findmappings^%R`).
  - `Test/ServiceEdit.cls:22-97` arms and snapshots a service and restores it.
  - `Test/EncryptionProbe.cls` makes principals: `:27-32`, `SeedPrincipal` :218, `RemoveAll` :247.
  - `Test/AtelierPortWriteDenial.cls` `EnsurePrincipals` :276.
  - `scripts/ci-throwaway.sh` `OCUPILOT_ALLOW_SERVICE_CONFIG` block :421-431; PRINCIPALS :330.
  - Browser:
    - `browser/license-servers.browser-spec.mjs`: create :274, row menu :131-151, delete :154-166, typed confirm :310-312, structure :192-221;
    - `browser/system-explorer-sql.browser-spec.mjs`: `runIris` probe :32, :63, :71;
    - `browser/developer-floor.browser-spec.mjs`: refuses the live container :58-81.
- **Rosters a change trips** (`Test/` unless shown):
  - `ExplorerDescriptor`: `DESCRIPTORS` :21 and its count word :18; the side-bar order :41. The atelier-only loop :56-73 must not take the docdb screen. The area test :140-170 and its count words.
  - `ReadTool` :93-94 (266 → 269). `ToolRoundTrip` `REFUSEEMPTY` :72. `SurfaceCoverage`: a screen row after :178, tool rows after :331.
  - `Descriptor`: a ReadShapes row before :171; EntityType count :1745.
  - `DeveloperFloor` :9, :34, :37, :43, :460-483, as its derivation answers.
  - `DeveloperFloorRoutes` `Roster()` :85-93, only if the developer passes the new route. `EndpointCoverage`: a probe after :255.
  - `GovernanceBaseline` `DISABLED` :15. `Governance` `EXPLORERDISABLED` :33.
  - `DraftRegistry` :135-158, :227. `ToolEmit`: a branch near :200-235. `ToolWrite` `tOtherPorts` :1339 (13 → 15).
  - `Prohibited` `CoveredTypes` :232. `PortGate` `ROSTER` :29 and a leg before :241. `AdminPairCorpus` :58.
  - `tools/screen-mirror.test.mjs`: `READ_SOURCE_PORTS` :2691, a per-source test near :2757, the ownPrivileges roster :2337-2365.
  - `tools/navigation.test.mjs`: after :314. `tools/self-protection.test.mjs`: a `DOCDB_SENTENCES` array after :698. `tools/ci.test.mjs` DW-1276 `# classes:` lines.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Api/DocDbError.cls` (new):
  - The codes, with the sentences in Design Notes › Strings: `DOCDB.SERVICE.DISABLED` 409 `conflict`, `DOCDB.NAME.INVALID` and `DOCDB.NAME.MAPPED` 422 validation on `Name`, `DOCDB.NAME.TAKEN` and `DOCDB.CLASS.TAKEN` 409.
  - `ReasonFor(code)`, plus one `DOCDB.` prefix line in `Api/Error.cls` `ReasonForToolCode` (:1224-1227), so a tool result carries the sentence.
- [ ] `src/OcuPilot/Port/DocDbPort.cls` (new): implement the Boundaries' gate, types, name rules and mappings.
  - Expose `PAIRS`, `NAMESPACEKEY`, `NAMEKEY`, a pure `ClassNameOf`, `NameProblem`, and `WritePairs(ns)`.
  - Define `Snippet` and `SnippetForm` beside `Invoke` (AD-59). They render `%SYSTEM.DocDB` `CreateDatabase` / `DropDatabase` in the namespace, and nothing for `LIST` or `DATABASE`.
  - Doc comments name the vendor routine it calls and the audit row a disabled service costs.
- [ ] `src/OcuPilot/Screen/Read.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`: add the `docdb` source kind.
  - `Read.cls`: `SOURCEDOCDB` and a `DocDbPortClass` seam; the allow-list :358; a dispatch branch after :472 that seeds `maxRows` (cap+1) and the namespace, as atelier does.
  - Registry and mirror, alike: endpoint `Databases`, type `LIST`, and no `rowGet`, `forEach`, `query`, `parts`, `rows` or criteria. The allow-list sentence becomes "ten sources".
  - Regenerate `ui/src/app/core/screens.generated.ts`.
- [ ] `src/OcuPilot/Kernel/EntityType.cls`, `Kernel/EntityRef.cls`: add `docdb-database` with its doc line, and `docdb-database:foldcase`.
- [ ] `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: add `TYPEDOCDBDATABASE` and cover it at :250 and :1105, plus an arm beside :1134, ahead of `Target`, that answers `..Code(DocDbPort.ClassNameOf(<name>))` and returns without reaching `Target` or `Created`. `<name>` is the payload's `Name` for a create and the target id for a drop.
- [ ] `src/OcuPilot/Screen/Tool/Write.cls`, `Kernel/Proposal/ReadBack.cls`: add `Parameter READBACKFIELDS` (default `""`).
  - `Compared` consults it only when `Rows` finds no `ToolFields` entry, treating each name as an ordinary field under the default rules.
  - Every existing tool is unchanged.
- [ ] `src/OcuPilot/Screen/Descriptor/ExplorerDocDbList.cls` (new):
  - route `system-explorer/docdb`; area `system-explorer`; `sideBarPosition` 12; archetype `list`; scope `namespace`; entity `docdb-database`.
  - privileges `%Development:USE`, `%DocDB_Admin:USE`, `%Service_DocDB:USE`; `ownPrivileges` the last two.
  - `primaryAction` `create`; `rowActions` `[delete]`, no self-protection rule.
  - read source `{port: docdb, endpoint: Databases, type: LIST}`; fields, filter and sort `Name, Class, DocumentType, Resource`, default `Name` ascending; paging `cap`.
  - table columns Name (`name`), Class, Document type and Resource (`identifier`); context fields as the read.
  - three prompts, group `webAppPromptGroupCode`; aliases `document databases`, `docdb`, `create document database`.
  - `classicPage ""` with the reason in the doc comment; `toolIdentifier` `explorer.docdb`.
- [ ] `src/OcuPilot/Screen/Tool/ExplorerDocDbWrite.cls` (abstract), `ExplorerDocDbCreate.cls`, `ExplorerDocDbDelete.cls` (new): the Boundaries' tool parameters.
  - `PrivilegePairs`: the descriptor's set plus WRITE on the routines- and globals-database resources of `Scope.Current()` (`AtelierPort.DatabaseResources`), each once.
  - `PortQuery` carries the payload's `Namespace`. `ArgumentProblem` returns `NameProblem`.
  - `SettableFields` is `Name` for the create and empty for the delete.
  - `InputSchema`: `Name`, described with the name rules and the `ISC.DM` mapping.
  - The create's `ComposeCreate` adds `Namespace` to the payload but no diff row. The delete's `StateDiff` shows `Name` and `Class`.
- [ ] `src/OcuPilot/Area/Explorer/DocDbSave.cls` (new) plus `Api/Router.cls`: the route `POST /explorer/docdb` (`ExplorerDocDbCreate`, after :243), modeled on `LanguageServerSave.HandleCreate`.
  - It runs: the tool's pairs, the name rules (422 violation), `Prohibited`, `ComposeCreate`, the port `CREATE`, and `ReadBack.ForSave`.
  - It answers 201 `{name, readBack}`.
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls`: after :178, add `"explorer.docdb.create": true` and `"explorer.docdb.delete": false`.
- [ ] `src/OcuPilot/Test/DocDbProbe.cls` (fixture, new). Every method refuses unless `OCUPILOT_ALLOW_SERVICE_CONFIG` reads 1. Every armed class below declares its variables as `ServiceEdit.cls:22-25` does.
  - `EnableService` returns the prior `Enabled`; `RestoreService(prior)` reads the value back.
  - `Make(ns, name)`, `RemoveAll(ns)` (every `OcuProbe1917*` database and class, verified), and `DeniedCount()` (`%IGNOREINDEX` over `%SYS.Audit` `AccessDenied`).
- [ ] `src/OcuPilot/Test/DocDbDescriptor.cls` (new, unarmed): the registry and mirror refusals for the docdb source, the descriptor and tool shapes, `ClassNameOf`, `NameProblem`'s matrix and the Snippet forms.
- [ ] `src/OcuPilot/Test/DocDbPort.cls` (new, armed SERVICE_CONFIG): the matrix's port rows.
  - Disabled: 409, no vendor call, one audit row.
  - The `CheckServiceStatus` signature pin: 1 enabled, 822 disabled.
  - List, case-variant drop, class taken, mapped, invalid, drop absent → 404.
  - The service is restored after every method.
- [ ] `src/OcuPilot/Test/DocDbGate.cls` (new, armed PRINCIPALS and SERVICE_CONFIG): purpose-built principals, each missing one pair, are refused naming it with no audit row; an exact holder lists, creates and drops in USER; an `%Admin_Secure:USE`-only holder is refused naming `%DocDB_Admin:USE`.
- [ ] `src/OcuPilot/Test/DocDbWrite.cls` (new, armed SERVICE_CONFIG): both callers.
  - The Save route (201 with `readBack` `matches`; 422; 409).
  - The agent's create and delete mint and confirm (the absence fingerprint refuses a name taken since the mint), and the screen's delete action.
  - `PROHIBITED.OCUPILOTCODE` both ways, the governance keys, and the copy-out draft.
- [ ] `scripts/ci-throwaway.sh`: add-only comment and `# classes:` lines naming the DocDb classes, under SERVICE_CONFIG (before :431) and PRINCIPALS (near :330).
- [ ] Rosters (Code Map › Rosters): update each as its derivation answers, with each new member's canonical name read from the instance.
- [ ] `ui/src/app/areas/system-explorer/docdb-list.page.ts`, `docdb-create-dialog.ts`, `docdb-create.store.ts` and their specs (new):
  - The page wraps `<app-list-page />`. It registers `create`, which opens the dialog, as `namespace-list.page.ts` does.
  - While `RefreshService.descriptor()` is this screen and `fault()?.code === 'DOCDB.SERVICE.DISABLED'`, it shows a `role="status"` strip with the published sentence.
  - The dialog has one Name field and a hint, and posts through the store with the route's `?ns=`. It shows a violation on Name and a 409 reason in the dialog. A 201 publishes the `docdb-database` `created` change event and closes.
- [ ] `ui/src/app/shell/screen-outlet.ts`, `shell/screen-action-handler.ts`, `core/screen-actions.ts`: add-only entries.
  - The page in `DESCRIPTOR_PAGES`.
  - The descriptor in `SCREEN_ACTION_DESCRIPTORS`, and the drop consequence in `DESTRUCTIVE_CONSEQUENCES`.
  - `{delete: "Drop"}` in `DESCRIPTOR_ACTION_LABELS`.
- [ ] `ui/src/app/core/strings.ts` (end) and EXPERIENCE.md:
  - Add a new Fixed-strings row after :601, then move every citation `strings.test.mjs` reports.
  - At :159, add "· Document databases" and make the story range 19.17.
  - At :173, add "create a document database (System Explorer's Document databases)".
- [ ] `ui/angular.json`, `ui/tools/angular-json.test.mjs`: re-base `maximumWarning` on the measured build (DW-1166). Stop above 3,800 kB.
- [ ] `ui/browser/system-explorer-docdb.browser-spec.mjs` (new):
  - It refuses the live and slot containers.
  - Disabled strip, then `EnableService` through `runIris`.
  - Create through the dialog and see the row; a bad name shows its violation; drop through the typed-name dialog.
  - Structure in both themes; `after` restores the service and calls `RemoveAll`.

**Acceptance Criteria:**

- **AC1 (Integration).** Given `%Service_DocDB` enabled on `ocupilot-a2-ci` and two probe databases in USER, when a caller holding the screen's pairs opens System Explorer › Document databases, then each database is a row (Name, Class, Document type, Resource) read through `DocDbPort`, and `explorer.docdb.read` answers the same rows.
- **AC2 (service reported).** Given the service disabled, when the screen opens, the read tool runs, a person creates or drops through the routes, or the agent proposes a create, then each answers 409 `DOCDB.SERVICE.DISABLED` and no `%SYSTEM.DocDB` method runs. The screen shows the sentence naming `%Service_DocDB` and the Services screen. The service stays disabled.
- **AC3 (gate).** Given purpose-built principals each lacking one declared pair, when each lists, creates or drops, then each is refused 403 naming that pair before the service check and any vendor call, and no audit row is written. A principal holding exactly the declared pairs succeeds.
- **AC4 (create).** Given the service enabled, when a person creates `OcuProbe1917A` from the dialog, then the route answers 201, class `ISC.DM.OcuProbe1917A` exists, the row appears and `readBack` reads `matches`. Every other create row of the matrix answers its code, with nothing created.
- **AC5 (drop).** Given `OcuProbe1917A`, when a person drops it through the typed-name dialog, then its class, data and row are gone and the row leaves the list.
- **AC6 (agent).** Given a turn on this screen:
  - When the agent proposes `explorer.docdb.create`, then the card shows the name, and a confirm creates the database and marks it (AD-15).
  - A confirm after another session created the same name in any case is refused.
  - When it proposes `explorer.docdb.delete` under the baseline, then dispatch refuses it by governance.
- **AC7 (own code).** Given either caller, when a create names `OcuPilot.X` or `ocupilot.y`, or a drop targets a database whose class begins with `OcuPilot`, then it is refused `PROHIBITED.OCUPILOTCODE` and nothing is written.
- **AC8.** Given the screen in light and dark themes, when the structural walk and the screen's browser spec run, then the structural gate passes, the screen keeps three suggested prompts, and the dialog and strip draw only `--ocu-*` tokens.

## Spec Change Log

- 2026-10-05, lead (spec gate): the Design Notes decisions are ruled tier-1 and written into the spine: the `%Admin_Secure`-only holder refused, the drop's `CheckAccess "W"` not repeated (DW-2084 cited), create by name only, a mapped package refused, `READBACKFIELDS` (AD-58), AD-7's sixth shape for the vendor's service-refusal audit row (the shape count corrected at origin), AD-29's `DocDbPort` paragraph, AD-8, AD-10, AD-13, AD-36, AD-15's sixteenth case and AD-53's nineteenth gap (AD-53's duplicate sixteen corrected at origin). The same-line edits in `Read.cls`, `EntityType.cls`, `EntityRef.cls`, `Prohibited.cls` and the roster counts are list entries, add-only in substance, resolved by union at the forward merge.

## Review Triage Log

## Design Notes

**Decisions:**

- **Gate.**
  - The orchestrator decided that the port repeats the vendor's `%Service_DocDB` and `%DocDB_Admin` checks.
  - **Named limit:** the vendor also admits `%Admin_Secure:USE` in place of `%DocDB_Admin:USE` (`CheckAdmin1`, `DOCDB.int:53-61`). `Screen.Gate` and a descriptor pair set require every pair, so an `%Admin_Secure`-only holder is refused. A narrower audience, as AD-8 accepts for 18.15 and 18.16.
  - `%Developer` holds all three pairs (19.9, measured).
- **The drop does not repeat `CheckAccess "W"`.** It needs a `Security.DocDBs` record, which no database created without a resource has (DW-2084, decision-pending owner=burndown). It is cited, not built on.
- **Create takes a name only.** A resource-scoped create needs the service and a valid DocDB resource, and writes a `Security.DocDBs` record, WA-11's application object. The vendor stores `DocumentType` `""` when none is given (measured).
- **A mapped package is refused**, so no create writes into `ENSLIB` or `HSLIB`. Measured: `Ens` resolves to `enslib` in USER and HSCUSTOM, and `HS` to `hslib` in HSCUSTOM. `ISC.DM`, `^ISC.DocDB.1` and the data globals resolve to the namespace's own database in both.
- **Write pairs.**
  - The routines database holds the class: 19.9 measured `<PROTECT>` on `^oddDEF` without it.
  - The globals database holds the registry row and the data: `^ISC.DocDB.1`, then `^DXKX.DiBt.1` (inference from the storage definition).
- **Read-back.** With no `ToolFields` row, a create's present re-read would read `unchecked` with an "unreadable" reason, which is false. `READBACKFIELDS` makes it compare `Name`; the drop reads gone on the 404.
- **The create is advertised.** The vendor generates the class from the name and the agent authors no code, so AD-53's 19.3 unadvertised case does not apply.
- **No classic page:** the portal lists Doc DB applications (WA-11), not databases.
- **A custom page.** `ListPage` draws a read's 409 as "request refused" with no reason, and a Create always needs registered client code. So the page wraps `ListPage`, as Resources does.

**Measured** (2026-10-05, `ocupilot-a2-ci`, USER; probes removed and `%Service_DocDB` restored to `Enabled` 0, each read back):

- **Service:** stock `Enabled` 0. `%SYSTEM.DocDB` list, get, create and drop all ran with it disabled.
- **`CheckServiceStatus(Name, Namespace)`** (`DOCDB.int:62-88`):
  - It runs `New $roles` and adds `%DB_IRISSECURITY` inside its own frame.
  - It checks the record (#809), enabled (#800) and `%Service_DocDB:U` (#921).
  - Any refusal returns 822 and writes one `%System/%Security/AccessDenied` "Doc DB Access" row; a pass returns 1 and writes none.
  - The indexed `COUNT(*)` undercounts; `%IGNOREINDEX` counts.
- **Names:**
  - Lookups ignore case (`xN` is SQLUPPER): `Exists`, `GetDatabase` and `DropDatabase("OCUPROBE1917A")` reached `OcuProbe1917A`, and `CreateDatabase("ocuprobe1917a")` threw #25051.
  - An unqualified name maps to `ISC.DM.<name>`; a qualified one is the class.
  - #25070 on a class clash; #25053 for `_`, `-`, a leading digit, a space, `%`, `""`, and a leading, trailing or double dot.
  - 213 characters unqualified is accepted and 214 refused.
- **Drop:** answers 1, deleting the class, data, row and index; it answers 0 for an absent name. `GetDatabase` of an absent name throws #25351.
- **Scope and cost:** per namespace (HSCUSTOM saw none of USER's). `GetAllDatabases` takes 0.011 ms and `GetDatabase` 0.009 ms with five databases.

**Strings** (about 20 literals; 2,607 + 20 of 2,700, so no raise; the union with 18.22 is the lead's):

- `DOCDB.SERVICE.DISABLED`: "The DocDB service (%Service_DocDB) is disabled on this instance, so document databases cannot be listed, created or dropped. An administrator can enable it on the Services screen in Permissions."
- `DOCDB.NAME.INVALID`: "A document database name is a class name: letters and digits in parts separated by dots, each part starting with a letter, and at most 213 characters without a package."
- `DOCDB.NAME.MAPPED`: "This namespace keeps that package's classes in another database, where OcuPilot does not create or drop document databases."
- `DOCDB.NAME.TAKEN`: "This namespace already holds a document database of that name, in any letter case."
- `DOCDB.CLASS.TAKEN`: "A class of that name already exists in this namespace, so the database was not created."
- Drop consequence: "Dropping a document database deletes its class and every document it holds. This cannot be undone."
- Labels:
  - "Document databases", "Document type", "Create document database", "Drop";
  - the hint "An unqualified name creates the class ISC.DM.<name>.";
  - the empty state "No document databases in this namespace." and its agent line "Ask the agent to create a document database here."
- Prompts: "Which document databases does this namespace hold?", "Create a document database named Orders.", "Is the DocDB service enabled here?"

**Spine amendments (draft, for the lead's gate, Rule 20):**

- **Design Paradigm and the Ports row:** add `DocDbPort` (`%SYSTEM.DocDB`, in process, Stage 3).
- **AD-29**, a new paragraph:
  > `DocDbPort` (Story 19.17) reaches `%SYSTEM.DocDB` in the caller's process. It runs, in order: `%Development:USE`, `%DocDB_Admin:USE` and `%Service_DocDB:USE`; then `AtelierPort`'s namespace pairs (a write adds WRITE on the routines and globals databases); then the name's rules; then `CheckServiceStatus^%SYS.DOCDB`, whose signature a test pins. A disabled service answers 409 `DOCDB.SERVICE.DISABLED` and costs one vendor `AccessDenied` audit row. Named limits: an `%Admin_Secure`-only holder, whom the vendor admits, is refused; the vendor drop's `CheckAccess "W"` is not repeated (DW-2084); a name whose package the namespace maps elsewhere is refused.
- **AD-8:** the screen's own pairs, and the two writes' WRITE pairs.
- **AD-13:** `docdb-database` keeps `foldcase`, measured.
- **AD-10:** `OCUPILOTCODE` covers a document database by the class its name creates.
- **AD-36:** a declared read may name the DocDB port.
- **AD-7:** a sixth shape: the access-denied audit row the vendor's service check writes while `%Service_DocDB` is disabled.
- **AD-15 / AD-53:** creating and dropping a document database record no vendor event (19.9, measured): a named case and a named gap. The lead numbers them; the two lists already disagree at :933 and :941.
- **AD-58:** a tool whose port has no derived field list may declare `READBACKFIELDS`.

**ADs:** AD-1, AD-3, AD-5, AD-6, AD-7, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-19, AD-20, AD-21, AD-22, AD-24, AD-29, AD-34, AD-36, AD-39, AD-40, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58, AD-59, AD-60, AD-61.

- Not engaged: AD-26 (no async path), AD-27 (no `%Api.Admin` class), AD-57 (the console is untouched).
- AD-21: no SQL is composed; the name is shape-checked before every vendor call.
- AD-34: the Save holds no target lock yet (DW-1882).

**Integration ACs:** AC1.

**Consumes:**

- Story 19.1's and 19.2's `AtelierPort.NamespacePairs`, `WritePairs` and `DatabaseResources`;
- the kernel's mint, confirm, `Prohibited.Code` and `ReadBack`;
- `ListPage`, and the typed-name Delete;
- `RefreshService.fault()`.

**Consumed-by:** this story's screen and three tools. No later story is planned; DT-01's documents, find and properties rows have none.

**Declined:** an InjectionChannels source. A document database name, its class and its resource follow class-name or resource grammar (measured #25053), so they cannot carry delimiters or spaces. 19.1's class names have no case either, and AD-60 still applies.

**Footprint (Rule 11)**, checked against `.worktrees/epic-18` at `5952fd82765950e426c2e633c6afeb9310465864`, committed and `status -s` (18.22 implementing):

- **Contended, not add-only (lead approval):**
  - `Screen/Read.cls:358`: 18.22 edits the same statement.
  - `Kernel/EntityType.cls:77` and `Kernel/EntityRef.cls:59`: the same lines.
  - `Kernel/Proposal/Prohibited.cls:250` and `:1105`: the same lines.
  - `Screen/Registry.cls:1142-1143` and `ui/tools/screen-mirror.mjs:946-948` and `:1214`: 18.22 edits :1161 and :1232 nearby.
  - EXPERIENCE.md :173.
  - `ui/angular.json` with `angular-json.test.mjs`.
  - Count lines in `Test/Descriptor`, `Prohibited`, `ReadTool`, `GovernanceBaseline` and `ToolRoundTrip`, and `screen-mirror.test.mjs:2691`.
  - The spine.
- **Contended, add-only:**
  - `Baseline.cls` (end; 18.22 inserts at :94), `strings.ts` (end) and `screens.generated.ts` (regenerate);
  - `screen-action-handler.ts`, `screen-outlet.ts`, `screen-actions.ts`;
  - `ci-throwaway.sh` (18.22 edits :330 and :543);
  - EXPERIENCE.md's new row;
  - the `SurfaceCoverage`, `DraftRegistry`, `ToolEmit`, `navigation.test.mjs` and `self-protection.test.mjs` rows.
- **Not contended:** every new file; `Router.cls`; `Api/Error.cls` (one prefix line); `ReadBack.cls`; `Write.cls`; EXPERIENCE.md :159; `ExplorerDescriptor`, `PortGate`, `AdminPairCorpus`, `EndpointCoverage`, `DeveloperFloor`, `Governance` :33 and `ToolWrite` :1339.

**Ledger inbox:** none. Ledger candidates for the lead: none.

## Verification

All of these run on `ocupilot-a2-ci`, and never on `ocupilot` or any slot container:

- every check that creates or drops a document database, enables `%Service_DocDB` or creates principals;
- loading the source: `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)` in `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`. Never restart the container.

The stateful classes run one at a time: one test-runner call per message, wait for it to land, never re-submit after a timeout. After each run, check that `%Service_DocDB` reads `Enabled` 0 and that no `OcuProbe1917*` database or class remains.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<X>` (loop), one class at a time, expected green:
  - DocDbDescriptor, DocDbPort, DocDbGate, DocDbWrite, ReadBack;
  - ExplorerDescriptor, ReadTool, ToolRoundTrip, SurfaceCoverage, Descriptor, DeveloperFloor, DeveloperFloorRoutes, EndpointCoverage, GovernanceBaseline, Governance, DraftRegistry, ToolEmit, ToolWrite, Prohibited, PortGate, AdminPairCorpus.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/docdb*.spec.ts'` (loop): expected green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>` for `system-explorer-docdb.browser-spec.mjs` and for `a11y-structural-invariants.browser-spec.mjs`: expected green.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edits): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci` (once, before dev_complete): the full ObjectScript sweep, one class at a time. Expected green apart from the known residue. The full browser suite is CI's.

**Pinning tests and the mutation each must redden (Rule 19).** The implement stage records each `mutation:` line here.

- AC1: `DocDbPort` LIST drops `Class` → the DocDbPort list leg and the browser row leg.
- AC2: the port skips `CheckServiceStatus` → the DocDbPort disabled leg (a vendor call was made) and the browser strip leg.
- AC3: `PAIRS` loses `%DocDB_Admin:USE` → the DocDbGate missing-admin leg. Moving the service check ahead of the pairs → the leg asserting no audit row.
- AC4: `NameProblem` removed → the DocDbPort invalid-name leg. `READBACKFIELDS` emptied → DocDbWrite's `matches` leg.
- AC5: DROP ignores a 0 answer → DocDbPort's drop-absent leg. `DESTRUCTIVE_CONSEQUENCES` loses the entry, so no Drop is drawn → the browser drop leg.
- AC6: the absence fingerprint is skipped → DocDbWrite's taken-since-mint leg. The baseline sets `explorer.docdb.delete` `true` → GovernanceBaseline and DocDbWrite's governance leg.
- AC7: the `docdb-database` arm removed → DocDbWrite's two `OCUPILOTCODE` legs.
- AC8: the strip's token swapped for a literal color → `client-lint.mjs` and the structural leg.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
