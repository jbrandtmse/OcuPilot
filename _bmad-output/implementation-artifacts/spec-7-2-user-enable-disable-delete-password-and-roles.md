---
title: 'Story 7.2: User enable, disable, delete, password and roles'
type: 'feature'
created: '2026-09-22'
status: 'done'
baseline_revision: '584172aa9bf05f103bd75ce8f1adcb2cfebee556'
baseline_commit: '584172aa9bf05f103bd75ce8f1adcb2cfebee556'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: ['oversized']
deferred:
  - 'AD-56 (i) "the change-on-login flag is its own update write, sent first": measured on ocupilot-ci, a CHANGEPWD (Security.Users.Modify with Password) clears ChangePassword, so the flag sent first alone ends cleared. The client re-sends it after the password lands (flag, password, flag); the spine sentence and the agent path (a password proposal and a flag proposal, in either order) need the same rule.'
  - 'AC4 names `%Admin_Secure` as a role to add; it is a resource on this build and no role carries that name, so the add is 400 (unknown role) before the prohibited set. The privileged-add legs use `%All` and `%Manager` (a role carrying `%Admin_Secure:U`).'
  - 'The armed last-holder `%All` strip is pinned through the tool delta plus `Operation.Gate` in-process (UserUpdate.TestAnAllStripOfTheLastHolderIsRefusedAtTheSharedGate): the census is armable only in the test process, never in the web server serving the route.'
  - 'Prohibited.cls-test port: `WithoutAuthoredSecrets` taken byte-for-byte from Epic 8 (its absence already reddened TestNoWriteToolAdmitsAnAlwaysProhibitedField after the lead port 771b08b); the action-write secret check was restated for AD-56 (i).' 
  - summary: >-
      DESIGN.md publishes the command bar at a fixed `{spacing.command-bar-height}` (50px) with no narrow-width rule; the rework makes 50px a minimum and lets the bar wrap, which DESIGN.md should state.
    evidence: |-
      The Users list's bar measures 898px on one line (filter, count, six row actions, sort, Refresh) against a 640px content minimum; EXPERIENCE.md keeps every row action on the bar and adds no copy, so wrap is the one treatment left. The wrap rule is borrowed from DESIGN.md's Home tiles (inference that it extends to the bar). For the lead: a Rule 5 apply-and-report restatement of DESIGN.md's `command-bar` entry.
    location: >-
      ui/src/styles/_components.scss (appended `.ocu-command-bar` rule); DESIGN.md `command-bar`
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The Users list declares no action (`UserList.cls` `rowActions []`), so a person can do
none of FR-37's five account jobs from it, while the agent can already enable, disable and change
roles through `permissions.users.update` (5.9) and can neither delete an account nor set its
password. Worse, the prohibited set's account arms fire only on a *disable*
(`Prohibited.User` gates them on `Disables(pPayload, pChanged)`), so a bodyless delete of
`_SYSTEM`, the signed-in account, a service account or the last `%All` holder would pass straight
through -- the AD-53 "predicate over the payload, not the effect" hole 7.1 closed for web
applications. And every account refusal sentence says "not something the agent can propose"
(DW-1499), which is false once a screen caller reaches it.

**Approach:** Two callers of one operation, on 7.1's seam. `UserList` declares six row actions
(enable, disable, set password, add role, remove role, delete). Enable, disable and the two role
actions run `permissions.users.update`; delete runs a new action-style `permissions.users.delete`;
set password runs a new `permissions.users.password` over the vendor's `CHANGEPWD` type, its
password a secret supplied once -- in the dialog or at the card's confirm -- and never stored. The
prohibited set's account arms are restated over the effect, and every sentence they return is
caller-neutral and published once.

## Boundaries & Constraints

**Always:** The prohibited set stays in `Kernel/Proposal/Prohibited.cls` and refuses whatever the
caller (AD-10, AD-53); a surface only explains a refusal. Deleting or disabling `_SYSTEM`, the
signed-in account, a service account (`SERVICEACCOUNTS`) or the last `%All` holder is refused for a
delete exactly as for a disable. A password exists only as a request-scoped local: never stored in a
proposal, a ledger row, a log line, a status, a fingerprint, a diff or any read answer, never
pre-filled, never echoed, pasted text never trimmed (AD-21, AD-35, Conventions › Secrets). Every
write's pair set is `UserList`'s own -- `%Admin_Secure:USE` plus `%DB_IRISSYS:READ` -- never
`:WRITE` (AD-8). Account ids go through the identity layer's `user:foldcase` rule at mint, confirm,
row action and change event (AD-13). One AD-14 change event per write; the list re-fetches in place.
Merge writes reuse `permissions.users.update`; no second path writes `Enabled` or `Roles`. A role
action applies **one role** as a delta over the server's fresh read, never a client-computed list.

**Never:** No self-protection predicate in a screen, descriptor or route. No new copy authored in
`strings.ts` that EXPERIENCE.md's Fixed strings table does not publish; `strings.ts` is
SHARED-APPEND -- add keys at its end, touch none this story did not add. No entry of
`AdminPort.cls` this story did not add is rewritten. No edit under Epic 8's exclusive footprint
(`scripts/ci-*.sh`, `.github/workflows/ci.yml`, `Install/**` but `Smoke.cls`,
`areas/web-applications/**`, `Kernel/Secret/Ladder.cls`, `ui/tools/field-lists.*`), so no new
*armed* test class (its arming roster lives in `scripts/ci-throwaway.sh`). No user editor is built
here (Story 9.1's). No agent marker on the screen's path (AD-15, AD-53).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Row enable / disable | ordinary account selected | `POST /screens/permissions.users/action` runs it through `permissions.users.update`; one `(user, instance, <name>)` `updated` event; row re-fetched in place and marked | No error expected |
| Row delete | name typed exactly in the typed-name dialog | one `deleted` event; row gone; focus to the grid | Mismatch: `formTypedNameMismatch`, `aria-invalid`, nothing sent |
| Delete or disable a protected account, screen | `_SYSTEM`, the signed-in user, or `CSPSystem` selected | both surfaces list the action non-selectable with that account's published sentence inline; pressing sends nothing | Route called anyway: 403 with the same sentence and its `PROHIBITED.*` code |
| Delete the last `%All` holder, screen | the only enabled holder, not the signed-in user | the client cannot know the census, so the action is offered | 403 `PROHIBITED.LASTALLHOLDER` with its published sentence, rendered on the list's refusal line |
| Delete a protected account, agent | `permissions.users.delete` for `_system` | refused at the write inside the transition; canonical form asked | `PROHIBITED.SYSTEMACCOUNT` (AD-39) |
| Set password, screen | new password pasted with a trailing space, flag checked | the flag write, then `CHANGEPWD` with `{NewPassword}` exactly as pasted; one `updated` event; the field empties | Flag refused: nothing else sent. Password refused (policy): the vendor's refusal as a published sentence; the flag stays set |
| Set password, agent | `permissions.users.password` minted | card shows no diff value for the password; its masked field is filled at confirm | Confirm without it: `aria-disabled` with `proposalSecretsRequired`; channel refuses any other key |
| Add a privileged role | `%All`, a `%Admin_*` role, or a custom role recursing to one | offered, never hidden; this story adds no refusal and no test asserting one (owner decision 2026-09-23: permitted at typed confirmation, Epic 8's predicate change) | the instance's answer, whatever it is on the branch |
| Remove `%All` from the last holder | row action remove-role `%All` | refused | 403 `PROHIBITED.LASTALLHOLDER` |
| Concurrent role change | another session added role X after the list loaded; this user adds Y | the write holds X and Y | No error expected (delta over fresh read) |


**Orchestrator rulings, 2026-09-23 (binding; the three intent gaps are closed).**

1. AC4 is amended (`epics.md` Story 7.2) by the owner, superseding the earlier ruling: a grant of
   `%All`, a `%Admin_*` role or a role carrying them is permitted at typed confirmation. Epic 8 owns
   the predicate, the confirmation level and `privilegedGrantEffect`; this story adds no refusal of
   its own, hides no role, and tests Add/Remove role with a non-privileged role only.
2. **AD-56** (spine) is the write shape: (i) an action write may send a body made only of its
   declared secret arguments (`CHANGEPWD` takes exactly `{NewPassword}`), supplied at the write,
   never stored, fingerprinted over a declared subject of the fresh read; (ii) a screen action
   accepts values only under names its tool declares, a role change is a server-side delta over a
   fresh read, and the change-on-login flag is its own `update` write sent first. **No second secret
   channel:** the secret travels under the descriptor's existing `secretArguments` declaration (AD-55,
   on Epic 8's branch). Epic 8's Story 8.2 owns the widening of that declaration in
   `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs` and `ui/tools/screen-mirror.test.mjs`; this
   story does NOT write its own version -- the lead ports 8.2's hunks byte-for-byte before the
   implement stage starts, and the plan builds on them.
3. `UserList.cls` is contended: this story adds only `rowActions`, reuses 8.2's
   `secretArguments: ["Password"]` line verbatim, and never touches `primaryAction` or
   `emptyAgentKey` (8.2 sets `emptyAgentKey: "userListEmptyAgent"` = "create a user",
   `EXPERIENCE.md:404`, published by the lead; the `strings.ts` key is this story's shared append).
4. `Prohibited.ReasonFor`'s `PRIVILEGEGRANT` sentence is Story 8.2's; this story consumes it and
   publishes only the four caller-neutral account refusals (`EXPERIENCE.md:398-401`), the delete
   consequence (`:402`) and the labels (`:403`), all published by the lead; the role dialog is added
   to `:173`'s dialog list. The lead has **already appended and verified** (`npm run test:tools`
   1,322/0) the `strings.ts` keys for them -- consume, do not re-author: `userRefusalCurrentUser`,
   `userRefusalSystemAccount`, `userRefusalServiceAccount`, `userRefusalLastAllHolder`,
   `userDeleteConsequence`, `userActionSetPassword`, `userPasswordChangeOnLogin`, `userActionAddRole`,
   `userActionRemoveRole`, `userRoleField`, `userListEmptyAgent`.
5. **DW-1486 folds in, as one restructure with the delete hole** (AD-10 amended 2026-09-23): every
   account predicate -- current user, `_SYSTEM`, the service account, the last `%All` holder -- is
   evaluated by effect for a delete, a disable and a `Roles` delta that strips `%All`, with a test per
   arm that fails when that arm's predicate is removed. `Prohibited.cls` is contended (Epic 8 added
   ~122 lines): read `git show origin/OCU-1-epic8:src/OcuPilot/Kernel/Proposal/Prohibited.cls` first
   and stay off its hunks.
6. AC1's editor half is DW-1501, routed to `9-1-the-user-editor`; this story ships the row-menu half.
</intent-contract>

## Code Map

Line anchors are this branch's (`OCU-1-epic7` at `220c6a3`). ⚠ = contended with Epic 8: read
`git show origin/OCU-1-epic8:<path>` first and stay off its hunks.

### Server

- ⚠ `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `SERVINGPATHREASON` :58 (the parameter-held
  sentence to copy); codes :74-94; `ReasonFor` :211-230 (agent-worded account sentences :221-224);
  `PermittedChangeFields` :277 (user :280); `Prohibits` :344 (`Target` answers `tToolClass` :369,
  the user dispatch :379-381); `User` :523-578 (name arms gated by `Disables` :529);
  `Disables` :964; `DePrivilegesLastAllHolder` :983 (role path :989-995); `RolesGrantAll` :1017;
  `LastAllHolder` :1059 (overridable census seam); `IsServiceAccount` :1141; `SERVICEACCOUNTS` :162;
  `Changed` :1211 skips `SkippedFields` :1322 (state label + fingerprint subject). Epic 8's hunks:
  header doc :6-11, after `AlwaysProhibitedFields` :298, inside `Prohibits` between :370 and :371,
  after `UncoveredWriteTools` :439. Nothing of Epic 8's touches `ReasonFor`, `User` or :379-381.
- `src/OcuPilot/Api/ScreenAction.cls` -- `Handle` reads `{action, id}` only; `Run` computes
  `ScreenActionArguments` before the pair gate, reads fresh, `Body` (merge, or projection +
  `StateDiff` for an action write), prohibited gate, `Apply` with
  `$Select(tSendsBody: tPayload, 1: "")`.
- `src/OcuPilot/Kernel/Proposal/Operation.cls` -- Epic 7's own (7.1). `Gate`, `Apply`, `SendsBody`.
- ⚠ `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- `Set tBody = ""` :357 then
  `If tSendsBody Set tBody = ..WithSecrets(...)` :358; Epic 8 inserts one line after :358.
  `ChannelProblem` :428 (closed to the descriptor's `secretArguments`), `FieldNames` :701 (drops
  declared secret names from the ledger).
- ⚠ `src/OcuPilot/Screen/Tool/Write.cls` -- `SCREENACTIONS` grammar :125-140, `ScreenActionIds`
  :196, `ScreenActionArguments` :216, `SecretArguments` :388 (the descriptor's list). Epic 8 adds
  after `CHANGEACTION` :124, after `ChangeAction()` :193, rewrites `InputSchema`, appends at end.
- `src/OcuPilot/Screen/Tool/UserUpdate.cls` -- `PERMITTEDFIELDS "Enabled"`, authored `Roles`.
- `src/OcuPilot/Screen/Tool/WebAppDelete.cls` -- the action-write shape to copy.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` :128-132 refuses a declared secret from the model;
  :170-192 pushes `StateDiff` rows into the diff.
- ⚠ `src/OcuPilot/Port/AdminPort.cls` -- `MUTATINGTYPES` :173, `BODYLESSTYPES` :189,
  `EndpointType` :837, `ImplementsRead` :862 (`Security.User` overrides `Run`, so every type
  reads implemented), the object-body refusal :460 then `RunSequence` :466 in `Invoke`.
- ⚠ `src/OcuPilot/Screen/Registry.cls` -- `SELFPROTECTIONRULES` :2154, `ConfirmChannelProblem`
  :1993, `DeclaredNames` :2270, `ToolFieldRows` :2485; table empty-key rule :1896-1906 (a
  write-capable list names `emptyAgentKey`, `emptyNextKey` empty).
- `src/OcuPilot/Screen/Descriptor/UserList.cls` -- `rowActions []`, no `secretArguments`,
  `emptyNextKey "tableReadOnlyEmptyNext"`, `emptyAgentKey ""`. `RoleList.cls` is built on the
  same pairs, endpoint `Security.Role`.
- `src/OcuPilot/Screen/Tool/Classification.cls` :46-69 -- the `permissions.users.update` entry.
- Measured on `ocupilot-slot-a`: `Security.User` `GET` answers 16 names (`AccountNeverExpires`,
  `AutheEnabled`, `ChangePassword`, `Comment`, `EmailAddress`, `Enabled`, `ExpirationDate`,
  `FullName`, `HOTPKeyDisplay`, `NameSpace`, `PasswordNeverExpires`, `PhoneNumber`,
  `PhoneProvider`, `Roles`, `EscalationRoles`, `Routine`) and no `Name`. `CHANGEPWD` takes exactly
  `{NewPassword}` and sets only the password. A trailing space passes `PasswordPattern` 3.255ANP (8.2's measurement; `" "?1P` is 1).

### Client

- `ui/src/app/shell/screen-action-handler.ts` -- `SCREEN_ACTION_DESCRIPTORS`,
  `DESTRUCTIVE_CONSEQUENCES`, `start`, `send` (`{action, id}`), `PendingConfirm`.
- `ui/src/app/core/self-protection.ts` `selfProtectionReason(rule, rowKey)`; callers
  `data-table.ts:667`, `command-bar.ts:397`, `command-box.ts:490`, the handler :139.
  `ui/tools/screen-mirror.mjs:313` `IMPLEMENTED_SELF_PROTECTION_RULES`;
  `ui/tools/self-protection.test.mjs` reads `Roster.cls` from the repo (the pin idiom).
- `ui/src/app/core/session.ts:430` `userName()`.
- `ui/src/app/core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS`. A declared action with no
  registered handler is drawn by no surface (DW-389: `data-table.ts:665`, `command-bar.ts:389`,
  `command-box.ts:484`).
- `ui/src/app/shell/list-page.ts` renders `pending()`; `typed-name-dialog.ts`, `dialog.ts`;
  `change-password-dialog.ts` (15.1's masked field and reveal toggle, the pattern to reuse).
- `ui/src/app/core/proposal-view.ts` `payloadSecrets` :349 -- the card asks for a declared secret
  only when a diff row names it; `proposal-card.ts` :199-215 masked inputs.
- `ui/src/app/core/strings.ts` -- the ruling's keys are appended (:1338-1365).

### Tests

- `src/OcuPilot/Test/UserUpdate.cls` (armed, 877 lines) -- account fixtures, `Refused`,
  `ProhibitedFixture.Ask`/`UserObject`/`Diff`, census arming.
- `src/OcuPilot/Test/ProhibitedByEffect.cls` (unarmed, 519 lines) -- fixture-port set tests.
- ⚠ `src/OcuPilot/Test/ProhibitedRoute.cls` :1533 -- the "one write verb on users" tripwire this
  story trips on purpose.
- `src/OcuPilot/Test/RefusalCopy.cls`; ⚠ `Test/SurfaceCoverage.cls`.
- `ui/browser/users.browser-spec.mjs`, `users-write.browser-spec.mjs`,
  `web-applications-actions.browser-spec.mjs` (the row-action precedent).

## Tasks & Acceptance

**Execution:**

*Prohibited set (DW-1486, DW-1499, AD-10 as amended):*

- `Prohibited.cls` `User` + `Prohibits` :380 -- pass `RemovesOf(tToolClass)` (the tool's
  `ChangeAction() = "deleted"`; a class that cannot be asked reads as a removal, the fail-closed
  direction) into `User`. `User` computes one effect: a removal, a disable (`Disables`), or a
  `Roles` delta that strips `%All` (`Roles` changed, `RolesGrantAll` true over the target's roles
  and false over the payload's). When it holds, the `_SYSTEM`, signed-in, service-account and
  last-holder arms run in that order; `DePrivilegesLastAllHolder` folds into it. The escalation,
  grant and reviewed-few arms follow unchanged. Rewrite the code and method doc comments that say
  "disable" to say the effect.
- same file -- `SYSTEMACCOUNTREASON`, `CURRENTUSERREASON`, `SERVICEACCOUNTREASON`,
  `LASTALLHOLDERREASON` after `SERVINGPATHREASON`, each the published row
  (`EXPERIENCE.md:398-401`, equal to `strings.ts` `userRefusal*`); `ReasonFor` returns them.
  `PRIVILEGEGRANT`'s sentence is untouched (ruling 4).
- same file `PermittedChangeFields` -- user becomes `Enabled, Roles, ChangePassword`; the doc
  states AD-10 forbids no change to `ChangePassword`.

*Tools:*

- `src/OcuPilot/Screen/Tool/UserDelete.cls` (new) -- `permissions.users.delete` on
  `WebAppDelete`'s shape: `WRITETYPE "DELETE"`, `SENDSBODY 0`, `CHANGEACTION "deleted"`,
  `DESTRUCTIVE 1`, `SCREENACTIONS "delete"`, `PRECONDITIONFIELD "Enabled"`,
  `FINGERPRINTSUBJECT "Enabled,FullName,Roles"`, removal-row `StateDiff`, the screen's pairs.
- `src/OcuPilot/Screen/Tool/UserPassword.cls` (new) -- `permissions.users.password`:
  `WRITETYPE "CHANGEPWD"`, `SENDSBODY 0`, `SECRETBODY "Password"`, `STATEFIELD "Password"`,
  `PRECONDITIONFIELD`/`FINGERPRINTSUBJECT "Enabled"`, `SCREENACTIONS "set-password"`,
  `SCREENVALUES "set-password=Password"`; `StateDiff` answers one row
  `{field:"Password", before:"", after:""}` so the card masks it and asks for it; no settable field.
- `UserUpdate.cls` -- `PERMITTEDFIELDS "Enabled,ChangePassword"` (and `DESCRIPTION`);
  `SCREENACTIONS "enable=Enabled:true,disable=Enabled:false,require-password-change=ChangePassword:true,add-role,remove-role"`,
  `SCREENVALUES "add-role=Role,remove-role=Role"`; override `ScreenActionDelta` to build `Roles`
  from the fresh read plus or minus the one role (case-insensitive match, the instance's spelling
  kept). Refused 400 `TOOL.ARGUMENTS`: an add of a held role, a remove of an unheld one, and an add
  of a name `Security.Role` `GET` through the tool's port answers 404 for.
- ⚠ `Write.cls` -- after `SecretArguments` :393 (and the parameters after `READANSWERS` :153),
  off Epic 8's hunks: `SECRETBODY` and `SCREENVALUES` parameters, `SecretBodyNames()`,
  `ScreenActionValueNames(pActionId)`, and `ScreenActionDelta(pActionId, pValues, pFresh, Output
  pArgs, Output pProblem)` whose default answers `ScreenActionArguments`. Empty defaults leave every
  shipped tool byte-identical.
- `Operation.cls` -- `SecretBody(pToolClass, pSupplied, pSecretNames)`: `""` unless the tool
  declares `SECRETBODY`; otherwise an object holding each `SECRETBODY` name that is also a declared
  secret and was supplied, under that name, and nothing else.
- ⚠ `Confirm.cls:357` -- `Set tBody = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tToolClass, pSuppliedSecrets, tSecretNames)`;
  the one line, so :358 and Epic 8's insert after it are untouched. `FieldNames` then records no
  field for the password write.
- `ScreenAction.cls` -- `Handle` accepts `{action, id, values}`; `values` absent or an object of
  strings keyed only by `ScreenActionValueNames(action)`, every declared name present; any other
  body key or value name is 400 `TOOL.ARGUMENTS` before any read. A name that is a declared secret
  goes to a local passed to `Operation.SecretBody` at the write and nowhere else; the rest go to
  `ScreenActionDelta` after the fresh read, whose answer is held to `SettableFields` as the static
  arguments are. Values are never trimmed, logged or echoed.
- ⚠ `AdminPort.cls` -- append `Security.User/DELETE,Security.User/CHANGEPWD` to `MUTATINGTYPES`
  and `Security.User/DELETE` to `BODYLESSTYPES`; add `RENAMEDTYPES =
  "Security.User/CHANGEPWD=Password:NewPassword"` and apply it in `Invoke` after the object-body
  refusal, on a copy, before `RunSequence`. 8.2's `WRAPPEDTYPES` lands at the same point.
- ⚠ `Classification.cls` + `node tools/field-lists.mjs` -- a `permissions.users.password` entry:
  `fieldList "Security.User"`, the update entry's classification map, `authored {"Password":
  "secret"}` (AD-3). Needs 8.2's `authored` grammar (Design Notes).

*Descriptor, registry and mirror:*

- `UserList.cls` -- `rowActions` in order enable, disable (`protected-account`), set-password,
  add-role, remove-role, require-password-change, delete (`protected-account`); 8.2's
  `"secretArguments": ["Password"]` line verbatim; the header's "declares no action" sentence
  replaced. `primaryAction` untouched. The empty keys per Design Notes.
- ⚠ `Registry.cls` `SELFPROTECTIONRULES` and ⚠ `screen-mirror.mjs:313` -- add
  `protected-account`; regenerate `screens.generated.ts`.

*Client:*

- `self-protection.ts` -- `selfProtectionReason(rule, rowKey, signedIn = '')`; `protected-account`
  answers `userRefusalSystemAccount`, `userRefusalCurrentUser`, `userRefusalServiceAccount` in the
  server's order, else `''`; `SERVICE_ACCOUNTS` mirrored. The four callers pass
  `Session.userName()`.
- `screen-action-handler.ts` -- `UserList` on the roster; `delete` consequence
  `userDeleteConsequence`; `require-password-change` registers no menu handler; `PendingConfirm`
  becomes a union (typed-name, set-password, role); `send` takes optional `values`. Set password
  sends `require-password-change` first when the box is checked and stops on its refusal, then
  `set-password` with `values.Password`, then drops the value.
- `ui/src/app/shell/set-password-dialog.ts` (new) -- 15.1's masked field and reveal toggle
  (`accountNewPasswordLabel`, `accountShowPassword`/`accountHidePassword`),
  `autocomplete="new-password"`, empty and focused on open, `value` read untrimmed, cleared on
  close; `userPasswordChangeOnLogin` checkbox; submit disabled while empty.
- `ui/src/app/shell/role-dialog.ts` (new) -- one role in a native `select` labeled
  `userRoleField`: add lists `permissions.roles`' read names minus the row's roles (AD-5, "issue
  another built screen's read"); remove lists the row's `Roles`. No pre-mark; the instance decides.
- `list-page.ts` renders all three dialogs from `pending()`; `screen-actions.ts` adds the UserList
  labels `userActionSetPassword`, `userActionAddRole`, `userActionRemoveRole`.

*Tests:*

- `ProhibitedByEffect.cls` -- `TestEveryAccountArmRefusesEveryRemovalEffect`: {signed-in,
  `_SYSTEM`, service account, last holder (census armed)} x {delete, disable, `%All` strip} through
  `ProhibitedFixture.Ask`, each leg asserting its code, plus an ordinary account permitted for all
  three and a non-`%All` role change on `_SYSTEM` permitted.
- `UserUpdate.cls` -- route legs on a probe account: the six actions and the flag; delete and
  disable of `_SYSTEM`, the caller and `CSPSystem` 403 with the parameter sentence; `%All` strip on
  the armed last holder 403; `%All`/`%Admin_Secure` add 403 `PRIVILEGEGRANT`; an undeclared
  `values` key 400 with nothing written; agent legs: password mint refuses a `Password` argument,
  stores no password, confirm with `{Password}` sets it (`Security.Users.CheckPassword` in `%SYS`);
  delete confirm removes the account; after either write no ledger row, proposal row, `^ERRORS`
  or OcuPilot log line holds the password; a token minted for the probe is refused after its delete.
- `RefusalCopy.cls` -- each of the four codes answers its parameter and names no caller.
- `ui/tools/self-protection.test.mjs` -- each `*REASON` parameter equals its `strings.ts` key;
  `SERVICE_ACCOUNTS` equals `SERVICEACCOUNTS`; the rule's answers per account.
- ⚠ `ProhibitedRoute.cls:1533` -- roster becomes {update, delete, password}; the live leg adds a
  bodyless `_SYSTEM` delete asked of the shipped set (nothing minted). ⚠ `SurfaceCoverage.cls` --
  two rows, names read from the instance. Any other roster that reddens is updated.
- Specs: `screen-action-handler.spec.ts`, `set-password-dialog.spec.ts`, `role-dialog.spec.ts`,
  `list-page.spec.ts`, `screen-mirror.test.mjs`.
- `ui/browser/users-actions.browser-spec.mjs` (new) -- `resetRememberedState`; probe account
  created and removed by exact name through `docker exec`.

**Acceptance Criteria:**

- **AC1.** Given a selected user, when enable, disable, delete, set password, add role or remove
  role is run from the row menu or the command bar, then it reaches
  `POST /screens/permissions.users/action`, one AD-14 event is published, and the list re-fetches
  in place. (The editor half is DW-1501, Story 9.1.)
- **AC2.** Given the set-password dialog, when it opens, then the field is empty, masked and
  focused with a change-on-login checkbox; pasted text is sent byte for byte once; and no read,
  change event, proposal, ledger row or log holds it afterwards.
- **AC3.** Given `_SYSTEM`, the signed-in account or a service account, when disable or delete is
  attempted, then both surfaces draw it refused with the published sentence and the route answers
  403 with the same sentence; the last `%All` holder is refused on the instance for delete,
  disable and a remove-role of `%All`.
- **AC4.** Given `%All`, a `%Admin_*` role or a role reaching one, when the person picks it in Add
  role, then it is offered and this story adds no refusal of its own (owner decision 2026-09-23:
  such grants are permitted at typed confirmation, which Epic 8 implements); adding and removing a
  non-privileged role works from the screen as a delta over the fresh read.
- **AC5 (Integration, Rule 1).** Given a probe account on the throwaway, when the Users list served
  by `ListPage` disables and re-enables it, sets its password, adds and removes an ordinary role and
  deletes it, then each change re-fetches in place and `POST /api/ocupilot/login` with the new
  password answers 200 before the delete.
- **AC6 (DW-1486).** Given each account predicate and each removal effect (delete, disable, a
  `Roles` delta stripping `%All`), when the set is asked, then it refuses with that predicate's
  code, and each leg reddens when its predicate or its effect term is removed.
- **AC7.** Given `permissions.users.password` or `permissions.users.delete` minted by the agent,
  when confirmed (the password typed on the card), then the write lands, a marker and an event are
  emitted, and the password is in no stored argument, payload, diff value or ledger field.

### Review Findings

Code review 2026-09-23 (first review; four layers, full-opus). Lead-directed patch applied: the
route's `%All`/`%Manager` add legs expecting 403 `PRIVILEGEGRANT` removed from
`Test/UserUpdate.cls` (the only such leg this story added; Story 5.9's refusal legs untouched). This
story adds no refusal of its own for a privileged add (`UserUpdate.ScreenActionDelta` refuses only
empty, held, unheld and unknown roles) and hides no role (`openRole` offers every read row not held;
`screen-action-handler.spec.ts` offers `%Operator`). `privilegedGrantEffect` is not on the branch, so
no consequence line was added. AC4's text above still reads the pre-reversal refusal; it is the
lead's to amend.

| # | Finding | Sev | Fix-risk | Footprint | Disposition |
|---|---|---|---|---|---|
| F1 | Set password and the change-on-login flag are permitted on `_SYSTEM`, the signed-in account and a service account (blind+edge) | med | low (one effect term) | in-story | `decision-pending` DW-1520 owner=burndown: AD-10 scope is a product call |
| F2 | The held-`%All` term of `RemovesAdministration` is unpinned against over-refusal (verification-gap) | low | low | in-story | patched: control leg in `ProhibitedByEffect` |
| F3 | `SecretBody`'s empty-value branch is unexercised (verification-gap) | low | low | in-story | patched: one assertion in `ToolWrite` |
| F4 | AC4's `mutation:` line pinned the removed privileged legs (verification-gap, Rule 19) | low | low | in-story | closed in-pass: AC4 row rewritten |
| F5 | `self-protection.test.mjs` "no signed-in name" assertion cannot fail (verification-gap) | low | low | in-story | patched: assertion removed |
| F6 | The no-password confirm leg asserted only not-OK (blind) | low | low | in-story | patched: code asserted `PORT.VALIDATION` |
| F7 | `ScreenAction.Values` carries a redundant loop before its length check (blind) | low | low | in-story | patched: one check; route leg for `values: {}` added |
| F8 | Doc comments say the flag is sent first only (acceptance) | low | low | in-story | patched: `UserPassword`, `UserUpdate` |
| F9 | `RemovesOf` doc claims a class naming no action reads as a removal (acceptance) | low | low | in-story | patched |
| F10 | `Write.ScreenActionDelta` contract says it reads nothing; the override reads `Security.Role` (acceptance) | low | low | in-story | patched |
| F11 | Three account refusal sentences say "Disabling or deleting" for a `%All` strip (blind+edge+acceptance) | low | low | out-of-footprint (EXPERIENCE.md copy) | `wontfix-accepted` DW-1521 |

- [ ] [Review][Decision] F1 -- AD-10's account arms fire on delete, disable and a `%All` strip only; a new password or a forced change on `CSPSystem` (inference) stops the gateway's sign-in. Ledgered DW-1520 for the decision sheet; does not block `done`.
- [x] [Review][Patch] F2 [src/OcuPilot/Test/ProhibitedByEffect.cls:591]
- [x] [Review][Patch] F3 [src/OcuPilot/Test/ToolWrite.cls:467]
- [x] [Review][Patch] F4 [spec `## Verification`, AC4 row]
- [x] [Review][Patch] F5 [ui/tools/self-protection.test.mjs:148]
- [x] [Review][Patch] F6 [src/OcuPilot/Test/UserUpdate.cls:1228]
- [x] [Review][Patch] F7 [src/OcuPilot/Api/ScreenAction.cls:366]
- [x] [Review][Patch] F8 [src/OcuPilot/Screen/Tool/UserPassword.cls:13]
- [x] [Review][Patch] F9 [src/OcuPilot/Kernel/Proposal/Prohibited.cls:620]
- [x] [Review][Patch] F10 [src/OcuPilot/Screen/Tool/Write.cls:451]
- [x] [Review][Defer] F11 [src/OcuPilot/Kernel/Proposal/Prohibited.cls:65] -- deferred: the copy is EXPERIENCE.md:398-400's; DW-1521 `wontfix-accepted`

Rejected:

- `low` A self password set through the admin path: the caller holds `%Admin_Secure:USE`, which already permits it; no harm.
- `false` Remove-role declares no `selfProtection`: only a `%All` strip is refused, so marking the action would refuse permitted removes.
- `low` A confirm with no password burns the proposal: the card holds confirm `aria-disabled` until the secret is typed; direct API only.
- `low` The first flag write stays set when the password is refused: specified (I/O row "the flag stays set", AD-56).
- `low` `openRole` silent on no read, a non-`rows` answer or a truncated read: the Roles screen is built with a read; more than 1,000 roles is unlikely.
- `low` The roles read resolving after cancel or after another dialog opened: unlikely, and the fix adds a guard.
- `low` An added role keeps the client's spelling: already adjudicated in the triage log.
- `low` A non-404 role lookup renders 500: the role read uses the same pairs the fresh user read just passed.
- `low` The `Prohibited` roster checks `SecretBody` only for tools declaring none: `ToolWrite` pins the one declaring tool, extra key included.
- `false` The route path's ledger is unchecked for the password: the route writes no ledger or proposal row; its logs are checked.
- `low` Browser gaps (signed-in row, protected delete, the flag): the component specs and the route legs pin each.
- `low` Enable and disable are both offered whatever the row's state: specified.
- `false` A non-array `Roles` in the fresh read drops held roles: the vendor `GET` answers an array; a string is only the model's payload shape.
- `low` Agent-password test cleanup skipped on an early return: failure path only.
- `low` A numeric secret canonicalized on the confirm channel: the card sends strings, and the route refuses non-strings.
- `low` AC7's marker not asserted for these tools: the marker is `Confirm`'s, pinned by `AuditMarker.TestAConfirmedWriteIsMarked`.
- `low` `UserPassword`'s card row names a field no read answers: specified by AD-56 (i) and the Tasks.
- `med` The agent path does not order the flag after the password: DW-1516, already harvested, not re-filed.

**Rework iteration 1 (2026-09-23, lead, CI):**

- [x] [CI] `browser`, run 35828196362 on e5b7e1b: `ui/browser/panel.browser-spec.mjs:759` `not ok 104`
  "the 640px content minimum ... on the Users list": at 1,280px with the panel at its maximum the
  content region is 640 wide but scrolls to 938 (`contentScrollWidth`; docked, 911 against 832), so
  "the content does not scroll" fails at `:776`. Before this story the Users list fit. The cause is
  what this story added to the Users list (inference: the command bar now carries six row actions
  and does not collapse); fix it at its cause per DESIGN.md and EXPERIENCE.md's command-bar rule,
  never by relaxing the assertion, and run `panel.browser-spec.mjs` plus the story's own browser
  specs against a rebuilt, redeployed bundle.

## Spec Change Log

- 2026-09-23, lead spec gate: intent gap 1 ratified as recommended (b) -- `epics.md` Story 7.2 AC4
  amended under Rule 5 tier-1 on the orchestrator's identical 8.2 AC3 ruling: privilege grants are
  refused on the instance whatever the caller. Gaps 2 and 3 answered by the orchestrator the same
  day (rulings in the intent block; AD-56 and the AD-10 amendment written to the spine; copy
  published at `EXPERIENCE.md:173,398-404`); DW-1486 re-owned here; `status` reset to `draft` to re-plan.

- 2026-09-23, lead: AC4 rewritten to the owner's reversal (offered, no refusal of this story's own);
  re-opened for one rework iteration on CI run 35828196362's `browser` failure.

## Review Triage Log

### 2026-09-22 — Review pass

- verdicts: 22 findings — high 0, medium 5, low 10, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` VG1: the signed-in account's refusal is untested on the row menu, command bar and command box — added one leg each (`data-table`, `command-bar`, `command-box` specs, `Session` stubbed); dropping `this.signedIn()` at the three call sites reddened exactly those three.
  - `[medium]` `[patch]` VG2: the route's stray-key, non-object `values`, non-string value and empty-value refusals are unexercised — four legs added to `UserUpdate.TestEveryRowActionReachesTheRouteAndChangesTheAccount`; opening the stray-key check reddened its leg.
  - `[low]` `[patch]` VG3: a password confirm with no password is untested — measured on `ocupilot-ci` the vendor answers `{}` with 400 `PORT.VALIDATION`; leg added (undeclared key refused by the channel, empty confirm refused, old password still signs in).
  - `[low]` `[reject]` VG4: the ported `WithoutAuthoredSecrets` floor lets a bodyless user tool's confirm channel accept `Password` — the write drops it (`SecretBody` answers `""`), nothing is stored or sent; closing it needs a new guard in Epic 8's AD-55 channel.
  - `[low]` `[reject]` VG-other: `openRole` shows nothing when the Roles read answers `ok` without `rows` — the read route always answers `rows`; unlikely.
  - `[low]` `[reject]` VG-other: an added role is written in the client's spelling — the dialog offers the Roles list's own spelling, so the everyday path writes the instance's.
  - `[false]` `[reject]` VG-other: `TestEveryAccountArmRefusesEveryRemovalEffect` depends on `$Username` — it asserts the precondition first, so it cannot pass vacuously; green on `ocupilot-ci`.
  - `[low]` `[reject]` IA: the last-holder delete is pinned at the kernel, not the route — the census is armable only in the test process; `ProhibitedByEffect` and the shared-gate leg cover it (spec `deferred:` item 3).
  - `[low]` `[reject]` IA: the last-holder `%All` strip rebuilds the route's steps rather than calling it — same root cause as the row above.
  - `[low]` `[reject]` IA: no agent delete of a protected account is minted and confirmed — a live confirm against `_SYSTEM` or a service account would delete it under any mutation; the set call the transition makes is pinned live by `ProhibitedRoute`.
  - `[low]` `[reject]` IA: no card spec for the password proposal — the card's secret masking is 5.10's generic `proposal-card.spec`, and the server legs pin the row, the channel and the confirm.
  - `[false]` `[reject]` IA: set password sends three writes and three events — AD-14 is one event per write and the intent's own flag-then-password is already two; the re-assert is what makes the flag hold (spec `deferred:` item 1).
  - `[medium]` `[patch]` IA: the bar and box half of AC3's "both surfaces" is untested — grouped with VG1, same patch.
  - `[low]` `[reject]` IA: no Users-specific typed-name mismatch leg — the same `TypedNameDialog` and handler path 7.1 pins.
  - `[low]` `[reject]` IA: the route legs assert the action, not the event triple or the row mark — the handler publishes the route's own triple generically (7.1's `list-page.spec`).
  - `[medium]` `[patch]` IA: "the password is nowhere" is checked on the agent path only — `AssertNotLogged` (`^ERRORS`, `messages.log`, now asserting the log opens) runs after the route's `set-password` too.
  - `[false]` `[reject]` IA: seven declared actions against six — the spec's Tasks declare `require-password-change` undrawn.
  - `[false]` `[reject]` IA: the add-role dialog depends on the Roles screen's gate — specified ("issue another built screen's read", AD-5).
  - `[false]` `[reject]` IA: `permissions.users.update` admits `ChangePassword` — specified (`PERMITTEDFIELDS "Enabled,ChangePassword"`).
  - `[false]` `[reject]` IA: `RemovesOf` fails closed beyond the three effects — specified ("a class that cannot be asked reads as a removal").
  - `[false]` `[reject]` IA: edits beside Epic 8's hunks in `UserList`, `AdminPort`, `Confirm`, `Prohibited` — each is the spec's or the lead's instruction, listed as footprint extensions.
  - `[medium]` `[defer]` IA: on the agent path a password confirmed after a flag proposal clears the flag — a vendor fact; the fix is AD-56's sentence, which only the lead amends (spec `deferred:` item 1).

## Design Notes

**Governing ADs (Rule 6):** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10 (amended 2026-09-23), AD-13,
AD-14, AD-15, AD-21, AD-27, AD-31, AD-34, AD-35, AD-37, AD-39, AD-40, AD-41, AD-51, AD-52, AD-53,
AD-55, AD-56, Conventions › Secrets. AD-49 does not apply: an administrator sets another account's
password through the admin API.

**The secret: one declaration, two names.** The descriptor's `secretArguments` holds `Password`
(8.2's line); the vendor's `CHANGEPWD` key is `NewPassword`. The kernel carries `Password`
everywhere -- the card's field, the confirm channel, the route's `values`, `SecretBody`,
`FieldNames`' exclusion -- and `AdminPort.RENAMEDTYPES` renames it on the wire, beside 8.2's
`WRAPPEDTYPES`, because the vendor's key is a wire fact (AD-27). Renaming in the tool would put
`NewPassword` in the body `FieldNames` records, outside the declared-secret exclusion.

**What 7.2 needs from 8.2's widening, and the named risk.** 8.2's Registry/mirror widening
accepts a `secretArguments` name that is a top-level `secret` row of a `permissions.users.*`
`ToolFields` entry. On this branch no such row exists unless a Classification entry authors one,
which needs 8.2's `authored` grammar in `Classification.cls`, `ui/tools/field-lists.mjs` and
`ui/tools/field-lists.test.mjs` -- beyond the three files the rulings name, and field-lists is
Epic 8's exclusive file. **Risk: the lead's pre-implement port must include those grammar hunks**;
without them `UserList`'s `secretArguments` is refused at registration and at `npm run build`.
7.2 then adds only its own `permissions.users.password` entry; if the port also brings 8.2's
`permissions.users.create` entry, both stay.

**Ruling 3 versus the table rule.** A list that declares a row action must name `emptyAgentKey`
and leave `emptyNextKey` empty (`Registry.cls:1896-1906`, `screen-mirror.mjs:2170`), so
`rowActions` cannot land alone. If the port carries 8.2's `UserList` lines, 7.2 leaves them;
otherwise it writes `"emptyNextKey": ""` and `"emptyAgentKey": "userListEmptyAgent"`
byte-identical to 8.2's, so the merge collapses them and no value diverges.

**The flag is a declared, undrawn action.** AD-56 makes it its own `update` write sent first.
`require-password-change` is declared so the route admits it and has no menu handler, so no
surface draws it (DW-389); only the dialog sends it.

**PRIVILEGEGRANT's sentence.** Consumed as 8.2's (ruling 4). Until 8.2 lands, the screen's refused
add-role renders today's agent-worded `ReasonFor` text on the refusal line: the DW-1499 residual.

**Delete consequences (AD-37).** A deleted account's token is refused by the authentication-time
read (`Kernel/Identity.IsEnabled` answers 0 for an unknown account) and its turn stops at the next
step boundary (AD-31); pinned by the token leg rather than rebuilt.

**Contended edits** (footprint extensions): `Prohibited`, `Write`, `Confirm`, `AdminPort`,
`Registry`, `Classification`/`ToolFields`, `screen-mirror.mjs`, `ProhibitedRoute`,
`SurfaceCoverage`, `screens.generated.ts`. `ProhibitedRoute:1533` also reddens under 8.2's create;
the merge reconciles the roster to four.

**Ledger inbox (Rule 17).** DW-1486 -- addressed (Execution's first task, AC6). DW-1499 --
addressed for `SYSTEMACCOUNT`, `CURRENTUSER`, `SERVICEACCOUNT`, `LASTALLHOLDER`; declined for
`PRIVILEGEGRANT` (8.2's, ruling 4) and for the process and web-application codes no screen caller
on this branch reaches. Recommend re-owning that residual to `8-2-create-a-user` and `7-8` at
adjudication. DW-1501 -- routed to 9.1; out of scope.

**Consumes:** 7.1 (route, `Operation`, handler, typed-name dialog, rule vocabulary), 5.9
(`permissions.users.update`, census), 5.10 (card masking), 15.1 (masked-field pattern), 8.2's
widening and `authored` grammar (ported by the lead). **Consumed-by:** 9.1 (editor actions, via
DW-1501), 7.8 (`SCREENVALUES` for terminate's flag), 8.2 at merge (shared `UserList` lines).
**Integration ACs:** AC5.

## Verification

Slot A's throwaway `ocupilot-ci` (web 52776, super 1975) for every stateful or destructive check;
IRIS MCP calls carry `server: "ocupilot-slot-a"`; one test class per call, never two in one
message, never a re-submit on a client timeout.

**Targeted (loop):**

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>`, one at a time, for
  `OcuPilot.Test.UserUpdate`, `ProhibitedByEffect`, `RefusalCopy`, `ProhibitedRoute`, `Prohibited`,
  `SurfaceCoverage`, `ToolWrite`, `ToolRoundTrip`, `Descriptor`, `DerivedFields`,
  `EndpointCoverage` -- expected: 0 failures each.
- `cd ui && npm run test:tools && npm run test:components` -- expected: 0 failures.
- `cd ui && node tools/field-lists.mjs --check && node tools/screen-mirror.mjs --check && node tools/client-lint.mjs && node tools/browser-reset.mjs` -- expected: no drift.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`,
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/users-actions.browser-spec.mjs browser/users.browser-spec.mjs browser/users-write.browser-spec.mjs`
  -- expected: all pass.
- `uv run scripts/check-objectscript.py <changed paths>`; `bash scripts/lint-docs.sh` -- clean.

**Once, before `dev_complete`:** the full ObjectScript sweep on `ocupilot-ci`, per class, totals
checked against `%UnitTest_Result` with the numeric-run-index probe -- 0 failures, non-zero count.
The full browser suite is not run locally (Rule 29).

**Pinning tests and mutations (Rule 19; the implementer records what was observed):**

| AC | Pinning test | Mutation | Observed |
|---|---|---|---|
| AC1 | `users-actions` row-menu leg per action | drop `UserList` from `SCREEN_ACTION_DESCRIPTORS` | mutation: roster entry removed, bundle rebuilt and redeployed → both `users-actions` tests red |
| AC2 | `users-actions` paste leg (login with `pw1 ` answers 200, `pw1` 401); `UserUpdate` no-residue leg | trim the value in `send`; store it in `Mint` stored arguments | mutation: `password.trim()` in `submitPassword`, rebuilt → paste leg red ("one request carrying the value byte for byte"); mutation: `Confirm` logs the secret body (the `Mint` variant is unreachable, the schema refuses a `Password` argument first) → `TestTheAgentsPasswordAndDeleteLandAndThePasswordIsNowhere` red on "no messages.log line holds it" |
| AC3 | `UserUpdate` route legs; `self-protection.test.mjs` | return `''` from `protected-account`; edit one `*REASON` word | mutation: `protected-account` answers `''` → `self-protection.test.mjs` per-account test red; mutation: one word of `CURRENTUSERREASON` → the one-sentence test red (the route legs compare against the parameter, so only the pin catches a word edit) |
| AC4 | `UserUpdate.TestEveryRowActionReachesTheRouteAndChangesTheAccount` non-privileged add/remove legs (the privileged-add legs were removed at code review, owner decision 2026-09-23) | build `Roles` from the value alone in `UserUpdate.ScreenActionDelta` | mutation: the fresh-read loop in `ScreenActionDelta` gated `If 0`, reloaded on `ocupilot-ci` → the concurrent-change leg ("the concurrently added one survived", "so did the original") and the remove legs red |
| AC5 | `users-actions` integration leg | drop the `values` member from `send` | mutation: `values` never set on the request, rebuilt → integration leg red |
| AC6 | `ProhibitedByEffect` arm test | remove each arm's predicate, then each effect term, in turn | mutation: each of the four arms and each of the three effect terms (`pRemoves`, `Disables`, the `%All` strip) gated off in turn, reloaded with subclasses → `TestEveryAccountArmRefusesEveryRemovalEffect` red naming exactly that arm's three legs or that effect's four |
| AC7 | `UserUpdate` agent legs | remove `Security.User/CHANGEPWD` from `RENAMEDTYPES` | mutation: `RENAMEDTYPES` emptied → confirm answers `PORT.VALIDATION`, sign-in legs red in both the route and the agent methods |

Review patches: mutation: `this.signedIn()` dropped at the three surfaces → the three new `data-table`/`command-bar`/`command-box` legs red (AC3); mutation: stray-key check opened in `ScreenAction.Handle` → the stray-key route leg red; mutation: flag re-sent after a refused password → the handler's policy leg red.

Code review patches: mutation: `If 'tHeldGrants Quit` removed from `Prohibited.RemovesAdministration` → `ProhibitedByEffect.TestEveryAccountArmRefusesEveryRemovalEffect` red on the new service-account ordinary-add control alone; mutation: the empty-value `Continue` removed from `Operation.SecretBody` → `ToolWrite.TestTheUserPasswordToolSendsOnlyItsDeclaredSecret` red on "an empty password is not sent". Each applied to the `/tmp/ocupilot-ci/src` copy only, loaded, observed red, then the copy re-synced from the worktree (`diff -r` identical) and reloaded.

Rework iteration 1 (CI item): mutation: the appended `.ocu-command-bar` rule removed, bundle rebuilt and redeployed → `panel.browser-spec.mjs` "the 640px content minimum ..." red alone (10/11, "and the content does not scroll", 898 !== 640); mutation: `height: auto` removed from that rule, rebuilt and redeployed → the same leg red on "the command bar grows to hold every line its six row actions wrap onto" (bar bottom 187 against controls at 217), content scroll still 640.

Every mutation was reverted and the original reloaded (or the bundle rebuilt and redeployed);
`git diff --stat` read the same before and after.

## Auto Run Result

Status: done
Blocking condition: none

This records rework iteration 1 only. The first pass's record is in commit f4345af.

**Change.** The CI item is fixed at its cause. The command bar laid its controls out on one line
with no wrap. On the Users list that line is 898px wide: the filter, the count, the six row
actions, Sort and Refresh. It was measured by walking the deployed page's content region at
1,280px. The rule appended to `_components.scss` lets the bar wrap and grow (`flex-wrap: wrap`,
`height: auto`, `min-height` at the command-bar height, block padding, `border-box`), and on one
line the bar is still 50px. No row action is hidden and no copy is added. The Web applications
list fits at 832 and wraps only at the 640 maximum.

**Files.**

- `ui/src/styles/_components.scss`: one rule appended at the end. The original rule is not ours to edit (shared-append), so the appended rule overrides it.
- `ui/browser/panel.browser-spec.mjs`: the 640px leg now also asserts, on the Users list at the maximum, that the bar contains every control and that the list starts below it.

**Review.** 11 findings: high 0, medium 3, low 4, false 4.

- Patched (medium, one root cause): nothing checked that a wrapped bar grows to hold its lines (verification-gap and intent-alignment). Fixed by the `commandBarBox` assertions, with a demonstrated mutation.
- Deferred (medium): DESIGN.md gives the bar a fixed 50px, and the fix makes that a minimum. See `deferred:` item 5; it is for the lead to restate DESIGN.md.
- Rejected (low):
  - One-line 50px height unpinned: no screen in the leg stays on one line, so a pin needs a new leg on another list. The pre-existing pin was the same token check.
  - The original rule's `height` is dead: it can only be removed by editing a shared-append entry this story does not own.
  - The Refresh chip loses its right edge when the bar wraps (two rows): none of the bars that wrap carries the chip. The Users bar's controls were listed and it has none.
- Rejected (false):
  - Mutation line not written: written in `## Verification` by this stage.
  - The fix changes a shared class: the dispatch required the fix to hold for the Web applications list if the shared component was at fault.
  - The "34px border box" comment: `.ocu-button-text` is a 32px content box plus its 1px border on each side, which is 34px.
  - The cause was not measured: the descendant walk found it, and with the fix the content scroll width equals the client width (832 and 640).

followup_review_recommended: false. This is a follow-up pass and no `high` was patched; the patched
entries were one medium, in the test only.

**Verification (tiers run).** The bundle was rebuilt and redeployed to `ocupilot-ci`.

- Browser: `panel.browser-spec.mjs` 11/11; `users-actions`, `users` and `users-write` 9/9; `web-applications-actions` 3/3.
- `test:tools` 1,327/0 and `test:components` 858/0.
- Rule 19: two mutations were observed red and reverted; they are recorded in `## Verification`. After each revert the tree was byte-identical and the bundle was rebuilt and redeployed.
- No ObjectScript changed, so no ObjectScript sweep was run. The full browser suite was not run (Rule 29).

**footprint_extensions:** none new. `ui/src/styles/_components.scss` is shared-append; this story's
entry is at the end. Epic 8 also appends there (43 lines), so expect an append-append merge
contact. Epic 8 has not modified `ui/browser/panel.browser-spec.mjs` (checked with `git diff --stat dd70e59 origin/OCU-1-epic8`).

**Residual risks:**

- A bar that wraps is taller, so the list gets less height. The Users list's bar is 88px at the default docked width.
- The 640 fit on the Web applications list rests on the implementer's measurement. No assertion pins it.
