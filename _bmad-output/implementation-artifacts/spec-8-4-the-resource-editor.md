---
title: 'Story 8.4: The resource editor'
type: 'feature'
created: '2026-09-23'
status: 'ready-for-dev'
baseline_revision: 'b0d416a618f2bb0666c5e7729df48a4aabc278cc'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-3-create-a-role-and-manage-its-resource-grants.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A resource cannot be created, edited or deleted from OcuPilot. The Resources list declares no action, no tool writes `Security.Resource`, the prohibited set does not cover the `resource` type, and the port admits no `Security.Resource` write.

**Approach:** Ship a resource editor dialog on the Resources list. It serves create (the list's Create) and edit (a row's name cell), and saves through `permissions.resources.create` (AD-54) and `permissions.resources.update` (a merge write, AD-4), each with the screen and the agent as two callers of one tool (AD-55). Ship `permissions.resources.delete` as an agent-only action-style write (AD-51). It refuses a system resource and OcuPilot's own resources. The Resources-list Delete row action is pending the lead's ruling (Design Notes).

## Boundaries & Constraints

### Always

- A resource is `{Description, PublicPermission}` on the wire. `Name` travels only as the `name` query parameter, because the vendor refuses it in the body. `PublicPermission` is a subset of `R`, `W`, `U`, sent in that order.
- An edit sends the complete property set: the fresh read with the edited fields applied (AD-4, AC3). The screen sends only the fields the user changed from what the dialog opened with, so another field changed on the instance since is kept.
- "System resource" means the vendor's own `AllowDelete` is false: the list's Deletable column, the delete refusal and the pending row action all read that one field.
- A public permission that adds a letter on a resource `Prohibited.ResourceGrantsAdministrativePrivilege` names is a privilege grant (AD-10 as amended). It is permitted at the strongest confirmation: the proposal is destructive with `consequence` `GRANT.PRIVILEGED`, and the dialog shows `STRINGS.privilegedGrantEffect` at the field.
- Every field sentence is authored once in `Api/Error.cls`. Every visible word is a `STRINGS.<key>` with a Fixed strings row. The admissible public-permission letters are authored once on the server and shipped as data in the form read.
- The port re-reads after a `Security.Resource` PUT. A sent value that does not read back fails `PORT.NOTAPPLIED`, because the vendor overwrites a failed save's status with OK.

### Never

- Never edit `Kernel/Proposal/Confirm.cls`, `Kernel/Restraint.cls`, `Port/LogSourcePort.cls`, `Install/Smoke.cls` or `ui/src/app/areas/{tasks,logs}/**`.
- Never edit `ui/src/app/shell/{data-table,list-page,dialog,command-bar,screen-action-handler}.ts`, `core/self-protection.ts` or any file Epic 7 added. No row action in this story unless the lead rules (b) below.
- No field beyond name, description and public permission. `Type` is never sent.
- No direct `Security.Resources` mutation outside `AdminPort` (AD-2, AD-49).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create, screen | `POST /api/ocupilot/resources` `{Name, Description, PublicPermission:"RU"}`, name free | 201 `{name}`. The port sends `PUT Security.Resource?name=<Name>`. A `resource` `created` event follows, the route becomes `permissions/resources/<id>`, and the dialog stays open in edit mode showing `formSaved` | No error expected |
| Edit, screen | `PUT /api/ocupilot/resources/<id>` `{Description:"new"}` while the instance reads `PublicPermission:"W"` | The port body is `{Description:"new", PublicPermission:"W"}`. 200, an `updated` event, and `formSaved` shows | No error expected |
| Agent create / update | `permissions.resources.create` or `.update` minted, then confirmed | The create has one diff row per supplied field and fingerprints the absence. The update's diff shows the changed rows with `unchangedCount`. A marker, a ledger row and a `created` or `updated` event follow | No error expected |
| Field rules | Name empty, over 64 characters, holding a control character, `,` or `:`; Description over 256; a letter outside `RWU` or repeated; a letter the name does not admit | One `RESOURCE.<FIELD>.<RULE>` row per failing field, from the same `Validate` the tool's `ArgumentProblem` runs | 422 on the screen, 400 `TOOL.ARGUMENTS` at mint. Nothing is sent |
| Name taken | Any spelling of an existing resource on create | `RESOURCE.NAME.TAKEN` on Save and on blur (`GET /resources/name`). If taken after the mint: 409 `PROPOSAL.TARGETCHANGED` | The upsert is never reached |
| Absent on edit | Edit, form read, or update mint for a name the instance does not hold | 404 `RESOURCE.NAME.ABSENT`. The dialog shows the reason in its summary, and Save is `aria-disabled` | Nothing is sent |
| Privileged public permission | Create or edit `%Admin_Probe` with `U` added | Agent: the proposal is destructive with `GRANT.PRIVILEGED`. Screen: `privilegedGrantEffect` shows at Public permission while a letter is checked, and Save applies it | No error expected |
| Agent delete | `permissions.resources.delete` for a user resource | Removal rows for `Description` and `PublicPermission`. Confirm sends a bodyless `DELETE`, then a marker and a `deleted` event | No error expected |
| Delete refused | A resource whose vendor `AllowDelete` is false; `%DB_OCUPILOT` or `OcuPilotAdmin` in any spelling | Mint 400 `TOOL.ARGUMENTS` (`RESOURCE.NAME.SYSTEM`); 403 `PROHIBITED.OCUPILOTRESOURCE` | Nothing is deleted |
| Save the vendor did not apply | The vendor PUT answers 2xx, and the re-read differs from a sent value | 500 `PORT.NOTAPPLIED` | The row or the dialog reports failure, never "saved" |
| Leave dirty | Close, Escape, Cancel, or any navigation, including the agent's, while the dialog holds a change | The shared leave question replaces the dialog. "Stay" re-shows it with the edits | Nothing is lost silently |

</intent-contract>

## Code Map

### Contention (Epic 7 on slot A, head `9b649d59e4a9f3a129a3140d872bb957c147587e`)

Before editing a ⚠ file, run `git fetch origin && git show origin/OCU-1-epic7:<path>`. Keep off its hunks (Epic 7 line numbers are marked `e7`) and restructure nothing it added. Epic 7 touches no resource code.

**Needs the lead:**

- `src/OcuPilot/Screen/Tool/Classification.cls`, where Epic 7 appends `permissions.users.create`/`.password` entries at its tail (e7 +136). HEAD's role entry is at :221-232.
- `src/OcuPilot/Screen/Tool/ToolFields.cls`, generated (e7 +13, HEAD :13).
- This story needs one tail append and a regeneration in each.

### Server

- `src/OcuPilot/Screen/Tool/RoleCreate.cls` -- the create template: `CREATES` :24, `CHANGEACTION` :27, `WRITETYPE` PUT upsert :33, `ArgumentProblem` :99.
- `src/OcuPilot/Screen/Tool/UserUpdate.cls` -- the merge template: `PERMITTEDFIELDS` :41, `SettableFields` :68, `PrivilegePairs` :114.
- `src/OcuPilot/Screen/Tool/RoleDelete.cls` -- the action-delete template: `WRITETYPE` :30, `SENDSBODY` :34, `DESTRUCTIVE` :42, `READANSWERS` :48, `PRECONDITIONFIELD` :52, `FINGERPRINTSUBJECT` :56, `ArgumentProblem` :96, `StateDiff` :122.
- `src/OcuPilot/Screen/Tool/Write.cls` -- no edit. `IdParam` is "name" :338, `FieldRows` :384, `ArgumentProblem` :568.
- `src/OcuPilot/Screen/Tool/FieldLists.cls` :309-312 already derives `Security.Resource` (`Description`, `PublicPermission`).
- `src/OcuPilot/Kernel/Proposal/Mint.cls`:
  - fresh read :160-183, `Compose` :186, `Merge` :192/:421-503;
  - `ArgumentProblem` for every tool :204-216;
  - `GrantsPrivilegeByEffect` call :300, destructive OR :306, `ConsequenceOf` :614. Not in Epic 7's diff.
- ⚠ `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :135 and type gate :425 (e7 +149, +416; one-line merges);
  - `Codes` :225, `ReasonFor` :233 (e7 +249 and shared sentences +55);
  - `PermittedChangeFields` :297, `PermittedCreateFields` :350;
  - `Prohibits` :414; the `Role` branch :775 and `OcuPilotRoles` :809 are the pattern;
  - `ResourceGrantsAdministrativePrivilege` :1253, `GrantsPrivilegeByEffect` :1311 (no resource branch today).
- `src/OcuPilot/Kernel/State/Base.cls` -- `DBRESOURCE` "%DB_OCUPILOT" :79 and `ADMINRESOURCE` "OcuPilotAdmin" :83. These are OcuPilot's only two resources (`Install/Installer.cls` :1927, :2018).
- `src/OcuPilot/Port/AdminPort.cls`:
  - ⚠ `MUTATINGTYPES` :174 (e7 +173), `BODYLESSTYPES` :190 (e7 +207);
  - shared-append: `VERIFIEDDELETES` :201 and `VerifyGone` :850 (the re-read pattern), `Invoke` :449 (e7 +496 adds `Renamed()`);
  - ⚠ `ImplementsRead` :969-978 maps no `DELETE`. Epic 7 adds exactly `If pSuffix = "DELETE" Set tRunner = "RunDelete"` (e7 +935). Add that same line so the merge is trivial.
- `src/OcuPilot/Kernel/EntityRef.cls` `IDRULES` :59 -- no `resource` rule.
- `src/OcuPilot/Area/Permissions/RoleCreate.cls` (`HandleCreate` :51, `Perform` :98, `CallerFields` :154, `RenderViolations` :182, `Gate` :192, `PortClass` :35) and `RoleCreateRules.cls` (`Validate` :72, `HandleForm` :295, `HandleName` :329, `Taken` :364) -- the screen-route pattern. No screen route does a merge update yet; `Mint.Merge` is public and is what the update route reuses.
- ⚠ `src/OcuPilot/Api/Router.cls` -- role routes :100-102, handlers :313-332 (e7 +95 inserts `/screens/:screen/action`; +253 a handler).
- `src/OcuPilot/Api/Error.cls` -- ROLE block :1741-1821, `ReasonForViolation` :1048 (ROLE lines end :1127), `RoleViolationCodes` :1154, `ViolationCodes` :1165, `PORTNOTAPPLIED` :197.
- `src/OcuPilot/Screen/Descriptor/ResourceList.cls` -- `primaryAction` :45, `rowActions` :46, `emptyNextKey` :67, `emptyAgentKey` :68.

### Client

- `ui/src/app/areas/permissions/role-actions.ts` :34-44 -- a root service registers `ScreenActions.register(descriptor, 'create', fn)`. Copy it; the handler opens the dialog instead of navigating.
- `ui/src/app/shell/dialog.ts` (`heading` :76, `closed` :82, `dialogAction` :67) and `change-password-dialog.ts` (summary :80, `aria-invalid`/`aria-describedby` :105-106, submit :283) -- the form-in-a-dialog precedent. `role-grant-dialog.ts` :68-142 and its host `role-create-form.page.ts` :220-271 show the dialog hidden while `FormDirty.pending()`.
- `ui/src/app/shell/data-table.ts` :456-479 -- the name cell of a list with no paired form links to `permissions/resources/<id>`. `list-page.ts` `selectFromRoute` selects that row. The new page opens the editor from the same route id, so the data table is not edited.
- `ui/src/app/core/navigation.ts` -- `ownIdSegment` :362, `CREATE_ONLY_FORMS` :201. `screen-outlet.ts` `DESCRIPTOR_PAGES` :89-100.
- `ui/src/app/app.routes.ts` :24, :72 -- `leaveFormGuard` rides `form-page` routes only. `core/form-dirty.ts` -- `setDirty`, `requestLeave`, `pending`, `answer`.
- `ui/src/app/app.ts` :237-238 (injections), :507 (sign-out reset). `role-create-form.store.ts` :508-517 -- `ChangeBus.publish`.
- ⚠ `ui/src/app/core/strings.ts` -- the tail ends :1414, `} as const;` :1416 (e7 appends at +1317). Reuse `resourceColumnPublicPermission`, `tableColumnName`, `tableColumnDescription`, `permissionRead/Write/Use`, `formSaved`, `actionSave`, `actionCancel`, `privilegedGrantEffect`, `formLeaveWithoutSaving`.
- ⚠ EXPERIENCE.md -- surface rows :123-124, dialog list :173 (already names the resource editor; do not edit), Fixed strings last row :405 (e7 inserts after its :394).
- `ui/browser/roles-create.browser-spec.mjs` -- `irisSys` :79, `signedInAt` :116, `fill` :133, `saveButton` :140, `waitForDialogClosed` :226, and an exact-name cleanup pattern :89.

## Tasks & Acceptance

### Execution

#### Port, identity, prohibited set

- `src/OcuPilot/Port/AdminPort.cls`:
  - ⚠ Append `Security.Resource/PUT,Security.Resource/DELETE` to `MUTATINGTYPES`, and `Security.Resource/DELETE` to `BODYLESSTYPES`.
  - ⚠ Add the `DELETE` → `RunDelete` line to `ImplementsRead`, exactly as Epic 7 wrote it.
  - Add `Parameter VERIFIEDWRITES = "Security.Resource/PUT"` beside `VERIFIEDDELETES`. After a 2xx for a listed pair, `Invoke` re-issues the `GET` for the same id. Every key of the sent body must read back equal, with `PublicPermission` compared as a letter set; otherwise it raises `PORT.NOTAPPLIED`. The doc states the wire fact: `RunPut`'s closing `Exists` overwrites the save's status, and a 300-character Description answered 200 unchanged.
- `src/OcuPilot/Kernel/EntityRef.cls` -- append `,resource:foldcase`. A vendor lookup is case-insensitive.
- ⚠ `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, off Epic 7's hunks:
  - Add `TYPERESOURCE "resource"` to `COVEREDTYPES` and the type gate.
  - `PermittedCreateFields` and `PermittedChangeFields` for `resource` are both `Description,PublicPermission`.
  - Add a `Resource(pId, pToolClass, pPayload, pTarget, ByRef pChanged, …)` branch:
    - A `DELETE` of one of `OcuPilotResources()` refuses `OCUPILOTRESOURCE`.
    - A change that adds a `PublicPermission` letter on one of them refuses `OCUPILOTRESOURCE` too (pending P2).
    - Otherwise it runs `ReviewedFewOnly`.
    - A create step refuses the same public-permission case, and `UNCOVEREDFIELD` as usual.
  - `OcuPilotResources()` folds `Kernel.State.Base`'s `DBRESOURCE` and `ADMINRESOURCE`. It never transcribes them.
  - Add `Parameter OCUPILOTRESOURCE = "PROHIBITED.OCUPILOTRESOURCE"` to `Codes()`. Its caller-neutral `ReasonFor` is "This resource guards OcuPilot's own data or administration. It cannot be deleted or opened to every user; only OcuPilot's installer changes it."
  - `GrantsPrivilegeByEffect` gains a trailing `pId As %String = ""` and a `resource` branch. It is privileged when the payload's `PublicPermission` holds a letter the target's lacks and `ResourceGrantsAdministrativePrivilege(pId)` is true.
  - `src/OcuPilot/Kernel/Proposal/Mint.cls` :300 passes the target id.

#### Tools

- `src/OcuPilot/Screen/Tool/ResourceCreate.cls` -- new, on `RoleCreate`:
  - `TOOLNAME "permissions.resources.create"`, `DESCRIPTORCLASS ResourceList`, `CREATES 1`, `CHANGEACTION "created"`, `WRITETYPE "PUT"` with the upsert reason, `Endpoint() "Security.Resource"`.
  - `PERMITTEDFIELDS "Description,PublicPermission"`.
  - `InputSchema` describes the letters and says that a letter on an administrative resource is a privileged grant.
  - `ArgumentProblem` calls `ResourceRules.Validate`. `PrivilegePairs` are the screen's pairs.
- `src/OcuPilot/Screen/Tool/ResourceUpdate.cls` -- new, on `UserUpdate`:
  - `TOOLNAME "permissions.resources.update"`, a merge write (`READTYPE "GET"`, `WRITETYPE "PUT"`, `SENDSBODY 1`), `CHANGEACTION "updated"`.
  - The same permitted fields and `ArgumentProblem` (field rules only; name rules skipped). The fingerprint is the default: every field.
- `src/OcuPilot/Screen/Tool/ResourceDelete.cls` -- new, on `RoleDelete`:
  - `TOOLNAME "permissions.resources.delete"`, `READTYPE "GET"`, `WRITETYPE "DELETE"`, `SENDSBODY 0`, `CHANGEACTION "deleted"`, `DESTRUCTIVE 1`.
  - `READANSWERS` and `FINGERPRINTSUBJECT` are both `"Description,PublicPermission"`. `PRECONDITIONFIELD "PublicPermission"`: what every user loses is what the confirm must still find.
  - `StateDiff` emits removal rows.
  - `ArgumentProblem` refuses `RESOURCE.NAME.SYSTEM` when the tool's port `LIST` (`names=<id>`) answers `AllowDelete` false.
- Needs the lead: `Classification.cls` gains `permissions.resources.create` and `.update` entries (`fieldList "Security.Resource"`, both fields `ordinary`). Regenerate `ToolFields.cls` with `cd ui && node tools/field-lists.mjs`.

#### Screen routes

- `src/OcuPilot/Area/Permissions/ResourceRules.cls` -- new:
  - `Validate(pName, pArgs, Output pViolations, pCheckName, pCheckTaken)` holds the matrix's rules.
  - `AdmissibleLetters(pName)` ports `%CSP.UI.Portal.Dialog.Resource` :222-236 exactly. Read it on the instance first. The planner observed:
    - no `R`/`W` for `%Service_`, `%DeepSee_`, `%Admin_`, `%Development`, `%Application_`, `%System_`, `%DocDB_`, `%Gateway_`, `%IAM`, `%Native_`, `%SQL`, `%Secure_`;
    - no `U` for `%DB_`.
  - `HandleForm` (`GET /resources/form[?name=]`) answers `{requiredFields, maxLengths, letterRules, privilegeReason}`. With a name it adds `resource:{name, Description, PublicPermission, privileged}`, read through the update tool's port, or 404 `RESOURCE.NAME.ABSENT`.
  - `HandleName` (`GET /resources/name?name=`) answers `{taken, privileged}`. `privileged` is `ResourceGrantsAdministrativePrivilege`.
- `src/OcuPilot/Area/Permissions/ResourceSave.cls` -- new, mirroring `RoleCreate.cls`:
  - `HandleCreate` (`POST /resources`) runs gate, prohibited verdict, `Validate`, `Mint.Compose`, then the port `PUT`.
  - `HandleUpdate` (`PUT /resources/:id`) runs gate, then the fresh read through the update tool's port (404 → `RESOURCE.NAME.ABSENT`), then `Validate` on the sent fields, then `Mint.Merge(fresh, sent)`, then the prohibited verdict over the merged payload and the fresh read, then the port `PUT`. A `PROHIBITED.*` verdict is a 403 envelope. Only the `Description` and `PublicPermission` keys are accepted; any other key is 400.
- ⚠ `src/OcuPilot/Api/Router.cls` -- after :102: `GET /resources/form`, `GET /resources/name`, `POST /resources`, `PUT /resources/:id`, sub-resources first, with thin handlers after :332.
- `src/OcuPilot/Api/Error.cls` -- after :1821, add:
  - `RESOURCE.VALIDATION` (422);
  - `RESOURCE.NAME.{REQUIRED,LENGTH,SHAPE,TAKEN,SYSTEM,ABSENT}`, `RESOURCE.DESCRIPTION.LENGTH`, `RESOURCE.PUBLICPERMISSION.{SHAPE,LETTERS}`, each with its sentence. `SYSTEM` is "This is a system resource. IRIS does not allow it to be deleted.";
  - registration in `ReasonForViolation` and a `ResourceViolationCodes`.
- `src/OcuPilot/Screen/Descriptor/ResourceList.cls`:
  - `primaryAction.id "create"`, `emptyNextKey ""`, `emptyAgentKey "resourceListEmptyAgent"`;
  - its doc names the Create action and the name cell's editor.

#### Client

- `ui/src/app/areas/permissions/resource-actions.ts`, `resource-editor.store.ts`, `resource-editor-dialog.ts` and `resource-list.page.ts` -- new, with the `ocu-resource-` id prefix:
  - The page renders `<app-list-page />` plus the dialog and the leave question.
  - A route id opens edit mode for that id; the Create handler opens create mode.
  - The dialog is on `app-dialog`. Its heading is `resourceEditorCreate` or `resourceEditorEdit`. Its fields are Name (required; read-only in edit), Description, then a Public permission fieldset with one checkbox per admissible letter.
  - Inline blur validation and the error summary follow the change-password dialog. `privilegedGrantEffect` shows under the fieldset while a letter is checked on a privileged name.
  - Save posts or puts; the edit sends only the changed fields. It publishes `{kind:'changed', type:'resource', scope:'instance', id, action}`. A create then replaces the route with `permissions/resources/<id>`, and `formSaved` shows beside the actions.
  - The store marks `FormDirty` on a change and clean on save or close.
  - Cancel, Escape and the close button call `FormDirty.requestLeave()`. On `true` the store resets; edit mode then navigates to `permissions/resources`.
- `ui/src/app/core/navigation.ts` -- export `DIALOG_EDITORS` (`ResourceList`). `ui/src/app/app.routes.ts` guards those screens' routes with `leaveFormGuard`, as it guards `form-page`.
- `ui/src/app/shell/screen-outlet.ts` gains the `DESCRIPTOR_PAGES` entry. `ui/src/app/app.ts` injects `ResourceActions` and resets the editor store at sign-out.
- ⚠ `ui/src/app/core/strings.ts` and ⚠ EXPERIENCE.md Fixed strings, **append only**, one row each:
  - `resourceListEmptyAgent` 'create a resource';
  - `resourceEditorCreate` 'New resource', `resourceEditorEdit` 'Edit resource <name>'.
- `ui/src/app/core/screens.generated.ts` -- regenerate; never hand-merge.

#### Tests and rosters

- `src/OcuPilot/Test/ResourceFixture.cls` (overrides `PortClass`, records sent bodies), `ResourceCreate.cls`, `ResourceUpdate.cls` and `ResourceDelete.cls` -- new, each under 500 lines. They cover:
  - every field rule on both callers;
  - one body from both callers;
  - AC3's merge (a fresh `PublicPermission:"W"` survives a Description-only edit on both callers);
  - the privileged marking (destructive, consequence, screen allowed);
  - `OCUPILOTRESOURCE` for both names in another case;
  - `RESOURCE.NAME.SYSTEM`, removal rows, a moved `PublicPermission` refusing `TARGETCHANGED`;
  - `VERIFIEDWRITES` through a port subclass whose re-read differs;
  - the form read's letter rules against `AdmissibleLetters`.
- `src/OcuPilot/Test/ResourceWire.cls` -- new, armed on `OCUPILOT_ALLOW_PRINCIPALS`. Append it to `scripts/ci-throwaway.sh` :203 and the `ui/tools/ci.test.mjs` roster. On the throwaway it checks:
  - the routes' envelopes;
  - a create, then an edit that keeps the other field;
  - a real-port write the vendor did not apply (300-character Description through the port) failing `PORT.NOTAPPLIED`;
  - an agent delete confirmed through the real port;
  - `%Admin_Secure` refused `RESOURCE.NAME.SYSTEM`;
  - cleanup by exact probe names.
- `resource-editor.store.spec.ts` and `resource-editor-dialog.spec.ts` -- new, on the 8.3 harness.
- `ui/browser/resources-editor.browser-spec.mjs` -- new. It covers:
  - Create opens the dialog with fields in order;
  - a name cell opens edit with Name read-only;
  - Save creates, then re-labels to edit with `formSaved`;
  - the list row appears without refresh;
  - a dirty Escape asks;
  - `privilegedGrantEffect` on `%Admin_` names.
- Rosters that redden:
  - ⚠ `Test/{SurfaceCoverage,EndpointCoverage,ReadTool,ToolRoundTrip,Prohibited,ToolWrite,PortFixture}.cls` (8.3's rows: SurfaceCoverage :104-105, EndpointCoverage :133-135, ReadTool :93-94, ToolRoundTrip :30, Prohibited :192/:584, ToolWrite :799-835, PortFixture :21);
  - `Test/PermissionsLists.cls` :35/:146-149, `Test/EntityRef.cls` :211-225;
  - `ui/tools/entity-ref.test.mjs` :83 (pick another unruled type), `screen-mirror.test.mjs` :178-187, `navigation.test.mjs`, `app.routes.spec.ts`.

### Rulings and routed work (lead, 2026-09-23)

- **P1 fallback** (`AdminPort`, shared-append): the `Security.Resource` empty-`PublicPermission` completion through `Security.Resources` in `%SYS` described under Design Notes, with `ResourceWire` legs for create-private, clear and edit-private that fail when the fallback is removed.
- **P2** (`Prohibited.cls`, contended): `PROHIBITED.OCUPILOTRESOURCE` with a caller-neutral `ReasonFor` sentence; a test on both callers that fails when it is removed.
- **P4** `Screen/Tool/Classification.cls` is contended append-only (read Epic 7's pushed version first; append only this story's entry at the tail). `Screen/Tool/ToolFields.cls` is regenerated with `node tools/field-lists.mjs`, never hand-edited; the orchestrator regenerates it at the merge.
- **DW-1524 (floor-blocking).** `Prohibited.User`'s update predicate follows AD-10 as amended: a privilege-granting role delta and any `EscalationRoles` change are permitted, minted destructive with the privilege named (the same `GrantsPrivilegeByEffect`/`consequence` path 8.3 built), keeping only the account protections (current user, `_SYSTEM`, service account, last `%All` holder -- Epic 7's; touch nothing of theirs). `src/OcuPilot/Test/UserUpdate.cls` is contended (Epic 7 added 441 lines): `git fetch origin`, read `git show origin/OCU-1-epic7:src/OcuPilot/Test/UserUpdate.cls` first, recode ONLY the methods that assert the privileged refusal to assert the new terms, touch nothing Epic 7 added, and add a test that fails when the update-path permission regresses. List it under `footprint_extensions:`.

### Acceptance Criteria

- **AC1.** Given the Resources list, when Create or a row's name cell is used, then the resource editor opens as a dialog (not a route) capturing name, description and public permission, in that order. The name is read-only when editing.
- **AC2 (agent path).** Given a resource whose vendor `AllowDelete` is false, when `permissions.resources.delete` is proposed, then it is refused with `RESOURCE.NAME.SYSTEM`'s sentence, and the list shows the row with Deletable "No". The Resources-list Delete row action, drawn disabled with that reason, is Story 9.3's (DW-1528).
- **AC3.** Given an edit saved through either caller, when it is written, then the body is the complete property set from a fresh read with the edits applied. A field the user did not change keeps the instance's current value.
- **AC4 (Integration).** Given a valid Save, when the server accepts it, then:
  - the instance holds the sent values;
  - after a create the route is `permissions/resources/<id>`, and the dialog is in edit mode showing `STRINGS.formSaved`;
  - the Resources list, the change bus's consumer, shows the change without a refresh.
- **AC5.** Given the agent's create, update or delete confirmed, then:
  - the write is marked, the ledger names the sent fields, and a `created`, `updated` or `deleted` event is published;
  - OcuPilot's own resources are refused `PROHIBITED.OCUPILOTRESOURCE`;
  - a vendor 2xx that did not apply fails `PORT.NOTAPPLIED`.
- **AC6.** Given a public permission that adds a letter on an administrative resource, when either caller saves it, then it is permitted at the strongest confirmation: the proposal is destructive and names `GRANT.PRIVILEGED`, and the dialog shows `privilegedGrantEffect`.
- **AC7.** Given the dialog holds a change, when it is closed or any navigation leaves, the agent's included, then the shared leave question asks first.

## Spec Change Log

- 2026-09-23, spec gate (orchestrator rulings): P1 is AD-27's fallback (AD-27 amended; the lead ruled out every other encoding); P2 adds `OCUPILOTRESOURCE` to AD-10; the row action goes to Story 9.3 (DW-1528); `Classification.cls` is contended append-only; DW-1524 is routed here as floor-blocking; AD-4 was corrected for `Security.Resource`. Status set to `ready-for-dev` without a re-plan.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-19, AD-27, AD-34, AD-39, AD-49, AD-51, AD-52, AD-54, AD-55. Epic 7's AD-53 governs the pending row action.

### What the instance settled

Read on `ocupilot-slot-b`. The probes were on `ocupilot-b-ci` with exact-name cleanup confirmed; the probe script and output are `probe84.txt`/`probe84.out` in the stage scratchpad.

- **Endpoint.** `%Api.Admin.Endpoints.Security.Resource` implements `LIST`, `GET`, `PUT` and `DELETE`, with `ResourcesOR` `%Admin_Secure`.
  - The template is `PutRequestBodySchema` `{Description, PublicPermission}`. Unknown keys, `Name` among them, are refused. On an absent name both fields are required.
- **PUT is an upsert.**
  - Absent → `Create` → 201. Present → `Modify` with only the keys sent → 200: a Description-only body kept `PublicPermission` (probe 4). AC3's premise that the type does not merge is therefore wider than the instance; its outcome holds regardless.
  - A value `ExternalToInternal` maps to 0 answers 400 with an empty body. That includes `""` (probes 2, 5).
  - The closing `Exists` overwrites the save status: a 300-character Description answered 200, unchanged (probe 8).
- **GET and LIST.** GET answers `{Description, PublicPermission}` only, and 404 when absent. LIST rows add `ResourceType` and `AllowDelete`.
- **DELETE.** It maps #890 (a system resource) to 409 and #892 to 404, and it did delete on 200 (probe 14).
- **`Security.Resources`.**
  - Names are case-insensitive, at most 64 characters, with no `,` or `:`. A user-defined `%` name is accepted (probe on `%OcuPilotProbe84`). Description is at most 256.
  - `AllowDelete` is false exactly when `Type` bit 0 is set: 131 of 185 resources on slot B, with no exception.
  - `Modify` of a system resource's Description succeeded (`%DocDB_Admin`, restored).
  - `Create`/`Modify` with `PublicPermission ""` succeed directly; the endpoint cannot send it.
- **The classic dialog** orders Name, Description, then Public Permission checkboxes. Name is disabled on edit. The list's name cell is not a link, and its Delete is disabled for ten hard-coded names with no reason shown.

### Ruled: P1, a public permission of none (AD-27 fallback)

The vendor PUT cannot carry "no permission": its `RunPut` normalizes `PublicPermission` with `Security.Datatype.Permission.ExternalToInternal`, whose answer for none is `0`, and refuses `If permsNormalized = 0` with a 400. The lead ruled out every other encoding on `ocupilot-b-ci` (`null`, `""`, `"N"`, `0`, `"0"`, `" "`: each 400 on a create and on a clear). Orchestrator ruling 2026-09-23: option (a), AD-27's fallback, now written into AD-27 as its one named case. `AdminPort` completes a `Security.Resource` `PUT` whose `PublicPermission` is empty through `Security.Resources.Create`/`Modify` in `%SYS`, behind the same `%Admin_Secure` gate, answering the vendor's status codes, with `VERIFIEDWRITES` re-reading it; nothing above the port changes. Pin it with a test that fails when the fallback is removed, for creating a private resource and for clearing an existing public permission (and edit-private). DW-1527 records the vendor defect for the contest's feedback channel.

### Ruled: P2, public permission on OcuPilot's own resources

Orchestrator ruling 2026-09-23: yes. AD-10 now carries the bullet: no public permission on `%DB_OCUPILOT` or `OcuPilotAdmin`, refused `PROHIBITED.OCUPILOTRESOURCE` whatever the caller (self-protection, AD-9). Its refusal needs its own test on both callers.

### Deferred to Story 9.3 (DW-1528): the Resources-list row action

Orchestrator ruling 2026-09-23, the 8.3 precedent: this story ships `permissions.resources.delete` (refusing a resource whose vendor `AllowDelete` is false and OcuPilot's own two resources); the Delete row action drawn disabled with its reason goes to Story 9.3 as DW-1528, beside DW-1513. It needs a new AD-53 self-protection word that reads the row's `AllowDelete`, an `ocupilot-resource` key predicate, `SCREENACTIONS`, `rowActions`, the handler entries and the published sentences (DW-1502 applies). `epics.md` 8.4 AC2 carries the `[AMENDED]` marker.

### Consumes and consumed-by

**Consumes:**

- Story 8.3's `ResourceGrantsAdministrativePrivilege`, `GrantsPrivilegeByEffect`, `privilegedGrantEffect`, the `RoleCreate`/`RoleDelete` shapes and `PORT.NOTAPPLIED`;
- Story 8.1's create kind;
- Epic 5's merge write (`UserUpdate`, `Mint.Merge`);
- Story 3.5's `FormDirty`.

**Consumed-by:**

- Story 9.3 (DW-1528) puts the Resources-list row action on `permissions.resources.delete`;
- Story 9.3's grant dialog lists resources this editor creates.

**Integration ACs:** AC4 (the Resources list re-reads on the change bus) and AC5 (the agent's events reach the same list).

## Verification

Stateful checks run on slot B's throwaway `ocupilot-b-ci` (web 52777, super 1976). When a fresh one is needed: `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`. This story creates, edits and deletes real resources, so nothing stateful runs against `ocupilot-slot-b`. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Run one test class per call, and wait for each run to land before sending the next.

### Targeted (loop)

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/resources-editor.browser-spec.mjs browser/roles-create.browser-spec.mjs` -- expected: all pass.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>`, one class per call -- expected: 0 failures each. Run it for `OcuPilot.Test.ResourceCreate`, `ResourceUpdate`, `ResourceDelete`, `ResourceWire`, `RoleCreate`, `RoleDelete`, `Prohibited`, `ProhibitedRoute`, `ToolWrite`, `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `PermissionsLists`, `Descriptor`, `EntityRef`, `WireSecurityRead` and `DerivedFields`.
- `cd ui && npm run test:tools && npm run test:components` -- expected: 0 failures.
- `cd ui && node tools/field-lists.mjs --check && node tools/screen-mirror.mjs --check && node tools/client-lint.mjs && node tools/browser-reset.mjs` -- expected: no drift.
- `uv run scripts/check-objectscript.py <changed paths>` and `bash scripts/lint-docs.sh` -- expected: clean.

### Once, before `dev_complete`

- The full ObjectScript sweep on a throwaway brought up after the last edit, one class at a time, with the totals checked against `%UnitTest_Result` -- expected: 0 failures and a non-zero count.
- `cd ui && npm run build && npm test` -- expected: green.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: all pass, with a non-zero count.
- The full browser suite is **not** run locally. CI's `browser` job runs it on a fresh throwaway (Rule 29; DW-1447).

### Pinning tests and mutations (Rule 19; the implementer records what was observed)

| AC | Pinning test | Mutation |
|---|---|---|
| AC1 | `resources-editor.browser-spec.mjs` order and read-only legs | Swap Description and Public permission; make Name editable in edit mode |
| AC2 | `ResourceDelete` system-resource test; `ResourceWire` `%Admin_Secure` leg | Drop the `AllowDelete` check from `ArgumentProblem` |
| AC3 | `ResourceUpdate` merge test on both callers | `HandleUpdate` sends the sent fields without `Mint.Merge` |
| AC4 | `resource-editor.store.spec.ts` change-event and route tests; the browser create leg | Drop the publish; drop the route replacement |
| AC5 | `ResourceDelete` own-resource test; the `VERIFIEDWRITES` test; `ResourceWire` real-port legs | Drop the `Resource` branch's delete step; empty `VERIFIEDWRITES` |
| AC6 | `ResourceCreate`/`ResourceUpdate` privileged tests; dialog spec | The `resource` branch of `GrantsPrivilegeByEffect` answers 0; the dialog's effect flag is false |
| AC7 | `resource-editor-dialog.spec.ts` dirty-close test; browser Escape leg | Close without `requestLeave()`; drop `DIALOG_EDITORS` from `app.routes.ts` |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned; the lead applied the orchestrator's rulings on P1-P4 and routed DW-1524 here at the spec gate.

### Summary

Planned the resource editor dialog (create from the list's Create, edit from the name cell's existing id route), three tools (create, merge update, agent-only action delete), `ResourceRules`/`ResourceSave` screen routes, a `resource` prohibited branch, `VERIFIEDWRITES` in `AdminPort`, and the `resource:foldcase` id rule. Instance facts are in Design Notes; AD-4 was corrected at its origin for `Security.Resource`.
