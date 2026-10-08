---
title: "Story 18.29: Role members' admin option, user Copy from and password validation"
type: 'feature'
created: '2026-10-08'
status: 'in-progress'
baseline_revision: '33287e8bc06efb6258cdd7a82da9645b12444440'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      The client's privileged flag for a copy source may be computed only from the role rules' flags, so a source whose escalation roles grant a privilege the server counts may not show the consequence line.
    evidence: |-
      (inference) Settles by comparing the client's privileged computation in user-create-form.store.ts absorbSource with the server's GrantsPrivilegeByEffect for an escalation-role source; a source with %All as an escalation role must show the consequence line.
    location: >-
      ui/src/app/areas/permissions/user-create-form.store.ts
    severity: medium (unverified)
  - summary: >-
      UserCreateRules.Account no longer removes EscalationRoles for any caller, so the update form's read may now carry escalation roles that its save writes back, a change the spec does not state.
    evidence: |-
      (inference) Settles by reading UserUpdate's read and save path: whether an update that does not touch escalation roles writes them back unchanged, and whether an update can add an escalation role it did not before.
    location: >-
      src/OcuPilot/Area/Permissions/UserCreateRules.cls
    severity: medium (unverified)
  - summary: >-
      The DW-1662 default-role leg may not post %Manager in its body, so the wire test may not cover the pre-ticked roles the intent names.
    evidence: |-
      (inference) Settles by reading the default-role leg of OcuPilot.Test.OAuthAuthorizationServerWire and confirming its body carries %DB_IRISSYS and %Manager.
    location: >-
      src/OcuPilot/Test/OAuthAuthorizationServerWire.cls
    severity: medium (unverified)
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
- Tests: `Test/PasswordPolicy.cls` (new, armed): `Verdict` on the instance's own routine (accepted, the pattern refusal's published sentence, empty) and on a probe routine installed in `%SYS` and restored after each test (a quoting refusal replaced by the published sentence, a refusal's own sentence kept); the check route's answer with no password in its raw body; the guard on a `POST`, judged by its body's `Name`, and on set-password, both refused before the vendor. The check route's refusal of a principal without the pairs is pinned in `Test/UserCopy.cls`.
- Tests, changed:
  - `Test/RoleSave.cls` (:135-147) takes the members row.
  - `OAuthAuthorizationServerWire.cls` :287 creates with the default roles, and keeps a non-default unreadable role's 422.
  - Client specs for the role editor, `user-create-form.store` and `set-password-dialog`.
  - Browser specs: `users-create` (copy from, the blur check), `roles-editor` (admin option), `users-actions` (the dialog's check).
- **Shared-surface sweep (Rule 30).**
  - Grep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for `permissions.users.create`, `USER.PASSWORD.POLICY`, `MeetsPolicy`, `ocu-form-role`, `/users/name`, `CUSTOMIZATIONROLES.ABSENT` and `set-password`.
  - Known pins: `ReadTool.cls` :93-94 (count, names), `SurfaceCoverage` :218, `ToolRoundTrip` :83 (`permissions.users.copy:TOOL.ARGUMENTS`), `EndpointCoverage` :149-157, `DraftRegistry`, `field-lists.test.mjs`, and `ci-throwaway.sh`'s principals `# classes:`.

**Review patches (pass 1, from the triage log; each in one fresh pass, one test class or spec per run, mutation line per changed pin):**

- **R1 (admin option, V1).** `RoleSave` setup adds a member granted `WITH ADMIN OPTION`; assert its `AdminOption` is `1`. Mutation: `RoleCreateRules.Members` hard-codes `AdminOption` to `0` → `RoleSave` red.
- **R2 (copy data and sources, V2, I3).** `UserCopy`: give the source one escalation role and one setting; assert the target's `EscalationRoles` equals the source's as a set and `readBack` matches the stored account. Add LDAP and delegated sources, each refused `USERCOPY.SOURCE` on `CopyFrom` with nothing created. Mutation: `ComposeCreate` sets `EscalationRoles` to `Roles` → red.
- **R3 (principals, I2, V2 gate).** Create a probe principal holding exactly `%Admin_Secure:U`, `%DB_IRISSYS:R` and `%DB_HSCUSTOM:R` plus the Users pairs (the Task 0 probe principal); the copy and the password check succeed as it. A principal without `%Admin_Secure` gets the copy refused 403 with nothing created. Mutation: remove the gate in `UserCopyPort.Copy` → the 403 leg red.
- **R4 (password reason, V3).** `PasswordPolicy`: for `a`, assert the reason equals the published sentence (the `REASONUSERPASSWORDPOLICY` text) exactly, and a routine refusal whose text contains the password is replaced. Mutation: `Verdict` returns the raw validator text → red. Correct the class header's mutation claim to what the test pins.
- **R5 (guard and check route, V4, I4).** A `POST` through `AdminPort` with a refused password gets 422 before the vendor call, with the password unchanged and no body text in the log; the check route refuses a principal without the form's pairs; a raw-body search finds no password in the check answer. Mutation: drop `"POST"` from `IsPasswordType` → the POST leg red.
- **R6 (confirmed proposal, I5, I4).** Mint and confirm a copy as the probe principal; `SOURCECHANGED` at confirm; a privileged source's proposal is destructive and names the privilege; the agent confirm goes through the guard. Mutation: the `EscalationRoles` line removed from `GrantsPrivilegeByEffect` → the escalation leg red.
- **R7 (browser and rendered, I1, V5).** Browser legs in `users-create` (copy Save posts to `/users/copy`; Password blur shows the reason), `roles-editor` (admin-option tag), `users-actions` (dialog blur). Component assertion that the consequence sentence renders for a privileged source and not otherwise. Rebuild and `docker cp` before each browser run; mutation lines for each.
- **R8 (guard name, V8).** `AdminPort` takes the account name from the body's `Name` on `POST` and from the query on `CHANGEPWD`. Test: a `POST` whose password contains its `Name` is refused. Mutation: restore the query-only read → red.
- **R9 (escalation scope, V7).** One direct assertion that a `UserCreate` or `LdapCreate` payload carrying an `%All` escalation role is classified destructive, matching Decision 3.
- **Spec corrections (V6, V10).** The Integration mutation line names `user-create-form.store.spec.ts`; the Test line for `PasswordPolicy.cls` lists only what the tests pin.

**Rework items (pass 2, lead, 2026-10-08; pass 1 returned with the full sweep in flight and these open):**

- [x] [Rework] R3, the port gate. The route and the confirm answer first (Design Notes; runs 78, 82, 84). The port's gate is pinned in-process by `TestThePortRefusesACopyWhoseCallerLacksAdminSecureWhateverTheRoute` through the test subclass `OcuPilot.Test.UserCopyNoGate` (mutation red, run 94). Run 56: removing the `%Admin_Secure` check from `UserCopyPort.Copy` left every test green, because the route answers a refused principal 403 first. The agent's confirm path reaches the port without that route gate, so pin the port's gate there: confirm a `permissions.users.copy` proposal (or call the port in-process) as a principal lacking `%Admin_Secure`, and assert it is refused with nothing created. Mutation: remove the port gate, and that leg goes red. If another gate answers first on that path too, record which gate is load-bearing on each path under Design Notes.
- [x] [Rework] Reconcile pass 1's record. `## Auto Run Result`'s "Not written or not run" list contradicts `## Verification` (runs 45-57 record R1, R2, R5, R6/R9, R7, R8 and C4 red). For each of R1-R9, V6 and V10 above, confirm the patch is in the tree and its pinning test has its mutation line, and do whatever is missing. Named as missing in pass 1's record: R4's routine legs of `Verdict` (the reason equals the published sentence exactly; a routine refusal whose text contains the password is replaced), the check route's gate (a principal without the form's pairs is refused), and the `Security.Users` SQL-privilege copy, with every reproduced privilege removed by the teardown (18.9's `SqlPrivilegeProbe` sweep). Then rewrite `## Auto Run Result` to what is true.
- [x] [Rework] Leave `ocupilot-ci` at S0: no `OcuProbe1829*` principal, role or privilege row, and `PasswordValidationRoutine` restored.

**Review patches (pass 2 review, 2026-10-08; applied by a fresh subagent per /epic-cycle Rule 18):**

- [x] [Patch] P1 (medium) `Port/UserCopyPort.cls` `SameNames` on Roles: a leg where only Roles differ from the source expects 409 `USERCOPY.SOURCECHANGED`; a leg where the same names differ only in case or order expects 201. Mutation: remove the Roles clause from the source-changed test, and the Roles-only leg goes red.
- [x] [Patch] P2 (medium) C4 log and card: after a refused POST and a refused CHANGEPWD, the log written since the refusals is read and the password marker is asserted absent; in `set-password-dialog.spec.ts`, the typed password is asserted absent from the rendered reason. Mutation: a refusal branch that logs the request body goes red.
- [x] [Patch] P3 (medium) C3 `%Admin_*`: a copy whose source holds an `%Admin_*` privilege as a role and as an escalation role is proposed destructive and names the privilege. Mutation: `Prohibited.IsPrivilegedRole` stops treating `%Admin_*` as privileged, and that leg goes red.
- [x] [Patch] P4 (low) Integration mutation lines: the dialog's request path is asserted as `PASSWORD_CHECK_PATH` in `set-password-dialog.spec.ts`; the role editor's form path `GET /roles/form` is asserted in `role-editor.store.spec.ts`; the agent tool string `permissions.users.copy` is asserted in `MintAs`. Each has a mutation line, applied and observed red, then reverted.
- [x] [Patch] P5 (medium) POLICYCODES gate: a probe entry returns a non-listed code with a sentence, and the published sentence comes back. Mutation: delete the `$ListFind` gate in `PasswordPolicy.Verdict`, and that leg goes red.
- [x] [Patch] P6 (medium) SqlGrantsLeft positive control: `SqlGrantsLeft() > 0` is asserted before `RemoveSqlGrants`. Mutation: change the grantee match so it never matches, and the positive control goes red.
- [x] [Patch] P7 (medium) `TestACopyPayloadAdmitsItsFourFieldsAlone`: a leg whose payload is the four fields alone asserts it is not refused `PROHIBITED.UNCOVEREDFIELD`; the refusal leg keeps its extra fields. Mutation: delete the `Copied` arm in `Prohibited.cls`, and the admitted leg goes red.
- [x] [Patch] P8 (medium) `TestThePasswordCheckAnswersAndNeverEchoesThePassword`: a distinctive marker password is asserted absent from the whole response body, not only the `password` key. Mutation: echo the password into `reason`, and that leg goes red.
- [x] [Patch] P9 (low) Snippet: `Test/UserCopy.cls` asserts the copy's `Snippet` contains `Security.Users.Copy(` and `"<Password>"` and no literal password. Mutation: change the `Copy` arguments inside `Snippet`, and that leg goes red.
- [x] [Patch] P10 (low) Teardown hygiene: `OnAfterOneTest` keeps the `SetSourceEscalation` status in its own variable and asserts it; `RemoveSqlGrants` returns its status instead of swallowing errors, and the teardown asserts it.
- [x] [Patch] P11 (low) Mutation lines: the LDAP and delegated refusal leg (`TestADirectoryOrDelegatedSourceIsRefusedOnCopyFrom`) and the `Copied` arm in `Prohibited.cls` each have a mutation line, applied and observed red, then reverted byte-identical.
- [x] [Patch] P12 (medium) `Test/PasswordPolicy.cls` `ReadValidationRoutine`: a read that fails is recorded, and `RestoreValidationRoutine` does not write `""` over the instance's validation routine. This is a harness guard, not an acceptance criterion, so it has no mutation line.
- [x] [Patch] P13 (low) Naming and dead code: `TestTheConfirmOfACopyAsAPrincipalWithoutAdminSecureIsRefusedByThePort` is renamed to match its header (the confirm's pair gate answers); `OcuPilot.Api.UserCopyError.Codes()` is deleted after a grep showed no caller.

**Sweep items (pass 3, lead, 2026-10-08).** The runner's full ObjectScript sweep ran on a fresh `ocupilot-ci` over the tree merged with feature `19f2011d`: 526 classes, 4,188 tests, 8 failed, every failure from this story's new surfaces.

- [ ] [Sweep] `ClassicPageGate.TestWithNoAssignmentEachToolsPairsAreItsDeclaredSet` (run 62). `permissions.users.copy` declares a replaced classic page but is absent from `OWNPAIRS` (68 declaring tools, 67 declared). Add its entry, in the form its `permissions.users.*` neighbours use, and make the count sentence "sixty-eight".
- [ ] [Sweep] `MappingDescriptor.TestTheClassicPagesRosterIsTheDeclaringTools` (run 243). The classic-pages roster lacks the copy tool and its page. Add the row.
- [ ] [Sweep] `PortGate.TestEveryPortDeclaresANamedGate` (run 310). `OcuPilot.Port.UserCopyPort` must declare and evaluate a named pair set (AD-29), as the other ports do, and join `PortGate`'s roster.
- [ ] [Sweep] `ProhibitedRoute.TestTheUserWriteVerbsAreRosteredAndALiveSystemDisableOrDeleteIsRefused` (run 320). The users write-verb roster, now "seven", must name `permissions.users.copy` and count eight, with the copy asserted the way the roster's other verbs are.
- [ ] [Sweep] `ReadTool.TestTheRegistryListsDescriptorReadsAndInheritedKinds` (run 346). Feature's 315 already includes Epic 20's 20.18 tools; the copy tool makes 316. Take the number and the names from the registry, and update both assertions' counts and sentences.
- [ ] [Sweep] `SaveHoldCoverage.TestEveryWriteRouteTakesTheHoldOrIsExempt` (run 371). `POST /users/password-check` neither takes the target hold nor is listed exempt. It writes nothing, so add it to the exemption list with that reason, as other non-writing POSTs are listed; if it does write, it takes the hold.
- [ ] [Sweep] `ToolWrite.TestEveryWriteToolsRequestTypeAgreesWithThePortsBodylessRoster` (run 464). `permissions.users.copy` writes `Security.User/COPY`, which the port declares a mutating pair, while the roster the test reads (the registry's pairs plus `AHEADTYPES`) does not admit it. Reconcile it as the test's message says.
- [ ] [Sweep] `UserSave.TestTheSaveAndTheFormReadAnswerOneEnvelopeOverTheWire` (run 496): "without its escalation roles". This proves pass 2's deferred item about `UserCreateRules.Account`. The user form's read must answer without escalation roles again, for every caller, as before this story; only the copy path keeps the source's escalation roles. Pin it, with a mutation line.
- [ ] [Deferred] Settle pass 2's other two `deferred:` items: the client's privileged flag for an escalation-role source (`user-create-form.store.ts`), and whether the DW-1662 default-role leg posts `%Manager`. Fix each one that is real, with a pinning test and its mutation line, or record under Design Notes, with evidence, why it is not. Then remove all three settled items from the frontmatter `deferred:` list.

**Acceptance Criteria:**

- **C1.** Given a probe role whose members include one granted `WITH ADMIN OPTION` and an escalation holder, when its Members tab is read, then each member shows whether it holds the admin option, compared by value, and the escalation holder reads as one, without it.
- **C2.** Given a probe source user, when a new user is created from it by the form's Save and by a confirmed proposal, as a principal holding only the Users pairs, then the account holds what `Security.Users.Copy` gives it (roles, escalation roles, settings, SQL privileges) and the read-back matches.
- **C3.** Given a source whose roles or escalation roles grant `%All` or an `%Admin_*` privilege, when its copy is proposed, then it is confirmed at the destructive treatment naming the privilege, and the form shows the consequence line.
- **C4.** Given a candidate password on the create form and the set-password dialog, when it is checked or sent, then `$SYSTEM.Security.ValidatePassword` answers. A refusal is 422 `USER.PASSWORD.POLICY` before any vendor write, and no reason, log line or card carries the password.
- **C5 (DW-1662).** Given a principal holding only the authorization server tab's two pairs, when it creates a configuration with the pre-ticked default roles, then the instance stores it.
- **Integration.** Given `ocupilot-ci`, when each consumer acts, then the create form goes through `POST /users/copy` and `POST /users/password-check`, the set-password dialog through the check route, the agent through `permissions.users.copy`, and the role editor through `GET /roles/form`.

## Spec Change Log

- 2026-10-08, lead: re-opened `in-progress` for pass 3 after the runner's full sweep (8 reds, all from this story's surfaces), with the sweep items and the three deferred items under Tasks & Acceptance. Pass 2's interim-return root cause was the harness (Rule 18 item 5), not the model.
- 2026-10-08, lead: pass 1 (implement on Haiku) returned with its full sweep in flight; the sweep died with it after 16 classes. The spec was re-opened `in-progress` with the three rework items under Tasks & Acceptance; pass 1's uncommitted diff is kept for pass 2's finalize commit. The full ObjectScript sweep moves to the runner, which runs it before `dev_complete`. The Setup loader path now names the carry folder.
- 2026-10-08, spec gate (lead): Task 0 settles option A (the orchestrator's ruling). Decisions confirmed: a copy always takes a new password; escalation roles count toward the destructive treatment. Spine amendments written (AD-27, AD-8, AD-10, AD-2, AD-39, AD-44, AD-52, AD-15 named gap). Vendor candidates DW-2222, DW-2223 under the owner's hold.

## Review Triage Log

### 2026-10-08 — Review pass

- verdicts: 17 findings — high 5, medium 6, low 3, false 2, maybe-false 1
- findings:
  - `[high]` `[patch]` V2: copy tests do not pin escalation-role contents, read-back equality, settings, SQL privileges, or the `%Admin_Secure` gate (UserCopy.cls:136-142, 65-72) — patch: add the tests listed under Review patches R2 and R4.
  - `[high]` `[patch]` V4: no `POST` through AdminPort's password guard, no refused-principal case on `/users/password-check`, no raw-body search for the password — patch: R5.
  - `[high]` `[patch]` I1: browser legs for the copy Save and blur check, the admin-option tag, and the dialog blur are unwritten — patch: R7.
  - `[high]` `[patch]` I2: every copy and password-check test runs as `_SYSTEM`, so the least-privileged principal (Users pairs and code-database READ) is never exercised — patch: R3.
  - `[high]` `[patch]` I5: the confirmed-proposal path (mint, confirm, SOURCECHANGED at confirm, destructive treatment) is untested — patch: R6.
  - `[medium]` `[patch]` V1: no admin-option holder in RoleSave's setup, so `AdminOption = 1` is never asserted; the hardcoded-0 mutation stays green — patch: R1.
  - `[medium]` `[patch]` V3: `PasswordPolicy.cls:48` asserts only non-empty; the reason is not pinned to the published sentence — patch: R4.
  - `[medium]` `[patch]` V5: the C3 consequence line is not asserted in rendered DOM — patch: R7.
  - `[medium]` `[patch]` V8: `AdminPort.cls:1307` reads the account name from the query, which is empty on a POST create, so the verdict skips the name check — patch: R8.
  - `[medium]` `[patch]` I3: LDAP and delegated source refusals are in code and matrix, not in tests — patch: R2.
  - `[medium]` `[patch]` I4: a set-password refusal leaving the password unchanged, and the agent-confirm path through the guard, are untested — patch: R5 and R6.
  - `[low]` `[patch]` V6: the spec's Integration mutation names a browser test that does not exist; the component store spec pins it — patch: correct the spec's Verification line to name `user-create-form.store.spec.ts`.
  - `[low]` `[patch]` V7: the EscalationRoles leg also classifies UserCreate, LdapCreate and LdapUpdate proposals, which no test covers; the behavior follows Decision 3 — patch: R9.
  - `[low]` `[patch]` V10: the spec's Test line for `PasswordPolicy.cls` promises gate, verdicts and unlogged body the class does not pin — patch: correct the spec's Test line and the class header to what the tests pin.
  - `[maybe-false]` `[defer]` I6: the client's `privileged` flag may miss escalation roles that the server counts (inference); if true it is medium — deferred with what would settle it.
  - `[false]` `[reject]` V9: `HandlePasswordCheck` returns `tGateSC` on refusal; `Denial.Envelope` renders through `Error.Render` and matches `ResourceRules.Gate`, so it does not return without a response.
  - `[false]` `[reject]` I7: the copy tool's `CREATES`, `CHANGEACTION` and `DESCRIPTORCLASS` are inherited from `UserCreate` (`UserList`, 1, `created`), matching the spec.

### 2026-10-08 — Review pass (pass 2, rework re-review)

- verdicts: 24 findings — high 0, medium 8, low 10, false 4, maybe-false 2
- findings:
  - `[medium]` `[patch]` V-a: the Roles half of the source-changed check has no leg; a copy could write roles the user never reviewed — patch: P1.
  - `[medium]` `[patch]` V-b: C4's log and card clauses have no pinning test — patch: P2.
  - `[medium]` `[patch]` V-c: C3's `%Admin_*` clause has no copy-path pin — patch: P3.
  - `[low]` `[patch]` V-d: dialog, role-editor and agent integration consumers have no path assertion or mutation line — patch: P4.
  - `[medium]` `[patch]` V-e: the POLICYCODES gate has no leg that reaches its refusal branch — patch: P5.
  - `[low]` `[reject]` V-f: an empty `CopyFrom` mint's reason sentence is unpinned; a user meets it only through API misuse, and pinning it is more than a correction.
  - `[low]` `[reject]` V-g: the store spec's valid-answer test name asserts clearing that its body never checks; adding the step is more than a correction, and the failure needs a stale refusal the form does not show.
  - `[medium]` `[patch]` V-h: the SQL-grant teardown has no positive control — patch: P6.
  - `[low]` `[patch]` V-i: the Snippet is not pinned by `UserCopy`, and the spec's Test line claims it is — patch: P9.
  - `[medium]` `[patch]` F1: `TestACopyPayloadAdmitsItsFourFieldsAlone` only asserts refusal, so it cannot fail for the admission it names — patch: P7.
  - `[medium]` `[patch]` F2: the password-check test only checks the `password` key, so a password echoed in `reason` passes — patch: P8.
  - `[low]` `[patch]` F3: `OnAfterOneTest` overwrites the restore status, and `RemoveSqlGrants` swallows errors — patch: P10.
  - `[low]` `[patch]` F4: the LDAP and delegated refusal legs have no mutation line — patch: P11.
  - `[low]` `[patch]` F5: the `Copied` arm in `Prohibited.cls` has no mutation line — patch: P11.
  - `[medium]` `[patch]` F6: `ReadValidationRoutine` can leave the restore writing `""` over the instance routine — patch: P12.
  - `[low]` `[patch]` O1: a test name does not match its header — patch: P13.
  - `[low]` `[patch]` O2: `UserCopyError.Codes()` has no caller — patch: P13.
  - `[low]` `[reject]` O3: `Test/UserCopy.cls` is about 640 lines; splitting is more than a correction, and the guide is roughly 500 lines.
  - `[false]` `[reject]` O4: a short password's reason containing a letter is replaced by `REASONUSERPASSWORDPOLICY`, the same policy constant the verdict uses for every non-listed refusal, so the operator sees the published sentence either way.
  - `[false]` `[reject]` I-R3: the port gate is pinned in-process by the rework seam (`UserCopyNoGate`), as Design Notes records, not by a real principal.
  - `[false]` `[reject]` I-R4: the intent names `GrantsPrivilegeByEffect`'s user branch, and the create and directory-service legs (R9) pin the wider reach.
  - `[false]` `[reject]` I-R5: the copy's `COPY` gate requires `%Admin_Secure:USE` by the intent's own text, so a copy principal must hold it.
  - `[maybe-false]` `[defer]` I-R6: `UserCreateRules.Account` now keeps `EscalationRoles` for every caller, which may change the update form's save (medium if true); deferred with the settling check in the frontmatter.
  - `[maybe-false]` `[defer]` I-DW1662: the DW-1662 default-role leg's body may not carry `%Manager` (medium if true); deferred with the settling check in the frontmatter.

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

**Port gate (R3).** On the wire, the `%Admin_Secure:USE` check in `UserCopyPort.Copy` never answers first: the copy route's floor refuses a principal without it, and the confirm's pair gate does the same on the proposal path (runs 78, 82, 84). The port's own gate is pinned in-process by `Test/UserCopyNoGate`, a subclass whose `HoldsResource` answers no. That tests the gate's answer, not a real principal's identity; a real identity test would need `$System.Security.Login`, which CLAUDE.md forbids.

## Verification

**Setup.** Load with `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` (`LOAD-OK`, `STARTPATH-OK`). Browser runs use a rebuilt bundle `docker cp`'d to `ocupilot-ci`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`. S0 means no `OcuProbe1829*` principal, role or privilege row; `PasswordValidationRoutine` restored; monitor 0.

**Shared surfaces:** the role editor's Members tab, the user create form, the set-password dialog, the tool and route rosters, `Security.User` writes through `AdminPort`, and the authorization-server create. Standing criterion: *existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Bundle:** 3.16 MB against a 3165kB warning. The implement stage may re-base it under DW-1166.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, with totals checked in `%UnitTest_Result`. The classes: `UserCopy`, `PasswordPolicy`, `RoleSave`, `OAuthAuthorizationServerWire`, `UserCreate`, `UserCreateWire`, `UserUpdate`, `Prohibited`, and each class the sweep changed.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/users-create.browser-spec.mjs browser/roles-editor.browser-spec.mjs browser/users-actions.browser-spec.mjs`.
- `(loop)` `npm run test:tools && npm run test:components`, `uv run scripts/check-objectscript.py <changed .cls>`, `bash scripts/lint-docs.sh`.
- `(once, before dev_complete)` The full ObjectScript sweep, one class at a time; `cd ui && npm test && npm run build`; `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; S0.
- `(CI)` The full browser suite (Rule 29).

**Mutations (Rule 19)**, each recorded as `mutation: ... -> ... red (run n)`:

- C1: `Members` passes `AdminOption` through raw -> `RoleSave` red.
- C2: `ComposeCreate` drops `EscalationRoles` -> `UserCopy` red.
- R1: `Members` hard-codes `AdminOption` to `0` -> `RoleSave` red (run 45, pass 1; run 85, pass 2); reverted byte-identical; `RoleSave` green on the reverted tree (run 87).
- R2: `ComposeCreate` sets `EscalationRoles` to `Roles` -> `UserCopy` red (run 55, the composed-payload leg); reverted byte-identical.
- R3: the `%Admin_Secure` gate in `UserCopyPort.Copy` removed -> not load-bearing over the wire (run 56, pass 1; run 78, pass 2): the confirm's pair gate answers the refused principal 403 before the port, and the route's floor does so on the copy route. The confirm leg (`TestTheConfirmOfACopyAsAPrincipalWithoutAdminSecureIsRefusedByThePort`) stays green under this mutation, by design.
- R3 in-process (pass 2): the same removal -> `TestThePortRefusesACopyWhoseCallerLacksAdminSecureWhateverTheRoute` red (run 94); reverted byte-identical; green on the reverted tree (run 95). The seam is `Test/UserCopyNoGate`, whose `HoldsResource` answers no.
- R3 (pass 2) SQL-privilege copy: `VendorCopy` passes `0` for `SQLObjPrivs` -> `TestTheCopyCarriesTheSourcesSqlPrivilegesAndTheTeardownRemovesThem` red (run 79); reverted byte-identical.
- R4 routine legs: `Verdict`'s quoting replacement removed (`If 0 {`) -> `PasswordPolicy`'s quote, check-route and verdict legs red (run 80); reverted; `PasswordPolicy` green on the reverted tree (run 86).
- Check route gate (pass 2): `HandlePasswordCheck`'s `Gate` answers `$$$OK` without evaluating the form's pairs -> `UserCopy`'s floor-only leg red (run 84); reverted byte-identical. The same change with the floor-only principal absent (run 82) stays green, because the API floor refuses the no-admin principal first, so that leg pins the floor and not the form.
- SameNames (pass 2, named in the `UserCopy` header): `SameNames` answers 1 -> two source-changed legs red (run 89); reverted, `UserCopy` green (runs 88 and 90).
- R5: `IsPasswordType` without `"POST"` -> `PasswordPolicy` POST legs red (run 49); reverted byte-identical.
- R8: `AdminPort` reads the account name from the query on a `POST` -> `PasswordPolicy`'s body-named leg red (run 50); reverted byte-identical.
- C3: the inserted `EscalationRoles` line is removed -> `UserCopy`'s escalation leg red. R6/R9: the same removal -> `UserCopy`'s privileged-copy and create/directory-service legs red (run 57); reverted byte-identical.
- C4: `Verdict` returns the raw text (the codes forced, the quoting check dropped) -> `PasswordPolicy`'s quoting, check-route and verdict legs red (run 48); the guard is removed -> its set-password leg red.
- R7 browser: the copy's Save posts to `/users` -> `users-create` AC6 red (run: timeout at the Saved wait); the store's privileged flag forced true -> `users-create` AC6's plain-source leg red; `onBlur('Password')` removed from the create page -> `users-create` AC7 red; `AdminOption` hard-coded `0` -> `roles-editor` AC8 red; the dialog's `(blur)="onBlur()"` removed -> `users-actions` AC6 red. Each rebuilt, deployed, run red, restored byte-identical and rebuilt.
- C5: the `Defaults()` read is reverted -> `OAuthAuthorizationServerWire` red.
- Integration: Save posts to `/users` -> `user-create-form.store.spec.ts`'s copy leg red (`USERS_COPY_PATH`, run n), and `users-create` AC6 red under the same change.
- P1 (review pass 2): the Roles clause dropped from the source-changed check -> `UserCopy` roles-only leg red (run 98); reverted green (run 99).
- P2 (review pass 2): `AdminPort.PasswordGuard` logs the refused password under key `body` -> `UserCopy` log leg red (run 100); reverted green (run 101). `set-password-dialog.ts` appends the password to the reason -> `set-password-dialog.spec.ts` blur leg red (component run).
- P3 (review pass 2): `Prohibited.IsPrivilegedRole` returns 0 for the `%Admin_` prefix -> `UserCopy` `%Admin_*` legs red (run 103).
- P4 (review pass 2): `MintAs` mints as `permissions.users.copy.x` -> `UserCopy` ToolName assertion red (run 102). `PASSWORD_CHECK_PATH` changed -> `set-password-dialog.spec.ts` path leg red (component run). `role-editor.store.ts` form path changed -> `role-editor.store.spec.ts` GET assertion red (component run).
- P5 (review pass 2): the `$ListFind` gate in `PasswordPolicy.Verdict` deleted -> `PasswordPolicy`'s non-listed-code leg red (run 105).
- P6 (review pass 2): `SqlGrantsLeft`'s grantee match changed -> the positive control red (run 106).
- P7 (review pass 2): the `Copied` arm in `Prohibited.cls` deleted -> the four-field admitted leg red (run 104; eleven tests red in that run).
- P8 (review pass 2): the password echoed into `reason` -> the password-check marker leg red (run 107).
- P9 (review pass 2): `Snippet`'s `1, 1` changed to `0, 1` -> the Snippet leg red (run 108).
- P11 (review pass 2): the LDAP and delegated refusal removed -> `TestADirectoryOrDelegatedSourceIsRefusedOnCopyFrom` red (run 109). The `Copied` arm carries the P7 line (run 104).
- Every mutated file was restored from a saved copy and matched its pre-mutation hash.
- Review-pass verification: `UserCopy` 21/21 (run 96 initial, run 110 reverted); `PasswordPolicy` 9/9 (run 97 initial, run 111 reverted); `npm run test:tools` 1893 pass; `npm run test:components` 2686 pass; `check-objectscript.py` 0 problems over 1781 files.

## Auto Run Result

Status: done
Blocking condition: none

- Rework (pass 2): R3 port gate pinned in-process through `Test/UserCopyNoGate` (mutation red, run 94); the route floor and the confirm's pair gate answer first on the wire (Design Notes). Pass 1's record reconciled: R1-R9, V6 and V10 patches are in the tree with mutation lines. `ocupilot-ci` reads S0.
- Review (pass 2 triage, 2026-10-08): 24 findings. 15 patched as P1-P13; 3 low findings rejected; 4 false; 2 deferred to the frontmatter `deferred:` list (the escalation-filter change in `UserCreateRules.Account`; the DW-1662 default-role body).
- Patched by P-item: P1 Roles-only source change and case/order legs; P2 password absent from log and dialog card; P3 `%Admin_*` copy privilege; P4 integration path and tool-name pins; P5 POLICYCODES gate; P6 SQL-grant positive control; P7 four-field admission leg; P8 password marker absent from the whole body; P9 Snippet pin; P10 teardown status; P11 LDAP/delegated and `Copied` arm mutation lines; P12 validation-routine read guard; P13 test rename and `UserCopyError.Codes()` deleted.
- Verification on `ocupilot-ci` after the patches: `UserCopy` 21/21 (run 110) and `PasswordPolicy` 9/9 (run 111), green on the reverted tree. `RoleSave` 8/8 (run 87) is unchanged since. Every mutation in `## Verification` red, then byte-identical revert. `ocupilot-ci` reads S0 after run 111.
- Static: `npm run test:tools` 1893 pass; `npm run test:components` 2686 pass; `npm run build` initial total 3,164,712 bytes (main 2.96 MB, under the 3165 kB warning; measured in the rework pass, and no client bundle change since); `check-objectscript.py` 0 problems over 1781 files; `lint-docs.sh` exit 0, check-prose 0 problems; staged-equivalent secrets scan 0.
- Not run here: the full ObjectScript sweep (the runner's) and the full browser suite (CI). Pass 2 changed client spec files only.
- Follow-up review recommendation: false. The patches were medium and low; none was high.
- Residual risks: the port gate's test is a seam, not a real principal (`UserCopyNoGate` overrides `HoldsResource`). `Test/UserCopy.cls` is about 780 lines, above the 500-line guide; splitting it is left to the lead. The two deferred items are unverified.
