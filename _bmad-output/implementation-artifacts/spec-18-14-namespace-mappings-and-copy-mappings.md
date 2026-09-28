---
title: 'Story 18.14: Namespace mappings and copy-mappings'
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

**Vendor.** These classes were read on this build through `iris_doc_get` in `%SYS` (read-only). Measurements are under Design Notes.

- `%Api.Admin.Endpoints.Namespace.{Global,Routine,Package}Mappings`:
  - Query `namespace` is required. `name` is required except on LIST. `ResourcesOR` is `%Admin_Manage`.
  - `PUT` is an upsert, and `NeedsRequestBody` is true for `PUT` only.
  - The LIST runs `Config.Map*:List`, excluding `Global`, `Routine` or `Package` respectively, so rows are:
    - global `{Name, Subscript, Database, Collation, LockDatabase}`;
    - routine `{Name, Type, Database}`;
    - package `{Name, Database}`.
  - This row shape is inferred from each query's ROWSPEC. Task 0 records the actual rows.
- `%Api.Admin.Endpoints.Namespace.Namespace`:
  - `TYPEINTEROP` is 10 and `TYPEMAPPINGS` is 11, and `ShouldRunAsync` is true for both.
  - `MAPPINGS` takes no `name` and requires the body `{SourceNamespace, DestinationNamespace}` (a strict validator), then calls `Config.Namespaces.CopyMaps`.
  - `INTEROP` requires query `name`, takes no body (`NeedsRequestBody` is false), answers 404 for an absent namespace, and calls `%EnsembleMgr.EnableNamespace(name, 1)`.
- `irislib/%Library/EnsembleMgr.cls:1738` `EnableNamespace` does the following, all inferred from source:
  - creates mappings;
  - creates a portal web application;
  - adds SQL privileges;
  - modifies the Interop Editors API application;
  - grants database privileges;
  - on a non-HealthShare instance, creates ENSTEMP and SECONDARY databases unless the namespace is USER.
  - Many step failures are only displayed, not returned.
- Routes already derived: `src/OcuPilot/Port/AdminRoutes.cls:130-139`.
- Templates already in `src/OcuPilot/Screen/Tool/FieldLists.cls:131-146`:
  - global `{Database, LockDatabase, Collation}`;
  - routine and package `{Database}`.
- Classic pages (AD-44):
  - `%CSP.UI.Portal.Mappings` is one list page for all three kinds.
  - `%CSP.UI.Portal.Mappings.Global`, `.Routine` and `.Package` are the create and edit dialogs.
  - Each declares `RESOURCE = %Admin_Manage`.
- Sibling guard: `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/Config.cls:557-560,640-647`. `IsGuardedBaseMapping` refuses a base `%`-global create without `force`.

**Port** (`src/OcuPilot/Port/`):

- `AdminPort.cls`:
  - Parameters: `MUTATINGTYPES` :309, `BODYLESSTYPES` :325, `QUEUEDWRITES` :492 (with its doc at :486-491), `PROPERTYFAULTS` :2319 (grammar at :2292-2318).
  - `SPLITQUERIES` :517 splits on `/`, which a subscript can hold, so it is not used here.
  - `Invoke` :770-830. `EndpointType` :1968 resolves `MAPPINGS` and `INTEROP` once they are mutating, because `Namespace.Namespace` overrides `Run`.
  - The `ShouldRunAsync` handoff and the queued-write refusal are in `Sequence` :2103-2123. `AwaitTask` :2152.
  - `Snippet` :2504.
- `AuditPort.cls` is the model to follow:
  - `STARTEDHTTP` :44;
  - `Invoke` :69-104: it refuses a caller body, builds the body at :92, calls super with an empty query at :94, and converts a timeout to started at :96-102;
  - `Snippet` :380.
- `src/OcuPilot/Kernel/Proposal/Operation.cls:173-184` `Query()`: the id always travels under `IdParam`, then comes the tool's `PortQuery`.

**Tools** (`src/OcuPilot/Screen/Tool/`):

- `Write.cls` parameters:
  - `DESTRUCTIVE` 52, `READTYPE` 57, `WRITETYPE` 62, `SENDSBODY` 67;
  - `FINGERPRINTSUBJECT` 97, `PRECONDITIONFIELD` 105, `PORTCLASS` 114, `CHANGEACTION` 124, `CREATES` 141;
  - `SCREENACTIONS` 157, `READANSWERS` 170, `SCREENVALUES` 201.
- `Write.cls` hooks:
  - `DerivedFields` 301, `PortQuery` 417, `StateDiff` 463, `MintClass` 472;
  - `IdArgument` and `IdParam` 500/507, `ScreenActionDelta` 584, `InputSchema` 674, `ArgumentProblem` 786.
- `Base.cls`: `PrivilegePairs` :92, `ArgumentPairs` :123.
- `NamespaceCreate`, `NamespaceUpdate` and `NamespaceDelete` show the shapes and the `%DB_IRISSYS:WRITE` pairs.
- `AuditCopy.cls` is the model for an action with a dialog value:
  - `SCREENVALUES` :51, `SettableFields` :80, `PortQuery` :111, `ScreenActionDelta` :142, `PrivilegePairs` :155.
  - The value flow is `Api/ScreenAction.cls` `Values` :453, then `Run` :217-363 (on a 202 answer, `continues` :356).
- `ErrorDeleteMint.cls:35-81` shows arguments joined into a composite id.
- `OAuthResourceServerRemoveMapping` subclasses `AddMapping`; this is the subclass idiom to copy.
- The registry skips `[ Abstract ]` classes (`Registry.cls:636-646`).
- `Classification.cls` grammar is at :6-29, and the namespace entries at :469-484. A tool that sends no body needs no entry (`Write.FieldRows` :612).

**Kernel:**

- `Kernel/EntityType.cls:42`: 33 types.
- `Kernel/EntityRef.cls`: `IDRULES` :59, `IDRULENAMES` :64, `NormalizedId` :246-259, which applies the rule to the whole id. Normalization happens at `Api/ScreenAction.cls:190` and `Mint.cls:431`, so the port may receive a lower-cased namespace part.
- `Kernel/EntityId.cls:71-84`.
- `Screen/Read.cls`:
  - The single-object read seeds its id at :410-415. The admin LIST branch is :423-437. Projection is at :450-468 (`Project` :1026).
  - `SeedCriteria` :767. `READ.CRITERION` refusal :370-373.
- `Kernel/Proposal/Mint.cls`:
  - `GrantsPrivilegeByEffect` :317 runs for creates too.
  - `WeakensByEffect` runs only under `If 'tCreates` (:324-331).
  - `ConsequenceOf` :739 and the destructive flag :332-333.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250 (22 types), `Codes()` :489 (19 codes), `ReasonFor` :497.
  - `PermittedChangeFields` :600, `PermittedCreateFields` :712.
  - `Prohibits` :799, with the type chain at :810, the create branch at :831-838 and the dispatch at :847-921.
  - `Created` :986. `WeakensByEffect` :1157-1204.
  - The shipped namespace predicate: `Namespace` :1595-1621, `IsOwnNamespace` :1627-1632, `NamespaceFields` :1636. `Target` :2856.
- `Kernel/Proposal/Impact.cls:371-383` `ListRows` is the gate plus declared read, where a cut list reads as unchecked. The copy predicate reuses it.
- OcuPilot's own mapping is exactly one global mapping, `OcuPilot*` → `OCUPILOT`, in the install namespace (`Kernel/State/Base.cls:86`, `Install/Installer.cls:2852-2882`). No `%ALL` mapping exists.
- `Kernel/Governance/Baseline.cls:24-26`: the namespace lines.

**Screens:**

- `Screen/Descriptor/NamespaceList.cls:23-68`:
  - `rowActions` is `[{delete}]` at :39.
  - `NamespaceForm.cls:19-49` declares no read, and so is exempt from `TableProblem` (`Registry.cls:1015-1019,1281`).
- Other models:
  - `WalletSecretList.cls:32-83` is parent-scoped with one criterion.
  - `TaskRunList.cls:44-99` has a composite id and is parent-scoped.
- `Screen/Registry.cls`:
  - `CriteriaProblem` :1376-1429. A parent-scoped read declares exactly one criterion, and `namespace` is not reserved (:1324).
  - `TableProblem` :2242-2251: `id.parts` must be among `read.fields`.
  - `ParentScopeResolutionProblem` :3332.
  - `PROMPTGROUPKEYS` :2538.
- `ui/tools/screen-mirror.mjs` has the mirrors of all of these. Its id-rule check `IMPLEMENTED_ID_RULES` :162 and `checkedIdRules` :2554-2590 fail the build.

**Save routes:**

- `Area/OsMgmt/NamespaceRules.cls` has these methods: `Validate` :57, `HandleForm` :160, `HandleName` :207, `Taken` :241, `Databases` :302 (the `Database.ConfigCRUD` LIST as the caller), `Spelled` :330, `Gate` :342.
- `Area/OsMgmt/NamespaceSave.cls` has these methods: `Create` :115, `Update` :160, `PortViolations` :227, `Prohibited` :256, `Gate` :349.
- `Api/Router.cls`:
  - The namespace routes are at :119-122 and the screen routes at :123-125. The ordering precedents are :81-86 and :164-165. The handlers start at :582.
- `Api/Error.cls`:
  - The NAMESPACE block is at :2483-2530. `NamespaceViolationCodes` is near :1415 and `ReasonForViolation` at :1201, where the prefix routes at :1356.

**Client** (`ui/src/app/`):

- `areas/os-management/namespace-form.page.ts` (400 lines):
  - The fields end at :150, and the form bar is at :152.
  - The link-line model to follow is `areas/tasks/task-editor.page.ts:91-95,239-267,339-346`.
  - The edit route id is read at :353.
- `namespace-actions.ts:31-40`.
- `areas/security/wallet-actions.ts:38-47` and `wallet-secret-form.page.ts:546-556` show a parent carried as a query parameter. The parameter is never `ns` (`core/navigation.ts:619,636-644`).
- `core/navigation.ts`:
  - `childListFor` :254-265 returns the first child only. `parentListFor` :293-300 inverts only that one.
  - The locator link-back is `shell/locator-bar.ts:350`. `ownIdSegment` answers `''` for a parent-scoped screen (:371).
- `shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :51-73, `UNDRAWN_ACTIONS` :149-157, `DESTRUCTIVE_CONSEQUENCES` :208-227.
  - `startFor` :494-564, `sendFor` :748, `continued()` :758.
  - The handler is built lazily by the list page and re-registers every declared row action (:395-408). So an action a page owns joins `UNDRAWN_ACTIONS`, and the page registers it after injecting the handler (`areas/security/auditing-config.page.ts:253,308-310`).
- The running-line model:
  - `auditing-config.page.ts:172,527-541,596-620`;
  - `areas/security/audit-copy-dialog.ts` (102 lines);
  - `ListPage` renders only the table and dialogs (`shell/list-page.ts:59-78`), and the wrapper-page model is `areas/security/audit-user-event-list.page.ts:28-54`.
- The consequence line at a field: `areas/web-applications/create-form.page.ts:327,341-343,534-536` (a client trigger with a `strings.ts` sentence).
- The effect code-to-sentence map is `core/proposal-view.ts:138-189`.
- The panel appends the still-running sentence for any confirmed write that answers `continues` (`shell/panel.ts:1158-1174`).
- `core/entity-ref.ts:65-112`, `shell/screen-outlet.ts:113-144`, `app.ts:296-313,554-610`.
- `core/strings.ts` (3411 lines):
  - The 18.2 keys are at :3351-3394.
  - Keys to reuse: `oauthResourceServerTabMappings` ("Mappings"), `auditDatabaseCopyConfirm` ("Copy"), `auditDatabaseStillRunning`, `headerNamespaceLabel`, `tableColumnName`, `tableColumnType` and `systemInfoDatabase`.
  - Values are unique (`tools/strings.test.mjs:732`).

**EXPERIENCE.md** (993 lines), the rows to extend in place:

- :164 OS management side bar;
- :173 Dialogs;
- :378 the OS management literals;
- :479 delete bodies;
- :481 kernel refusals.

The audit copy row (:516) is the source of the reused strings. The row with the field-consequence pattern (:403) is the model.

**Rosters** (18.2's list, with each line to extend):

- ObjectScript:
  - `Test/Descriptor.cls`: `ReadShapes` :67-118, entity count :1700.
  - `Test/ReadTool.cls` :93-94,112, the count 134.
  - `Test/SurfaceCoverage.cls` :74,125,148-150.
  - `Test/EndpointCoverage.cls` :192-195.
  - `Test/Navigation.cls` :326-339, 12 screens.
  - `Test/Wire.cls:697`, `Test/WireSecurityRead.cls` :549,556,559.
  - `Test/ProposalPrivilege.cls` :95-106.
  - `Test/Prohibited.cls` :218,672 (the codes count, 19).
  - `Test/AuditingUpdate.cls:505` (19), `Test/RefusalCopy.cls:107`.
  - `Test/GovernanceBaseline.cls:10`, `Test/Governance.cls:90-104`, `Test/ToolDispatch.cls:139-150`, `Test/ToolEmit.cls:200-212`.
  - `Test/ToolWrite.cls` :1192-1297, including `tOtherPorts` :1297.
  - `Test/ToolRoundTrip.cls:38` `REFUSEEMPTY`.
  - `Test/PortFixture.cls:21`, `Test/AdminPortAsync.cls:88`, `Test/DraftRegistry.cls` :80,123,159, `Test/EntityRef.cls`.
- Client:
  - `ui/tools/navigation.test.mjs` :150-158,223-245,384-432;
  - `navigation-wire.test.mjs` :90-180, `shell/rail-wire.spec.ts` :87-179;
  - `tools/self-protection.test.mjs:252-266`, `tools/screen-mirror.test.mjs:191-210`, `tools/entity-ref.test.mjs:207-215`;
  - `shell/screen-action-handler.spec.ts`, `app.spec.ts:1209-1213,1317-1319`.
- DW-1774: every new screen takes position 0, so no side-bar list changes. `namespaces.browser-spec.mjs:369-393` stays valid.

**Test models:**

- `Test/NamespaceWrite.cls` (the arming, the lifecycle and the `^||OcuPilotNamespaceWritePort` seam), `NamespaceWriteGate` with its `Probe` (`EnsurePrincipals` :324-354, `RunAs` :266), `NamespaceRefusals`, `NamespaceWriteProbe` (`RemoveAll` :225, `CpfValid` :299), `AcceptPort` (`ReadThrough`), `DeviceRecordPort` and `RoleDeletePort`.
- The started path with a zero bound: `Test/AuditStarted.cls` with `AuditStartedPort`, `AuditStartedConfirm`, `AuditStartedAction` and `AuditStartedCopy`.
- Arming:
  - `scripts/ci-throwaway.sh`: the NAMESPACE_CONFIG block is at :353-361, and the principals `classes:` lines at :200-235.
  - These rosters are derived by `ui/tools/ci.test.mjs:1818-1927`.
- Browser:
  - `ui/browser/namespaces.browser-spec.mjs`: the `docker exec` cleanup is at :71-93, and the local `assertStructure` at :338-365.
  - `audit-copy-purge.browser-spec.mjs:92-99,174-208` has the running-line observer.

## Tasks & Acceptance

**Task 0: the implement stage's first task, before any code** (on `ocupilot-b-ci` only, with probe objects the step creates and removes; the results go into Design Notes › Measured at implement):

1. **Read-only checks:**
   - Do the three mapping LISTs answer the same rows for `namespace=user` as for `USER`?
   - What key set does each LIST row carry?
2. **Copy without `%DB_IRISSYS:WRITE`:** a direct `AdminPort` call. The caller is a principal holding the screen pairs and `%Admin_Operate:USE`, and the call runs between two probe namespaces. Does the copy apply?
3. **Enable-interop:**
   - Setup: a probe namespace `OCUPROBE1814I` over a probe database `OCUPROBE1814D`, with its resource `%DB_OCUPROBE1814D` created first (Conventions › IRIS security objects). Never use the `USER` or `HSCUSTOM` databases.
   - Record the request and answer, the async behavior, and the time to finish.
   - Record every object the call creates or changes: mappings, web applications, databases, roles and their resources, SQL privileges, and the Interop Editors API application.
   - Record the pairs a least-privileged principal needs for every one of those effects to apply. Remove each candidate pair in turn: `%DB_IRISSYS:WRITE`, `%Admin_Operate:USE`, `%Admin_Secure:USE`, and WRITE on the namespace's own databases.
   - Record that the namespace delete plus the probe cleanup leave no survivor.
4. **Halt conditions.** HALT `blocked`, with the blocking condition `enable-interop observation contradicts the plan: <what>` and with nothing built, if any of these hold:
   - Enable-interop takes a body.
   - It does not queue through the `ShouldRunAsync` handoff.
   - It creates or changes one of OcuPilot's own applications, roles, resource, database or mapping.
   - It needs a pair outside the candidates above.
   - Something it creates cannot be removed by the probe cleanup.
   - A clause of its consequence sentence (`:378`, below) is false on the throwaway.
5. **Otherwise:**
   - Set the enable-interop tool's pairs to exactly the measured set. A demand for WRITE on the namespace's databases goes through `ArgumentPairs`, from the fresh read's `Globals` and `Routines`.
   - Keep or drop the copy's `%DB_IRISSYS:WRITE` according to item 2.
   - Write the resulting AD-8 and AD-26 sentences into `## Spec Change Log` for the runner (Rule 20).

**Execution: Part A, mappings (AC1-AC5):**

- `src/OcuPilot/Kernel/EntityType.cls`, `Kernel/EntityRef.cls`, `ui/src/app/core/entity-ref.ts`, `ui/tools/screen-mirror.mjs`:
  - Append `global-mapping`, `routine-mapping` and `package-mapping` (33 becomes 36).
  - Add the rule `foldcase-firstpart` to `IDRULENAMES`, `ID_RULES` and `IMPLEMENTED_ID_RULES`. It lower-cases only the text before the first `$Char(1)`, and each of the three types takes it.
  - Why: namespaces resolve without case, and global and routine names are case-sensitive.
- `src/OcuPilot/Screen/Read.cls`:
  - Scope: a parent-scoped admin `LIST` whose composite id's first part equals its one criterion's `param`.
  - It refuses a missing criterion value with 400 `READ.CRITERION` before any port call.
  - It then seeds that value onto every row under that part, before projection (after :436). This is the object read's seeding (:410-415), extended to a list.
  - `TableProblem` already requires the part in `read.fields`. No new registry key is added.
- `src/OcuPilot/Port/AdminPort.cls`:
  - Add the three mapping endpoints' `/PUT` and `/DELETE` to `MUTATINGTYPES`, and the three `/DELETE`s to `BODYLESSTYPES`. The vendor reads a body on `PUT` only.
  - Add to `PROPERTYFAULTS`: `<endpoint>:5854:@Name=MAPPING.NAME.SHAPE` and `:448:@Name=MAPPING.NAME.SHAPE` for all three endpoints, and `Namespace.GlobalMappings:451:@Name=MAPPING.NAME.SUBSCRIPTS`.
  - Give each entry its measured fact in the doc comment. Mirror `MUTATINGTYPES` in `Test/PortFixture.cls:21`.
- `src/OcuPilot/Port/NamespacePort.cls` (new, extends `AdminPort`, on the `AuditPort` model):
  - Scope: the three mapping endpoints' non-LIST calls.
  - A query that already carries `namespace` passes through unchanged. This covers LIST and every inner re-read.
  - Otherwise it splits `name` with `EntityId.SplitComposite` into `namespace` (upper-cased; the instance stores namespace names upper case, measured by 18.2) and `name` (unchanged).
  - Anything other than two non-empty parts answers 404 `PORT.NOTFOUND` with no vendor call.
  - `SnippetForm` and `Snippet` mirror every branch (AD-59).
- `src/OcuPilot/Screen/Tool/MappingMint.cls` (new, on the `ErrorDeleteMint` model):
  - The id is `JoinComposite($lb(Namespace, Name))` from the agent's `Namespace` and `Name`.
  - It refuses a part that is empty or holds `$Char(1)`.
- `src/OcuPilot/Screen/Tool/MappingCreate.cls`, `MappingUpdate.cls`, `MappingDelete.cls` (new, `[ Abstract ]`, with no `TOOLNAME`), plus nine thin subclasses `{Global,Routine,Package}Mapping{Create,Update,Delete}.cls`:
  - Each subclass sets `TOOLNAME` `osmgmt.<kind>mappings.<verb>`, its endpoint `Namespace.<Kind>Mappings` and `DESCRIPTORCLASS` `<Kind>MappingList`.
  - All nine declare `PORTCLASS` `NamespacePort`. `MintClass` is `MappingMint`, and `InputSchema` adds `Namespace` as a required argument, described as "the namespace as the Namespaces list shows it".
  - `PrivilegePairs` is the list's pairs plus `%DB_IRISSYS:WRITE`, added once.
  - Create: `CREATES` 1 and `CHANGEACTION` `created`. The settable fields are the kind's template, and Database is required.
  - Update: a merge that sends the complete template set read fresh.
  - Delete: `DELETE`, `SENDSBODY` 0, `DESTRUCTIVE` 1, `CHANGEACTION` `deleted` and `SCREENACTIONS` `delete`.
  - Delete fingerprint: `READANSWERS` and `FINGERPRINTSUBJECT` are the template fields, and `PRECONDITIONFIELD` is `Database`.
  - `ArgumentProblem` and `DerivedFields` apply `MappingRules`.
- `src/OcuPilot/Screen/Tool/Classification.cls`:
  - Add create and update entries for each kind (`fieldList` `Namespace.<Kind>Mappings`), with every field `ordinary`.
  - Then run `cd ui && node tools/field-lists.mjs` (AD-3).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` and `Mint.cls`:
  - The three types join `COVEREDTYPES` and the type chain. Their permitted create and change fields are the kind's template.
  - A `Mapping` predicate runs for create, change and delete, the create through `Created`. The target is own when the id's first part, upper-cased, is `$NAMESPACE` or `%ALL`, and its name part begins with `ocupilot` ignoring case. An own target is refused with `OCUPILOTMAPPING`, whose `REASON` is the `:481` sentence; add it to `Codes()` (20) and `ReasonFor`. Everything else takes `ReviewedFewOnly`.
  - `WeakensByEffect` gains a `global-mapping` arm: `EFFECTSYSTEMGLOBAL` `MAPPING.SYSTEMGLOBAL` when the id's name part begins with `%`.
  - `Mint.cls:324` also asks `WeakensByEffect` for a create of type `global-mapping`.
- `src/OcuPilot/Api/Error.cls`: add a MAPPING block after the NAMESPACE block, sharing the NAMESPACE reasons where the sentence is equal:

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

- `src/OcuPilot/Area/OsMgmt/MappingRules.cls` and `MappingSave.cls` (new, on the `NamespaceRules` and `NamespaceSave` model, gated on the kind's form):
  - Rules:
    - Name is required. A routine name ending in `_` plus lower case is SHAPE.
    - Taken means the create tool's `GET` does not answer 404.
    - The namespace must exist (`Namespace.Namespace` `GET`).
    - Database and LockDatabase must be names from `NamespaceRules.Databases`, sent in the list's spelling.
    - Collation, when sent, is a whole number.
  - `HandleForm` answers `{requiredFields, rules, databases}`, and with `?name=` also the mapping, from the update tool's fresh read.
  - `Create` and `Update` run the tools in this order: gate, prohibited, rules, send, `PortViolations`, read-back. An edit whose fresh read answers 404 is refused with `MAPPING.NAME.ABSENT`, and nothing is sent.
- `src/OcuPilot/Api/Router.cls`: add thin wrappers, following the ordering convention. `kind` is `global`, `routine` or `package`; any other value answers 404.
  - `GET /mapping/:kind/form?namespace=[&name=]`
  - `GET /mapping/:kind/name?namespace=&name=`, which answers `{name, taken, reason}`
  - `POST /mapping/:kind`, with body `{Namespace, Name, <template fields>}`
  - `PUT /mapping/:kind/:id`, where `:id` is the row key (the composite, one segment, AD-13) and the body is the template fields
- `src/OcuPilot/Kernel/Governance/Baseline.cls`: add the nine `osmgmt.<kind>mappings.<verb>` lines, all `true`, in name order.
- `src/OcuPilot/Screen/Descriptor/`: six new descriptors.
  - **`GlobalMappingList`, `RoutineMappingList`, `PackageMappingList`** (lists):
    - route `os-management/namespaces/<kind>-mappings`, position 0, `parentScope` `os-management/namespaces`;
    - the entity is its type, with `secondaryEntityTypes` `["namespace"]`, so a copy or interop event re-fetches it;
    - id: composite `["namespace","Name"]`;
    - read: `{admin, Namespace.<Kind>Mappings, LIST}`, with one criterion `{param:"namespace", labelKey:"headerNamespaceLabel", kind:"text", maxLength:64}`;
    - fields:
      - global: `namespace, Name, Database, LockDatabase, Collation`;
      - routine: `namespace, Name, Type, Database`;
      - package: `namespace, Name, Database`;
    - columns: Name (`name`), then Database, then "Lock database" and "Collation" for globals, or Type for routines;
    - primary action `create`, row action `delete`;
    - `classicPage` `%CSP.UI.Portal.Mappings`, three prompts, and `toolIdentifier` `osmgmt.<kind>mappings`.
  - **`GlobalMappingForm`, `RoutineMappingForm`, `PackageMappingForm`** (form pages):
    - route `<list route>/edit`, position 0, `parentScope` `""`;
    - the same composite id, and no read;
    - `classicPage` `%CSP.UI.Portal.Mappings.<Kind>`, three prompts, and `toolIdentifier` `osmgmt.<kind>mappingform`.
- `ui/src/app/core/navigation.ts`:
  - `parentListFor` answers the list whose route is the screen's `parentScope` whenever the screen qualifies as its child list or detail screen, not only when it is the first match.
  - Every mapping list's locator then links back to Namespaces. Every existing child resolves unchanged.
- `ui/src/app/areas/os-management/mapping-form.page.ts`, `mapping-form.store.ts`, `mapping-actions.ts` (new; one page serves the three form descriptors, with the kind taken from the route):
  - Create carries `?namespace=`, on the wallet model.
  - The fields:
    - Name (read-only on an edit);
    - Database, a native select from `/mapping/:kind/form`;
    - for globals only, LockDatabase (a select with an empty choice) and Collation (a whole number).
  - While a global's name begins with `%`, the form shows the `%` line under Name, using the `create-form.page.ts:534` idiom.
  - Cancel returns to the list for that namespace.
  - Register the page in `DESCRIPTOR_PAGES`, and inject the actions and `reset()` in `app.ts`.
- `ui/src/app/areas/os-management/namespace-form.page.ts`:
  - In edit mode only, after :150, add a Mappings line labeled with `oauthResourceServerTabMappings`.
  - It holds three links, "Global mappings", "Routine mappings" and "Package mappings", each to `<list route>/<encodeEntityId(name)>` through `withQuery`.
- `ui/src/app/shell/screen-action-handler.ts`: add the three lists to `SCREEN_ACTION_DESCRIPTORS`, and their three delete consequences to `DESTRUCTIVE_CONSEQUENCES`.
- `ui/src/app/core/proposal-view.ts`: map each consequence code to its sentence key: `MAPPING.SYSTEMGLOBAL` in Part A, `NAMESPACE.COPYMAPPINGS` in Part B, `NAMESPACE.INTEROP` in Part C. The Part B and Part C keys are the dialogs' consequence sentences, so each sentence is published once.
- `ui/src/app/core/strings.ts` (append; each key cites its EXPERIENCE row) and EXPERIENCE.md, edited in place with 993 lines kept. The literals are the `:378`, `:479` and `:481` lists below.

**Execution: Part B, copy-mappings (AC6):**

- `AdminPort.cls`:
  - Add `Namespace.Namespace/MAPPINGS` to `MUTATINGTYPES`, with the mirror in `PortFixture`, and to `QUEUEDWRITES`. The doc says no secret is carried.
  - Update `Test/AdminPortAsync.cls:88`'s literal.
- `NamespacePort.cls`: on `Namespace.Namespace` `MAPPINGS`:
  - Refuse a caller body.
  - Build `{SourceNamespace, DestinationNamespace}` from `pQuery("SourceNamespace")` and the target id `pQuery("name")`, both upper-cased. Call super with an empty query.
  - A `PORT.TIMEOUT` on a queued write becomes started (202), as at `AuditPort:96-102`. `Snippet` renders the built body.
- `src/OcuPilot/Screen/Tool/NamespaceCopyMappings.cls` (new, `osmgmt.namespaces.copymappings`, on the `AuditCopy` model):
  - `DESCRIPTORCLASS` `NamespaceList`, `PORTCLASS` `NamespacePort`;
  - `READTYPE` `GET`, `WRITETYPE` `MAPPINGS`, `SENDSBODY` 0;
  - `DESTRUCTIVE` 1, `CHANGEACTION` `updated`;
  - `SCREENACTIONS` `copy-mappings`, `SCREENVALUES` `copy-mappings=SourceNamespace`, `SettableFields` `SourceNamespace`;
  - `READANSWERS` and `FINGERPRINTSUBJECT` are `Globals,Routines,TempGlobals`, and `PRECONDITIONFIELD` is `Globals`;
  - `PortQuery` passes `SourceNamespace`. `ArgumentProblem` and `ScreenActionDelta` refuse an absent or same source before any task is queued. The tool's `Consequence` answers `NAMESPACE.COPYMAPPINGS`.
  - `PrivilegePairs`: the list's pairs, plus `%Admin_Operate:USE`, plus `%DB_IRISSYS:WRITE` unless Task 0 dropped it.
  - `NamespacePort`'s `GET` answers the vendor object with an empty `SourceNamespace`, on `AuditPort`'s DATABASE precedent, so the merge makes the one diff row.
- `Prohibited.cls`, `Namespace` predicate:
  - A `MAPPINGS` write branches before `ReviewedFewOnly`.
  - When the destination is own or `%ALL`, it reads the source's three mapping lists through their declared reads, as the caller: `Kernel.Shell.Effective.Gate`, then `Screen.Read.Execute(<Kind>MappingList, CopySourceCap(), …, .criteria)` with `criteria("namespace")` set to the source. This follows `Impact.ListRows`' idiom (`Impact.cls:371-383`); that method is private and takes no criteria.
  - `CopySourceCap()` is a new class method answering `""` (the default cap).
  - A row whose `Name` begins with `ocupilot` ignoring case, a gate refusal, or a list answering `truncated` is refused `OCUPILOTMAPPING`. Otherwise the copy is permitted.
- `Error.cls`:
  - `NAMESPACE.SOURCE.ABSENT` (the absent reason);
  - `NAMESPACE.SOURCE.SAME`: "Choose a namespace other than this one."
- `Baseline.cls`: add `"osmgmt.namespaces.copymappings": true`.
- `NamespaceList.cls`: `rowActions` gains `{copy-mappings}`.
- `ui/src/app/areas/os-management/namespace-list.page.ts` (new, the `AuditUserEventListPage` shape) and `copy-mappings-dialog.ts` (new, the `audit-copy-dialog` model):
  - The wrapper renders `<app-list-page/>`, the dialog and a `role="status"` operation line. It registers `copy-mappings` after injecting the handler, and `copy-mappings` joins `UNDRAWN_ACTIONS`.
  - The dialog's select offers `NamespaceList`'s read, through the ordinary read route, minus the destination. It shows the consequence and Copy.
  - The running line becomes the done line or `auditDatabaseStillRunning`, taken from `continued()`.
  - Register the wrapper page for `NamespaceList` in `DESCRIPTOR_PAGES`.

**Execution: Part C, enable-interop (AC7; only after Task 0 passes):**

- `AdminPort.cls`: add `Namespace.Namespace/INTEROP` to `MUTATINGTYPES`, `BODYLESSTYPES` and `QUEUEDWRITES`, with the mirrors in `PortFixture` and `AdminPortAsync`. `NamespacePort` applies its started conversion to `INTEROP` too.
- `src/OcuPilot/Screen/Tool/NamespaceEnableInterop.cls` (new, `osmgmt.namespaces.enableinterop`):
  - `DESCRIPTORCLASS` `NamespaceList`, `PORTCLASS` `NamespacePort`;
  - `READTYPE` `GET`, `WRITETYPE` `INTEROP`, `SENDSBODY` 0;
  - `DESTRUCTIVE` 1, `CHANGEACTION` `updated`, `SCREENACTIONS` `enable-interop`;
  - `READANSWERS` is `Globals,Routines,TempGlobals`, `FINGERPRINTSUBJECT` is `Globals,Routines` and `PRECONDITIONFIELD` is `Globals`;
  - `Consequence` answers `NAMESPACE.INTEROP`;
  - `ArgumentProblem` and `ScreenActionDelta` refuse `%SYS` with `NAMESPACE.INTEROP.SYSTEM`: "Interoperability cannot be enabled in %SYS.";
  - its pairs are Task 0's measured set.
- `Baseline.cls`: add `"osmgmt.namespaces.enableinterop": true`.
- `NamespaceList.cls`: `rowActions` gains `{enable-interop}`.
- `Prohibited.Namespace`: an `INTEROP` write branches before `ReviewedFewOnly` and is permitted.
- `namespace-list.page.ts`:
  - It registers `enable-interop`, which joins `UNDRAWN_ACTIONS`.
  - A `confirm-dialog` warning names the action and shows the consequence, then sends. The running line becomes the done line or still running.
- `screens.generated.ts`: regenerate with `cd ui && node tools/screen-mirror.mjs` after each part's descriptor change.

**EXPERIENCE.md edits (in place, 993 lines) and `strings.ts`:**

- `:164`: the third cell reads "Namespaces (Stage 2, Stories 18.2 and 18.14: its editor links a namespace's global, routine and package mappings)".
- `:173`:
  - "global, routine and package mapping" joins the delete confirmations.
  - "the two warnings" becomes "the three warnings", adding "enable interoperability (Story 18.14)".
  - "copy mappings (Story 18.14)" joins the dialogs.
- `:378` gains these literals, and its where-clause ends `[ADDED 2026-09-28 - Story 18.14]`:
  - "Global mappings" · "Routine mappings" · "Package mappings" · "Global mapping" · "Routine mapping" · "Package mapping" · "Lock database" · "Collation"
  - "This namespace has no global mappings." · "This namespace has no routine mappings." · "This namespace has no package mappings."
  - "map a global" · "map routines" · "map a package" · "change this mapping"
  - "This maps a system global. Code in this namespace that uses it reads the mapped database instead of the system's own."
  - "Copy mappings" · "Copies every mapping of the chosen namespace into this one. A mapping this namespace already has under the same name is replaced; its other mappings stay." · "Copying mappings from <source> into <namespace> on the instance since <time>" · "Copied the mappings of <source> into <namespace>."
  - "Enable interoperability" · "This adds the interoperability code to this namespace, creates its Interoperability portal application, gives the interoperability roles access to its databases, and can create databases for its temporary and secondary data. OcuPilot cannot undo it." · "Enabling interoperability in <namespace> on the instance since <time>" · "Enabled interoperability in <namespace>."
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

**Tests** (each stateful class refuses unless `OCUPILOT_ALLOW_NAMESPACE_CONFIG` reads 1; each runs `RemoveAll` before all, after each and after all tests, and a survivor fails the class):

- `src/OcuPilot/Test/MappingProbe.cls` (new; not a test case; the `NamespaceWriteProbe` model):
  - Probe namespaces `OCUPROBE1814A` and `OCUPROBE1814B` over `USER`, created and removed through `AdminPort`. The namespace delete takes their mappings.
  - Mapping names begin with `OcuProbe1814`.
  - `%SYS` seeding helpers for all three kinds (test-only); `CpfValid`.
  - The interop probe: create database `OCUPROBE1814D` (resource first), namespace `OCUPROBE1814I`, and the exact removal Task 0 recorded.
- `src/OcuPilot/Test/MappingWrite.cls` (new): each Part A matrix row on both callers (the agent's mint and confirm; `MappingSave` and the screen action route).
  - The `%` legs assert the proposal row's `destructive` and `consequence`.
  - The install-namespace legs run through `AcceptPort` with `ReadThrough(1)` on both callers, so a removed predicate records a write instead of making one.
  - The `%ALL` legs call `Prohibited.Prohibits` directly with a `%ALL` target (no `%ALL` is created).
- `src/OcuPilot/Test/MappingRefusals.cls` (new): the edit of a mapping deleted since the read (the Save answers 404 and the confirm `TARGETCHANGED`); a key outside the template; the routine suffix; the #451 delete, with both mappings surviving; `NamespacePort`'s malformed id (404, no vendor call); a lower-cased namespace part reaching the vendor upper-cased.
- `src/OcuPilot/Test/MappingWriteGate.cls` with `MappingWriteGateProbe.cls` (new, the `NamespaceWriteGate` model; also armed by `OCUPILOT_ALLOW_PRINCIPALS`; calls counted through `DeviceRecordPort`):
  - A reader holding the two screen pairs reads the three lists and the form choices.
  - A writer without `%DB_IRISSYS:WRITE`, and a copier without `%Admin_Operate:USE`, are refused 403 naming the pair, with zero port calls, on both callers.
  - Holders of exactly the declared pairs create, edit and delete a mapping and copy (AD-29).
- `src/OcuPilot/Test/MappingDescriptor.cls` (new, stateless):
  - The six declarations and the eleven tools' fields, kinds and pairs.
  - The Integration legs: each `osmgmt.<kind>mappings.read` answers the rows its list's read answers, every row carries `namespace`, and a missing criterion answers 400 `READ.CRITERION`.
- `src/OcuPilot/Test/NamespaceCopy.cls` (new): the copy matrix rows on both callers.
  - `QUEUEDWRITES` admits `MAPPINGS`.
  - The started path, through `NamespaceStartedPort`, `NamespaceStartedAction` and `NamespaceStartedConfirm` (the `AuditStarted*` seams, zero bound): the confirm answers `continues` and the route answers `continues: true`.
  - The copy-into-own legs run through `AcceptPort`. The source is a probe namespace seeded with an `OcuPilotProbe1814` global mapping, which is refused.
  - For the cut-list leg, the source is seeded with two ordinary mappings and read through `Test/MappingProhibitedFixture` (a `Prohibited` subclass whose `CopySourceCap()` answers 1), which is reached through the `ProhibitedClass` seams of `ScreenAction` (:50) and the confirm fixture. That list reads cut, and the copy is refused.
- `src/OcuPilot/Test/NamespaceInterop.cls` (new, Part C):
  - The enable-interop round trip on `OCUPROBE1814I` over `OCUPROBE1814D`, on both callers, after which `%Library.EnsembleMgr.IsEnsembleNamespace` answers 1.
  - `%SYS` refused.
  - The measured pairs' 403s with zero calls.
  - `QUEUEDWRITES` admits `INTEROP`.
  - Removal leaves no survivor.
- `scripts/ci-throwaway.sh`:
  - The NAMESPACE_CONFIG `# classes:` line gains `MappingRefusals, MappingWrite, MappingWriteGate, NamespaceCopy, NamespaceInterop`.
  - The principals block gains `MappingWriteGate` and `NamespaceInterop`, whose pair legs create principals.
- Rosters, re-derived from the code and from each class's red, never hand-counted: every roster the Code Map lists. Among them:
  - `Descriptor`'s entity count reads 36, and `ReadTool` reads 137.
  - `Prohibited`'s and `AuditingUpdate`'s code counts read 20.
  - `Navigation` shows 18 OS management screens.
  - `KERNEL_REFUSALS` gains `OCUPILOTMAPPING`.
  - `ToolWrite`'s `tOtherPorts` grows by the eleven `NamespacePort` tools.
  - `REFUSEEMPTY` gains eleven entries.
  - `EndpointCoverage` gains four routes. `SurfaceCoverage` gains a row per descriptor and tool.
- Client specs: `mapping-form.page.spec.ts`, `mapping-form.store.spec.ts`, `namespace-list.page.spec.ts` and `copy-mappings-dialog.spec.ts` (new); `namespace-form.page.spec.ts`, which gains the Mappings line; `navigation.test.mjs`, where `parentListFor` of each mapping list is `NamespaceList`; `entity-ref.test.mjs` and `screen-mirror.test.mjs` for the rule; `strings.test.mjs`.
- `ui/browser/namespace-mappings.browser-spec.mjs` (new, the `namespaces.browser-spec` model; cleanup by exact probe name through `docker exec ocupilot-b-ci`):
  - From a probe namespace's editor, the Mappings line opens each list.
  - A global mapping is created, edited from the name cell and deleted with the typed name.
  - The `%` line appears under Name.
  - Copy shows the running line, then the done line.
  - Enable interoperability opens its warning dialog and is canceled.
  - The DW-1337 walk runs in both themes over a list, the form and both dialogs.

**Acceptance Criteria:**

- **AC1:** Given a probe namespace holding one mapping of each kind on `ocupilot-b-ci`, when a holder of the Namespaces pairs opens its editor, then a Mappings line links the three lists.
  - Each list shows exactly the rows its read tool `osmgmt.<kind>mappings.read` answers for that namespace, and each row's id carries the namespace.
  - Each list's locator links back to Namespaces.
  - None of the lists takes a side-bar position.
- **AC2:** Given those lists, when a person creates a mapping from Create, edits it from its name cell and deletes it with the typed name, then each operation round-trips through `PUT` or `DELETE /namespace/<kind>-mapping` as follows:
  - A create answers 201.
  - An edit sends the complete template set.
  - A delete leaves the row absent after the change event.
  - The agent's confirmed `osmgmt.<kind>mappings.create`, `.update` and `.delete` behave the same, addressed by the row ids the read returned.
  - A taken name, an absent database, a lower-case routine suffix and a base-global delete while subscript mappings exist are each refused on the named field, and the instance is unchanged.
- **AC3:** Given a global mapping named `%OcuProbe1814` or `%OcuProbe1814("a")`, when the agent proposes it or a person saves it, then it is permitted.
  - The agent's proposal card is destructive and states the system-global consequence.
  - The form shows that sentence under Name before Save.
  - A routine or package mapping, a delete and a list read carry no such effect.
- **AC4:** Given the install namespace or `%ALL`, when either caller creates, changes or deletes a mapping whose name begins with OcuPilot in any case, then it is refused `PROHIBITED.OCUPILOTMAPPING` and no write reaches the port. The same name in a probe namespace is permitted.
- **AC5:** Given least-privileged principals on the throwaway, when they call the mapping and copy tools, then:
  - the two screen pairs read the lists and the form choices;
  - a write missing a declared pair is refused 403 naming that pair, with zero port calls, on both callers;
  - a holder of exactly the declared pairs writes.
- **AC6:** Given two probe namespaces, when Copy mappings is chosen on the destination's row and a source is picked, then:
  - The dialog shows "Copying mappings from <source> into <namespace> on the instance since <time>", then "Copied the mappings of <source> into <namespace>.".
  - The destination holds the source's mappings. Same-named ones are replaced and its others stay.
  - The write took `AdminPort`'s async path, admitted by `QUEUEDWRITES`, and the agent's confirmed `osmgmt.namespaces.copymappings` does the same.
  - A copy still running past the port's bound is recorded applied and marked, and both callers say "Still running on the instance. It finishes in the background.".
  - The bad-source and copy-into-own matrix rows are refused before any task is queued.
- **AC7:** Given Task 0 passed and a probe namespace over a probe database, when Enable interoperability is confirmed in its warning dialog, or the agent's `osmgmt.namespaces.enableinterop` is confirmed, then:
  - The write is queued through `QUEUEDWRITES`.
  - The running line shows, then "Enabled interoperability in <namespace>.".
  - The namespace is then interoperability-enabled.
  - A caller without one of Task 0's measured pairs is refused 403 naming it, before any port call.
  - `%SYS` is refused before any task is queued.
- **AC8:** Given the new screens and dialogs, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays below 3800 kB; if it passes `maximumWarning` (2107 kB), the warning is re-based under DW-1166 together with `angular-json.test.mjs:384`'s literal.

## Spec Change Log

- 2026-09-28, spec gate (runner): the orchestrator split the story for risk (Rule 5, by=merge_gate): Part C, SA-13's enable-interop with its Task 0 observation (DW-1776), moved to Story 18.15, which runs after 18.4; the intent block was cut to Parts A and B. The owner's DW-1784 decision (AD-44 amended: a screen replacing several classic pages unions each replaced page's custom resource into its write tools' pairs) joined the scope, routed here, with the namespace tools 18.2 shipped included. The orchestrator's 18.4 note applies to the copy: read a finished async task's result exactly once, one poller per task. The spec is `draft` for a re-plan; the first plan's Part C stays in this file's history at commit `4b73be11`.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: every call goes through `AdminPort` or `NamespacePort`, which extends it.
- AD-3: derived field lists.
- AD-4: an edit sends the complete set.
- AD-5, AD-36, AD-44: one descriptor per screen; each list and its tool read one read; the seeded parent key; each descriptor declares its classic page.
- AD-6, AD-34, AD-40: proposal and confirm; the gates at the write.
- AD-8, AD-29: the pairs and the extra pairs.
- AD-10: `OCUPILOTMAPPING`, and the strongest-confirmation `%` effect.
- AD-13, AD-14: the new types, the new rule and the change events (`secondaryEntityTypes`).
- AD-15: the marker. AD-16: `%SYS` only through the port.
- AD-21: no path field.
- AD-22: the baseline lines.
- AD-26: two queued writes.
- AD-39: violations and `PROPERTYFAULTS`.
- AD-51: two actions, and the copy's port-built body.
- AD-53, AD-55: two callers of one tool.
- AD-54: the create's absence fingerprint.
- AD-58: the read-back (a 202 is `unchecked`).
- AD-59: `Snippet` for every `NamespacePort` branch.

**Measured on `ocupilot-b-ci`, 2026-09-28** (18.2's first plan, `f473ce9b`; every probe object was removed):

- **Mapping writes.** For each kind, `PUT …-mapping?namespace=&name=` answers 201 on create, and 200 on edit while keeping omitted fields. `DELETE` answers 200, and 404 #421 when the mapping is absent.
- **Subscripts.** Creating `G("a"):("m")` also creates `G` on the namespace's default database. `DELETE G` while a subscript mapping exists answers 500 #451.
- **Names.** `%`-named globals and packages are accepted. `X_mac` creates `X_MAC`, then answers 500. The vendor's name refusals are #5854 and #448.
- **Lists.** A mapping list for an absent namespace answers 200 `[]`. A subscript mapping's list row shows Collation 0, where its `GET` shows 5, so the read-back uses the `GET`.
- **Copy-mappings:**
  - `POST /namespace/copy-mappings {SourceNamespace, DestinationNamespace}` answers 202 with a location.
  - The poll carries `{State, TaskName, Console, FailureReason, Result:{}, TimeQueued, TimeStarted, TimeFinished}`. There is no progress field, which is why "with progress" is a running line and then done or still running (the orchestrator's ruling). The task finished within 2 s.
  - The copy merges, and the source wins on a same name.
  - An absent source still gets 202, then `Failed` #420, which is why the tool refuses it first.
- **Pairs.** Every mapping write also needs `%DB_IRISSYS:WRITE`; without it the answer is `<PROTECT>` and nothing changes. The poll needs `%Admin_Operate:USE`, and it is owner-only.
- **Not measured.** Enable-interop, the copy's `%DB_IRISSYS:WRITE`, and the LIST's case handling are all Task 0's.

**Read in the vendor source on this build** (`iris_doc_get` in `%SYS`, read-only; the throwaway was not touched during this plan): the `Namespace.*` classes and `%EnsembleMgr.EnableNamespace`, as summarized in the Code Map. Enable-interop's payload (`name` query only, no body, `ShouldRunAsync`) is therefore read, not guessed. Its effects and pairs are unmeasured, which is what Task 0 gates.

**Decisions:**

- **Mapping identity.** The vendor rows carry no namespace, and the mint's fresh read sends one id parameter, so the id is the composite `[namespace, Name]`.
  - The list seeds the namespace, and `NamespacePort` splits the id and upper-cases the namespace part. `foldcase-firstpart` lowers that part at the identity layer (`ScreenAction.cls:190`, `Mint.cls:431`).
  - `SPLITQUERIES` is not used, because it splits on `/`, which a subscript can hold.
- **Seeding is implicit.** It applies when the first id part is named like the one criterion. No registry key is added. `TableProblem` already forces the part into `read.fields`, and no shipped list matches the shape: `TaskRunList`'s `TaskId` against `taskId` differs by case.
- **Placement.**
  - A list's name cell reaches its editor or one child list, never three (`data-table.ts:587-615`, where the editor wins), so the three lists are linked from the namespace editor.
  - `parentListFor` is widened so each list's locator links back.
  - The copy and interop actions are page-owned, because the lazily built handler overwrites registrations (`screen-action-handler.ts:395-408`), and `ListPage` hosts no running line.
- **The #451 delete is mapped, not pre-read.** The vendor refuses it and changes nothing (the test pins that both mappings survive), so `PROPERTYFAULTS` is the one mechanism, with no list read in the mint. The routine suffix is refused before any call, because the vendor applies it and then fails.
- **No `VERIFIEDDELETES` for mappings.** Nothing was measured that answers a delete wrongly. AD-58's read-back already expects absence. It also avoids a re-read through the split.
- **The `%` guard.**
  - The harvested rule refuses a base `%`-global create without `force`. Under the owner's developer-tool-first direction, `force` becomes AD-10's strongest confirmation, and no request field bypasses anything.
  - Coverage widens to every `%` name, because the vendor creates the base mapping for a subscript: measured for a non-`%` global, and an inference for `%`.
  - Coverage also includes edits, which the sibling has no equivalent for.
  - It lives in the kernel's `WeakensByEffect`, and `Mint` asks it on a create for this one type.
- **Copy and interop are destructive on the agent's card**, since a copy replaces same-named mappings and enable-interop grants access that OcuPilot cannot undo. On the screen, copy's dialog and interop's warning are the confirmation (EXPERIENCE `:173`); neither is a typed-name delete.
- **Governance.** The mapping deletes and copy join the baseline `true` by orchestrator ruling. Enable-interop joins `true` under AD-22's default: it removes nothing, and the destructive treatment carries it.
- **Classic pages (AD-44).** The lists replace `%CSP.UI.Portal.Mappings`, the one classic list for all three kinds. Each form replaces its kind's dialog. Enable-interop sits on the classic New Namespace page, whose custom resource is not unioned; this is an occurrence of DW-1784 for the runner to ledger, and it is not built on.
- **Enable-interop is a row action, not a New Namespace checkbox**, because the namespace create is 18.2's shipped form. Whether a namespace is already enabled is not shown: the read has no such field, and re-running the vendor's enable is its upgrade path (inference).

**Size and recommended split (the gate's call; nothing is dropped).**

- Parts A and B are the 10 write tools, 6 screens, id rule, read extension, port and queued write that 18.2's planner sized at about three times 18.1.
- Part C adds an observation-gated write whose probe harness creates databases and whose effects span security objects.
- Recommended: keep Parts A and B as Story 18.14, and move Part C with DW-1776 to a new story after it (for example 18.15, "Enable interoperability"), with Task 0 as that story's first task.
- If the gate keeps Part C here, Task 0 runs first as written, and Part C is built last, after Parts A and B are each green.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate).** Enable-interop's AD-8 and AD-26 sentences follow Task 0, through the Spec Change Log.

1. **AD-8, after the Story 18.2 paragraph:** "**Story 18.14's mapping and copy tools declare pairs beyond their screen's set** [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]: every global, routine and package mapping write declares `%DB_IRISSYS:WRITE`, because a principal holding only the Namespaces screens' `%Admin_Manage:USE` and `%DB_IRISSYS:READ` was answered `<PROTECT>` on every mapping write and nothing changed (measured on `ocupilot-b-ci`, 2026-09-28). `osmgmt.namespaces.copymappings` declares `%Admin_Operate:USE` under the endpoint clause, the `AsyncResult` gate the port polls the queued `Namespace.Namespace` `MAPPINGS` through. Each is refused by name before any port call."
2. **AD-10, a new bullet:** "**OcuPilot's own mappings** [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]: creating, changing or deleting, in the namespace OcuPilot's API runs in or in `%ALL`, a global, routine or package mapping whose name begins with `OcuPilot` in any case, and copying mappings into either namespace from a source that holds one, is refused `PROHIBITED.OCUPILOTMAPPING`, from either caller; the source's lists are read at the write and a list cut at its cap is refused. Such a mapping moves OcuPilot's protected globals out of its database (AD-9) or lets other code answer for its classes. A global mapping whose name begins with `%` shadows a system global for its namespace; it is **permitted at the strongest confirmation** (effect `MAPPING.SYSTEMGLOBAL`: the agent's proposal is minted destructive with the consequence, a person's Save shows it at the field), for a create as for a change, because the vendor creates a subscript mapping's base mapping too."
3. **AD-26, the `QUEUEDWRITES` paragraph, appended:** "…and `Namespace.Namespace` `MAPPINGS` (Story 18.14, copy-mappings, body `{SourceNamespace, DestinationNamespace}` built by the port, no secret), which the vendor queues through `ShouldRunAsync()` (read on this build) [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]."
4. **AD-36, a new paragraph:** "**A parent-scoped list may carry its parent's key on its rows** [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]. Where a parent-scoped admin `LIST` answers rows without the parent's key (a namespace's mapping lists), and its composite id's first part is named like its one criterion, the read refuses a missing criterion as the single-object read does and seeds the criterion's value onto each row under that part before projection, so the row's id carries the namespace its write addresses. Screen and tool read the same seeded rows."
5. **AD-51, the port-built body list, appended:** "…and `NamespacePort`, which builds `Namespace.Namespace` `MAPPINGS`'s body from the destination (the target) and the tool's declared `SourceNamespace` (Story 18.14) [AMENDED 2026-09-28, Story 18.14 spec gate, Rule 20]."

**Integration ACs:**

- AC1 is pinned by `MappingDescriptor` and the browser spec. Each mapping list and its read tool answer one read (AD-36), with the namespace seeded on every row.
- AC2 is pinned by `MappingWrite`. The mapping tools consume the seeded row ids through `NamespacePort`.
- AC6 is pinned by the browser spec and `namespace-list.page.spec.ts`. The copy dialog consumes `NamespaceList`'s declared read. The copy predicate consumes the three lists' reads.

**Consumes:**

- 18.2's `NamespaceList`, `NamespaceForm` and `NamespaceRules.Databases`, and the `namespace` type;
- `AdminPort`, and the `AuditPort` and `AuditCopy` models;
- the screen-action value path;
- 16.17's read-back, 14.1's `Snippet` and 14.2's baseline;
- the typed-name and warning dialogs;
- the panel's still-running line.

**Consumed-by:**

- 18.3: its database delete's impact reads the namespaces through `NamespaceList`.
- 18.12: the agent's grown tool set.
- 18.13: multi-namespace install, under which `OCUPILOTMAPPING` and the install-namespace predicate must keep holding (DW-1788).

**Ledger inbox:** DW-1776 is addressed by Part C and Task 0, with the split recommended above. DW-1774 is met, because no side-bar list changes (Code Map, Rosters). DW-1784 is not built on (classic pages, above).

**Contended with Epic 16, all edited add-only:** `Error.cls`, `Router.cls`, `Baseline.cls`, `strings.ts`, EXPERIENCE.md, the rosters, `ci-throwaway.sh` and `ci.test.mjs`. `screens.generated.ts` and `ToolFields.cls` are regenerated. Not touched: `Screen/Area.cls` and `scripts/check-objectscript.py`.

## Verification

**Setup (slot B):**

- Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src`, and load it on `ocupilot-b-ci` only.
- Every mapping, copy and interop write happens there, on `OCUPROBE1814*` objects. MCP calls carry `server: "ocupilot-slot-b"`, and no admin API write reaches a dev instance.
- Stateful classes are armed per call with `docker exec -e OCUPILOT_ALLOW_NAMESPACE_CONFIG=1` (plus `OCUPILOT_ALLOW_PRINCIPALS=1` for the gate class) if the throwaway predates the arming block.
- Run one test class per call, and start the next only once the previous run has landed in `%UnitTest_Result`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expected: 0 failures each, with totals checked against `%UnitTest_Result`. The classes are:
  - `MappingWrite`, `MappingRefusals`, `MappingWriteGate`, `MappingDescriptor`, `NamespaceCopy`, `NamespaceInterop` (Part C);
  - `NamespaceWrite`, `NamespaceRefusals`, `NamespaceDescriptor`;
  - `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Prohibited`, `RefusalCopy`;
  - `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `AuditingUpdate`;
  - `ToolWrite`, `ToolRoundTrip`, `DraftRegistry`, `ProposalPrivilege`, `AdminPortAsync`, `AuditStarted`, `EntityRef`;
  - `Navigation`, `Wire`, `WireSecurityRead`, `ScreenGrounding`, `Envelope`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/namespace-mappings.browser-spec.mjs browser/namespaces.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 993.
- `(once, before dev_complete)`:
  - the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, which runs one class at a time;
  - then `cd ui && npm test && npm run build`;
  - then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
  - Expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway's source copy, observe red, revert byte-identical, and record a `mutation:` line. Predicate mutations run only against `AcceptPort`.

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
| AC7 | `INTEROP` removed from `QUEUEDWRITES` | `NamespaceInterop` (refused); `AdminPortAsync` |
| AC8 | A field label drawn in `--ocu-surface` | the DW-1337 legs, in both themes |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only; no code changed. Parts A (mappings), B (copy-mappings) and C (enable-interop, DW-1776) are specified in build order, and Part C is gated by Task 0's observation, with explicit halt conditions. Design Notes recommends moving Part C to its own story, and it carries five spine amendments for the runner to write at the spec gate. The throwaway was not touched. The vendor classes were read through `iris_doc_get` on `ocupilot-slot-b`, read-only.
