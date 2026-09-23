---
title: 'Story 7.2: User enable, disable, delete, password and roles'
type: 'feature'
created: '2026-09-22'
status: 'blocked'
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

</intent-contract>

## Code Map

### Server

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- CONTENDED. `ReasonFor` `:136-155` (the account
  sentences `:141`, `:146-149`); `SERVINGPATHREASON` `:58` is the parameter-held precedent;
  `Prohibits` `:269-333`, which already holds the resolved tool class from `Target` `:294`; `User`
  `:374-429`, whose three name arms sit inside `If ..Disables(...)` `:380`;
  `DePrivilegesLastAllHolder` `:467-487` (`tReaches` starts from `Disables`); `Disables` `:448`;
  `SERVICEACCOUNTS` `:162`. Epic 8 inserts at `:223` (after `AlwaysProhibitedFields`), after `:295`
  (inside `Prohibits`) and after `UncoveredWriteTools` -- keep off those hunks. Epic 8 does not touch
  `ReasonFor` or `User`.
- `src/OcuPilot/Screen/Tool/UserUpdate.cls` -- 5.9's merge tool, `PERMITTEDFIELDS "Enabled"`,
  authored `Roles`. Gains `SCREENACTIONS` and `ChangePassword` as a reviewed field.
- `src/OcuPilot/Screen/Tool/WebAppDelete.cls` -- the action-style delete to copy
  (`WRITETYPE`, `SENDSBODY 0`, `CHANGEACTION`, `DESTRUCTIVE`, `READANSWERS`, `PRECONDITIONFIELD`,
  `FINGERPRINTSUBJECT`, `StateDiff`, `PrivilegePairs`).
- `src/OcuPilot/Screen/Tool/Write.cls` -- CONTENDED. `SCREENACTIONS` `:140` and its grammar
  (`enable=Enabled:true,...`), `ScreenActionIds` `:196`, `ScreenActionArguments` `:216`,
  `SecretArguments` `:388` (delegates to the descriptor; a tool may override it). Epic 8 edits
  `:115-130`, adds methods after `ChangeAction` and rewrites `InputSchema` `:416-431` -- append only,
  at the end of the class.
- `src/OcuPilot/Api/ScreenAction.cls` -- 7.1's route. `Handle` reads `{action, id}` only; `Run`
  refuses any declared argument outside `SettableFields`, gates pairs, reads fresh, builds the
  body (`Body`, via `Mint.Merge`), gates the prohibited set, applies.
- `src/OcuPilot/Kernel/Proposal/Operation.cls` -- CONTENDED. The shared `Read`/`Gate`/`Apply`.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- CONTENDED. `ChannelProblem` `:148` closes the confirm
  channel to `Registry.SecretArguments(tool)` `:233`; `WithSecrets` `:611` merges them into the body
  only when `tSendsBody` `:358`. Epic 8 inserts one line directly after `:358` -- any edit here must
  be reconciled at merge; prefer a hook both callers reach through `Operation`.
- `src/OcuPilot/Port/AdminPort.cls` -- SHARED-APPEND. `MUTATINGTYPES` `:173`, `BODYLESSTYPES` `:189`.
  Measured 2026-09-23 on `ocupilot-slot-a` (`GetTextAsString` of the hidden class):
  `%Api.Admin.Endpoints.Security.User` overrides `Run` (so `ImplementsRead` answers 1 for every
  type), `RunDelete` 404s an absent name then `Security.Users.Delete`, `TYPECHANGEPWD` is 10,
  `NeedsRequestBody()` is true for it, its validator's schema is exactly `{"NewPassword": ""}`, and
  `RunChangePassword` sets only `Password` -- it carries no change-on-login flag.
  `ChangePassword` is a `PUT` template field (`literal|boolean`, pinned by `Test/DerivedFields.cls`).
- `src/OcuPilot/Screen/Descriptor/UserList.cls` -- `primaryAction`/`rowActions` empty,
  `emptyNextKey "tableReadOnlyEmptyNext"`, `emptyAgentKey ""`. Epic 8's 8.2 will set
  `primaryAction create` and the same two empty keys.
- `src/OcuPilot/Screen/Registry.cls` -- `SELFPROTECTIONRULES` `:2154` (`serves-ocupilot`),
  validated at `:2167-2190`.
- `src/OcuPilot/Kernel/EntityRef.cls` -- `IDRULES` `:59` already carries `user:foldcase`.

### Client

- `ui/src/app/shell/screen-action-handler.ts` -- `SCREEN_ACTION_DESCRIPTORS`, `DESTRUCTIVE_ACTIONS`,
  `DESTRUCTIVE_CONSEQUENCES`, `start` (self-protection then dialog), `send` (`{action, id}` only).
- `ui/src/app/core/self-protection.ts` -- `selfProtectionReason(rule, rowKey)`; mirrors the roster,
  pinned by `ui/tools/self-protection.test.mjs`. `ui/tools/screen-mirror.mjs` `:313`
  `IMPLEMENTED_SELF_PROTECTION_RULES`. `ui/src/app/core/session.ts` `userName()` `:430` is the
  signed-in account.
- `ui/src/app/shell/typed-name-dialog.ts`, `ui/src/app/shell/dialog.ts`, `ui/src/app/shell/list-page.ts`
  (renders `pending()`) -- the delete dialog, reused as is.
- `ui/src/app/shell/change-password-dialog.ts` -- 15.1's masked-secret-field and reveal toggle
  (`accountNewPasswordLabel`, `accountShowPassword`, `accountHidePassword`); the pattern to reuse,
  not the component (it proves the old password; this does not).
- `ui/src/app/core/screen-actions.ts` -- `ACTION_LABELS` `:61`, `DESCRIPTOR_ACTION_LABELS` `:81`.
- `ui/src/app/shell/proposal-card.ts` `:199-215` -- the card's masked secret fields and
  `proposalSecretsRequired`, already built (Story 5.10).

### Tests

- `src/OcuPilot/Test/UserUpdate.cls` -- 877 lines, armed by `OCUPILOT_ALLOW_PRINCIPALS`, owns the
  account fixtures (`ProposalFixture` `USERTARGET`, `USERALLHOLDER*`) and the `%All` census seams.
- `src/OcuPilot/Test/RefusalCopy.cls` -- the serving-path sentence pin to extend.
- `src/OcuPilot/Test/SurfaceCoverage.cls` (CONTENDED, Epic 8 +2 lines) -- the write-tool roster.
- `src/OcuPilot/Test/Prohibited.cls` (CONTENDED) `TestTheSetHasOneHomeAndOneSentencePerCode` `:460`.
- `ui/browser/users.browser-spec.mjs`, `ui/browser/users-write.browser-spec.mjs`,
  `ui/browser/web-applications-actions.browser-spec.mjs` (the row-action precedent).

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- make a **removal** reach every account arm the
  disable reaches: `_SYSTEM`, the signed-in account, a service account and the last `%All` holder
  (`DePrivilegesLastAllHolder`'s `tReaches`), deciding "removal" from the resolved tool's declared
  `ChangeAction() = "deleted"`, never from the payload -- AD-53's effect rule.
- same file -- hold each account sentence (`CURRENTUSER`, `SYSTEMACCOUNT`, `SERVICEACCOUNT`,
  `LASTALLHOLDER`, `PRIVILEGEGRANT`) in a `…REASON` parameter, caller-neutral, equal to its
  published row, `ReasonFor` returning the parameter (DW-1499).
- `src/OcuPilot/Screen/Tool/UserDelete.cls` (new) -- `permissions.users.delete`, action-style over
  `Security.User` `DELETE`, `DESTRUCTIVE`, `CHANGEACTION "deleted"`, `SCREENACTIONS "delete"`,
  subject and precondition read from the live `GET` (identity excluded, AD-51).
- `src/OcuPilot/Screen/Tool/UserPassword.cls` (new) -- `permissions.users.password` over `CHANGEPWD`,
  declaring `NewPassword` its one secret argument (tool-level `SecretArguments`), body exactly
  `{NewPassword}` (Gap 2), fingerprint over a declared subject of the fresh read.
- `src/OcuPilot/Screen/Tool/UserUpdate.cls` -- admit `ChangePassword`; declare `SCREENACTIONS` for
  `enable`, `disable`, the flag's two values, `add-role` and `remove-role`; the role pair apply one
  named role as a delta over the fresh read; declare no secret argument, so its confirm channel
  stays closed to `NewPassword`.
- `src/OcuPilot/Api/ScreenAction.cls`, `src/OcuPilot/Kernel/Proposal/Operation.cls` -- admit a
  caller-supplied value only under a name the tool declares for that action (the role name; the
  tool's secret), refuse any other key 400, and merge a secret only at the write, as confirm does
  (Gap 2).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` `PermittedChangeFields` -- add `ChangePassword` to
  the account's reviewed few; AD-10 forbids no change to it.
- `src/OcuPilot/Port/AdminPort.cls` -- APPEND `Security.User/DELETE` (to `MUTATINGTYPES` and
  `BODYLESSTYPES`) and `Security.User/CHANGEPWD` (to `MUTATINGTYPES`).
- `src/OcuPilot/Screen/Descriptor/UserList.cls` -- declare the six row actions in command-bar order,
  destructive last, `disable` and `delete` carrying `selfProtection "protected-account"`; set
  `emptyNextKey ""` and `emptyAgentKey "userListEmptyAgent"`.
- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/core/self-protection.ts`
  -- add `protected-account` to the closed vocabulary on both sides; the client answers the matching
  sentence for `_SYSTEM`, `Session.userName()` and the mirrored service accounts, `''` otherwise.
- `ui/src/app/shell/screen-action-handler.ts` -- add `UserList` to the roster and its delete
  consequence; open the set-password dialog and the role dialog (Gap 3) for their actions, sending
  their value in the request body; the flag write precedes the password write.
- `ui/src/app/shell/set-password-dialog.ts` (new) -- masked field with reveal toggle, never
  pre-filled, `value` read untrimmed, cleared on close, the change-on-login checkbox; nothing sent
  until submit.
- `ui/src/app/shell/role-dialog.ts` (new, per Gap 3) -- one role from the instance's roles list
  (add) or the row's roles (remove); `%All` and `%Admin_*` names drawn unavailable with the
  `PRIVILEGEGRANT` sentence; the instance decides.
- `ui/src/app/core/strings.ts` -- APPEND the keys for the rows the lead publishes (Design Notes).
- `src/OcuPilot/Test/UserUpdate.cls` -- the screen-route and agent legs of every I/O row, the
  removal arms over the census seam, and the password's no-residue check (ledger, proposal row,
  error log carry no password). Tests go here because a new armed class needs a roster line in
  `scripts/ci-throwaway.sh`, Epic 8's exclusive file.
- `src/OcuPilot/Test/RefusalCopy.cls`, `ui/tools/self-protection.test.mjs` -- pin each account
  sentence server-parameter = client-string = caller-neutral, and the service-account mirror to
  `SERVICEACCOUNTS`.
- `src/OcuPilot/Test/SurfaceCoverage.cls` -- the two roster rows, names read from the instance.
- `ui/browser/users-actions.browser-spec.mjs` (new) -- AC1-AC4 against `ocupilot-ci`.

**Acceptance Criteria:**

- Given a selected user, when any of the six actions is run from the row menu or the command bar,
  then it reaches `POST /screens/permissions.users/action`, one AD-14 event is published and the
  list re-fetches in place preserving sort, filter, selection and scroll.
- Given the set-password dialog, when it opens, then the masked field is empty and focused, pasted
  text is sent byte-for-byte once, the change-on-login checkbox is present, and neither the list
  read, the tool's read, the change event, the proposal, the ledger nor the error log afterwards
  holds the password.
- Given the signed-in account, `_SYSTEM` or a service account, when disable or delete is attempted
  from any surface or the route, then the surfaces draw it non-selectable with the published
  sentence and the instance refuses it with the same sentence; given the last `%All` holder, the
  instance refuses both, and the role removal that would strip it.
- Given `%All`, a `%Admin_*` role, or a role recursing to one, when it is added through the agent
  or the screen, then the instance refuses it `PROHIBITED.PRIVILEGEGRANT`, while adding and
  removing any other role works from the screen (reading per Gap 1).
- Integration AC (Rule 1): the Users list, served by `ListPage` through the generic handler on a
  real throwaway, disables and re-enables a fixture account, sets its password (then signs in
  with it), adds and removes an ordinary role and deletes it, each re-fetched in place; and the
  agent's `permissions.users.delete` and `permissions.users.password` proposals, confirmed, reach the
  same account.

## Spec Change Log

- 2026-09-23, lead spec gate: intent gap 1 ratified as recommended (b) -- `epics.md` Story 7.2 AC4
  amended under Rule 5 tier-1 on the orchestrator's identical 8.2 AC3 ruling: privilege grants are
  refused on the instance whatever the caller. Gaps 2 and 3 are with the orchestrator.

## Review Triage Log

## Design Notes

**Intent gaps (why this spec is `blocked`).** Each has a recommended answer the spec above is
already written to; ratifying all three should need no re-plan.

1. **AC4 contradicts AD-10 as literally read.** "Refused through the agent … while the screen's own
   role management remains available to a privileged user" reads either as (a) the screen may grant
   `%All`/`%Admin_*`, or (b) role management stays available and privilege grants are refused
   whatever the caller. (a) contradicts AD-10 ("adding `%All` or any `%Admin_*` role to any user",
   "whatever the caller") and AD-53 (one prohibited set, two callers). Recommend (b), and a Rule 5
   tier-1 amendment of 7.2 AC4 on the orchestrator's 2026-09-23 ruling for the identical 8.2 AC3
   (precedent 7.8 AC2): "refused on the instance whatever the caller; such grants stay a
   classic-portal action in Release 1".
2. **The password write fits neither write kind, and the screen route carries no caller value.**
   `CHANGEPWD` takes exactly `{NewPassword}`: not AD-4's complete property set, not AD-51's "sends
   no body". And AD-53's route today sends only `{action, id}`, while set password and the role
   actions need a value the person supplies. Recommend a Rule 20 spine entry covering both: (i) an
   action-style write may send a body made **only** of its declared secret arguments, supplied at
   the write (confirm or dialog), never stored, fingerprinted over a declared subject of the fresh
   read; (ii) a screen action admits caller values only under names its tool declares for that
   action -- secrets under the confirm channel's own closure (AD-6), an ordinary value validated as
   the tool's schema validates it -- and a list-valued field is changed by a server-side delta, never
   a client-computed replacement. The change-on-login flag is a separate `update` write because the
   vendor type cannot carry it; it goes first, so a failure leaves a forced change against the old
   password rather than an unforced temporary one.
3. **UX surface and copy.** EXPERIENCE.md `:173` lists every dialog ("Dialogs exist only for …") and
   has no role dialog, while `:155` files add/remove roles under actions without a surface "(User
   editor)"; and the Fixed strings table publishes none of this story's copy. Recommend amending
   `:173` with a role dialog, and publishing (tier 1, as for 7.1's `:395-397`): the five
   caller-neutral account refusals -- CURRENTUSER "This is the account you are signed in as.
   Disabling or deleting it would lock you out."; SYSTEMACCOUNT "_SYSTEM is the instance's own
   predefined account. Disabling or deleting it is not available here."; SERVICEACCOUNT "The
   instance's own services run as this account. Disabling or deleting it would stop them, OcuPilot
   included."; LASTALLHOLDER "This is the last account that holds %All. Disabling it, deleting it or
   taking the role off it would leave nobody able to administer this instance."; PRIVILEGEGRANT
   "Granting an administrative privilege, to an account or through a web application, is not
   available in this release. Use the classic portal."; the delete consequence "Deleting this user
   removes the account and every role it holds. This cannot be undone."; the labels "Set password",
   "Require a password change at next sign-in", "Add role", "Remove role", "Role"; and the invitation
   `userListEmptyAgent` "create a user".

**Governing ADs (Rule 6).** AD-3 (authored secret argument; empty derived list for the bodyless
delete), AD-4 (the role and flag writes merge over a fresh read), AD-5 (row actions and their
self-protection rule), AD-6 (proposal, fingerprint, closed confirm channel), AD-8 (screen pairs,
`USE`), AD-10 (removal arms; privilege grants whatever the caller), AD-13 (`user:foldcase`), AD-14,
AD-15 (marker on the agent path only), AD-21/AD-35/Conventions › Secrets (password), AD-34, AD-39
(one published sentence per code), AD-40, AD-51, AD-52 (default `AdminPort`), AD-53. AD-49 does
**not** apply: this is an administrator setting another account's password through the admin API,
the route AD-49 names as "the admin story's".

**The editor half.** No user editor exists on this branch (no `areas/permissions/`, no user
form descriptor). Story 9.1 builds it; its actions should reuse this story's handler and tools.
Recommend the orchestrator add that bullet to 9.1 at the Epic 7 merge. 9.1's AC3 (secret
`NewPassword` filled at confirm) is delivered here by `permissions.users.password`.

**Coordination with Epic 8.** `UserList.cls`: 8.2 sets `primaryAction create` and the same two empty
keys -- identical values, so the merge collapses them; `userListEmptyAgent` must carry 8.2's value
exactly. `Prohibited.ReasonFor`'s `PRIVILEGEGRANT` line is the sentence 8.2's Roles violation will
render: whichever story lands second reconciles to one published sentence. Contended edits
(`Prohibited`, `Write`, `Operation`, `Confirm`, `SurfaceCoverage`) are footprint extensions.

**Ledger inbox (Rule 17).** DW-1499 -- addressed for the five codes a screen caller reaches here
(second Execution task). `OCUPILOTPROCESS` and `SYSTEMPROCESS` are first reached by Story 7.8's
process row actions, and the web-application and sweep codes by no screen caller on this branch:
recommend re-owning that residual to `7-8` at adjudication.

**Consumes:** 7.1 (route, operation, handler, typed-name dialog, `selfProtection` vocabulary), 5.9
(`permissions.users.update` and its census), 5.10 (the card's masked secret field), 15.1 (the
masked-field pattern). **Consumed-by:** 8.2 (the password secret discipline and `userListEmptyAgent`),
9.1 (the editor's actions), 7.8 (the caller-value channel, for terminate's error-to-job flag).

## Verification

**Targeted, inside the implement loop (loop)** -- slot A's throwaway `ocupilot-ci` (web 52776, super
1975) for every stateful or destructive check; IRIS MCP calls carry `server: "ocupilot-slot-a"`
(the dev container `ocupilot`, never the target of a destructive check). One test class per call,
never two in one message, never a re-submit on a client timeout.

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.UserUpdate` --
  expected: green; then, one at a time, `OcuPilot.Test.RefusalCopy`, `OcuPilot.Test.Prohibited`,
  `OcuPilot.Test.ProhibitedRoute`, `OcuPilot.Test.SurfaceCoverage`, `OcuPilot.Test.ToolRoundTrip`,
  `OcuPilot.Test.Descriptor`, `OcuPilot.Test.DerivedFields`.
- `cd ui && npm run test:tools` -- expected: green (`self-protection`, `strings`, `screen-mirror`,
  `citations`).
- `cd ui && npm run test:components` -- expected: green (handler, both dialogs, data table, command
  bar, command box).
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`,
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node
  --test --test-concurrency=1 browser/users-actions.browser-spec.mjs browser/users.browser-spec.mjs
  browser/users-write.browser-spec.mjs` -- expected: green, on a rebuilt and redeployed bundle.
- `uv run scripts/check-objectscript.py` on the changed paths; `bash scripts/lint-docs.sh` --
  expected: clean.
- Rule 19: one `mutation:` line per AC beside its pinning test (e.g. restore the `Disables`-only
  gate -> the `_SYSTEM` delete legs go red; trim the pasted password -> the byte-for-byte leg goes red).

**Once, before `dev_complete`:**

- The full ObjectScript sweep on `ocupilot-ci`, per class, one call at a time, totals verified
  against `%UnitTest_Result` with the numeric-run-index probe -- expected: green.
- The full browser suite is **not** run locally (Rule 29): CI's `browser` job runs it on a fresh
  throwaway.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

Plan written in full against the three recommended answers under Design Notes › Intent gaps:
(1) AC4 read against AD-10/AD-53 -- recommend refusing privilege grants whatever the caller, with
a tier-1 AC4 amendment on the 8.2 AC3 precedent; (2) a Rule 20 spine entry for a secret-only-body
action write (`CHANGEPWD` takes exactly `{NewPassword}`, measured) and a closed caller-value channel
on the screen-action route; (3) EXPERIENCE.md `:173` role dialog plus the Fixed-strings rows listed,
published by the lead. Nothing was implemented; nothing was committed.
