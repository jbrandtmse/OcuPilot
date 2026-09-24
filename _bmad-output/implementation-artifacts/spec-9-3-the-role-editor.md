---
title: 'Story 9.3: The role editor'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: 'd6e6e8eb9ed93e8082bda1ecdd7ef75cf5e9d5ee'
baseline_commit: 'd6e6e8eb9ed93e8082bda1ecdd7ef75cf5e9d5ee'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
warnings: ['oversized']
deferred:
  - 'A forced Delete of a predefined role is pinned below the route (RoleDelete.ScreenActionDelta), not over POST /screens/permissions.roles/action: with the refusal missing the vendor drops the role, so a request-level leg would delete a vendor role on the throwaway. A held-port ScreenAction harness would let it be pinned over the route.'
  - 'The census reads a role set escalation-only as reaching nothing for its holders (inference): holders keep the role in Roles, measured on ocupilot-ci; whether a sign-in still grants it was not measured.'
---

<intent-contract>

## Intent

**Problem:** A role can be created (8.3) but not edited. `permissions/roles/edit/<id>` mounts the create page again. The Roles and Resources lists have no Delete row action (DW-1513, DW-1528). `PROHIBITED.UNCOVEREDFIELD`'s sentence names the agent, although a screen Save reaches it too (DW-1598).

**Approach:** Build a tabbed role editor at `permissions/roles/edit/<id>`, following 9.1 and 9.2. Its tabs are the classic page's: **General**, **Members** and **Assigned to**.

- **Save:** `PUT /roles/:id` through a new merge tool, `permissions.roles.update` (AD-55). Save carries `Description` and `EscalationOnly`.
- **Grants and roles:** resource grants and assigned roles change only through AD-53 screen actions on the Roles list. Each is a server-side delta (AD-56 ii), and grants go through 8.3's grant dialog.
- **Members:** account members use the Users list's `add-role`/`remove-role`. Role members use this story's role actions on the member role.
- **Delete row actions:** each list gets Delete through its own delete tool. Role delete states its holder count. A resource the vendor marks undeletable is drawn refused.

## Boundaries & Constraints

**Always:**

- **Save order** follows `UserSave.Update`:
  1. the tool's pair set;
  2. a fresh read, where an absent role is 404 `ROLE.NAME.ABSENT` and nothing is sent;
  3. any body key other than `Description` or `EscalationOnly` is 400 `PORT.FIELD.UNEXPECTED`;
  4. the rules (`RoleCreateRules.Validate`, update mode);
  5. `Mint.Merge` over the complete set (AD-4);
  6. the prohibited set, before any port call;
  7. the send.

  Save publishes one `role`/`updated` event.
- **Agent tool.** `permissions.roles.update` takes `Description` and `EscalationOnly`, plus the authored arguments `GrantedRoles` and `Resources`, as `RoleCreate` does. Each is the complete new value, merged over the fresh read.
  - A privileged grant (`GrantsPrivilegeByEffect`, unchanged) is minted destructive with `GRANT.PRIVILEGED`.
  - A merge with no changed row is 400 `TOOL.ARGUMENTS` (existing Mint rule).
- **Screen actions on `RoleUpdate`:**
  - `SCREENACTIONS` is `add-granted-role`, `remove-granted-role`, `set-resource-grant` and `remove-resource-grant`.
  - `SCREENVALUES` is `add-granted-role=Role`, `remove-granted-role=Role`, `set-resource-grant=Resource:Permissions` and `remove-resource-grant=Resource`.
  - `ScreenActionDelta` rebuilds the complete array from the fresh read. It refuses what `UserUpdate` refuses: empty, already held, not held, or unknown (404 through the port).
  - A grant is validated by `RoleCreateRules.ResourceViolation`. That is one rule copy for three callers.
  - `set-resource-grant` adds a grant or replaces its letters.
- **Delete actions.** `RoleDelete` and `ResourceDelete` each declare `SCREENACTIONS "delete"`.
  - The screen path does not call `ArgumentProblem`. So each tool overrides `ScreenActionDelta` for `delete` and returns its own refusal as the bare published sentence:
    - a role whose name begins with `%`: `REASONROLENAMESYSTEM`;
    - a resource whose LIST row reads `AllowDelete` false: `REASONRESOURCENAMESYSTEM`.
  - `Prohibits` still refuses OcuPilot's own role or resource.
- **Prohibited set (`Prohibited.cls`):**
  - `PermittedChangeFields("role")` is `Description`, `EscalationOnly`, `GrantedRoles` and `Resources`.
  - A change to `GrantedRoles`, `Resources` or `EscalationOnly` of one of `OcuPilotRoles` is `PROHIBITED.OCUPILOTROLE`. Its `Description` may change. This needs the recommended AD-10 wording in Design Notes.
  - **The %All census runs for a role delete and for a role change** (AD-10's by-effect account arm).
    - When the role reached `%All` before and does not after, an account that would lose `%All` through that role is refused, checked in this order: `_SYSTEM` (`SYSTEMACCOUNT`), the signed-in account (`CURRENTUSER`), a service account (`SERVICEACCOUNT`).
    - When no counted holder keeps `%All`, the refusal is `LASTALLHOLDER`.
    - "After" is: nothing for a delete; the payload's `GrantedRoles` for a change. Setting `EscalationOnly` true counts as not reaching `%All` for login holders (inference: holders keep the role in `Roles`, measured on `ocupilot-ci`; whether login still grants it was not measured, so the census is conservative).
- **Refusal copy (DW-1598 and AD-53).** These become `…REASON` parameters returned by `ReasonFor`. Each is published in the Fixed strings table and pinned by `RefusalCopy`, and by a `self-protection.test.mjs` leg equating the parameter with its Fixed-strings sentence:
  - `UNCOVEREDFIELDREASON`: "Only some of this kind of object's settings can be changed here, and that is not one of them."
  - `OCUPILOTROLEREASON`: "This role belongs to OcuPilot, which stops working without what it grants. Only OcuPilot's installer changes or removes it."
  - `OCUPILOTRESOURCEREASON`: the existing sentence, unchanged.
- **Pre-click rules.** Two self-protection words are appended to `SELFPROTECTIONRULES` and to `IMPLEMENTED_SELF_PROTECTION_RULES`:
  - `system-role`: a key beginning with `%` answers `roleRefusalSystem`;
  - `system-resource`: a row whose `AllowDelete` is `false` answers `resourceRefusalSystem`.

  `selfProtectionReason` gains an optional `row` argument. Every call site passes it where it holds the row. With no row, `system-resource` answers `''`, and the instance still refuses. Each sentence is pinned equal to its `Error.cls` reason.
- **Role delete confirmation.** It is the typed-name dialog with `roleDeleteConsequence`, plus an advisory holder line.
  - The line is `roleDeleteHolders` ("<n> users hold this role."), `roleDeleteHoldersOne` or `roleDeleteHoldersNone`, whichever fits.
  - The count is the form read's `holders`: the distinct names of `User` and `User (escalation)` rows in `OWNERLIST`. This is 8.3's lead ruling.
  - A failed count read opens the dialog without the line.
- New strings are appended to `strings.ts` and to Fixed strings, marked `[ADDED 2026-09-24 - see the story change log]`. Use tokens only, `\uXXXX` escapes, named inputs, and no overflow. The editor gets no DW-1337 allowance.

**Never:**

- A client-computed `GrantedRoles`, `Resources` or `MatchRoles`. Save refuses both lists.
- SQL privilege tabs. The AC names none of them.
- A second grant dialog or action mechanism.
- Any edit to Epic 10's exclusive paths (as in 9.2).
- Anything but appends in `Api/Error.cls`, `strings.ts`, `_components.scss`, Fixed strings and `DW-n:` bullets.
- More than this story's own members in `Screen/Tool/Registry.cls` and `ui/tools/strings.test.mjs`.
- DW-1597 or DW-1357 work.
- A full browser suite run locally.
- A private key in any file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Two-field save | `PUT /roles/<probe>` `{Description, EscalationOnly}` on a probe with grants and granted roles | 200; the vendor gets the complete set; grants and granted roles read back unchanged; one `updated` event | — |
| Undeclared key | body carries `GrantedRoles`, `Resources` or `Name` | 400 `PORT.FIELD.UNEXPECTED` naming each; nothing sent | — |
| Absent | form read or Save of a missing role | 404 `ROLE.NAME.ABSENT`; the editor shows its absent state | — |
| Grant | `set-resource-grant` `{Resource:%DB_USER, Permissions:RW}`, then `RW`→`R`, then `remove-resource-grant` | each is a delta over the fresh read; other grants survive | unknown resource 404; bad letters 400 with `ROLE.RESOURCES.*` |
| Own role | Save `{EscalationOnly:true}` or a grant action on `OcuPilotShell` | 403 `PROHIBITED.OCUPILOTROLE`; nothing sent | — |
| Census | probe user P holds only probe role R, which is granted `%All`, and P is the last counted holder (seam `DeletingLeavesNoAllHolder`/the new change seam) | removing `%All` from R, deleting R, or setting R escalation-only is 403 `LASTALLHOLDER`; the same through `_SYSTEM`'s role is 403 `SYSTEMACCOUNT` | — |
| Agent privileged | `permissions.roles.update` adds `%All` to `GrantedRoles` | destructive proposal, `GRANT.PRIVILEGED`, the diff names `%All` | — |
| Role delete | Roles list Delete on a probe held by 2 users | the dialog states "2 users hold this role."; typed name deletes; the list re-reads | `%Developer` is drawn refused with `roleRefusalSystem`; a forced call is 400 with the same sentence |
| Resource delete | Resources list Delete on a probe; on `%DB_IRISSYS` | the probe is deleted after the typed name; `%DB_IRISSYS` is drawn refused with `resourceRefusalSystem` | `%DB_OCUPILOT` → 403 `OCUPILOTRESOURCE` |
| DW-1598 | Save a field outside `PermittedChangeFields` on any covered type | 403 with the new caller-neutral sentence | — |

</intent-contract>

## Code Map

S = `src/OcuPilot/`, U = `ui/src/app/`. Anchors are at HEAD `f0186ad20b6f4a3ad925adab3f81da0f06fc329a`.

Server:

- `S/Screen/Tool/`:
  - `RoleCreate.cls`: the template for the authored `Resources` and `GrantedRoles` arguments and their schema, at :38-100.
  - `UserUpdate.cls`: the merge template. See `SCREENACTIONS` :55, `SCREENVALUES` :59, `ArgumentProblem` :166 and `ScreenActionDelta` :213.
  - `WebAppUpdate.cls`: the nested-array delta at :250-353.
  - `RoleDelete.cls`: `ArgumentProblem` :96.
  - `ResourceDelete.cls`: `ArgumentProblem` :81, which reads `AllowDelete` from LIST.
  - `Write.cls`: `ScreenActionValueNames` :509 and `ScreenActionDelta` :537.
  - `Classification.cls`: the role create entry at :258. `ToolFields.cls` is regenerated with `cd ui && node tools/field-lists.mjs`.
- `S/Api/ScreenAction.cls`: `Run` :165 (delta :215, prohibited gate :246). It never calls `ArgumentProblem`.
- `S/Area/Permissions/`:
  - `RoleCreateRules.cls`: `Validate` :72 (it has no update mode), `ResourceViolation` :184, `GrantedRoleViolation` :249, `HandleForm` :295 (no `?name=`), `Resources()` :388.
  - `UserSave.cls` (`HandleUpdate` :52, `Update` :103, `Gate` :184) and `UserCreateRules.Changed` :228 are the templates.
  - `UserCreateRules.HandleForm` :381 with `Account()` :483 is the `?name=` template.
- `S/Kernel/Proposal/Prohibited.cls`:
  - `OCUPILOTROLE` :192, `OCUPILOTRESOURCE` :197 and `UNCOVEREDFIELD` :202. `ReasonFor` :354 has literals at :372-375.
  - `PermittedChangeFields` :443, which has no role branch.
  - `Prohibits` :592, with the role dispatch at :642. `Role()` :1025, `OcuPilotRoles` :1059, `ReviewedFewOnly` :1389.
  - The census: `LastAllHolder` :1911, `DeletingLeavesNoAllHolder` :1975 (the seam), `ReachesAllWithout` :2033, `CountsAsHolder` :2099 and `HoldsAll` :2142.
  - The account arms: `User()` :965 and `RemovesAdministration` :1826. `RolesGrantAll` :1869 is Private.
  - `GrantsPrivilegeByEffect` :1691, with the role branch at :1706.
- `S/Kernel/Proposal/Mint.cls`: the empty-diff refusal is at :241 and destructive/consequence at :306-322.
- `S/Port/AdminPort.cls`:
  - `TYPESUFFIXES` :118 lacks `OWNERLIST`. The type resolves through `$Parameter(class, "TYPE"_suffix)` :1800.
  - Measured: `Security.Role` `TYPEOWNERLIST` is 10 and `ShouldRunAsync` is 0. It answers `[{Name, Type: User|Role|"User (escalation)", AdminOption}]` and 404 for an absent role.
  - Also check the suffix-roster validation at :932-944.
- `S/Api/Router.cls`: the role routes are at :103-105, and `PUT /users/:id` at :101 is the precedent.
- `S/Api/Error.cls`: the ROLE block is at :1882-1962, `ReasonForViolation` role arms at :1128, `RoleViolationCodes` at :1222. The tail append point is after :2400.
- `S/Screen/Descriptor/`:
  - `RoleList.cls`: `rowActions []` :44.
  - `ResourceList.cls`: `rowActions []` :48; its read already carries `AllowDelete` :56.
  - `RoleForm.cls`: label `roleFormLabel` :21, and no prompts.
  - `UserForm.cls`: its prompts :45-49 are the precedent.
- `S/Screen/Registry.cls`: `SELFPROTECTIONRULES` :2244. `ui/tools/screen-mirror.mjs`: :313.
- Tests:
  - `Test/RefusalCopy.cls` (groups :22-91), `RoleCreate`, `RoleDelete`, `RoleWire`, `ResourceDelete` and `ResourceWire`.
  - `UserSave` and its fixtures are the template.
  - `SurfaceCoverage.cls`, with its role rows at :107-108, and `EndpointCoverage`.
  - `WireSecurityRead`, for the pair-denial leg.

Client:

- `U/areas/permissions/`:
  - `role-create-form.page.ts` (539 lines): grants fieldset :145-170, dialog host :220-229, `onSave` hand-off :466-480 (retain, to be replaced).
  - `role-create-form.store.ts`: types :35-67, `absorbRules` :525.
  - `role-grant-dialog.ts`: inputs `resources`, `granted`, `editing`, `clearing` and outputs `applied`, `closed`. It is stateless and reusable as it stands.
  - `user-editor.page.ts`/`.store.ts` are the pattern: tabs :145, `start` :845, `onApplied` :852, `afterRefusal` :883, and in the store `arriveSaved`/`open` :332-351, `refresh` :355, `save` :410.
  - `web-app-editor.page.ts` `start(…, values)` :959.
  - `resource-list.page.ts` hosts `<app-list-page>`.
- `U/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :39, `UNDRAWN_ACTIONS` :113, `DESTRUCTIVE_CONSEQUENCES` :160, `TYPED_NAME_ROWS` advisory :204, `startFor` :408, the async `openRole` precedent, `open` :482.
- `U/core/self-protection.ts` :91. Its call sites are `shell/data-table.ts:669`, `command-bar.ts:399`, `command-box.ts:492` and the handler :422. `ui/tools/self-protection.test.mjs`: `stringValue` :57, pairs :112-160.
- `U/shell/screen-outlet.ts`: `DESCRIPTOR_EDIT_PAGES` :124. `U/core/navigation.ts`: `CREATE_ONLY_FORMS` :201. `ui/tools/navigation.test.mjs` :275-290 asserts that roles have no editor.
- `U/core/strings.ts` ends at :1777 (`} as const;`). The keys to reuse: `processDetailsGroupGeneral`, `userRoleField`, `roleColumnEscalationOnly`, `roleFormGrantedRoles`, `roleGrant*` :1384-1394, `privilegedGrantEffect` :1408, `webAppRoleAssign` :1750, `actionRemove`, `actionDelete`, `userPromptGroupAccess`.
- EXPERIENCE.md: the Fixed strings last row is :475. The IA rows are :119 (role editor), :121 (grant dialog) and :122 (delete with count).
- Browser: `roles-create.browser-spec.mjs` (helpers :74-292; AC5 :359 expects the edit route) and `resources-editor.browser-spec.mjs` (helpers :67-168). `structural-walk.mjs` walks RoleForm at its bare route only.
- Bundle: `ui/angular.json:51-55` sets the warning at 1467kB, measured at 1,397,013 bytes. The same literal is pinned in `ui/tools/angular-json.test.mjs:371`.

## Tasks & Acceptance

**Execution:**

Server:

- `S/Screen/Tool/RoleUpdate.cls` (new; `permissions.roles.update`, `DESCRIPTORCLASS` RoleList):
  - Parameters: READTYPE GET, WRITETYPE PUT, `PERMITTEDFIELDS "Description,EscalationOnly"`, the authored `RESOURCESARGUMENT`/`GRANTEDROLESARGUMENT`, and the SCREENACTIONS/SCREENVALUES above. Pairs are as `RoleCreate`.
  - Methods:
    - `SettableFields`/`InputSchema`, each with authored descriptions;
    - `ArgumentProblem`: a fresh read, then `RoleCreateRules.Validate` in update mode over `Changed`;
    - `ScreenActionDelta`.
  - Add a `Classification.cls` entry and regenerate `ToolFields.cls`.
- `S/Screen/Tool/RoleDelete.cls` and `ResourceDelete.cls`: add `SCREENACTIONS "delete"` and the `ScreenActionDelta` delete refusal. It answers the bare sentence and reuses the class's own check.
- `S/Area/Permissions/RoleCreateRules.cls`:
  - `Validate` gains `pMode="update"` and `pFresh`. Add `Changed()`, and an `EscalationOnly` boolean rule (`ROLE.ESCALATIONONLY.SHAPE`, appended to Error.cls and `RoleViolationCodes`).
  - `HandleForm` with `?name=` also answers:
    - `role` {`Name`, `Description`, `EscalationOnly`, `GrantedRoles`, `Resources`} from `RoleUpdate`'s fresh read;
    - `members` [{`Name`, `Type`}] from `OWNERLIST` through the port;
    - `holders`, the distinct names whose Type is `User` or `User (escalation)`.

    An absent role is 404 `ROLE.NAME.ABSENT`, appended to Error.cls.
- `S/Area/Permissions/RoleSave.cls` (new) and `S/Api/Router.cls`: add `PUT /roles/:id` after `/roles/name` and before `POST /roles`. It follows the Save order through `RoleUpdate`.
- `S/Port/AdminPort.cls`: append `OWNERLIST` to `TYPESUFFIXES`, and update any suffix roster or inventory test that holds that list.
- `S/Kernel/Proposal/Prohibited.cls`:
  - Add the role change fields.
  - Add the own-role change arm in `Role()`.
  - Generalize the census. Add `ChangeStripsAll(pRole, pAfterGranted, pAfterEscalation, .pCode)` (public, overridable seam). It is used for DELETE (after = none) and for a change, and returns the first account code in the order above, else `LASTALLHOLDER`.
  - `ReachesAllWithout` becomes a walk in which the role answers its after-state.
  - `DeletingLeavesNoAllHolder`'s existing test seam keeps working.
  - Add `UNCOVEREDFIELDREASON`, `OCUPILOTROLEREASON` and `OCUPILOTRESOURCEREASON`, each returned by `ReasonFor`, and rescope the `OCUPILOTROLE` doc to cover a change.
- `S/Screen/Descriptor/RoleList.cls`: rowActions are `delete` (`system-role`) plus the four value actions (`""`).
- `S/Screen/Descriptor/ResourceList.cls`: rowActions are `delete` (`system-resource`).
- `S/Screen/Descriptor/RoleForm.cls`: labelKey `userRoleField` and 3 `suggestedPrompts`.
- `S/Screen/Registry.cls`: add the two rules. Then regenerate the mirror.
- Tests:
  - `Test/RoleSave.cls` (new): the matrix rows Two-field save through Own role, the census row over Save and actions, the form read's `role`/`members`/`holders` and its 404.
  - `Test/RoleUpdate.cls` (new): the schema, and the agent mint row for "Agent privileged" (destructive), plus the no-op 400.
  - `RoleDelete`/`ResourceDelete`: the screen-path legs of the Role delete and Resource delete rows, and the census order for a delete.
  - `RefusalCopy`: one leg for each of the three new `…REASON` parameters, and legs for `ROLENAMESYSTEM`/`RESOURCENAMESYSTEM` through `Error.ReasonForViolation`.
  - `SurfaceCoverage`: a row for the new tool, its name read from the instance.
  - `EndpointCoverage` and `WireSecurityRead`: a `PUT /roles/:id` pair-denial leg.
  - `Prohibited`: the role change fields.

Client:

- `U/areas/permissions/role-editor.page.ts` and `role-editor.store.ts` (new), each with a `.spec.ts`. Mirror `UserEditorPage`/`UserEditor`: load `GET /roles/form?name=`, `NavigationEnd`, and `PUT` the changed fields. Keep the summary, the tab opening, "Saved", `FormDirty`, and the clean re-read on `role` and `user` events.
  - **General:** Name read-only; Description; Escalation only; the grants list with Edit/Remove and Add. Grants open `RoleGrantDialog` (imported, not copied) and apply through `startFor(ROLE_LIST, 'set-resource-grant' | 'remove-resource-grant', name, null, sink, '', values)`.
  - **Members:** the rows (name, type).
    - A `User` row has Remove, which is `USER_LIST` `remove-role` with this role.
    - A `Role` row has Remove, which is `ROLE_LIST` `remove-granted-role` on the member with this role.
    - A `User (escalation)` row has no Remove.
    - Assign a user takes a named text input and uses `add-role`. Assign a role takes a select of `rules.roles` and uses `add-granted-role` on that role.
    - When this role is privileged, `privilegedGrantEffect` shows under Assign.
  - **Assigned to:** held roles with Remove, a role select with Assign (`add-granted-role`/`remove-granted-role` on this role), and `privilegedGrantEffect` under a privileged choice.
  - A header Delete runs `startFor(ROLE_LIST, 'delete', …)`, and `<app-screen-action-dialogs [descriptor]=ROLE_LIST>`. `onApplied('delete')` abandons and goes to the list.
  - Import `Grant`, `ResourceOption` and `RoleOption` from `role-create-form.store.ts`; do not copy them.
- `U/areas/permissions/role-create-form.page.ts`/`.store.ts`: replace the retain hand-off with `editor.arriveSaved(id)` before `navigateByUrl`, as `user-create-form.page.ts:488` does.
- `U/shell/screen-outlet.ts`: add `RoleForm: RoleEditorPage`. `U/core/navigation.ts`: `CREATE_ONLY_FORMS` becomes empty. Flip `navigation.test.mjs:275-290`.
- `U/shell/screen-action-handler.ts`:
  - Add RoleList and ResourceList to `SCREEN_ACTION_DESCRIPTORS`.
  - Add their `delete` to `DESTRUCTIVE_CONSEQUENCES` (`roleDeleteConsequence`, `resourceDeleteConsequence`).
  - Add RoleList's four value actions to `UNDRAWN_ACTIONS`.
  - RoleList `delete` reads `GET /api/ocupilot/roles/form?name=` for `holders` before it opens the typed-name dialog, with the count line as its advisory.
- `U/core/self-protection.ts` and its call sites: add the two rules and the `row` argument.
- `ui/tools/self-protection.test.mjs`:
  - pairs `REASONROLENAMESYSTEM`↔`roleRefusalSystem` and `REASONRESOURCENAMESYSTEM`↔`resourceRefusalSystem` (read from Error.cls);
  - three legs that the `UNCOVEREDFIELDREASON`, `OCUPILOTROLEREASON` and `OCUPILOTRESOURCEREASON` sentences each appear verbatim in the Fixed strings table, and that `ReasonFor` returns each parameter.
- `U/core/strings.ts` and the EXPERIENCE.md Fixed-strings rows (appends):
  - labels: `roleEditorTabMembers` "Members", `roleEditorTabAssignedTo` "Assigned to", `roleMemberUser` "User", `roleMemberType` "Type", and the type words `roleMemberTypeUser` "Account", `roleMemberTypeRole` "Role", `roleMemberTypeEscalation` "Account (escalation)";
  - empty states: `roleMembersEmpty` "No account or role holds this role.", `roleAssignedToEmpty` "This role carries no other role.";
  - delete copy: `roleDeleteConsequence` "Deleting this role takes it from every account and role that holds it. This cannot be undone.", the three holder lines, and `resourceDeleteConsequence` "Every role that grants this resource loses it. This cannot be undone.";
  - refusals: `roleRefusalSystem` and `resourceRefusalSystem`, each equal to its Error.cls reason;
  - one Fixed-strings row publishing the three kernel sentences;
  - three prompts: "Who holds this role, and what does it grant them?", "Does this role grant any administrative privilege?" and "Which other roles does this role carry?"
- Browser:
  - `ui/browser/roles-editor.browser-spec.mjs` (new) covers:
    - the name cell opens 3 tabs;
    - a two-field Save reads back through `docker exec`, and the list shows the new Description without a reload;
    - a grant added and edited through the dialog shows current and resulting grants, and reads back;
    - Assigned to Assign/Remove, and Members Assign user/Remove;
    - the tab error dot;
    - the leave guard;
    - Roles list Delete with the count line;
    - `%Developer` drawn refused;
    - the visual gate, with the bar flush at 1440x900.
  - `resources-editor.browser-spec.mjs`: a probe deleted from the row menu, and `%DB_IRISSYS` Delete drawn refused with its sentence.
  - `roles-create.browser-spec.mjs` AC5: the editor's bar reads "Saved", and a hard reload shows the created role.

**Acceptance Criteria:**

- **Given** a Roles row, **when** its name is opened, **then** the editor shows General (description, escalation-only, resource grants), Members and Assigned to, each read from the instance.
- **Given** a grant is added or edited from the editor, **when** the dialog opens, **then** it shows the current grant and the resulting grant, as on the create path, and the applied grant reaches the instance as a delta.
- **Given** the Roles list or the editor, **when** Delete is chosen for a role N users hold, **then** the typed-name dialog states "N users hold this role." and the confirmed delete is re-read by the list (DW-1513). A `%` role is drawn refused before a click and refused after one with the same sentence.
- **Given** the Resources list, **when** a row's `AllowDelete` is false, **then** Delete is drawn disabled with `resourceRefusalSystem`, and the instance refuses a forced call with that sentence (DW-1528).
- **Given** any covered type, **when** a change names an unreviewed field, **then** the refusal is the caller-neutral `UNCOVEREDFIELDREASON`, published and pinned (DW-1598).
- **Integration:** `RoleEditorPage` consumes `form-tabs`, `startFor(…, values)`, `RoleGrantDialog` and `DESCRIPTOR_EDIT_PAGES`. A refusal on an unselected tab opens it with its dot, and a grant reaches the instance through the Roles list's AD-53 route. The browser spec observes both.

## Spec Change Log

- 2026-09-24 spec gate (lead): accepted the recommended AD-10 amendment (own-role grant changes refused `PROHIBITED.OCUPILOTROLE`, required by AD-21's privilege floor; account arms fire through a role delete or change) and applied it to the spine.

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 29 findings — high 0, medium 4, low 10, false 15, maybe-false 0
- findings:
  - `[medium]` `[patch]` The editor's own Delete → `onApplied` return path had no test (AC3 "or the editor") — added a page-spec leg that confirms the typed name and asserts the list route and a clean form; mutation recorded.
  - `[medium]` `[patch]` The editor's change-bus re-read, route following and clean refresh were unpinned — added the user editor's two legs to `role-editor.page.spec.ts`; mutations recorded.
  - `[low]` `[patch]` The Members tab's privileged caption and `privileged()`'s false branch were unverified — added a marked and an unmarked leg; mutation recorded.
  - `[medium]` `[patch]` The command bar's and command box's new `row` argument had no test — added a `system-resource` leg to each spec; mutations recorded.
  - `[medium]` `[patch]` The holder count's distinct-name and escalation counting were unpinned — `RoleSave` now makes an escalation-only holder and gives the member account the role both ways, and asserts `holders` 2; mutation recorded.
  - `[low]` `[patch]` The unknown-role refusal of `add-granted-role` (and the restated-grant refusal) had no leg — both added to `RoleSave`'s refusal loop.
  - `[low]` `[patch]` The page spec's AC3 GET assertion could not fail (the open already reads the same path) — it now counts the form reads before and after the click.
  - `[low]` `[patch]` `TestOcuPilotsOwnRoleIsRefusedAGrantChangeButNotItsDescription` could pass on an empty own-role list — it now asserts the list is non-empty before quitting.
  - `[false]` `[reject]` The census's signed-in and service-account legs run only for some runners — `ci-runner` sessions run as `irisowner` on `ocupilot-ci` (measured), so both legs run.
  - `[low]` `[reject]` `RefusalCopy`'s "not a literal" message cannot tell for `OCUPILOTRESOURCE`, whose old literal equalled the parameter — cosmetic; `self-protection.test.mjs` pins the `ReasonFor` source line.
  - `[low]` `[reject]` Several matrix rows (Undeclared key, Absent server half, Grant, Agent privileged, Resource delete, the pair denial) carry no `mutation:` line — Rule 19 scopes one line per AC and every AC has one; each test's doc comment names its mutation.
  - `[low]` `[patch]` The three kernel sentences have `strings.ts` keys although the new Fixed-strings row said "no client copy" — the keys are required by `strings.test.mjs` (every Fixed-strings literal must be a value; 9.2's own-app sentence is the precedent), so the row now reads "no control draws them before a click".
  - `[false]` `[reject]` The task list's `roleMemberUser`, `roleMemberType`, `roleMemberTypeRole` were not added — `strings.test.mjs` refuses duplicate values, so the existing `processColumnUser`, `tableColumnType`, `userRoleField` are reused; the fix would edit the spec.
  - `[false]` `[reject]` Grant row: an unknown resource answers 400, not 404 — the Boundaries bind the delta to "what `UserUpdate` refuses … unknown (404 through the port)", and `UserUpdate` turns the port's 404 into a `TOOL.ARGUMENTS` problem; a 404 answer would need a second refusal channel in `ScreenAction.Run`.
  - `[false]` `[reject]` Grant row: bad letters carry the `ROLE.RESOURCES.PERMISSIONS` sentence, not its code — the delta's only channel is the problem sentence, which is that code's published reason.
  - `[low]` `[defer]` A forced `%Developer` delete is pinned at `RoleDelete.ScreenActionDelta`, not over the route — already the spec's first `deferred:` item; a route leg would drop a vendor role if the refusal regressed.
  - `[false]` `[reject]` The census is pinned through fixture seams, not a route — the matrix row names those seams.
  - `[false]` `[reject]` DW-1598 is pinned only at `ReasonFor` for one type — `ReasonFor(UNCOVEREDFIELD)` is type-independent and is the envelope reason on both callers.
  - `[low]` `[patch]` The Save's event was asserted as "at least one" — the store spec now asserts exactly one.
  - `[false]` `[reject]` The own-role test uses the last of `OcuPilotRoles`, not `OcuPilotShell` — the arm is a `$ListFind` over that list, so any member takes the same path.
  - `[false]` `[reject]` `ScreenAction.Run` adds the id argument to every tool's delta values — values are validated before `Run` (`Values`, :131) and not read after; the method already adds the id to `tArgs` the same way, and the add is skipped when a value of that name exists.
  - `[false]` `[reject]` `Error.cls` edits inside `ReasonForViolation` and `RoleViolationCodes` break append-only — the spec's task requires the new code in both; each is one element appended at the end, and the feature branch touches neither.
  - `[false]` `[reject]` The Role form's label changes to `userRoleField` — a spec task.
  - `[false]` `[reject]` The create form drops its retain hand-off — a spec task.
  - `[false]` `[reject]` `OWNERLIST` is added to `TYPESUFFIXES` — a spec task.
  - `[false]` `[reject]` The editor has its own Delete button — a spec task ("A header Delete").
  - `[false]` `[reject]` A Save of `{}` answers 200 and writes the unchanged set — `UserSave` and `WebAppSave` pin the same; the client never sends `{}`.
  - `[low]` `[reject]` `error-log.page.ts` calls `selfProtectionReason` without a row — its screen declares no row-reading rule, so the argument changes nothing there.
  - `[false]` `[reject]` Intent-alignment's summary that the census is never exercised by a route — same root as the fixture-seam row above; the matrix names the seams.

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-19, AD-27 (a new read suffix inside the port, not a fallback), AD-39, AD-51, AD-53, AD-54, AD-55 and AD-56 (ii).

**Recommended spine amendment (lead, Rule 20; ask-first if read as narrowing).** AD-10 lists the deletion of OcuPilot's own role, but not a change to what that role grants. Adding `%All` to `OcuPilotShell` makes every request to `/ocupilot` run elevated. That is the application-role harm the `PRIVILEGEGRANT` arm names, reached by effect. Removing its database grant breaks the serving path. The proposed wording for AD-10's fifth bullet:

> "Terminating IRIS system processes; deleting OcuPilot's own web applications, resource, role or database; **or changing what one of OcuPilot's own roles grants (`GrantedRoles`, `Resources`, `EscalationOnly`), refused `PROHIBITED.OCUPILOTROLE`, because those roles are the privilege floor AD-21 fixes and what OcuPilot administers and signs in with.**"

For the account arm, append:

> "…and a role delete or change that strips `%All` from the account through that role."

If the lead declines the first sentence, drop the own-role change arm. Such changes then become permitted, and a privileged one is minted destructive.

**Why `Members` writes through other rows' actions.** A member is the holder's own field: a user's `Roles`, or a role's `GrantedRoles`. The classic Members tab also writes the holder (`RoleMemberTab.RemoveRole`). So an account member is the Users list's shipped `add-role`/`remove-role`, and a role member is `add-granted-role`/`remove-granted-role` on the member. No new mechanism is involved. Escalation holders are read-only, because `EscalationRoles` is excluded from `UserUpdate`.

**The screen delete path skips `ArgumentProblem`** (`ScreenAction.Run`). So the `%` and `AllowDelete` refusals live in each delete tool's `ScreenActionDelta`, which reuses its own check. Without that, a screen Delete could drop `%Developer`: the vendor `DropUser` reports success. The pre-click sentence and the post-click sentence are the same published `Error.cls` reason.

**The three kernel sentences have no client copy.** They reach a person only as the server's reason, as 9.2's own-app sentences do. So each is pinned to its Fixed-strings text rather than to a `strings.ts` key.

**Bundle.** The editor is estimated at about 35-45 kB, which puts the total near 1.44 MB. That is under the 1467kB warning and the 1500kB line (inference; measure after build).

**Consumes:** 9.1's editor pattern, `form-tabs`, `startFor`, `arriveSaved` and the `UserSave` order. 9.2's `startFor(…, values)`, the form-page flex rule and the no-op 400. 8.3's `RoleCreateRules`, `RoleGrantDialog`, `RoleDelete` and census. 8.4's `ResourceDelete`. 7.x's AD-53 route and typed-name dialog.

**Consumed-by:** 9.5, 9.8 and 9.9 get the `row`-aware self-protection. 14.7 draws the typed-name field on destructive role proposals.

**Ledger inbox:** DW-1513, DW-1528 and DW-1598 are addressed. DW-1357 is declined: naming the refused field is a detail-shape change outside this story. DW-1597 is not this story's.

## Verification

**Commands:**

- `(loop)` `cd ui && node --test tools/self-protection.test.mjs tools/navigation.test.mjs tools/strings.test.mjs tools/screen-mirror.test.mjs tools/field-lists.test.mjs tools/angular-json.test.mjs`. Expected: green.
- `(loop)` `cd ui && npm run test:components`. Expected: green, with the `role-editor.*.spec.ts`, `screen-action-handler.spec.ts` and `data-table.spec.ts` specs.
- `(loop)` Run `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<X>`, one run at a time, for X in `RoleSave`, `RoleUpdate`, `RoleDelete`, `RoleCreate`, `RoleWire`, `ResourceDelete`, `ResourceUpdate`, `ResourceWire`, `RefusalCopy`, `Prohibited`, `ProhibitedByEffect`, `SurfaceCoverage`, `EndpointCoverage`, `WireSecurityRead`, `ToolWrite` and `Descriptor`. Expected: 0 failures.
- `(loop)` Build and deploy: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
  - Then run each spec file alone, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<f>`, over:
    - the editors: roles-editor, roles-create, resources-editor, permissions, users-editor, web-applications-editor;
    - the row-action and typed-name specs the handler and self-protection changes reach: users-actions, web-applications-actions, oauth-delete, task-schedule-actions, task-run, process-actions, error-log-actions, audit-events, auditing-write;
    - a11y-structural-invariants.
  - Expected: green.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean, with the initial bundle under 1467kB.
- `(once, before dev_complete)` `node ui/tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test`. Expected: 0 new failures, excluding the arming-variable classes this throwaway refuses.

**Mutations (Rule 19; the pass that adds each pinning test writes its line):**

- AC1: drop the Members tab.
- AC2: pass `[]` as the dialog's `granted`.
- AC3: drop the advisory. Also clear the `system-role` rule, and drop the delete delta refusal.
- AC4: make `system-resource` ignore the row, and drop `ResourceDelete`'s delta refusal.
- AC5: restore the literal in `ReasonFor`.
- Census: have `ChangeStripsAll` answer `""` for a change.
- Own role: delete the own-role arm.
- Save order: merge over `{Name}`.
- Integration: skip `tabToOpen`.

**Mutations observed (implement pass; each reverted, file byte-identical by md5):**

- mutation: drop the Members tab from `RoleEditorPage.tabs` → `role-editor.page.spec.ts` AC1 (and three dependent legs) went red.
- mutation: pass `[]` as the grant dialog's `granted` → `role-editor.page.spec.ts` AC2 went red.
- mutation: drop the holder advisory from `ScreenActionHandler.openRoleDelete` → `role-editor.page.spec.ts` AC3 and `screen-action-handler.spec.ts` "states how many accounts hold the role" went red.
- mutation: make `system-role` answer `''` in `selfProtectionReason` → `self-protection.test.mjs` "system-role answers a name beginning %" went red.
- mutation: drop the delete refusal from `RoleDelete.ScreenActionDelta` → `OcuPilot.Test.RoleDelete.TestTheScreenDeleteRefusesAPredefinedRoleWithThePublishedSentence` went red.
- mutation: make `system-resource` ignore the row → `self-protection.test.mjs` "system-resource" leg and `data-table.spec.ts` "system-resource entry" went red.
- mutation: drop the delete refusal from `ResourceDelete.ScreenActionDelta` → `OcuPilot.Test.ResourceDelete.TestTheScreenDeleteRefusesASystemResourceWithThePublishedSentence` went red.
- mutation: restore the agent-worded literal for `UNCOVEREDFIELD` in `Prohibited.ReasonFor` → `OcuPilot.Test.RefusalCopy.TestEachKernelRefusalIsItsParameterAndNamesNoCaller` and `self-protection.test.mjs` "DW-1598" went red.
- mutation: have `ChangeStripsAll` answer `""` for a change (`If 'pDelete Quit`) → `OcuPilot.Test.RoleSave.TestTheCensusRefusesAChangeOrDeleteThatStripsAll` went red.
- mutation: delete the own-role arm for a change in `Prohibited.Role` (`If tDelete {`) → `OcuPilot.Test.RoleSave.TestOcuPilotsOwnRoleIsRefusedAGrantChangeButNotItsDescription` went red.
- mutation: merge over `{Name}` instead of the fresh read in `RoleSave.Update` → `OcuPilot.Test.RoleSave.TestATwoFieldSaveSendsTheCompleteSetAndTheGrantsSurvive` (and three other legs) went red.
- mutation: skip `tabToOpen` in `RoleEditorPage.afterRefusal` → `role-editor.page.spec.ts` Integration went red.
- mutation: drop the 404 branch from `RoleEditor.absorb` → `role-editor.store.spec.ts` "reads a role the instance does not hold as absent" went red (matrix row Absent, client half).
- mutation: never take the delete branch in `RoleEditorPage.onApplied` → `role-editor.page.spec.ts` "AC3: a Delete confirmed from the editor…" went red (AC3, editor half).
- mutation: have `RoleEditor.refresh` always absorb the lists alone → `role-editor.page.spec.ts` "re-reads the role in place…" went red.
- mutation: return before the `NavigationEnd` check in the page's route subscription → `role-editor.page.spec.ts` "follows the route to another role…" went red.
- mutation: have `RoleEditor.privileged` answer true → `role-editor.page.spec.ts` "states the privilege consequence under Members' Assign…" went red.
- mutation: drop `row` from `command-bar.ts`'s `selfProtectionReason` call → `command-bar.spec.ts` "Story 9.3: a system-resource action…" went red; the same in `command-box.ts` → `command-box.spec.ts` "Story 9.3: with a not-deletable row selected…" went red (AC4, the other two surfaces).
- mutation: drop the distinct-name check from `RoleCreateRules.Members` (throwaway copy, recompiled) → `OcuPilot.Test.RoleSave.TestTheSaveAndTheFormReadAnswerOneEnvelopeOverTheWire` went red on `holders` 3 (AC3's count).

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The role editor at `permissions/roles/edit/<id>` (General, Members, Assigned to) over `GET /roles/form?name=` and `PUT /roles/:id`; the new `permissions.roles.update` tool, whose four screen actions are the editor's grant and granted-role deltas; Delete on the Roles and Resources lists, refused before and after a click for a `%` role and a not-deletable resource, with the role's holder count in its dialog; the role change fields, own-role arm and change census in `Prohibited.cls`; the three kernel sentences as parameters (DW-1598).

**Files.**

- Server: `Screen/Tool/RoleUpdate.cls` (new tool); `Area/Permissions/RoleSave.cls` (new Save); `RoleCreateRules.cls` (update mode, `Changed`, form read `role`/`members`/`holders`); `Kernel/Proposal/Prohibited.cls` (role fields, own-role arm, `ChangeStripsAll`, reason parameters); `RoleDelete.cls`/`ResourceDelete.cls` (screen Delete and its refusal); `Api/ScreenAction.cls` (target passed to the delta); `Api/Router.cls`, `Api/Error.cls` (appends), `Port/AdminPort.cls` (`OWNERLIST`); `RoleList`/`ResourceList`/`RoleForm` descriptors; `Screen/Registry.cls` (two rules); `Classification.cls`/`ToolFields.cls`.
- Server tests: new `RoleSave`, `RoleUpdate` (+ two fixtures); legs in `RoleDelete`, `ResourceDelete`, `RefusalCopy`, `Prohibited`, `WireSecurityRead`; roster rows in `SurfaceCoverage`, `EndpointCoverage`, `PermissionsLists`, `ReadTool`, `ToolRoundTrip`, `Wire`, `WireSecurityRead`, `ProhibitedFixture`, `scripts/ci-throwaway.sh`.
- Client: `role-editor.page.ts`/`.store.ts` (+ specs); `role-create-form.*` (`arriveSaved` hand-off); `screen-action-handler.ts`, `self-protection.ts`, `table-model.ts` (`rowFor`), `data-table.ts`, `command-bar.ts`, `command-box.ts`, `screen-outlet.ts`, `navigation.ts`, `strings.ts`, `_components.scss`, `screens.generated.ts`; specs for handler, data table, command bar, command box; `navigation.test.mjs`, `self-protection.test.mjs`, `screen-mirror.mjs`.
- Browser: new `roles-editor.browser-spec.mjs`; legs in `roles-create`, `resources-editor`, `permissions`. EXPERIENCE.md Fixed strings rows 476-480.

**Review (one pass, two layers).** 29 findings: 10 patched (medium 4, low 6), 1 deferred (already recorded), 18 rejected with reasons in the Review Triage Log. The patches add tests only (editor Delete return, bus re-read, route following, privileged caption, command bar and box row rule, holder counting, unknown-role and restated-grant refusals, one vacuous and one silently-skippable assertion) and correct the new Fixed-strings row's wording. The full sweep then tripped three rosters the new tool and row actions change (`PermissionsLists`, `ReadTool`, `ToolRoundTrip`), updated in the same pass. Follow-up review: `false`. Four medium entries were patched, but each patch is a test whose mutation was observed red, so no unverified risk remains to name.

**Verification.** All on `ocupilot-ci`, one run at a time.

- Tool tier: 1,382/1,382. Component tier: 80 files, 1,089 tests.
- `check-objectscript` and `lint-docs` are clean.
- Build: initial total 1,428,112 bytes, under the 1467kB warning. The same bundle (`main-PFNB5AEU.js`) was deployed for every browser run.
- Browser spec files, each run alone, all green: roles-editor 8, roles-create 5, resources-editor 6, permissions 5, users-editor 8, web-applications-editor 7, users-actions 2, web-applications-actions 3, oauth-delete 2, task-schedule-actions 4, task-run 2, process-actions 3, error-log-actions 3, audit-events 4, auditing-write 3, a11y-structural-invariants 10.
- Full ObjectScript sweep: 220 classes, 1,928 tests. It showed 4 failed tests and the 4 class-level arming refusals (`AuditingUpdate`, `ErrorDelete`, `ProcessControl`, `TaskResume`). Three of the four were the rosters above, now green on re-run (`PermissionsLists` 7, `ReadTool` 27, `ToolRoundTrip` 2). The fourth is the known `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal`.
- Every mutation under `## Verification` was observed red and reverted byte-identical.

**Residual risks.**

- The census reads an escalation-only role as granting nothing at sign-in (inference; see `deferred:`).
- A forced `%Developer` delete is pinned below the route.
- `EXPERIENCE.md:476-480` references will need renumbering if Epic 10 appends Fixed-strings rows first.
- `Test/Wire.cls` carries the Role form's new label, which Epic 10's copy does not.
