---
title: 'Story 18.14: Namespace mappings and copy-mappings'
type: 'feature'
created: '2026-09-28'
baseline_revision: '57c4a1d797567e26000d343ecd7d41069457f4a7'
baseline_commit: 'c267f6da5e9ababff6ea59664edcb9f4050afcc7'
status: 'in-progress'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized', 'multiple-goals']
deferred:
  - summary: >-
      A global mapping's Collation cannot be cleared from the edit form.
    evidence: |-
      The form sends Collation "" when cleared, and MappingRules.Validate refuses "" as MAPPING.COLLATION.VALUE (not a whole number); reported by the implementation stage, confirmed by reading Validate.
    location: >-
      src/OcuPilot/Area/OsMgmt/MappingRules.cls:123
    severity: low
  - summary: >-
      The mapping form's locator screen segment opens the create route without its namespace, which shows the namespace-absent message.
    evidence: |-
      Reported by the implementation stage's client work; the form's route carries the namespace as a query parameter the locator's link does not keep.
    location: >-
      ui/src/app/shell/locator-bar.ts
    severity: low
  - summary: >-
      A mapping create refused on Namespace shows its sentence only in the form's summary, on no field.
    evidence: |-
      Reported by the implementation stage's client work; the form draws no Namespace control, so a MAPPING.NAMESPACE.ABSENT violation has no field to attach to.
    location: >-
      ui/src/app/areas/os-management/mapping-form.page.ts
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot list, create, edit or delete a namespace's global, routine and package mappings (catalog SA-11), or copy mappings between namespaces (SA-14). SA-13's enable-interop (DW-1776) moved to Story 18.15. The classic Mappings page and its three dialogs are the only way to manage mappings. There are two hazards:

- The vendor accepts a `%`-named global mapping, which shadows a system global, with no guard.
- Nothing stops a mapping write, or a copy, from moving OcuPilot's own `OcuPilot*` mapping.

**Approach:** The namespace editor gains a Mappings line that links three per-namespace mapping lists, each with a create and edit form and a typed-name Delete. The Namespaces list gains a Copy mappings row action that runs through AdminPort's async path, reading the finished task's result once.

The work has two parts, built in order:

- **Part A**, mappings: epic AC1 (18.14's first AC).
- **Part B**, copy-mappings: epic AC2 (18.14's second AC).

**Also in scope, by the owner's decision on DW-1784 (AD-44 as amended 2026-09-28):** each namespace and mapping write tool's pairs union the custom resource assigned to every classic page whose operation it performs -- the namespace create the New Namespace page's (`%CSP.UI.Portal.Namespace`), the namespace delete the Delete Namespace dialog's (`%CSP.UI.Portal.Dialog.NamespaceDelete`), the mapping writes their kind's classic page -- so an operator's custom resource on a replaced classic page gates the OcuPilot write too.

**Scope, decided by the orchestrator at the spec gate (2026-09-28, Rule 5):** the planned Part C, SA-13's enable-interop with its Task 0 observation (DW-1776), moved to Story 18.15, which runs after 18.4. The research stays in this spec's history at the commit that first planned it.

## Boundaries & Constraints

**Always:**

- **Screens.** Every new screen is in `os-management`, with the pairs `%Admin_Manage:USE` and `%DB_IRISSYS:READ`. None takes a side-bar position.
- **Extra tool pairs.** Each is refused by name before any port call (AD-8):
  - Every mapping write declares `%DB_IRISSYS:WRITE`.
  - `osmgmt.namespaces.copymappings` declares `%Admin_Operate:USE` (the poll) and `%DB_IRISSYS:WRITE`; the implement stage measures the second on the throwaway before the dialog is built.
  - Each namespace and mapping write tool also declares the custom resource assigned to each classic page it replaces, read at call time, never cached (AD-44, DW-1784).
- **Write kinds:**
  - A mapping create follows AD-54: it fingerprints the name's absence, because the vendor's `PUT` is an upsert.
  - A mapping edit follows AD-4: it sends the complete set, read fresh.
  - A mapping delete sends no body and is `DESTRUCTIVE`.
  - Copy is an AD-51 action, queued under `QUEUEDWRITES` (AD-26), `DESTRUCTIVE` with its own consequence. Its finished task's result is read exactly once (a second `async-result` read logs ERROR #7846 and turns the instance state to Warning, reported) and one poller runs per task.
- **Identity:**
  - Types `global-mapping`, `routine-mapping` and `package-mapping`, all with scope `instance`.
  - Composite id `[namespace, Name]`, joined on `$Char(1)` (`Kernel/EntityId`).
  - New id rule `foldcase-firstpart`, which folds only the namespace part. Mapping names keep their case.
- **The `%`-global guard (orchestrator ruling):**
  - A global-mapping create or edit whose name begins with `%` is permitted at the strongest confirmation.
  - It carries effect `MAPPING.SYSTEMGLOBAL`. The agent's proposal is minted destructive and states the consequence, and the form states the consequence under Name.
  - No request field suppresses the effect.
- **Kernel refusal (AD-10), from either caller:** `PROHIBITED.OCUPILOTMAPPING` refuses:
  - creating, changing or deleting a mapping whose name begins with `OcuPilot` (any case) in the install namespace (the evaluating process's `$NAMESPACE`, as 18.2 decided) or in `%ALL`;
  - a copy into either of those namespaces from a source holding such a mapping. The source's three lists are read at the write, and a list cut at its cap fails closed.
- **Governance (`Kernel/Governance/Baseline.cls`), all `true`:** the nine mapping writes and copy-mappings.
- **Contended files are edited add-only.** EXPERIENCE.md stays at 993 lines. `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged.

**Never:**

- No `%Api.Admin.*` name outside `AdminPort` or a port extending it.
- No direct `Config.Map*` or `Config.Namespaces` call in product code (test-only `%SYS` seeding is allowed).
- No polling outside the port, and no progress figure. The poll exposes none (measured).
- No enable-interop (Story 18.15).
- No test writes a mapping of the `USER` or `HSCUSTOM` namespace.
- No namespace, database or web-application create.
- No spine edit. The runner writes the amendments.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Lists | Probe namespace `OCUPROBE1814A` with one mapping of each kind | Each list shows that kind's rows, and each row's id is `[OCUPROBE1814A, Name]` | none |
| Mapping create | `OcuProbe1814G` → `USER` in `OCUPROBE1814A` | The `PUT` answers 201, and the row appears after the change event | none |
| Mapping edit | The Database of an existing mapping changes | The complete template set is sent, and the diff shows one row | none |
| Mapping delete | Typed name, then Delete | The `DELETE` answers 200, and the row is absent | none |
| Taken | Create a name that exists in that namespace | Refused on Name at the mint and at Save. No `PUT` is sent | `MAPPING.NAME.TAKEN` |
| Unknown database | Database `NOSUCHDB` | Refused on that field. No `PUT` is sent | `MAPPING.DATABASE.ABSENT` |
| Routine suffix | `OcuProbe1814R_mac` | Refused on Name before any port call (the vendor would create `_MAC`, then answer 500) | `MAPPING.NAME.SHAPE` |
| Base with subscripts | Delete `G` while `G("a"):("m")` exists | The vendor refuses with #451, and both mappings remain | `MAPPING.NAME.SUBSCRIPTS` |
| `%` global | `%OcuProbe1814` or `%OcuProbe1814("a")` | Permitted. The card is destructive with the consequence, and the form shows the line under Name | effect `MAPPING.SYSTEMGLOBAL` |
| OcuPilot mapping | A name that begins with `OcuPilot`, in the install namespace or `%ALL` | Create, edit and delete are refused. Nothing reaches the port write | `PROHIBITED.OCUPILOTMAPPING` |
| Deleted since read | Edit a mapping that was deleted after the read | 404 on the Save, and the upsert is never sent. The agent's confirm is refused as target changed | `MAPPING.NAME.ABSENT` |
| Copy | Source `OCUPROBE1814A`, destination `OCUPROBE1814B` | 202, polled. The running line shows, then done. The destination holds the source's mappings; same-named mappings are replaced and its others stay | none |
| Copy past the bound | The poll bound is exceeded | Recorded applied and marked; "Still running on the instance. It finishes in the background." | none |
| Copy source bad | The source is absent, or equals the destination (ignoring case) | Refused before any task is queued | `NAMESPACE.SOURCE.ABSENT` / `.SAME` |
| Copy into own | The destination is the install namespace or `%ALL`, and the source holds an `OcuPilot*` mapping, or one of its lists is cut | Refused, failing closed | `PROHIBITED.OCUPILOTMAPPING` |
| Missing pair | A write without one of its declared pairs, a replaced classic page's custom resource among them | 403 naming the pair, with zero port calls, on both callers | `AUTH.NOPRIVILEGE` |
| Integration | Each list and its read tool, and the copy dialog's choices | The same rows (AD-36). The dialog offers `NamespaceList`'s read, minus the destination | Same gate |

</intent-contract>

## Code Map

**Vendor.** Read in `%SYS` through `iris_doc_get` and in `irissys/`, read-only. Measurements are under Design Notes.

- `%Api.Admin.Endpoints.Namespace.{Global,Routine,Package}Mappings`:
  - Query `namespace` is required. `name` is required except on LIST. `ResourcesOR` is `%Admin_Manage`.
  - `PUT` is an upsert and the only verb that reads a body.
  - The LIST runs `Config.Map*:List`. Its rows, inferred from each query's ROWSPEC, are global `{Name, Subscript, Database, Collation, LockDatabase}`, routine `{Name, Type, Database}` and package `{Name, Database}`. Task 0 records the real keys.
- `%Api.Admin.Endpoints.Namespace.Namespace`: `TYPEMAPPINGS` is 11, and `ShouldRunAsync` is true for it. `MAPPINGS` takes no `name` and the strict body `{SourceNamespace, DestinationNamespace}`, then calls `Config.Namespaces.CopyMaps`.
- Routes already derived: `src/OcuPilot/Port/AdminRoutes.cls:130-139` (`MAPPINGS` at :134). Templates: `src/OcuPilot/Screen/Tool/FieldLists.cls:131-146`, global `{Database, LockDatabase, Collation}`, routine and package `{Database}`.
- Classic pages (AD-44), each with `RESOURCE = %Admin_Manage`:
  - `%CSP.UI.Portal.Mappings`: one list for all three kinds. Its `DeleteItem` (`irissys/%CSP/UI/Portal/Mappings.cls:353-364`) performs the mapping delete.
  - `%CSP.UI.Portal.Mappings.{Global,Routine,Package}`: the create and edit dialogs.
  - `%CSP.UI.Portal.Namespace` (New Namespace). It also holds "Copy namespace mappings from" (`Namespace.cls:83,238`), which runs through `%CSP.UI.System.ExpResultPage`. That is a `%CSP.Page`, which no custom-resource check reaches (inference: `%GetCustomResource` is called only from `%ZEN/Controller.cls:55,363`, `%CSP/Portal/Home.cls:1145` and `%CSP/Portal/ResourceDialog.cls:126`).
  - `%CSP.UI.Portal.NamespaceEdit` (Edit Namespace, `NamespaceForm`'s `classicPage`), `%CSP.UI.Portal.Dialog.NamespaceDelete`, and `%CSP.UI.Portal.Namespaces` (`NamespaceList`'s).
- The custom-resource store: `%CSP.Portal.Utils.%GetCustomResource` and `%SetCustomResource(<URL-encoded page>, <resource>)`, where an empty resource removes the assignment. `%SYS.Portal.Resources` keys on `NormalizePage`, which neither checks that the class exists nor folds case.
- Sibling guard: `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/Config.cls:557-560,640-647`. `IsGuardedBaseMapping` refuses a base `%`-global create without `force`.

**Privilege (DW-1784):**

- `src/OcuPilot/Screen/Gate.cls`: `RequiredPairs` :106 unions the descriptor's one `classicPage` resource at `CLASSICPERMISSION` (`USE`). `ClassicResource` :242 reads the store. Its doc (:236-241) says no test writes the store.
- Every gate reads a tool's `PrivilegePairs` at call time:
  - `Kernel/Proposal/Operation.cls` `RequiredPairsOf` :395, reached from `Gate` :298 (the confirm and the screen-action route) and from `Kernel/Proposal/Mint.cls:469`;
  - `Area/OsMgmt/NamespaceSave.cls` `Gate` :349-366 (the Save), after the form descriptor's own pairs.
- `Screen/Tool/NamespaceCreate.cls:142`, `NamespaceUpdate.cls:85` and `NamespaceDelete.cls:90`: each `PrivilegePairs` is `Gate.RequiredPairs(NamespaceList)` plus the tool's own pairs.
- `Test/ScreenGate.cls:10-13` is the override seam. Its header says the store stays empty.
- `Test/NamespaceWriteGate.cls` (`RunAs` :266, `EnsurePrincipals` :324) with `NamespaceWriteGateProbe` is the principals model.

**Port** (`src/OcuPilot/Port/`):

- `AdminPort.cls`:
  - `MUTATINGTYPES` :309, `BODYLESSTYPES` :325, `QUEUEDWRITES` :492 (doc :486-491), `PROPERTYFAULTS` :2319 (grammar :2292-2318).
  - `SPLITQUERIES` :517 splits on `/`, which a subscript can hold, so it is not used.
  - `Invoke` :758, `EndpointType` :1960. `Sequence` :2067 holds the `ShouldRunAsync` handoff and the queued-write refusal.
  - `AwaitTask` :2152 is the one poller, and `Snippet` :2504.
- `AuditPort.cls` is the model. `STARTEDHTTP` :44. `Invoke` :69-104 refuses a caller body, builds the body, calls super with an empty query, and turns a timeout into started. `Snippet` :380.
- `Kernel/Proposal/Operation.cls:173-184` `Query()`: the id travels under `IdParam`, followed by the tool's `PortQuery`.

**Tools** (`src/OcuPilot/Screen/Tool/`):

- `Write.cls` parameters: `DESTRUCTIVE` 52, `READTYPE` 57, `WRITETYPE` 62, `SENDSBODY` 67, `FINGERPRINTSUBJECT` 97, `PRECONDITIONFIELD` 105, `PORTCLASS` 114, `CHANGEACTION` 124, `CREATES` 141, `SCREENACTIONS` 157, `READANSWERS` 170, `SCREENVALUES` 201.
- `Write.cls` hooks: `DerivedFields` 301, `PortQuery` 417, `StateDiff` 463, `MintClass` 472, `IdArgument`/`IdParam` 500/507, `ScreenActionDelta` 584, `FieldRows` 602, `InputSchema` 674, `ArgumentProblem` 786.
- `Base.cls`: `PrivilegePairs` :92, `ArgumentPairs` :123.
- `AuditCopy.cls` is the model for an action with a dialog value: `SCREENVALUES` :51, `SettableFields` :80, `PortQuery` :111, `ScreenActionDelta` :142, `PrivilegePairs` :155. The value flows through `Api/ScreenAction.cls` `Values` :453, then `Run` :217 (a 202 answers `continues`).
- `ErrorDeleteMint.cls:35-81` joins arguments into a composite id. The subclass idiom is `OAuthResourceServerRemoveMapping`, which subclasses `AddMapping`. `Screen/Tool/Registry.cls:636-646` skips `[ Abstract ]` classes.
- `Classification.cls`: the grammar is at :6-29, and the namespace entries at :469-484. A bodyless tool needs no entry.

**Kernel:**

- `Kernel/EntityType.cls` `TYPES` holds 33 types.
- `Kernel/EntityRef.cls`: `IDRULES` :59, `IDRULENAMES` :64, `NormalizedId` :246-259. Normalization runs at `Api/ScreenAction.cls:190` and `Mint.cls:431`, so the port can receive a lower-cased namespace part.
- `Kernel/EntityId.cls:71-84` handles `$Char(1)` joins.
- `Screen/Read.cls`:
  - `Execute` :263 and the `READ.CRITERION` refusal :370-373;
  - the object read's id seeding :410-415, the admin LIST branch :423-437, projection :450-468 (`Project` :1026), `SeedCriteria` :767.
- `Kernel/Proposal/Mint.cls`: `GrantsPrivilegeByEffect` is called at :317, and `WeakensByEffect` runs only under `If 'tCreates` (:324-331). The destructive flag is at :332-333, and `ConsequenceOf` at :739.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250 (22 types), `Codes()` :489 (19 codes), `ReasonFor` :497;
  - `PermittedChangeFields` :600, `PermittedCreateFields` :712;
  - `Prohibits` :799, with the type chain at :810, the create branch at :831-838 and the dispatch at :847-921;
  - `Created` :986, `WeakensByEffect` :1157-1204, `Namespace` :1595-1621, `IsOwnNamespace` :1627, `NamespaceFields` :1636, `Target` :2856.
- `Kernel/Proposal/Impact.cls:371-383` `ListRows` is the gate plus the declared read, where a cut list reads as unchecked. It is private and takes no criteria.
- OcuPilot's own mapping is one global mapping, `OcuPilot*` → `OCUPILOT`, in the install namespace (`Kernel/State/Base.cls:86`, `Install/Installer.cls:2852-2882`).
- `Kernel/Governance/Baseline.cls:24-26` holds the namespace lines.

**Screens:**

- `Screen/Descriptor/NamespaceList.cls:23-68` (`rowActions` `[{delete}]` at :39). `NamespaceForm.cls:19-49` declares no read.
- Models: `WalletSecretList.cls:32-83` (parent-scoped, one criterion) and `TaskRunList.cls:44-99` (composite id, parent-scoped).
- `Screen/Registry.cls`: `CriteriaProblem` :1376-1429 (one criterion, and `namespace` is not reserved at :1324), `TableProblem` :2187 (`id.parts` must be among `read.fields`), `PROMPTGROUPKEYS` :2538, `ParentScopeResolutionProblem` :3332.
- `ui/tools/screen-mirror.mjs` mirrors all of these. `IMPLEMENTED_ID_RULES` :162 and `checkedIdRules` :2554-2590 fail the build.

**Save routes:**

- `Area/OsMgmt/NamespaceRules.cls`: `Validate` :57, `HandleForm` :160, `HandleName` :207, `Taken` :241, `Databases` :302 (the `Database.ConfigCRUD` LIST, as the caller), `Spelled` :330, `Gate` :374.
- `Area/OsMgmt/NamespaceSave.cls`: `Create` :115, `Update` :160, `PortViolations` :227, `Prohibited` :256, `Gate` :349.
- `Api/Router.cls`: the namespace routes are at :119-122 and the screen routes at :123-125. The ordering precedents are :81-86 and :164-165, and the handlers start at :579.
- `Api/Error.cls`: the NAMESPACE block is at :2498-2540. `NamespaceViolationCodes` is at :1427. `ReasonForViolation` :1211 routes the prefix at :1366.

**Client** (`ui/src/app/`):

- `areas/os-management/namespace-form.page.ts`: the fields end at :150, the form bar is at :152, and the edit id is read at :353. The link-line model is `areas/tasks/task-editor.page.ts:91-95,239-267,339-346`.
- `namespace-actions.ts:31-40`. For a parent carried as a query parameter, see `areas/security/wallet-actions.ts:38-47` and `wallet-secret-form.page.ts:546-556`. That parameter is never `ns` (`core/navigation.ts:619,636-644`).
- `core/navigation.ts`: `childListFor` :254-265 answers only the first child, and `parentListFor` :293-300 inverts only that one. The locator links back at `shell/locator-bar.ts:350`, and `ownIdSegment` answers `''` for a parent-scoped screen (:371).
- `shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :51-73, `UNDRAWN_ACTIONS` :149-157, `DESTRUCTIVE_CONSEQUENCES` :208-227;
  - `startFor` :494-564, `sendFor` :748, `continued()` :758.
  - The lazily built handler re-registers every declared row action (:395-408). A page-owned action therefore joins `UNDRAWN_ACTIONS` and registers after the handler is injected (`areas/security/auditing-config.page.ts:253,308-310`).
- The running-line model:
  - `auditing-config.page.ts:172,527-541,596-620` and `areas/security/audit-copy-dialog.ts`;
  - `ListPage` renders only the table and dialogs (`shell/list-page.ts:59-78`), so the wrapper model is `areas/security/audit-user-event-list.page.ts:28-54`.
- The field consequence line: `areas/web-applications/create-form.page.ts:327,341-343,534-536`. The effect code-to-sentence map: `core/proposal-view.ts:138-189`. The panel's still-running sentence: `shell/panel.ts:1158-1174`.
- `core/entity-ref.ts:65-112`; `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :114 (`NamespaceForm` at :137); `app.ts:306-308,554-611`.
- `core/strings.ts` (3447 lines): the 18.2 keys are at :3383-3420. Reuse `oauthResourceServerTabMappings` ("Mappings"), `auditDatabaseCopyConfirm` ("Copy"), `auditDatabaseStillRunning`, `headerNamespaceLabel`, `tableColumnName`, `tableColumnType` and `systemInfoDatabase`. Values are unique (`tools/strings.test.mjs:732`).

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 993 lines): extend rows :164, :173, :378, :479 and :481 in place. Row :516 is the source of the reused strings, and row :403 is the field-consequence model.

**Rosters** (each to extend):

- ObjectScript:
  - `Test/Descriptor.cls`: `ReadShapes` :67-118, the entity count :1700 (33).
  - `Test/ReadTool.cls:93`: the production registry holds 134 tools, reads and writes together.
  - `Test/SurfaceCoverage.cls` :75,126,149-151; `Test/EndpointCoverage.cls` :192-195; `Test/Navigation.cls` :338-339 (12 screens).
  - `Test/Wire.cls`, `Test/WireSecurityRead.cls` :549,556,559; `Test/ProposalPrivilege.cls` :95-106.
  - `Test/Prohibited.cls` :218,672 (19 codes); `Test/AuditingUpdate.cls:505` (19); `Test/RefusalCopy.cls:107`.
  - `Test/GovernanceBaseline.cls:10`, `Test/Governance.cls:90-104`, `Test/ToolDispatch.cls:139-150`, `Test/ToolEmit.cls:200-212`.
  - `Test/ToolWrite.cls` :1192-1263 (`tOtherPorts`), `Test/ToolRoundTrip.cls:38` `REFUSEEMPTY`.
  - `Test/PortFixture.cls:21`, `Test/AdminPortAsync.cls:88`, `Test/DraftRegistry.cls` :80,123,159, `Test/EntityRef.cls`.
- Client: `ui/tools/navigation.test.mjs` :150-161,223-245,384-432; `navigation-wire.test.mjs` :90-180; `shell/rail-wire.spec.ts` :87-179; `tools/self-protection.test.mjs:252-266`; `tools/screen-mirror.test.mjs:191-210`; `tools/entity-ref.test.mjs:207-215`; `shell/screen-action-handler.spec.ts`; `app.spec.ts`.
- DW-1774: every new screen takes position 0, so no side-bar list changes, and `namespaces.browser-spec.mjs:369-393` stays valid.

**Test models:**

- `Test/NamespaceWrite.cls` (the arming, the lifecycle, and the `^||OcuPilotNamespaceWritePort` seam); `NamespaceWriteGate` with its probe; `NamespaceRefusals`; `NamespaceWriteProbe` (`RemoveAll` :225, `CpfValid` :299); `AcceptPort` (`ReadThrough`); `DeviceRecordPort`; `RoleDeletePort`.
- The started path with a zero bound: `Test/AuditStarted.cls` with `AuditStartedPort`, `AuditStartedConfirm`, `AuditStartedAction` and `AuditStartedCopy`.
- Arming: in `scripts/ci-throwaway.sh`, the NAMESPACE_CONFIG block is at :354-362 and the principals `classes:` lines at :200-237. The rosters are derived by `ui/tools/ci.test.mjs:1818-1927`.
- Browser: `ui/browser/namespaces.browser-spec.mjs` has the `docker exec` cleanup at :71-93 and `assertStructure` at :338-365. `audit-copy-purge.browser-spec.mjs:92-99,174-208` has the running-line observer.

## Tasks & Acceptance

**Task 0: the implement stage's first task, before any code.** Run it on `ocupilot-b-ci` only, on probe namespaces the step creates and removes. Record the results in Design Notes › Measured at implement.

1. **Read-only checks:**
   - Do the three mapping LISTs answer the same rows for `namespace=user` as for `USER`?
   - Which keys does each LIST row carry?
   - If the lower-case form answers `[]` where the upper-case form answers rows, `NamespacePort` also upper-cases a LIST's `namespace`, and `MappingRefusals` pins it.
2. **The copy without `%DB_IRISSYS:WRITE`:** make a direct `AdminPort` call between two probe namespaces as a principal holding the screen pairs and `%Admin_Operate:USE`. Does the copy apply? Keep or drop the copy tool's `%DB_IRISSYS:WRITE` accordingly, and write the resulting AD-8 sentence into `## Spec Change Log` for the runner (Rule 20).
3. **Read once:** after one copy through `AdminPort`'s async path, confirm that the throwaway's alerts and `messages.log` hold no ERROR #7846 and that the instance state is unchanged. Do not provoke a second `async-result` read.
4. **HALT** `blocked`, with the blocking condition `observation contradicts the plan: <what>` and nothing built, if a LIST row carries no `Name` or the copy path logs #7846.

**Execution: DW-1784, the replaced classic pages' custom resources (AC7):**

- `src/OcuPilot/Screen/Tool/Write.cls`: add `Parameter CLASSICPAGES = ""`. It names the classic pages, beyond the descriptor's `classicPage`, whose operation the tool performs: normalized class names, comma-separated, spelled exactly (AD-44).
- `src/OcuPilot/Screen/Gate.cls`:
  - Add `ClassMethod WithClassicPages(pPairs As %List, pPages As %String) As %List`. For each page in `pPages` whose `ClassicResource` is not empty, it appends that resource at `CLASSICPERMISSION` once. It reads the store on every call and caches nothing.
  - Replace `ClassicResource`'s sentence about tests (:239-241) with one naming `Test/ClassicPageGate` as the one writer, on the throwaway only, restoring each page.
- Each declaring tool's `PrivilegePairs` ends with `Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)`:
  - `NamespaceCreate`: `%CSP.UI.Portal.Namespace`;
  - `NamespaceUpdate`: `%CSP.UI.Portal.NamespaceEdit`;
  - `NamespaceDelete`: `%CSP.UI.Portal.Dialog.NamespaceDelete`;
  - `NamespaceCopyMappings`: `%CSP.UI.Portal.Namespace`;
  - the create and update subclasses of each kind: `%CSP.UI.Portal.Mappings.<Kind>`, with the union done once in the abstract `MappingCreate` and `MappingUpdate`.
  - The mapping deletes declare none: the classic delete is performed on `%CSP.UI.Portal.Mappings`, which their descriptor already unions.
  - The namespace tools change here. The copy and mapping tools take their pages when Parts A and B build them.
- `Test/ScreenGate.cls:10-13`: replace "That store is empty here and stays so; its write path is an operator's, not a test's." with the same one-writer sentence.

**Execution: Part A, mappings (AC1-AC5):**

- `src/OcuPilot/Kernel/EntityType.cls`, `Kernel/EntityRef.cls`, `ui/src/app/core/entity-ref.ts`, `ui/tools/screen-mirror.mjs`:
  - Append `global-mapping`, `routine-mapping` and `package-mapping`, so 33 becomes 36.
  - Add the rule `foldcase-firstpart` to `IDRULENAMES`, `ID_RULES` and `IMPLEMENTED_ID_RULES`. It lower-cases only the text before the first `$Char(1)`, and each of the three types takes it.
  - Why: namespaces resolve without regard to case, while global and routine names are case-sensitive.
- `src/OcuPilot/Screen/Read.cls`:
  - Scope: a parent-scoped admin `LIST` whose composite id's first part equals its one criterion's `param`.
  - Refuse a missing criterion value with 400 `READ.CRITERION` before any port call.
  - Then seed the value onto every row under that part, before projection (after :436).
  - No registry key is added.
- `src/OcuPilot/Port/AdminPort.cls`:
  - Add the three mapping endpoints' `/PUT` and `/DELETE` to `MUTATINGTYPES`, and their three `/DELETE`s to `BODYLESSTYPES`.
  - Add to `PROPERTYFAULTS`: `<endpoint>:5854:@Name=MAPPING.NAME.SHAPE` and `<endpoint>:448:@Name=MAPPING.NAME.SHAPE` for each of the three endpoints, and `Namespace.GlobalMappings:451:@Name=MAPPING.NAME.SUBSCRIPTS`. Give each entry its measured fact in the doc comment.
  - Mirror `MUTATINGTYPES` in `Test/PortFixture.cls:21`.
- `src/OcuPilot/Port/NamespacePort.cls` (new, extends `AdminPort`, on the `AuditPort` model), for the three mapping endpoints' non-LIST calls:
  - A query that already carries `namespace` passes through unchanged. This covers LIST and every inner re-read.
  - Otherwise, split `name` with `EntityId.SplitComposite` into `namespace` (upper-cased; 18.2 measured that the instance stores namespace names upper case) and `name` (unchanged).
  - Anything other than two non-empty parts answers 404 `PORT.NOTFOUND` with no vendor call.
  - `SnippetForm` and `Snippet` mirror every branch (AD-59).
- `src/OcuPilot/Screen/Tool/MappingMint.cls` (new, on the `ErrorDeleteMint` model): the id is `JoinComposite($lb(Namespace, Name))`, built from the agent's `Namespace` and `Name`. A part that is empty or holds `$Char(1)` is refused.
- `src/OcuPilot/Screen/Tool/MappingCreate.cls`, `MappingUpdate.cls` and `MappingDelete.cls` (new, `[ Abstract ]`, no `TOOLNAME`), plus nine thin subclasses `{Global,Routine,Package}Mapping{Create,Update,Delete}.cls`:
  - Each subclass sets `TOOLNAME` `osmgmt.<kind>mappings.<verb>`, its endpoint `Namespace.<Kind>Mappings` and `DESCRIPTORCLASS` `<Kind>MappingList`.
  - All nine declare `PORTCLASS` `NamespacePort`, with `MintClass` `MappingMint`. `InputSchema` adds a required `Namespace`, described as "the namespace as the Namespaces list shows it".
  - `PrivilegePairs` is the list's pairs plus `%DB_IRISSYS:WRITE`, added once, then the `WithClassicPages` union (above).
  - Create: `CREATES` 1, `CHANGEACTION` `created`. The settable fields are the kind's template, with Database required.
  - Update: a merge that sends the complete template set, read fresh.
  - Delete: `DELETE`, `SENDSBODY` 0, `DESTRUCTIVE` 1, `CHANGEACTION` `deleted` and `SCREENACTIONS` `delete`. `READANSWERS` and `FINGERPRINTSUBJECT` are the template fields, and `PRECONDITIONFIELD` is `Database`.
  - `ArgumentProblem` and `DerivedFields` apply `MappingRules`.
- `src/OcuPilot/Screen/Tool/Classification.cls`: add a create entry and an update entry per kind (`fieldList` `Namespace.<Kind>Mappings`), every field `ordinary`. Then run `cd ui && node tools/field-lists.mjs` (AD-3).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` and `Mint.cls`:
  - The three types join `COVEREDTYPES` and the type chain. Their permitted create and change fields are the kind's template.
  - A `Mapping` predicate runs for create (through `Created`), change and delete. The target is own when its id's first part, upper-cased, is `$NAMESPACE` or `%ALL`, and its name part begins with `ocupilot` ignoring case.
  - An own target is refused `OCUPILOTMAPPING`, with the `:481` sentence as its `REASON`; add the code to `Codes()` (20) and to `ReasonFor`. Anything else takes `ReviewedFewOnly`.
  - `WeakensByEffect` gains a `global-mapping` arm: effect `MAPPING.SYSTEMGLOBAL` when the name part begins with `%`.
  - `Mint.cls:324` also asks `WeakensByEffect` for a create of type `global-mapping`.
- `src/OcuPilot/Api/Error.cls`: add a MAPPING block after the NAMESPACE block, sharing the NAMESPACE reasons where the sentence is the same:

  | Code | Reason |
  | --- | --- |
  | `MAPPING.VALIDATION` | the 422 slug |
  | `MAPPING.NAME.REQUIRED` | "Name what to map." |
  | `MAPPING.NAME.SHAPE` | "The instance does not accept that name. A routine type suffix is written in capitals, as in _MAC." |
  | `MAPPING.NAME.TAKEN` | "This namespace already has that mapping." |
  | `MAPPING.NAME.ABSENT` | "This namespace has no mapping with that name." |
  | `MAPPING.NAME.SUBSCRIPTS` | "Delete this global's subscript-level mappings first." |
  | `MAPPING.NAMESPACE.ABSENT` | the namespace-absent reason |
  | `MAPPING.DATABASE.REQUIRED` | "Choose a database." |
  | `MAPPING.{DATABASE,LOCKDATABASE}.ABSENT` | "No database on this instance has that name." |
  | `MAPPING.COLLATION.VALUE` | "Collation is a whole number." |

- `src/OcuPilot/Area/OsMgmt/MappingRules.cls` and `MappingSave.cls` (new, on the `NamespaceRules` and `NamespaceSave` model, each gated on its kind's form):
  - Rules:
    - Name is required, and a routine name ending in `_` plus lower case is SHAPE.
    - Taken means the create tool's `GET` does not answer 404.
    - The namespace exists (`Namespace.Namespace` `GET`).
    - Database and LockDatabase are names from `NamespaceRules.Databases`, sent in the list's spelling.
    - Collation, when sent, is a whole number.
  - `HandleForm` answers `{requiredFields, rules, databases}`. With `?name=`, it also answers the mapping, from the update tool's fresh read.
  - `Create` and `Update` run: gate, prohibited, rules, send, `PortViolations`, read-back. An edit whose fresh read answers 404 is refused `MAPPING.NAME.ABSENT`, and nothing is sent.
- `src/OcuPilot/Api/Router.cls`: add thin wrappers in route order. `kind` is `global`, `routine` or `package`, and anything else answers 404:
  - `GET /mapping/:kind/form?namespace=[&name=]`
  - `GET /mapping/:kind/name?namespace=&name=`, which answers `{name, taken, reason}`
  - `POST /mapping/:kind` with `{Namespace, Name, <template fields>}`
  - `PUT /mapping/:kind/:id`, where `:id` is the row key (the composite, one segment, AD-13)
- `src/OcuPilot/Kernel/Governance/Baseline.cls`: add the nine `osmgmt.<kind>mappings.<verb>` lines, all `true`, in name order.
- `src/OcuPilot/Screen/Descriptor/`: six new descriptors.
  - `GlobalMappingList`, `RoutineMappingList` and `PackageMappingList`:
    - route `os-management/namespaces/<kind>-mappings`, position 0, `parentScope` `os-management/namespaces`;
    - the entity is its own type, with `secondaryEntityTypes` `["namespace"]`, so a copy re-fetches it;
    - id: composite `["namespace","Name"]`;
    - read: `{admin, Namespace.<Kind>Mappings, LIST}`, with one criterion `{param:"namespace", labelKey:"headerNamespaceLabel", kind:"text", maxLength:64}`;
    - fields: global `namespace, Name, Database, LockDatabase, Collation`; routine `namespace, Name, Type, Database`; package `namespace, Name, Database`;
    - columns: Name (`name`), Database, then "Lock database" and "Collation" for globals, or Type for routines;
    - primary action `create`, row action `delete`;
    - `classicPage` `%CSP.UI.Portal.Mappings`, three prompts, and `toolIdentifier` `osmgmt.<kind>mappings`.
  - `GlobalMappingForm`, `RoutineMappingForm` and `PackageMappingForm`:
    - route `<list route>/edit`, position 0, `parentScope` `""`;
    - the same composite id, and no read;
    - `classicPage` `%CSP.UI.Portal.Mappings.<Kind>`, three prompts, and `toolIdentifier` `osmgmt.<kind>mappingform`.
- `ui/src/app/core/navigation.ts`: `parentListFor` answers the list whose route is the screen's `parentScope` whenever the screen qualifies as its child list or detail, not only on the first match. Each mapping list's locator then links back to Namespaces, and every existing child resolves unchanged.
- `ui/src/app/areas/os-management/mapping-form.page.ts`, `mapping-form.store.ts` and `mapping-actions.ts` (new). One page serves the three form descriptors, taking the kind from the route.
  - Create carries `?namespace=`, on the wallet model.
  - Fields:
    - Name (read-only on an edit);
    - Database, a native select from `/mapping/:kind/form`;
    - for globals only, LockDatabase (a select with an empty choice) and Collation (a whole number).
  - While a global's name begins with `%`, the `%` line shows under Name (the `create-form.page.ts:534` idiom).
  - Cancel returns to that namespace's list.
  - Register the page in `DESCRIPTOR_PAGES`, and inject the actions and `reset()` in `app.ts`.
- `ui/src/app/areas/os-management/namespace-form.page.ts`: in edit mode only, after :150, add a Mappings line labeled `oauthResourceServerTabMappings`. It holds three links, "Global mappings", "Routine mappings" and "Package mappings", each to `<list route>/<encodeEntityId(name)>` through `withQuery`.
- `ui/src/app/shell/screen-action-handler.ts`: add the three lists to `SCREEN_ACTION_DESCRIPTORS`, and their delete consequences to `DESTRUCTIVE_CONSEQUENCES`.
- `ui/src/app/core/proposal-view.ts`: map `MAPPING.SYSTEMGLOBAL` and `NAMESPACE.COPYMAPPINGS` to their sentence keys. The copy's key is the dialog's consequence sentence, so the sentence is published once.
- `ui/src/app/core/screens.generated.ts`: regenerate with `cd ui && node tools/screen-mirror.mjs` after each descriptor change.

**Execution: Part B, copy-mappings (AC6):**

- `AdminPort.cls`: add `Namespace.Namespace/MAPPINGS` to `MUTATINGTYPES` (mirrored in `PortFixture`) and to `QUEUEDWRITES`, whose doc states that no secret is carried. Update the literal at `Test/AdminPortAsync.cls:88`.
- `NamespacePort.cls`, on `Namespace.Namespace` `MAPPINGS`:
  - Refuse a caller body.
  - Build `{SourceNamespace, DestinationNamespace}` from `pQuery("SourceNamespace")` and the target id `pQuery("name")`, both upper-cased, then call super with an empty query.
  - A `PORT.TIMEOUT` on a queued write becomes started (202), as at `AuditPort:96-102`. `AwaitTask` stays the one poller: it reads the finished task's result once, and nothing reads it again.
  - `Snippet` renders the built body.
- `src/OcuPilot/Screen/Tool/NamespaceCopyMappings.cls` (new, `osmgmt.namespaces.copymappings`, on the `AuditCopy` model):
  - `DESCRIPTORCLASS` `NamespaceList`, `PORTCLASS` `NamespacePort`;
  - `READTYPE` `GET`, `WRITETYPE` `MAPPINGS`, `SENDSBODY` 0, `DESTRUCTIVE` 1, `CHANGEACTION` `updated`;
  - `SCREENACTIONS` `copy-mappings`, `SCREENVALUES` `copy-mappings=SourceNamespace`, `SettableFields` `SourceNamespace`;
  - `READANSWERS` and `FINGERPRINTSUBJECT` `Globals,Routines,TempGlobals`, `PRECONDITIONFIELD` `Globals`.
  - `PortQuery` passes `SourceNamespace`. `ArgumentProblem` and `ScreenActionDelta` refuse an absent source or the destination itself (ignoring case) before any task is queued. `Consequence` answers `NAMESPACE.COPYMAPPINGS`.
  - `PrivilegePairs`: the list's pairs, plus `%Admin_Operate:USE`, plus `%DB_IRISSYS:WRITE` unless Task 0 dropped it, then the `WithClassicPages` union (above).
  - `NamespacePort`'s `GET` answers the vendor object with an empty `SourceNamespace` (`AuditPort`'s DATABASE precedent), so the merge makes the one diff row.
- `Prohibited.cls`, `Namespace` predicate: a `MAPPINGS` write branches before `ReviewedFewOnly`.
  - When the destination is own or `%ALL`, read the source's three lists as the caller: `Kernel.Shell.Effective.Gate`, then `Screen.Read.Execute(<Kind>MappingList, CopySourceCap(), …, .criteria)` with `criteria("namespace")` set to the source. This follows the `Impact.ListRows` idiom.
  - `CopySourceCap()` is a new class method answering `""` (the default cap).
  - A row whose `Name` begins with `ocupilot` ignoring case, a gate refusal, or a list answering `truncated` is refused `OCUPILOTMAPPING`. Otherwise the copy is permitted.
- `Error.cls`: `NAMESPACE.SOURCE.ABSENT` takes the absent reason, and `NAMESPACE.SOURCE.SAME` reads "Choose a namespace other than this one."
- `Baseline.cls`: add `"osmgmt.namespaces.copymappings": true`.
- `NamespaceList.cls`: `rowActions` gains `{copy-mappings}`.
- `ui/src/app/areas/os-management/namespace-list.page.ts` (new, in the `AuditUserEventListPage` shape) and `copy-mappings-dialog.ts` (new, on the `audit-copy-dialog` model):
  - The wrapper renders `<app-list-page/>`, the dialog and a `role="status"` operation line.
  - It registers `copy-mappings` after injecting the handler, and `copy-mappings` joins `UNDRAWN_ACTIONS`.
  - The dialog's select offers `NamespaceList`'s read, through the ordinary read route, minus the destination. It shows the consequence and Copy.
  - The running line becomes the done line or `auditDatabaseStillRunning`, taken from `continued()`. The client never polls the vendor task.
  - Register the wrapper for `NamespaceList` in `DESCRIPTOR_PAGES`.

**EXPERIENCE.md edits (in place, keeping 993 lines) and `strings.ts` (append; each key cites its row):**

- `:164`: the third cell reads "Namespaces (Stage 2, Stories 18.2 and 18.14: its editor links a namespace's global, routine and package mappings)".
- `:173`: "global, routine and package mapping" joins the delete confirmations, and "copy mappings (Story 18.14)" joins the dialogs.
- `:378` gains these literals, and its where-clause ends `[ADDED 2026-09-28 - Story 18.14]`:
  - "Global mappings" · "Routine mappings" · "Package mappings" · "Global mapping" · "Routine mapping" · "Package mapping" · "Lock database" · "Collation"
  - "This namespace has no global mappings." · "This namespace has no routine mappings." · "This namespace has no package mappings."
  - "map a global" · "map routines" · "map a package" · "change this mapping"
  - "This maps a system global. Code in this namespace that uses it reads the mapped database instead of the system's own."
  - "Copy mappings" · "Copies every mapping of the chosen namespace into this one. A mapping this namespace already has under the same name is replaced; its other mappings stay." · "Copying mappings from <source> into <namespace> on the instance since <time>" · "Copied the mappings of <source> into <namespace>."
  - 18 prompts, three per screen:
    - global list: "Which globals does this namespace read from another database?" · "Is any system global mapped in this namespace?" · "Which database holds this namespace's mapped globals?"
    - routine list: "Which routines does this namespace run from another database?" · "Which routine mappings use a wildcard?" · "Where do this namespace's mapped routines come from?"
    - package list: "Which packages does this namespace load from another database?" · "Is any package here mapped to a database outside this namespace?" · "Which database does this package load from here?"
    - global form: "What does mapping a global to another database change?" · "When should a global mapping name a subscript range?" · "What does a global mapping's lock database do?"
    - routine form: "What does mapping routines to another database change?" · "How do I map only one routine type?" · "Can a routine mapping use a wildcard?"
    - package form: "What does mapping a package to another database change?" · "Does a package mapping include its subpackages?" · "Which database should this package mapping name?"
- `:479`:
  - "This namespace stops reading these globals from the mapped database and reads its default database again. No data is deleted. This cannot be undone."
  - "This namespace stops running these routines from the mapped database. The routines themselves stay. This cannot be undone."
  - "This namespace stops loading this package's classes from the mapped database. The classes themselves stay. This cannot be undone."
- `:481`: "Mappings whose names begin with OcuPilot keep OcuPilot's own globals and code where it expects them. In the namespace OcuPilot runs in, and in %ALL, they cannot be added, changed, removed or copied in."

**Tests.** Each stateful class refuses to run unless `OCUPILOT_ALLOW_NAMESPACE_CONFIG` reads 1, and the principal classes also need `OCUPILOT_ALLOW_PRINCIPALS`. Each runs `RemoveAll` before all tests, after each and after all, and a survivor fails the class.

- `src/OcuPilot/Test/MappingProbe.cls` (new; not a test case; on the `NamespaceWriteProbe` model):
  - Probe namespaces `OCUPROBE1814A` and `OCUPROBE1814B` over `USER`, created and removed through `AdminPort`. The namespace delete takes their mappings with it.
  - Mapping names begin with `OcuProbe1814`.
  - `%SYS` seeding helpers for all three kinds (test-only), and `CpfValid`.
- `src/OcuPilot/Test/MappingWrite.cls` (new): each Part A matrix row on both callers (the agent's mint and confirm; `MappingSave` and the screen-action route).
  - The `%` legs assert the proposal row's `destructive` and `consequence`.
  - The install-namespace legs run through `AcceptPort` with `ReadThrough(1)`, so a removed predicate records a write instead of making one.
  - The `%ALL` legs call `Prohibited.Prohibits` directly with a `%ALL` target.
- `src/OcuPilot/Test/MappingRefusals.cls` (new):
  - the edit of a mapping deleted since the read (the Save answers 404 and the confirm `TARGETCHANGED`);
  - a key outside the template; the routine suffix;
  - the #451 delete, with both mappings surviving;
  - `NamespacePort`'s malformed id (404, no vendor call);
  - a lower-cased namespace part reaching the vendor upper-cased.
- `src/OcuPilot/Test/MappingWriteGate.cls` with `MappingWriteGateProbe.cls` (new, on the `NamespaceWriteGate` model; port calls are counted through `DeviceRecordPort`):
  - A reader holding the two screen pairs reads the three lists and the form choices.
  - A writer without `%DB_IRISSYS:WRITE`, and a copier without `%Admin_Operate:USE`, are refused 403 naming the pair, with zero port calls, on both callers.
  - Holders of exactly the declared pairs create, edit and delete a mapping, and copy (AD-29).
- `src/OcuPilot/Test/MappingDescriptor.cls` (new, stateless):
  - the six declarations, and the ten tools' fields, kinds and pairs;
  - the `CLASSICPAGES` roster, read from the registered tools: the four namespace tools and the six mapping create and update tools with the pages above, and no other registered tool;
  - each declared page is a compiled class whose `%Dictionary.CompiledClass` `Name` equals the declared spelling;
  - the Integration legs: each `osmgmt.<kind>mappings.read` answers the rows its list's read answers, every row carries `namespace`, and a missing criterion answers 400 `READ.CRITERION`.
- `src/OcuPilot/Test/NamespaceCopy.cls` (new): the copy matrix rows on both callers.
  - `QUEUEDWRITES` admits `MAPPINGS`.
  - The started path runs through `NamespaceStartedPort`, `NamespaceStartedAction` and `NamespaceStartedConfirm` (the `AuditStarted*` seams, with a zero bound). The confirm answers `continues`, and the route answers `continues: true`.
  - The copy-into-own legs run through `AcceptPort`, from a probe source seeded with an `OcuPilotProbe1814` global mapping, which is refused.
  - The cut-list leg seeds the source with two ordinary mappings and reads it through `Test/MappingProhibitedFixture`, a `Prohibited` subclass whose `CopySourceCap()` answers 1. It is reached through the `ProhibitedClass` seams of `ScreenAction` (:50) and the confirm fixture, and the copy is refused.
- `src/OcuPilot/Test/ClassicPageGate.cls` (new, on the `NamespaceWriteGate` model, reusing `NamespaceWriteGateProbe` and `MappingWriteGateProbe` for the child-process legs):
  - Before all tests:
    - record each declared page's custom resource through `%CSP.Portal.Utils.%GetCustomResource`;
    - create the probe resource `OcuProbe1814Page` (test-only `%SYS`);
    - create two principals: `OcuProbe1814PageLacking`, holding every pair the declaring tools declare except the page resource, and `OcuProbe1814PageHolding`, holding those plus `OcuProbe1814Page:USE`.
  - For each tool on the `CLASSICPAGES` roster (derived from the registry), assign `OcuProbe1814Page` to its page with `%SetCustomResource`. The lacking principal's mint is then refused 403 `AUTH.NOPRIVILEGE`, with `detail.failedPair` `OcuProbe1814Page:USE` and zero port calls. Then restore the page.
  - For the namespace create's Save, the namespace delete's row action and the global mapping create's Save, run the same refusal on the screen's caller. The holding principal is admitted on both callers, and its write reaches the recording port.
  - With no assignment, each tool's `PrivilegePairs` equals its declared set.
  - After each test and after all tests, restore every page to its recorded value, then remove the probe resource and the principals. A page that does not read its recorded value fails the class.
- `scripts/ci-throwaway.sh`:
  - The NAMESPACE_CONFIG `# classes:` line gains `ClassicPageGate, MappingRefusals, MappingWrite, MappingWriteGate, NamespaceCopy`.
  - The block's comment gains "and assigns a probe custom resource to the classic namespace and mapping pages, restoring each".
  - The principals block gains `ClassicPageGate` and `MappingWriteGate`.
- Rosters, re-derived from the code and from each class's red, never hand-counted: every roster the Code Map lists.
  - `Descriptor`'s entity count reads 36. `ReadTool` reads 147: 134 plus three reads and ten writes.
  - The `Prohibited` and `AuditingUpdate` code counts read 20. `Navigation` shows 18 OS management screens.
  - `KERNEL_REFUSALS` gains `OCUPILOTMAPPING`.
  - `ToolWrite`'s `tOtherPorts` grows by ten `NamespacePort` tools, and `REFUSEEMPTY` gains ten entries.
  - `EndpointCoverage` gains four routes, and `SurfaceCoverage` gains a row per descriptor and tool.
- Client specs:
  - `mapping-form.page.spec.ts`, `mapping-form.store.spec.ts`, `namespace-list.page.spec.ts` and `copy-mappings-dialog.spec.ts` (new);
  - `namespace-form.page.spec.ts`, for the Mappings line;
  - `navigation.test.mjs`, where `parentListFor` of each mapping list is `NamespaceList`;
  - `entity-ref.test.mjs` and `screen-mirror.test.mjs`, for the rule; `strings.test.mjs`.
- `ui/browser/namespace-mappings.browser-spec.mjs` (new, on the `namespaces.browser-spec` model; cleanup by exact probe name through `docker exec ocupilot-b-ci`):
  - From a probe namespace's editor, the Mappings line opens each list.
  - A global mapping is created, edited from its name cell and deleted with its typed name.
  - The `%` line appears under Name.
  - Copy shows the running line, then the done line.
  - The DW-1337 walk runs in both themes over a list, the form and the copy dialog.

**Acceptance Criteria:**

- **AC1:** Given a probe namespace holding one mapping of each kind on `ocupilot-b-ci`, when a holder of the Namespaces pairs opens its editor, then a Mappings line links the three lists.
  - Each list shows exactly the rows its read tool `osmgmt.<kind>mappings.read` answers for that namespace.
  - Each row's id carries the namespace.
  - Each list's locator links back to Namespaces.
  - No list takes a side-bar position.
- **AC2:** Given those lists, when a person creates a mapping from Create, edits it from its name cell and deletes it with the typed name, then each operation round-trips through `PUT` or `DELETE /namespace/<kind>-mapping`:
  - A create answers 201. An edit sends the complete template set. After a delete, the row is absent once the change event arrives.
  - The agent's confirmed `osmgmt.<kind>mappings.create`, `.update` and `.delete` do the same, addressed by the row ids the read returned.
  - A taken name, an absent database, a lower-case routine suffix, and a base-global delete while subscript mappings exist are each refused on the named field, and the instance is unchanged.
- **AC3:** Given a global mapping named `%OcuProbe1814` or `%OcuProbe1814("a")`, when the agent proposes it or a person saves it, then it is permitted.
  - The agent's card is destructive and states the system-global consequence.
  - The form shows that sentence under Name before Save.
  - A routine mapping, a package mapping, a delete and a list read carry no such effect.
- **AC4:** Given the install namespace or `%ALL`, when either caller creates, changes or deletes a mapping whose name begins with OcuPilot in any case, then it is refused `PROHIBITED.OCUPILOTMAPPING` and no write reaches the port. The same name in a probe namespace is permitted.
- **AC5:** Given least-privileged principals on the throwaway, when they call the mapping and copy tools, then:
  - the two screen pairs read the lists and the form choices;
  - a write missing a declared pair is refused 403 naming that pair, with zero port calls, on both callers;
  - a holder of exactly the declared pairs writes.
- **AC6:** Given two probe namespaces, when Copy mappings is chosen on the destination's row and a source is picked, then:
  - The dialog shows "Copying mappings from <source> into <namespace> on the instance since <time>", then "Copied the mappings of <source> into <namespace>.".
  - The destination holds the source's mappings. Same-named ones are replaced, and its other mappings stay.
  - The write took `AdminPort`'s async path, admitted by `QUEUEDWRITES`, with one poller that read the finished task's result once. The agent's confirmed `osmgmt.namespaces.copymappings` does the same.
  - A copy still running past the port's bound is recorded applied and marked, and both callers say "Still running on the instance. It finishes in the background.".
  - The bad-source and copy-into-own matrix rows are refused before any task is queued.
- **AC7:** Given a probe custom resource assigned on `ocupilot-b-ci` to a classic page that a namespace or mapping write tool declares it performs, when a principal holding every other declared pair calls that tool through the agent's mint or the screen's Save or row action, then:
  - it is refused 403 `AUTH.NOPRIVILEGE` naming `<resource>:USE`, with zero port calls;
  - a principal also holding the resource is admitted;
  - with no assignment, the tools' pairs are unchanged;
  - each page's custom resource reads afterwards exactly as it did before.
  - The pages are the New Namespace page, the Edit Namespace page, the Delete Namespace dialog, and each mapping kind's dialog.
- **AC8:** Given the new screens and the copy dialog, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays below 3800 kB. If it passes `maximumWarning` (2107 kB), the warning is re-based under DW-1166 together with the literal at `angular-json.test.mjs:384`.

### Review Findings

Code review 2026-09-28 (`review_tier: full-opus`; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor).

- [x] [Review][Defer] The own-mapping predicate matches only names that begin with `OcuPilot`, so a wildcard covering them (`Ocu*`, `O*`) in the install namespace or `%ALL` is permitted and would redirect OcuPilot's class routines (inference) [src/OcuPilot/Kernel/Proposal/Prohibited.cls:1783] — deferred: DW-1803 `decision-pending`, widening AD-10's rule is the owner's call.
- [x] [Review][Patch] A refused list delete shows only "The mapping was refused."; the one field sentence (#451's "Delete this global's subscript-level mappings first.") never reaches the list [src/OcuPilot/Port/NamespacePort.cls:126]
- [x] [Review][Patch] `ClassicPageGate`'s screen-caller legs assign every page at once, so the create Saves are refused by the form's own classic page and never prove the create tool's `CLASSICPAGES` union [src/OcuPilot/Test/ClassicPageGate.cls:196]
- [x] [Review][Patch] The DW-1337 walk never measures the copy status line while it holds text, and its comment claims a mutation that cannot redden [ui/browser/namespace-mappings.browser-spec.mjs:450]
- [x] [Review][Patch] `MAPPING.DATABASE.REQUIRED` and `MAPPING.NAME.REQUIRED` are raised by no test [src/OcuPilot/Test/MappingRefusals.cls:181]
- [x] [Review][Patch] The bad-source test compares against `ReasonForViolation`, so a missing sentence arm reads `""` and `[ ""` always passes [src/OcuPilot/Test/NamespaceCopy.cls:136]
- [x] [Review][Patch] `MappingUpdate.CreateTool` and `MappingDelete.InputSchema` find the create class by editing `$ClassName()`, which names no class for a subclass such as `Test.SeamGlobalMappingDelete` [src/OcuPilot/Screen/Tool/MappingUpdate.cls:75]
- [x] [Review][Patch] `ClassicPageGate.TestWithNoAssignment...` skips a tool that fails to resolve, silently and with the previous tool still in `tTool` [src/OcuPilot/Test/ClassicPageGate.cls:117]
- [x] [Review][Patch] EXPERIENCE.md's kernel-refusals row says the namespace Delete advisory "states the last", which now names the mapping sentence [_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:481]
- [x] [Review][Patch] `MappingWriteGate`'s header says four users and four roles; it creates three of each [src/OcuPilot/Test/MappingWriteGate.cls:12]
- [x] [Review][Patch] The Verification line for `NamespacePort.Refused` says "alone red", which predates `TestANameTheInstanceRefusesAnswersOnName` [spec ## Verification]
- [x] [Review][Defer] The form read and name check are never called by a principal lacking the screen's pairs [src/OcuPilot/Area/OsMgmt/MappingRules.cls:217] — deferred: DW-1804 `wontfix-accepted`; the gate is the shared `Screen.Gate.Evaluate`, and 18.2's `/namespace/form` has the same untested denial.

Verified on the recreated `ocupilot-b-ci` after the patches:

- ObjectScript: `MappingRefusals` 8/8 (run 11), `ClassicPageGate` 3/3 (run 16), `NamespaceCopy` 7/7 (run 17), `MappingDescriptor` 6/6 (run 18) and `MappingWrite` 9/9 (run 19).
- Client: `namespace-mappings.browser-spec` 4/4 on the rebuilt bundle, and `npm run test:tools` 1688/1688.
- `check-objectscript` and `lint-docs` clean, with EXPERIENCE.md still 993 lines.

Lead action, not a code finding: AD-8's Story 18.14 paragraph in the spine still lacks the copy's `%DB_IRISSYS:WRITE` sentence from the Spec Change Log (Rule 20).

Ledger adjudication of this story's in-story LOWs: DW-1799 `wontfix-accepted` (the vendor's Collation is a number with no empty form); DW-1800 `wontfix-accepted` (every form's locator segment opens its own route; this one lacks its namespace); DW-1801 `by-design` (the form takes its namespace from the route and draws no Namespace control, so its summary shows the sentence).

Rejected:

- `false`: the global list keys subscript mappings apart. The vendor LIST's `Name` is the whole mapping name; the endpoint drops only `Global`.
- `false`: the copy's status line does not stick on a network fault. `requestJson` answers a `kind` and never rejects.
- `false`: `READANSWERS` and `FINGERPRINTSUBJECT` carry `SourceNamespace`. The port reads it empty, and the stored source is fingerprinted by design.
- `false`: the `ci-throwaway.sh` comment's scope is right. Every mapping written, `%` and `OcuPilot` names included, is in an `OCUPROBE1814*` namespace.
- `low`, spec-bound:
  - `MAPPING.NAME.SHAPE`'s routine-suffix sentence on every kind;
  - no effect for `%` routine or package mappings (AC3);
  - no own-mapping refusal in `%SYS`, since the spec and AD-10 name the install namespace and `%ALL`;
  - the fail-closed copy refusal's sentence;
  - the copy card stating no system-global effect;
  - AC6's "dialog shows" wording;
  - the spec's "20 new classes" count.
- `low`, not worth the added branch:
  - `$Char(1)` in a Save's name, which the form cannot type;
  - a source deleted between mint and confirm, where the task fails and copies nothing;
  - the fresh-read-to-PUT and Taken-to-PUT windows, milliseconds inside one request, which AD-4 and AD-54 accept;
  - an empty-diff Save from a direct API caller;
  - a boolean `Collation`;
  - `Update` asking the rules before the prohibited set, which is still refused with nothing sent;
  - `Snippet` not mirroring the caller-body refusal, as in `AuditPort`, since a stored bodyless proposal has no body;
  - a principal without write on the destination's globals database copying package mappings, which logs the vendor's severity-2 extent-index line and still applies;
  - the copy outrunning the 30 s bound on a loaded shard, where the measured copy took 2 s;
  - AC8's 3800 kB, the implement stage's stop-and-ask rule, measured at 2,110,488 B under the enforced 4000 kB.
- `low`, vacuous if fixed: "zero port calls" on `ClassicPageGate`'s mint legs. The dispatch path never reaches the recording port.

### Rework iteration 1 (DW-1803, DW-1798, orchestrator decisions)

- [ ] [Decision] DW-1803 (owner, by=merge_gate 2026-09-28; AD-10's own-mappings bullet as amended): `PROHIBITED.OCUPILOTMAPPING` refuses, in the install namespace (the evaluating process's `$NAMESPACE`) or `%ALL`, any global, routine or package mapping whose name pattern or range overlaps an OcuPilot package, routine or global name -- `O*`, `Ocu*`, `*`, a subscript range or routine range spanning an `OcuPilot` name -- not only a name beginning with `OcuPilot`; a copy into either namespace from a source holding such a mapping is refused the same way. Read OcuPilot's names from the instance (its package mapping and state-database mapping, `Kernel/State/Base` `MAPPINGPATTERN`), never a second literal. Pin the overlap cases (`O*`, `Ocu*`, `*`, a range) with tests on both callers through the recording/accepting port, plus a permitting leg (`Q*`, `Zz*` in the install namespace, and any pattern in another namespace), and a Rule 19 mutation that puts the prefix match back.
- [ ] [Decision] DW-1798 (owner, by=merge_gate 2026-09-28; AD-21's sixth case as amended): `PathPort.Resolve` refuses an overwriting consumer (`file` with `pOverwrite` 1) any existing file in OcuPilot's own served files -- the static application's directory (`csp/ocupilot/`, read from the instance's own application definition or the installer's roster at call time, never a literal path) and whatever the installer deploys there -- with `PATH.INSTANCE`; a new name elsewhere is unaffected. Pin it with a `PathPortInstance` leg and a Rule 19 mutation.

## Spec Change Log

- 2026-09-28, spec gate (runner): the orchestrator split the story for risk (Rule 5, by=merge_gate): Part C, SA-13's enable-interop with its Task 0 observation (DW-1776), moved to Story 18.15, which runs after 18.4; the intent block was cut to Parts A and B. The owner's DW-1784 decision (AD-44 amended: a screen replacing several classic pages unions each replaced page's custom resource into its write tools' pairs) joined the scope, routed here, with the namespace tools 18.2 shipped included. The orchestrator's 18.4 note applies to the copy: read a finished async task's result exactly once, one poller per task. The spec is `draft` for a re-plan; the first plan's Part C stays in this file's history at commit `4b73be11`.

- 2026-09-28, spec gate (runner, after the re-plan): the six proposed amendments under Design Notes were written into the spine verbatim (Rule 20) -- AD-8 (a paragraph), AD-10 (a bullet), AD-26 (a paragraph, with the read-once rule), AD-36 (a paragraph), AD-51 (a named case) and AD-44 (appended to the DW-1784 paragraph). Accepted at the gate: the update and copy also declare classic pages, as "every classic page whose operation it performs" reads.

- 2026-09-28, implement (Task 0), for the runner (Rule 20): AD-8's Story 18.14 paragraph gains the sentence "`osmgmt.namespaces.copymappings` also declares `%DB_IRISSYS:WRITE`: a principal holding the Namespaces screens' pairs and `%Admin_Operate:USE` was answered 500, its queued copy failing `<PROTECT>` in `Config.Namespaces.CopyMaps` with the destination unchanged (measured on `ocupilot-b-ci`, 2026-09-28)."
- 2026-09-28, runner: the implement commit (first 12a936cc) was moved by cherry-pick to 35f085bc on top of 18.1's DW-1790 fix, which the orchestrator ordered first; the code is byte-identical, and the review baseline is `c267f6da`, the cherry-pick's parent (`baseline_commit`), since `baseline_revision` 57c4a1d7 now also spans the DW-1790 commits.
- 2026-09-28, rework iteration 1 (runner): re-opened after the first code review (no HIGH) on two owner decisions the orchestrator directed into this story: DW-1803 (the own-mappings refusal by overlap) and DW-1798 (PathPort refuses an overwrite of OcuPilot's served files, folded here instead of a separate commit). AD-10 and AD-21 carry both rules.

## Review Triage Log

### 2026-09-28 — Review pass

- verdicts: 28 findings — high 0, medium 5, low 17, false 6, maybe-false 0
- findings:
  - `[medium]` `[patch]` vendor name refusals (`PROPERTYFAULTS` `MAPPING.NAME.SHAPE`) reached by no test — added `MappingRefusals.TestANameTheInstanceRefusesAnswersOnName` (global unclosed subscript, routine and package hyphen; Save 422 on Name, confirm 422, nothing created), mutation recorded.
  - `[medium]` `[patch]` `Validate`'s namespace-absent and collation rules and the form read's 404s untested — added `MappingRefusals.TestAnAbsentNamespaceAndABadCollationAreRefused` through `MappingAcceptPort`, mutation recorded.
  - `[medium]` `[patch]` mapping violation codes' sentences and `Rules(kind)` not pinned as the namespace codes are — added `MappingDescriptor.TestEachViolationCodeCarriesASentenceAndItsField`, mutation recorded.
  - `[medium]` `[patch]` the locator's composite-id label untested — added a `locator-bar.spec.ts` case, mutation recorded.
  - `[low]` `[patch]` `NamespaceCopy`'s task-count comparison could pass with an unreadable list — added the `tTasks >= 0` floor, mutation recorded.
  - `[low]` `[reject]` AC2 absent-database and suffix legs carry no own mutation line — Rule 19 asks one demonstrated mutation per AC and AC2 has several; writing more is not a direct correction.
  - `[low]` `[reject]` AC2 edit-sends-complete-set leg has no own mutation line — same reason.
  - `[low]` `[reject]` AC2 taken-name Save leg not shown load-bearing by the `CREATES` mutation — the Save leg asserts the `MAPPING.NAME.TAKEN` violation by code; the AC's line stands.
  - `[low]` `[reject]` AC3 delete-carries-no-effect has no own mutation line — same per-AC reason.
  - `[low]` `[reject]` AC5 positive halves have no own mutation line — same per-AC reason; AC5 carries two lines.
  - `[low]` `[reject]` AC6 bad-source leg has no own mutation line — same per-AC reason; AC6 carries three.
  - `[low]` `[patch]` AC6 copy-into-own and cut-list mutations only in doc comments — demonstrated the `CopiesOwnMapping` mutation and recorded it.
  - `[low]` `[reject]` AC6 destination-contents mutation only in a doc comment — same per-AC reason.
  - `[low]` `[reject]` AC7 restore check has no mutation line — it is the class's teardown contract, and every run since left each page reading empty.
  - `[medium]` `[patch]` `ClassicPageGate.TestWithNoAssignment...` built its expected pairs through `WithClassicPages` itself — expected set now built from the recorded pages, mutation recorded.
  - `[low]` `[patch]` stray `MappingQuery` call in `MappingRefusals.TestTheCompositeIdIsSplit...` — deleted.
  - `[false]` `[reject]` the mint answers `TOOL.ARGUMENTS` with the rule's sentence rather than the matrix's code — the spec's Tasks route these through `ArgumentProblem`, the mint's convention; the Save answers the codes on their fields.
  - `[false]` `[reject]` the routine suffix reaches a port read at the mint — the mint's absence `GET` is a read; no write reaches the port (`WriteCount` 0), which is what the matrix row guards.
  - `[low]` `[reject]` tests assert route statuses, not the vendor's — the Taken rule precludes an upsert over an existing mapping; recording vendor statuses adds a seam for no user harm.
  - `[false]` `[reject]` mapping deletes declare no `CLASSICPAGES` — by the spec's Tasks and AD-44 as amended; the descriptor's `%CSP.UI.Portal.Mappings` union predates this story (`ScreenGate`).
  - `[low]` `[reject]` missing-pair coverage limited to the spec's legs (3 screen legs, global kind, copy `%DB_IRISSYS:WRITE` by declaration) — the declared pairs are pinned by `MappingDescriptor`, `ProposalPrivilege` and `ToolEmit`.
  - `[low]` `[reject]` `%ALL` exercised only through the predicate — the spec's plan; `IsOwnMappingNamespace`'s `%ALL` arm is shared by the copy.
  - `[low]` `[reject]` the Lists row's probe-namespace form runs only in the browser spec — covered there, 4/4.
  - `[false]` `[reject]` the client sends only the changed field — AD-4's complete set is the server's merge, asserted at `MappingRecordPort`.
  - `[low]` `[reject]` no Save confirmation for a `%` global and no edit-mode page test of its line — the spec's ruling puts the screen's confirmation at the field line.
  - `[false]` `[reject]` read-once tested only indirectly — provoking a second read is forbidden by the orchestrator; the logs held no #7846 after the full sweep.
  - `[low]` `[reject]` `SourceHeld` reads a non-404 failure as held — the pair gate precedes it, and the vendor then fails the task #420.
  - `[false]` `[reject]` regeneration of `screens.generated.ts` and `ToolFields.cls` unverifiable — `npm run build`'s prebuild ran `screen-mirror.mjs --check` and `field-lists.mjs --check`, both clean.

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: every call goes through `AdminPort` or `NamespacePort`, which extends it.
- AD-3: derived field lists. AD-4: an edit sends the complete set.
- AD-5, AD-36: one descriptor per screen, and each list and its tool read one read with the parent key seeded.
- AD-6, AD-34, AD-40: proposal and confirm, and the gates at the write.
- AD-8, AD-29: the pairs and the extra pairs.
- AD-44: each descriptor's classic page, and, per the DW-1784 amendment, each write tool's replaced pages.
- AD-10: `OCUPILOTMAPPING`, and the strongest-confirmation `%` effect.
- AD-13, AD-14: the new types, the new rule, and the change events (`secondaryEntityTypes`).
- AD-15: the marker. AD-16: `%SYS` only through the port. AD-21: no path field. AD-22: the baseline lines.
- AD-26: one queued write. AD-39: violations and `PROPERTYFAULTS`. AD-51: an action, and the copy's port-built body.
- AD-53, AD-55: two callers of one tool. AD-54: the create's absence fingerprint.
- AD-58: the read-back, where a 202 is `unchecked` and reads nothing. AD-59: `Snippet` for every `NamespacePort` branch.

**Measured on `ocupilot-b-ci`, 2026-09-28** (18.2's first plan, `f473ce9b`; every probe object was removed):

- **Mapping writes.** For each kind, `PUT …-mapping?namespace=&name=` answers 201 on create, and 200 on edit while keeping omitted fields. `DELETE` answers 200, or 404 #421 when the mapping is absent.
- **Subscripts.** Creating `G("a"):("m")` also creates `G` on the namespace's default database. `DELETE G` while a subscript mapping exists answers 500 #451.
- **Names.** `%`-named globals and packages are accepted. `X_mac` creates `X_MAC`, then answers 500. The vendor's name refusals are #5854 and #448.
- **Lists.** A list for an absent namespace answers 200 `[]`. A subscript mapping's list row shows Collation 0 where its `GET` shows 5, so the read-back uses the `GET`.
- **Copy-mappings.**
  - `POST /namespace/copy-mappings` answers 202 with a location.
  - The poll carries `{State, TaskName, Console, FailureReason, Result:{}, TimeQueued, TimeStarted, TimeFinished}` and no progress field, so "progress" is a running line, then done or still running.
  - The task finished within 2 s. The copy merges, and the source wins on a same name.
  - An absent source still gets 202, then `Failed` #420, which is why the tool refuses it first.
- **Pairs.** Every mapping write needs `%DB_IRISSYS:WRITE`: without it the answer is `<PROTECT>`, and nothing changes. The poll needs `%Admin_Operate:USE` and is owner-only.
- **Not measured, left to Task 0:** the copy's `%DB_IRISSYS:WRITE`, the LIST's case handling, and the read-once check.

**Measured at implement** (Task 0, `ocupilot-b-ci`, 2026-09-28; probe namespaces `OCUPROBE1814A`/`B`/`C`, two probe principals and a probe port class, all removed):

- **LIST case.** `namespace=user` and `namespace=USER` answered the same rows (117 global, 1 routine, 4 package), and so did `hscustom` against `HSCUSTOM` (120, 3, 8). `NamespacePort` does not upper-case a LIST's `namespace`.
- **LIST keys.** Global rows carry `{Name, Subscript, Database, Collation, LockDatabase}`, routine rows `{Name, Type, Database}`, package rows `{Name, Database}`. Every row of all six reads carries `Name`. `HSCUSTOM`'s own mapping reads `{"Name":"OcuPilot*","Database":"OCUPILOT",...}`.
- **Copy without `%DB_IRISSYS:WRITE`.** A principal holding the install namespace's code read, `%DB_IRISSYS:READ`, `%Admin_Manage:USE` and `%Admin_Operate:USE` was answered 500: the queued task failed `<PROTECT>CopyMaps+12^Config.Namespaces.1 ^SYS("CONFIG","IRIS","MapGlobals",...)`, and the destination was unchanged. With `%DB_IRISSYS:RW` added, the copy answered 200 and the destination held the source's three mappings. The copy tool keeps `%DB_IRISSYS:WRITE`.
- **Read once.** After three copies through the async path, each read once by `AwaitTask`, neither `messages.log` nor `alerts.log` held ERROR #7846. `$SYSTEM.Monitor.State()` read 2 before and after, already raised by earlier severity-2 lines. A copy that carries a package mapping, made by a principal without write on the destination's globals database, logs a vendor severity-2 line (`Error rebuilding Extent index: <PROTECT>RebuildExtentIndexNS`), and the copy still applies.

**Decisions:**

- **Mapping identity.** The vendor rows carry no namespace, and the mint's fresh read sends one id parameter, so the id is the composite `[namespace, Name]`.
  - The list seeds the namespace, and `NamespacePort` splits the id and upper-cases its namespace part.
  - `foldcase-firstpart` lowers that part at the identity layer.
  - `SPLITQUERIES` is not used, because a subscript can hold `/`.
- **Seeding is implicit.** It applies when the id's first part is named like the one criterion. `TableProblem` already forces the part into `read.fields`, and no shipped list has this shape: `TaskRunList`'s `TaskId` against `taskId` differs by case.
- **Placement.** A list's name cell reaches one editor or one child list, never three (`data-table.ts:587-615`), so the namespace editor links the three lists, and `parentListFor` is widened so each list links back. The copy action is page-owned, because the lazily built handler overwrites registrations and `ListPage` hosts no running line.
- **The #451 delete is mapped, not pre-read.** The vendor refuses it and changes nothing, so `PROPERTYFAULTS` is the one mechanism. The routine suffix is refused before any call, because the vendor applies it and then fails.
- **No `VERIFIEDDELETES` for mappings.** Nothing measured answers a delete wrongly, and AD-58's read-back already expects absence.
- **The `%` guard.**
  - The harvested rule's `force` becomes AD-10's strongest confirmation, under the owner's developer-tool-first direction. No request field bypasses it.
  - Coverage widens to every `%` name, because the vendor creates the base mapping for a subscript (measured for a non-`%` global; for `%`, an inference).
  - Coverage also takes in edits.
  - It lives in the kernel's `WeakensByEffect`, which `Mint` asks on a create of this one type.
- **Copy is destructive on the agent's card**, because it replaces same-named mappings. On the screen, its dialog is the confirmation (EXPERIENCE `:173`), not a typed-name delete.
- **Read once, one poller (orchestrator rule).** `AdminPort.AwaitTask` is the only reader of a copy task. It reads the finished result once and stops at the finish or the bound. A started copy is never re-read: AD-58 records it `unchecked`, and the still-running line comes from `continues`.
- **Governance.** The nine mapping writes and copy join the baseline `true`, by orchestrator ruling.
- **DW-1784: where the replaced pages are declared.**
  - On the tool, not the descriptor, because one list's tools perform different classic pages' operations.
  - `PrivilegePairs` is the one method every gate calls at call time: the mint, the confirm, the screen-action route and the Save. The union there therefore reaches both callers and is never cached.
  - A page whose operation the descriptor's own classic page already performs is not redeclared. The mapping deletes happen on `%CSP.UI.Portal.Mappings`.
  - Update declares the Edit Namespace page and copy the New Namespace page, because AD-44 names every page whose operation a tool performs. `%CSP.UI.System.ExpResultPage` is not declared: it only renders the copy's result, and no custom-resource check reaches it (inference, Code Map).
  - `ClassicPageGate` is the first test to prove any classic-page union against the real store. The descriptor union has so far been proven only through `ScreenGate`'s override.
  - `NamespaceForm` still declares only the Edit page. Its Save gate reads the create tool's pairs after the form's own, so the New Namespace page's resource gates the create Save.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate).** Task 0's copy measurement adds its AD-8 sentence through the Spec Change Log.

1. **AD-8, after the Story 18.2 paragraph:** "**Story 18.14's mapping and copy tools declare pairs beyond their screen's set** [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]: every global, routine and package mapping write declares `%DB_IRISSYS:WRITE`, because a principal holding only the Namespaces screens' `%Admin_Manage:USE` and `%DB_IRISSYS:READ` was answered `<PROTECT>` on every mapping write and nothing changed (measured on `ocupilot-b-ci`, 2026-09-28). `osmgmt.namespaces.copymappings` declares `%Admin_Operate:USE` under the endpoint clause, the `AsyncResult` gate the port polls the queued `Namespace.Namespace` `MAPPINGS` through. Each is refused by name before any port call."
2. **AD-10, a new bullet:** "**OcuPilot's own mappings** [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]: creating, changing or deleting, in the namespace OcuPilot's API runs in or in `%ALL`, a global, routine or package mapping whose name begins with `OcuPilot` in any case, and copying mappings into either namespace from a source that holds one, is refused `PROHIBITED.OCUPILOTMAPPING`, from either caller; the source's lists are read at the write and a list cut at its cap is refused. Such a mapping moves OcuPilot's protected globals out of its database (AD-9) or lets other code answer for its classes. A global mapping whose name begins with `%` shadows a system global for its namespace; it is **permitted at the strongest confirmation** (effect `MAPPING.SYSTEMGLOBAL`: the agent's proposal is minted destructive with the consequence, a person's Save shows it at the field), for a create as for a change, because the vendor creates a subscript mapping's base mapping too."
3. **AD-26, appended to the `QUEUEDWRITES` paragraph:** "…and `Namespace.Namespace` `MAPPINGS` (Story 18.14, copy-mappings, body `{SourceNamespace, DestinationNamespace}` built by the port, no secret), which the vendor queues through `ShouldRunAsync()` (read on this build); its finished result is read once, by the port's one poller [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]."
4. **AD-36, a new paragraph:** "**A parent-scoped list may carry its parent's key on its rows** [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]. Where a parent-scoped admin `LIST` answers rows without the parent's key (a namespace's mapping lists), and its composite id's first part is named like its one criterion, the read refuses a missing criterion as the single-object read does and seeds the criterion's value onto each row under that part before projection, so the row's id carries the namespace its write addresses. Screen and tool read the same seeded rows."
5. **AD-51, appended to the port-built body list:** "…and `NamespacePort`, which builds `Namespace.Namespace` `MAPPINGS`'s body from the destination (the target) and the tool's declared `SourceNamespace` (Story 18.14) [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]."
6. **AD-44, appended to the DW-1784 paragraph:** "A write tool names, in its `CLASSICPAGES` parameter, each classic page beyond its descriptor's `classicPage` whose operation it performs, as normalized class names spelled exactly; its `PrivilegePairs` unions each page's custom resource at `USE` through `Screen.Gate.WithClassicPages`, read on every gate call, so the mint, the confirm and a screen's Save refuse a caller without it by name before any port call. A page whose operation the descriptor's own classic page performs is not redeclared. Story 18.14's: the namespace create and copy-mappings `%CSP.UI.Portal.Namespace`, the update `%CSP.UI.Portal.NamespaceEdit`, the delete `%CSP.UI.Portal.Dialog.NamespaceDelete`, and each mapping create and edit its kind's `%CSP.UI.Portal.Mappings.<Kind>`; the mapping deletes, performed on `%CSP.UI.Portal.Mappings`, declare none [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]."

**Integration ACs:**

- AC1 is pinned by `MappingDescriptor` and the browser spec. Each mapping list and its read tool answer one read (AD-36), with the namespace seeded on every row.
- AC2 is pinned by `MappingWrite`. The mapping tools consume the seeded row ids through `NamespacePort`.
- AC6 is pinned by `NamespaceCopy`, the browser spec and `namespace-list.page.spec.ts`. The copy dialog consumes `NamespaceList`'s declared read, and the copy predicate consumes the three lists' reads.
- AC7 is pinned by `ClassicPageGate` on the throwaway's real store. The mint, the confirm, the screen-action route and the Saves consume `WithClassicPages` through each declaring tool's `PrivilegePairs`.

**Consumes:**

- 18.2's `NamespaceList`, `NamespaceForm`, `NamespaceRules.Databases`, the `namespace` type, and the namespace tools' `PrivilegePairs`;
- `AdminPort`, and the `AuditPort` and `AuditCopy` models;
- `Screen.Gate`'s classic-page union;
- the screen-action value path;
- 16.17's read-back, 14.1's `Snippet` and 14.2's baseline;
- the typed-name dialog and the panel's still-running line.

**Consumed-by:**

- 18.3: its database delete's impact reads the namespaces through `NamespaceList`, and its wizards and delete dialog declare `CLASSICPAGES`.
- 18.4: its dialogs declare `CLASSICPAGES`.
- 18.15: enable-interop reuses `NamespacePort`'s started conversion and the `namespace-list.page.ts` wrapper's page-owned action and running line, and declares `CLASSICPAGES` `%CSP.UI.Portal.Namespace`. The New Namespace page holds the classic enable (inference).
- 18.12: the agent's grown tool set.
- 18.13: multi-namespace install, under which `OCUPILOTMAPPING` and the install-namespace predicate must keep holding (DW-1788).
- AD-44's later applications (the resource, process-terminate and role-resource dialogs) have no story yet.

**Ledger inbox:** DW-1784 is addressed by the DW-1784 tasks and AC7, with the namespace tools 18.2 shipped included. DW-1774 is met, because no side-bar list changes.

**Contended with Epic 16, all edited add-only:** `Error.cls`, `Router.cls`, `Baseline.cls`, `strings.ts`, EXPERIENCE.md, the rosters, `ci-throwaway.sh` and `ci.test.mjs`. `screens.generated.ts` and `ToolFields.cls` are regenerated. `Screen/Area.cls` and `scripts/check-objectscript.py` are not touched.

## Verification

**Setup (slot B):**

- Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src`, and load it on `ocupilot-b-ci` only. MCP calls carry `server: "ocupilot-slot-b"`, and no admin API write reaches a dev instance.
- Every mapping, copy and custom-resource write happens there, on `OCUPROBE1814*` and `OcuProbe1814*` objects the tests create and restore.
- If the throwaway predates the arming block, arm stateful classes per call with `docker exec -e OCUPILOT_ALLOW_NAMESPACE_CONFIG=1`, adding `-e OCUPILOT_ALLOW_PRINCIPALS=1` for the principal classes.
- Run one test class per call. Start the next only once the previous run has landed in `%UnitTest_Result`.
- Before any browser run, run `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expected: 0 failures each, with totals checked against `%UnitTest_Result`. The classes:
  - `MappingWrite`, `MappingRefusals`, `MappingWriteGate`, `MappingDescriptor`, `NamespaceCopy`, `ClassicPageGate`;
  - `NamespaceWrite`, `NamespaceWriteGate`, `NamespaceRefusals`, `NamespaceDescriptor`, `ProposalPrivilege`;
  - `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Prohibited`, `RefusalCopy`;
  - `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `AuditingUpdate`;
  - `ToolWrite`, `ToolRoundTrip`, `DraftRegistry`, `AdminPortAsync`, `AuditStarted`, `EntityRef`;
  - `Navigation`, `Wire`, `WireSecurityRead`, `ScreenGrounding`, `Envelope`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/namespace-mappings.browser-spec.mjs browser/namespaces.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, with `wc -l` on EXPERIENCE.md reading 993.
- `(once, before dev_complete)`:
  - the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  - then `cd ui && npm test && npm run build`;
  - then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
  - Expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each to the throwaway's source copy, observe red, revert byte-identical, and record a `mutation:` line. Run predicate mutations only against `AcceptPort`.

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC1 | `Read.cls` seeds nothing | `MappingDescriptor`'s Integration legs; the browser spec's list legs |
| AC1 | `parentListFor` reverted to the first-child inverse | `navigation.test.mjs`'s mapping-list legs |
| AC2 | `NamespacePort` does not split | `MappingWrite`'s create, edit and delete legs (404) |
| AC2 | A mapping create drops `CREATES` | `MappingWrite`'s taken leg (the upsert is minted) |
| AC3 | `WeakensByEffect`'s `global-mapping` arm removed | `MappingWrite`'s `%` legs (the card is not destructive) |
| AC4 | The `OCUPILOTMAPPING` arm removed | `MappingWrite`'s install-namespace legs (a write is recorded) |
| AC5 | A mapping create drops `%DB_IRISSYS:WRITE` | `MappingWriteGate` (the port is called) |
| AC6 | `MAPPINGS` removed from `QUEUEDWRITES` | `NamespaceCopy` (refused); `AdminPortAsync` |
| AC6 | The started conversion removed | `NamespaceCopy`'s zero-bound legs |
| AC7 | `WithClassicPages` answers `pPairs` unchanged | `ClassicPageGate`'s refusal legs (the lacking principal is admitted) |
| AC7 | `NamespaceDelete`'s `CLASSICPAGES` emptied | `ClassicPageGate`'s delete legs alone; `MappingDescriptor`'s roster |
| AC8 | A field label drawn in `--ocu-surface` | the DW-1337 legs, in both themes |

Demonstrated on `ocupilot-b-ci`, each ObjectScript mutation loaded with its subclasses, each client mutation over a rebuilt and redeployed bundle where a browser spec reads it, and each reverted byte-identical:

- mutation: `Read.SeedRows` sets nothing → `MappingDescriptor.TestEachReadToolAnswersItsListsRowsWithTheNamespace` red on all three kinds (run 428), and `namespace-mappings.browser-spec`'s AC2/AC3 leg red (the name cell opens no edit); its AC1 leg stayed green.
- mutation: `NamespacePort.Invoke` does not split the composite id → all nine `MappingWrite` methods red (run 430); the vendor refuses the unsplit name 400 `PORT.VALIDATION`, not 404.
- mutation: `MappingCreate` `CREATES` 0 → `MappingWrite.TestATakenNameIsRefused` red, the upsert minted 200; every agent create red beside it (run 432).
- mutation: `Prohibited.WeakensByEffect`'s `global-mapping` arm removed → `MappingWrite.TestASystemGlobalMappingIsPermittedAtTheStrongestConfirmation` alone red (run 434).
- mutation: `Prohibited.IsOwnMapping` answers 0 → `MappingWrite`'s install-namespace and `%ALL` tests red, each refused write recorded by `MappingAcceptPort`, with OcuPilot's own mapping unchanged (run 435).
- mutation: `MappingCreate.PrivilegePairs` drops `%DB_IRISSYS:WRITE` → `MappingWriteGate.TestAWriteWithoutTheWritePairIsRefusedBeforeAnyPortCall` red on both callers (run 436).
- mutation: `NamespaceCopyMappings.PrivilegePairs` drops `%Admin_Operate:USE` → `MappingWriteGate.TestACopyWithoutThePollPairIsRefusedBeforeAnyPortCall` alone red on both callers (run 444).
- mutation: `Namespace.Namespace/MAPPINGS` out of `AdminPort.QUEUEDWRITES` → 4 of 7 `NamespaceCopy` methods red, both callers answering 500 `INTERNAL` with no task row written (run 437); `AdminPortAsync.TestOnlyTheNamedQueuedWritesAreAdmitted` red (run 438).
- mutation: `NamespacePort`'s started conversion removed → `NamespaceCopy`'s two zero-bound tests alone red, 503 `PORT.TIMEOUT` on both callers, each task still read once by `Settle` and deleted (run 439).
- mutation: `Screen.Gate.WithClassicPages` answers `pPairs` → `ClassicPageGate`'s two assigned-page tests red, all ten declaring tools admitted; its no-assignment test green (run 440).
- mutation: `NamespaceDelete` `CLASSICPAGES` "" → `ClassicPageGate.TestAnAssignedPageGatesTheScreensCaller` and `TestWithNoAssignmentEachToolsPairsAreItsDeclaredSet` red (run 441), `MappingDescriptor.TestTheClassicPagesRosterIsTheDeclaringTools` red (run 442).
- mutation: `NamespacePort.Refused` converts nothing → `MappingRefusals.TestABaseMappingWithSubscriptMappingsIsRefusedOnName` red, the screen's delete answering 500 `INTERNAL`, and `TestANameTheInstanceRefusesAnswersOnName` red on each kind's confirm (code review, run 9 on the recreated throwaway).
- mutation: `.ocu-field-label` drawn in `--ocu-surface` → `namespace-mappings.browser-spec`'s AC8 leg red at 1.04:1 light and 1.08:1 dark. An inline `style` on the form's label left it green and is not counted (inference: the served CSP drops inline styles).
- mutation: `EndpointCoverage`'s `GET /mapping/:kind/name` row deleted → `TestEveryRouteHasAProbeAndEveryProbeHasARoute` red (run 446); `SurfaceCoverage`'s `osmgmt.namespaces.copymappings` row deleted → `TestEveryWriteToolHasACoverageRowAndBack` red (run 447).
- mutation: `navigation.ts` `parentListFor` as the first-child inverse → `navigation.test.mjs`'s mapping-parent test red (routine leg); `routeIdFor` returns the id unchanged → its mapping-change test red; `builtScreensForArea` descending → `app.routes.spec`'s route-order test red.
- mutation: `entity-ref.ts` `foldcase-firstpart` lower-cases the whole id → `entity-ref.test.mjs`'s rule test red; `proposal-view.ts` drops `MAPPING.SYSTEMGLOBAL` → `proposal-view.test.mjs`'s consequence-codes test red.
- mutation: `namespace-form.page.ts` `mappingLinks` answers `[]` → `namespace-form.page.spec` AC1 red; `namespace-list.page.ts` drops the `copy-mappings` registration, or its `continued` branch → `namespace-list.page.spec`'s AC6 legs red.
- mutation: `screen-action-handler.ts` drops `GlobalMappingList` from `TYPED_NAME_ROWS`, or `NamespaceList` from `UNDRAWN_ACTIONS` → its typed-name Delete or undrawn-Copy test red; `screen-outlet.ts` drops `NamespaceList` from `DESCRIPTOR_PAGES` → `screen-outlet.spec`'s 18.14 test red; `app.ts` drops `mappingForm.reset()` → `app.spec`'s sign-out test red.
- mutation: `mapping-form.page.ts`'s `%` line disabled → `mapping-form.page.spec` AC3 red; `mapping-form.store.ts` sends empty optional fields → `mapping-form.store.spec`'s create test red; `copy-mappings-dialog.ts` excludes the destination case-sensitively → `copy-mappings-dialog.spec`'s sources test red.
- mutation (review pass): `MappingSave.PortViolations` returns at once → `MappingRefusals.TestANameTheInstanceRefusesAnswersOnName` alone red (run 810).
- mutation (review pass): `MappingRules.Validate`'s namespace-absent arm removed → `MappingRefusals.TestAnAbsentNamespaceAndABadCollationAreRefused` alone red, every write going to `MappingAcceptPort` (run 811).
- mutation (review pass): `Error.ReasonForMapping`'s `MAPPINGDATABASEREQUIRED` arm removed → `MappingDescriptor.TestEachViolationCodeCarriesASentenceAndItsField` alone red (run 812).
- mutation (review pass): `Screen.Gate.WithClassicPages` adds an unassigned page's empty resource → `ClassicPageGate.TestWithNoAssignmentEachToolsPairsAreItsDeclaredSet` alone red (run 813).
- mutation (review pass): `NamespaceCopy.TaskCount` answers -1 → `NamespaceCopy.TestACopyRoundTripsOnBothCallers` red on its readable-list floor (run 814).
- mutation (review pass): `Prohibited.CopiesOwnMapping` permits every destination → `NamespaceCopy.TestACopyIntoTheInstallNamespaceOfAnOcuPilotMappingIsRefused` and `TestACutSourceListIsRefused` red, each copy accepted by `MappingAcceptPort` and `HSCUSTOM`'s mappings unchanged (run 819).
- mutation (review pass): `locator-bar.ts` `entityLabel` answers the raw id → `locator-bar.spec`'s Story 18.14 composite-id test red.
- mutation (code review): `NamespacePort.Refused` keeps the generic reason for a single field refusal → `MappingRefusals.TestABaseMappingWithSubscriptMappingsIsRefusedOnName` alone red, on its reason (run 8).
- mutation (code review): `MappingRules.Validate`'s absent-database arm removed → `MappingRefusals.TestADatabaseAndANameAreRequiredOnACreate` alone red, the Save reaching the port (run 10).
- mutation (code review): `Error.ReasonForNamespace`'s `NAMESPACE.SOURCE.SAME` arm removed → `NamespaceCopy.TestABadSourceIsRefusedBeforeAnyTaskIsQueued` alone red (run 13).
- mutation (code review): `NamespaceCreate` `CLASSICPAGES` "" → `ClassicPageGate.TestAnAssignedPageGatesTheScreensCaller` red on the namespace create's Save leg alone, beside the agent test's confirm leg and the roster count (run 15).
- mutation (code review): `.ocu-namespace-copy-status` drawn in `--ocu-surface`, rebuilt and redeployed → `namespace-mappings.browser-spec`'s AC6 leg red at 1:1 in both themes, its AC8 leg green.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** Parts A and B and the DW-1784 mechanism, in the spec's order. Task 0 found every LIST row carrying `Name`, the LIST case-insensitive, and no #7846 after the async copies; the copy keeps `%DB_IRISSYS:WRITE`, measured refused without it (the AD-8 sentence is in the Spec Change Log for the runner).

**Files.**

- Server: `Port/NamespacePort.cls`; `Area/OsMgmt/MappingRules.cls` and `MappingSave.cls` behind four `/mapping/:kind` routes; six mapping descriptors; nine mapping tools on three abstract bases with `MappingMint`, and `NamespaceCopyMappings`.
- Kernel: `Screen/Gate.WithClassicPages` with `Write.CLASSICPAGES`, declared by the four namespace tools and the six mapping create and update tools; `Screen/Read.cls` row seeding (AD-36); `PROHIBITED.OCUPILOTMAPPING` and `MAPPING.SYSTEMGLOBAL` in `Prohibited.cls` and `Mint.cls`; the id rule `foldcase-firstpart`; `AdminPort` mutating, bodyless, queued and property-fault rosters; `Error.cls` codes; ten `Baseline.cls` lines.
- Client: the mapping form, its store and actions, the Namespaces list page with the copy dialog and status line, the namespace editor's Mappings line, and `parentListFor` widened.
- Tests: 20 new classes and fixtures, the rosters extended, and `scripts/ci-throwaway.sh` given its class lines. No new arming variable.

**Review (first pass).** 28 findings. Patched: 5 medium (vendor name refusals, `Validate`'s namespace and collation rules and the form's 404s, the mapping codes' sentences, the locator's composite label, `ClassicPageGate`'s self-referential expectation) and 3 low (a task-count floor, a stray line, the `CopiesOwnMapping` mutation line). Every patch is a test, each demonstrated red by its recorded mutation, and no product code changed in the pass. Deferred: 3 low client items the implementation reported. Rejected: 20, each with its reason in the triage log.

**Follow-up review:** `false`. Five medium entries were patched, but all five are test additions, each shown red under its mutation and green on the reverted tree, so no unverified risk can be named.

**Verification.**

- The full ObjectScript sweep on `ocupilot-b-ci` (348 classes, 2852 tests) found one red, `PortGate`, whose port roster lacked `NamespacePort`. The row was added, and `PortGate` re-ran 4/4 (run 805).
- After the patches: `MappingDescriptor` 6/6, `MappingRefusals` 7/7, `NamespaceCopy` 7/7 and `ClassicPageGate` 3/3 (runs 815-820).
- Client: `npm test` 1688 tools and 1749 components, then the `locator-bar` spec 32/32. `npm run build` is clean at 2.11 MB initial, with the warning re-based to 2217kB under DW-1166.
- Browser: `namespace-mappings` and `namespaces` 9/9 on the redeployed bundle. Smoke on `ocupilot-b-ci` 49/49.
- `check-objectscript` and `lint-docs` clean, and EXPERIENCE.md is 993 lines.
- Throwaway state afterwards: no probe namespaces, principals or resource, the six classic pages' custom resources empty as recorded, `HSCUSTOM`'s only OcuPilot mapping `OcuPilot*` on `OCUPILOT`, and no #7846 in either log.

**Residual risks.** The contended rosters shared with Epic 16 (`Prohibited` codes, `ReadTool`, `Navigation`, `Wire`, `PortGate`, `strings.ts`, `screens.generated.ts`) will need their counts reconciled at the merge. `MappingDelete.InputSchema` finds its create class by replacing the class name, which holds only for the registered tool names.
