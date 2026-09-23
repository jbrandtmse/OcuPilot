---
title: 'Story 8.3: Create a role, and manage its resource grants'
type: 'feature'
created: '2026-09-22'
status: 'done'
baseline_revision: 'f1783ea2bde538a990d7f610936d8859a6876e79'
baseline_commit: 'a7c155e7e20fa7119e38682817ab58ae964b5497'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-2-create-a-user.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A user update's role delta that grants privilege, and any EscalationRoles change, is still
      refused PROHIBITED.PRIVILEGEGRANT by Prohibited.User, whose sentence now names OcuPilot's own
      web applications; AD-10 as amended permits the delta, and the create path grants it.
    evidence: |-
      Prohibited.cls User predicate unchanged; Test/UserUpdate.cls (Epic 7's, not contended) asserts
      the refusal, so the fix needs that file. The mint marks such an update destructive before the
      confirm refuses it (inference).
    location: >-
      src/OcuPilot/Kernel/Proposal/Prohibited.cls (User)
    severity: medium
  - summary: >-
      Doc comments in Epic 7's files still say privilege is refused through any path.
    evidence: |-
      Screen/Tool/WebAppUpdate.cls:26, Screen/Tool/Classification.cls:28, Test/UserUpdate.cls:23
      (all in Epic 7's diff, not contended).
    location: >-
      src/OcuPilot/Screen/Tool/WebAppUpdate.cls:26
    severity: low
  - summary: >-
      AD-54's last paragraph still says setting application roles on any web application stays
      prohibited on both paths, against AD-10 as amended 2026-09-23.
    evidence: |-
      ARCHITECTURE-SPINE.md AD-54 final paragraph; AD-10's "Granting application roles on
      OcuPilot's own web applications" bullet.
    location: >-
      _bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md (AD-54)
    severity: low
  - summary: >-
      Mint.ConsequenceOf now asks Consequence(payload, privileged); a later tool overriding
      Consequence with one formal raises <PARAMETER>, which the catch turns into no consequence.
    evidence: |-
      Only WebAppCreate declares Consequence today, with both formals; the call is in a Try that
      answers "" on any error.
    location: >-
      src/OcuPilot/Kernel/Proposal/Mint.cls (ConsequenceOf)
    severity: low
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

### Owner reversal 2026-09-23: privilege grants are permitted at the strongest confirmation (rework scope)

Two owner decisions supersede this spec's escalation refusals, 8.2's AC3 refusal and 8.1's `MatchRoles` refusal: "I want to be able to grant those other roles, so grant %All" and "Web applications should allow %All as well, remember this is a developer tool first". AD-10 is amended (the lead wrote it): the only grant still prohibited is an application role (`MatchRoles`, `Roles`) on **OcuPilot's own** web applications. Vendor verified by the lead on `ocupilot-b-ci` through `AdminPort.Invoke`: `Security.User` POST with `Roles:["%All"]` answered 201 and stored `%All`; `WebApp.App` PUT with `MatchRoles:[{MatchRole:"",TargetRoles:["%All"]}]` answered 201 and stored `:%All`; both probes deleted. Work these items; the rest of the story stands.

- [x] [Lead] **Prohibited set.** Remove the privilege-grant refusal for users (8.2's `user` step), roles (this story's `role` step's escalation legs) and application roles on any web application that is not OcuPilot's own. `PROHIBITED.PRIVILEGEGRANT` now refuses exactly `MatchRoles`/`Roles` on a web application that is OcuPilot's own (the API, the static application, and any other application the installer creates -- reuse the existing identity of OcuPilot's own applications, `ServesOcuPilot`/`UnderOcuPilot` or the installer roster, never a transcribed list), on create and change alike; reword `ReasonFor(PRIVILEGEGRANT)` to exactly that case, caller-neutral. Remove the `%DB_IRISSECURITY:W` clause (`ResourceGrantEscalates`' DB leg) -- DW-1512 is moot. The role-delete refusals (`ROLE.NAME.SYSTEM`, `OCUPILOTROLE`, `LASTALLHOLDER`) stay. Do not touch the account protections (current user, `_SYSTEM`, service account, last `%All` holder -- Epic 7's). `Prohibited.cls` is contended: `git fetch origin`, read `git show origin/OCU-1-epic7:src/OcuPilot/Kernel/Proposal/Prohibited.cls` first, stay off its hunks.
- [x] [Lead] **One classifier, kept.** `RoleEscalates`/`RoleGrantsAdministrativePrivilege` (by effect: the role, the roles it recurses to, their resources) and the `%All`/`%Admin_*` resource test stay, no longer as refusals but as the one answer to "is this grant privileged?", asked by the kernel (agent path) and by the bootstrap reads (screen path), so the two cannot drift.
- [x] [Lead] **Agent path: the strongest confirmation.** A proposal whose payload grants a privileged role (a user's `Roles`, a role's `GrantedRoles`), an escalating resource (a role's `Resources`) or a privileged application role (`MatchRoles`/`Roles` on a web application) is confirmed as a delete is: the mint marks **that proposal** destructive (the kernel computes it from the payload with the classifier, OR'd with the tool's own `destructive` declaration), so the card draws the destructive treatment now and Story 14.7's typed-name field applies to it from one place. Its server-computed diff names the privilege: the proposal's `consequence` (8.2's column) carries a code for the privileged grant, rendered as `STRINGS.privilegedGrantEffect`; a web-application create that is both unauthenticated and granted a privileged application role carries one combined code rendered as `STRINGS.privilegedGrantEffectUnauthenticated`, never two lines. Pin both: a test that fails when the per-proposal destructive marking is removed, and one that fails when the consequence is removed.
- [x] [Lead] **Screen path: a consequence line, never a refusal.** The user form's Roles fieldset, this story's GrantedRoles and Resources fields and its grant dialog show `STRINGS.privilegedGrantEffect` at the field while a privileged choice is selected, from the bootstrap reads' `privileged` flags; privileged choices are no longer disabled. The web-application create form gains an **Application roles** control (a role checkbox fieldset reusing 8.2's roles bootstrap shape, sent as `MatchRoles: [{MatchRole:"", TargetRoles:[...]}]`) placed after the authentication methods; while a privileged role is checked it shows `privilegedGrantEffect`, or `privilegedGrantEffectUnauthenticated` instead of both it and `webAppUnauthenticatedEffect` when Unauthenticated is also checked. The screen's Save then applies the grant (AD-55: same tool, same prohibited set).
- [x] [Lead] **8.1's tool admits `MatchRoles`.** `WebAppCreate`: remove `MatchRoles` from `ExcludedFields` and add it to `PERMITTEDFIELDS`; `Prohibited.PermittedCreateFields("web-application")` gains it and `AlwaysProhibitedCreateFields("web-application")` loses it; regenerate `ToolFields.cls` if its classification changes (`MatchRoles[].*` rows are already derived). The update tool (`webapp.list.update`) keeps its admitted field list; its change-path `AlwaysProhibitedFields` loses `MatchRoles` except on OcuPilot's own applications, so the prohibition means what AD-10 now says.
- [x] [Lead] **Strings.** Append `privilegedGrantEffect` and `privilegedGrantEffectUnauthenticated` to `strings.ts` (the key family is this story's; Epic 7 ports it byte-for-byte) with matching EXPERIENCE.md Fixed-strings rows (tier-1). Meaning, in plain words: the first says the grant gives `%All` or an administrative privilege and whoever holds it can administer this instance; the second says anyone who reaches this application, without signing in, runs with that privilege -- with `%All`, full control of the instance.
- [x] [Lead] **DW-1514 (LOW, two-way door).** In the grant dialog, ticking Write on a database resource ticks and locks Read, as the classic `RoleResourceEdit` does (`writeChanged`); `RoleCreateRules` refuses a Write-only database grant on both callers with a field sentence. One test each side.
- [x] [Lead] **Tests rewritten, not deleted.** Every test that asserted a privilege-grant refusal (8.2's `UserCreate` both-callers test and picker pre-mark, this story's `RoleCreate` escalation legs, the `%DB_IRISSECURITY` legs, 8.1's `MatchRoles` refusal in `WebAppCreate`/`ProposalCreate`/`Prohibited`/`ToolWrite` and the browser specs) now asserts the new terms: the grant is proposable, its proposal is destructive and names the privilege, it applies on the throwaway once confirmed, and on the screen the consequence line appears. Keep a test that fails when OcuPilot's own applications stop being refused (both callers). Update every `mutation:` row these touch.

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
- **AC4.** [AMENDED 2026-09-23, owner decision: privilege grants permitted at typed confirmation; was "the instance refuses it"] Given a grant that would add `%All` or an `%Admin_*` resource to the role, or a granted role that carries one, when saved by either caller, then it is permitted at the strongest confirmation: the agent's proposal is destructive and names the privilege; on the screen `privilegedGrantEffect` shows at the field and in the grant dialog. Only application roles on OcuPilot's own web applications are refused (AC7). The two lines below are superseded:
  - on the screen, the server's sentence lands on the field it concerns;
  - the pickers pre-mark those choices with the same sentence.
- **AC5 (Integration).** Given a valid Save, when the server accepts it, then:
  - the role exists with the sent grants;
  - the route becomes `permissions/roles/edit/<id>`;
  - `STRINGS.formSaved` shows;
  - the Roles list, the change bus's consumer, shows the role without a refresh.
- **AC6.** Given `permissions.roles.create`, when the agent proposes a role and the user confirms, then the write is marked, a ledger row names the sent fields, and a `created` event is published.
- **AC7.** [owner decision 2026-09-23: developer tool first] Given a web-application create through either caller with `MatchRoles` naming a privileged role, then it is permitted at the strongest confirmation (agent: destructive, diff names the privilege; screen: the Application roles control shows `privilegedGrantEffect`, or `privilegedGrantEffectUnauthenticated` when Unauthenticated is also chosen); on one of OcuPilot's own web applications, application roles are refused `PROHIBITED.PRIVILEGEGRANT` on both callers.

### Review Findings

Code review 2026-09-23 (first review of the story; both code commits, `a7c155e..HEAD`). Tier `full-opus`, four layers.

- [x] [Review][Patch] Mint's privileged-grant check against the target it changes (update, delete) is unpinned [src/OcuPilot/Test/RoleDelete.cls] -- added `TestDeletingAPrivilegedRoleNamesNoGrant`
- [x] [Review][Patch] Role form reset at sign-out is untested [ui/src/app/app.spec.ts] -- role-store legs added to the sign-out test
- [x] [Review][Patch] `USEONLYPREFIXES` is unpinned against the vendor's prefixes [src/OcuPilot/Test/RoleCreate.cls] -- added `TestTheAdmittedLettersFollowTheVendorsPrefixes` over `%sySecurity.inc`
- [x] [Review][Patch] The Resources consequence line and the dialog's edit-mode consequence reach no `aria-describedby` [ui/src/app/areas/permissions/role-create-form.page.ts, role-grant-dialog.ts] -- wired; dialog spec and browser AC4 leg assert it
- [x] [Review][Patch] Stale doc comments say privileged choices are disabled or refused [role-create-form.page.ts, user-create-form.page.ts, src/OcuPilot/Test/RoleWire.cls:3]
- [x] [Review][Patch] DW-1526: `Mint.ConsequenceOf` swallowed an arity error [src/OcuPilot/Kernel/Proposal/Mint.cls] -- asks only a compiled `Consequence`, unguarded; a one-formal probe tool now fails the mint 500 `<PARAMETER>`
- [x] [Review][Defer] A user update still refuses a privileged role delta with the web-application sentence, after the mint marks it destructive [src/OcuPilot/Kernel/Proposal/Prohibited.cls (User)] -- deferred: DW-1524, escalated for the merge gate (confirmed by three layers)
- [x] [Review][Defer] Agent create posts the folded name [src/OcuPilot/Kernel/EntityRef.cls:59] -- deferred: DW-1493, escalated

Rejected:

- `%DB_IRISSECURITY:W` is not marked privileged -- by-design: the reversal work list removes that leg and keeps the classifier at `%All`/`%Admin_*` (DW-1512 moot); reopens only by amending AD-10's classifier
- Combined unauthenticated-privileged code when the privileged target roles sit under a non-empty `MatchRole` -- low: agent-only, and the card over-warns rather than under-warns
- `GET /roles/name` skips the name's own rules -- low: 8.2's shape (blur answers `TAKEN` only, per the matrix), and Save carries the rule; bad names read 404, never 500
- `GrantedRoles` has no duplicate rule -- low: the screen cannot produce one, and the fix is a new code
- Lower-case or unordered permission letters sent raw -- false: probed, the vendor stores `%DB_USER:wr` as `%DB_USER:RW`
- A non-string `Description` is accepted -- low: 8.2's `IsScalar` precedent; the vendor stores the literal as text
- `MatchRoles` entries with empty `TargetRoles` or a repeated `MatchRole` -- low: rare, and the fix adds branches
- The role delete predicates are skipped when `WriteTypeOf` answers `""` -- wontfix-theoretical: `Target()` resolves the tool class and every role write tool declares `WRITETYPE`; real only if a role write resolves no class
- The `%` refusal lives only at the mint -- false: a tool rule by spec; already ruled in the first pass
- An unticked privileged role is described by the consequence line -- low: describing an option's consequence is correct information
- Case-insensitive prefixes differ from the vendor -- false: deliberate and documented
- A copy of OcuPilot's API at another path can take `%All` -- by-design: AD-10 as amended keys the refusal to the installer's applications
- Strongest confirmation is one click until Story 14.7 -- by-design: the typed-name field is 14.7's, reading the flag this story pins
- `PRIVILEGEGRANT`'s sentence misstates a create under OcuPilot's path -- false: an application under that path answers OcuPilot's requests
- A proposal certain to be refused is minted -- by-design: AD-10 evaluates at the write inside AD-34, pinned by `ProposalCreate`
- No guard on deleting the caller's own access role -- by-design: AD-10's set is closed; the last-`%All`-holder census covers the unrecoverable case
- `PORT.NOTAPPLIED` also answers a failed re-read -- low: deliberate fail-closed in `VerifyGone`, rare
- A role name equal to a user name is a banner, not a field error -- low: mirror of DW-1504 (`wontfix-accepted`), occurrence appended
- Edit button and legend reuse other keys -- by-design: the spec mandates the reuse
- The spec still defers AD-54's paragraph, which this diff amends -- rejected: the fix edits the spec under review (lead's bookkeeping)
- `Classification.cls` keeps `MatchRoles` `secret` -- low: `Disclosure` renders unchanged rows only and a create has none; the doc is already deferred (Epic 7's file)

## Spec Change Log

- 2026-09-23, lead (owner reversal, rework iteration 1): privilege grants permitted at the strongest confirmation; only application roles on OcuPilot's own web applications stay refused; `%DB_IRISSECURITY:W` clause dropped (DW-1512 moot); 8.1's `MatchRoles` refusal removed inside this story. Work list under `### Owner reversal 2026-09-23`; AC4 amended, AC7 added.

- 2026-09-23, spec gate (orchestrator rulings): AC3's screen row action moved to Story 9.3 as DW-1513; `%DB_IRISSECURITY:W` joins the escalation predicate (DW-1512 in part; AD-10 amended); the predicate was checked to decide by effect, not by name (Design Notes). Status reset to `ready-for-dev` without a re-plan.
- 2026-09-23, implement (Rule 5 apply-and-report): `Classification.cls` classifies `Resources[].Name` and `Resources[].Permissions` `ordinary` rather than `Resources` `opaque`, because `field-lists.mjs` refuses to classify a member that has member rows; `Resources` stays the tool's authored argument, so the schema and payload are unchanged.

## Review Triage Log

### 2026-09-23 — Review pass

- verdicts: 16 findings — high 0, medium 3, low 6, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` Role-delete census never runs a kept holder or a nested-only holder (verification-gap) — added `RoleWire.TestTheDeleteCensusCountsOnlyHoldersThatLoseAllThroughTheRole` over real probe roles and account with `ArmAllHolders`; both directions observed red (runs 194, 196)
  - `[low]` `[patch]` Real-port delete tested only with a lower-case name (verification-gap) — vendor drop is case-insensitive (probed); `RoleWire.DELETEPROBE` is now `OcuPilotProbeRoleDelete`, green (run 192)
  - `[medium]` `[patch]` No screen test for a top-level `EscalationOnly` (verification-gap) — screen leg added to `TestAnEscalatingGrantIsRefusedOnBothCallers`, observed red (run 198)
  - `[low]` `[patch]` AC5 store test compares the event type with the store's own constant (verification-gap) — asserts `'role'` and the Roles list's declared `entityType`; mutation observed red
  - `[false]` `[reject]` `TestEveryRoleFieldCodeCarriesItsOwnSentence` reason assertion cannot fail — it fails if `Rules()` stops drawing its sentences from `ReasonForViolation`
  - `[false]` `[reject]` Store test key computed with `entityRefKey` — the event key equal to the bus's canonical key is the contract; the fold rule is pinned in `entity-ref.test.mjs`
  - `[low]` `[patch]` AC6's recorded mutation stops before the ledger assertions — `mutation:` line added (run 197)
  - `[low]` `[reject]` Per-letter pre-mark fails open when `privilegedPermissions` is absent — `RoleCreateRules.Resources` sets it on every row and the server refuses the grant at Save; the fix adds a branch for a state the server never ships
  - `[medium]` `[defer]` Agent's role create sends the folded name (intent-alignment a) — occurrence of DW-1493, which the spec carries as known and the lead keeps escalated (`Confirm.cls` not edited); deferred with the delete probed unaffected
  - `[low]` `[reject]` Screen create's name check and `PUT` are not atomic (intent-alignment b) — the same `Taken`-then-`PUT` shape as 8.1's web-application create; two creates of one name inside one request's window, and the fix is a lock
  - `[false]` `[reject]` `%` refusal only at the mint (intent-alignment c) — the spec makes it a tool rule, not a prohibition, and proposals are only server-minted; the screen caller is Story 9.3's (DW-1513)
  - `[medium]` `[patch]` Census positive verdict on a reachable role never exercised (intent-alignment d) — same root and patch as the first row
  - `[low]` `[reject]` `PORT.NOTAPPLIED` not carried through Confirm to the row (intent-alignment e) — the port fault is pinned in `RoleDelete`; a failed write's closure is `ProposalConfirm.TestAFailedWriteLeavesTheProposalBurned`'s, unchanged
  - `[false]` `[reject]` A custom granted role that escalates is untested (intent-alignment f) — the role step asks 8.2's `GrantsPrivilege`/`RoleEscalates`, whose recursion `UserCreateWire` pins with a nested role
  - `[medium]` `[patch]` Screen `EscalationOnly` rests on inference (intent-alignment g) — same root and patch as the third row
  - `[false]` `[reject]` Changes beyond the named surface (intent-alignment h) — each is spec-mandated (`role:foldcase`, `VERIFIEDDELETES`, roster rows) or required by a matrix row (`Mint` asks `ArgumentProblem` of every tool for `ROLE.NAME.SYSTEM`'s 400)

### 2026-09-23 — Review pass (rework iteration 1, owner reversal)

- verdicts: 14 findings — high 0, medium 4, low 4, false 6, maybe-false 0
- findings:
  - `[medium]` `[patch]` `WEBAPP.MATCHROLES.SHAPE`/`.UNKNOWN` untested on either caller (verification-gap) — added `WebAppCreate.TestTheApplicationRoleRulesRefuseOnBothCallers`, three cases on both callers; observed red with the rule call removed (run 241)
  - `[medium]` `[patch]` The web-application form read's `roles` marks are unpinned (verification-gap) — added `WebAppCreate.TestTheFormReadMarksThePrivilegedApplicationRoles` (`%All`, `%Manager` 1, `%Developer` 0); observed red with every role marked (run 241)
  - `[low]` `[patch]` The two consequence codes are pinned only against the client's own literals (verification-gap) — `ProposalCreate` asserts both literals; observed red with the code renamed (run 242)
  - `[low]` `[patch]` AC7's combined line has no observed mutation (verification-gap) — both page mutations applied on rebuilt, redeployed bundles and observed red on the browser AC7 leg; `mutation:` line written
  - `[medium]` `[defer]` A user update's privileged role delta or `EscalationRoles` change is still refused `PRIVILEGEGRANT`, whose sentence now names OcuPilot's own web applications (verification-gap other) — the fix edits `Test/UserUpdate.cls`, Epic 7's file, which asserts the refusal; deferred for the lead
  - `[low]` `[reject]` The create branch of `Prohibited.TestNoWriteToolAdmitsAnAlwaysProhibitedField` loops zero times (verification-gap other) — explicit `""` assertions on `AlwaysProhibitedCreateFields` pin the emptiness; removing the method touches the contended `Prohibited.cls` for no user-reachable harm
  - `[low]` `[reject]` `GrantsPrivilegeByEffect`'s error path is untested (verification-gap other) — it fails closed (no proposal is minted); a `%SYS` role read failing is not reachable in everyday use, and a seam to force it adds surface
  - `[medium]` `[defer]` The user update surface: mint marks destructive, confirm refuses with a web-application sentence (intent-alignment a) — same root and route as the user-update row above
  - `[false]` `[reject]` A web-application change refuses `MatchRoles` as `UNCOVEREDFIELD` off OcuPilot's own applications (intent-alignment b) — the reversal's `MatchRoles` item keeps the update tool's admitted field list; by design
  - `[false]` `[reject]` The consequence names the category, not the specific role (intent-alignment c) — the reversal specifies the `consequence` code rendered as `privilegedGrantEffect`; the diff rows already name each granted role
  - `[false]` `[reject]` The typed-name half of "confirmed as a delete is" is not exercised (intent-alignment d) — Story 14.7's, reading the per-proposal flag this pass pins
  - `[false]` `[reject]` The own-application change refusal is exercised only as a predicate test (intent-alignment e) — no caller can author `MatchRoles` on a change (the update tool's schema), so the predicate is the reachable surface; the create half is pinned on both callers
  - `[false]` `[reject]` The screen's consequence line is computed client-side (intent-alignment f) — AD-10 asks for a line at the field from the one classifier; the flags are server-computed and pinned in `RoleCreate`, `UserCreateWire` and `WebAppCreate`
  - `[false]` `[reject]` The dialog detects a database by `permissions === 'RW'` (intent-alignment g) — `AdmissiblePermissions` answers `RW` exactly for `IsDatabaseResource` names (`U` for Use-only prefixes, `RWU` otherwise), so the test is equivalent

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
| AC4 | `RoleCreate`/`UserCreate`/`ProposalCreate` privileged-grant tests; `RoleWire` real-port create; the dialog and browser AC4/AC3 legs | Drop `tPrivileged` from the mint's destructive value; drop the privileged consequence; make the page's or dialog's consequence flag false |
| AC7 | `WebAppCreate` screen refusal and `ProposalCreate` in-transition refusal at OcuPilot's own path; `WebAppWire`; `Prohibited` create and change legs; browser AC7 | Stop refusing application roles at OcuPilot's own path; drop the change path's own-application leg; make the page's application-role flag false |
| AC5 | `role-create-form.store.spec.ts` change-event test | Drop the `publishCreated()` call |
| AC6 | `RoleCreate.cls` confirm test; `RoleWire` create leg | Set `CREATES` to 0 on `RoleCreate` |

Observed (implement stage; each applied to the checked-in file, loaded with `cbk` (subclasses recompiled) or rebuilt and redeployed, observed red, reverted from a byte copy and reloaded):

- mutation: `tPrivileged` dropped from the mint's destructive value -> `ProposalCreate.TestAPrivilegedApplicationRoleIsMintedDestructiveAndNamed` (rework run 217), `UserCreate.TestAPrivilegedRoleIsGrantedAtTheStrongestConfirmationOnBothCallers` (rework run 218), `RoleCreate.TestAPrivilegedGrantIsGrantedAtTheStrongestConfirmationOnBothCallers` (rework run 219) and `RoleWire.TestAPrivilegedCreateConfirmedThroughTheRealPortIsApplied` (rework run 220) red
- mutation: `Mint.ConsequenceOf`'s privileged fallback removed -> `ProposalCreate` case 1 consequence red (rework run 221); `UserCreate` `%All` and `%Manager` consequence legs red (rework run 222)
- mutation: `WebAppCreate.Consequence` ignores `pPrivileged` -> `ProposalCreate` case 2 (the combined code) red (rework run 229)
- mutation: `Prohibited.Created` stops refusing application roles at OcuPilot's own path -> `WebAppCreate.TestTheScreenSaveRefusesAProhibitedCreateBeforeThePortIsTouched` (screen, rework run 223), `ProposalCreate.TestApplicationRolesOnOcuPilotsOwnPathAreRefusedInsideTheTransition` (agent, rework run 224), `WebAppWire.TestTheCreateAnswersOneEnvelopeForEachOutcome` (rework run 225) and `Prohibited.TestACreateIsRefusedAtOcuPilotsOwnPathForRolesAndForAnUnreviewedField` (rework run 226) red
- mutation: `Prohibited.WebApplication`'s own-application roles leg dropped -> `Prohibited.TestAChangedRoleGrantIsRefusedOnOcuPilotsOwnApplication` red (rework run 227)
- mutation: `RoleCreateRules`' write-only rule removed -> `RoleCreate.TestEveryFieldRuleRefusesOnBothCallers` red on case 14 (rework run 228)
- mutation: `MATCHROLESARGUMENT` dropped from `WebAppCreate.SettableFields` -> `WebAppCreate.TestTheToolAdvertisesTheReviewedCreateFieldsAndApplicationRoles` and the one-body test red (rework run 230)
- mutation (one client pass, each reddening its own): the dialog's `writeChanged` line dropped -> `role-grant-dialog.spec.ts` DW-1514 red; `showEffect` false -> its AC4 red; `CONSEQUENCE_PRIVILEGED` branch dropped from `consequenceSentence` -> `proposal-card.spec.ts` AD-10 and `proposal-view.test.mjs` red; the `MatchRoles` entry dropped from the web-application store's body -> its AC7 red; the privileged early return restored in either store's `setRole` -> the user store's AC3 and the role store's AC4 and AD-54 body tests red
- mutation (one rebuilt, redeployed bundle, each reddening only its own): the user page's `privilegedChecked`, the role page's `privilegedRoleChecked` and the web-application page's `privilegedRoleFlag` answer false -> browser `users-create` AC3, `roles-create` AC4 and `web-applications-create` AC7 red; green again on the reverted bundle (22/22 across the four specs)
- mutation: the `MatchRolesViolation` call removed from `Area.WebApp.Create.Validate` -> `WebAppCreate.TestTheApplicationRoleRulesRefuseOnBothCallers` red on all three cases on both callers; `FormRules.Roles` marks every role privileged -> `WebAppCreate.TestTheFormReadMarksThePrivilegedApplicationRoles` red on `%Developer` (one load, each reddening only its own method, rework run 241)
- mutation: `Mint.CONSEQUENCEPRIVILEGED` `"GRANT.PRIVILEGE"` -> `ProposalCreate.TestAPrivilegedApplicationRoleIsMintedDestructiveAndNamed` red on the literal the card resolves (rework run 242)
- mutation (two rebuilt, redeployed bundles): the web-application page's `unauthenticatedEffect` answers `unauthenticatedFlag` alone -> browser `web-applications-create` AC7 red on "the one combined line replaces the unauthenticated effect"; `privilegeEffect` ignores Unauthenticated -> the same leg red waiting for the combined sentence
- mutation: `Prohibited.Role`'s delete step disabled -> `RoleDelete.TestOcuPilotsOwnRolesAreRefusedAtTheWrite` and `TestTheLastAllHoldersPathIsRefused` red (run 224)
- mutation: `AdminPort.VERIFIEDDELETES` emptied -> `RoleDelete.TestAVendorDeleteThatDidNotApplyFailsNotApplied` red (run 225)
- mutation: `Mint` asks `ArgumentProblem` of creates only (the pre-story condition) -> `RoleDelete.TestASystemRoleIsRefusedAtTheMint` red (run 226)
- mutation: `RoleCreate.CREATES` 0 -> `RoleCreate.TestAConfirmedCreateIsMarkedAndAnswersCreated` red, with four other legs (run 227)
- mutation: `Security.Role/PUT` removed from `AdminPort.MUTATINGTYPES` -> `RoleWire.TestTheCreateMakesTheRoleWithTheSentGrants` red (run 228)
- mutation: `AdminPort.VerifyGone`'s 404 line removed -> `RoleWire.TestTheAgentDeleteThroughTheRealPortRemovesTheRole` red (run 229)
- mutation: `EscalationOnly` added to `RoleCreate.PERMITTEDFIELDS` -> `RoleCreate.TestTheSchemaCarriesNoEscalationOnlyAndThePermittedSetIsTheSets` red (run 230)
- mutation: the duplicate-grant rule removed from `RoleCreateRules.ResourceViolation` -> `RoleCreate.TestEveryFieldRuleRefusesOnBothCallers` red (run 231)
- mutation: `RoleCreate.Perform` composes from a hand-typed list without `Resources` -> `RoleCreate.TestTheScreenAndTheConfirmSendOneBody` red (run 232)
- mutation: `Prohibited.ResourceGrantsAdministrativePrivilege` answers 0 -> `RoleCreate.TestTheBootstrapMarksWhatTheClassifierCallsPrivileged` and the privileged-grant test red (rework run 231)
- mutation: `ROLE.VALIDATION` added to `Error.RoleViolationCodes` -> `RoleCreate.TestEveryRoleFieldCodeCarriesItsOwnSentence` red (run 234)
- mutation: `RoleForm.sideBarPosition` 7 -> `RoleCreate.TestTheFormDescriptorIsBuiltUnlistedAndCarriesTheListsOwnPairs` red (run 235)
- mutation: `Resources` dropped from `RoleDelete.READANSWERS` -> the registration guard refuses the tool; five `RoleDelete` tests red, `TestTheDeleteIsAnActionWriteOverTheScreensOwnPairs` among them (run 236)
- mutation: `Resources` dropped from `RoleDelete.FINGERPRINTSUBJECT` (precondition moved to `Description`, the `StateDiff` check kept on `Resources`) -> `RoleDelete.TestTheRemovalRowsAndAMovedGrantRefusesTheConfirm` red on "a moved grant refuses the confirm" (run 238)
- mutation: `RoleDelete.CHANGEACTION` `updated` -> `RoleDelete.TestAConfirmedDeleteIsMarkedAndSendsNoBody` red (run 239)
- mutation: the Use-only branch removed from `RoleCreateRules.AdmissiblePermissions` -> `RoleWire.TestTheFormReadPublishesTheRulesAndMarksThePrivilegedChoices` red (run 240)
- mutation: `RoleCreate.RenderViolations` renders `USER.VALIDATION` -> `RoleWire.TestEachRouteAnswersOneJsonEnvelopeOverTheWire` red (run 241)
- mutation: `publishCreated()` dropped from `RoleCreateForm.save()` -> `role-create-form.store.spec.ts` change-event test red
- mutation: the dialog's current line renders the resulting grant -> the three AC2 tests of `role-grant-dialog.spec.ts` red; rebuilt and redeployed, `roles-create.browser-spec.mjs` AC2 red
- mutation (one bundle, three legs, each reddening only its own): Description moved after Resources in the page -> browser AC1 field order red; the route replacement dropped from `onSave` -> browser AC5 red; the `RoleActions` injection dropped from `app.ts` -> browser "the Roles list offers Create" red; AC2 stayed green
- mutation: `RoleCreate.CREATES` 0 -> `RoleCreate.TestATakenNameRefusesTheMintAndAConfirmTakenSince` red on its free-name leg (run 190; matrix row "Name taken", mint 400 and confirm 409)
- mutation: `ReachesAllWithout` answers 0 -> `RoleWire.TestTheDeleteCensusCountsOnlyHoldersThatLoseAllThroughTheRole` red on the kept-holder leg (run 194); the deleted role skipped only among the account's direct roles -> the nested-holder leg red (run 196)
- mutation: `RoleCreate.SettableFields` without `Resources` -> `RoleCreate.TestAConfirmedCreateIsMarkedAndAnswersCreated` red on "the ledger names Resources" (run 197; AC6's ledger leg)
- mutation: `RoleCreate.CallerFields` skips `EscalationOnly` -> `RoleCreate.TestAnEscalatingGrantIsRefusedOnBothCallers` red on the screen's `UNCOVEREDFIELD` leg (run 198)
- mutation: `ROLE_ENTITY` `'roles'` -> `role-create-form.store.spec.ts` AC5 change-event test red (now asserted against the literal and the Roles list's declared `entityType`)
- mutation: `RoleForm` dropped from `CREATE_ONLY_FORMS` -> `navigation.test.mjs` create-form and screenForChange tests red
- roster rows: `Prohibited` (covered types, fourteen codes), `AuditingUpdate` (fourteen codes; red in the full sweep, run 23, and green reloaded, run 188), `ToolWrite` (the absent-DELETE assertion, `PortFixture`'s roster), `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `PermissionsLists`, `Wire`, `WireSecurityRead`, `EntityRef`, `entity-ref.test.mjs`, `screen-mirror.test.mjs` and `navigation.test.mjs` were each observed red without this story's rows and green with them
- mutation (code review): the mint measures every write's grant against `{}` -> `RoleDelete.TestDeletingAPrivilegedRoleNamesNoGrant` red alone (run 202); `RoleCreateRules.USEONLYPREFIXES` without `%SQL` -> `RoleCreate.TestTheAdmittedLettersFollowTheVendorsPrefixes` red alone (run 203); `roleCreateForm.reset()` dropped from `app.ts` -> `app.spec.ts` sign-out test red; the dialog's permissions-fieldset `aria-describedby` dropped -> `role-grant-dialog.spec.ts` edit-mode AC4 red; the Resources fieldset given its refusal id alone (rebuilt, redeployed) -> browser `roles-create` AC4 red on "which describes the Resources field", green on the restored bundle (5/5)

## Auto Run Result

Status: done
Blocking condition: none

footprint_extensions: contended `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, `src/OcuPilot/Kernel/Proposal/Mint.cls`, `src/OcuPilot/Test/Prohibited.cls`, `src/OcuPilot/Test/SurfaceCoverage.cls` (8.1's own row edited for a renamed test method, not an append), `src/OcuPilot/Test/ToolWrite.cls` (doc comment), `ui/src/app/core/proposal-view.ts`, `ui/src/app/shell/proposal-card.spec.ts`; shared appends `ui/src/app/core/strings.ts`, EXPERIENCE.md Fixed strings rows 403-405 (rows 398 and 402, 8.2's and 8.3's own, reworded); Epic 8 files outside 8.3's own `src/OcuPilot/Api/Error.cls`, `src/OcuPilot/Area/WebApp/{Create,FormRules}.cls`, `src/OcuPilot/Area/Permissions/{UserCreate,UserCreateRules}.cls`, `src/OcuPilot/Screen/Tool/{WebAppCreate,UserCreate}.cls`, `src/OcuPilot/Test/{WebAppCreate,ProposalCreate,WebAppWire,UserCreate,UserCreateWire}.cls`, `ui/src/app/areas/web-applications/create-form.{page,store,store.spec}.ts`, `ui/src/app/areas/permissions/user-create-form.{page,store,store.spec}.ts`, `ui/browser/{users-create,web-applications-create}.browser-spec.mjs`, `ui/tools/proposal-view.test.mjs`. No file Epic 7 alone modified, and none of the never-edit files, was touched.

### Summary

Owner reversal 2026-09-23 (AD-10 amended): privilege grants are permitted at the strongest confirmation. `PROHIBITED.PRIVILEGEGRANT` now refuses only application roles on OcuPilot's own web applications, on create (ahead of `SERVINGPATH`) and on change, with a reworded sentence; the user and role create refusals and the `%DB_IRISSECURITY:W` clause are gone. `Prohibited.GrantsPrivilegeByEffect` is the one classifier: the mint ORs it into the proposal's `destructive` flag and names it in `consequence` (`GRANT.PRIVILEGED`, or one combined `WEBAPP.UNAUTHENTICATEDPRIVILEGED`); the bootstrap reads mark choices with its per-choice halves. The user, role and web-application forms state `privilegedGrantEffect` (or `privilegedGrantEffectUnauthenticated`) at the field instead of disabling choices; the web-application form and tool gain `MatchRoles` (Application roles). DW-1514: the grant dialog ticks and locks Read with Write on a database, and `ROLE.RESOURCES.WRITEONLY` refuses a Write-only database grant on both callers. `Confirm.cls` untouched.

### Review

Two layers, 14 findings (Review Triage Log, rework pass): 4 patched (medium 2, low 2; all test additions or recorded mutations, each observed red), 2 deferred as one root (medium: the user update path still refuses a privileged role delta with a sentence that now names web applications; the fix needs Epic 7's `Test/UserUpdate.cls`), 8 rejected with reasons logged. Follow-up review recommended: false -- follow-up pass, no high patched (patched: high 0, medium 2, low 2).

### Verification

On a fresh `ocupilot-b-ci` brought up after the last code edit: the full ObjectScript sweep, 187 classes one at a time, 1700/1700 confirmed in `%UnitTest_Result`; smoke 47/47; `roles-create`, `users-create`, `web-applications-create` and `web-applications` browser specs 22/22 on the deployed bundle (initial total 1.16 MB). `npm run build` and `npm test` green (1325 tool tests, 855 component tests); `check-objectscript`, `lint-docs`, `client-lint`, `field-lists --check`, `screen-mirror --check`, `browser-reset` clean. Matrix rows "Escalating resource" and "Escalating granted role" are superseded by amended AC4 and pinned by the privileged-grant tests; the frozen intent block still states the refusal.

### Residual risks

The deferred user-update refusal (medium) until Epic 7 or the merge drops or recodes it; the intent-contract's escalation rows and AD-54's last paragraph still describe the old rule (lead's to amend); single-line merges with Epic 7 on `Prohibited.cls` and the shared-append files.
