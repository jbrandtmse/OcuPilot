---
title: 'Story 9.1: The user editor'
type: 'feature'
created: '2026-09-23'
status: 'done'
baseline_revision: '1d0ad5eb590985d347fb6e29e4ef13594891dffc'
baseline_commit: '1d0ad5eb590985d347fb6e29e4ef13594891dffc'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A user can be created (8.2) and acted on from the Users list (7.2), but there is no screen that edits an existing user: `permissions/users/edit/<id>` mounts the create page, which ignores the id. Six routed entries are also due here, among them a HIGH card row that AD-51 forbids (DW-1576).

**Approach:** Add a tabbed user editor at `permissions/users/edit/<id>`, with General and Roles tabs named after the classic page's tabs. Save goes through `UserUpdate` on a new `PUT /users/:id` (AD-55), with the tool's permitted fields widened to the whole classic General tab. The editor's Delete, Set password and Add/Remove role reuse 7.2's AD-53 actions. The tabs (with their error dot and count) and the action dialogs become shared components for 9.2–9.8 to reuse. The existing error-summary markup and the `FormDirty` guard are reused as they are. The six routed entries are fixed as listed in the tasks.

## Boundaries & Constraints

**Always:**

- Save reads the target fresh, merges only the fields the client changed, and sends the complete set (AD-4). This follows `DeviceSave`'s order: pairs first, then a fresh read (404 sends nothing), then refusal of any undeclared body key with 400, then the rules, then the merge, then the prohibited set, then the send.
- Save carries no `Roles`, `EscalationRoles`, `Password` or `NewPassword`. Roles change only by the server-side delta on AD-53's route (AD-56 ii).
- The screen and the agent share one tool (`permissions.users.update`) and one rule set (`UserCreateRules`, update mode). The prohibited set is evaluated before any port call.
- A privileged role (`%All`, `%Admin_*`, or a role carrying one) is permitted everywhere:
  - on the agent path, the proposal is minted destructive;
  - on the screen, `privilegedGrantEffect` is shown.
- The only refusals are `PROHIBITED.PRIVILEGEGRANT`, `PROHIBITED.OCUPILOTRESOURCE` and the account arms, each judged by effect (AD-10).
- Every new input has an accessible name. No control is narrower than its declared minimum, and no element overflows its container.
- New strings are appended to `strings.ts` and to EXPERIENCE.md's Fixed-strings rows. Nothing is reordered or rewritten. Non-ASCII is written as `\uXXXX`.

**Never:**

- No third write mechanism. Save is AD-55; editor actions are AD-53.
- No edit to the Roles description sentence in `Screen/Tool/UserUpdate.cls` (DW-1537).
- No edits in Epic 15's exclusive paths: `ui/src/styles/_tokens|_theme|_typography|_metrics.scss`, `shell/rail*`, `areas/home/**`, `shell/account-menu*`, `core/account-preferences*`.
- No SQL-privilege or EscalationRoles tabs.
- No PhoneProvider picker. The admin API has no provider endpoint and AD-27 names no fallback for one, so it is a text field.
- No private keys in any file.
- No run of the full browser suite locally.
- No edit to `ui/src/app/shell/toast-host.ts`: Epic 15 has modified it (contended, Rule 11). The toast rule lives in `core/navigation.ts` and `core/toasts.ts`, which toast-host already calls. If an edit there proves unavoidable, HALT `intent gap` naming it.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Two-field save | `PUT /users/<id>` `{FullName, Comment}` on a user with every field set | 200. The vendor receives all 16 read fields, and the other 14 read back unchanged. A change event `user`/`updated` is published. | — |
| Undeclared key | body carries `Roles`, `Password`, `NewPassword` or `EscalationRoles` | 400 `PORTFIELDUNEXPECTED` in `detail.violations`, nothing sent | — |
| Two-factor | TOTP (2^21) and SMS (2^20) both on, or `AutheEnabled` differs from stored in any other bit | 422 violation on `AutheEnabled`, nothing sent | reason written on the server (AD-39) |
| Error on another tab | Save pressed on Roles with an invalid General field | General opens, shows the `destructive` dot and is named "General, 1 error". The summary takes focus, then the field. | — |
| Protected account | `Enabled` off on `_SYSTEM`, the signed-in user or the last `%All` holder, via Save | 403 with the published sentence. The Enabled field is drawn disabled beforehand for `protected-account`. | — |
| DW-1520 | new password, or `ChangePassword` turned on, for `CSPSystem`/`_Ensemble`/`irisowner` (either caller) | 403 `PROHIBITED.SERVICEACCOUNTSIGNIN`. The row and editor actions are drawn disabled with that sentence. `_SYSTEM`, the signed-in user and turning the flag off stay permitted. | — |
| DW-1516 | agent confirms the flag proposal, then later the password proposal (or the reverse order) | the user ends with `ChangePassword` true either way | a failed re-apply answers the port's fault; the password stands |
| DW-1576 | agent proposes `security.auditsystemevents.reset` (or the user-events reset) on an event whose Total is 25184 | card row `Total` 25184 → 0, read from `LIST names=<EventName>` | zero matching rows means absent (404) |
| DW-1523 | Add role dialog, from the Users list or from the editor's Roles tab, with a privileged role selected | `privilegedGrantEffect` is shown under the select and referenced by `aria-describedby` | — |
| DW-1546 | a task resumed on Task details (UJ-6) | toast "Open in Task schedule" is shown and opens `tasks/schedule/<id>` with the row selected | hidden only while that list is open |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Tool/UserUpdate.cls`:
  - PERMITTEDFIELDS is `:47`. SCREENACTIONS (`:54`) includes `require-password-change` and `add-role`/`remove-role`. `ScreenActionDelta` is `:151-213`.
  - The Roles description sentence is off-limits.
- `Screen/Tool/UserPassword.cls`:
  - WRITETYPE is CHANGEPWD and SECRETBODY is `Password`. The port renames `Password` to `NewPassword` (`AdminPort.RENAMEDTYPES`).
  - FINGERPRINTSUBJECT is `Enabled`.
- `Screen/Tool/FieldLists.cls:374`, `Classification.cls:94` → generated `ToolFields.cls` via `ui/tools/field-lists.mjs`:
  - 14 ordinary `Security.User` fields.
  - `Roles` and `EscalationRoles` are opaque.
- `Kernel/Proposal/Prohibited.cls`:
  - `User()`: `:860-914`. The arms are at `:868-890`.
  - `Prohibits` passes `RemovesOf` at `:569-571`.
  - `PermittedChangeFields("user")`: `:390`. `SERVICEACCOUNTS`: `:228`. `IsServiceAccount`: `:1982`.
  - `WriteTypeOf`: `:1056`. `SkippedFields`: `:2163`.
  - Codes: `:96-165`. `ReasonFor`: `:313`.
- `Kernel/Proposal/Mint.cls`:
  - Fresh read at `:163-174` (the object-only presence test is `:174`).
  - `StateDiff` is called at `:223`. `Merge` is `:421-433`.
- `Kernel/Proposal/Operation.cls`: `Query` `:173-184`, `ReadAt` `:203-210`, `Apply` `:298`. This is the one operation both callers use.
- `Screen/Tool/Write.cls`: READTYPE `:57`, READANSWERS `:170`, `PortQuery` `:331`, `IdParam` `:421`.
- `Screen/Tool/AuditEventReset.cls`:
  - READANSWERS is `Description,Enabled` (L45). IdParam is `event` (L74), which the port splits.
  - `StateDiff` hardcodes before `""` at L121. `AuditUserEventReset.cls` inherits it.
  - `Test/AuditEventTools.cls:80-83` pins the defect.
- `Api/Router.cls`:
  - User routes: `:98-100`. Handlers: `:309-323`.
  - The edit precedent is `PUT /device/:id` (`:118`, `:461`).
- `Area/OsMgmt/DeviceSave.cls` `Update` `:155-221` and `DeviceRules.cls:226` (form read with the fresh object) are the edit-Save pattern.
- `Area/Permissions/UserCreate.cls` (`RenderViolations` `:200-207`) and `UserCreateRules.cls`:
  - `Validate` `:64`, create-only.
  - `HandleForm` `:247` answers `roles:[{name, privileged}]`.
- `Screen/Descriptor/UserForm.cls`: form-page, `permissions/users/edit`, id `single`, `secretArguments: []`.
- `UserList.cls`: rowActions and `secretArguments: ["Password"]`.
- `Screen/Registry.cls`: `SELFPROTECTIONRULES` `:2186`.
- `Test/RefusalCopy.cls:41` pins each code's sentence.
- Client, form pieces:
  - `ui/src/app/areas/os-management/device-form.page.ts` + `.store.ts` is the create+edit precedent: `ownIdSegment`, re-open on `NavigationEnd`, send changed fields only.
  - `areas/permissions/user-create-form.page.ts` holds the summary, legend, form bar and leave dialog markup.
  - `core/form-dirty.ts` and `app.routes.ts:24,73-80` (`leaveFormGuard`, form-page archetype only) are the guard. `shell/agent-navigator.ts:92-110` already routes agent navigation through it.
  - `core/violations.ts:35`.
- Client, shell and routing:
  - `ui/src/app/shell/screen-outlet.ts:95-110` (`DESCRIPTOR_PAGES`).
  - `core/navigation.ts`: `EDITOR_ROUTE_SUFFIX` `:167`, `CREATE_ONLY_FORMS` `:201`, `screenForEntityType` `:407`, `screenForChange` `:486`.
  - `core/toasts.ts:193-196,285-288`; `shell/toast-host.ts:195,223`.
  - `list-page.ts:217-219`: a list's `/:id` selects the row.
- Client, row actions:
  - `ui/src/app/shell/screen-action-handler.ts`: `start` is private and reads the list selection (`:538`); `submitPassword` is `:336-346`; `openRole` is `:444-464`; `send` is `:489-526`; `sendFor` is `:533`.
  - `shell/role-dialog.ts:26-27`. The dialogs render in `list-page.ts:89-105`.
  - `core/self-protection.ts:46-83`.
- Client tests and strings:
  - `ui/tools/navigation.test.mjs:966,970,972`.
  - `ui/src/app/core/strings.ts`: `privilegedGrantEffect` `:1408`, `formSaved` `:252`, `formLeaveWithoutSaving` `:256`.
- Browser:
  - `ui/browser/users-actions.browser-spec.mjs` (`irisSession`, probe create/delete, `signedInAt`).
  - `task-resume.browser-spec.mjs` is the UJ-6 replay. Its AC4 test confirms the resume on Task details.

## Tasks & Acceptance

**Execution:**

Server tasks:

- `src/OcuPilot/Screen/Tool/UserUpdate.cls`, `Kernel/Proposal/Prohibited.cls` (`PermittedChangeFields("user")`), `FieldLists.cls`/`Classification.cls`:
  - Permit the classic General set: AccountNeverExpires, AutheEnabled, ChangePassword, Comment, EmailAddress, Enabled, ExpirationDate, FullName, HOTPKeyDisplay, NameSpace, PasswordNeverExpires, PhoneNumber, PhoneProvider, Routine.
  - Author each field's description, and an enum where the set is closed.
  - Regenerate `ToolFields.cls` (`node ui/tools/field-lists.mjs`).
  - `ArgumentProblem` runs the update-mode rules.
  - Why: every editor ships its agent tool over the derived list (AD-3).
- `src/OcuPilot/Area/Permissions/UserCreateRules.cls`:
  - Add an update mode for `Validate`: scalar shapes and lengths (MAXLEN read from `Security.Users` on the instance) for Comment, EmailAddress, PhoneNumber and PhoneProvider.
  - `AutheEnabled`: only bits 2^20 (SMS) and 2^21 (TOTP) may differ from stored, and not both may be on (measured with `%sySecurity`).
  - `HandleForm` with `?name=` also answers `user`, the tool's fresh read without EscalationRoles.
  - Why: one rule copy for both callers.
- `src/OcuPilot/Area/Permissions/UserSave.cls` (new) plus `Api/Router.cls`:
  - Add `PUT /users/:id` → `UserSave`, following `DeviceSave.Update`'s order through `UserUpdate`.
  - Place it after `/users/form` and `/users/name`.
  - Why: AD-55.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (DW-1520):
  - Pass the tool's write type into `User()`.
  - A new service-account arm refuses code `PROHIBITED.SERVICEACCOUNTSIGNIN` when the target is a service account and either the write is CHANGEPWD or its diff turns `ChangePassword` on.
  - Add the code's REASON parameter and its `ReasonFor` mapping.
  - Why: AD-10 by effect.
- `src/OcuPilot/Screen/Tool/Write.cls`, `UserPassword.cls`, `Kernel/Proposal/Operation.cls` (DW-1516):
  - Add a no-op after-write hook on `Write`, called by `Operation.Apply` once the write reads OK.
  - `UserPassword` overrides it. When the operation's fresh read had `ChangePassword` true, it re-reads, sets it true, and PUTs the complete body through the same port.
  - Why: the pair ends set in either confirm order, for both callers.
- `src/OcuPilot/Screen/Tool/Write.cls`, `Mint.cls`, `Operation.cls`, `AuditEventReset.cls` (DW-1576):
  - Add optional `READIDPARAM` (the query key the fresh read sends the id under; defaults to `IdParam`) and `READROWKEY` (when set, the read answers an array and the target is the one row whose key equals the id ignoring case; no row reads as 404).
  - The mint and `Operation.ReadAt` share one helper for this.
  - The reset tools declare READTYPE `LIST`, READIDPARAM `names`, READROWKEY `EventName`, and READANSWERS `EventName,Enabled,Total,Written,Lost`. FINGERPRINTSUBJECT stays `Enabled`. `StateDiff`'s before is `fresh.Total`.
  - The CLEARCOUNT write keeps `event`.
  - Why: AD-51, rows come from the fresh read.
- `src/OcuPilot/Screen/Descriptor/UserForm.cls`, `UserList.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`:
  - Append self-protection rule `service-account-sign-in`. `set-password` and `require-password-change` declare it.
  - Add an optional descriptor key `suggestedPrompts` `[{groupKey, textKey}]`, placed beside `commandAliases` and validated identically by both engines: at least 3 when present, keys that resolve in strings. `UserForm` declares 3.
  - `UserForm`'s label reads as an editor.
  - Regenerate the mirror.
  - Why: AD-5, AD-53, Story 11.3's contract.
- Tests:
  - `src/OcuPilot/Test/UserSave.cls` (new, HTTP): pins the two-field survival (all 16 read back), the four undeclared keys refused, the AutheEnabled rules, `_SYSTEM` disable refused, a privileged Roles grant absent from Save, and the form read's `user`.
  - `Test/UserSignIn.cls` (new): pins DW-1520 (each service account × {password, flag on} refused on both callers; `_SYSTEM`, self and flag-off permitted) and DW-1516 (flag then password, and password then flag, both end true).
  - `Test/AuditEventTools.cls`: before equals the LIST Total.
  - `Test/RefusalCopy.cls`: the new code's sentence.
  - `Test/UserUpdate.cls`: adjust its unreviewed-field test to the widened set.

Client tasks:

- `ui/src/app/core/form-tabs.ts` (new, framework-free) plus `ui/tools/form-tabs.test.mjs`:
  - Given a field→tab map and violations, answer per-tab counts, the tab to open (the one holding the first violation in field order), and the accessible name "<label>, 1 error" / "<label>, <n> errors".
  - Why: shared pattern, AD-19.
- `ui/src/app/shell/form-tabs.ts` (new):
  - `mat-tab-group` with `preserveContent` and a `destructive` dot per tab with errors; Left/Right between tabs.
  - Inputs: tabs, counts and selected. Output: selectedChange. Tab bodies are projected.
  - Styles are appended to `_components.scss`.
- `ui/src/app/shell/screen-action-handler.ts`, `list-page.ts`, new `shell/screen-action-dialogs.ts`:
  - Add a public `startFor(descriptor, actionId, target, rowFields, refusalSink)` that `start` also uses.
  - Move the dialog block out of `list-page` into a shared component so the editor renders the same dialogs.
  - `add-role` options come from `GET /users/form` `roles[]`.
  - Why: DW-1501 with no new mechanism.
- `ui/src/app/shell/role-dialog.ts`:
  - Take a `privileged` set. Show `STRINGS.privilegedGrantEffect` under the select when adding a privileged role, wired with `aria-describedby`.
  - Why: DW-1523.
- `ui/src/app/areas/permissions/user-editor.page.ts`, `user-editor.store.ts` (new) plus `.spec.ts`:
  - Loads `GET /users/form?name=<id>`, with fields locked until then.
  - General tab: the 14 fields in classic order. Two-factor is two mutually exclusive checkboxes mapped to the two bits; the display-QR option shows while TOTP is on.
  - Roles tab: held roles, each with Remove, plus Add role.
  - Header actions: Set password, Delete. Drawn disabled with the reason per `self-protection.ts`.
  - The sticky bar sends changed fields to `PUT`.
  - A failed Save focuses the summary, opens the tab and focuses the field. The unsaved-changes guard comes from `FormDirty`.
  - "Saved" is shown and the route stays open.
  - A change event re-reads in place while the form is clean. While dirty, only roles are re-read.
  - Delete returns to the list.
- `ui/src/app/shell/screen-outlet.ts`, `core/navigation.ts`:
  - `DESCRIPTOR_EDIT_PAGES` renders `UserEditorPage` when the route carries an id; `/edit` keeps 8.2's create page.
  - Remove `UserForm` from `CREATE_ONLY_FORMS`, so the name cell links to the editor.
- `ui/src/app/core/navigation.ts`, `core/toasts.ts`, `shell/toast-host.ts` (DW-1546):
  - `screenForEntityType` answers the entity's list: the built `list` with that type and the lowest non-zero `sideBarPosition`, else any built list, else the current rule. It is the one lookup `screenForChange` and toast-host use.
  - `publish` hides a toast only when the open screen is that target and the scope matches.
  - Rewrite the pins at `navigation.test.mjs:966/970` to the list rule (task → `tasks/schedule`). `toasts.test.mjs` pins the new hide rule.
- `ui/src/app/core/self-protection.ts` plus `ui/tools/self-protection.test.mjs`: add the `service-account-sign-in` rule and pin its sentence to the server's.
- `ui/src/app/core/strings.ts`: append, each with its EXPERIENCE.md Fixed-strings row:
  - tab labels General and Roles (reuse existing keys where they exist);
  - the new field labels;
  - the tab error suffixes;
  - the SERVICEACCOUNTSIGNIN sentence;
  - the 3 prompts.

Browser tasks:

- `ui/browser/users-editor.browser-spec.mjs` (new): Rule 3 and the visual gate. Checks:
  - the name cell opens the editor, with tabs General and Roles;
  - a two-field Save reads back via `docker exec`;
  - the Roles-tab error switch, dot and accessible name;
  - the leave guard;
  - editor Set password, and Add role with the privileged line;
  - Delete;
  - every input has a name, and nothing overflows.
- `users-actions.browser-spec.mjs`: the list's Add role consequence line (DW-1523), and set-password drawn disabled on `CSPSystem`.
- `task-resume.browser-spec.mjs`: after the AC4 confirm, the toast "Open in Task schedule" appears on Task details, and clicking it lands on `tasks/schedule/<id>` with the row selected (DW-1546).
- `users-create.browser-spec.mjs`: re-point any post-create assertion to the editor that the create now opens.

Review patches (2026-09-23 review pass; each adds or tightens a test, plus its `mutation:` line):

- P1 `Test/UserSave.cls` (or `UserSignIn`): mint `permissions.users.update` through the agent path (`View` under a seeded turn, as `UserSignIn.Confirm` does) with `AutheEnabled` both-on, and with a non-two-factor bit moved; each is refused with a problem naming `'AutheEnabled'`. Mutation: `UserUpdate.ArgumentProblem` answers `""`.
- P2 `Test/AuditEventTools.cls`: mint `security.auditsystemevents.reset` for the system event; the proposal's state row `before` equals the LIST row's `Total`, `after` `0`. Mutation: revert the mint's read in `Mint.cls` to `tQuery(pIdParam)` plus a direct `Invoke`.
- P3 `Test/WireSecurityRead.cls`: `PUT /api/ocupilot/users/<name>` by `SYSREADUSER` is 403 `AUTH.NOPRIVILEGE` naming `%Admin_Secure:USE`, and by `SECUREUSER` naming `%DB_IRISSYS:READ`; nothing is written. Mutation: drop the `..Gate` call from `UserSave.HandleUpdate`.
- P4 `user-editor.page.spec.ts`: an external `user` change event while the form is clean re-reads the account and the field shows the new `FullName`; the Save test also asserts the event's `action` is `updated`. Mutation: `absorb(result, false)` unconditionally in `refresh`.
- P5 `Test/UserSignIn.cls`: `Operation.ApplyAt` for `UserPassword` with a test port that forwards the password write and fails the flag re-apply `PUT`: the call is an error carrying that port's status and fault, and the password was set. Mutation: `ApplyAt` quits `tSC` whatever `AfterWrite` answers.
- P6 `users-create.browser-spec.mjs`: after the editor's `FullName` wait, the editor's own form bar reads "Saved". Mutation: drop the `arriveSaved` call.
- P7 `user-editor.page.ts`: the Enabled field is drawn refused for `protected-account` only while it is on (turning it on stays possible), as the change-password field is; the page spec pins a disabled `_SYSTEM` read as enable-able. Mutation: lock whatever the flag.
- P8 `Test/UserSave.cls`: the refused legs (`_SYSTEM` disable; new: `CSPSystem` `ChangePassword` on, 403 `PROHIBITED.SERVICEACCOUNTSIGNIN`) run through a fixture port that records and never forwards a write, so a regression cannot change a protected account; the `%All` leg asserts the read succeeded before checking roles. Mutation: remove `..Prohibited` from `UserSave.Update`.
- P9 `Test/AuditEventTools.cls`: `TestAResetsBeforeIsTheListsOwnTotal` asserts the LIST read succeeded and answered one row, rather than skipping.
- P10 `## Verification`: mutation lines for AC1 (`DESCRIPTOR_EDIT_PAGES` entry removed), AC3 (the `Password`/`NewPassword`/`EscalationRoles` legs), and DW-1520's client half (the editor's change-password lock).

**Acceptance Criteria:**

- **Given** a user row, **when** its name is opened, **then** `permissions/users/edit/<id>` shows the tabs General (account settings, comment, expiry, enabled, change-password-on-login, startup namespace and routine, email, mobile, two-factor) and Roles.
- **Given** a two-field change, **when** it is saved, **then** the complete property set is sent and every other field survives (`OcuPilot.Test.UserSave`).
- **Given** the user tools, **when** their schemas are read, **then** `Password` is secret on create and password and is absent from update and from Save. `NewPassword` is never a model argument or a Save key. The stored proposal, the ledger and screen context carry neither (the existing `UserUpdate.cls:1247` pin plus the `UserSave` key refusal).
- Integration: **given** `form-tabs` and `screen-action-dialogs`, **when** `UserEditorPage` renders an error on a tab that is not selected and an Add role dialog, **then** the tab opens with its dot and ", 1 error", and the dialog is the list's own. The browser spec observes both.

## Spec Change Log

- 2026-09-23 spec gate (lead): applied the recommended amendments - AD-10 (service-account sign-in arm, DW-1520), AD-56 (i) (password write re-applies the flag, DW-1516), AD-51 (a list-type fresh read filtered to one row, DW-1576) in the spine; EXPERIENCE.md toast row and Off-screen toast bullet (DW-1546). The new Fixed-strings row and `strings.ts` key for `PROHIBITED.SERVICEACCOUNTSIGNIN` stay with the implement stage. Added the `toast-host.ts` boundary (Epic 15 contended).

## Review Triage Log

### 2026-09-23 — Review pass

- verdicts: 28 findings — high 0, medium 9, low 16, false 3, maybe-false 0
- findings:
  - `[medium]` `patch` The agent's update-mode rules (`UserUpdate.ArgumentProblem`) had no mint test — P1: `UserSave.TestTheAgentsUpdateKeepsTheTwoFactorRules`, run 8902.
  - `[medium]` `patch` The mint's list-type fresh read for the reset tools was untested — P2: `AuditEventTools.TestAMintedResetStartsAtTheListsOwnTotal`, run 8906.
  - `[medium]` `patch` The pair gate on `PUT /users/:id` was unpinned — P3: `WireSecurityRead.TestTheUserSaveRefusesACallerWithoutItsPairs`, run 8908.
  - `[medium]` `patch` The editor's clean re-read on a change event was unobserved — P4: page-spec test for an external change while clean.
  - `[medium]` `patch` A failed flag re-apply after a password write was untested (layer filed defer; a held-PUT port made it cheap) — P5: `UserSignIn.TestAFailedFlagReapplyIsTheWritesFailureAndThePasswordStands`, run 8904.
  - `[low]` `patch` "Saved" on arrival from a create was not pinned to the editor — P6: `users-create` AC4 asserts the editor's own form bar.
  - `[low]` `patch` AC1 had no mutation line — P10: `DESCRIPTOR_EDIT_PAGES` entry removed, seven editor browser tests red.
  - `[low]` `patch` AC3's `Password`/`NewPassword`/`EscalationRoles` legs had no mutation — P10, run 8902.
  - `[low]` `patch` The protected-account refusal on Save had no mutation removing it — P8/P10, run 8902.
  - `[low]` `patch` DW-1520's client half (the editor's change-password lock) had no mutation line — P10.
  - `[low]` `patch` The `%All` absence check passed vacuously on a failed read — P8: the leg first requires the read to show `%Developer`.
  - `[low]` `patch` `TestAResetsBeforeIsTheListsOwnTotal` skipped its comparison on a failed LIST — P9.
  - `[medium]` `patch` The Enabled field was locked for a protected account even while off, so a disabled `_SYSTEM` could not be re-enabled from the editor (AD-10 permits enabling) — P7: locked only while on; page spec pins a disabled `_SYSTEM` as enable-able.
  - `[low]` `patch` A regression of the Save's prohibited check would have disabled `_SYSTEM` on the throwaway, because the recording port forwards writes — P8: refused legs run through `Test.HeldPutPort`, which never sends a `PUT`.
  - `[low]` `patch` The two-field Save's change event was not asserted to carry `action: 'updated'` — P4 asserts it; the sixteen-field check stays on `UserSave.Update`, which `HandleUpdate` calls directly.
  - `[low]` `reject` Undeclared keys are exercised over HTTP for `Roles` alone — the other three run through the same `Update` behind a two-line handler; a wider HTTP loop adds nothing the class-method legs miss.
  - `[low]` `reject` The "other bit moved" case is rules-level only — the Save and the mint call that same `Validate`, pinned by P1 on the agent path.
  - `[low]` `reject` Nothing observes the error summary taking focus before the field — transient focus; pinning it needs a focus spy for no user-visible gain.
  - `[low]` `reject` The signed-in and last-`%All` arms are not exercised through the Save — the Save calls the same `Prohibits` whose arms `Test.Prohibited` and `Test.UserUpdate` pin.
  - `[medium]` `patch` Enabled drawn disabled whatever its state (reading R4a) — grouped with the Enabled-lock finding; P7.
  - `[low]` `patch` Turning `ChangePassword` on for a service account through `PUT` was untested — P8: `CSPSystem` leg, 403 `PROHIBITED.SERVICEACCOUNTSIGNIN`, nothing sent.
  - `[low]` `reject` The list's set-password dialog still re-sends require-password-change after the password — harmless and idempotent now that `AfterWrite` re-applies; removing it changes 7.2's shipped flow.
  - `[medium]` `patch` DW-1576's agent card was not exercised end to end — grouped with the mint-read finding; P2.
  - `[false]` `reject` Add role's choices now come from `GET /users/form` — the spec's Tasks specify exactly that.
  - `[false]` `reject` DW-1546 changes the toast rule for every type, and a Save on the editor raises a Users toast — the rule as amended in EXPERIENCE.md at the spec gate ("Open in <list>", hidden only while that list is open).
  - `[low]` `reject` `UserForm.labelKey` now reads "User" on the create route too, leaving `userFormLabel` unreferenced — spec-bound ("UserForm's label reads as an editor").
  - `[false]` `reject` The 8.2 browser test lost its after-save password-caption leg — the spec's browser task re-points post-create assertions to the editor, which carries no password field.
  - `[medium]` `patch` No test had a mint refuse an update-mode rule — grouped with the first finding; P1.

## Design Notes

**Governing ADs:** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-11, AD-13, AD-14, AD-19, AD-27, AD-35, AD-36, AD-39, AD-51, AD-53, AD-55, AD-56.

**Consumed-by:**

- 9.2: the web-app editor's tabs, summary, `DESCRIPTOR_EDIT_PAGES` and editor actions.
- 9.3: the role editor, the same pieces plus the role dialog.
- 9.5: the SSL/TLS editor's tabs.
- 9.7: `core/form-tabs` field→step errors.
- 9.8: Edit task's tabs.

**Consumes:**

- 7.2's `UserUpdate`/`UserPassword` and AD-53 route.
- 8.2's `/users/form` and create page.
- 8.8's edit-Save order.
- 4.7's `FormDirty` refusal.

**Roles are actions, not Save.** The classic Roles tab assigns at once, and AD-56 (ii) forbids replacing a list with one the client computed. The Roles tab therefore holds no form field. "Save applies everything" covers every field the form holds, and a Roles error cannot occur. Enabled and change-on-login stay General fields (classic), so DW-1501's enable/disable/require-change are the Save through the same tool. Set password, Delete and Add/Remove role are the 7.2 actions.

**DW-1576 measured (read-only, `ocupilot-slot-a`):**

- `AdminPort.Invoke("Security.Audit.Event","LIST",names=%System/%Login/Login)` answers `[{"EventName","Enabled":false,"Total":25184,"Written":0,"Lost":0}]`.
- A lower-cased name matches the same row. An unknown name answers `[]`. Extra `source/type/name` parameters are tolerated.
- GET answers only `{Description, Enabled}`.
- The row therefore stays and is read, rather than dropped.

**Recommended spine and UX amendments (Rule 20/Rule 5, the lead's at the spec gate):**

- **AD-10**, after the "refused by effect" paragraph: "The service-account predicate also covers a write that changes how that account signs in — a new password, or turning on change-password-on-login — refused `PROHIBITED.SERVICEACCOUNTSIGNIN`; `_SYSTEM`, the signed-in account and the last `%All` holder stay permitted for both, and turning the flag off is permitted for every account (DW-1520)."
- **AD-56 (i)**, last sentence, becomes: "The password write re-applies a change-on-login flag its fresh read found set, so the pair ends set whichever proposal is confirmed first (DW-1516)."
- **AD-51**, add: "A tool's fresh read may be a list type filtered by a declared read parameter; the target is the one row whose declared key equals the id, and no row reads as absent (DW-1576)."
- **EXPERIENCE.md `:721` and `:494`**: "When the entity's list is not open, a toast … with 'Open in <list>', which opens that list with the entity selected" (DW-1546).
- New Fixed-strings row for the SERVICEACCOUNTSIGNIN sentence: "The instance's own services sign in as this account. A new password or a required password change would stop them, OcuPilot included."

**Ledger inbox:** DW-1501, DW-1516, DW-1520, DW-1523, DW-1546 and DW-1576 are all addressed (see the Tasks and the Matrix). None is declined.

## Verification

**Commands:**

- `cd ui && node --test tools/form-tabs.test.mjs tools/navigation.test.mjs tools/toasts.test.mjs tools/self-protection.test.mjs tools/screen-mirror.test.mjs tools/field-lists.test.mjs` (loop). Expected: green.
- `cd ui && npm run test:components` (loop). Expected: green, including `user-editor.*.spec.ts` and the role dialog spec.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.UserSave`, then separately `--class OcuPilot.Test.UserSignIn`, `OcuPilot.Test.UserUpdate`, `OcuPilot.Test.AuditEventTools`, `OcuPilot.Test.RefusalCopy`, `OcuPilot.Test.ScreenRegistry` (loop, one run at a time). Expected: 0 failures.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/users-editor.browser-spec.mjs browser/users-actions.browser-spec.mjs browser/users-create.browser-spec.mjs browser/task-resume.browser-spec.mjs` (loop). Expected: green.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh` (loop). Expected: clean.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test` (once, before dev_complete). Expected: 0 failures, excluding only the four arming-variable classes this throwaway refuses.

**Implement-stage note:** `OcuPilot.Test.ScreenRegistry` is a registry fixture, not a test class; the prompt-corpus leg it stood for runs in `OcuPilot.Test.Descriptor` (`TestEveryPromptCorpusCaseGetsItsSentence`).

**Mutations (Rule 19)** -- each applied, compiled or run as named, observed red, reverted; `git status --short` unchanged after each batch. Mutations listed together ran in one run.

- mutation: `UserSave.Update` merges over `{}` instead of the fresh read → `OcuPilot.Test.UserSave` `TestATwoFieldSaveSendsEverySixteenAndTheOthersSurvive` and `TestDisablingTheSystemAccountIsRefusedBeforeThePort` red, run 8887 (matrix: Two-field save; AC2).
- mutation, together: `UserSave.Update` admits `SettableFields` instead of `PermittedFields`; the both-on leg dropped from `UserCreateRules.AutheViolation`; the `user` member dropped from `UserCreateRules.HandleForm` → `UserSave` `TestTheFourUndeclaredKeysAreRefusedAndNothingIsSent`, `TestTheTwoFactorRules` and `TestTheSaveAndTheFormReadAnswerOneEnvelopeOverTheWire` red, run 8888 (matrix: Undeclared key, Two-factor; AC3).
- mutation, together: `If 0 &&` before `ChangesServiceSignIn` in `Prohibited.User`; `UserPassword.AfterWrite` answers at once → `OcuPilot.Test.UserSignIn` `TestAServiceAccountsSignInCannotBeChangedAndOtherAccountsCan`, `TestTheFlagEndsSetInEitherConfirmOrder` and `TestTheScreensSetPasswordKeepsASetFlag` red, run 8889 (matrix: DW-1520, DW-1516).
- mutation: `AuditEventReset.StateDiff` before set to `""` → `AuditEventTools` `TestAResetsBeforeIsTheListsOwnTotal` and `TestTheResetToolsAreActionWritesWithOneStateRow` red, run 8890; `READROWKEY` set to `""` → those two plus `TestTheProhibitedSetPermitsEnabledAloneForBothTypes` red, run 8891 (matrix: DW-1576).
- mutation: `Registry.SUGGESTEDPROMPTSMIN` 3 → 2 → `Descriptor` `TestEveryPromptCorpusCaseGetsItsSentence` red, run 8892; `Prohibited.ReasonFor` answers a shorter literal for `SERVICEACCOUNTSIGNIN` → `RefusalCopy` `TestEachAccountRefusalIsItsParameterAndNamesNoCaller` red, run 8893.
- mutation: `SUGGESTED_PROMPTS_MIN` 3 → 2 in `screen-mirror.mjs` → `screen-mirror.test.mjs` "suggestedPromptsProblem returns every sentence OcuPilot.Test.PromptCorpus declares" red.
- mutation: one word of `SERVICEACCOUNTSIGNINREASON` changed → `self-protection.test.mjs` "AD-53, AD-39: each account refusal is one sentence on both surfaces" red.
- mutation: signed-in exemption dropped from the sign-in branch of `core/self-protection.ts` → `self-protection.test.mjs` "DW-1520: the sign-in rule explains a service account other than the signed-in one, and nothing else" red.
- mutation: singular branch of `tabAccessibleName` dropped → `form-tabs.test.mjs` "a tab with refusals names their count, singular and plural, and one without is its label" red.
- mutation: `screenForEntityType` answers the first built screen of the type → `navigation.test.mjs` "screenForChange resolves the screen a change opens and the route that names the entity" red; UserForm put back in `CREATE_ONLY_FORMS` → "documentScreenFor resolves the REST API explorer ..." red at its user-editor assertion (matrix: DW-1546; AC1).
- mutation: `targetIsOpen` in `core/toasts.ts` drops the descriptor comparison → `toasts.test.mjs` "a change raises its toast on the entity's details screen, and only the entity's own list hides it" red (matrix: DW-1546).
- mutation, together, rebuilt and redeployed to `ocupilot-ci`: the same `targetIsOpen` change; `[privileged]` dropped from `app-screen-action-dialogs` → `task-resume.browser-spec.mjs` "AC4, AC7, Story 7.6 AC3" red and `users-editor.browser-spec.mjs` "the editor's Set password and Add role are the list's own actions, a privileged role stating its consequence" red; the other six editor tests stayed green (matrix: DW-1546, DW-1523).
- mutation: the select's `aria-describedby` dropped in `role-dialog.ts` → `role-dialog.spec.ts` "states the privilege-grant consequence while a privileged role is chosen, and only then" red (DW-1523).
- mutation: the privileged marks dropped in the handler's add-role options → `screen-action-handler.spec.ts` "offers a remove of the row's own roles and an add of the form read's others, sending one role" red; the handler reports to the list store whatever the sink → "opens the list's own dialogs for the editor, and a refusal reaches the editor's sink" red.
- mutation: `UserEditorPage` does not select the tab `tabToOpen` answers → `user-editor.page.spec.ts` "Integration: a refusal on General while Roles is open ..." red (matrix: Error on another tab; Integration AC).
- mutation: `authe &= ~other` dropped in `UserEditor.setTwoFactor` → `user-editor.store.spec.ts` "moves only the two two-factor bits ..." red; a dirty refresh absorbs every field → "sends only what changed, and re-reads only the roles while the form holds unsaved work" red.
- mutation, together: `UserUpdate.ArgumentProblem` answers no problem; `UserSave.Update` admits `Password`, `NewPassword` and `EscalationRoles` beside `PermittedFields`; the `..Prohibited` call removed from `UserSave.Update` → `UserSave` `TestTheAgentsUpdateKeepsTheTwoFactorRules` (both legs), `TestTheFourUndeclaredKeysAreRefusedAndNothingIsSent` (the `Password`, `NewPassword` and `EscalationRoles` legs; `Roles` stayed green) and `TestDisablingTheSystemAccountIsRefusedBeforeThePort` (the `_SYSTEM` and `CSPSystem` legs) red, run 8902; afterwards `_SYSTEM` read enabled and `CSPSystem`'s `ChangePassword` 0 (matrix: Two-factor, Protected account, DW-1520; AC3).
- mutation: `Operation.ApplyAt` answers the write's status whatever `AfterWrite` answers → `UserSignIn` `TestAFailedFlagReapplyIsTheWritesFailureAndThePasswordStands` red, run 8904 (matrix: DW-1516).
- mutation: the mint's fresh read in `Mint.Mint` reverted to `tQuery(pIdParam)` and a direct port `Invoke` → `AuditEventTools` `TestAMintedResetStartsAtTheListsOwnTotal` red ("not present on this instance"), run 8906 (matrix: DW-1576).
- mutation: the `..Gate` call dropped from `UserSave.HandleUpdate` → `WireSecurityRead` `TestTheUserSaveRefusesACallerWithoutItsPairs` red, run 8908. `TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` was red in that run and in the unmutated run 8907 ("nothing is cut at 1,000" on `OcuPilotWireTaskBoth`), which this story does not touch.
- mutation, together: `UserEditor.refresh` absorbs the roles alone whatever the form holds; the Enabled field refused whatever its value in `UserEditorPage` → `user-editor.page.spec.ts` "re-reads the account in place when another caller changes it while the form is clean" and "draws the protected account's Enabled and Delete refused, ..." red.
- mutation: `UserEditorPage.changePasswordRefusal` answers `''` → `user-editor.page.spec.ts` "draws the protected account's Enabled and Delete refused, ..." red on the `CSPSystem` change-password lock (DW-1520, client half).
- mutation, rebuilt and redeployed to `ocupilot-ci`: the `arriveSaved` call dropped from `UserCreateFormPage.onSave` → `users-create.browser-spec.mjs` AC2 and AC4 red at `waitForSaved`'s Saved wait, which comes before AC4's new assertion on the editor's own form bar.
- mutation, rebuilt and redeployed to `ocupilot-ci`: the `UserForm` entry removed from `DESCRIPTOR_EDIT_PAGES` → all seven `users-editor.browser-spec.mjs` tests red (AC1).

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** The user editor ships at `permissions/users/edit/<id>` (General and Roles tabs). Its Save is `PUT /users/:id` (`Area/Permissions/UserSave.cls`) through `UserUpdate`, now admitting the classic General tab's fourteen settings under one update-mode rule set (`UserCreateRules`). Its actions are the Users list's own, through `ScreenActionHandler.startFor` and the shared `app-screen-action-dialogs`; `app-form-tabs`/`core/form-tabs.ts` carry the error dot and count. DW-1520 (`PROHIBITED.SERVICEACCOUNTSIGNIN`), DW-1516 (`Write.AfterWrite`, `UserPassword` re-applies the flag), DW-1576 (`READIDPARAM`/`READROWKEY`, `Operation.ReadTarget`), DW-1523 (role dialog states `privilegedGrantEffect`), DW-1546 (a toast opens the entity's list and hides only there) and DW-1501 are closed. `suggestedPrompts` is a validated descriptor key on both engines; `UserForm` declares three.

**Deviation from the Tasks (not the intent).** The tab strip is Material's tab nav bar over one panel, not `mat-tab-group` with `preserveContent`: the tab group put the initial bundle at 1,388,465 bytes; the nav bar keeps every body in the DOM itself. Bundle now 1,349,991 bytes initial (main 1,216,937 + styles 133,054), under the 1378kB warning.

**Files.** Server: `Area/Permissions/UserSave.cls` (new), `UserCreateRules.cls`, `Api/Router.cls`, `Api/Error.cls`, `Api/ScreenAction.cls`, `Kernel/Proposal/{Prohibited,Operation,Mint,Confirm}.cls`, `Screen/Tool/{UserUpdate,UserPassword,Write,AuditEventReset}.cls`, `Screen/Descriptor/{UserForm,UserList}.cls`, `Screen/Registry.cls`. Tests: new `Test/{UserSave,UserSignIn,PromptCorpus,UserSaveFixture,UserSaveHeldFixture,HeldPutPort}.cls`; updated `AuditEventTools`, `AuditingUpdate`, `DeclarationCorpus`, `Descriptor`, `EndpointCoverage`, `Prohibited`, `RefusalCopy`, `ToolWrite`, `UserUpdate`, `Wire`, `WireSecurityRead`. Client: new `user-editor.{page,store}.ts` (+specs), `core/form-tabs.ts`, `shell/form-tabs.ts`, `shell/screen-action-dialogs.ts`; updated `screen-action-handler.ts`, `list-page.ts`, `role-dialog.ts`, `screen-outlet.ts`, `navigation.ts`, `toasts.ts`, `self-protection.ts`, `strings.ts`, `_components.scss`, `screen-mirror.mjs` (+ generated `screens.generated.ts`). Browser: new `users-editor.browser-spec.mjs`; updated `users-actions`, `users-create`, `task-resume`. EXPERIENCE.md: four Fixed-strings rows appended. `scripts/ci-throwaway.sh`: arming roster comment.

**Review.** 28 findings (0 high, 9 medium, 16 low, 3 false); all patches applied as P1-P10 above (six medium entries, ten low), 8 low rejected with reasons, 3 false; nothing deferred. Follow-up review recommended: true (six medium entries patched): the review-pass patches -- six new test legs, the `Test.HeldPutPort` fixture and the Enabled-field lock change in `user-editor.page.ts` -- were verified by mutation and re-run but not seen by a review layer.

**Verification.** Loop commands green after patching: node tool tests 1349/1349; `npm run test:components` 1041/1041; `check-objectscript` 0 problems (739 files); `lint-docs` clean; build + redeploy to `ocupilot-ci`, then `users-editor`, `users-actions`, `users-create`, `task-resume` 17/17; classes `UserSave` 6/6, `UserSignIn` 4/4, `AuditEventTools` 10/10, `UserUpdate` 23/23, `RefusalCopy` 3/3, `Descriptor` 51/51, `ToolWrite` 29/29. Full sweep once (tree recompiled into `ocupilot-ci`, runs 8910-9120): 216 classes, 1889 tests, 1 failed; four classes refused on their arming variables (`AuditingUpdate`, `ErrorDelete`, `ProcessControl`, `TaskResume`) as this throwaway predates them. The one failure, `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` ("nothing is cut at 1,000"), has failed on this throwaway since run 8192, before this story's first run (8887); its task history holds 1,383 rows (environmental, inference: CI's fresh throwaway holds fewer than 1,000).

**Residual risk.** The failed-re-apply path (DW-1516 error column) is pinned only through a held-PUT fixture port, not a real vendor fault.
