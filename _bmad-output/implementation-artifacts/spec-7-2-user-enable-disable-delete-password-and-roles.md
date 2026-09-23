---
title: 'Story 7.2: User enable, disable, delete, password and roles'
type: 'feature'
created: '2026-09-22'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: ['oversized']
deferred: []
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
| Add a privileged role | `%All`, a `%Admin_*` role, or a custom role recursing to one | refused on the instance for both callers (reading per Gap 1) | 403 `PROHIBITED.PRIVILEGEGRANT` |
| Remove `%All` from the last holder | row action remove-role `%All` | refused | 403 `PROHIBITED.LASTALLHOLDER` |
| Concurrent role change | another session added role X after the list loaded; this user adds Y | the write holds X and Y | No error expected (delta over fresh read) |


**Orchestrator rulings, 2026-09-23 (binding; the three intent gaps are closed).**

1. AC4 is amended (`epics.md` Story 7.2): a grant of `%All` or any `%Admin_*` role is refused on
   the instance whatever the caller.
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
- **AC4.** Given `%All`, a `%Admin_*` role or a role reaching one, when it is added by either
  caller, then the instance refuses it `PROHIBITED.PRIVILEGEGRANT`, while adding and removing any
  other role works from the screen as a delta over the fresh read.
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

## Spec Change Log

- 2026-09-23, lead spec gate: intent gap 1 ratified as recommended (b) -- `epics.md` Story 7.2 AC4
  amended under Rule 5 tier-1 on the orchestrator's identical 8.2 AC3 ruling: privilege grants are
  refused on the instance whatever the caller. Gaps 2 and 3 answered by the orchestrator the same
  day (rulings in the intent block; AD-56 and the AD-10 amendment written to the spine; copy
  published at `EXPERIENCE.md:173,398-404`); DW-1486 re-owned here; `status` reset to `draft` to re-plan.

## Review Triage Log

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

| AC | Pinning test | Mutation |
|---|---|---|
| AC1 | `users-actions` row-menu leg per action | drop `UserList` from `SCREEN_ACTION_DESCRIPTORS` |
| AC2 | `users-actions` paste leg (login with `pw1 ` answers 200, `pw1` 401); `UserUpdate` no-residue leg | trim the value in `send`; store it in `Mint` stored arguments |
| AC3 | `UserUpdate` route legs; `self-protection.test.mjs` | return `''` from `protected-account`; edit one `*REASON` word |
| AC4 | `UserUpdate` privileged-add legs | skip `GrantsPrivilege` in `User` |
| AC5 | `users-actions` integration leg | drop the `values` member from `send` |
| AC6 | `ProhibitedByEffect` arm test | remove each arm's predicate, then each effect term, in turn |
| AC7 | `UserUpdate` agent legs | remove `Security.User/CHANGEPWD` from `RENAMEDTYPES` |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Re-planned against the 2026-09-23 rulings: AD-56 secret-only action write with the `Password` to
`NewPassword` rename in the port, a closed `values` channel on the screen route, the DW-1486
restructure by effect with per-arm legs, and the published copy consumed rather than authored.
Named risk: the lead's port must carry 8.2's `authored` grammar as well as its widening (Design
Notes). Nothing was implemented; nothing was committed.
