---
title: 'Story 8.3: Create a role, and manage its resource grants'
type: 'feature'
created: '2026-09-22'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-2-create-a-user.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A role cannot be created or deleted from OcuPilot. `Security.Role` creates only through an upsert `PUT` that silently rewrites an existing role, and its `DELETE` answers 200 even when the drop did not happen. The prohibited set does not cover the `role` type, so every role write would be refused `UNCOVERED`.

**Approach:** Ship `permissions.roles.create` and a `permissions/roles/edit` create form as two callers of one tool (AD-54, AD-55). The form carries a resource-grant dialog that shows the current and the resulting grant. Ship `permissions.roles.delete` as an action-style write (AD-51). The prohibited set gains a `role` branch: it refuses escalating grants on create, and refuses deleting OcuPilot's own roles or the last `%All` holder's path to it.

## Boundaries & Constraints

### Always

- Escalation (AD-10, AD-55), refused inside the write path whatever the caller, with the one caller-neutral `PRIVILEGEGRANT` sentence. The predicate is the existing one plus one clause (DW-1512, orchestrator ruling 2026-09-23, AD-10 amended):
  - A **resource grant escalates** when the resource's name is `%All` or begins `%Admin_`, at any permission (`Prohibited.IsPrivilegedRole`), **or it is `%DB_IRISSECURITY` with WRITE** (the security database; by effect it is `%All`).
  - A **granted role escalates** when `Prohibited.RoleEscalates` says so: its name, a role it recurses to, or a resource any of those carries -- which now includes a role carrying `%DB_IRISSECURITY:W` (the `%DB_IRISSECURITY` role, and any role recursing to it), for users (8.2) and roles alike.
  - On the screen the refusal is one AD-39 `detail.violations[]` row `{field, code:"PROHIBITED.PRIVILEGEGRANT", reason}` on each offending field (`Resources`, `GrantedRoles`). The bootstrap read ships the same sentence for the pickers' pre-marks. The client holds no copy.
- The create is `PUT` with `CREATES = 1`. The absence fingerprint (AD-54) is the only thing standing between a confirmed create and a silent rewrite of someone else's role. `Name` travels only as the `name` query parameter, because the vendor refuses it in the body.
- A grant is `{Name, Permissions}`, the vendor's own shape, in the arguments, the payload and the diff row alike. A permission letter is admitted only if the classic grant dialog offers it for that resource. That rule is authored once, in `RoleCreateRules`, and shipped per resource in the bootstrap read.
- Every field sentence is authored once in `Api/Error.cls`. Every visible word is `STRINGS.<key>`, and each new key has a Fixed strings row.
- A role delete is refused for:
  - a name beginning `%`, the instance's own roles (tool rule `ROLE.NAME.SYSTEM`);
  - one of OcuPilot's own roles (`PROHIBITED.OCUPILOTROLE`, AD-10);
  - a role whose removal leaves no counted `%All` holder (`PROHIBITED.LASTALLHOLDER`, AD-10).
- The port re-reads after a `Security.Role` DELETE. A role still present fails the call. It never reads as deleted.

### Never

- Never edit `Kernel/Proposal/Confirm.cls`, `Kernel/Restraint.cls`, `Port/LogSourcePort.cls`, `Install/Smoke.cls` or `ui/src/app/areas/{tasks,logs}/**`.
- Never add `Security.Role/POST` to the port. The vendor's inherited `RunPost` answers `{}` and writes nothing, and a `Run` override makes `ImplementsRead` accept it.
- No field outside the acceptance criterion's set (name, description, resources, granted roles). `EscalationOnly` stays out of the schema and the payload, and the prohibited set refuses it `UNCOVEREDFIELD`. Story 9.3 owns it.
- No Epic 9 work. `permissions/roles/edit/:id` redraws the create form with the created values, as 8.1's and 8.2's do. Re-saving there is refused because the name is taken.
- No change to `RoleEscalates`' verdicts beyond the `%DB_IRISSECURITY:W` clause. WRITE on `%DB_IRISSYS` and `%DB_IRISLIB` stays out (DW-1512, decision-pending for the owner).
- No second row-action mechanism, and no edit to any file Epic 7 added. The Roles-list row action is Story 9.3's (DW-1513).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create through the screen | `POST /api/ocupilot/roles` with a free `Name`, optional `Description`, `Resources:[{Name:"%DB_USER",Permissions:"RW"}]`, `GrantedRoles:["%Developer"]` | 201 `{name, role}`. The port sends `PUT Security.Role?name=<Name>` with the flat body. The client publishes `{kind:'changed', type:'role', scope:'instance', id, action:'created'}` and replaces the route with `permissions/roles/edit/<id>` | No error expected |
| Create through the agent | `permissions.roles.create` minted, then confirmed | One diff row per supplied field (`Resources` shows its JSON) and `unchangedCount` 0. Confirm matches the absence fingerprint. A marker, a ledger row and a `created` event follow | No error expected |
| Escalating resource, either caller | `Resources` names `%Admin_Secure`, or any `%Admin_*` resource, at any permission | Screen: 422 with a `PRIVILEGEGRANT` row on `Resources`, no port call. Agent: minted, then 403 `PROHIBITED.PRIVILEGEGRANT` inside the transition | Nothing is created |
| Escalating granted role, either caller | `GrantedRoles` holds `%All`, `%Manager`, or a custom role that reaches one | As above, on `GrantedRoles` | Nothing is created |
| Name taken | Any spelling of an existing role | Screen: `ROLE.NAME.TAKEN` on Name, also answered on blur by `GET /roles/name`. Mint: 400 `TOOL.ARGUMENTS`. Taken after the mint: 409 `PROPOSAL.TARGETCHANGED` | The upsert `PUT` is never reached |
| Field rules | Name empty, over 64 characters, holding a control character, `,` or `:`, or beginning `%`; Description over 256; a grant not `{Name, Permissions}`, naming no resource, repeating one, or carrying a letter its resource does not admit; a granted role that does not exist or is not a string | One `ROLE.<FIELD>.<RULE>` violation per failing field. The same `Validate` runs as the tool's `ArgumentProblem` at mint | The banner takes focus, then the first invalid field |
| Agent delete | `permissions.roles.delete` for a custom role | The diff is one removal row per fingerprint-subject field. Confirm sends a bodyless `DELETE`, the port confirms the role is gone, and a marker and a `deleted` event follow | No error expected |
| Delete refused | A `%`-prefixed name; `OcuPilotAdmin`, `OcuPilotIdentity`, `OcuPilotShell` or `OcuPilotReadiness`; or the role through which the last counted holder reaches `%All` | 400 `TOOL.ARGUMENTS` (`ROLE.NAME.SYSTEM`); 403 `PROHIBITED.OCUPILOTROLE`; 403 `PROHIBITED.LASTALLHOLDER` | Nothing is deleted |
| Delete the vendor did not apply | `DELETE` answers 2xx and a re-read finds the role | The port fails 500 `PORT.NOTAPPLIED` | The row closes failed, never "deleted" |

</intent-contract>

## Code Map

### Contention (Epic 7 on slot A)

Before editing any file marked ⚠, read Epic 7's version with `git fetch origin && git show origin/OCU-1-epic7:<path>`. Keep off its hunks (line numbers below are on that branch) and restructure nothing it added. `Screen/Descriptor/RoleList.cls`, `Kernel/EntityRef.cls`, `Api/Error.cls`, `Area/Permissions/**` and `Test/ProhibitedFixture.cls` are not in Epic 7's diff.

### Server: tools, port, prohibited set

- `src/OcuPilot/Screen/Tool/UserCreate.cls` -- the create template: `CREATES` :29, `CHANGEACTION` :32, `PERMITTEDFIELDS` :43, the authored argument :46, `SettableFields` :68, `InputSchema` :96, `ArgumentProblem` :111, `PrivilegePairs` :126.
- `src/OcuPilot/Screen/Tool/ErrorDelete.cls` -- the action-style delete template: `READTYPE`/`WRITETYPE`/`SENDSBODY`/`CHANGEACTION`/`DESTRUCTIVE` :37-53, `READANSWERS` :59, `PRECONDITIONFIELD` :63, `FINGERPRINTSUBJECT` :69, `StateDiff` :145 (removal rows).
- `src/OcuPilot/Screen/Tool/Write.cls` -- needs no edit. Its parameters are :52-154, `FieldRows` :384, which admits top-level literals and literal arrays only, and `ArgumentProblem` :568. ⚠ Epic 7 adds `SCREENACTIONS` at 123-144 and methods at 192-244.
- `src/OcuPilot/Screen/Registry.cls` -- the fingerprint-subject guard is at ~:2071-2110: a bodyless tool declares a subject, and that subject contains `PRECONDITIONFIELD`. No edit is needed.
- `src/OcuPilot/Screen/Tool/FieldLists.cls` :313-322 already derives `Security.Role`: `Description`, `GrantedRoles[]`, `EscalationOnly`, and the nested `Resources[].Name`/`.Permissions`. `Classification.cls` has no role entry yet. The users entry is at :189-211.
- ⚠ `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :126 and the dispatch guard :396. Epic 7 appends its OAuth types to the same two lines (its :126, :357), so this is a one-line merge on each.
  - `PermittedCreateFields` :318 and `AlwaysProhibitedCreateFields` :334.
  - `Prohibits` :385: the create branch :417-423 and the per-type dispatch :433-453. Epic 7 adds an `OAuthEntry` branch at its :401-410.
  - `Created` :512, with the user step at :537.
  - `GrantsPrivilege` :957 and `RoleNames` :992, which read `FIELDROLES` :177 only.
  - `RoleEscalates` :1028, `RoleGrantsAdministrativePrivilege` :1073, `IsPrivilegedRole` :1127.
  - `RolesGrantAll` :1191, `LastAllHolder` :1233 (an overridable seam), `CountsAsHolder` :1303.
  - `Codes` :201, `ReasonFor` :209. Epic 7 rewrites `ReasonFor`'s `SERVINGPATH` at its 219-228.
- `src/OcuPilot/Test/ProhibitedFixture.cls` -- where the `LastAllHolder` seam is overridden. The new delete seam goes there.
- ⚠ `src/OcuPilot/Port/AdminPort.cls`:
  - `MUTATINGTYPES` :166 and its doc :161-165. That doc says `DELETE` is deliberately absent; Epic 7 rewrites the same doc at its 152-164 and appends three `DELETE` entries at 170-186.
  - `BODYLESSTYPES` :182. Epic 7 appends at its 196-202.
  - `Invoke` :430, with the body refusal at :469.
  - `ImplementsRead` :924. Its override shortcut at :926 already admits `Security.Role`'s types, so this story adds no `DELETE` mapping. Epic 7 adds one at 866-879.
  - `Fail` :1126.
- `src/OcuPilot/Kernel/EntityRef.cls` `IDRULES` :59 has no `role` rule, so ids are kept verbatim.
- `src/OcuPilot/Kernel/State/Base.cls` `ADMINRESOURCE` :83 names `OcuPilotAdmin`. The identity role is `OcuPilotIdentity`: read its parameter near :60-67.
- `src/OcuPilot/Install/Roster.cls` `Keys` :200 and `Application` :223 carry the `matchRole` values `OcuPilotShell` :110 and `OcuPilotReadiness` :142.

### Server: screen routes (8.2 precedent)

- `src/OcuPilot/Area/Permissions/UserCreate.cls`:
  - `HandleCreate` :60 and `Perform` :108. `Perform` runs the prohibited verdict over `CallerFields` with diff `"[]"`, and at :138 a grant refusal becomes a field row.
  - `CallerFields` :185, `RenderViolations` :214, `Gate` :224, `PortClass` :44 (the test seam).
- `src/OcuPilot/Area/Permissions/UserCreateRules.cls`:
  - `Validate` :64, `RoleViolation` :203, `HandleForm` :249, `HandleName` :279.
  - `Taken` :314 reads through the tool's port. `Roles` :338 lists roles through the port, each `{name, privileged}`, and this story reuses it as is.
- ⚠ `src/OcuPilot/Api/Router.cls` -- 8.2's routes are :97-99 and its handlers :288-308. Epic 7 inserts `POST /screens/:screen/action` at its :95 and a handler at 250-266.
- `src/OcuPilot/Api/Error.cls`:
  - The `USER.*` block is :1620-1695.
  - `ReasonForViolation` :1041, `UserViolationCodes` :1125, `ViolationCodes` :1136.
- `src/OcuPilot/Screen/Descriptor/UserForm.cls` :18-46 -- the `form-page` declaration to copy.
- `src/OcuPilot/Screen/Descriptor/RoleList.cls`:
  - `primaryAction` :42 and `rowActions` :43.
  - `emptyNextKey "tableReadOnlyEmptyNext"` :63 and `emptyAgentKey ""` :64.

### Client

- `ui/src/app/areas/permissions/user-create-form.{page,store}.ts` and `user-actions.ts` -- copy their shape with the `ocu-role-` prefix; do not extract a base.
  - Page: error summary :63-78, field pattern :83-103, Roles fieldset :217-238 with getters :380-414, sticky bar :241-258, leave guard :261-271, `onSave` :478, focus sequence :513-526.
  - Store: `open` :246, `onBlur` :304, `save` :348, `absorbRules` :474 (fail-closed `privileged`), `publishCreated` :457.
- `ui/src/app/shell/dialog.ts` -- the house modal (`heading`, `closeLabel`, `[dialogAction]` slot, focus trap, `OverlayStack`). Dialogs never stack: a second `app-dialog` replaces the first.
- `ui/src/app/shell/change-password-dialog.ts` :74-162 -- the form-in-a-dialog precedent: a summary, `aria-describedby`, and the action projected through `dialogAction`.
- `ui/src/app/core/navigation.ts` `CREATE_ONLY_FORMS` :201-204. `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :88-98. `ui/src/app/app.ts`: injections :232-233, sign-out resets :500-501.
- ⚠ `ui/src/app/core/strings.ts` -- 8.2's block ends at :1368 and `} as const;` is at :1370. Epic 7 appends at the same point, ending at its :1380.
- ⚠ EXPERIENCE.md Fixed strings -- the last row is :400 and `## Component Patterns` is at :402. Epic 7 inserts at its :392-406. The surface rows :119-122 are the role surfaces.
- `ui/browser/users-create.browser-spec.mjs` -- the harness: `irisSys`, `privilegeSentence`, `signedInAt`, `roleBoxes`, `waitForSaved`.

### Deferred to Story 9.3 (DW-1513)

- **The Roles-list Delete row action (AC3's screen caller) has no conforming mechanism on this branch.** AD-53's generic route (`Api/ScreenAction.cls`), `Kernel/Proposal/Operation.cls`, `shell/screen-action-handler.ts`, `shell/typed-name-dialog.ts` and `core/self-protection.ts` exist only on `origin/OCU-1-epic7`. So do `Write.SCREENACTIONS`, the action route in `Router.cls` and the action validator in `Registry.cls`.
- A screen is served only after it is added to `screen-action-handler.ts`'s `SCREEN_ACTION_DESCRIPTORS` and `DESTRUCTIVE_CONSEQUENCES`, both inside Epic 7's files.
- That handler's consequence is a static `STRINGS` key. A live holder count therefore also needs an edit to Epic 7's handler.
- Ruled 2026-09-23: this spec ships everything else; its delete tool is the operation AD-53's screen caller will reach in Story 9.3.

## Tasks & Acceptance

### Execution

#### Port, identity and field lists

- `src/OcuPilot/Port/AdminPort.cls`:
  - Append `Security.Role/PUT,Security.Role/DELETE` to `MUTATINGTYPES` and `Security.Role/DELETE` to `BODYLESSTYPES`.
  - Reword the :161-165 sentence so it keeps `Process` out of `DELETE` without claiming `DELETE` is absent everywhere.
  - Add `Parameter VERIFIEDDELETES = "Security.Role/DELETE"`. After a 2xx for a listed pair, `Invoke` re-issues the endpoint's `GET` for the same id. Only a 404 confirms the delete. Anything else raises a 500 fault with code `PORT.NOTAPPLIED`.
  - Rationale: the vendor's `DropUser(…,"ROLE")` always answers `$$$OK`. That is a wire fact, and AD-27 confines wire facts to the port.
- `src/OcuPilot/Kernel/EntityRef.cls` -- append `,role:foldcase` to `IDRULES`. An IRIS role name is case-insensitive, so this is AD-13's per-type rule. DW-1493 applies: the agent's create sends the folded name.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- add a `permissions.roles.create` entry:
  - `fieldList: "Security.Role"`
  - `Description`, `GrantedRoles` and `EscalationOnly` are `ordinary`; `Resources` is `opaque`.
  - Then regenerate `ToolFields.cls` with `cd ui && node tools/field-lists.mjs`.

#### Tools

- `src/OcuPilot/Screen/Tool/RoleCreate.cls` -- new, on `UserCreate`'s shape:
  - `TOOLNAME "permissions.roles.create"`, `DESCRIPTORCLASS RoleList`, `CREATES 1`, `CHANGEACTION "created"`.
  - `WRITETYPE "PUT"`, stated with the upsert reason. `Endpoint() = "Security.Role"`.
  - `PERMITTEDFIELDS "Description,GrantedRoles"` plus the authored `RESOURCESARGUMENT "Resources"`.
  - `InputSchema` describes `Resources` as `{Name, Permissions}` objects, the letters R, W and U. It states that `%All`/`%Admin_*` resources and escalating granted roles are refused.
  - `ArgumentProblem` calls `RoleCreateRules.Validate`. `PrivilegePairs` is copied: the screen's pairs plus `%Admin_Secure:USE`.
- `src/OcuPilot/Screen/Tool/RoleDelete.cls` -- new, on `ErrorDelete`'s shape through the default `AdminPort`:
  - `TOOLNAME "permissions.roles.delete"`, `DESCRIPTORCLASS RoleList`.
  - `READTYPE "GET"`, `WRITETYPE "DELETE"`, `SENDSBODY 0`, `CHANGEACTION "deleted"`, `DESTRUCTIVE 1`.
  - `READANSWERS` and `FINGERPRINTSUBJECT` are both `"Description,GrantedRoles,EscalationOnly,Resources"`. The GET answers no `Name`.
  - `PRECONDITIONFIELD "Resources"`: what every holder loses is what the confirm must still find.
  - `StateDiff` emits removal rows.
  - `ArgumentProblem` refuses a `%`-prefixed name with `ROLE.NAME.SYSTEM`.
  - `PrivilegePairs` as the create's.

#### Prohibited set

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, staying off Epic 7's hunks:
  - Add `TYPEROLE "role"`, add it to `COVEREDTYPES` and the dispatch guard, and give it a branch in `Prohibits`.
  - Add `role` branches: `PermittedCreateFields` is `Description,GrantedRoles,Resources`, and `AlwaysProhibitedCreateFields` is empty.
  - Add a `role` step in `Created`. It refuses `PRIVILEGEGRANT` when `GrantsPrivilege(payload, {}, "GrantedRoles")` is true, or when any `Resources` element's `Name` is `IsPrivilegedRole`.
    - Give `GrantsPrivilege`/`RoleNames` a field parameter that defaults to `FIELDROLES`, so the user callers are unchanged.
  - Add a public `ResourceGrantsAdministrativePrivilege(pName) As %Boolean` over `IsPrivilegedRole`, for the resource pre-mark.
  - Add a `Role(pId, pToolClass, ByRef pChanged, …)` branch. For a tool whose `WriteType()` is `DELETE`:
    - refuse `OCUPILOTROLE` when the folded id is in `OcuPilotRoles()`;
    - otherwise refuse `LASTALLHOLDER` when `DeletingLeavesNoAllHolder(pId)` is true.
    - Any other role write is `ReviewedFewOnly` (fail closed).
  - `OcuPilotRoles()` builds the list from `Kernel.State.Base`'s admin and identity names and the roster's non-empty `matchRole` values, never a transcribed list.
  - `DeletingLeavesNoAllHolder(pRole, Output pLeaves) As %Status` is an overridable seam like `LastAllHolder`:
    - It answers 0 unless `RolesGrantAll` finds the role reaching `%All`.
    - It is 1 when counted holders (`CountsAsHolder`) reach `%All` now, and none of them still does once the role is gone. A holder still reaches `%All` if some direct role, walked through `GrantedRoles` with the deleted role skipped, arrives at `%All`.
  - Add `Parameter OCUPILOTROLE = "PROHIBITED.OCUPILOTROLE"` to `Codes()`. Its caller-neutral `ReasonFor` sentence is "This role belongs to OcuPilot, which stops working without it. It is removed only when OcuPilot is uninstalled."
- `src/OcuPilot/Test/ProhibitedFixture.cls` -- override `DeletingLeavesNoAllHolder` as `LastAllHolder` is overridden.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- DW-1512's ruled clause, added **alongside** the existing predicate (Epic 7's 7.2 has just restructured the account predicates to work by effect; do not restructure them): a resource grant of `%DB_IRISSECURITY` whose permissions include `W` escalates. Put it where both `RoleGrantsPrivilege` (a granted role's resources, which serves 8.2's user roles and its picker) and the `role` step's `Resources` check ask it, as one method (for example `ResourceGrantEscalates(pName, pPermissions)`), so the two cannot drift. `%DB_IRISSYS` and `%DB_IRISLIB` stay out.
- Tests: `RoleCreate` refuses a `Resources` grant `{Name:"%DB_IRISSECURITY", Permissions:"RW"}` on both callers and admits `{Name:"%DB_IRISSECURITY", Permissions:"R"}`; `UserCreate` refuses granting the `%DB_IRISSECURITY` role on both callers, and the picker pre-marks it. Mutation: drop the `%DB_IRISSECURITY` clause -> both red.

#### Screen routes

- `src/OcuPilot/Area/Permissions/RoleCreateRules.cls` -- new:
  - `Validate(pName, pArgs, Output pViolations, pCheckName, pCheckTaken)` holds the matrix's rules. Names are checked through `Security.Roles.Exists` and `Security.Resources.Exists` in `%SYS` (AD-16).
  - `AdmissiblePermissions(pResource)` returns what `%CSP.UI.Portal.Dialog.RoleResourceEdit` offers. Read that class and `RoleResourceNew.GetPermission` on the instance and port them exactly. The planner observed `%DB_*` → `RW`, the USE-only prefixes (`%Service_`, `%Admin_`, `%Development`, `%System_`, `%DeepSee_`, `%DocDB_`, `%Gateway_`, `%IAM`, `%Native_`, `%SQL`, `%SecureShell`) → `U`, and any other name → `RWU`.
  - `HandleForm` (`GET /roles/form`) answers `{requiredFields, maxLengths, rules, roles, resources, privilegeReason}`.
    - `roles` comes from `UserCreateRules.Roles`.
    - `resources` is `[{name, permissions, privileged}]`, listed through the tool's port `Security.Resource` `LIST`.
  - `HandleName` (`GET /roles/name`) and `Taken` read through the tool's port.
- `src/OcuPilot/Area/Permissions/RoleCreate.cls` -- new, mirroring `UserCreate.cls` (`HandleCreate`, `Perform`, `Gate`, `CallerFields`, `PortClass`):
  - A `PRIVILEGEGRANT` verdict is attributed by asking `Prohibits` again with `Resources` alone and with `GrantedRoles` alone. It answers 422 with one row per offending field. The predicate is not duplicated.
  - Then `Validate`, then `Mint.Compose`, then the port `PUT`.
- `src/OcuPilot/Api/Router.cls` -- after :99, add `GET /roles/form`, `GET /roles/name` and `POST /roles`, with thin handlers after :308.
- `src/OcuPilot/Api/Error.cls` -- after :1695:
  - a `ROLE.VALIDATION` 422 envelope code;
  - the `ROLE.NAME.{REQUIRED,LENGTH,SHAPE,TAKEN,SYSTEM}`, `ROLE.DESCRIPTION.LENGTH`, `ROLE.RESOURCES.{SHAPE,UNKNOWN,PERMISSIONS,DUPLICATE}` and `ROLE.GRANTEDROLES.{SHAPE,UNKNOWN}` codes with their sentences;
  - `PORT.NOTAPPLIED` ("The instance reported the change as made, and it is not there.").
  - Register them in `ReasonForViolation` and a `RoleViolationCodes`.

#### Descriptors

- `src/OcuPilot/Screen/Descriptor/RoleForm.cls` -- new `form-page` copying `UserForm`:
  - `route "permissions/roles/edit"`, `labelKey "roleFormLabel"`, `sideBarPosition 0`.
  - `entityType "role"`, the RoleList pairs, `classicPage "%CSP.UI.Portal.Role"`, `toolIdentifier "permissions.roleform"`.
- `src/OcuPilot/Screen/Descriptor/RoleList.cls`:
  - Set `primaryAction.id` to `"create"`.
  - Set `emptyNextKey` to `""` and `emptyAgentKey` to `"roleListEmptyAgent"`.
  - Doc: "declares no primary or row action" becomes a Create primary action.

#### Client

- `ui/src/app/areas/permissions/role-create-form.{page,store}.ts`, `role-grant-dialog.ts`, `role-actions.ts` -- new:
  - Fields in the classic order: Name (required), Description, Resources, Granted roles.
  - Resources lists each grant as `<resource>` plus the permission words, with Edit and Remove text buttons, then an Add-a-grant secondary button.
  - Granted roles is 8.2's checkbox fieldset. A privileged role is `disabled`, described by the bootstrap sentence.
  - The grant dialog is on `app-dialog`, with `ocu-role-` ids:
    - Add mode: a `select` of the resources not yet granted, privileged ones as disabled options with the sentence as a caption.
    - Checkboxes only for the admissible letters.
    - The "Current grant" and "Resulting grant" lines, each `<resource>: Read, Write` or "No grant".
    - Confirm applies the result to the store; a "No grant" result removes an edited grant; Confirm is `aria-disabled` for an add with no letter.
    - It makes no server call. The page closes it before the leave question renders.
  - The store posts to `/api/ocupilot/roles`, publishes the `role` `created` event, and replaces the route.
- `ui/src/app/core/navigation.ts` -- add `RoleForm` to `CREATE_ONLY_FORMS`.
- `ui/src/app/shell/screen-outlet.ts` -- the `DESCRIPTOR_PAGES` entry.
- `ui/src/app/app.ts` -- inject `RoleActions`, and reset the role form store at sign-out.
- ⚠ `ui/src/app/core/strings.ts` and ⚠ EXPERIENCE.md, **append only** after 8.2's block and rows, with two rows:
  - `roleListEmptyAgent` 'create a role', which is also the form's refusal action.
  - `roleFormLabel` 'New role', `roleFormGrantedRoles` 'Granted roles', `roleGrantAdd` 'Add a grant', `roleGrantDialogAdd` 'Add a resource grant', `roleGrantDialogEdit` 'Edit the grant on <resource>', `roleGrantCurrent` 'Current grant', `roleGrantResulting` 'Resulting grant', `roleGrantNone` 'No grant', `permissionRead` 'Read', `permissionWrite` 'Write', `permissionUse` 'Use', `actionRemove` 'Remove'.
  - Reuse `tableColumnName`, `tableColumnDescription`, `resourceListLabel`, `webAppColumnResource`, `navAreaPermissions` and `agentPanelSecretWarningEdit`, because values are unique.
- `ui/src/app/core/screens.generated.ts` -- regenerate; never hand-merge.

#### Tests and rosters

- `src/OcuPilot/Test/RoleCreate.cls` and `RoleCreateFixture.cls` -- new; the fixture overrides `PortClass`:
  - The schema holds no `EscalationOnly`, and the permitted set equals `Prohibited.PermittedCreateFields("role")`.
  - Every field rule is checked on both callers, and both send one body.
  - An escalating resource and an escalating granted role are each refused on both callers: on the right field on the screen, inside the transition on confirm, including a seeded row.
  - The bootstrap marks `%Admin_Secure` and `%Manager` privileged and `%DB_USER`/`%Developer` not.
- `src/OcuPilot/Test/RoleDelete.cls` -- new, fixture-based:
  - `ROLE.NAME.SYSTEM`, `OCUPILOTROLE` for each of the four names, and `LASTALLHOLDER` through the seam.
  - The removal rows, and a moved `Resources` refused `TARGETCHANGED`.
  - `VERIFIEDDELETES` through a port subclass whose re-read answers present.
- `src/OcuPilot/Test/RoleWire.cls` -- new, armed (`ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS"`, added to `scripts/ci-throwaway.sh` :204-205), on the throwaway:
  - `POST /roles` creates a probe role whose `GET` reads back the sent grants.
  - A second `POST` with another spelling is `ROLE.NAME.TAKEN`.
  - `permissions.roles.delete` minted and confirmed through the real port leaves `Exists` 0.
  - Cleanup by exact probe name.
- `ui/src/app/areas/permissions/role-create-form.store.spec.ts` and `role-grant-dialog.spec.ts` -- new, on the 8.2 harness.
- `ui/browser/roles-create.browser-spec.mjs` -- new: field order, the dialog's current/resulting lines on add, edit and remove, the pre-marks against `privilegeSentence()`, Save opens the editor, the list's Create.
- Update the rosters that redden:
  - `ui/tools/navigation.test.mjs` :130-178, :248-264, :937-962;
  - `Test/PermissionsLists.cls` :141-142;
  - `Test/Wire.cls` :537 and `WireSecurityRead` :784/:830/:858;
  - ⚠ `Test/{SurfaceCoverage,EndpointCoverage,ReadTool,ToolRoundTrip,Prohibited,ToolWrite,PortFixture,Descriptor}.cls`, using the anchors in the Contention note. `ToolWrite` :810-811, which asserts no `DELETE` pair, is the same assertion Epic 7 rewrites.

### Acceptance Criteria

- **AC1.** Given the Roles list's Create, when the form renders, then it captures name, description, resources and granted roles, in that order, under the `form-page` contract.
- **AC2.** Given a resource grant, when it is added, edited or removed in its dialog, then:
  - the grant is a resource plus only the permissions that resource admits;
  - the dialog shows the current grant and the resulting grant before Confirm applies it.
- **AC3.** Given `permissions.roles.delete`, when the agent proposes deleting a role and the user confirms, then:
  - the role is gone on the instance, the write is marked, and a `deleted` event is published;
  - a `%`-prefixed role, OcuPilot's own role, or the last counted `%All` holder's path is refused;
  - a vendor 2xx that did not delete fails `PORT.NOTAPPLIED`.
  - The Roles-list row action with its holder count and typed name is Story 9.3's (DW-1513, orchestrator ruling 2026-09-23; `epics.md` 8.3 AC3 is marked `[AMENDED]`).
- **AC4.** Given a grant that would add `%All`, an `%Admin_*` resource or WRITE on `%DB_IRISSECURITY` to the role, or a granted role that escalates, when saved by either caller, then the instance refuses it:
  - on the screen, the server's sentence lands on the field it concerns;
  - the pickers pre-mark those choices with the same sentence.
- **AC5 (Integration).** Given a valid Save, when the server accepts it, then:
  - the role exists with the sent grants;
  - the route becomes `permissions/roles/edit/<id>`;
  - `STRINGS.formSaved` shows;
  - the Roles list, the change bus's consumer, shows the role without a refresh.
- **AC6.** Given `permissions.roles.create`, when the agent proposes a role and the user confirms, then the write is marked, a ledger row names the sent fields, and a `created` event is published.

## Spec Change Log

- 2026-09-23, spec gate (orchestrator rulings): AC3's screen row action moved to Story 9.3 as DW-1513; `%DB_IRISSECURITY:W` joins the escalation predicate (DW-1512 in part; AD-10 amended); the predicate was checked to decide by effect, not by name (Design Notes). Status reset to `ready-for-dev` without a re-plan.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-12, AD-13, AD-14, AD-15, AD-16, AD-19, AD-27, AD-34, AD-36, AD-39, AD-40, AD-41, AD-51, AD-52, AD-54, AD-55. Epic 7's AD-53 governs the pending row action.

### What the instance settled

These facts were read on `ocupilot-slot-b` from `%SYS`.

- `%Api.Admin.Endpoints.Security.Role` implements `LIST`, `GET`, `PUT`, `DELETE` and `OWNERLIST` (type 10), with `name` as the id. `ResourcesOR` is `%Admin_Secure`.
- `PutRequestBodySchema` is `{Description, GrantedRoles:["%All"], EscalationOnly, Resources:[{Name, Permissions:"RU"}]}`.
  - The validator refuses unknown keys, `Name` among them.
  - It checks only element 0 of each array.
  - It never checks permission letters.
- `RunPut` calls `Modify` on an existing role, otherwise `Create` → 201. `GET` answers without `Name`, and 404 when absent.
- `RunDelete` is 404 when absent. It then calls `DropUser(name,"ROLE")`, which always returns `$$$OK`.
- `Security.Roles`:
  - A name is at most 64 characters, holds no `,` or `:`, and begins with `%` only for a predefined role.
  - A description is at most 256 characters.
  - A name is compared case-insensitively.
  - Deleting a role removes it from its holders.
- The classic `%CSP.UI.Portal.Role` create orders its fields Name, Description, Escalation Only, then resources. It sets granted roles on a later tab, and its list refuses Delete for 19 `%` names.
- The resource dialogs are `RoleResourceNew`/`RoleResourceEdit`.

### Escalation predicate, stated

It is the one `Prohibited.RoleEscalates`/`IsPrivilegedRole` already apply to users (8.2), reused unchanged:

- a resource named `%All` or beginning `%Admin_`, at any permission;
- a role that is, recurses to, or carries one.

On this build every stock role that also writes a system database (`%Manager`, `%Operator`, `%SecurityAdministrator`) is already refused through its `%Admin_*` resources. Only the implicit `%DB_IRISSYS`, `%DB_IRISSECURITY`, `%DB_IRISLIB` and `%DB_IRISAUDIT` roles, and `%DB_*` write grants themselves, pass.

**Ruled 2026-09-23 (DW-1512, in part):** WRITE on `%DB_IRISSECURITY` joins AD-10's set (written into AD-10's Rule). WRITE on `%DB_IRISSYS` and `%DB_IRISLIB` stays decision-pending for the owner; measured, widening would newly refuse only the `%DB_IRISSYS` and `%DB_IRISLIB` roles themselves, since `%Operator`, `%Manager` and `%SecurityAdministrator` are already refused through their `%Admin_*` resources.

**The predicate decides by effect, not by name (checked 2026-09-23 on `ocupilot-b-ci`).** `RoleEscalates` reads `GetRecursedRoleSet` and each recursed role's resources: `%HS_Administrator` recurses to `%Developer,%HS_Administrator,%HS_CCR_Deployer,%Manager` and escalates through `%Manager`'s `%Admin_Secure:U`; `%Manager`, `%SecurityAdministrator` and `%Operator` escalate by resource; `%Developer` and `%SQL` do not. No fix is needed.

### Delete refusals

- AD-10 names deleting OcuPilot's own role and removing the last `%All` holder.
- The `%` rule is a tool rule rather than a prohibition. It exists because the vendor endpoint can drop a predefined role and still report success, and the classic list refuses the same names.
- A role that does not reach `%All` cannot change who holds `%All`, so the census runs only for one that does.

### Deferred to Story 9.3 (DW-1513): the Roles-list row action

Under the lead's ruling, the holder count is the number of distinct `User` and `User (escalation)` rows in `Security.Role` `OWNERLIST`. This is direct holders; nested grants are not expanded, as on the classic Members tab. The confirm also needs a Fixed strings row carrying `<n>`, and `screen-action-handler.ts`'s fixed confirmation text needs a count slot, which 9.3 plans.

**Known carry-over:** DW-1493 (the agent's create sends the folded name). DW-1502 covers publishing `OCUPILOTROLE`'s sentence, as it covers `PRIVILEGEGRANT`'s.

**Consumes:** Story 8.2's `UserCreateRules.Roles`, the escalation predicate and its sentence, the form shape and the `form-page` contract. Story 8.1's create kind and `CreateFixture` seam. AD-51's action-style write and 5.13's `ErrorDelete`.

**Consumed-by:**

- Story 9.3 takes over `permissions/roles/edit/:id` and reuses the grant dialog and `RoleCreateRules`.
- Story 8.4 may reuse `ResourceGrantsAdministrativePrivilege`.
- Story 9.3 (DW-1513) puts the Roles-list row action on `permissions.roles.delete`.

**Integration ACs:** AC5 (the Roles list re-reads on the change bus) and AC3 (the confirmed delete's `deleted` event reaches the same list).

## Verification

Stateful checks run on slot B's throwaway `ocupilot-b-ci` (web 52777, super 1976). When a fresh one is needed: `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`. This story creates and deletes real roles, so nothing stateful runs against `ocupilot-slot-b`. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Run one test class per call, and wait for each run to land before the next.

### Targeted (loop)

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/roles-create.browser-spec.mjs browser/users-create.browser-spec.mjs` -- expected: all pass.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>`, one class per call -- expected: 0 failures each. Run it for `OcuPilot.Test.RoleCreate`, `RoleDelete`, `RoleWire`, `UserCreate`, `Prohibited`, `ProhibitedRoute`, `ToolWrite`, `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `PermissionsLists`, `Descriptor`, `Wire`, `WireSecurityRead` and `DerivedFields`.
- `cd ui && npm run test:tools && npm run test:components` -- expected: 0 failures.
- `cd ui && node tools/field-lists.mjs --check && node tools/screen-mirror.mjs --check && node tools/client-lint.mjs && node tools/browser-reset.mjs` -- expected: no drift.
- `uv run scripts/check-objectscript.py <changed paths>` and `bash scripts/lint-docs.sh` -- expected: clean.

### Once, before `dev_complete`

- The full ObjectScript sweep on a throwaway brought up after the last edit, one class at a time, with the totals checked against `%UnitTest_Result` -- expected: 0 failures, non-zero count.
- `cd ui && npm run build && npm test` -- expected: green.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: all pass, non-zero count.
- The full browser suite is **not** run locally. CI's `browser` job runs it on a fresh throwaway (Rule 29; DW-1447).

### Pinning tests and mutations (Rule 19; the implementer records what was observed)

| AC | Pinning test | Mutation |
|---|---|---|
| AC1 | `roles-create.browser-spec.mjs` field-order leg | Swap Description and Resources in the page |
| AC2 | `role-grant-dialog.spec.ts` current/resulting test; the browser edit leg | Render the resulting grant in the current line |
| AC3 | `RoleDelete.cls` refusal and verified-delete tests; `RoleWire` delete leg | Drop the `Role` branch's delete step; empty `VERIFIEDDELETES` |
| AC4 | `RoleCreate.cls` both-callers escalation test | Remove the `role` step from `Prohibited.Created` |
| AC4 (DW-1512) | `RoleCreate.cls` `%DB_IRISSECURITY:W` leg; `UserCreate.cls` `%DB_IRISSECURITY` role leg | Drop the `%DB_IRISSECURITY` write clause |
| AC5 | `role-create-form.store.spec.ts` change-event test | Drop the `publishCreated()` call |
| AC6 | `RoleCreate.cls` confirm test; `RoleWire` create leg | Set `CREATES` to 0 on `RoleCreate` |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned; the AC3 intent gap was ruled by the orchestrator (the row action moves to Story 9.3 as DW-1513) and the lead added the `%DB_IRISSECURITY:W` clause (DW-1512) at the spec gate.
