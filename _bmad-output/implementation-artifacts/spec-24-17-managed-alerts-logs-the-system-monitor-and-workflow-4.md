---
title: 'Story 24.17: Managed alerts, logs, the system monitor and workflow (Batch 3b: workflow roles and membership)'
type: 'feature'
created: '2026-11-25'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-17-managed-alerts-logs-the-system-monitor-and-workflow-3.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-17-managed-alerts-logs-the-system-monitor-and-workflow.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-17-managed-alerts-logs-the-system-monitor-and-workflow-2.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot has nothing for the classic Workflow Roles page (`EnsPortal.WFRoles`) or its Add and Remove user dialogs (`EnsPortal.Dialog.WorkflowRoleAddUser`, `WorkflowRoleRemoveUser`), so a namespace's workflow roles and their members cannot be listed, added, edited or removed, and nothing round-trips over `EnsLib.Workflow.RoleDefinition` or `EnsLib.Workflow.RoleMembership`.

**Approach:** Batch 3b, after Batch 3a's workflow users (`-3.md`, Design Notes, Batch split), whose port family, tools, case, fixture and seam it extends. **Workflow roles**, a list with **New workflow role**, **Edit** and **Remove**, and its sub-screen **Role members**, with **Add member** and **Remove**, each one operation reached by the screen and by the agent. "Round-trips" means: a role added or edited from either caller reads back from `EnsLib.Workflow.RoleDefinition` exactly as sent, a member added reads back from `RoleMembership` with its rank and title, and a removed role or member is gone.

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains `WorkflowRoles` (`LIST`; `WORKFLOWROLE`, the fresh read with `ACTIONKEY`; writes `ADDWORKFLOWROLE`, `SETWORKFLOWROLE`, `REMOVEWORKFLOWROLE`) and `WorkflowMembers` (`LIST` with exactly one criterion, `role` or `user`; `WORKFLOWMEMBER`, the fresh read by the composite id `[Role, User]`, AD-13; writes `ADDWORKFLOWMEMBER`, `REMOVEWORKFLOWMEMBER`). Reads use `%ExecDirectNoPriv` after the gate. Switched by save and restore; no `OcuPilot.*` call while switched, logging included; a fault is logged after the restore. Batch 3a's rules hold unless named here.
- **Rows.** Roles `{Name, Description, Capacity, Members, Namespace}` as the classic `RoleDefinition:Roles` (`Members` its `Users` count), by name ascending. Members `{Role, User, FullName, Ranking, Title, IsActive, Namespace}` as the classic `Engine:ListUsersForRole`, by user name for `role` and by role name for `user`. Each capped (`WORKFLOWROLESMAX`, `WORKFLOWMEMBERSMAX`), truncation reported (AD-36).
- **Gate (AD-29, AD-8), before any vendor call or value judged; never cached.** Batch 3a's pairs: reads `%Ens_Portal:USE`, `%Ens_WorkflowConfig:READ` (`WFRoles.cls:10`), then `Admit`; writes plus `%Ens_WorkflowConfig:WRITE` (`EDITRESOURCE` :13, `GetHyperEventResources` :497; both dialogs' `RESOURCE`) and WRITE on the namespace's globals database, plus any pair Task 0 (b) measures. If 3a's veto item 2 condition was ruled and measured, the lists take the same check on their tables.
- **Write refusals by name, after the gate, before any vendor call**, in this order: source control, 409 `INTEROP.WORKFLOW.SOURCECONTROL` (3a's code); a role name empty, over 128 characters or holding a control character (add), 422 `INTEROP.WORKFLOW.ROLENAME`; a role the namespace holds in any letter case (add), 409 `.ROLETAKEN`; an edit or remove of a role not held exactly, and an add member to one, 404; a description over 2,000 characters, 422 `.ROLEDESCRIPTION`; a capacity that is not a whole number from 1 to 100, 422 `.ROLECAPACITY`; an added member who is not a workflow user of the namespace, held exactly, 422 `.MEMBERUSER`; one already a member, 409 `.MEMBERTAKEN`; a rank that is not a whole number from 1 to 5, 422 `.MEMBERRANK`; a title over 128 characters or holding a control character, 422 `.MEMBERTITLE`; a remove of a user who is not a member, 404 (the vendor answers it OK).
- **The writes run as the classic page and dialogs do**, in the proposal's namespace: a role add `%New` and `%Save` (absent `Capacity` the vendor's 100); an edit `%OpenId(name, 4)` and `%Save` of only the fields that differ (`WFRoles.cls:393` `SaveItem`), a locked role 503; a remove `%DeleteId` (`DeleteID` :306), whose foreign key cascade removes the role's memberships; a member add `EnsLib.Workflow.RoleDefinition.AddUserToRole(role, user, rank, title)` (absent rank the vendor's 3), a remove `RemoveUserFromRole(role, user)`, which discards its own delete status (`RoleDefinition.cls:190-193`), so the port reads the membership again and answers 500 if it is still held. No rename. A single operation, as the purge: a vendor error status answers 500 `INTERNAL`, never 200, even after the membership was saved, and its audit row reads `completed` false.
- **The tools (AD-3, AD-6, AD-10, AD-14, AD-22, AD-34, AD-51 to AD-55, AD-58, AD-59).** `interop.workflowroles.add` (a create; read-back through the update's read), `.update` (`edit=Description:Capacity`, optional, `Description` may be empty), `.remove` (`DESTRUCTIVE`, typed name, `FINGERPRINTSUBJECT` `Name,Description,Capacity,Members,Namespace`); `interop.workflowmembers.add` (a create on `[Role, User]`, `Ranking` and `Title` optional), `.remove` (`FINGERPRINTSUBJECT` `Role,User,Ranking,Title,Namespace`; destructive or not per veto item 5). Each extends 3a's family (`WRITERESOURCE` `%Ens_WorkflowConfig`, `WRITEPERMISSION` `WRITE`, `CLASSICPAGES` `EnsPortal.WFRoles`). Keys per veto item 5. The New workflow role and Add member dialogs save through `POST /interop/workflow-roles` and `POST /interop/workflow-members` (AD-55). Classified in `ConfirmNamespaceRoster` and `DraftRegistry`. Each script form shape-checks every value, renders no draft for a bad one, and renders the switch, each refusal as a one-line guard and the vendor call, running none. A screen action mints nothing and is not gated by read-only or the kill switch.
- **Namespace at confirm (AD-52).** Every stored proposal carries `Namespace`; every confirm-time judgment (the fresh read, the source-control test, the role and user tests, the vendor call) runs there.
- **Audit (AD-15).** The agent's marker on the agent's write; OcuPilot's own `ConfigChange` from either caller, after the restore, naming the namespace, the role (and user, for a member), the fields changed and `completed`, never a description or title.
- **Bounds.** `WORKFLOWROLESMAX` and `WORKFLOWMEMBERSMAX` (provisional 2,000; Task 0 (e) sets each), boundary-tested at the cap and one over through 3a's seam.
- **README.** The switched-off count rises by each `false` key and the off list gains this batch's clause (veto item 1), in the same commit as the keys.
- **Rosters.** `interop-workflow-role` then `interop-workflow-member` after 3a's `interop-workflow-user` in `TYPES` and `COVEREDTYPES`; their `Prohibited.cls` terms appended; no earlier type reaches a different arm. Every pinned roster is in the Code Map.

**Never:**

- `RoleDefinition.OnSubmit`, `CreateRole` without the fields, any SQL `DELETE`/`UPDATE` of OcuPilot's own on the workflow tables; a membership edit (the classic page has none); any `EnsPortal.*` call in product code; a rename by delete and create.
- A description or title in a log line or an audit row; a vendor status text in a log.
- `Set $ROLES`, `AddRoles`, or a `New $ROLES` (a vendor call that changes `$ROLES` is a HALT).
- Tasks and the worklist (Batch 4), including the classic Tasks popups; the README's Interoperability paragraph (Batch 5); a spine edit.
- Batch 3a's file prohibitions, unchanged.

## I/O & Edge-Case Matrix

Route namespace USER. Probe roles are named `OcuP2417r*`; probe users are 3a's fixture's; HSCUSTOM holds its own. Tasks are 3a's probe tasks.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Lists | Two probe roles, one with two members (one inactive) | Roles by name with `Members`; the members list for `role` by user and for `user` by role | - |
| Role add and edit, both callers | A name, a description, capacity 40; then the description only | Reads back as sent; the edit changes the description only | - |
| Role remove, both callers | A probe role with two members and a task sent through it | Gone with its memberships; the task and its worklist items as they were; card destructive | - |
| Member add, both callers | An active probe user, rank 2, title from the agent; an inactive one with neither | Reads back with rank 2 and the title, then rank 3 and no title; the active member gets the role's unassigned task, the inactive none | - |
| Member remove, both callers | A member holding a task through the role | Gone; their worklist items for the role gone, the task unassigned | - |
| Values | Role name of 129 characters, with a tab; a held role in another case; description of 2,001; capacity 0, 101, 1.5; rank 0, 6, `x`; title of 129; a user not a workflow user; one already a member; a non-member removed | Refused; nothing saved or deleted | 422 `.ROLENAME`; 409 `.ROLETAKEN`; 422 `.ROLEDESCRIPTION`, `.ROLECAPACITY`, `.MEMBERRANK`, `.MEMBERTITLE`, `.MEMBERUSER`; 409 `.MEMBERTAKEN`; 404 |
| Source control | The seam's source-controlled namespace | Every write refused, through the mint, both Save routes and the screen actions | 409 `.SOURCECONTROL` |
| Gate | No `%Ens_WorkflowConfig:READ`; no `:WRITE`; no database WRITE | Refused before any vendor call | 403 naming the pair |
| Vendor error | The seam answers an error status after a member's save | Never 200; audit `completed` false; no vendor text logged | 500 `INTERNAL` |
| Remove kept | The seam's `RemoveUserFromRole` deletes nothing and answers OK | Never 200 | 500 `INTERNAL` |
| Moved | A member added after the agent's role remove was minted | Confirm refused, nothing deleted | `PROPOSAL.TARGETCHANGED` |
| Confirm elsewhere | Each write minted in USER, confirmed with `?ns=HSCUSTOM`, HSCUSTOM holding same-named roles, users and members | Each acts in USER only; HSCUSTOM unchanged | - |
| Cap | Seam caps 3: three probes, then four | Three; four listed as three with truncation, for both lists | - |
| Script | Each draft; a bad value | Renders the switch, guards and vendor call, runs nothing; a bad value renders no draft | - |

</intent-contract>

## Code Map

Anchors are at plan (HEAD `2ded140f53041a5f6efcaf25fc283fe030e28823`) and Batch 3a moves most of them: re-grep by name. Epic 21 changes no product file beyond feature at plan; re-check before editing.

- **`Port/InteropPort.cls`**: extend Batch 3a's `WorkflowUsers` family (Rule 31): its facts, write tokens, source-control refusal, perform, snippet and caps take the role and member arms beside the user's. Anchors as 3a's Code Map; the composite id follows `InvokeItems` :1959 (`[Production, Name]`); the child list's criterion follows `ListAlerts`' `alert` criterion :11418.
- **Vendor (read-only, read at plan):** `irislib/EnsLib/Workflow/RoleDefinition.cls` (properties :20-28 with `Capacity` `MINVAL` 1 and initial 100, `Roles` :81-89, `AddUserToRole` :145-178, `RemoveUserFromRole` :183-203 discarding the delete status at :190-193, `%OnDelete` :234-240, storage `^EnsLib.W.RoleDefinition*`); `irislib/EnsLib/Workflow/RoleMembership.cls` (`IdKey (Role, User)` :17, both foreign keys `OnDelete = cascade` :19-21, `Ranking` `MINVAL` 1 :31, `Title` `MAXLEN` 128 :37); `irislib/EnsLib/Workflow/Engine.cls` (`ListUsersForRole` :381-392, `ListRolesForUser` :394-403, `%OnRoleChange` :785-789 does nothing, `%OnRoleMembershipChange` :797-896: a remove deletes the member's worklist items in the role and relinquishes each task they own, an add of an active user sends the role's unassigned tasks); `irislib/EnsPortal/WFRoles.cls` (`RESOURCE` :10, `EDITRESOURCE` :13, table :109-128 with `maxRows` 10000 :113, form :140-142, `DeleteID` :306-320, `SaveItem` :393-452 with capacity coerced to 100 and the rename, `GetHyperEventResources` :497-503); `irislib/EnsPortal/Dialog/WorkflowRoleAddUser.cls` (`RESOURCE` `%Ens_WorkflowConfig:WRITE`, rank 1 to 5, title, the duplicate check and `AddUserToRole` in `SaveData`); `irislib/EnsPortal/Dialog/WorkflowRoleRemoveUser.cls` (`RESOURCE` `%Ens_WorkflowConfig:WRITE`, `RemoveUserFromRole` in `RemoveData`).
- **`Api/InteropError.cls`:** codes `WORKFLOWROLENAME`, `WORKFLOWROLETAKEN`, `WORKFLOWROLEDESCRIPTION`, `WORKFLOWROLECAPACITY`, `WORKFLOWMEMBERUSER`, `WORKFLOWMEMBERTAKEN`, `WORKFLOWMEMBERRANK`, `WORKFLOWMEMBERTITLE`, consequences `WORKFLOWROLEREMOVE`, `WORKFLOWMEMBERADD`, `WORKFLOWMEMBERREMOVE`, in 3a's workflow block and lists.
- **Tools (new, `Screen/Tool/`):** `InteropWorkflowRoleAction` (abstract) with `InteropWorkflowRoleAdd`, `InteropWorkflowRoleUpdate`, `InteropWorkflowRoleRemove`; `InteropWorkflowMemberAction` (abstract, the composite id) with `InteropWorkflowMemberAdd` (`Consequence` `WORKFLOWMEMBERADD` when the user is active) and `InteropWorkflowMemberRemove`. Each modeled on 3a's user tools; extend 3a's abstract where the shape is shared, or record why a copy reads better.
- **Save routes (new):** `Area/Interop/WorkflowRoleSave.cls` and `Area/Interop/WorkflowMemberSave.cls` beside 3a's `WorkflowUserSave.cls` (the member's parent is its role, as `ItemSave`'s production); `Api/Router.cls` two routes and `Call=` targets beside 3a's.
- **Descriptors (new):** `Screen/Descriptor/InteropWorkflowRoleList.cls` (route `interoperability/workflow-roles`, side bar 26, entity `interop-workflow-role`, id `["Name"]`, primary `add`, rows `edit`, `remove`, `classicPage` `EnsPortal.WFRoles`, `toolIdentifier` `interop.workflowroles`; columns `tableColumnName`, `tableColumnDescription`, `promptGroupCapacity`, `roleEditorTabMembers`); `Screen/Descriptor/InteropWorkflowMemberList.cls` (route `interoperability/workflow-roles/members`, side bar 0, parent `role`, entity `interop-workflow-member`, id `["Role", "User"]`, primary `add`, row `remove`, `classicPage` `EnsPortal.WFRoles`, `toolIdentifier` `interop.workflowmembers`; columns `processColumnUser`, `userColumnFullName`, the new "Rank", `interopPartnerFieldTitle`, `interopColumnActive`; opened from the role's name cell through the shared child-list mechanism, as Batch 1's Alert history). Both `ownPrivileges` `%Ens_WorkflowConfig:READ`.
- **Kernel:** `Kernel/EntityType.cls` both types after 3a's; `Kernel/Governance/Baseline.cls` five keys in name order; `Kernel/Proposal/Prohibited.cls` append-only, as 3a: two `TYPE*`, `COVEREDTYPES` last, the uncovered chain extended at its end, new `PermittedChangeFields` (`Description`, `Capacity`), `PermittedCreateFields` (role `Name`, `Description`, `Capacity`; member `Role`, `User`, `Ranking`, `Title`), create branches and `ReviewedFewOnly` arms.
- **Client (`ui/src/app/`):** `areas/interoperability/interop-workflow-role-list.page.ts`, `interop-workflow-role-dialog.ts`, `interop-workflow-member-dialog.ts`, a store, and specs, extending 3a's page, dialog and store; the members list on the shared list page; the Add member dialog's User is a choice of 3a's `WorkflowUsers` `LIST` less the role's members, Rank a choice of 1 to 5 (default 3), Title text. Add-only entries in `shell/screen-outlet.ts`, `shell/screen-action-handler.ts`, `core/screen-actions.ts`, `core/proposal-view.ts`, `core/strings.ts`; regenerate `screens.generated.ts` and `Screen/Titles.cls`.
- **Tests (new; principal legs armed as 3a's, one add-only `# classes:` line):** extend 3a's `InteropWorkflowCase`, `InteropWorkflowFixture` (`ProbeRole`, `ProbeMember`) and `InteropWorkflowSeam` (a `RemoveUserFromRole` that deletes nothing and answers OK, the member status after a save) add-only; classes `InteropWorkflowRoleList`, `InteropWorkflowRoleControl`, `InteropWorkflowMemberControl`, `InteropWorkflowRoleRefusals`, `InteropWorkflowRoleGate`, `InteropWorkflowRoleElsewhere`; each under 500 lines. Browser `ui/browser/interop-workflow-roles.browser-spec.mjs` (sibling 3a's).
- **Rosters (Rule 30; re-grep `interop.workflowusers`, `InteropWorkflowUser`, `interop-workflow-user`, `/interop/workflow-users` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src`, `scripts/`):** the rosters 3a's Code Map names, each with this batch's rows; `ConfirmNamespaceRoster` `CHECKEDFLOOR` set to the count the walk asks.
- **`README.md`** the count and the off list; **EXPERIENCE.md**: one Fixed strings row after 3a's, once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci` only, USER and HSCUSTOM, auditing on; every probe removed after, by 3a's fixture where it can; record under Design Notes, Measured): (a) each write (role add, edit of each field, remove; member add, remove) writes only the namespace's own database (journal by process id: name the globals) and no vendor audit row (with a positive control); `$ROLES`, `$USERNAME` and `$NAMESPACE` the same after, for a principal without `%All` and for `_SYSTEM`; (b) a principal holding `%Ens_Portal:U`, `%Ens_WorkflowConfig:R` and `%DB_USER:R` reads both lists through `%ExecDirectNoPriv`, and the classic queries (`RoleDefinition:Roles`, `Engine:ListUsersForRole` through `%ResultSet`) answer rows or `#5580`; with `%Ens_WorkflowConfig:W` and `%DB_USER:RW` each write succeeds; with `%DB_USER:R` what the vendor answers; name any further pair; (c) a role remove deletes its memberships through the cascade and leaves a task sent through the role and its worklist items as they were; a member remove deletes the member's worklist items in the role and unassigns the task they own; an add of an active user sends the role's unassigned task, of an inactive user none; `RemoveUserFromRole` of a non-member answers OK; (d) `AddUserToRole` with rank 0, 6 and absent and a title of 129 characters: what the vendor stores or answers; (e) the roles list's time at 2,000, 5,000 and 10,000 probe roles with three members each, and the members list's at 1,000 and 2,000 members of one role: each cap is the largest whose read ends within 5 s here (7.5 s on CI at 1.5 times), never above 10,000 (`WFRoles.cls:113`). HALT `blocked` on 3a's conditions, and if (c) measures otherwise than the consequences say (`intent gap: new string`).
- [ ] `src/OcuPilot/Port/InteropPort.cls`, `src/OcuPilot/Api/InteropError.cls` -- the two endpoints, the lists, fresh reads, five writes, snippets, codes -- 3a's family extended.
- [ ] `src/OcuPilot/Screen/Tool/InteropWorkflowRole*.cls`, `InteropWorkflowMember*.cls`, the two Save classes, `Api/Router.cls`, the two descriptors, `EntityType.cls`, `Baseline.cls`, `Prohibited.cls` -- the tools, routes, screens, types, keys and terms.
- [ ] `ui/src/app/areas/interoperability/interop-workflow-role-*` and `interop-workflow-member-dialog.ts` with specs, the add-only maps, strings and registrations; regenerate the mirror and titles; the EXPERIENCE.md row; `README.md` count and off-list clause with `ui/tools/interop.test.mjs`'s assertion.
- [ ] `src/OcuPilot/Test/InteropWorkflowRole*.cls`, `InteropWorkflowMemberControl.cls`, the case, fixture and seam extensions, `ui/browser/interop-workflow-roles.browser-spec.mjs`, the `# classes:` line and the rosters the sweep names -- the matrix, either order.

**Acceptance Criteria:**

- **AC1 (lists).** Given USER's probe roles and members, when a person opens Workflow roles and Role members and the agent reads both, by role and by user, then each lists exactly its probes in the stated order with the member counts, ranks, titles and active states.
- **AC2 (roles, both callers).** Given USER's probes, when a person's New workflow role and Edit and the agent's confirmed add and update run, then each reads back as sent, an edit changes only the fields sent, and each write has one `ConfigChange` holding no description.
- **AC3 (role remove).** Given a probe role with two members and a task sent through it, when either caller removes it, then the role and its memberships are gone and the task and its worklist items are as they were.
- **AC4 (members, both callers).** Given probe users, when a person's Add member and Remove and the agent's confirmed add and remove run, then an added member reads back with its rank and title (3 and none when absent), an active one is sent the role's unassigned task, and a removed member is gone with its worklist items for the role and its owned task unassigned.
- **AC5 (refusals and gate).** Given each refusal row of the matrix, when either caller writes, then the named code answers before any vendor call, nothing is saved or deleted, and no log line carries a description, a title or a vendor text.
- **AC6 (vendor error).** Given the seam's error status after a member's save, and its remove that deletes nothing, when either caller writes, then the answer is 500 `INTERNAL`, never 200, and the audit row reads `completed` false.
- **AC7 (the proposal's namespace; Integration, Rule 1).** Given same-named probes in USER and HSCUSTOM, when each agent write is minted in USER and confirmed from HSCUSTOM, then it acts in USER only and HSCUSTOM is unchanged.
- **AC8 (rosters, script, switched).** Given the five tools, when `ConfirmNamespaceRoster`, `DraftRegistry` and `Prohibited` run, then each is green with its rows and red with one removed; each draft renders the switch, guards and vendor call and nothing for a bad value; and nothing is logged while switched.
- **AC9 (README).** Given the `false` keys, when `interop.test.mjs` runs, then the README's count and off-list clause hold, and red with the count one less.
- **AC10 (browser).** Given a fresh instance and a probe workflow user, when a person adds a role, adds the user to it with rank 2, removes the member and removes the role, typing its name, then each screen shows each change.
- **AC11 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe workflow row, instance user or principal remains in either namespace.

## Spec Change Log

## Review Triage Log

## Veto items

Each is the lead's to take to the veto gate; the recommended option is first.

1. **New user-facing strings** (reused, each read true here: "Name", "Description" (`tableColumnDescription`), "Capacity" (`promptGroupCapacity`), "Members" (`roleEditorTabMembers`), "User" (`processColumnUser`), "Full name", "Title" (`interopPartnerFieldTitle`), "Active", "Save", "Cancel", "Remove", "Edit <name>", "Remove <name>", "Type <name> to confirm", "Yes"/"No", 3a's source-control sentence once ruled):
   - Labels: "Workflow roles" · "Role members". Buttons and dialog titles: "New workflow role" · "Add member". Column and field: "Rank".
   - Help lines: "A workflow role is a group of workflow users who are sent the same tasks. Capacity, from 1 to 100, is used to report the role's active tasks as a percentage." · "Rank 1 is the highest. The rank and the title can decide which member a task is sent to."
   - Consequences (provisional until Task 0 (c)): `WORKFLOWROLEREMOVE` "Removing this workflow role also removes each of its members from it. Tasks already sent through it are left as they are. It cannot be restored from OcuPilot." · `WORKFLOWMEMBERADD` "An active member is sent each unassigned task of this role." · `WORKFLOWMEMBERREMOVE` "Removing this member deletes their worklist for this role and leaves each task they hold through it unassigned."
   - Refusals: `ROLENAME` "A workflow role name is 1 to 128 characters and holds no control characters." · `ROLETAKEN` "This namespace already has a workflow role with that name, in some letter case." · `ROLEDESCRIPTION` "A description is at most 2,000 characters." · `ROLECAPACITY` "Capacity is a whole number from 1 to 100." · `MEMBERUSER` "This namespace has no workflow user with that name." · `MEMBERTAKEN` "This workflow user is already a member of this role." · `MEMBERRANK` "Rank is a whole number from 1 to 5." · `MEMBERTITLE` "A title is at most 128 characters and holds no control characters."
   - Empty states: "This namespace has no workflow roles." (agent phrase "add a workflow role") · "This workflow role has no members." (agent phrase "add a member to this workflow role").
   - Prompts: "Which workflow roles have no members?" · "Which workflow role has the most members?" · "Add a workflow role for order approvals." · "Which members of this role are inactive?" · "Add a member to this role."
   - README: the count is derived from the Baseline on the tree committed (after 3a, "One hundred and two"; this batch adds one `false` key, or two if veto item 5's alternative is taken). The off-list clause "a schedule spec or a workflow user, purging" becomes "a schedule spec, a workflow user or a workflow role, purging" (with the alternative, "a schedule spec, a workflow user or a workflow role, removing a member from a workflow role, purging"), and `interop.test.mjs`'s assertion takes the same text.
2. **Security posture.** Batch 3a's, unchanged, for both lists and all five writes, including its conditional SQL check (3a's veto item 2). The classic Remove user dialog and Add user dialog require `%Ens_WorkflowConfig:WRITE`, which both member writes ask; WRITE on the namespace's globals database is stricter (inference until Task 0 (b)).
3. **An access grant.** Adding a workflow user to a role makes them a recipient of that role's tasks and of the data those tasks carry. Recommended: an ordinary write behind the confirmation the person sees (developer tool first). Alternative: key `false`.
4. **Values narrower than the classic page.** A capacity outside 1 to 100 is refused (the classic Save stores 100 in its place); a role name held in any letter case is refused; no rename (the classic Save renames by delete and create, dropping every membership); rank 1 to 5, as the classic dialog offers, absent meaning the vendor's 3 (the classic dialog sends an empty rank); a removal of a non-member is refused (the vendor answers it as success).
5. **Governance keys and confirm.** `interop.workflowroles.remove` ships `false`, destructive, typed name. `interop.workflowroles.add`, `.update` and `interop.workflowmembers.add` ship `true`. `interop.workflowmembers.remove` ships `true`, not destructive: the card shows the member's rank and title, and adding them again restores the membership and sends the role's unassigned tasks again. Alternative for the member remove: `false`, destructive with a typed name, since the tasks the member held may be taken by another member meanwhile.
6. **AD amendments (story end, the lead writes them, add-only, `[AMENDED <date>, Story 24.17, Rule 20]`).** AD-62, the item after Batch 3a's: "**Workflow roles and membership** (Story 24.17). `InteropPort` gains `WorkflowRoles` over `EnsLib.Workflow.RoleDefinition` and `WorkflowMembers` over `EnsLib.Workflow.RoleMembership`, behind `%Ens_WorkflowConfig:READ`, the classic page's `RESOURCE`, with a role's add, edit and remove through `%Save` and `%DeleteId` and a member's add and remove through the vendor's `AddUserToRole` and `RemoveUserFromRole`, as the classic page and its dialogs perform them, behind `%Ens_WorkflowConfig:WRITE` and WRITE on the namespace's globals database. A role name held in any letter case is refused, capacity, rank and title are judged before any vendor call, and a removal of a user who is not a member is refused, because the vendor answers it as success." AD-22: "**Story 24.17's Batch 3b keys:** `interop.workflowroles.add`, `interop.workflowroles.update` and `interop.workflowmembers.add` ship `true`, `interop.workflowroles.remove` `false`, and `interop.workflowmembers.remove` as ruled." AD-15, named case: "**A workflow role or membership write** (Story 24.17), which the vendor does not audit, records OcuPilot's own `ConfigChange` from either caller: the namespace, the role and user, the fields changed and whether it completed, never a description or title."

No new dependency; nothing is written into another namespace. A workflow role is not an instance role and grants no privilege (veto item 3 names its task reach).

## Design Notes

**Batch split.** As Batch 3a's Design Notes: 3a is workflow users, this spec is 3b, and Batch 1's items 4 and 5 take `-5.md` and `-6.md`. This spec is planned against HEAD `2ded140f5`, before 3a lands; its implement stage re-reads 3a's spec and Code Map as built.

**Decided in-stage (plan).**

1. Names: endpoints `WorkflowRoles` and `WorkflowMembers`; types `WORKFLOWROLE`, `ADDWORKFLOWROLE`, `SETWORKFLOWROLE`, `REMOVEWORKFLOWROLE`, `WORKFLOWMEMBER`, `ADDWORKFLOWMEMBER`, `REMOVEWORKFLOWMEMBER`; tools `interop.workflowroles.add|update|remove`, `interop.workflowmembers.add|remove`; routes `interoperability/workflow-roles` and `.../members`; Saves `POST /interop/workflow-roles` and `POST /interop/workflow-members`.
2. Members are a sub-screen of a role, as Batch 1's Alert history is of an alert, so their rows are a declared read the agent shares (AD-36). The classic Users and Roles popups are read-only views of membership; the members list's `user` criterion gives the agent a user's roles. No screen offers a user's roles (the Workflow users list shows the count).
3. The list column `Members` is the classic `Users` count, named as `roleEditorTabMembers` reads.
4. The Add member dialog's users come from 3a's list read less the role's members, so no new read and no new privilege.
5. `Members` is in the role remove's fingerprint, so a member added after the review closes the proposal as moved; a member's rank and title are in its remove's.
6. A role edit is not a membership edit: the classic page edits a role's description and capacity only.
7. `Prohibited.cls` as 3a's Decided item 8.
8. Siblings (Rule 31): 3a's whole family; the schedule and partner families through it; `InvokeItems` (composite id); `ListAlerts` and `InteropManagedAlertHistory` (child list and sub-screen).
9. Side-bar position 26; the members sub-screen takes none.

**Governing ADs (Rule 6):** 3a's list.

**Integration and linkage (Rules 1, 2).** Integration: AC7 (the kernel's confirm consumes each stored proposal in its own namespace), AC1's agent leg, and AC4 (the Add member dialog consumes 3a's list). Consumes: Batch 3a's family, the kernel's proposal, confirm, governance and audit. Consumed-by: Batch 4's task list (a role's tasks; inference); Story 24.20's undo (inference). DW-2841 applies through `InteropAction`, as 3a.

**Ledger inbox (Rule 17):** empty at plan; `owned_ledger=0`.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropWorkflowRoleList`, then likewise `InteropWorkflowRoleControl`, `InteropWorkflowMemberControl`, `InteropWorkflowRoleRefusals`, `InteropWorkflowRoleGate`, `InteropWorkflowRoleElsewhere`, 3a's five `InteropWorkflowUser*` classes, `ConfirmNamespaceRoster`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline`, `ClassicPageGate`, `EndpointCoverage`, `SaveHoldCoverage`, and every class the roster sweep changes. Expected: green; new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-workflow-roles.browser-spec.mjs browser/interop-workflow-users.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** 3a's list, plus the Workflow users list's `Roles` count, which this batch's member writes change.

**Hermeticity:** as 3a's.

**Mutations** (as 3a's procedure). Planned: AC1 the `user` criterion ignored -> `InteropWorkflowRoleList` red; AC2 the edit saves every field -> `InteropWorkflowRoleControl` red; AC3 the remove deletes the role by SQL with no cascade -> `InteropWorkflowRoleControl` red (membership leg); AC4 the rank passed as `""` when absent -> `InteropWorkflowMemberControl` red; AC5 the any-case role test made exact -> `InteropWorkflowRoleRefusals` red, the member pair dropped -> `InteropWorkflowRoleGate` red; AC6 the remove's re-read skipped -> `InteropWorkflowRoleRefusals` red (remove-kept leg); AC7 `PortQuery` drops the proposal's namespace -> `InteropWorkflowRoleElsewhere` red; AC8 a `DraftRegistry` row removed -> red, a log line in a switched block -> red, the new arm placed first -> `Prohibited` red; AC9 the README count typed one less -> `interop.test.mjs` red; AC10 the member dialog sends no rank -> the browser spec red; AC11 `DropProbes` skips the probe roles -> the case's after-all check red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan.** Batch 3b of the story: Workflow roles and Role members through `InteropPort`, with New workflow role, Edit, Remove, Add member and Remove, reached by the screen and the agent, extending Batch 3a's family. Dispatched after 3a lands. Veto items 1 to 6; decided-in-stage under Design Notes. Read-only check on `ocupilot-b-ci` as 3a's. Nothing was written to the instance.
