---
title: "Story 18.29: Role members' admin option, user Copy from and password validation"
type: 'feature'
created: '2026-10-08'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The role editor's Members tab drops each member's admin option. Copying a user exists only on the classic page (`Security.Users.Copy`); no admin API route does it. A password is checked against the pattern alone on the create form and not at all before the set-password dialog sends it, and the vendor answers a refused one 500 #845, which the port logs at severity 2. DW-1662: the authorization-server create refuses the default roles its editor pre-ticks.

**Approach:** `Members` carries the admin option. A new tool `permissions.users.copy` and the create form's Save reach `Security.Users.Copy` through `Port/UserCopyPort`, an AD-27 named case (build A; Task 0 ran at plan). One kernel helper over `$SYSTEM.Security.ValidatePassword` serves a check route, the create rules and an `AdminPort` guard. DW-1662's create admits `Defaults()`'s roles.

## Boundaries & Constraints

**Always:**

- **Members.** `RoleCreateRules.Members` adds `AdminOption` to each row as a boolean, true only for the string `"1"`. An escalation row (`User (escalation)`, boolean `false`) keeps its type and reads false.
- **Tool** `Screen/Tool/UserCopy.cls`, modeled on `ExplorerDocDbCreate`:
  - `CREATES` 1 on `Security.User` (AD-54, absence of `Name`); `CHANGEACTION` `created`; `WRITETYPE` `COPY`; `PORTCLASS` `UserCopyPort`; `DESCRIPTORCLASS` `UserList`.
  - `UserCreate`'s pairs; `CLASSICPAGES` `%CSP.UI.Portal.User`.
  - Arguments: `Name`, `CopyFrom` (required) and `FullName` (empty takes the source's). The secret `Password` is supplied at confirm.
  - `ComposeCreate` reads the source through `SOURCE`. Payload and diff rows are `CopyFrom`, `FullName`, `Roles` and `EscalationRoles` (the last two as the source's `GET` lists them), plus the masked `Password` row.
- **Port** `Port/UserCopyPort.cls` extends `AdminPort`, as `ProcessPort` does:
  - `SOURCE` is the admin `GET` plus `Flags` from `Security.Users.Get` in `%SYS`. An absent source, or one whose `Flags` carry `$$$LDAPUser` or `$$$DelegatedUser` (the classic list's exclusion), is refused `USERCOPY.SOURCE` on `CopyFrom`.
  - `COPY`, in order: the gate `%Admin_Secure:USE`; the password helper; `SOURCE` again, refusing 409 `USERCOPY.SOURCECHANGED` when its roles or escalation roles differ from the payload's as sets, ignoring case; then `Security.Users.Copy(CopyFrom, Name, FullName, 1, 1, Password)` in `%SYS` (AD-16).
  - Vendor codes, none logged: #837 is `USER.NAME.TAKEN` on `Name`, #838 is `USERCOPY.SOURCE`, and #845 and #958 are `USER.PASSWORD.POLICY` on `Password`. Anything else is a logged 500 whose vendor text is never sent.
  - `Snippet` renders the call with `"<Password>"`.
- **Prohibited**, by inserted lines and a method at the end only:
  - An arm for a `COPY`-type user tool admits those four fields alone (`UNCOVEREDFIELD` otherwise).
  - `GrantsPrivilegeByEffect`'s user branch also asks `EscalationRoles`, so a copy conferring `%All` or an `%Admin_*` privilege is destructive and names it (AD-10).
- **Screen.** `POST /users/copy` goes to `Area/Permissions/UserCopy.cls`, `UserCreate`'s flow over the copy tool.
  - Rules: the name's, `CopyFrom` required, `Password` required plus the helper, and `FullName`'s length.
  - It holds the target, asks the prohibited set, composes, writes, reads back `FullName`, `Roles` and `EscalationRoles`, and answers 201 `{name, user, readBack}`.
- **Helper** `Kernel/PasswordPolicy.cls` `Verdict(pPassword, pUser, .pReason)`, as `Api/Account.cls`'s validator arm does:
  - A refusal's reason is the first error's own text for 5001, 845 or 958.
  - `REASONUSERPASSWORDPOLICY` replaces a reason that is empty or contains the password, and stands for any other error.
  - The password is never logged, returned or kept (AD-35).
- **Callers of the helper:**
  - `POST /users/password-check` `{password, name}` answers 200 `{valid, reason}`. It is gated by `UserForm`'s pairs, and the body is never logged.
  - `UserCreateRules.Validate` uses the helper and drops `MeetsPolicy`.
  - `AdminPort` refuses a `Security.User` `POST` or `CHANGEPWD` the helper refuses: 422 `USER.PASSWORD.POLICY` on `Password`, before the vendor call, unlogged.
  - The create form's Password blur and the set-password dialog's field blur call the check route and show the reason on the field; a stale answer is dropped.
- **DW-1662.** `OAuthAuthorizationServerRules.CustomizationViolations` reads stored roles from `Defaults()` on a create only (:390).
- **Codes and governance.** `USERCOPY.SOURCE` and `.SOURCECHANGED` go in `Api/UserCopyError.cls`, with two dispatch lines in `Error.cls`. `permissions.users.copy` is `true` in `Baseline.cls`.
- **Probes** run on `ocupilot-ci` only, with prefix `OcuProbe1829`, and are removed. One test class per call.

**Never:**

- Copy the source's password. The classic "Leave as is" copies its hash (measured).
- Set anything but `FullName` at a copy.
- Edit a contended file beyond list or roster inserts, `Prohibited.cls`'s insertions and EXPERIENCE.md's rows in place.
- Add a new entity type, a new `PROHIBITED.*` code, a route beyond these two, or an `Account.cls` change.
- Use `$SYSTEM.Monitor.State()` in a test snapshot.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error handling |
|---|---|---|---|
| Members | Members granted `WITH ADMIN OPTION` and plainly, a role member, an escalation holder | `AdminOption` true, false, false, false; the escalation row reads "Account (escalation)" | — |
| Copy | Both callers, as a principal holding only the Users pairs and code-database READ. The source has roles, an escalation role, settings, and standard, column and admin SQL privileges in USER and HSCUSTOM | The new account holds them all, grantor kept, with `FullName` as given or the source's; the read-back matches | — |
| Privileged copy | The source holds `%Manager` as a role or as an escalation role | The proposal is destructive and names it; the form shows the consequence line | — |
| Source | Absent, LDAP or delegated; or its roles changed after the mint | `USERCOPY.SOURCE` (the mint refuses with its sentence); 409 `.SOURCECHANGED` | Nothing is created |
| Password | `a` (pattern `3.255ANP`); or a routine refusing with text that quotes the password | 422 `USER.PASSWORD.POLICY`, reason "Password does not match length or pattern requirements" or the published sentence | Nothing is written and nothing is logged; the check route answers alike |
| Set password | `a` from the dialog or at the agent's confirm | 422 on `Password` before the vendor call | The password is unchanged |
| DW-1662 | A two-pair principal sends the pre-ticked `%DB_IRISSYS` and `%Manager` | 201, stored | A non-default unreadable role still answers 422 `.ABSENT` |

</intent-contract>

## Code Map

- `RoleCreateRules.cls` `Members` :506-534 (fields :524-526); `role-editor.store.ts` `Member` :56 and `absorb` :519; `role-editor.page.ts` members :252-269 and `memberRows` :625.
- `Area/Permissions/UserCreate.cls` (`HandleCreate`, `Perform`); `UserCreateRules.cls` `Validate` :102 (password :122-131), `MeetsPolicy` :284; `Screen/Tool/UserCreate.cls`.
- Models: `Screen/Tool/ExplorerDocDbCreate.cls` (`ComposeCreate` :56); `Port/ProcessPort.cls` (`Invoke` :88, `Snippet` :306); `Api/Account.cls` `ClassifyRefusal` :145-200.
- `Port/AdminPort.cls`: guard slot :1270-1275; `RENAMEDTYPES` :786 renames `CHANGEPWD`'s `Password`.
- `Prohibited.cls`: `Prohibits` :1279 (arms precede `Target()`), `GrantsPrivilegeByEffect` user branch :4320-4323, `GrantsPrivilege(…, pField)`.
- `Api/Router.cls` `/users` :101-105; `Error.cls` prefix arms :1222-1235 and :1430-1442.
- `user-create-form.page.ts` password :128, roles :220; `.store.ts` `onBlur` :313, `save` :357.
- `OAuthAuthorizationServerRules.cls` `Defaults` :150, `CustomizationViolations` :363-405.

## Tasks & Acceptance

**Task 0 (done at plan):** Copy runs under the caller's own `%Admin_Secure:USE` (Design Notes), so build A. `Test/UserCopy` pins it.

**Execution** (each per Boundaries):

- Server, changed: `RoleCreateRules.cls`, `UserCreateRules.cls` (and `HandlePasswordCheck`), `Port/AdminPort.cls`, `Kernel/Proposal/Prohibited.cls`, `Api/Router.cls` (two routes in the :101-103 block, their wrappers, the :449 doc), `Api/Error.cls`, `Classification.cls` (entry `permissions.users.copy`, then regenerate `ToolFields`), `Baseline.cls`, and `OAuthAuthorizationServerRules.cls`.
- Server, new: `Kernel/PasswordPolicy.cls`, `Port/UserCopyPort.cls`, `Screen/Tool/UserCopy.cls`, `Area/Permissions/UserCopy.cls` (extends `UserCreate`) and `Api/UserCopyError.cls`.
- Client: the role editor's store gains `adminOption`, and its row an "Admin option" tag.
- Client: the create form's page and store:
  - A "Copy from" select over the Users list's declared read (AD-5).
  - Choosing a source reads it (`GET /users/form?name=`), pre-fills Full name, and shows its roles and escalation roles read-only, with the consequence line when one is privileged (`roles[].privileged`).
  - Expiry, namespace, routine and Roles are hidden while copying.
  - Save posts `{Name, CopyFrom, FullName, Password}` to `/users/copy`, and Password blur checks.
- Client: `set-password-dialog.ts` checks on blur through the API service, with the reason under the field via `aria-describedby`.
- Client: `strings.ts` (add-only), and EXPERIENCE.md rows :115, :398, :431 and :478 in place. Re-base `angular.json` if crossed (DW-1166).
- Tests: `Test/UserCopy.cls` (new, armed by `OCUPILOT_ALLOW_PRINCIPALS`): the matrix's copy, privilege and source rows on both callers as a least-privileged principal it creates, the SQL privileges through the 18.9 and 18.28 reads, `SOURCECHANGED` at confirm, the read-back and `Snippet`. It removes everything, revoking SQL privileges first.
- Tests: `Test/PasswordPolicy.cls` (new, armed): `Verdict` with the routine legs (restored as `AccountPasswordWire` :66-292 does), the check route (gate, verdicts, body unlogged), the create rule, and the guard on create and set-password through both callers.
- Tests, changed:
  - `Test/RoleSave.cls` (:135-147) takes the members row.
  - `OAuthAuthorizationServerWire.cls` :287 creates with the default roles, and keeps a non-default unreadable role's 422.
  - Client specs for the role editor, `user-create-form.store` and `set-password-dialog`.
  - Browser specs: `users-create` (copy from, the blur check), `roles-editor` (admin option), `users-actions` (the dialog's check).
- **Shared-surface sweep (Rule 30).**
  - Grep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for `permissions.users.create`, `USER.PASSWORD.POLICY`, `MeetsPolicy`, `ocu-form-role`, `/users/name`, `CUSTOMIZATIONROLES.ABSENT` and `set-password`.
  - Known pins: `ReadTool.cls` :93-94 (count, names), `SurfaceCoverage` :218, `ToolRoundTrip` :83 (`permissions.users.copy:TOOL.ARGUMENTS`), `EndpointCoverage` :149-157, `DraftRegistry`, `field-lists.test.mjs`, and `ci-throwaway.sh`'s principals `# classes:`.

**Acceptance Criteria:**

- **C1.** Given a probe role whose members include one granted `WITH ADMIN OPTION` and an escalation holder, when its Members tab is read, then each member shows whether it holds the admin option, compared by value, and the escalation holder reads as one, without it.
- **C2.** Given a probe source user, when a new user is created from it by the form's Save and by a confirmed proposal, as a principal holding only the Users pairs, then the account holds what `Security.Users.Copy` gives it (roles, escalation roles, settings, SQL privileges) and the read-back matches.
- **C3.** Given a source whose roles or escalation roles grant `%All` or an `%Admin_*` privilege, when its copy is proposed, then it is confirmed at the destructive treatment naming the privilege, and the form shows the consequence line.
- **C4.** Given a candidate password on the create form and the set-password dialog, when it is checked or sent, then `$SYSTEM.Security.ValidatePassword` answers. A refusal is 422 `USER.PASSWORD.POLICY` before any vendor write, and no reason, log line or card carries the password.
- **C5 (DW-1662).** Given a principal holding only the authorization server tab's two pairs, when it creates a configuration with the pre-ticked default roles, then the instance stores it.
- **Integration.** Given `ocupilot-ci`, when each consumer acts, then the create form goes through `POST /users/copy` and `POST /users/password-check`, the set-password dialog through the check route, the agent through `permissions.users.copy`, and the role editor through `GET /roles/form`.

## Spec Change Log

- 2026-10-08, spec gate (lead): Task 0 settles option A (the orchestrator's ruling). Decisions confirmed: a copy always takes a new password; escalation roles count toward the destructive treatment. Spine amendments written (AD-27, AD-8, AD-10, AD-2, AD-39, AD-44, AD-52, AD-15 named gap). Vendor candidates DW-2222, DW-2223 under the owner's hold.

## Review Triage Log

## Design Notes

**Task 0, measured at plan** (`ocupilot-ci`, 2026-10-08; probe principal with exactly `%Admin_Secure:U`, `%DB_IRISSYS:R` and `%DB_HSCUSTOM:R`):

- **What Copy copied.** Roles, escalation roles and every setting (`FullName` as given, or the source's when empty). Standard, column and admin SQL privileges in USER and HSCUSTOM, grantor `irisowner` kept, though the caller held no SQL privilege and no READ on USER.
- **Copy's refusals.** #822 without `%Admin_Secure`. #845 for a bad password, #838 for an absent source, #837 for a taken name; none creates anything.
- **The password.** An empty `NewPassword` copies the source's hash and salt.
- **Audit.** `UserChange` "Create User" lists roles and escalation roles. The copied SQL privileges record no grant row.
- **Role owners.** `OWNERLIST` answers `"0"` or `"1"`, `"1"` after `WITH ADMIN OPTION`. An escalation row reads `User (escalation)` with `false`, and a role member reads `Role` with `"0"`.
- **The validator.** `ValidatePassword` answers any caller #845 "Password does not match length or pattern requirements".
- **The vendor's password refusal.** `POST /security/user` and `/security/user/password` answer `a` with 500 #845.
- **End state.** S0 was restored: no `OcuProbe1829*` principal, role, table, privilege row or class, and the monitor reads 0.

**Decisions:**

1. Build A: measured above.
2. A copy always sets a new password; sharing a credential is AD-35's harm (inference).
3. Escalation roles count as a grant: they confer the ability to become that role (inference).
4. The source's roles are checked by the port's re-read at the write, because an AD-54 fingerprint covers only absence.
5. Field refusals from the helper or the code map are unlogged, so a bad password no longer raises the alert state.

**Governing ADs:** AD-2, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-22, AD-27, AD-35, AD-39, AD-44, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58 and AD-59.

**Integration ACs.** Consumers in this story: the form, the dialog, the role editor and the agent. Consumes: 7.2, 9.1, 9.3, 12.7, 15.1, 18.9 and 18.28. Consumed-by: 18.12.

**Ledger (Rule 17).** DW-1662 is addressed by C5. No owner-hold entry is built on.

**For the lead** (Rule 20):

- AD-27's named case `UserCopyPort` (`Security.Users.Copy`; `Security.Users.Get` for `Flags`). AD-52: its sequence. AD-44: its `CLASSICPAGES`.
- AD-8: no pair beyond the Users list's; the vendor's model copies SQL privileges the caller could not grant. AD-10: escalation roles count.
- AD-2: unlogged are the guard and #837, #838, #845 and #958. AD-39: the third exception widens to an administrator's password check, create and set-password. AD-15: the copy's SQL privileges go unaudited.
- Vendor candidates (owner hold): (a) copied SQL privileges are unaudited; (b) `AdminOption` is a string for members and a boolean for escalation rows.

**Footprint (Rule 11).** Contended files take list or roster inserts and `Prohibited.cls`'s insertions only. `footprint_extensions`: `AdminPort.cls`, `OAuthAuthorizationServerRules.cls` and `shell/set-password-dialog.ts`.

**Size (inference).** About 18.28's: one port, one tool, one handler, one helper and three client surfaces.

## Verification

**Setup.** Load with `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-18-d8/load-ocupilot-ci.sh` (`LOAD-OK`, `STARTPATH-OK`). Browser runs use a rebuilt bundle `docker cp`'d to `ocupilot-ci`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`. S0 means no `OcuProbe1829*` principal, role or privilege row; `PasswordValidationRoutine` restored; monitor 0.

**Shared surfaces:** the role editor's Members tab, the user create form, the set-password dialog, the tool and route rosters, `Security.User` writes through `AdminPort`, and the authorization-server create. Standing criterion: *existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Bundle:** 3.16 MB against a 3165kB warning. The implement stage may re-base it under DW-1166.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, with totals checked in `%UnitTest_Result`. The classes: `UserCopy`, `PasswordPolicy`, `RoleSave`, `OAuthAuthorizationServerWire`, `UserCreate`, `UserCreateWire`, `UserUpdate`, `Prohibited`, and each class the sweep changed.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/users-create.browser-spec.mjs browser/roles-editor.browser-spec.mjs browser/users-actions.browser-spec.mjs`.
- `(loop)` `npm run test:tools && npm run test:components`, `uv run scripts/check-objectscript.py <changed .cls>`, `bash scripts/lint-docs.sh`.
- `(once, before dev_complete)` The full ObjectScript sweep, one class at a time; `cd ui && npm test && npm run build`; `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; S0.
- `(CI)` The full browser suite (Rule 29).

**Mutations (Rule 19)**, each recorded as `mutation: … → … red (run n)`:

- C1: `Members` passes `AdminOption` through raw → `RoleSave` red.
- C2: `ComposeCreate` drops `EscalationRoles` → `UserCopy` red.
- C3: the inserted `EscalationRoles` line is removed → `UserCopy`'s escalation leg red.
- C4: `Verdict` returns the raw text → `PasswordPolicy`'s routine leg red; the guard is removed → its set-password leg red.
- C5: the `Defaults()` read is reverted → `OAuthAuthorizationServerWire` red.
- Integration: Save posts to `/users` → the browser copy test red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
