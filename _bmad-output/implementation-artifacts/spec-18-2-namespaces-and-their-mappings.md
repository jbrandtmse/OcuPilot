---
title: 'Story 18.2: Namespaces and their mappings'
type: 'feature'
created: '2026-09-28'
status: 'done'
baseline_revision: 'b329f89286e80a95206aaee3d03f558e5138e7cd'
baseline_commit: 'b329f89286e80a95206aaee3d03f558e5138e7cd'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
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

**Vendor** (payloads under Design Notes):

- `%Api.Admin.Dispatch.v2`: `GET /namespaces` (`Namespace.Namespace` `LIST`), `GET|PUT|DELETE /namespace?name=`, and `GET /databases` (`Database.ConfigCRUD` `LIST`, rows `{Name, Directory, Server, …}`), the forms' database names. The routes are `src/OcuPilot/Port/AdminRoutes.cls:132,135`. The `PUT` template `{Globals, Routines, TempGlobals}` is already derived at `Screen/Tool/FieldLists.cls:136-140`, so nothing is regenerated from an instance.
- Classic pages (AD-44), each `RESOURCE = %Admin_Manage` (`irissys/%CSP/UI/Portal/`): `Namespaces` (list), `Namespace` (New Namespace), `NamespaceEdit`, `Dialog.NamespaceDelete`.

**Port:** `src/OcuPilot/Port/AdminPort.cls` -- `MUTATINGTYPES` :302, `BODYLESSTYPES` :318, `VERIFIEDDELETES` :348, each entry's measured fact in the doc comment above it (:284-347). `src/OcuPilot/Test/PortFixture.cls:21` holds a copy of `MUTATINGTYPES`.

**Tools** (`src/OcuPilot/Screen/Tool/`):

- `Write.cls`: `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `CREATES` :141, `SCREENACTIONS` :157, `READANSWERS` :170; `IdArgument`/`IdParam` :500/:507 already answer `Name`/`name`; `ArgumentProblem` :786.
- `DeviceCreate.cls`, `DeviceUpdate.cls`, `DeviceDelete.cls`: the three shapes to copy -- `PrivilegePairs` adding `WRITERESOURCE:WRITEPERMISSION` (DeviceCreate :159-166), and `REMOVALROWS` with `StateDiff` (DeviceDelete).
- `Classification.cls` device entries :443-468; `ToolFields.cls` is regenerated by `cd ui && node tools/field-lists.mjs`.

**Kernel:**

- `Kernel/EntityType.cls:40` `TYPES` (32 values); `Kernel/EntityRef.cls:59` `IDRULES` (`foldcase` exists, and the client's `ui/src/app/core/entity-ref.ts:71` implements it).
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250, `Codes()` :470, `ReasonFor` :478, `PermittedChangeFields` :580, `PermittedCreateFields` :691, `Prohibits` :777 (type chain :788, create branch :807-816, the wallet delete's `Kill tChanged` idiom :849-853), `ReviewedFewOnly` :1776, `Refuse` :3014.
- `Kernel/Proposal/Impact.cls`: kinds :20-30, `Of` :92, `KindOf` :157, `Guarded` :282 (matches `Resource` only), `ListRows` :332 (gate, read, a cut read answers unchecked), `Fill` :373 (three names shown).
- `Kernel/Governance/Baseline.cls` :21-23, the device lines.
- The install namespace is the API process's own: the router never switches `$NAMESPACE` (`Api/Router.cls:1139,1213`), and a turn job refuses to run in another (`Kernel/Agent/Job.cls:89`).

**Screens:** `Screen/Descriptor/DeviceList.cls` and `DeviceForm.cls` are the models, and `RoleList.cls:46` declares a `delete` row action. OS management's positions 1-5 are Processes, Locks, System usage, Databases and Devices. `Screen/Registry.cls:2538` is `PROMPTGROUPKEYS`.

**Save routes:** `Area/OsMgmt/DeviceRules.cls` (`HandleForm` :230, `HandleName` :293, `SubTypes` :389, a list read through the tool's port) and `DeviceSave.cls` (`Create` :115, `Update` :160, `PortViolations` :232, `Prohibited` :248). `Api/Router.cls` device routes :113-116, handlers :527-554. `Api/Error.cls` device codes :2343-2444. `Api/ScreenImpact.cls` (the dialog's impact, generic) and `Api/ScreenAction.cls:43` (`PortClass` seam).

**Client:**

- `ui/src/app/areas/os-management/device-actions.ts`, `device-form.page.ts` (:445, the refusal action), `device-form.store.ts`: the models.
- `ui/src/app/shell/screen-outlet.ts:134` `DESCRIPTOR_PAGES`; `ui/src/app/app.ts:297-299,597-598`.
- `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :50, `IMPACT_ACTIONS` :188, `DESTRUCTIVE_CONSEQUENCES` :202, `openWithImpact` :646.
- `ui/src/app/core/impact.ts`: `ImpactKind`/`ImpactPartName` :14-23, `IMPACT_PARTS` :26, `PHRASES`, `phraseOf` :157.
- `ui/src/app/core/scope.ts`: `ScopeOptions` :52, `load` :276. `ui/src/main.ts:122` builds the scope and :170 the bus. `core/agent-status.ts:251-254,383,535-539` is the bus re-read model.
- `ui/src/app/core/shortcuts.ts:10-16` (the unbuilt count) and :33 (`os-management/namespaces` is first).
- `ui/src/app/core/strings.ts`: impact phrases :3031ff. Reuse `tableColumnName`, and `headerNamespaceLabel` ("Namespace") as the form's title, since a second key with that value fails `strings.test.mjs`'s uniqueness.

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 993 lines): :164 OS management side bar, :173 dialogs, :378 the Devices Fixed-strings row, :479 delete bodies, :481 kernel refusals, :577 impact phrases.

**Rosters naming the OS management screens or the tool set** (`grep -rl 'osmgmt.devices\|DeviceList\|os-management/devices'`):

- ObjectScript: `Test/Descriptor.cls` (`ReadShapes` :67-118, entity count :1699), `ReadTool.cls` :94,112, `SurfaceCoverage.cls` :73,143-145, `EndpointCoverage.cls` :184-187, `Navigation.cls` :328-354, `Wire.cls:697`, `WireSecurityRead.cls` :548-558, `ScreenGrounding.cls` :66-84, `ProposalPrivilege.cls:95`, `Prohibited.cls` :218 (covered types) and :672 (18 codes), `RefusalCopy.cls:107`, `GovernanceBaseline.cls` :50-67 (the `false` set).
- Client: `ui/tools/navigation.test.mjs` :150-159, `navigation-wire.test.mjs` :90-165, `ui/src/app/shell/rail-wire.spec.ts` :88-160, `ui/tools/self-protection.test.mjs:253` (`KERNEL_REFUSALS`), `ui/src/app/areas/home/home.page.spec.ts:1057`.
- No browser spec pins OS management's side bar (`grep -l ocu-side-bar-label ui/browser`).

**Test models:**

- `Test/DeviceWriteGate.cls` with `DeviceWriteGateProbe` (a child process logged in as the principal; `EnsurePrincipals` :274-304).
- `DeviceRecordPort.cls` (records, then passes through, for any endpoint), `DeviceConfirm.cls` (the `ConfirmFixture` seam), `AcceptPort.cls` (accepts every call and writes nothing), `SslActionFixture.cls` (the `ScreenAction` seam).
- `DeviceProbe.cls` (`RemoveAll`, `CpfValid`) and `GovernanceFixture.cls` (`Snapshot`, `Apply`, `Restore`; used at `AuditPurge.cls:180-183`).
- Arming blocks: `scripts/ci-throwaway.sh` :172-350, derived by `ui/tools/ci.test.mjs:1818-1990`.
- `OcuPilot.Test.NamespaceProbe`, `NamespaceFixture`, `NamespaceInfoFixture` and `Namespaces` already exist (installer and shell tests), so the new names avoid them.
- Browser: `ui/browser/device-editor.browser-spec.mjs` :59-120 (`docker exec` cleanup), `oauth-resource-server-editor.browser-spec.mjs` :127-157 (the DW-1337 `assertStructure`), `impact.browser-spec.mjs`.

## Tasks & Acceptance

**Execution** (in dependency order):

- `src/OcuPilot/Kernel/EntityType.cls`, `Kernel/EntityRef.cls` -- append `namespace` to `TYPES`; add `namespace:foldcase` to `IDRULES` -- the vendor resolves a name without case and stores it upper case (measured).
- `src/OcuPilot/Port/AdminPort.cls` -- add `Namespace.Namespace/PUT` and `/DELETE` to `MUTATINGTYPES`, `/DELETE` to `BODYLESSTYPES` and `VERIFIEDDELETES`, each with its measured fact; add the two to `Test/PortFixture.cls`'s copy -- the delete's answer was measured not to track its outcome (500 after a completed delete), so a 2xx is re-read before it is believed.
- `src/OcuPilot/Api/Error.cls` -- after the device block, add these codes with their reasons:
  - `NAMESPACE.NAME.REQUIRED`: "Name the namespace."
  - `NAMESPACE.NAME.SHAPE`: "A namespace name starts with a letter or %, then letters, digits, _ or -, at most 64 characters."
  - `NAMESPACE.NAME.TAKEN`: "This instance already has a namespace with that name. Choose a different one."
  - `NAMESPACE.NAME.ABSENT`: "This instance has no namespace with that name."
  - `NAMESPACE.GLOBALS.REQUIRED`, `NAMESPACE.ROUTINES.REQUIRED`: "Choose a database."
  - `NAMESPACE.{GLOBALS,ROUTINES,TEMPGLOBALS}.ABSENT`: "No database on this instance has that name."
- `src/OcuPilot/Area/OsMgmt/NamespaceRules.cls`, `NamespaceSave.cls` (new, the `DeviceRules`/`DeviceSave` model):
  - Name: required; `^[%A-Za-z][A-Za-z0-9_-]{0,63}$`, pinned by a corpus against the instance; taken when an existing name matches ignoring case.
  - Globals and Routines: required. Each, and TempGlobals when sent, must equal a `Name` of `Database.ConfigCRUD` `LIST` ignoring case, read through the tool's port as the caller. `DerivedFields` sends the list's own spelling.
  - `HandleForm` answers `{requiredFields, rules, databases}`, and with `?name=` also `namespace {Name, Globals, Routines, TempGlobals}` from the update tool's fresh read (404 `NAMESPACE.NAME.ABSENT` when absent). `HandleName` answers `{name, taken, reason}`.
  - `NamespaceSave` runs the create and update tools as `DeviceSave` does: gate, rules, prohibited set, send, read-back. `PortViolations` maps the vendor's #457 and #7201 to `NAMESPACE.NAME.SHAPE`, and #420 to the database field.
- `src/OcuPilot/Api/Router.cls` -- add `GET /namespace/form`, `GET /namespace/name`, `PUT /namespace/:id` and `POST /namespace` with thin wrappers, in the device quartet's order. The shell's `/namespaces` is another segment and is unaffected.
- `src/OcuPilot/Screen/Tool/NamespaceCreate.cls`, `NamespaceUpdate.cls`, `NamespaceDelete.cls` (new, the device model; `DESCRIPTORCLASS` `NamespaceList`, endpoint `Namespace.Namespace`, `READTYPE` `GET`):
  - `osmgmt.namespaces.create`: `CREATES` 1, `PUT`; `PERMITTEDFIELDS` `Globals,Routines,TempGlobals`, `REQUIREDFIELDS` `Globals,Routines`; `ArgumentProblem` and `DerivedFields` apply `NamespaceRules`.
  - `osmgmt.namespaces.update`: a merge `PUT` sending the complete `{Globals, Routines, TempGlobals}` read fresh (AD-4); its `ArgumentProblem` and `DerivedFields` apply `NamespaceRules` to the fields the arguments change, as `DeviceUpdate` does.
  - `osmgmt.namespaces.delete`: `DELETE`, `SENDSBODY` 0, `DESTRUCTIVE` 1, `CHANGEACTION` `deleted`, `SCREENACTIONS` `delete`; `READANSWERS`, `FINGERPRINTSUBJECT` and `REMOVALROWS` are `Globals,Routines,TempGlobals`; `PRECONDITIONFIELD` is `Globals`.
  - `PrivilegePairs`: the list's pairs, plus `%DB_IRISSYS:WRITE` on all three and `%Admin_Secure:USE` on the delete, each refused by name before any port call.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- add create and update entries over `Namespace.Namespace`, all three fields `ordinary`; then run `cd ui && node tools/field-lists.mjs` -- AD-3.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `namespace` joins `COVEREDTYPES` and the type chain, with permitted create and change fields `Globals, Routines, TempGlobals`.
  - Add `OCUPILOTNAMESPACE` (`PROHIBITED.OCUPILOTNAMESPACE`) with its `REASON` (the `:481` sentence below), `Codes()` entry and `ReasonFor` line.
  - A `Namespace` predicate. The target is own when its id, upper-cased, is `%SYS` or the process's `$NAMESPACE`, read at each evaluation. A delete of an own target, or a change to an own target whose `Globals` or `Routines` changed, is refused `OCUPILOTNAMESPACE`. Everything else takes the reviewed-fields sweep. A create goes through `Created` with its permitted fields.
- `src/OcuPilot/Kernel/Proposal/Impact.cls`:
  - Add kind `namespace-delete` for `osmgmt.namespaces.delete`.
  - Part `boundApplications`: `WebAppList` rows whose `Namespace` equals the id ignoring case, named by `Name`. `Guarded` gains a match-field argument, defaulting to `Resource`.
  - Part `databases`: the distinct `Globals`, `Routines` and `TempGlobals` of the fresh read. It is never unchecked.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- add `"osmgmt.namespaces.create": true`, `"osmgmt.namespaces.delete": false` and `"osmgmt.namespaces.update": true`, in name order.
- `src/OcuPilot/Screen/Descriptor/NamespaceList.cls` (new, a list):
  - route `os-management/namespaces`, `labelKey` `namespaceListLabel`, `sideBarPosition` 6, pairs `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, entity `namespace`, scope `instance`, id `single`, no refresh;
  - read `{admin, Namespace.Namespace, LIST}`; fields, filter and sort `Name, Globals, Routines, TempGlobals` (default `Name` ascending); paging `cap`;
  - columns Name (`tableColumnName`, `name`), then "Globals database", "Routines database" and "Temporary database" (`identifier`);
  - `primaryAction` `create`, `rowActions` `[{delete, ""}]`, `emptyStateKey` `namespaceListEmpty`, `emptyAgentKey` `namespaceListEmptyAgent`;
  - `classicPage` `%CSP.UI.Portal.Namespaces`, `commandAliases` `["namespaces","configure namespace"]`, three `promptGroupGettingStarted` prompts, `toolIdentifier` `osmgmt.namespaces`.
- `src/OcuPilot/Screen/Descriptor/NamespaceForm.cls` (new, `form-page`): route `os-management/namespaces/edit`, `labelKey` `headerNamespaceLabel`, position 0, the list's pairs, id `single`; `classicPage` `%CSP.UI.Portal.NamespaceEdit`; three prompts; `toolIdentifier` `osmgmt.namespaceform`.
- `ui/src/app/areas/os-management/namespace-actions.ts`, `namespace-form.page.ts`, `namespace-form.store.ts` (new, the device model):
  - Create on the list. Name, then the three database fields as native selects fed by `/namespace/form`; TempGlobals offers an empty choice on create.
  - An edit shows the name read-only. The refusal action reads "create a namespace" or "change this namespace".
  - Register the page in `DESCRIPTOR_PAGES`; inject the actions and the store's `reset()` in `app.ts`.
- `ui/src/app/shell/screen-action-handler.ts` -- `NamespaceList` joins `SCREEN_ACTION_DESCRIPTORS`, its `delete` joins `IMPACT_ACTIONS`, and its consequence joins `DESTRUCTIVE_CONSEQUENCES`.
- `ui/src/app/core/impact.ts` -- add kind `namespace-delete` with parts `boundApplications` (all four phrases) and `databases` (`many` and `one` only; a `databases` part counted 0 or unchecked renders nothing).
- `ui/src/app/core/scope.ts`, `ui/src/main.ts` -- `ScopeOptions` gains an optional `bus`. A `changed` event of type `namespace` with action `created` or `deleted` re-runs `load()`, the `AgentStatus` shape. `main.ts` builds the bus before the scope and passes it, so the switcher offers a new namespace and drops a deleted one without a reload.
- `ui/src/app/core/shortcuts.ts` -- the comment's count of unbuilt rows becomes six.
- `ui/src/app/core/strings.ts` (append, each key citing its EXPERIENCE row; keys on the device convention: `namespaceListLabel`, `namespaceColumnGlobals`, `namespaceColumnRoutines`, `namespaceColumnTemp`, `namespaceListEmpty`, `namespaceListEmptyAgent`, `namespaceFormRefusedAction`, `namespaceListPrompt1`-`3`, `namespaceFormPrompt1`-`3`, `namespaceDeleteConsequence`, `namespaceRefusalOcuPilot`, `impactBoundApplications`, `impactBoundApplicationsOne`, `impactBoundApplicationsNone`, `impactBoundApplicationsUnchecked`, `impactDatabasesStay`, `impactDatabasesStayOne`) and `EXPERIENCE.md`, edited in place and still 993 lines:
  - `:164`: the third cell gains "Namespaces (Stage 2, Story 18.2)".
  - `:173`: "namespace" joins the delete confirmations.
  - `:378` gains these literals, and its where-clause ends `[ADDED 2026-09-28 - Story 18.2]`:
    - "Namespaces" · "Globals database" · "Routines database" · "Temporary database" · "No namespaces on this instance." · "create a namespace" · "change this namespace";
    - "Which databases does each namespace use for its globals and routines?" · "Which namespaces share a database?" · "What would deleting a namespace take with it?";
    - "Which database should a new namespace use for its globals?" · "What changes if this namespace reads its routines from another database?" · "Which web applications run in this namespace?"
  - `:479`: "Deleting this namespace also deletes its mappings and every web application that runs in it. Its databases stay. This cannot be undone."
  - `:481`: "OcuPilot or the instance itself runs in this namespace. It cannot be deleted, and its globals and routines databases cannot be changed."
  - `:577`: "<n> web applications run in it and are deleted with it: <names>" · "1 web application runs in it and is deleted with it: <names>" · "no web application runs in it" · "which web applications run in it was not checked" · "it uses <n> databases, which stay: <names>" · "it uses 1 database, which stays: <names>".
- `ui/src/app/core/screens.generated.ts` -- regenerate with `cd ui && node tools/screen-mirror.mjs`.

**Tests:**

- `src/OcuPilot/Test/NamespaceWriteProbe.cls` (new, not a test case; the `DeviceProbe` model): namespaces `OCUPROBE182*` over the existing `USER` databases, created and removed through `AdminPort` and never through `Config.Namespaces`; their bound web applications `/csp/ocuprobe182*` and one seeded global mapping, created in `%SYS` (test-only). `RemoveAll` works by exact prefix; `CpfValid` checks the CPF.
- `src/OcuPilot/Test/NamespaceSaveFixture.cls`, `NamespaceActionFixture.cls`, `NamespaceConfirm.cls` (new seams on `NamespaceSave`, `ScreenAction` and `ConfirmFixture`): the port is the one a test names in `^||OcuPilotNamespaceWritePort`, and `OcuPilot.Test.AcceptPort` when none is named.
- `src/OcuPilot/Test/DeviceRecordPort.cls` -- also record each call's query subscripts (add-only), so the delete's query is pinned to `name` alone.
- `src/OcuPilot/Test/NamespaceWrite.cls` (new; refuses unless `OCUPILOT_ALLOW_NAMESPACE_CONFIG` reads 1; `RemoveAll` before all, after each and after all, and a survivor fails the class):
  - One method per matrix row, on both callers (the agent's mint and confirm; `NamespaceSave` and the screen action route): create; taken, in another case; the bad-name corpus; unknown database; an edit sending the complete set; a delete with two bound probe applications, after which the namespace, its mapping and both applications are gone and `USER` and `IRISTEMP` remain; the delete's query carrying `name` alone.
  - The impact from `Impact.Of`, from `ScreenImpact` and on the agent's proposal row, with the delete key enabled through `GovernanceFixture` (`Snapshot` first, `Restore` after). At the baseline the agent's delete is refused `GOVERNANCE.DISABLED` while the screen's proceeds.
  - The own-namespace legs aim at `$NAMESPACE` and `%SYS`: a delete, a `Globals` change and a `Routines` change are refused, and a `TempGlobals`-only change is permitted. They write through `AcceptPort` on both callers, so a removed predicate shows as an accepted write, never a deleted namespace.
- `src/OcuPilot/Test/NamespaceWriteGate.cls` with `NamespaceWriteGateProbe.cls` (new, the `DeviceWriteGate` model; refuses unless both `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_NAMESPACE_CONFIG` read 1; calls counted through `DeviceRecordPort`):
  - A reader holding the two screen pairs reads the list, the form's database choices and the name check.
  - A writer without `%DB_IRISSYS:WRITE` is refused 403 naming it on create and edit; a deleter without `%Admin_Secure:USE` is refused 403 naming it. Each is refused on both callers, with zero port calls, and the target is still present afterwards.
  - A principal holding exactly the declared pairs creates, edits and deletes a probe namespace on both callers (AD-29). A pair the instance still demands joins the tool and this class.
- `src/OcuPilot/Test/NamespaceDescriptor.cls` (new, stateless): both declarations, and the Integration row -- `osmgmt.namespaces.read` answers the rows the list's read answers.
- `scripts/ci-throwaway.sh` -- a new block `OCUPILOT_ALLOW_NAMESPACE_CONFIG: "1"` with `# classes: NamespaceWrite, NamespaceWriteGate`; `NamespaceWriteGate` also joins the principals block's `classes:` lines.
- Rosters, re-derived from the code and from each class's red, never hand-counted: every roster the Code Map lists. Among them, `Descriptor`'s entity count reads 33, `Prohibited`'s codes 19, `GovernanceBaseline`'s `false` set gains `osmgmt.namespaces.delete`, `EndpointCoverage` gains four probes, `SurfaceCoverage` a row per descriptor and tool, `KERNEL_REFUSALS` gains `OCUPILOTNAMESPACE`, and `home.page.spec.ts:1057` expects `os-management/namespaces`. Also `ui/tools/scope.test.mjs` (the re-read), `impact.test.mjs` and `screen-action-handler.spec.ts`.
- `ui/src/app/areas/os-management/namespace-form.page.spec.ts`, `namespace-form.store.spec.ts` (new, on the device specs).
- `ui/browser/namespaces.browser-spec.mjs` (new, the `device-editor` model, cleaning up by exact probe name through `docker exec`): AC1, AC2 and AC4's DW-1337 walk in both themes. The own-namespace leg only opens and cancels the dialog.

**Acceptance Criteria:**

- **AC1:** Given a holder of the Namespaces pairs on `ocupilot-b-ci`, when they open OS management, then "Namespaces" is its sixth side-bar entry and lists every namespace with its globals, routines and temporary databases -- the rows `osmgmt.namespaces.read` answers, narrowed only by its cap.
  - When they create a namespace from Create, it round-trips through `PUT /namespace` (201) and the row is present after the change event; a taken name is refused before any `PUT`.
  - When they change its routines database on its editor, the Save sends the complete set.
  - The agent's confirmed `osmgmt.namespaces.create` and `.update` do the same.
  - After either caller's create or delete, the namespace switcher offers the new namespace, and never the deleted one, without a reload.
- **AC2:** Given a probe namespace with two bound web applications, when Delete is chosen on its row, then before anything is removed the typed-name dialog's advisory names both applications as deleted with it and its databases as staying. The agent's proposal, with its key enabled, carries the same impact.
  - After the typed name and Delete, the namespace, its mappings and both applications are gone, and every database remains.
  - Deleting OcuPilot's install namespace or `%SYS`, or changing its globals or routines database, is refused `PROHIBITED.OCUPILOTNAMESPACE` from either caller, and the dialog states that reason when it opens.
- **AC3:** Given least-privileged principals on the throwaway, when they call the namespace tools, then:
  - the two screen pairs read the list and the form's database choices;
  - a write without `%DB_IRISSYS:WRITE`, and a delete without `%Admin_Secure:USE`, are each refused 403 naming that pair before any port call, and after the refused delete the namespace still exists;
  - a principal holding exactly the declared pairs writes on both callers.
- **AC4:** Given the new screens, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays below 3800 kB; if it passes `maximumWarning` (2106 kB), the warning is re-based under DW-1166 together with `angular-json.test.mjs`'s literal.

### Review Findings

Code review 2026-09-28, four layers, `full-opus`. 38 rows, 33 entries: 4 patched, 6 ledgered, 23 rejected. No high. AD-8, AD-10, AD-4, AD-54, AD-22, AD-53/55, AD-39, AD-13, AD-36 and AD-58 hold. AD-44's gap is the ledgered decision below.

- [x] [Review][Patch] `[medium]` The agent's edit rules (`NamespaceUpdate.ArgumentProblem`) and the edit's REQUIRED rule had no leg with a bad value; two mutations survived [src/OcuPilot/Test/NamespaceRefusals.cls:134]
- [x] [Review][Patch] `[low]` The edit route's decode was crossed only by names it leaves unchanged; a `%`-led name now goes over the wire [src/OcuPilot/Test/NamespaceRefusals.cls:159]
- [x] [Review][Patch] `[low]` AC4's DW-1337 walk skipped the edit form (read-only name, selects locked until the read lands); USER's editor is walked now [ui/browser/namespaces.browser-spec.mjs:545]
- [x] [Review][Patch] `[low]` Three roster comments still said "the four unlisted" OS management screens, and one "the full nine" [src/OcuPilot/Test/WireSecurityRead.cls:542] (also `rail-wire.spec.ts:96`, `navigation-wire.test.mjs:99`)
- [x] [Review][Defer] `[medium]` The New Namespace page's and the Delete Namespace dialog's custom resources are never unioned (AD-44); the spec names the gap, the spine does not, and three earlier dialogs share it [src/OcuPilot/Screen/Descriptor/NamespaceForm.cls:46] — deferred: DW-1784 `decision-pending`, an owner call; mirror it in the spine's Deferred (Rule 20)
- [x] [Review][Defer] `[low]` `Taken`'s fail-closed branch on a non-404 read has no leg; the tool's own reads have no seam [src/OcuPilot/Area/OsMgmt/NamespaceRules.cls:246] — deferred: DW-1785 `wontfix-accepted`
- [x] [Review][Defer] `[low]` No principal without the screen pairs calls `/namespace/form` or `/namespace/name` [src/OcuPilot/Area/OsMgmt/NamespaceRules.cls:374] — deferred: DW-1786 `wontfix-accepted`
- [x] [Review][Defer] `[low]` A case-only database name diffs as a change before it is spelled: a phantom card row, and a refused no-op on the install namespace [src/OcuPilot/Area/OsMgmt/NamespaceSave.cls:198] — deferred: DW-1787 `wontfix-accepted`
- [x] [Review][Defer] `[low]` The install-namespace predicate reads no application binding, so an OcuPilot application repointed elsewhere would go with that namespace [src/OcuPilot/Kernel/Proposal/Prohibited.cls:1627] — deferred: DW-1788 `wontfix-theoretical`, real under 18.13
- [x] [Review][Defer] `[low]` The Save's absence read (create) and fresh read (edit) are not one transition with the upsert `PUT` [src/OcuPilot/Area/OsMgmt/NamespaceSave.cls:134] — deferred: occurrence on DW-1497 (screen writes take no per-target lock)

**Rejected:**

- `false`: `Validate`'s unused `pFresh`. Its doc says it is unread; no caller diverges.
- `false`: the gate test's agent create target is never checked absent. That leg asserts `calls=0`, so no `PUT` reached the port.
- `false`: `MappingCount` and `ApplicationsOf` pass vacuously on a failed query. Probed on `ocupilot-b-ci`: both queries answer OK with no rows for an absent namespace, and the pre-delete legs assert 1 mapping and 2 applications through the same helpers.
- `false`: the commit's "the create fingerprints absence". AD-54 binds the tool's mint and confirm, which do.
- `false`: Rule 3 for the agent's card impact and switcher path. Every AC has a real-runtime test; the card renders 16.19's shared line, whose namespace phrases `impact.test.mjs` pins, and the switcher re-reads on the one event both callers publish.
- theoretical: the kernel does not refuse a create named `%SYS` or the install namespace. Both are always present, and both callers refuse a present target first (AD-54's absence read, the Save's `Taken`).
- theoretical: `Taken` reads a 2xx answer that is not an object as free. The vendor answers a present namespace with its object.
- theoretical: a vendor `DELETE` that answers non-2xx after deleting. The one measured case is refused by name before any port call (AD-8); DW-1775 carries the vendor defect.
- theoretical: `RemoveAll`'s recount failing right after the removals. Throwaway hygiene.
- `low`: an empty `TempGlobals` reads "No database on this instance has that name.". Agent-only (the form omits an empty choice), the field is named, and a fix is a new published sentence.
- `low`: the name check answers `taken:false` for a malformed name. It answers taken-ness only, as `DeviceRules` does; the shape refusal lands at Save.
- `low`: an edit Save with nothing changed still sends its `PUT`. The form sends no unchanged edit, and the rewrite changes nothing.
- `low`: the own-namespace legs hard-code `USER`. On an install namespace over `USER` they go red, never falsely green; the throwaway installs into HSCUSTOM.
- `low`: the form test asserts `>= 3` prompts and no `built`. Three is AD-5's floor, which the registry validates; `Navigation` pins the route of a built screen only.
- `low`: `TestThePurgeIsTheOneDisabledLine` no longer describes its assertion, the disabled set is written in three rosters, and several roster files were restructured rather than appended to. Each is a contended roster; another rename or refactor widens the integrate-forward surface for no behavior.
- `low`: the browser spec seeds through `Config.Namespaces` in `%SYS`. It is the device-editor model on the throwaway, seeds no mapping, and asserts every probe gone.
- `low`: a ninth copy of the I/O capture block. A shared helper is a refactor across nine classes.
- `low`: a namespace event arriving while a list read is in flight is absorbed by it. It needs a read already in flight at that moment, and a fix adds a pending re-read flag.
- `low`: the form and name routes render a port refusal as a generic 500, as `DeviceRules` does. It needs a port-level failure behind a caller who passed the gate.
- `low`: spec lines `:49`, `:72` and `:73`, and the Auto Run Result's counts. Each fix edits this spec.

## Spec Change Log

- 2026-09-28, spec gate (runner): the orchestrator split the story (Rule 5, by=merge_gate): Part B, the mappings and copy-mappings (epic AC2 and AC3), moved to Story 18.14 with SA-13's enable-interop (DW-1776). The intent block above was cut to Part A and the spec set to `draft` for a re-plan of Part A only. The Part B research (payloads, amendments, tasks) stays in this file's history at commit `f473ce9b` for 18.14's plan. Also approved at the gate: namespace delete joins the baseline disabled.
- 2026-09-28, spec gate (runner, after the re-plan): the three proposed amendments under Design Notes were written into the spine verbatim (Rule 20): AD-8 gains two paragraphs (the namespace tools' extra pairs; the namespace delete's removal impact), and AD-10 gains the `PROHIBITED.OCUPILOTNAMESPACE` bullet. The spine is the authority from here.

## Review Triage Log

### 2026-09-28 — Review pass

- verdicts: 21 findings — high 0, medium 3, low 13, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) An edit of a namespace deleted since the read had no test of its 404, the guard that keeps the upsert from re-creating it — added `NamespaceRefusals.TestAnEditOfADeletedNamespaceIsRefusedAndNotRecreated` (Save 404 with nothing sent; agent mint, delete, confirm 409 `TARGETCHANGED`); its mutation reddened it (run 418).
  - `[low]` `[patch]` (verification-gap) `Namespace.Namespace/DELETE` in `VERIFIEDDELETES` was not load-bearing in any test — added `NamespaceRefusals.TestAReportedDeleteThatLeftTheNamespaceIsNotApplied` over `RoleDeletePort`; removing the entry reddened it (run 421).
  - `[medium]` `[patch]` (verification-gap) The namespace violation-code roster and the create's REQUIRED rules had no server test — `NamespaceDescriptor` now asserts every code's sentence, its field and one rule per code; `NamespaceRefusals.TestACreateWithoutItsDatabasesIsRefusedOnEachField` pins both callers (run 419 red under the mutation).
  - `[medium]` `[patch]` (verification-gap) A key outside the three was untested on either Save route — added `NamespaceRefusals.TestAKeyOutsideTheThreeIsRefusedOnBothSaves` (create 403 `UNCOVEREDFIELD`, edit 400 `PORT.FIELD.UNEXPECTED`, schema refusal); run 420 red under the mutation.
  - `[low]` `[reject]` (verification-gap) `NamespaceSave.PortViolations` (420, and the 457/7201 `PROPERTYFAULTS` rows) is untested — reachable only when a database vanishes between the rule check and the `PUT`, or the vendor's name rule changes (the corpus pins it today); a test needs a stub port, more than a direct correction.
  - `[low]` `[patch]` (verification-gap) The own-namespace "is unchanged" read-back cannot fail through `AcceptPort`, and the spec's mutation line cited it as evidence — the claim was removed from the mutation line; the assertion stays as a guard on the port.
  - `[low]` `[patch]` (verification-gap) "no vendor write was sent by either caller" counts only the Save's port — message corrected to the Save.
  - `[false]` `[reject]` (verification-gap) The Integration row compares one read with itself — AD-36 requires one read; the equality fails if the tool's view projects or caps differently, so it is falsifiable.
  - `[low]` `[patch]` (verification-gap) The in-process own-namespace legs take `$NAMESPACE` as the install namespace by construction — the test now first asserts `$NAMESPACE` equals `/api/ocupilot`'s configured `NameSpace`; the over-the-wire impact leg already ran in the API process.
  - `[low]` `[patch]` (verification-gap) `MappingCount < 1` accepted the helper's `-1` — now `= 0`, green in the sweep.
  - `[low]` `[patch]` (verification-gap) The browser spec's mutation comment named `sideBarPosition` 7, which reddens nothing — corrected to 0, as the spec's line says.
  - `[false]` `[reject]` (verification-gap) AC sub-criteria without `mutation:` lines — Rule 19 asks one demonstrated mutation per AC, and each of AC1 to AC4 has one or more.
  - `[low]` `[patch]` (verification-gap) The `VERIFIEDDELETES` comment justified the entry by a false failure — it now says the 2xx is not trusted unread either.
  - `[low]` `[patch]` (intent-alignment) The kernel reads `$NAMESPACE`, not the API application's `NameSpace` — the Design Notes' decision (the API process runs in its application's namespace and a turn job refuses another); grouped with the precondition assertion above.
  - `[low]` `[reject]` (intent-alignment) A taken name at the mint answers AD-54's shared "already present" refusal, not `NAMESPACE.NAME.TAKEN` — it refuses before any `PUT`, naming the name, as every create tool's mint does (`Mint.cls:177`); only the model reads the label, and a fix reorders the shared mint.
  - `[low]` `[patch]` (intent-alignment) No test deletes the target between an edit's mint and confirm, nor covers the Save's check-then-`PUT` window — the edit half closed with the first row; the window is the shape every Save has and fingerprinting a person's Save is outside the intent.
  - `[low]` `[reject]` (intent-alignment) A bad name at the mint reaches one vendor `GET` before the refusal — the read changes nothing and is AD-54's shared absence read; the Save makes zero calls (pinned).
  - `[false]` `[reject]` (intent-alignment) "The complete set is sent" diverges between browser and server — the intent's surface is the vendor call, pinned on both callers; the browser sends changed fields by design (AD-4 is server-side).
  - `[false]` `[reject]` (intent-alignment) No server test opens the impact as a caller who cannot read `WebAppList` — the impact route and the mint gate on the delete's pairs, which include `WebAppList`'s two, so the part is unchecked only by truncation, pinned by Story 16.19.
  - `[low]` `[reject]` (intent-alignment) No principal missing a pair goes through the mint — the mint's pair refusal is shared `Operation` code (`ProposalPrivilege`); the Save and confirm gates that precede a write are pinned per principal.
  - `[false]` `[reject]` (intent-alignment) Behavior beyond the intent (switch re-read, Home shortcut, EXPERIENCE column, arming variable) — each is a spec task (AC1, the Code Map rosters, `:164`, the `ci-throwaway.sh` block).

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: every call through `AdminPort`, the tools' default port.
- AD-3: derived field lists with a reviewed classification.
- AD-4: an edit sends the complete set.
- AD-5, AD-36, AD-44: one descriptor per screen; the list and its tool read one read; each declares its classic page.
- AD-6, AD-34, AD-40: proposal and confirm; the gates at the write.
- AD-8, AD-29: pairs, the extra pairs, the removal impact.
- AD-10: the new predicate.
- AD-13, AD-14: the new type, its id rule, change events.
- AD-15: the marker. AD-16: `%SYS` only through the port.
- AD-21: no path field, so `PathPort` is not consumed.
- AD-22: the baseline lines. AD-39: violations.
- AD-51: the delete's declared fingerprint subject.
- AD-53, AD-55: two callers of one tool. AD-54: the create's absence fingerprint.
- AD-58: read-back. AD-59: `Snippet`, through `AdminPort`'s route table.

**Measured on `ocupilot-b-ci`, 2026-09-28** (the first plan's probes; every probe object was removed):

- **Create and edit.** `PUT /namespace?name=N` with `{"Globals":"USER","Routines":"USER"}` answers 201 `{Globals, Routines, TempGlobals:"IRISTEMP"}`. It creates no web application, mapping or database.
  - `{}` gives 400 #40301, and `Library` 400 #40307. An unknown database gives 500 #420.
  - In the name, `.`, a leading digit, a space or `$` gives 500 #457, and 65 characters #7201. `_`, `-`, a leading `%` and lower case are accepted; lower case is stored upper.
  - A second `PUT` is 200 and keeps the fields its body omits: the `PUT` is an upsert.
- **Delete.** `DELETE /namespace?name=N` answers 200 and removes the namespace, its mappings and every web application bound to it. It never deletes a database, and an application referencing the namespace never blocks it.
- **Pairs.** Reads need `%Admin_Manage:USE` and `%DB_IRISSYS:READ`. Every write also needs `%DB_IRISSYS:WRITE`: without it, `<PROTECT>` and nothing changes. The delete also needs `%Admin_Secure:USE`: without it the answer is 500 after the namespace is deleted, and the bound applications are orphaned.
- **Re-read at this plan, read-only.** `GET /namespace?name=` answers 404 #420 for an absent name, and resolves a lower-case name to `{Globals, Routines, TempGlobals}`. A LIST row also carries `Name`, `SysGlobals`, `SysRoutines` and `Library`.

**Decisions:**

- **Placement.** OS management at position 6, after Devices, since 1-5 are taken; the form takes 0.
- **The delete dialog** is the typed-name dialog with AD-8's advisory, as the classic `Dialog.NamespaceDelete` is one dialog. The vendor always deletes bound applications and never a database, so a stepper would offer no choice. Deleting the databases too is 18.3's delete.
- **The install namespace is the API process's own `$NAMESPACE`.** IRIS runs a request in its web application's configured `NameSpace`, and the router never switches it, so for both callers it is the API application's `NameSpace`, read at each evaluation. A turn job refuses any other namespace. `Security.Applications` is not read, because a caller holding only the namespace pairs cannot read security objects without AD-9's escalation (inference: `Kernel.Identity` escalates for exactly such a read).
- **No row self-protection rule.** The client does not know the install namespace; the refusal reaches the person through the dialog's advisory (the impact's `refused`) and the envelope.
- **Database names** match the list ignoring case and are sent in the list's spelling, so the read-back never reads a case difference as `differs`.
- **The `databases` part** comes from the fresh read the write itself needs, and a namespace always names its globals and routines databases (400 #40301 otherwise), so it is never unchecked or empty.
- **Governance** (the orchestrator's ruling at the spec gate): delete enters the baseline `false`; create and update enter `true`. A person's own Save and row action are never governed (AD-22, AD-53).
- **Classic pages.** The list declares `Namespaces` and the form `NamespaceEdit`. The New Namespace page and the delete dialog have no descriptor of their own, so a custom resource assigned only to those two keys is not unioned. This is a named gap; all four pages carry `%Admin_Manage`.
- **Not in this story:**
  - mappings, copy-mappings and SA-13's enable-interop: Story 18.14 (DW-1776);
  - SA-13's inline database create and SA-15's optional database delete: Story 18.3;
  - a web-application create: the admin API makes none.
- **Vendor defect candidates** from these probes are DW-1775 (decision-pending, a human report); nothing here depends on them.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate).** The first and third are the first plan's, cut to the namespace; the second is new at this re-plan.

1. **AD-8, the first clause, after the device case:** "Story 18.2's cases [AMENDED 2026-09-28, Story 18.2 spec gate, Rule 20]: the namespace tools declare `%DB_IRISSYS:WRITE`, because a principal holding only the Namespaces screens' `%Admin_Manage:USE` and `%DB_IRISSYS:READ` was answered `<PROTECT>` on every namespace write, and nothing changed (measured on `ocupilot-b-ci`, 2026-09-28). `osmgmt.namespaces.delete` also declares `%Admin_Secure:USE`: the vendor's delete removes every web application bound to the namespace, and a caller without that pair was answered 500 after the namespace was already deleted, its applications left behind."
2. **AD-8, the removal-impact clause, after the user case:** "A namespace delete carries one too (Story 18.2): the web applications whose `Namespace` is the target, which are deleted with it, read through the Web applications list's declared read, and the databases the namespace names, which stay [AMENDED 2026-09-28, Story 18.2 spec gate, Rule 20]."
3. **AD-10, a new bullet:** "**OcuPilot's install namespace** [AMENDED 2026-09-28, Story 18.2 spec gate, Rule 20]: deleting, or changing the `Globals` or `Routines` database of, the namespace OcuPilot's own API application runs in, or `%SYS`, is refused `PROHIBITED.OCUPILOTNAMESPACE`, from either caller. The vendor's delete removes every web application bound to the namespace (measured on `ocupilot-b-ci`, 2026-09-28), OcuPilot's own among them, and the routines database holds the code that answers OcuPilot's addresses (AD-9). Every other namespace delete or change is permitted, the delete at the destructive treatment with its removal impact. It is the same serving-path self-protection family."

**Integration ACs:**

- AC1: `NamespaceList` and `osmgmt.namespaces.read` answer one read (AD-36): the Integration matrix row, pinned in `NamespaceDescriptor`.
- AC2: the delete's impact consumes `WebAppList`'s declared read through that screen's own gate, pinned in `NamespaceWrite` and the browser spec.

**Consumed-by:**

- 18.14: the namespace editor's Mappings links, and the copy-mappings row action on `NamespaceList`.
- 18.3: the database delete's impact reads `NamespaceList`'s `Globals`, `Routines` and `TempGlobals`, and its inline create-database step joins `NamespaceForm`.
- 18.12: the agent's grown tool set.
- 18.13: multi-namespace install, under which the install-namespace predicate must keep holding.

**Consumes:** `AdminPort` (`Namespace.Namespace` `LIST`, `GET`, `PUT` and `DELETE`; `Database.ConfigCRUD` `LIST`); `WebAppList`'s read; 16.19's impact; 16.17's read-back; 14.1's `Snippet`; 14.2's baseline and `GovernanceFixture`; the typed-name dialog; `ScopeService`.

**Ledger:** the inbox was empty. DW-1774 is met by the roster tasks. DW-1770 does not bear, because no path is taken.

**Contended with Epic 16, all edited add-only:** `Error.cls`, `Router.cls`, `Baseline.cls`, `strings.ts`, EXPERIENCE.md, the rosters and `ci-throwaway.sh`. `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged. Not touched: `Area.cls`, `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/Proposal/Mint.cls`, `scripts/check-objectscript.py`.

## Verification

**Setup (slot B):**

- Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`. Every namespace write happens there, on `OCUPROBE182*` objects only; MCP calls carry `server: "ocupilot-slot-b"`.
- One test class per call, the next only once the previous has landed in `%UnitTest_Result`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time, for `NamespaceWrite`, `NamespaceWriteGate`, `NamespaceRefusals`, `NamespaceDescriptor`, `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Prohibited`, `RefusalCopy`, `GovernanceBaseline`, `ToolWrite`, `ToolRoundTrip`, `DraftRegistry`, `ProposalPrivilege`, `EntityRef`, `Navigation`, `Wire`, `WireSecurityRead`, `ScreenGrounding`, `ImpactRoute` and `Envelope` -- expected: 0 failures each, the totals checked against `%UnitTest_Result`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/namespaces.browser-spec.mjs browser/impact.browser-spec.mjs` -- expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh` -- expected: clean, and `wc -l` on EXPERIENCE.md reads 993.
- `(once, before dev_complete)` the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, which runs one class at a time; then `cd ui && npm test && npm run build`; then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line. The predicate mutation runs only against `AcceptPort`.

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC1 | `NamespaceCreate` drops `CREATES` | `NamespaceWrite`'s taken leg (the upsert is minted) |
| AC1 | `NamespaceList` takes `sideBarPosition` 0 | `navigation.test.mjs`; `Navigation` |
| AC1 | `NamespaceList`'s read drops `TempGlobals` | `NamespaceDescriptor`'s Integration leg; `ReadTool` |
| AC1 | `ScopeService` ignores the `namespace` event | `scope.test.mjs`; the browser spec's switcher leg |
| AC2 | `KindOf` omits `namespace-delete` | `NamespaceWrite`'s impact leg; the browser spec's advisory |
| AC2 | The `OCUPILOTNAMESPACE` arm is removed | `NamespaceWrite`'s own-namespace legs (an accepted write is recorded) |
| AC3 | The delete drops `%Admin_Secure:USE` from its pairs | `NamespaceWriteGate` (the port is called) |
| AC3 | The create drops `%DB_IRISSYS:WRITE` from its pairs | `NamespaceWriteGate` |
| AC4 | A header label is drawn in `--ocu-surface` | the DW-1337 legs, in both themes |

- mutation: `NamespaceCreate` `CREATES` 0 → `NamespaceWrite.TestATakenNameIsRefusedInAnyCase` red (the upsert minted, 200).
- mutation: `NamespaceList` `sideBarPosition` 0, mirror regenerated → `navigation.test.mjs` (two side-bar tests) and `Navigation.TestThePayloadCarriesEveryAreaWithAVerdict` red.
- mutation: `NamespaceList`'s `read.fields` drops `TempGlobals` → `NamespaceDescriptor.TestTheReadToolAnswersTheListsRows` and four `ReadTool` methods red.
- mutation: `ScopeService` drops its bus subscription → `scope.test.mjs` (the 18.2 re-read test) and `namespaces.browser-spec.mjs` (both switch legs) red.
- mutation: `Impact.KindOf` omits `namespace-delete` → `NamespaceWrite.TestTheImpactNamesTheApplicationsAndTheDatabasesThatStay` (all three sources) and the browser spec's advisory legs red.
- mutation: the `OCUPILOTNAMESPACE` arm disabled in `Prohibited.Namespace` → every leg of `NamespaceWrite.TestTheInstallNamespaceAndSysAreRefused` red, each refused write recorded as accepted by `AcceptPort`.
- mutation: `NamespaceDelete.PrivilegePairs` drops `%Admin_Secure:USE` → `NamespaceWriteGate.TestADeleteWithoutTheApplicationPairIsRefusedBeforeAnyPortCall` red (the vendor deleted the namespace and left its application).
- mutation: `NamespaceCreate.PrivilegePairs` drops `%DB_IRISSYS:WRITE` → `NamespaceWriteGate.TestAWriteWithoutTheWritePairIsRefusedBeforeAnyPortCall` red (both create legs).
- mutation: `.ocu-field-label` drawn in `--ocu-surface`, bundle rebuilt and redeployed → the browser spec's AC2 and AC4 DW-1337 legs red in light (1.04:1) and dark (1.08:1).
- mutation (review): `NamespaceSave.Update` carries on past a 404 fresh read with `{}` → `NamespaceRefusals.TestAnEditOfADeletedNamespaceIsRefusedAndNotRecreated` red (run 418).
- mutation (review): `NamespaceRules.Validate`'s create REQUIRED add disabled → `NamespaceRefusals.TestACreateWithoutItsDatabasesIsRefusedOnEachField` red (run 419).
- mutation (review): `NamespaceSave.Update`'s key check disabled → `NamespaceRefusals.TestAKeyOutsideTheThreeIsRefusedOnBothSaves` red (run 420).
- mutation (review): `Namespace.Namespace/DELETE` removed from `AdminPort.VERIFIEDDELETES`, `RoleDeletePort` recompiled → `NamespaceRefusals.TestAReportedDeleteThatLeftTheNamespaceIsNotApplied` red (run 421).
- mutation (code review): `NamespaceUpdate.ArgumentProblem` answers no problem → `NamespaceRefusals.TestAnEditNamingNoDatabaseOrEmptyingOneIsRefusedOnEachCaller` red, all three agent legs minted (run 769).
- mutation (code review): `NamespaceRules.Validate` answers REQUIRED only on a create → the same method red on both callers' emptied-field legs, each read as ABSENT (run 770).
- mutation (code review): `NamespaceSave.HandleUpdate` takes its segment undecoded, `NamespaceSaveFixture` recompiled → `NamespaceRefusals.TestAPercentLedNamespaceIsEditedOverTheWire` red, 404 `NAMESPACE.NAME.ABSENT` (run 771). Each mutation was applied to the throwaway's source copy only and reverted to the worktree's bytes (`diff -rq src` clean); the class is green again at run 772.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Part A as specified: the Namespaces list (OS management, position 6) and its form; `osmgmt.namespaces.create`, `.update` and `.delete`, each reached by the screen's Save or row action and by the agent's mint and confirm; the delete's impact (bound applications deleted, databases that stay); `PROHIBITED.OCUPILOTNAMESPACE`; the `namespace` entity type (`foldcase`); governance lines (delete `false`); the switcher's re-read on a namespace created or deleted; EXPERIENCE.md rows `:164`, `:173`, `:378`, `:479`, `:481`, `:577` (993 lines).

**Files.** New: `Area/OsMgmt/NamespaceRules.cls`, `NamespaceSave.cls`; `Screen/Descriptor/NamespaceList.cls`, `NamespaceForm.cls`; `Screen/Tool/NamespaceCreate.cls`, `NamespaceUpdate.cls`, `NamespaceDelete.cls`; tests `NamespaceWrite`, `NamespaceWriteGate` (+`Probe`), `NamespaceRefusals`, `NamespaceDescriptor`, `NamespaceWriteProbe`, `NamespaceSaveFixture`, `NamespaceActionFixture`, `NamespaceConfirm`; client `namespace-actions.ts`, `namespace-form.page.ts`, `namespace-form.store.ts` and specs; `ui/browser/namespaces.browser-spec.mjs`. Changed: `Error.cls`, `Router.cls`, `EntityType.cls`, `EntityRef.cls`, `Baseline.cls`, `Impact.cls`, `Prohibited.cls`, `AdminPort.cls`, `Classification.cls`, `ToolFields.cls` (regenerated), `AcceptPort.cls` (opt-in `ReadThrough`), `DeviceRecordPort.cls` (query keys), the rosters, `impact.ts`, `scope.ts`, `main.ts`, `app.ts`, `screen-action-handler.ts`, `screen-outlet.ts`, `shortcuts.ts`, `strings.ts`, `screens.generated.ts` (regenerated), `scripts/ci-throwaway.sh`, EXPERIENCE.md.

**Review.** 21 findings: 3 medium and 8 low patched (tests in the new `NamespaceRefusals`, the roster loop, wording and assertion corrections), 5 low rejected and 5 false, each with its reason in the triage log; none deferred. Patched by verdict: medium 3, low 8. Follow-up review: `false` -- every patched test was reddened by its own mutation (runs 418-421) and nothing outside tests changed but one comment.

**Verification** (all on `ocupilot-b-ci`, source copy byte-identical to the worktree; the three namespace-write classes armed per call with `docker exec -e`, since the throwaway predates the variable). Full sweep once: 338 classes, 2,784 tests, 4 failed, 0 leftovers -- the four were rosters the loop list missed (`AuditingUpdate` codes 19, `Governance` and `ToolDispatch` disabled set, `ToolEmit` the delete's second pair), fixed and green (runs 762-765). Browser: `namespaces` 5/5, `impact` 5/5. Client: `test:tools` 1660/1660, components 1648/1648, `ci.test.mjs` 75/75. Build 2.03 MB (under the 2106 kB warning). Smoke 48/48. `check-objectscript` and `lint-docs` clean. No `OCUPROBE182*` namespace, `/csp/ocuprobe182*` application or gate principal remains.

**Residual risks.** The install namespace is the evaluating process's `$NAMESPACE` (Design Notes); 18.13's multi-namespace install must keep it true. A taken or malformed name at the agent's mint answers AD-54's shared refusal after one vendor read.
