---
title: 'Story 19.17: The DocDB browser'
type: 'feature'
created: '2026-10-05'
status: 'done'
baseline_revision: 'e3d63db74e56fbf830b888bf0d6899e539109063'
baseline_commit: 'e3d63db74e56fbf830b888bf0d6899e539109063'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-9-documatic-and-docdb.md'
warnings: ['oversized']
deferred:
  - summary: >-
      ExplorerDescriptor.TestTheAreaHoldsTwentyFourReadsAndEightWrites keeps its name while it now
      asserts twenty-five reads and ten writes.
    evidence: |-
      Its messages state the current counts; renaming it edits the eight method attributes
      SurfaceCoverage.cls:321-328 hold, rows Epic 18 also edits, so it waits for the forward merge.
    location: >-
      src/OcuPilot/Test/ExplorerDescriptor.cls:141
    severity: low
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

### Review Findings

Code review 2026-10-05 (full-opus, four layers): 37 rows; 23 survive as 19 entries (0 high, 4 medium, 15 low): 18 patched, 1 deferred; 14 rejected.

- [x] [Review][Patch] (med) A case-variant class or package name answers 500 INTERNAL, logged: the vendor's #5092 and #5093 are unmapped (measured on `ocupilot-a2-ci`) [src/OcuPilot/Port/DocDbPort.cls:460]
- [x] [Review][Patch] (med) AC3's "before the service check" has no pin for the write pairs: `OcuP1917NoWrite` runs only with the service enabled [src/OcuPilot/Test/DocDbGate.cls:110]
- [x] [Review][Patch] (med) `PortQuery` is unpinned: every confirm runs in the mint's own scope [src/OcuPilot/Test/DocDbWrite.cls:239]
- [x] [Review][Patch] (med) The port's `maxRows` cut and the read's `truncated` run under no binding cap (AD-36) [src/OcuPilot/Test/DocDbPort.cls:117]
- [x] [Review][Patch] (low) The create's description refuses "a name beginning with OcuPilot"; the arm judges the class the name creates [src/OcuPilot/Screen/Tool/ExplorerDocDbCreate.cls:20]
- [x] [Review][Patch] (low) `OCUPILOTCODE`'s doc comment omits the document database arm [src/OcuPilot/Kernel/Proposal/Prohibited.cls:493]
- [x] [Review][Patch] (low) `Snippet`'s doc says the instance repeats the gate and service check for a script; `%SYSTEM.DocDB` checks neither [src/OcuPilot/Port/DocDbPort.cls:556]
- [x] [Review][Patch] (low) `DocDbGate`'s zero-audit-row assertion has no positive control in the class [src/OcuPilot/Test/DocDbGate.cls:124]
- [x] [Review][Patch] (low) Five `DocDbProbe` read methods skip `Armed()`, against the header and the spec's task [src/OcuPilot/Test/DocDbProbe.cls:115]
- [x] [Review][Patch] (low) The browser spec's cleanup: test 2's `finally` removes no probe, and `after` skips the service restore when `removeAll` throws [ui/browser/system-explorer-docdb.browser-spec.mjs:105]
- [x] [Review][Patch] (low) `const [name, type]` binds the Class cell [ui/browser/system-explorer-docdb.browser-spec.mjs:288]
- [x] [Review][Patch] (low) The QA leg's "creates nothing" assertions cannot fail: a case-insensitive `exists`, and a row count no refresh can change [ui/browser/system-explorer-docdb.browser-spec.mjs:340]
- [x] [Review][Patch] (low) `ExplorerDescriptor`'s writers message still names only the source code API port [src/OcuPilot/Test/ExplorerDescriptor.cls:157]
- [x] [Review][Patch] (low) `ReadBack.Compared`'s doc omits the `READBACKFIELDS` fallback [src/OcuPilot/Kernel/Proposal/ReadBack.cls:236]
- [x] [Review][Patch] (low) `CODEREADONLY` names #5883, a write-permission refusal [src/OcuPilot/Port/DocDbPort.cls:96]
- [x] [Review][Patch] (low) The drop's `Name` description omits the name rules and the `ISC.DM` mapping, and the test's `[ "letter"` passes on "letter case" [src/OcuPilot/Screen/Tool/ExplorerDocDbDelete.cls:51]
- [x] [Review][Patch] (low) `EnsurePrincipals` restores the namespace after its `Catch`, not first in it (AD-16) [src/OcuPilot/Test/DocDbGate.cls:207]
- [x] [Review][Patch] (low) AC3's exact-pairs clause and AC8's prompt count have no `mutation:` line [spec ## Verification]
- [x] [Review][Defer] (low) Create stays available while the strip says the service is disabled; the dialog then shows the 409 sentence [ui/src/app/areas/system-explorer/docdb-list.page.ts:102] — deferred: DW-2094 wontfix-accepted, not spec-clear

Rejected:

- `low` IsMapped admits a vendor package in `%SYS` (its packages resolve to IRISSYS, the namespace's own database): only an IRISSYS writer who names a vendor package reaches it, and the fix adds a guard.
- `false` ToolRoundTrip's `DOCDB.SERVICE.DISABLED` depends on the fresh instance's stock state, which Conventions › Tests allows.
- `low` The own-code drop through both real callers: already rejected in this spec's triage; no new evidence on harm.
- `low` The dialog posts the name untrimmed: the spec sends it exactly as typed, and the 422 sentence is true of a space.
- `false` The registry ties no docdb read to the port's pairs: no second docdb screen exists, and a missing pair fails closed, named.
- `false` `ExplorerDocDbWrite.PrivilegePairs` ignores `tResolved`: it is `ExplorerWrite.PrivilegePairs` verbatim, and the port refuses an unresolved namespace before any vendor call.
- `false` `DocDbSave`'s seams: identical to `LanguageServerSave`'s (:18-47, :243).
- `low` The 422 sentence omits the 220-character qualified limit: spec-bound sentence; a 221-character qualified name is rare.
- `low` EXPERIENCE.md has no Component Patterns entry for the strip: the spec asks for the Fixed-strings row, :159 and :173 only.
- `low` A non-ASCII name the vendor might accept is refused 422: spec-bound pattern, vendor acceptance unmeasured.
- `low` A dialog dismissed while its create is in flight publishes no change event: a sub-second window, and every form store orders it this way (`license-server-form.store.ts:383`, `:521`).
- `false` No per-database `CheckAccess`: the vendor's list checks `CheckAdmin` alone (`%Api.DocDB.v1:237`), and the drop's is the spec's Never item (AD-29, DW-2084).
- `low` `DocDbGate` cannot run with OcuPilot installed in USER: every throwaway installs into HSCUSTOM.
- `false` `ExplorerDocDbCreate.FieldRows` is hand-written: AD-3 fails that only for an endpoint that publishes a template, and `%SYSTEM.DocDB` publishes none.

## Spec Change Log

- 2026-10-05, lead (spec gate): the Design Notes decisions are ruled tier-1 and written into the spine: the `%Admin_Secure`-only holder refused, the drop's `CheckAccess "W"` not repeated (DW-2084 cited), create by name only, a mapped package refused, `READBACKFIELDS` (AD-58), AD-7's sixth shape for the vendor's service-refusal audit row (the shape count corrected at origin), AD-29's `DocDbPort` paragraph, AD-8, AD-10, AD-13, AD-36, AD-15's sixteenth case and AD-53's nineteenth gap (AD-53's duplicate sixteen corrected at origin). The same-line edits in `Read.cls`, `EntityType.cls`, `EntityRef.cls`, `Prohibited.cls` and the roster counts are list entries, add-only in substance, resolved by union at the forward merge.

## Review Triage Log

### 2026-10-05 — Review pass

- verdicts: 24 findings — high 0, medium 1, low 10, false 13, maybe-false 0
- findings:
  - `[medium]` `[patch]` AC6's "marks it (AD-15)" had no assertion on either DocDB confirm — both confirm legs in `DocDbWrite` now assert `auditMarked` 1; red with the marker suppressed (run 509).
  - `[low]` `[patch]` `DocDbGate`'s two "nothing created" checks could not fail: the probe child drops what a wrong create made before the check — both deleted, the per-leg codes are the pin.
  - `[false]` `[reject]` `DocDbPort`'s "neither created a database" and `DocDbWrite`'s class-name check cannot fail — they read the instance's end state after the refusal; the same shape in `DocDbPort`'s disabled leg went red under the service-check mutation (run 508).
  - `[false]` `[reject]` the browser spec's `exists(INVALID)` cannot fail — it reads the instance after the refused Save and reddens if the name is ever created; it is not cited as any AC's pin.
  - `[low]` `[patch]` the dialog spec's "stays open" check could not fail (the host renders the dialog unconditionally) — deleted, test retitled to what it checks.
  - `[false]` `[reject]` `DocDbWrite`'s "with nothing dropped" after the governance refusal, and "nothing minted" unasserted — the asserted `GOVERNANCE.DISABLED` result comes from the dispatch gate, which precedes the mint (AD-22); the end-state check reads the instance.
  - `[false]` `[reject]` `DocDbWrite`'s `OcuProbe1917C` check after a refused mint cannot fail — it reads the instance after the refusal (AD-7's guarantee), and went red under the service-check mutation (run 509).
  - `[low]` `[patch]` `DocDbProbe.Exists`, `ClassExists` and `HasData` read a failed lookup as absence — each now restores the namespace and raises.
  - `[low]` `[defer]` `ExplorerDescriptor.TestTheAreaHoldsTwentyFourReadsAndEightWrites` keeps a stale name — its rename edits eight `SurfaceCoverage` rows Epic 18 also edits (not add-only); recorded in `deferred:`.
  - `[low]` `[reject]` the globals-database WRITE pair is never falsified — every stock namespace keeps globals and routines in one database, so pinning it needs a probe namespace; a regression still meets the instance's own `<PROTECT>`.
  - `[false]` `[reject]` "pair missing → 403, no audit row" is tested at the port only — every surface reaches the port, whose gate refuses before the service check (`DocDbGate`), whatever the route's own gate did.
  - `[low]` `[patch]` "one audit row each" was counted at the port only — `DocDbWrite`'s disabled leg now counts four rows for the read, Save, Drop and mint; red under the service-check mutation (run 509).
  - `[low]` `[reject]` own-code drop is tested against the kernel predicate only — both callers reach the arm through the generic gate and it reads only the target id; a surface test needs an `OcuPilot.*` database on the instance, the effect the arm prevents.
  - `[false]` `[reject]` a case-variant drop is tested at the port only — the agent's confirmed drop uses `ocuprobe1917a` against `OcuProbe1917A` end to end.
  - `[low]` `[patch]` a DATABASE 404's "unlogged" was untested — `DocDbLogSeam` and `DocDbPort.TestAnAbsentReadIsUnloggedAndAnAbsentDropLogged` pin it, and the drop's logged 404; red with the read logging (run 508).
  - `[low]` `[reject]` the #25053, #25070, `<PROTECT>`/#5883 and 500 branches and the agent's class-taken create are unreached — each sits behind a pre-check by design or needs a vendor seam; the Save's class-taken leg runs the same port path.
  - `[low]` `[reject]` an exact-case re-create answers `CLASS.TAKEN`, not `NAME.TAKEN` — a correct refusal with a true sentence; the fix adds a branch for a rare input.
  - `[false]` `[reject]` the same input answers differently on Save and the agent's mint — both refuse and write nothing; each follows its caller's documented order (AD-55 asks AD-10 first, AD-54 reads first).
  - `[false]` `[reject]` the agent-side service reason is pinned in two places, not end to end — the dispatcher's composition is generic and pinned by its own suites; the `DOCDB.` link is now pinned (run 499).
  - `[false]` `[reject]` the port's validation reasons are unpublished — each port declares its own reasons for malformed internal input, as `AtelierPort` and `MgmntPort` do; the strings rule covers screen copy and `DOCDB.*` refusals.
  - `[false]` `[reject]` `READBACKFIELDS` changes the kernel — the spec's Tasks require it, and every tool with a `ToolFields` entry or no declaration compares as before.
  - `[false]` `[reject]` `ListRows`' inner `Catch` does not restore first — it continues inside the switched region by design or rethrows to the outer `Catch`, whose first line restores; it calls no `OcuPilot.*` class.
  - `[false]` `[reject]` `%Api.DocDB*` appears in a doc comment — the comment states the prohibition; no code names such a class.
  - `[false]` `[reject]` additions beyond the intent's text (precondition, closed body keys, unresolved-namespace refusal, logged drop 404, script forms, budget) — each is required by an AD the spec binds (AD-51, AD-56, AD-2, AD-59, DW-1166).

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
  - mutation: `DocDbPort.Row` sets no `Class` → `DocDbPort.TestTheListAnswersEachDatabase` red (run 483, with two other Class-reading legs); the browser spec's create leg red on the row's class cell (`(none)`).
  - mutation (review, AD-36 cut): `ListRows`' `maxRows` cut removed → `DocDbPort.TestTheListAnswersEachDatabase` red on the one-row cut (run 980).
- AC2: the port skips `CheckServiceStatus` → the DocDbPort disabled leg (a vendor call was made) and the browser strip leg.
  - mutation: `Invoke`'s `ServiceStatus` test replaced by `If 0` → `DocDbPort.TestADisabledServiceRefusesEveryCallWithOneAuditRow` red (run 484); the browser strip leg red (no `[data-docdb-service-strip]`).
- AC3: `PAIRS` loses `%DocDB_Admin:USE` → the DocDbGate missing-admin leg. Moving the service check ahead of the pairs → the leg asserting no audit row.
  - mutation: `PAIRS` without `%DocDB_Admin:USE` → `DocDbGate.TestEachMissingPairIsRefusedByNameBeforeTheService` red on the NoAdmin and Secure principals (run 485).
  - mutation: a `ServiceStatus` refusal inserted before the `PAIRS` check → the same method red, including "no refusal reached the vendor's service check, so none wrote an audit row" (run 486).
  - mutation (review, the write pairs): `Invoke`'s write branch asks `NamespacePairs` in place of `WritePairs` → the same method red on `OcuP1917NoWrite`'s create, drop and the audit count of 2 (run 981).
  - mutation (review, the exact pairs succeed): `PAIRS` gains `%Admin_Secure:USE` → `DocDbGate.TestTheExactPairsListCreateAndDrop` red on the exact principal (run 982).
- AC4: `NameProblem` removed → the DocDbPort invalid-name leg. `READBACKFIELDS` emptied → DocDbWrite's `matches` leg.
  - mutation: `Invoke`'s `NameProblem` test replaced by `If 0` → `DocDbPort.TestAMappedOrInvalidNameIsRefusedBeforeTheService` red (run 487).
  - mutation: `ExplorerDocDbCreate.READBACKFIELDS` = `""` → `DocDbWrite.TestTheSaveCreatesAndRefusesEachRow` and `TestTheAgentsCreateConfirmsAndATakenNameIsRefused` red on their `matches` assertions (run 488).
  - mutation (review, class taken in another case): `Mapped` without #5092 and #5093 → `DocDbPort.TestATakenNameOrClassIsRefused` red on the case-variant class and package (run 980).
- AC5: DROP ignores a 0 answer → DocDbPort's drop-absent leg. `DESTRUCTIVE_CONSEQUENCES` loses the entry, so no Drop is drawn → the browser drop leg.
  - mutation: `Drop`'s `If 'tDropped` replaced by `If 0` → `DocDbPort.TestAnAbsentDatabaseIsNotFound` red (run 489).
  - mutation: the `ExplorerDocDbList` entry removed from `DESTRUCTIVE_CONSEQUENCES`, rebuilt and redeployed → the browser create-and-drop leg red (no row menu trigger).
  - mutation (matrix audit, the drop's data): `Drop` sets `tDropped = 1` without the vendor call → `DocDbPort.TestADropInAnyCaseReachesTheDatabase` red on the database, its class and its data global `^DXKX.DiBt.1` (run 500).
- AC6: the absence fingerprint is skipped → DocDbWrite's taken-since-mint leg. The baseline sets `explorer.docdb.delete` `true` → GovernanceBaseline and DocDbWrite's governance leg.
  - mutation: `Confirm` digests `AbsenceState(0)` for a create → `DocDbWrite.TestTheAgentsCreateConfirmsAndATakenNameIsRefused` red on "the confirm is refused as a moved target" (run 490).
  - mutation: `"explorer.docdb.delete": true` in `Baseline.cls` → `GovernanceBaseline.TestThePurgeIsTheOneDisabledLine` red (run 491) and `DocDbWrite.TestTheAgentsDropIsGovernedThenConfirmed` red (run 492).
  - mutation (review, AD-15 marking): `Confirm`'s success-arm `RecordAgentWrite` replaced by an error status → `DocDbWrite.TestTheAgentsCreateConfirmsAndATakenNameIsRefused` and `TestTheAgentsDropIsGovernedThenConfirmed` red on `auditMarked` (run 509).
  - mutation (review, `PortQuery`): `ExplorerDocDbWrite.PortQuery` returns at once → `DocDbWrite.TestTheAgentsCreateConfirmsAndATakenNameIsRefused` red on the confirm from HSCUSTOM's scope, and `TestTheCopyOutDraftNamesTheCreate` red (run 984).
- AC7: the `docdb-database` arm removed → DocDbWrite's two `OCUPILOTCODE` legs.
  - mutation: the `docdb-database` arm's `If` replaced by `If 0` → `DocDbWrite.TestOcuPilotsOwnCodeIsRefusedOnBothCallers` red on the screen create, the agent confirm and both own-code drops (run 494).
- AC8: the strip's token swapped for a literal color → `client-lint.mjs` and the structural leg.
  - mutation: the strip's `color: var(--ocu-warning)` → `#6b4e00` → `client-lint.mjs` red (`no-hardcoded-color`); built with `ng build` and redeployed, the browser strip leg red on dark contrast (1.49:1).
  - mutation (review, three prompts): the descriptor's third prompt removed → `DocDbDescriptor.TestTheDescriptorShape` red on "three prompts in the Code group" (run 985).
- (QA) `ui/browser/system-explorer-docdb.browser-spec.mjs`, third leg: the case-variant create's 409 sentence in the dialog's alert, in a real browser.
  - mutation: `DocDbPort`'s #25051 test replaced by `If 0`, recompiled on the throwaway → the new leg red ("An internal error occurred"); reverted by rsync and reload, green.
- Matrix audit and review, the remaining rows' legs:
  - mutation: the `DOCDB.` line removed from `Error.ReasonForToolCode` → `DocDbDescriptor.TestEachCodeReachesAToolResultWithItsSentence` red (run 499).
  - mutation: `Invoke`'s name rules replaced by `If 0` and its package check moved after the service check → `DocDbWrite.TestTheAgentsMintRefusesAnInvalidOrMappedName` red on both names and the audit count (run 501).
  - mutation: `Invoke`'s `ServiceStatus` test replaced by `If 0` → `DocDbWrite.TestADisabledServiceIsReportedOnEveryCaller` red on the four refusals and their four audit rows (run 509).
  - mutation: `Database` logs its absent answer → `DocDbPort.TestAnAbsentReadIsUnloggedAndAnAbsentDropLogged` red on the read leg (run 508).

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** System Explorer gains Document databases (`system-explorer/docdb`): `Port/DocDbPort` repeats the vendor's gate in the spec's order (pairs, namespace, namespace pairs, name rules and package mapping, `CheckServiceStatus`) before any `%SYSTEM.DocDB` call; a disabled service refuses 409 `DOCDB.SERVICE.DISABLED` on every path and the screen draws the published sentence in a status strip. The agent gets `explorer.docdb.read`, `explorer.docdb.create` (AD-54 create, `READBACKFIELDS` `Name`, key `true`) and `explorer.docdb.delete` (AD-51, destructive, key `false`); the screen's Create posts `POST /explorer/docdb` (AD-55) and its Drop is the typed-name delete. Own code is refused through a `docdb-database` arm of `Prohibited`.

**Files.**

- New server: `Api/DocDbError.cls` (codes and sentences), `Port/DocDbPort.cls` (gate, four types, name rules, mappings, script forms), `Area/Explorer/DocDbSave.cls` (Save route), `Screen/Descriptor/ExplorerDocDbList.cls`, `Screen/Tool/ExplorerDocDbWrite.cls`, `ExplorerDocDbCreate.cls`, `ExplorerDocDbDelete.cls`.
- New tests: `Test/DocDbProbe.cls` (armed fixture), `DocDbDescriptor`, `DocDbPort`, `DocDbGate`, `DocDbWrite`, `DocDbGateSeam`, `DocDbLogSeam`.
- Changed server: `Api/Error.cls` (one `DOCDB.` prefix line), `Api/Router.cls` (route), `Kernel/EntityType.cls`, `EntityRef.cls`, `Governance/Baseline.cls`, `Proposal/Prohibited.cls` (type, coverage, arm, create field), `Proposal/ReadBack.cls` and `Screen/Tool/Write.cls` (`READBACKFIELDS`), `Screen/Read.cls` and `Registry.cls` (`docdb` source); fourteen roster test classes.
- Client: `areas/system-explorer/docdb-list.page.ts`, `docdb-create-dialog.ts`, `docdb-create.store.ts` and their specs; `screen-outlet.ts`, `screen-action-handler.ts`, `screen-actions.ts`, `strings.ts`, `screens.generated.ts`; `tools/screen-mirror.mjs` and six tool tests; `angular.json` (2921kB); `browser/system-explorer-docdb.browser-spec.mjs`.
- Elsewhere: `scripts/ci-throwaway.sh` (`# classes:` lines), EXPERIENCE.md (Fixed-strings row :602, :159, :173).

**This pass beyond the handoff.** Matrix audit added the agent's invalid and mapped mint refusals, the drop's data global (`^DXKX.DiBt.1`) and the `DOCDB.*` tool-result reasons; review patches added `auditMarked` on both confirms, four audit rows on the disabled callers and the unlogged absent read, made the probe lookups raise, and removed three assertions that could not fail. Two deviations from the handoff, kept: `PermittedCreateFields` lists `Name` for `docdb-database`, and AC7's legs name `OcuPilot.OcuProbe1917X` and `ocupilot.ocuprobe1917y` so the probe cleanup covers a wrong create.

**Review.** 24 findings: 6 patched (1 medium, 5 low), 1 deferred (low, the stale `ExplorerDescriptor` method name, waiting on Epic 18's `SurfaceCoverage` rows), 17 rejected with reasons in the triage log (13 false, 4 low). Follow-up review: not recommended (one medium patched).

**Verification.**

- ObjectScript, one class per call on `ocupilot-a2-ci`: story classes after the last patch DocDbGate 505, DocDbPort 506, DocDbWrite 507 (DocDbDescriptor 496); mutation runs 499–501, 508, 509 each red, reverted with the tree byte-identical; handoff runs 461–495.
- Full sweep, once (runs 510–974): 465 classes, 3,800 tests, 0 failed; the only refusals are the known residue, Story 18.7's EncryptionKeyFileRead, EncryptionKeyFileWrite and EncryptionWriteGate (`OCUPILOT_ALLOW_ENCRYPTION_CONFIG`, which this throwaway's compose predates). After it, `%Service_DocDB` reads `Enabled` 0 and USER holds no `OcuProbe1917*` database or class.
- Client: `npm test` 1,824 tool tests and 2,468 component tests green; `check-objectscript.py` 0 problems and its harness 146 OK; `lint-docs.sh` 0 issues; Fixed strings 2,623 of 2,700.
- Bundle: 2,920,111 bytes initial (2,921 kB), the deployed `main-UZCA323B.js` equal to the build. Browser (handoff, on that bundle): `system-explorer-docdb` 2 of 2, `a11y-structural-invariants` 12 of 12, nothing new against the baseline.

**Residual risks.** The globals-database WRITE pair is unfalsified on a stock instance (every namespace keeps globals and routines in one database). The vendor-answer branches behind pre-checks (#25053, #25070, `<PROTECT>`) run in no test. Same-line list edits in `Read.cls`, `Registry.cls`, `EntityType.cls`, `EntityRef.cls`, `Prohibited.cls`, the roster counts and the "ten sources" sentence meet Epic 18 at the forward merge, as the spec gate ruled.
