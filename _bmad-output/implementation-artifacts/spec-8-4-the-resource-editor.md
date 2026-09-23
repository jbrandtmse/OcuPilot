---
title: 'Story 8.4: The resource editor'
type: 'feature'
created: '2026-09-23'
status: 'done'
baseline_revision: '4d317b997a54c05b71656836b8a4651311ea664a'
baseline_commit: '4d317b997a54c05b71656836b8a4651311ea664a'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-3-create-a-role-and-manage-its-resource-grants.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A user update's EscalationRoles change is no longer refused PRIVILEGEGRANT but is still refused
      UNCOVEREDFIELD, because the Users write tool excludes the field and ToolWrite holds the kernel's
      reviewed list equal to the tool's advertised one.
    evidence: |-
      Prohibited.User no longer names EscalationRoles; Screen/Tool/UserUpdate.cls (Epic 7's diff, not
      contended) keeps EXCLUDEDFIELD EscalationRoles. Making it reachable needs that tool file.
    location: >-
      src/OcuPilot/Screen/Tool/UserUpdate.cls
    severity: low
  - summary: >-
      The Users write tool's model-facing Roles description still says a role granting an administrative
      privilege is refused, which now steers the agent away from a write AD-10 permits.
    evidence: |-
      Screen/Tool/UserUpdate.cls InputSchema Roles description (Epic 7's diff, not contended); the
      predicate now permits the delta and the mint marks it destructive (UserUpdate test, run 270).
    location: >-
      src/OcuPilot/Screen/Tool/UserUpdate.cls (InputSchema)
    severity: medium
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

### Review Findings

Code review 2026-09-23, `review_tier: full-opus` (blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 0 decision-needed, 8 patch (applied), 4 defer (ledger), 15 rejected.

- [x] [Review][Patch] (med) One id route to another (`/permissions/resources/A` to `/B`, the agent's navigation included) reuses the page, which read the id only in its constructor, so the dialog kept editing A [ui/src/app/areas/permissions/resource-list.page.ts:84] -- the page now follows `NavigationEnd`; new `resource-list.page.spec.ts`.
- [x] [Review][Patch] (med) An edit whose form read failed (non-404) or had not landed let Save send changes against blank values, so ticking R on a resource holding RW sent `R` and dropped W [ui/src/app/areas/permissions/resource-editor.store.ts:405] -- `canSave()` requires the fresh read in edit mode, fields take no input until it lands, and the dialog's `saveBlocked` reads it.
- [x] [Review][Patch] (med) AC6's negative half on the edit path and both form routes was unpinned: a constant `privileged` passed every test [src/OcuPilot/Test/ResourceWire.cls:92] -- dialog AC1 edit leg asserts no effect; `ResourceWire` asserts `%DB_USER` reads privileged 0 on both routes.
- [x] [Review][Patch] (low) The letters sentence and both tool schemas said any non-database, non-service, non-admin resource takes R, W or U, but ten more prefixes are Use-only [src/OcuPilot/Api/Error.cls:1900] -- sentences corrected (resource and role grant); `ResourceUpdate`/`RoleCreate` schemas list the prefixes from `RoleCreateRules.USEONLYPREFIXES`.
- [x] [Review][Patch] (low) An edit saved with nothing changed sent `PUT {}`, rewrote the resource and published `updated` [ui/src/app/areas/permissions/resource-editor.store.ts:404] -- it now writes and publishes nothing.
- [x] [Review][Patch] (low) A held letter the rule does not offer had no checkbox, so it could never be cleared and any permission change was refused `LETTERS` [ui/src/app/areas/permissions/resource-editor-dialog.ts:213] -- held letters are drawn too.
- [x] [Review][Patch] (low) Blur on an empty Name showed nothing; the form read's required-name rule was loaded and never used [ui/src/app/areas/permissions/resource-editor.store.ts:358].
- [x] [Review][Patch] (low) Save's `aria-disabled` over an absent resource was unpinned [ui/src/app/areas/permissions/resource-editor-dialog.ts:265] -- dialog spec leg added.
- [x] [Review][Defer] (med) The agent's confirmed create folds the name (`resource:foldcase`) while the screen keeps it as typed [src/OcuPilot/Kernel/EntityRef.cls:59] -- deferred: DW-1493 root cause, occurrence appended (escalated, owner burndown).
- [x] [Review][Defer] (med) The Users write tool's Roles description still says a privileged role is refused [src/OcuPilot/Screen/Tool/UserUpdate.cls:99] -- deferred: confirmed present, DW-1537 (escalated).
- [x] [Review][Defer] (low) No real-port leg for an agent create/update, no browser leg saving an edit [src/OcuPilot/Test/ResourceWire.cls] -- deferred: DW-1538 wontfix-accepted.
- [x] [Review][Defer] (low) Stale EXPERIENCE.md rows :360 (empty-state second line) and :403 (privilegedGrantEffect sites); stale DW-1524 text in `Test/UserUpdate.cls` header and unused `Prohibited.FIELDESCALATIONROLES` [EXPERIENCE.md:360] -- deferred: existing rows and contended hunks, DW-1539 and DW-1540 wontfix-accepted.

Rejected:

- `low` A public W on `%DB_IRISSYS` or U on `%Development` is not marked privileged -- spec-bound: Always row 4 scopes privilege to `ResourceGrantsAdministrativePrivilege` (AD-10 as amended).
- `low` `AdmissibleLetters` applies on create and ignores case, unlike the classic dialog -- the matrix refuses an inadmissible letter on create; case-folding is documented, for the agent's spellings.
- `low` The `OCUPILOTRESOURCE` sentence says only the installer changes the resource while a Description edit is allowed -- the sentence is the spec's own wording.
- `low` Edit-mode privilege denial reads "to create a resource" -- the list screen is gated on the same pair, so it appears only if the privilege is revoked mid-session; a fix needs a new string.
- `low` The form read gives no field-level sign that OcuPilot's own resources refuse an added letter -- the 403 reason is shown; a gap, not a defect.
- `low` `HandleForm` echoes the requested spelling in the heading -- the name cell links the instance's own spelling.
- `low` Screen create/update race with a concurrent create or delete (upsert) -- a window between two reads of one request, 8.3's shape, rejected in the earlier pass.
- `low` `setName` keeps the previous name's `privileged` until the blur reply -- the checkbox click blurs the name first; the window is one round trip.
- `low` A canceled create route replacement leaves `retaining` set -- no path cancels a `replaceUrl` from a clean editor.
- `low` The effect shows on an admin resource that already holds a letter -- settled as R5 in the earlier pass.
- `low` `ResourceSave.PortClass` resolves the update tool's port for the create -- both tools inherit one port declaration; nothing diverges today.
- `false` The AD-27 fallback skips `ValidateSemantics` -- `%Api.Admin.Endpoint.ValidateSemantics` returns OK and `Security.Resource` does not override it; `ValidateQueryParams` only sets `Name`, which the fallback sets (read on `ocupilot-slot-b`).
- `false` AD-27 fallback exceeds its one named case -- `CLASSCOMPLETEDTYPES` is exactly `Security.Resource/PUT=PublicPermission`, empty string only.
- `false` An AC lacks a `mutation:` line -- every AC, P1, P2 and DW-1524 has one.
- `false` Rule 3 real-runtime evidence missing -- `resources-editor.browser-spec.mjs` and `ResourceWire` drive the real instance.

## Spec Change Log

- 2026-09-23, spec gate (orchestrator rulings): P1 is AD-27's fallback (AD-27 amended; the lead ruled out every other encoding); P2 adds `OCUPILOTRESOURCE` to AD-10; the row action goes to Story 9.3 (DW-1528); `Classification.cls` is contended append-only; DW-1524 is routed here as floor-blocking; AD-4 was corrected for `Security.Resource`. Status set to `ready-for-dev` without a re-plan.

## Review Triage Log

### 2026-09-23 — Review pass

- verdicts: 23 findings — high 0, medium 4, low 12, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` VG: `showsPrivilegedEffect()`'s `privileged` half is unpinned; an ordinary name with a letter checked could state the privilege sentence with the suite green — added the store leg `AC6: no consequence is stated on a name the server did not mark privileged` (mutation below).
  - `[medium]` `[patch]` VG: `ResourceUpdate`'s "letters in another order" leg reverses `%DB_USER`'s empty permission, so it compares `""` with `""` and `AdminPort.SameValue`'s letter-set comparison is unpinned — the vacuous claim removed from `ResourceUpdate`, and `ResourceWire.TestARealWriteTheVendorDidNotApplyFailsNotApplied` now sends `UR` to a probe the vendor stores as `RU` through the real port (mutation below).
  - `[low]` `[reject]` VG: the AD-27 fallback's own `ResourcesOR()` gate and `ValidateRequest` have no test — defense in depth: every caller above the port (the screen gate, each tool's `PrivilegePairs`, `EDITFIELDS`, the composed settable fields) already refuses both cases; a test needs a principal without `%Admin_Secure`.
  - `[low]` `[patch]` VG other: `Prohibited.Codes()`'s doc said `PRIVILEGEGRANT` is reached by users as well as web applications — corrected to "only a web application reaches".
  - `[false]` `[reject]` VG other: an AC without a `mutation:` line — every AC has one in the Observed block.
  - `[low]` `[reject]` VG other and IA: the browser AC4 leg cannot tell a change-bus update from a re-read after navigation — the publish is pinned by the store spec against the Resources list's declared entity type (`SCREENS ... entityType 'resource'`), and the list's consumption is the shared refresh framework's, pinned by its own specs.
  - `[low]` `[reject]` IA R3: the agent's out-of-order or lower-case letters reach the vendor as given — the vendor stores them canonically and `VerifyApplied` compares as a set; the only visible effect is a card row `RU -> UR`, and canonicalizing needs a new rule and sentence.
  - `[low]` `[reject]` IA R4: a screen create with a bad name reports only the name, where the mint reports every field — the dialog validates the other fields inline on blur, and reporting both needs a second `Validate` pass in `ResourceSave.Create`.
  - `[false]` `[reject]` IA R5: the effect shows on an administrative resource already holding a letter — the matrix row says "while a letter is checked"; implemented as specified.
  - `[false]` `[reject]` IA R7: only an added letter on OcuPilot's own resources is refused — the spec's task says exactly that, and a clear stays possible.
  - `[low]` `[reject]` IA R8: the delete of an own resource is proposed and refused at the confirm — AD-10's set is evaluated at the write path by design (`Mint` never calls `Prohibits`), the role delete of 8.3 behaves the same.
  - `[false]` `[reject]` IA R10: the agent create requires both fields — the vendor create requires both; one diff row per supplied field still holds.
  - `[medium]` `[defer]` IA R11 (DW-1524): an `EscalationRoles` change is refused `UNCOVEREDFIELD`, not permitted — reaching it needs `Screen/Tool/UserUpdate.cls` (Epic 7's diff, not contended); already in `deferred:` with the stale Roles description.
  - `[low]` `[reject]` IA: the screen create checks the name then upserts with no fingerprint — a millisecond window between two reads of the same request, the 8.3 role create's shape.
  - `[low]` `[reject]` IA: `Type` in a screen create body is refused 403 `UNCOVEREDFIELD`, in an edit 400 — refused on both; only the code differs.
  - `[medium]` `[patch]` IA: `PORT.NOTAPPLIED` reaching the dialog was untested — added the store leg `AC5: a Save the vendor did not apply reports the refusal, never saved, and publishes nothing` (mutation below).
  - `[low]` `[reject]` IA: an absent resource's reason shows in the dialog's alert banner rather than the violations summary — the reason is shown and announced, and Save is blocked (store test).
  - `[low]` `[reject]` IA: the update mint for an absent name answers the kernel's shared 400 `TOOL.ARGUMENTS` naming the target, not 404 `RESOURCE.NAME.ABSENT` — every update tool answers so; nothing is sent; changing it edits the contended kernel.
  - `[false]` `[reject]` IA: Deletable may render the raw `false` — `ResourceList` renders a system resource as No (pre-existing column, its doc and list specs).
  - `[low]` `[reject]` IA: the agent's navigation away from a dirty dialog is not driven by a test — agent navigation goes through the router, whose guard `app.routes.spec.ts` pins on the Resources routes.
  - `[low]` `[reject]` IA R9: the client keeps `RWU` as the alphabet for ordering — the admissible letters per name are the server's `letterRules`; `RWU` is the vendor's fixed permission alphabet.
  - `[false]` `[reject]` IA: `resourceEditorEdit` has no Fixed strings comment of its own — row 407 carries both headings and `client-lint` passes.
  - `[false]` `[reject]` IA: "No forbidden file is touched" noted as alignment, not a defect.

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

Observed (implement stage; each applied to the working file, loaded with `cbk` (subclasses recompiled) or rebuilt and redeployed, observed red, restored from a byte copy and reloaded):

- mutation: `ResourceDelete.ArgumentProblem` answers no problem -> `ResourceDelete.TestASystemResourceIsRefusedAtTheMint` (run 230) and `ResourceWire.TestAnAgentDeleteThroughTheRealPortRemovesTheResource` (run 231) red (AC2)
- mutation: `ResourceSave.Update` sends the caller's fields without `Mint.Merge` -> `ResourceUpdate.TestAnEditKeepsTheFieldTheCallerDidNotChangeOnBothCallers` red (run 232, AC3)
- mutation: `Prohibited.Resource` drops its `DELETE` leg -> `ResourceDelete.TestOcuPilotsOwnResourcesAreRefusedAtTheWrite` red (run 233, AC5, P2)
- mutation: `AdminPort.VERIFIEDWRITES` emptied -> `ResourceUpdate.TestAVendorWriteThatDidNotApplyFailsNotApplied` (run 234) and `ResourceWire.TestARealWriteTheVendorDidNotApplyFailsNotApplied` (run 235) red (AC5)
- mutation: the `resource` branch of `Prohibited.GrantsPrivilegeByEffect` answers 0 -> `ResourceCreate.TestAPrivilegedPublicPermissionIsGrantedAtTheStrongestConfirmationOnBothCallers` (run 236) and `ResourceUpdate.TestAPrivilegedPublicPermissionIsMarkedOnTheAgentsEdit` (run 237) red; `Mint` passes no target id -> the create's privileged test red (run 238) (AC6)
- mutation: `Prohibited.Created`'s `resource` step disabled -> `ResourceCreate.TestACreateOpeningOcuPilotsOwnResourceIsRefusedOnBothCallers` red on both callers (run 239); `Prohibited.Resource`'s added-letter test dropped -> `ResourceUpdate.TestAnAddedPublicLetterOnOcuPilotsOwnResourceIsRefusedOnBothCallers` red on both callers (run 240) (P2)
- mutation: `AdminPort.CLASSCOMPLETEDTYPES` emptied -> `ResourceWire.TestAPublicPermissionOfNoneIsCreatedClearedAndKept` red with its create-private, clear and edit-private legs each red on its own (run 243; each leg starts from a resource made directly) (P1)
- mutation: `Prohibited.User` refuses a privilege-granting `Roles` delta `PRIVILEGEGRANT` again -> `UserUpdate.TestAPrivilegedRoleDeltaIsMintedDestructiveAndConfirmed` and `TestARoleDeltaThatGrantsPrivilegeIsPermittedAndClassifiedPrivileged` red (run 244); `EscalationRoles` back in `AlwaysProhibitedFields("user")` -> `UserUpdate.TestAChangedEscalationRoleAndAnUnreviewedFieldAreRefused` red (run 245); `IsPrivilegedRole` compares unfolded -> the different-case test red with four other classifier legs (run 264); `RoleNames` string branch reads nothing -> `TestARoleDeltaIsReadWhenTheRolesMemberIsAString` red alone (run 265) (DW-1524)
- mutation: `resource:foldcase` dropped from `EntityRef.IDRULES` -> `EntityRef.TestTheIdRuleTableIsDeclaredAndIsWhatNormalizationApplies` (run 246) and `ResourceDelete`'s canonical-spelling and own-resource legs (run 247) red
- mutation: `ResourceUpdate.Described` adds no required field -> `ResourceCreate.TestTheSchemaAndTheSettableSetAreTheSets` red (run 248); `ResourceRules.Validate`'s admitted-letters test dropped -> `TestEveryFieldRuleRefusesOnBothCallers` red (run 249); its repeated-letter test dropped -> the same red on case 6 (run 250); `ResourceSave.Create` composes over `Description` alone -> `TestTheScreenAndTheConfirmSendOneBody` red (run 251); `ResourceCreate.CREATES` 0 -> the confirmed-create and taken-name tests red with four others (run 252); the database prefix dropped from `LetterRules` -> `TestTheFormReadPublishesTheSentencesAndTheLetterRules` red (run 253)
- mutation: `PublicPermission` dropped from `ResourceUpdate.PERMITTEDFIELDS` -> `ResourceUpdate.TestTheUpdateIsAMergeWriteOverTheScreensOwnPairs` red with two others (run 254); `ResourceSave.Update`'s `EDITFIELDS` check dropped -> `TestTheEditRulesRefuseOnBothCallers` red (run 255)
- mutation: `PublicPermission` dropped from `ResourceDelete.READANSWERS` -> `ResourceDelete.TestTheDeleteIsAnActionWriteOverTheScreensOwnPairs` red on the live-read comparison (run 259); subject and precondition moved to `Description` -> that test and `TestTheRemovalRowsAndAMovedPublicPermissionRefusesTheConfirm` red (run 257); `CHANGEACTION` `updated` -> `TestAConfirmedDeleteIsMarkedAndSendsNoBody` red (run 258)
- mutation: `ResourceSave.RenderViolations` renders `ROLEVALIDATION` -> `ResourceWire.TestEachRouteAnswersOneJsonEnvelopeOverTheWire` red (run 261); `Security.Resource/PUT` removed from `MUTATINGTYPES` -> the create, fallback and not-applied legs red (run 262); `Security.Resource/DELETE` removed from `BODYLESSTYPES` -> the agent delete leg red (run 263)
- mutation (component specs): the store's `publish` dropped -> `resource-editor.store.spec.ts` AC4 and AC3 red; `changedFields` sends every field -> AC3 red; the created id not recorded -> AC4 red; `[readOnly]="editing"` dropped -> `resource-editor-dialog.spec.ts` edit-mode AC1 red; `showEffect` false -> both AC6 legs red; `requestClose()` resets without asking -> the store's and the dialog's AC7 red; `DIALOG_EDITORS` dropped from `buildRoutes` -> `app.routes.spec.ts` guard test red; `resourceEditor.reset()` dropped from `app.ts` -> `app.spec.ts` sign-out test red; `DIALOG_EDITORS` emptied -> `navigation.test.mjs` red
- mutation (two rebuilt, redeployed bundles): Description moved after the Public permission fieldset, the page's route replacement dropped and `showEffect` false -> browser AC1 (create), AC4 and AC6 red, the edit and AC7 legs green; `[readOnly]` dropped and `requestClose()` not asking -> browser AC1 (edit), AC4 (its read-only check), AC7 and AC6 (its Escape) red; green again on the restored bundle (15/15 across `resources-editor`, `roles-create`, `users-create`)
- roster rows: `Prohibited` (the reviewed-list sweep over a type with both a merge and an action tool, run 212), `PermissionsLists` (run 220), `EntityRef` (run 223), `entity-ref.test.mjs` and `screen-mirror.test.mjs` were observed red before this story's rows and green with them; the `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `PortFixture` and `Prohibited` code-count rows were added before their first run and are green (runs 213-219), not observed red
- mutation (review pass): `showsPrivilegedEffect()` answers `letters !== ''` alone -> `resource-editor.store.spec.ts` "AC6: no consequence is stated on a name the server did not mark privileged" red (AC6); a failed Save marks the editor saved -> the store's "AC5: a Save the vendor did not apply ..." red (AC5); `AdminPort.SameValue` compares `PublicPermission` verbatim -> `ResourceWire.TestARealWriteTheVendorDidNotApplyFailsNotApplied` red on its letter-order leg (run 273; green at run 272 before it) (AC5)
- (QA) mutation: restored `Prohibited.User`'s pre-DW-1524 blocks (`EscalationRoles` changed -> `PRIVILEGEGRANT`; a `Roles` delta `GrantsPrivilege` -> `PRIVILEGEGRANT`) on the working file, loaded (`cbk-d`, compiled clean) -> `UserUpdate.TestAChangedEscalationRoleAndAnUnreviewedFieldAreRefused`, `TestAPrivilegedRoleDeltaIsMintedDestructiveAndConfirmed` and `TestARoleDeltaThatGrantsPrivilegeIsPermittedAndClassifiedPrivileged` red, 3 of 19 (run 198, `ocupilot-b-ci`); reverted to a byte-identical copy, reloaded, 19 of 19 green (run 199) (DW-1524, independently re-confirmed by QA)
- (code review) mutation: the page's `NavigationEnd` follow dropped -> `resource-list.page.spec.ts` AC1 red (AC1); `canSave()` ignoring the held read -> the store's "an edit whose read failed ..." red; the unchanged-edit early return dropped -> "an edit saved with nothing changed ..." red; `markEmptyName()` dropped -> the empty-name blur leg red; `letterViews` drawing `admitted()` alone -> the dialog's held-letter leg red; `saveBlocked` answering `busy()` alone -> the dialog's `aria-disabled` leg red; `openEdit` marking every resource privileged -> the dialog's AC1 edit leg red (AC6); `HandleForm`/`HandleName` sending `privileged` 1 -> `ResourceWire.TestEachRouteAnswersOneJsonEnvelopeOverTheWire` red (run 201, green at 200 and 202 after restore) (AC6). Each reverted byte-identical.
- (QA) `ui/tools/ci.test.mjs` run directly: 65 of 65 pass, including "DW-1276: each arming roster names exactly the classes that declare that variable" -- `ResourceWire`'s roster row in `scripts/ci-throwaway.sh` needs no further edit there (Rule 8; the test derives the roster from the class's own `ARMINGVARIABLE` declaration rather than a second hand-written list)
- (QA) judged unnecessary: a `ResourceWire` leg sending a real `DELETE` for a system resource to the vendor, to exercise its 409. The mint's `AllowDelete` check refuses a system resource's delete before any `DELETE` reaches the port (I/O matrix: "Nothing is deleted"; `ResourceDelete.TestASystemResourceIsRefusedAtTheMint` and the mint half of `ResourceWire.TestAnAgentDeleteThroughTheRealPortRemovesTheResource` already pin that). 8.3's `RoleWire` carries the identical gap for a system role's delete, accepted (Review Triage Log IA R8). The generic HTTP 409 -> `PORT.CONFLICT` mapping `AdminPort.Fail` uses for any non-2xx is independently pinned in `Test/Fault.cls` and `Test/Envelope.cls`. No new test added for this.

## Auto Run Result

Status: done
Blocking condition: none

footprint_extensions: contended `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, `src/OcuPilot/Kernel/Proposal/Mint.cls`, `src/OcuPilot/Api/Router.cls`, `src/OcuPilot/Screen/Tool/Classification.cls` (tail append), `src/OcuPilot/Screen/Tool/ToolFields.cls` (regenerated), `src/OcuPilot/Test/{SurfaceCoverage,EndpointCoverage,ReadTool,ToolRoundTrip,PortFixture,Prohibited,UserUpdate}.cls`, `ui/tools/screen-mirror.test.mjs`; shared-append `src/OcuPilot/Port/AdminPort.cls` (plus one-line hooks in `Invoke` and `RunSequence`), `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss`, EXPERIENCE.md Fixed strings rows 406-407; in Epic 7's diff but not contended: `ui/src/app/core/screens.generated.ts` (regenerated) and `src/OcuPilot/Test/AuditingUpdate.cls` (one-line code-count roster at :505, off Epic 7's tail hunk, the line Story 8.3 already moved to 14)

### Summary

The resource editor dialog on the Resources list (create from Create, edit from the name cell's route), `permissions.resources.create`/`.update`/`.delete`, the `ResourceRules`/`ResourceSave` routes, the `resource` prohibited branch with `PROHIBITED.OCUPILOTRESOURCE`, `VERIFIEDWRITES` and AD-27's empty-`PublicPermission` fallback in `AdminPort`, `resource:foldcase`, and DW-1524's role-delta permission in `Prohibited.User`. No row action (Story 9.3, DW-1528). The form read ships `rules`, not `privilegeReason`, which 8.3's reversal removed.

### Files

- Server: `Port/AdminPort.cls` (write types, `VERIFIEDWRITES`, `CLASSCOMPLETEDTYPES`), `Kernel/Proposal/Prohibited.cls` (resource branch, own resources, DW-1524), `Mint.cls` (target id to the classifier), `Kernel/EntityRef.cls`, `Api/Error.cls` (`RESOURCE.*`), `Api/Router.cls` (four routes), `Area/Permissions/Resource{Rules,Save}.cls`, `Screen/Tool/Resource{Create,Update,Delete}.cls`, `Screen/Descriptor/ResourceList.cls`, `Classification.cls`/`ToolFields.cls`.
- Client: `areas/permissions/resource-{actions,editor.store,editor-dialog,list.page}.ts`, `navigation.ts` (`DIALOG_EDITORS`), `app.routes.ts`, `screen-outlet.ts`, `app.ts`, `strings.ts`, `_components.scss`, `screens.generated.ts`.
- Tests: `Test/Resource{Create,Update,Delete,Wire,Fixture,WritePort}.cls`, `resource-editor{.store,-dialog}.spec.ts`, `resources-editor.browser-spec.mjs`, roster rows in the classes above, `UserUpdate.cls` (five privileged-refusal methods recoded plus a regression test), `AuditingUpdate.cls` (code count), `scripts/ci-throwaway.sh` (`ResourceWire` armed).

### Review

Two layers (verification-gap, intent-alignment), 23 findings: patched 3 medium (the effect's non-privileged half, the vacuous letter-order leg now a real-port leg in `ResourceWire`, `PORT.NOTAPPLIED` reaching the store) and 1 low (a stale `Codes()` doc); deferred 1 (DW-1524's `EscalationRoles`, already in `deferred:`); rejected 12 low and 7 false, each with its reason in the triage log. Follow-up review: not recommended; the patches are tests whose mutations were observed, and no production code changed in the review pass.

### Verification

- Full ObjectScript sweep on a throwaway brought up after the review patches: 191 classes, 1727 tests, one failure, `AuditingUpdate`'s code-count roster (14 -> 15); fixed, reloaded, and that class re-ran green (6 tests). No other file changed after the sweep.
- `npm run build` green, initial total 1.17 MB (under the 1185 kB warning); `npm test` 1325 tool tests and 871 component tests green.
- `smoke.sh --container ocupilot-b-ci`: 46 executed, 46 passed.
- Browser (bundle redeployed): `resources-editor`, `roles-create`, `users-create` 15/15.
- `field-lists`/`screen-mirror --check`, `client-lint`, `browser-reset`, `check-objectscript`, `lint-docs`: clean.
- Mutations for every AC, P1, P2 and DW-1524 are in `## Verification`.

### Residual risks

- DW-1524 is part-done: a privilege-granting role delta is permitted and marked, but an `EscalationRoles` change is still refused (`UNCOVEREDFIELD`), and `permissions.users.update`'s Roles description still tells the agent a privileged role is refused. Both need `Screen/Tool/UserUpdate.cls`, which is in Epic 7's diff and not contended (see `deferred:`).
- Expect merge hunks next to Epic 7 in `Prohibited.cls` (`COVEREDTYPES`, type gate, the `User` block), `AdminPort.cls` type lists, `Classification.cls` tail and `Router.cls`.
- The resource delete's vendor 409 is not exercised over the wire; the mint's `AllowDelete` check refuses first. Closed by QA: judged unnecessary, see `## Verification`'s QA rows.
