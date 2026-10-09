---
title: "Story 18.29: Role members' admin option, user Copy from and password validation"
type: 'feature'
created: '2026-10-08'
status: 'done'
baseline_commit: '19f2011de94e0054f05c028db480a61fea08a95c'
baseline_revision: '33287e8bc06efb6258cdd7a82da9645b12444440'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      Read-back field set (ReadBackFields) has no mismatch leg and no per-field check; outcome is pinned by stored-state asserts.
    evidence: |-
      Test/UserCopy.cls asserts readBack verdict 'matches' only on success; removing EscalationRoles from ReadBackFields would not redden. Stored state is pinned separately, so only the read-back's discrimination is unpinned.
    location: >- # file:line
      Screen/Tool/UserCopy.cls ReadBackFields
    severity: low
  - summary: >-
      Create-path password refusal passes only the code; the policy reason from PasswordPolicy.Verdict is computed and unused.
    evidence: |-
      UserCreateRules.cls around line 133 computes tPolicyReason and calls Add with USERPASSWORDPOLICY only, so the operator sees the generic sentence on create. The fix changes the Violations shape, so it is deferred to the story that owns create-form refusal text.
    location: >- # file:line
      src/OcuPilot/Area/Permissions/UserCreateRules.cls:133
    severity: medium
  - summary: >-
      DW-1662 test builds its own default-role list instead of the editor's real pre-ticked request.
    evidence: |-
      Intent: the surface is the editor's pre-ticked request. The OAuth wire test posts [%DB_IRISSYS, %Manager] itself. The spec's open question on whether the editor posts %Manager is unresolved, so the leg does not prove the editor's request.
    location: >- # file:line
      src/OcuPilot/Test/OAuthAuthorizationServerWire.cls
    severity: medium
  - summary: >-
      Client privileged flag may miss an escalation role the server counts (inference).
    evidence: |-
      user-create-form.store.ts computes privileged from the form's role flags plus escalation names. Unverified (inference): an escalation role absent from that list would give privileged false. Settles with a browser leg against a real instance whose copy source holds an escalation role.
    location: >- # file:line
      ui/src/app/areas/permissions/user-create-form.store.ts
    severity: medium (unverified)
  - summary: >-
      SurfaceCoverage row for permissions.users.copy points at the route-envelope test, not a tool-pinning test.
    evidence: |-
      Test/SurfaceCoverage.cls row (around line 219) is in Epic 20's diff against origin/feature, so Rule 11 blocks the repoint in this pass. The new tool test TestTheCopyToolPinsItsInputSchemaAndSnippetForm exists and is mutation-checked; the row must be repointed when Epic 20 lands.
    location: >- # file:line
      src/OcuPilot/Test/SurfaceCoverage.cls
    severity: low
  - summary: >-
      MapVendorRefusal (#837, #838, #845, #958, unlisted code) has no test.
    evidence: |-
      Port/UserCopyPort.cls MapVendorRefusal is [Private]; a $ClassMethod call from a test raises <PRIVATE METHOD>. Visibility was not changed. Settles by a test seam that does not change visibility, or by the owner accepting the gap.
    location: >- # file:line
      src/OcuPilot/Port/UserCopyPort.cls:234
    severity: medium
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

- [x] [Sweep] `ClassicPageGate.TestWithNoAssignmentEachToolsPairsAreItsDeclaredSet` (run 62). `permissions.users.copy` declares a replaced classic page but is absent from `OWNPAIRS` (68 declaring tools, 67 declared). Add its entry, in the form its `permissions.users.*` neighbours use, and make the count sentence "sixty-eight".
- [x] [Sweep] `MappingDescriptor.TestTheClassicPagesRosterIsTheDeclaringTools` (run 243). The classic-pages roster lacks the copy tool and its page. Add the row.
- [x] [Sweep] `PortGate.TestEveryPortDeclaresANamedGate` (run 310). `OcuPilot.Port.UserCopyPort` must declare and evaluate a named pair set (AD-29), as the other ports do, and join `PortGate`'s roster.
- [x] [Sweep] `ProhibitedRoute.TestTheUserWriteVerbsAreRosteredAndALiveSystemDisableOrDeleteIsRefused` (run 320). The users write-verb roster, now "seven", must name `permissions.users.copy` and count eight, with the copy asserted the way the roster's other verbs are.
- [x] [Sweep] `ReadTool.TestTheRegistryListsDescriptorReadsAndInheritedKinds` (run 346). Feature's 315 already includes Epic 20's 20.18 tools; the copy tool makes 316. Take the number and the names from the registry, and update both assertions' counts and sentences.
- [x] [Sweep] `SaveHoldCoverage.TestEveryWriteRouteTakesTheHoldOrIsExempt` (run 371). `POST /users/password-check` neither takes the target hold nor is listed exempt. It writes nothing, so add it to the exemption list with that reason, as other non-writing POSTs are listed; if it does write, it takes the hold.
- [x] [Sweep] `ToolWrite.TestEveryWriteToolsRequestTypeAgreesWithThePortsBodylessRoster` (run 464). `permissions.users.copy` writes `Security.User/COPY`, which the port declares a mutating pair, while the roster the test reads (the registry's pairs plus `AHEADTYPES`) does not admit it. Reconcile it as the test's message says.
- [x] [Sweep] `UserSave.TestTheSaveAndTheFormReadAnswerOneEnvelopeOverTheWire` (run 496): "without its escalation roles". This proves pass 2's deferred item about `UserCreateRules.Account`. The user form's read must answer without escalation roles again, for every caller, as before this story; only the copy path keeps the source's escalation roles. Pin it, with a mutation line.
- [x] [Deferred] Settle pass 2's other two `deferred:` items: the client's privileged flag for an escalation-role source (`user-create-form.store.ts`), and whether the DW-1662 default-role leg posts `%Manager`. Fix each one that is real, with a pinning test and its mutation line, or record under Design Notes, with evidence, why it is not. Then remove all three settled items from the frontmatter `deferred:` list.

**Acceptance Criteria:**

- **C1.** Given a probe role whose members include one granted `WITH ADMIN OPTION` and an escalation holder, when its Members tab is read, then each member shows whether it holds the admin option, compared by value, and the escalation holder reads as one, without it.
- **C2.** Given a probe source user, when a new user is created from it by the form's Save and by a confirmed proposal, as a principal holding only the Users pairs, then the account holds what `Security.Users.Copy` gives it (roles, escalation roles, settings, SQL privileges) and the read-back matches.
- **C3.** Given a source whose roles or escalation roles grant `%All` or an `%Admin_*` privilege, when its copy is proposed, then it is confirmed at the destructive treatment naming the privilege, and the form shows the consequence line.
- **C4.** Given a candidate password on the create form and the set-password dialog, when it is checked or sent, then `$SYSTEM.Security.ValidatePassword` answers. A refusal is 422 `USER.PASSWORD.POLICY` before any vendor write, and no reason, log line or card carries the password.
- **C5 (DW-1662).** Given a principal holding only the authorization server tab's two pairs, when it creates a configuration with the pre-ticked default roles, then the instance stores it.
- **Integration.** Given `ocupilot-ci`, when each consumer acts, then the create form goes through `POST /users/copy` and `POST /users/password-check`, the set-password dialog through the check route, the agent through `permissions.users.copy`, and the role editor through `GET /roles/form`.


### Review patches (pass 3 review, 2026-10-08)

Applied by a fresh implementation subagent. Each closes one finding in the Review Triage Log's pass-3 entry; each writes or corrects its `mutation:` line in `## Verification`.

- [x] RP1 `Area/Security/OAuthAuthorizationServerRules.cls` `Defaults()` read (around line 392): run the C5 mutation on `ocupilot-ci` (revert the create read to the pre-change `StoredRoles(pFresh)`), observe `OAuthAuthorizationServerWire` red, revert, record `(run n)` on the C5 mutation line.
- [x] RP2 `ui/src/app/areas/permissions/user-create-form.store.ts` `checkPassword` (around line 436, generation and `passwordValue` guard): add a vitest leg where the first check answer resolves after the value has changed and assert its reason is absent; add a mutation line that removes the guard.
- [x] RP3 `ui/src/app/areas/permissions/user-create-form.store.spec.ts` (the leg named for a valid answer clearing the refusal): add a `checkPassword` answering valid and assert `violationFor('Password') === ''`; mutation: delete the clear branch in `checkPassword`, observe red.
- [x] RP4 `user-create-form.store.spec.ts`: record the two unrecorded mutations, dropping `copy=1` from `setCopyFrom` and dropping `escalationRoles` from the `.some` at `absorbSource` (around line 650), each with the red test name and `(run n)`.
- [x] RP5 Component spec for `ui/src/app/areas/permissions/user-create-form.page.ts` consequence caption: a privileged copy source renders the sentence, a plain source does not. In `ui/browser/users-create.browser-spec.mjs` (around line 396) replace the fixed 500 ms sleep with a wait for the source read's answered signal. Mutation: mark every copy source privileged, observe the component spec red.
- [x] RP6 `Test/UserCopy.cls`: assert the `reason` field equals `UserCopyError` `REASONSOURCE` in the 422 body and `REASONSOURCECHANGED` in the 409 body. Mutation: change `REASONSOURCECHANGED`, observe red.
- [x] RP7 `Test/UserCopy.cls` `TestTheLeastPrivilegedPrincipalCopiesAndChecksAndTheOtherIsRefused`: assert roles, escalation roles, settings and read-back on the principal's copy, the same content asserts the `_SYSTEM` route copy makes. Mutation: `ComposeCreate` drops `EscalationRoles`, observe the principal leg red.
- [x] RP8 (QA: the row is repointed; it is this story's own line, so the edit is add-only relative to feature) `Screen/Tool/UserCopy.cls`: one assertion on `InputSchema` properties and required list, one on `SnippetForm`'s kind. Repoint the `permissions.users.copy` row in `Test/SurfaceCoverage.cls` (around line 219) at a method that pins the tool, only if `Test/SurfaceCoverage.cls` is unchanged on Epic 20's side since the merge base (`git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 diff --name-only origin/feature/OCU-1_ocupilot-mvp...HEAD`); otherwise report it as a blocking condition.
- [x] RP9 (QA: pinned through the public `Invoke`, visibility unchanged) `Port/UserCopyPort.cls` `MapVendorRefusal` (`[Private]`, around line 234): a test for #837, #838, #845, #958 and an unlisted code. If it cannot be reached from a test without changing its visibility, report it as a known gap in the Auto Run Result and do not change visibility.

Deferred and rejected in the triage log, not patched here: the create refusal's policy reason (`UserCreateRules.cls` around line 133), the read-back field set, the DW-1662 editor request, the client `privileged` inference.

### Review Findings

Code review, 2026-10-08 (four layers, full-opus): 106 raw findings in 27 entries (high 1, medium 8, low 18), and 34 rejected (appendix below).

- [x] [Review][Patch] (high) The create and the screen copy refuse a password with the published sentence, not the policy's reason (DW-2231; AD-39 as amended) [src/OcuPilot/Area/Permissions/UserCreateRules.cls:133]
- [x] [Review][Patch] (med) The agent's mint composes a copy of a directory-service or delegated source; only the confirm refuses it (matrix row Source) [src/OcuPilot/Screen/Tool/UserCopy.cls:1008]
- [x] [Review][Patch] (med) A source read that fails for any reason but absence is answered 422 `USERCOPY.SOURCE`, unlogged (AD-36: only the vendor's 404 is an absence) [src/OcuPilot/Port/UserCopyPort.cls:83]
- [x] [Review][Patch] (med) `GrantsPrivilegeByEffect`'s escalation call overwrites an error from the roles call, so the user branch fails open (AD-10) [src/OcuPilot/Kernel/Proposal/Prohibited.cls:4363]
- [x] [Review][Patch] (med) No test keeps the validator's own 845 or 958 sentence; removing either from `POLICYCODES` stays green [src/OcuPilot/Test/PasswordPolicy.cls]
- [x] [Review][Patch] (med) The guard's `CHANGEPWD` account name is unpinned [src/OcuPilot/Port/AdminPort.cls:1308]
- [x] [Review][Patch] (med) The set-password dialog keeps a refusal on an edited value, and its stale-answer guard is unpinned [ui/src/app/shell/set-password-dialog.ts:169]
- [x] [Review][Patch] (med) Re-choosing the copy source keeps the first source's full name and its `CopyFrom` refusal; the re-choice and clear paths are unpinned [ui/src/app/areas/permissions/user-create-form.store.ts:340]
- [x] [Review][Patch] (med) C2's confirmed-proposal leg asserts the account and its escalation role, not its roles, setting or read-back [src/OcuPilot/Test/UserCopy.cls]
- [x] [Review][Patch] (low) Copy from has no field reason, `aria-invalid` or `aria-describedby`; the copy fieldset has two legends; its consequence caption is referenced by nothing [ui/src/app/areas/permissions/user-create-form.page.ts:108]
- [x] [Review][Patch] (low) The user form's three new strings are published in the role editor's row; rows :115, :398 and :431 are not updated [EXPERIENCE.md:478]
- [x] [Review][Patch] (low) Router's doc says three sub-resources precede `POST /users`; five do [src/OcuPilot/Api/Router.cls:451]
- [x] [Review][Patch] (low) `AgentInput` sits between a test's doc comment and the test, and its stated reason contradicts Dispatch's order [src/OcuPilot/Test/ClassicPageGate.cls:199]
- [x] [Review][Patch] (low) `UserCopyPort.Copy`'s doc says `pResult` is `{}`; `DELEGATEDFLAG` has no doc [src/OcuPilot/Port/UserCopyPort.cls:54]
- [x] [Review][Patch] (low) `UserCreateRules.Account`'s doc says escalation roles are included; the default strips them [src/OcuPilot/Area/Permissions/UserCreateRules.cls:459]
- [x] [Review][Patch] (low) `POLICYCODES` calls 958 the history refusal (it is `InvalidPasswordPattern`); the test header says 845's sentence quotes the password [src/OcuPilot/Kernel/PasswordPolicy.cls:14]
- [x] [Review][Patch] (low) An assertion message contradicts its test, and `ALLROLE` is created and never used [src/OcuPilot/Test/UserCopy.cls:464]
- [x] [Review][Patch] (low) `UserCopy.ReadBackFields` is never consulted (QA run 582) [src/OcuPilot/Screen/Tool/UserCopy.cls:116]
- [x] [Review][Patch] (low) The arming roster's existing line was rewritten in a file Epic 20 is changing; add a line instead [scripts/ci-throwaway.sh:263]
- [x] [Review][Patch] (low) The copy's unlisted-refusal and exception paths log without screening the password, and the catch leaves `pHttpStatus` and `pFault` unset (AD-35) [src/OcuPilot/Port/UserCopyPort.cls:106]
- [x] [Review][Patch] (low) `RoleSave` never asserts the role member's `AdminOption` false [src/OcuPilot/Test/RoleSave.cls:150]
- [x] [Review][Patch] (low) Test names and a comment carry "pass 3" [ui/src/app/areas/permissions/user-create-form.store.spec.ts:299]
- [x] [Review][Patch] (low) The guard's "nothing is logged" half is unpinned [src/OcuPilot/Test/PasswordPolicy.cls]
- [x] [Review][Patch] (low) Mutation lines: the Integration agent line mutates the test helper; C1's and C4's guard-removal lines record no run [## Verification]
- [x] [Review][Patch] (low) The source picker keeps the previous open's names until the list read lands [ui/src/app/areas/permissions/user-create-form.store.ts:288]
- [x] [Review][Defer] (low) `Test/UserCopy.cls` is about 860 lines against the 500-line guide [src/OcuPilot/Test/UserCopy.cls] — deferred: wontfix-accepted, reopen_if the class passes 900 lines or another copy leg is added to it
- [x] [Review][Defer] (low) C2's SQL-privilege leg covers standard and admin privileges in USER as `_SYSTEM`, not column privileges, HSCUSTOM or the principal [src/OcuPilot/Test/UserCopy.cls] — deferred: wontfix-accepted, reopen_if `VendorCopy`'s arguments or its namespace handling change

**Rejected:**

- (false) A principal without the pairs gets `TOOL.ARGUMENTS` from the mint: Dispatch evaluates `RequiredPairs` before `ValidateArguments` and the mint (`Dispatch.cls:264-290`).
- (false) `users-actions` AC6's "sends nothing" cannot fail: a blur that posted to the action route reddens it, and the submit's 422 is pinned in-process.
- (false) Classification and ToolFields lack a `CopyFrom` row: it is not an account field, and `Prohibited.Copied` admits it.
- (false) Rule 30, the default pattern, `_SYSTEM` and the predefined roles: the spine's Tests row admits the freshly installed instance, and no test sets `PasswordPattern`.
- (false) `ClassicPageGate` edited beyond add-only: it is not a contended file, and the sweep item asked for the probe body.
- (low, by-design) The screen copy composes at Save, so `SOURCECHANGED` cannot fire there and the source's settings are not shown: the spec's Save posts four fields.
- (low, by-design) Copied SQL privileges are not checked against OcuPilot's schemas: AD-8's 18.29 amendment adds no check the classic page lacks; occurrence appended to DW-2172.
- (low, by-design) A refused password at the card's confirm spends the proposal: AD-34's single use, and the spec puts the guard at the port.
- (low, spec-bound) AD-39's amendment says the check answers 422; the spec and the code answer 200 `{valid, reason}`. The spine wording is the lead's (Rule 20).
- (low, theoretical) `AdminPort` still logs a vendor #837, #845 or #958 on `Security.User` `POST` or `CHANGEPWD`: the create rules and the guard refuse those first, so only a race reaches it.
- (low) AD-15's and AD-53's named gaps omit a screen copy's SQL privileges: spine wording, the lead's (Rule 20).
- (low, theoretical) The source can change between `SameNames` and the copy: real only with a concurrent role change inside the port's write.
- (low, theoretical) The `EscalationRoles` read-back compare is order-sensitive: both sides are the vendor's read of one stored string.
- (low, theoretical) `Verdict`'s containment check is case-sensitive: real only for a routine that changes the password's case in its text.
- (low) `HoldsPairs` ignores the permission half: administrative resources carry only USE (AD-8).
- (low) Save during a pending or failed source read shows no consequence: needs a slow or failed read, and the fix adds a guard.
- (low) The picker offers directory-service and delegated accounts and stops at 1,000: the server refuses with its sentence, and the list's `Type` words are unmeasured.
- (low) The blur check uses the name at blur, and the routine runs twice on a create: matters only for a name-dependent routine.
- (low) `absorbSource` fails open when the rules read failed: that read is the form's bootstrap.
- (low) `Verdict` has no `Try` for a throwing validator: unverified; `ValidatePassword` answers a status.
- (low) The guard is skipped for a numeric JSON password: needs a crafted confirm body.
- (low) `MUTATINGTYPES` names `Security.User/COPY`, which only `UserCopyPort` carries: the sweep item's reconciliation.
- (low) `UserCopy`'s inherited `EXCLUDEDFIELD`, its `SettableFields` doc, its unreachable `CopyFrom` rule and a literal code: no behavior differs, because `InputSchema` requires `CopyFrom` first.
- (low) The form path reports one violation at a time: the form always sends `CopyFrom`.
- (low) The parameter spelling `USEREndpoint`: no underscore, and the checker passes it.
- (low) `UserCopyError`'s two sentences are not in Fixed strings: they are server-only, DW-1502's question.
- (low) `Mentions(tBody, "Password")` is weak: it still fails when no Password field is named.
- (low) The check-route test re-serializes the body: the result carries every value the raw body does.
- (low) No route leg asserts `FullName`, and none copies a source without escalation roles: the read-back legs pin `FullName`.
- (low) `$SYSTEM.Monitor.Clear()` in `UserCopy`'s teardown: confined to the throwaway; no test reads the alert state across classes.
- (low) `oauth-server-defaults.test.mjs` compares source text: a deliberate cross-file roster pin.
- (low) The empty option is unlabeled, and the source's roles have no loading state: either needs a new Fixed-strings row.
- (low) The set-password leg never asserts the password unchanged: the guard answers before the vendor call by construction.
- (low) The spec's `deferred:` list and Auto Run Result are stale: the fix edits the spec under review; the lead reconciles them.

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


### 2026-10-08 — Review pass (pass 3, sweep rework)

- verdicts: 19 findings — high 0, medium 10, low 8, false 0, maybe-false 1 (of the 19, 5 are rejected: intent-alignment 1, 2, 6, 7 and verification-gap Other 2)
- findings:
  - `[medium]` `[patch]` verification-gap 1: C5's mutation was not run against the leg that now pins it (`OAuthAuthorizationServerRules.cls` create read) — patch RP1, run and recorded.
  - `[medium]` `[patch]` verification-gap 2: no test where a first password answer resolves after the value changed, so a stale refusal could land on a valid field — patch RP2.
  - `[medium]` `[patch]` verification-gap 3: the store leg named for clearing asserts only that a reason is set; deleting the clear branch stays green — patch RP3.
  - `[low]` `[patch]` verification-gap 4: the copy-URL (`copy=1`) and escalation-source client legs have no recorded mutation — patch RP4.
  - `[medium]` `[patch]` verification-gap 5: the consequence line has no component assertion, and the browser negative waits a fixed 500 ms before asserting absence — patch RP5. The pass-3 Auto Run Result claim that R7 is in the tree is corrected at its origin.
  - `[medium]` `[patch]` verification-gap 6: the two refusal sentences are never asserted; `REASONSOURCE` and `REASONSOURCECHANGED` can change unseen — patch RP6.
  - `[medium]` `[patch]` verification-gap 7: the least-privileged principal's copy asserts status and existence only, not roles, escalation roles, settings or read-back — patch RP7.
  - `[low]` `[defer]` verification-gap 8: `ReadBackFields` has no mismatch leg and no per-field check; the outcome is pinned independently by the stored-state assertions, so only the read-back's own discrimination is unpinned — deferred with `ReadBackFields` named.
  - `[medium]` `[patch]` verification-gap 9: no assertion on the tool's `InputSchema` properties, the `SnippetForm` kind, and the SurfaceCoverage row points at the route-envelope test — patch RP8.
  - `[medium]` `[defer]` verification-gap Other 1: the create path's password refusal passes only the code (`USERPASSWORDPOLICY`); `tPolicyReason` from `PasswordPolicy.Verdict` is computed and unused, so the operator sees the generic sentence on create. Deferred, not patched: the fix changes the `Violations` shape; route to the story that owns create-form refusal text.
  - `[low]` `[reject]` verification-gap Other 2: `Api/Account.cls` has its own password-change arm; the spec excludes that file ("never an Account.cls change"), so the review's scope note stands and nothing is changed. Not a defect of this diff.
  - `[low]` `[patch]` verification-gap Other 3: the pass-3 Auto Run Result says R1 to R9 are in the tree, but R7's component assertion is not — corrected in the Auto Run Result by the lead.
  - `[low]` `[reject]` intent-alignment 1: the intent names `%Admin_Secure:USE` as the copy's gate (`## Boundaries` COPY, step 1). The diff implements that gate. The least-privileged principal's coverage is the verification-gap 7 patch, not an intent divergence.
  - `[low]` `[reject]` intent-alignment 2: the escalation check in `GrantsPrivilegeByEffect`'s user branch reaches create and update proposals. The intent's Prohibited bullet names that branch explicitly, so the wider scope is the spec's own wording, not drift.
  - `[maybe-false]` `[defer]` intent-alignment 3: the client's `privileged` may miss an escalation role the server counts, because the store reads the form's role flags. Unverified; medium if true. Settles with a browser leg against a real instance whose copy source holds an escalation role.
  - `[medium]` `[patch]` intent-alignment 4: `MapVendorRefusal` (#837, #838, #845, #958 and the unlisted 500) has no test that reaches it — patch RP9.
  - `[medium]` `[defer]` intent-alignment 5: the DW-1662 test posts the roles it builds itself, not the editor's real request. The spec's own open question covers whether the editor posts `%Manager`; deferred to that question.
  - `[low]` `[reject]` intent-alignment 6: `InputSchema` may advertise create arguments beyond the intent's list. Not verified and at most low (it advertises existing create fields); not worth a fix here.
  - `[low]` `[reject]` intent-alignment 7: the inherited tool metadata comes from `UserCreate`, which this diff does not change. Not a defect of this change.

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

**Pass 3 (sweep and deferred items).** Each sweep failure is closed in its named test; the three deferred items settle as follows.

- *Escalation roles reach the copy source (real, fixed).* The form read had lost its `EscalationRoles` strip (commit 555bda7e), so `absorbSource` never saw a source's escalation roles. The strip is restored in `UserCreateRules.Account`, and the create form's copy-source read adds `copy=1` (`COPYSOURCEQUERY`), which keeps them. The privileged flag is `roles` plus `EscalationRoles` checked against the instance role list's server flags; that list holds every role the instance holds, so each escalation name carries a server flag (inference: a name the list omitted would be missed, and the list is the full `Security.Role` listing).
- *`UserCreateRules.Account` (real, fixed).* The update form's Save writes back what its read returns, so the read answers without escalation roles; only the copy-source read keeps them (`copy=1`). Pinned by `UserSave`.
- *DW-1662 default-role leg (real, fixed).* The leg posted `%DB_IRISSYS` alone. It now posts `%DB_IRISSYS` and `%Manager`, the pair the editor pre-ticks, in `OAuthAuthorizationServerWire`.
- *Copy's classic page gate (found in the sweep, fixed).* `UserCopy.PrivilegePairs` inherited `UserCreate`'s, which does not call `WithClassicPages`, so an assigned `%CSP.UI.Portal.User` did not gate the copy. It now calls it (AD-44), pinned by `ClassicPageGate`.
- *Named port gate (found in the sweep, fixed).* `UserCopyPort` declares `PAIRS = "%Admin_Secure:USE"` (AD-29) and evaluates it through `HoldsPairs`, which calls `HoldsResource` per resource, the seam `UserCopyNoGate` overrides.

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

- C1: demonstrated by R1 below (runs 45 and 85).
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
- C4: `Verdict` returns the raw text (the codes forced, the quoting check dropped) -> `PasswordPolicy`'s quoting, check-route and verdict legs red (run 48); the guard's call disabled in `AdminPort.InvokeLocated` -> `TestTheSetPasswordGuardRefusesBeforeTheVendor` and four other guard legs red (run 602); reverted, hash-identical, green (run 603).
- R7 browser: the copy's Save posts to `/users` -> `users-create` AC6 red (run: timeout at the Saved wait); the store's privileged flag forced true -> `users-create` AC6's plain-source leg red; `onBlur('Password')` removed from the create page -> `users-create` AC7 red; `AdminOption` hard-coded `0` -> `roles-editor` AC8 red; the dialog's `(blur)="onBlur()"` removed -> `users-actions` AC6 red. Each rebuilt, deployed, run red, restored byte-identical and rebuilt.
- C5: the create's `Defaults()` read is reverted to `Set tStored = ..StoredRoles(pFresh)` -> `OAuthAuthorizationServerWire` red (run 564, `TestALeastPrivilegedPrincipalCreatesWithTheDefaultRoles`); reverted, hash-identical, green (run 565).
- RP2 mutation: the `generation` / `passwordValue` guard line removed from `checkPassword` -> `user-create-form.store.spec.ts` leg `a check answer that lands after the password changed does not mark the new value` red (component run, `AssertionError` on the reason); reverted, hash-identical.
- RP3 mutation: the `if (valid)` clear branch deleted from `checkPassword` -> `user-create-form.store.spec.ts` leg `... and a valid answer clears it` red (component run); reverted, hash-identical.
- RP4 mutation: `&copy=1` dropped from `setCopyFrom`'s read -> `user-create-form.store.spec.ts` leg `Story 18.29 (pass 3): a copy source whose only privilege is an escalation role ...` red (component run, `expected false to be true`); reverted, hash-identical.
- RP4 mutation: `escalationRoles` dropped from `absorbSource`'s `.some` -> the same leg red (component run); reverted, hash-identical.
- RP5 mutation: `absorbSource` marks every copy source privileged (`const privileged = true`) -> `user-create-form.page.spec.ts` leg `a copy of a plain source states no consequence` red (component run); reverted, hash-identical. The browser leg `AC6: a copy source that holds no privileged role` waits on the drawn role instead of a fixed sleep; its own mutation is not re-run here.
- RP6 mutation: `UserCopyError.REASONSOURCECHANGED` loses its final period -> `OcuPilot.Test.UserCopy` `TestTheSourceChangedAtTheWriteIsRefused` red (run 569, the reason leg); reverted, byte-identical to HEAD, green (run 570).
- RP7 mutation: `ComposeCreate` drops `EscalationRoles` -> `OcuPilot.Test.UserCopy` `TestTheLeastPrivilegedPrincipalCopiesAndChecksAndTheOtherIsRefused` red (run 571, and again run 572, on its `201` and escalation-role legs); reverted, hash-identical, green (run 573).
- RP8 mutation: `CopyFrom` removed from `InputSchema`'s required list -> `OcuPilot.Test.UserCopy` `TestTheCopyToolPinsItsInputSchemaAndSnippetForm` red (run 574, `and requires CopyFrom`); reverted, hash-identical. The `permissions.users.copy` SurfaceCoverage row points at this test (QA block below).
- RP9: see the QA block below.
- Integration: Save posts to `/users` -> `user-create-form.store.spec.ts`'s copy leg red (`USERS_COPY_PATH`, component run, QA), and `users-create` AC6 red under the same change.
- P1 (review pass 2): the Roles clause dropped from the source-changed check -> `UserCopy` roles-only leg red (run 98); reverted green (run 99).
- P2 (review pass 2): `AdminPort.PasswordGuard` logs the refused password under key `body` -> `UserCopy` log leg red (run 100); reverted green (run 101). `set-password-dialog.ts` appends the password to the reason -> `set-password-dialog.spec.ts` blur leg red (component run).
- P3 (review pass 2): `Prohibited.IsPrivilegedRole` returns 0 for the `%Admin_` prefix -> `UserCopy` `%Admin_*` legs red (run 103).
- P4 (review pass 2): the copy tool's `TOOLNAME` renamed `permissions.users.copied` -> `ReadTool`'s registry roster leg red (run 601); reverted, hash-identical, green (run 605). `PASSWORD_CHECK_PATH` changed -> `set-password-dialog.spec.ts` path leg red (component run). `role-editor.store.ts` form path changed -> `role-editor.store.spec.ts` GET assertion red (component run).
- P5 (review pass 2): the `$ListFind` gate in `PasswordPolicy.Verdict` deleted -> `PasswordPolicy`'s non-listed-code leg red (run 105).
- P6 (review pass 2): `SqlGrantsLeft`'s grantee match changed -> the positive control red (run 106).
- P7 (review pass 2): the `Copied` arm in `Prohibited.cls` deleted -> the four-field admitted leg red (run 104; eleven tests red in that run).
- P8 (review pass 2): the password echoed into `reason` -> the password-check marker leg red (run 107).
- P9 (review pass 2): `Snippet`'s `1, 1` changed to `0, 1` -> the Snippet leg red (run 108).
- P11 (review pass 2): the LDAP and delegated refusal removed -> `TestADirectoryOrDelegatedSourceIsRefusedOnCopyFrom` red (run 109). The `Copied` arm carries the P7 line (run 104).
- Every mutated file was restored from a saved copy and matched its pre-mutation hash.
- Review-pass verification: `UserCopy` 21/21 (run 96 initial, run 110 reverted); `PasswordPolicy` 9/9 (run 97 initial, run 111 reverted); `npm run test:tools` 1893 pass; `npm run test:components` 2686 pass; `check-objectscript.py` 0 problems over 1781 files.

- **Pass 3 mutations (Rule 19), applied on `ocupilot-ci` and each reverted to a saved copy, hash-checked, then reloaded:**
  - `UserCreateRules.Account` strip made `If 0` -> `UserSave` red (run 553); reverted and green (run 558).
  - `HandleForm` `copy=1` ignored (`(0)`) -> `UserSave` copy leg red (run 559); reverted and green (run 561).
  - `UserCopy.PrivilegePairs` without `WithClassicPages` -> `ClassicPageGate` assigned-page leg red (run 549); reverted and green (run 554).
  - `UserCopyPort.PAIRS` emptied -> `PortGate` named-gate roster leg red (run 550); reverted and green (run 555).
  - `Security.User/COPY` removed from `AdminPort.MUTATINGTYPES` -> `ToolWrite` bodyless-roster leg red (run 551); reverted and green (run 556).
  - `/users/password-check` exemption removed from `SaveHoldCoverage.Exemptions` -> `SaveHoldCoverage` red (run 552); reverted and green (run 557).
  - `permissions.users.copy` removed from `ProhibitedRoute`'s users roster -> roster leg red (run 560); reverted and green (run 562).
- `ReadTool`'s count and name roster went red at the sweep (run 346, roster 315 against a registry of 316) and green after the edit (run 536); the DW-1662 leg's mutation is C5's line above; the client store's copy-URL leg is RP4's.

- **QA block (Story 18.29, 2026-10-08; every run on `ocupilot-ci` after a reload).**
  - Files (QA): `src/OcuPilot/Test/UserCopyRefusals.cls` (armed, 5 tests), `src/OcuPilot/Test/UserCopyVendorFault.cls` (the port with only its vendor call replaced), `ui/tools/oauth-server-defaults.test.mjs`. Changed: the `permissions.users.copy` row in `Test/SurfaceCoverage.cls`, `UserCopyRefusals` in `scripts/ci-throwaway.sh`'s arming roster, one leg in `oauth-server-form.store.spec.ts`.
  - Green: `UserCopyRefusals` 5/5 (run 577, 589, 591), `UserCopy` 22/22 (588, 592) in both orders with it, `SurfaceCoverage` 4/4 (583, 590), `npm run test:tools` 1901 pass, the store spec 12/12. `ocupilot-ci` reads S0 afterwards: no `OcuProbe1829*` account, role or privilege, `PasswordValidationRoutine` empty.
  - DW-2235 `MapVendorRefusal`: #837 against a real taken name, and #838, #845, #958 and an unlisted code through the seam, each asserted for status, code, field and sentence, none carrying the vendor's text, only the unlisted one in `messages.log`. Mutations: the `958` clause dropped -> `TestEachMappedVendorCodeAnswersItsOwnRefusalOnItsOwnField` and the log leg red (run 578); `837` respelled -> the real-vendor leg, the mapped leg and the log leg red (run 579); the final arm answers the source refusal -> `TestAnUnlistedVendorCodeIsA500WithoutTheVendorsText` and the log leg red (run 580).
  - DW-2230 read-back: `TestTheReadBackNamesEachFieldThatDisagreesWithTheCopy` reads back a real copy as sent (`matches`, no field, the password listed as written) and with `FullName`, `Roles` and `EscalationRoles` each differing (`differs`, that field alone). Mutation: the copy tool's `EscalationRoles` row removed from `ToolFields` -> its leg red alone (run 581). The tool's `ReadBackFields` is not consulted while `ToolFields` carries rows for the tool: dropping `EscalationRoles` from it leaves `UserCopyRefusals` green (run 582).
  - DW-2234: the `permissions.users.copy` row names `TestTheCopyToolPinsItsInputSchemaAndSnippetForm`. Mutations: the method respelled -> `TestEveryCoverageRowNamesATestTheSuiteExecutes` red (run 584); the row removed -> `TestEveryWriteToolHasACoverageRowAndBack` red (run 585).
  - DW-2232: the editor's request is the client's `NEW_HELD.roles` (the form read answers no default list). `oauth-server-form.store.spec.ts`'s DW-1662 leg pins the untouched create's `CustomizationRoles`; `oauth-server-defaults.test.mjs` holds it equal to `Defaults()` and to the wire test's posted list. Mutations: `%Manager` out of `NEW_HELD.roles` -> the store leg and the tools test red; a role added to `Defaults()` -> the tools test red; the wire test's list shortened -> the tools test red.
  - Roster rows without an observed red: `EndpointCoverage`'s `/users/copy` probe removed -> red (run 586); `ToolRoundTrip`'s `permissions.users.copy:TOOL.ARGUMENTS` removed -> red (run 587); `field-lists.test.mjs`'s `permissions.users.copy` row removed -> red.
  - Rule 30: the story's classes create what they use and remove it; the browser specs create their accounts by exact name and remove them in `before` and `after`. The one instance-wide setting, `PasswordValidationRoutine`, is read and restored by `PasswordPolicy`. No dependency on a sibling's leftovers found.

- **Code review block (2026-10-08, `ocupilot-ci`, each run after a reload; one class per run).**
  - Mutations, run 599 (three applied together, each on its own leg; the other nine green): the reason dropped from `Validate`'s password violation -> `PasswordPolicy` `TestACreateRefusalCarriesThePolicysOwnReason` red; 845 removed from `POLICYCODES` -> `TestThePatternRefusalsKeepTheirOwnSentence` red; the `CHANGEPWD` account name read as `""` -> `TestASetPasswordIsJudgedByTheAccountNameInItsQuery` red.
  - Mutations, run 600 (three together, each on its own leg; the other five green): `ComposeCreate` refuses only an absent source -> `UserCopyRefusals` `TestTheMintsCompositionRefusesADirectoryOrDelegatedSource` red; `Copy` answers every unread source with `SourceRefusal` -> `TestASourceReadThatFailsIsAFaultNotARefusalOfTheSource` red; `MapVendorRefusal` calls `Fail` without the body -> `TestAnUnlistedRefusalQuotingThePasswordIsLoggedWithoutIt` red.
  - Every mutated file restored from its copy, hash-identical; green on the reverted tree: `PasswordPolicy` 12/12 (603), `UserCopyRefusals` 8/8 (604), `ReadTool` 28/28 (605).
  - Client mutations (component runs, each reverted byte-identical): the full-name clear on a re-choice removed, and the `copyFromValue !== name` guard removed -> the store's re-choice leg red; the dialog's value guard removed, and its clear on input removed -> the dialog's stale-refusal leg red; the effect id dropped from the select's `aria-describedby` -> the page spec's privileged leg red.
  - Not pinned: the `GrantsPrivilegeByEffect` error guard, because no public call makes `GrantsPrivilege` throw.
  - Patched tree: `PasswordPolicy` 12/12 (593), `UserCopyRefusals` 8/8 (594), `UserCopy` 22/22 (595), `RoleSave` 8/8 (596), `UserCreate` 9/9 (597), `ClassicPageGate` 8/8 (598); `npm run test:tools` 1901, `npm run test:components` 2726; build 3.17 MB; `users-create` 8/8 and `users-actions` 3/3 on the rebuilt bundle; `check-objectscript.py` 0 problems; `lint-docs.sh` exit 0. `ocupilot-ci` at S0, its alert state reset after the mutation runs; `OcuPilotProbeProhibitedRouteRole`, present before the review, left as found.

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

### Pass 3 (rework, lead's sweep and deferred items)

- Changed: `Port/UserCopyPort.cls` (`PAIRS`, `HoldsPairs`), `Screen/Tool/UserCopy.cls` (`PrivilegePairs` gates on the classic page), `Area/Permissions/UserCreateRules.cls` (escalation strip restored; `copy=1` flag), `Port/AdminPort.cls` (`Security.User/COPY` mutating), `Test/PortFixture.cls` (same), `Test/ClassicPageGate.cls` (OWNPAIRS `permissions.users.copy` entry and the probe body), `Test/MappingDescriptor.cls` (classic roster row), `Test/PortGate.cls` (roster row), `Test/ProhibitedRoute.cls` (copy in the users roster, eight), `Test/ReadTool.cls` (316, name inserted), `Test/SaveHoldCoverage.cls` (password-check exemption), `Test/UserSave.cls` (default strip and `copy=1` legs), `Test/OAuthAuthorizationServerWire.cls` (default-role leg posts both pre-ticked roles), `ui/src/app/areas/permissions/user-create-form.store.ts` (copy-source read adds `copy=1`), and its spec (one escalation-source leg).
- ObjectScript on `ocupilot-ci` (one class per run, after each reload): `ClassicPageGate` 8/8 (run 532, the green run after the last edit; the summary line carries no index), `MappingDescriptor` 6/6 (533), `PortGate` 4/4 (534), `ProhibitedRoute` 24/24 (535), `ReadTool` 28/28 (536), `SaveHoldCoverage` 2/2 (537), `ToolWrite` 34/34 (538), `UserSave` 7/7 (539), `UserCopy` 21/21 (540), `PasswordPolicy` 9/9 (541), `OAuthAuthorizationServerWire` 8/8 (542), `UserCreate` 9/9 (543), `UserCreateWire` 5/5 (544), `UserUpdate` 23/23 (545), `RoleSave` 8/8 (546), `GovernanceBaseline` 3/3 (548). Run 547 is an extra, unplanned `OAuthAuthorizationServerWire` run from a repeated shell command; its output was discarded, so its result is not recorded here.
- Client: `npm run test:tools` 1900/1900 pass; `npm run test:components` 2720/2720 pass (209 files); `npm run build` clean. Initial total 3,173,310 bytes (main 2,967,913 + styles 205,397), under the `angular.json` `maximumWarning` of 3326kB, which Epic 20 re-based (commit ddd5f82a); no re-base was needed here. The spec's earlier "3165kB" figure is superseded by that re-base.
- Browser: `users-create` 8/8 on the rebuilt bundle (`docker cp` to `ocupilot-ci`).
- `ocupilot-ci` state after the runs: no `OcuProbe1829*` user, role or resource (SQL counts 0); `PasswordValidationRoutine` reads empty; `$SYSTEM.Monitor.State()` reads 2, not 0 as the S0 definition says. I did not clean or restart anything, and I did not establish whether the 2 predates this pass. Reported to the lead as a non-S0 reading.
- Epic 20 contention: `Test/ReadTool.cls` is a listed shared file; the edit is in place (one count literal, one name, one sentence), as the sweep item asks. No other shared file was touched.
- Not run here: the full ObjectScript sweep, the full browser suite, `smoke.sh`.
- Review (pass 3, 2026-10-08): 19 findings from verification-gap and intent-alignment; 0 high, 10 medium, 8 low, 1 maybe-false; 5 rejected (the Triage Log has each row). Patched as RP1-RP7 (C5 mutation run 564 red, 565 green; RP6 mutation run 569 red, 570 green; RP7 mutation runs 571-572 red, 573 green; RP8 test mutation run 574 red, 575 green; RP2-RP5 vitest and the users-create browser spec, 8/8). Deferred to the frontmatter `deferred:` list: RP8 row repoint (blocked by Epic 20's diff on SurfaceCoverage.cls, Rule 11) and RP9 (MapVendorRefusal is Private), plus four review items.
- Non-S0 reading on `ocupilot-ci` after the RP runs: a role `OcuPilotProbeProhibitedRouteRole` is present. Not created by this pass's runs as reported by the patch subagent; not cleaned, and the lead decides.
- Patch follow-up: `Test/UserCopy.cls` is about 860 lines, above the 500-line guide (residual, as in pass 2).
- Follow-up review recommendation: false (no high patched; the medium patches close review items with tests, not logic changes).

