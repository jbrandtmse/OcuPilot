---
title: 'Story 9.1: The user editor'
type: 'feature'
created: '2026-09-23'
status: 'done'
baseline_revision: '62da5afea4cf00b21ae3348099c0112640c0a2b4'
baseline_commit: '62da5afea4cf00b21ae3348099c0112640c0a2b4'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The toast stack's published placement (DESIGN.md toast recipe, `toast-host.ts` header) says `spacing.4` above the status bar and component-scoped rules, while on a form page `_components.scss` now lifts it above the form bar.
    evidence: |-
      `ui/src/styles/_components.scss` `.ocu-shell:has(.ocu-form-bar) > app-toast-host` sets `bottom` to form-bar height plus spacing.4; DESIGN.md:1210 and `toast-host.ts`:48-52 were not amended (the one is the lead's, the other out of bounds).
    location: >-
      _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md:1210; ui/src/app/shell/toast-host.ts:48
    severity: low
  - summary: >-
      A form page taller than the content area does not keep its sticky form bar on screen: Save and Cancel sit below the fold until the content is scrolled (measured on the user editor at 1440x900).
    evidence: |-
      `.ocu-form-page` has `overflow-y: auto` and `flex: 1 1 auto` (Story 3.5), but no form-page host (`app-user-editor-page`, `app-device-form-page`, ...) is in the flex host list at `_components.scss:735`, so the section grows to its content (1069px) and `main.ocu-content` scrolls instead; the bar measured top 1184 against a shell bottom of 876. Pre-existing; the 14-field editor is the first form tall enough to show it.
    location: >-
      ui/src/styles/_components.scss:2847
    severity: medium
  - summary: >-
      The toast's dismiss glyph draws at the toast's 14px body size, while DESIGN.md's toast recipe calls for a 20px close icon.
    evidence: |-
      `.ocu-toast-dismiss` sets `font: inherit` under `.ocu-toast`'s `font-size: 0.875rem`; the glyph measured 7.9px wide with the box's minimums removed. Pre-existing since the toast host shipped; this pass enlarged the target box only.
    location: >-
      ui/src/app/shell/toast-host.ts:66; _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md:1210
    severity: low
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

**Rework iteration 1 (CI red on build commit `19849911`, run 35945402895, job `browser`, 2 of the full suite):**

- [x] [CI] browser: `ui/browser/users.browser-spec.mjs:225` "AC7: the _SYSTEM name link carries the id in one route segment" timed out waiting for `/permissions/users/_SYSTEM` -- this story moved the Users name cell to the editor (`UserForm` left `CREATE_ONLY_FORMS`), so the pin names the old target. Re-point it to `permissions/users/edit/_SYSTEM` (the editor, id in one segment, `data-id="_SYSTEM"` or the editor's own equivalent), keeping its AD-13 intent; confirm the editor opens over `_SYSTEM` -- https://github.com/jbrandtmse/OcuPilot/actions/runs/35945402895
- [x] [CI] browser: `ui/browser/device-editor.browser-spec.mjs:206` "AC2: a create and an edit reach the Devices list without a refresh, and its name cell opens the editor" timed out (30 s wait) -- a Story 8.8 test this story's shared changes broke (candidates: `screen-outlet.ts` `DESCRIPTOR_EDIT_PAGES`, `navigation.ts` `screenForEntityType`/`CREATE_ONLY_FORMS`, the toast rule, `list-page.ts`'s dialog move). Reproduce it against the rebuilt, redeployed bundle on `ocupilot-ci`, find which wait fails and why, and fix the product code (not the pin) unless the pin names behavior this story's spec deliberately changed. Also run every other browser spec file that exercises a form-page editor or a list name-cell link (`device-editor`, `users`, `users-create`, `users-actions`, `users-editor`, `task-resume`, and any `*-create`/`*-editor` spec touching `screen-outlet` or `navigation.ts`) one file at a time -- https://github.com/jbrandtmse/OcuPilot/actions/runs/35945402895

**Rework iteration 2 (CI red on the integrate-forward head `d317549f`, run 35983775764, job `browser`):**

- [x] [CI] browser: `ui/browser/definitions.browser-spec.mjs:631` (Story 10.5, merged from Epic 10) asserts its failure line passes every DW-1337 invariant and found `app-toast-host>button.ocu-toast-dismiss: width 15.9px under 24px (floor)` on `agent/definitions/edit` at 1280 and 720. This story's toast rule (DW-1546) now raises a change toast on an editor whose list is not open, which exposes the dismiss button's size: EXPERIENCE.md "Target sizes" sets every control at least 24 x 24 CSS px. Make the toast's dismiss button meet the 24 x 24 floor (tokens only; `ui/src/app/shell/toast-host.ts` styles, uncontended since Epic 15 merged), keep its 20px glyph, and pin it with a check a mutation can redden (e.g. in `toast.browser-spec.mjs`, or a structural-walk leg over a raised toast). Do not change `definitions.browser-spec.mjs` (Epic 10's, merged). Run `definitions`, `toast`, `users-editor` and `a11y-structural-invariants` browser spec files, one at a time, after rebuild and redeploy -- https://github.com/jbrandtmse/OcuPilot/actions/runs/35983775764

**Acceptance Criteria:**

- **Given** a user row, **when** its name is opened, **then** `permissions/users/edit/<id>` shows the tabs General (account settings, comment, expiry, enabled, change-password-on-login, startup namespace and routine, email, mobile, two-factor) and Roles.
- **Given** a two-field change, **when** it is saved, **then** the complete property set is sent and every other field survives (`OcuPilot.Test.UserSave`).
- **Given** the user tools, **when** their schemas are read, **then** `Password` is secret on create and password and is absent from update and from Save. `NewPassword` is never a model argument or a Save key. The stored proposal, the ledger and screen context carry neither (the existing `UserUpdate.cls:1247` pin plus the `UserSave` key refusal).
- Integration: **given** `form-tabs` and `screen-action-dialogs`, **when** `UserEditorPage` renders an error on a tab that is not selected and an Add role dialog, **then** the tab opens with its dot and ", 1 error", and the dialog is the list's own. The browser spec observes both.

### Review Findings

Code review 2026-09-23 (four layers, full-opus; 40 raw rows, 17 surviving entries: 2 high, 5 medium, 10 low). Every patch was applied and verified by mutation on `ocupilot-ci`.

- [x] [Review][Patch] HIGH: a past `ExpirationDate` on `_SYSTEM`, the signed-in account, a service account or the last `%All` holder passed AD-10 (the vendor refuses the sign-in and sets `Enabled` 0, measured on `ocupilot-ci`). `Disables` now counts it as a disable [src/OcuPilot/Kernel/Proposal/Prohibited.cls:1724]
- [x] [Review][Patch] HIGH: when a password write landed and its flag re-apply then failed, the confirm emitted no AD-15 marker and its comment said the write had not happened. `ApplyAt` now answers `pApplied`, and the confirm marks that write [src/OcuPilot/Kernel/Proposal/Confirm.cls:399]
- [x] [Review][Patch] The Enabled and change-on-login locks read the edited value, so a tick on a disabled `_SYSTEM`, or an untick on a flagged service account, could not be undone. Both locks now read the stored value (`storedFlag`) [ui/src/app/areas/permissions/user-editor.page.ts:618]
- [x] [Review][Patch] The update-mode field rules (lengths, flag shape, expiry, routine without a namespace, an object value) had no test [src/OcuPilot/Test/UserSave.cls]
- [x] [Review][Patch] Nothing tested the editor following one editor route to the next, so a Save could reach the previous account [ui/src/app/areas/permissions/user-editor.page.spec.ts]
- [x] [Review][Patch] Edits typed while a Save was in flight were marked saved and then dropped [ui/src/app/areas/permissions/user-editor.store.ts:444]
- [x] [Review][Patch] A 20-digit `AutheEnabled` threw `<FUNCTION>` and answered 500. It is now held to 15 digits, which is `USER.AUTHEENABLED.SCOPE` [src/OcuPilot/Area/Permissions/UserCreateRules.cls:210]
- [x] [Review][Patch] The "SMS on alone" leg never ran its rule, because it equalled the probe's stored mask [src/OcuPilot/Test/UserSave.cls]
- [x] [Review][Patch] Nothing tested the Roles tab's Remove, or the display-QR option appearing while TOTP is on [ui/src/app/areas/permissions/user-editor.page.spec.ts]
- [x] [Review][Patch] `Mint.ReadTypeOf` and `Prohibited.ReadTypeOf` were dead after `ReadTarget`, and `TaskResume`'s mutation note named one of them. The note now names `Operation.ReadType`. It was not re-observed: this throwaway refuses `TaskResume` on its arming variable [src/OcuPilot/Test/TaskResume.cls:113]
- [x] [Review][Patch] Three comments were wrong: the `Router` note about the `PUT` sub-resources, `ReadTarget`'s "every caller", and the `strings.test.mjs` label count [src/OcuPilot/Api/Router.cls:323]
- [x] [Review][Defer] DW-1592: the editor shows the name as the route spells it (low) — wontfix-accepted, with a `reopen_if` in the ledger
- [x] [Review][Defer] DW-1593: the sign-in arm does not exempt a service account that is the last `%All` holder, which AD-10's sentence lists — wontfix-theoretical. The code follows the matrix row, and the AD-10 wording is the lead's to settle
- [x] [Review][Defer] DW-1594: two-factor on, or `PasswordNeverExpires` off, for a service account passes — wontfix-theoretical (unmeasured)

Rejected:

- false: the Save's agent test is only refusals — `UserSignIn` confirms a `permissions.users.update` proposal that succeeds.
- false: `enabledRefusal` borrows the wrong rule — no disable action exists, and `protected-account` is the right rule.
- false: suggested prompts show on the create route — nothing renders the descriptor key yet (Story 11.3).
- low: refused fields use `disabled`, not `aria-disabled` — the caption stays readable, and the fix needs click guards.
- low: `AfterWrite`'s re-read is a separate `GET`/`PUT` pair — the race window is the same as every AD-4 merge write.
- low (by-design): the classic page's gating of two-factor, its provider picker and HOTP regenerate are outside the spec's 14 fields and its Never list.
- low (by-design): tab and title keys are reused, as the spec directs.
- low: a delete from another session is ignored until Save answers 404.
- low: the editor re-reads twice after an action.
- low: a no-op `PUT` would write, but the client never sends one.
- low: a stale refresh or a late sink could land after a Save or teardown — needs a sub-second race.
- low: a non-404 form-read fault or a merge problem answers 500 — unreachable once the gate and rules pass.
- low: a `1`/`true` flag mismatch on the agent path — it errs toward refusing.
- low: `UserSave` bypasses `ApplyAt`/`ReadTarget` — `UserUpdate` declares no hook or row key.
- low: the `AuditChange` Total could move between two reads — nothing in the run audits a config change.
- low: `USER.NAME.ABSENT` is not in the violation roster — it is only ever an envelope code.
- low: tab selection is a component signal — it is view state, not screen state (AD-19).
- low: the EXPERIENCE.md row names one surface of the sign-in sentence — shared-append file.
- low: the tests hard-code ", 1 error" — they pin the published literal.
- rejected (edits the spec): the spec's counts, and its `status` against sprint-status.

### Review Findings (rework 1)

Code review 2026-09-24 of `e162c9c9..HEAD` (four layers, full-opus; 18 raw rows, 4 surviving entries: 0 high, 1 medium, 3 low). Both `[CI]` items confirmed fixed: AC7 waits for `permissions/users/edit/_SYSTEM`, the outlet's `data-id` and the editor's Name field; the device-editor diagnosis holds (`app-toast-host` is a direct child of `.ocu-shell`, `--ocu-form-bar-height` is the bar's 56px, the rule's (0,2,1) beats the host's `:host` (0,1,0), and all nine form pages draw `.ocu-form-bar`).

- [x] [Review][Patch] The geometry test accepted a stack lifted too far; it is now two-sided within 1px, like `toast.browser-spec.mjs`'s placement pin [ui/browser/users-editor.browser-spec.mjs:404]
- [x] [Review][Patch] The lift's comment said Save and Cancel sit at the content area's right and that no form control is ever covered; it now names the form column, Save and Cancel, and the flush-bar condition [ui/src/styles/_components.scss:5514]
- [x] [Review][Patch] DW-1595 cited `toast-host.ts:48` for the placement prose, which is at `:13-22`; corrected by a ledger trailer [_bmad-output/implementation-artifacts/deferred-work.md]
- [x] [Review][Defer] The lift assumes the bar sits flush at the content area's bottom; a form whose bar ends mid-way can still sit under the stack, as it did before the lift [ui/src/styles/_components.scss:5518] — deferred: pre-existing, same root cause as DW-1596 (`occurrence` appended, routed to 9.2)

Rejected:

- false: the test measures an empty host and never hit-tests Save or Cancel — `device-editor` AC2 clicks Cancel under a real toast, and the host's bottom is where the stack's bottom sits.
- false: `switches.page.ts` draws `.ocu-form-bar` without being a form page — it is `<section class="ocu-form-page">`.
- false: the lift treats a symptom of DW-1597 — agent writes raise toasts on form pages whatever DW-1597 decides.
- false: the rework skipped the other name-cell specs — CI's `browser` job runs every spec file (Rule 29).
- low: a three-toast stack on a short viewport reaches the command bar — the stack was already 216px tall before the lift; needs a viewport under about 400px.
- low: `web-applications-create`'s header does not pin the create's toast — the toast after a form's own create is DW-1597's open question.
- low: DW-1595's two reasons for leaving DESIGN.md and `toast-host.ts` unamended differ — no reader is sent the wrong way.
- rejected (edits the spec): DW-1597 read as rejected in the 2026-09-24 triage row and residual risk while the ledger holds it `decision-pending`; DW-1596's `deferred:` location; the Auto Run Result's dropped earlier-pass paragraphs.

## Spec Change Log

- 2026-09-24 rework iteration 2 (lead): CI red after the integrate-forward that brought Epic 10's 10.5; one `[CI]` item (toast dismiss button under the 24px target floor, exposed by DW-1546's toast rule).

- 2026-09-24 (lead, post re-review): an editor's own Save raising a change toast is open as DW-1597 (decision-pending, for the user at the decision sheet); the rework triage row that reads it as rejected is superseded by that entry.

- 2026-09-24 rework iteration 1 (lead): CI red on `19849911` (run 35945402895, browser job, two specs outside this story's own list). Re-opened with two `[CI]` items; code review round 1 closed `done` with 0 unresolved high/med (its patches are in the rework commit).

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

### 2026-09-24 — Review pass

- verdicts: 10 findings — high 0, medium 2, low 5, false 3, maybe-false 0
- findings:
  - `[medium]` `patch` The toast lift above the form bar is pinned only through `device-editor` AC2's Cancel click, so a partial lift passes — added `users-editor` "the change-toast stack stands clear above the form bar holding Save and Cancel", measuring the host's bottom against the bar's top with the bar scrolled into view; mutation line in `## Verification`.
  - `[low]` `reject` The `## Verification` loop command does not list `users`/`device-editor`, and the related runs are not recorded — the fix edits the spec's Verification section; this pass's per-file runs are recorded in the Auto Run Result.
  - `[low]` `patch` `web-applications-create.browser-spec.mjs`'s header says the create's route replacement raises no toast, which DW-1546's rule made untrue — the sentence is removed.
  - `[low]` `defer` `toast-host.ts`'s header says the host's rules are component-scoped, while its bottom offset is now also set in `_components.scss` — `toast-host.ts` is out of bounds (Epic 15 contended); grouped with the DESIGN.md placement row, in `deferred`.
  - `[false]` `reject` An editor's own Save raises a toast, against DESIGN.md's "never for confirmations of what the user just did on the open screen" — carried: the 2026-09-23 row on DW-1546 (the rule as amended in EXPERIENCE.md at the spec gate); `toasts.ts` is unchanged by this pass.
  - `[false]` `reject` The `_components.scss` lift is the banned `toast-host.ts` edit made from another file — the lead's boundary names `_components.scss` shared-append and bans only `toast-host.ts`; the rule is appended and `toast-host.ts` is untouched.
  - `[low]` `defer` DESIGN.md `:1210` and `toast-host.ts` publish the stack's bottom as `spacing.4` above the status bar, while on a form page it is now the bar's height plus `spacing.4` — the fix amends DESIGN.md (the lead's) and `toast-host.ts` (out of bounds); in `deferred`.
  - `[medium]` `patch` The lift has no direct geometry test — grouped with the first row.
  - `[low]` `reject` The rework item's other browser runs are not recorded, and the Auto Run Result describes the first pass — same as the second row; rewritten at this finalize.
  - `[false]` `reject` The diff does not say whether a toast on form pages is intended — carried: the same 2026-09-23 DW-1546 row.

### 2026-09-24 — Review pass (rework 2)

- verdicts: 10 findings — high 0, medium 0, low 4, false 6, maybe-false 0
- findings:
  - `[low]` `patch` The height half of the new dismiss-size assertion had no mutation — applied `min-height` dropped, rebuilt and redeployed: DW-1405 red at 24 x 14; mutation line and test comment now name both minimums.
  - `[false]` `reject` The four required browser runs are unrecorded — the handoff ran all four after the final redeploy and `definitions` was re-run at verify; recorded in the Auto Run Result.
  - `[low]` `reject` The item's "keep its 20px glyph" has no basis (the glyph is 14px) — the claim is in the spec item's text; the fix edits the spec. The glyph is unchanged.
  - `[false]` `reject` The diff edits `toast-host.ts` against the contract's Never — the lead's re-open item and dispatch authorize it (Epic 15 merged, the file is uncontended); `definitions.browser-spec.mjs` is untouched.
  - `[false]` `reject` The new test does not exercise the definitions surface that failed — the unchanged `definitions.browser-spec.mjs` does, 8/8 on the rebuilt bundle; the rule is viewport- and screen-independent.
  - `[false]` `reject` The required runs are not recorded (intent layer) — carried: the second row.
  - `[low]` `patch` The mutation covers width only (intent layer) — grouped with the first row; same fix.
  - `[false]` `reject` The assertion admits 23.5px — the structural walk's own `min-width` check uses the same `+ 0.5` (`structural-walk.mjs:284`).
  - `[false]` `reject` "The structural walk's floor measures width alone" is unverified — `structural-walk.mjs:283-284` reads `getBoundingClientRect().width` only.
  - `[low]` `defer` DESIGN.md's 20px close icon is unmet — pre-existing (the glyph inherits the toast's 14px body size); in `deferred`.

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
- mutation (code review): the expiration term dropped from `Prohibited.Disables`, the length loop disabled in `UserCreateRules.UpdateViolations`, and `AutheViolation`'s digit bound removed → `UserSave` `TestDisablingTheSystemAccountIsRefusedBeforeThePort` (the past-date leg), `TestTheEditsFieldRulesRefuseEachFieldWithItsCode` and `TestTheTwoFactorRules` (`<FUNCTION>`) red, run 9131; green again after the restore.
- mutation (code review): the confirm's error arm emits no marker whatever `ApplyAt` applied → `UserSignIn` `TestAConfirmedPasswordWhoseReapplyFailsIsStillMarked` red, run 9132.
- mutation (code review), together: the Enabled lock keyed off the edited value; the display-QR field's `@if` false; the `NavigationEnd` follow disabled; the store taking the buffer as stored when a Save lands → `user-editor.page.spec.ts` "draws the protected account's Enabled …" (the tick-stays-undoable leg), "offers the display-QR option …", "follows the route to another account …", and `user-editor.store.spec.ts` "keeps what was typed while a Save was in flight …" red.
- mutation (code review), together: the change-on-login lock keyed off the edited value; `onRemoveRole` sends no role → the service-account leg of "draws the protected account's Enabled …" and "removes a held role from the Roles tab …" red.
- mutation (rework 1), together, rebuilt and redeployed to `ocupilot-ci`: the `UserForm` entry removed from `DESCRIPTOR_EDIT_PAGES`; the `.ocu-shell:has(.ocu-form-bar) > app-toast-host` lift removed from `_components.scss` → `users.browser-spec.mjs` "AC7: the _SYSTEM name link carries the id in one route segment" red at the editor's `_SYSTEM` name wait, and `device-editor.browser-spec.mjs` "AC2: a create and an edit reach the Devices list …" red at the list-path wait after Cancel (the create's toast covers Cancel); both green after the revert.
- mutation (rework 1 review), rebuilt and redeployed to `ocupilot-ci`: `+ var(--ocu-space-4)` dropped from the `_components.scss` toast lift → `users-editor.browser-spec.mjs` "the change-toast stack stands clear above the form bar holding Save and Cancel" red (host bottom 820 against bar top 819.875); green after the revert, bundle hashes identical to the verified build.
- mutation (rework 1 code review), rebuilt and redeployed to `ocupilot-ci`: the lift doubled to `+ 2 * var(--ocu-space-4)` → the same test, now two-sided, red (host bottom 788 against bar top 819.875); `users-editor` 8/8 after the revert, tree byte-identical.
- mutation (rework 2), rebuilt and redeployed to `ocupilot-ci`: `min-width: var(--ocu-space-6)` dropped from `.ocu-toast-dismiss` in `toast-host.ts` → `toast.browser-spec.mjs` "DW-1405: the toast stack renders at the recipe geometry …" red (dismiss control 7.9 x 24); `min-height: var(--ocu-space-6)` dropped instead → the same test red (24 x 14); `toast` 3/3 after each revert, `git diff --stat` unchanged.

## Auto Run Result

Status: done
Blocking condition: none

**Summary (rework iteration 2).** The one `[CI]` item is closed. The toast's dismiss button measured 15.9px wide, under EXPERIENCE.md's 24 x 24 target floor, which `definitions.browser-spec.mjs`'s DW-1337 walk caught once DW-1546's rule raised a toast on an editor. `.ocu-toast-dismiss` in `toast-host.ts` is now an inline-flex box of at least `--ocu-space-6` (24px) in both dimensions with the glyph centred; the glyph itself is unchanged (it is 14px, not 20px as the item said; deferred low).

**Files.** `ui/src/app/shell/toast-host.ts` (dismiss box minimums, header sentence); `ui/browser/toast.browser-spec.mjs` (DW-1405 test asserts the dismiss control is at least 24 x 24, floor read from `structural-walk.mjs`); this spec (item ticked, mutation line).

**Review.** Follow-up pass, two layers: 10 findings (0 high, 0 medium, 4 low, 6 false). Patched: 1 low entry (the height half's mutation). Deferred: 1 low (DESIGN.md's 20px close icon, pre-existing). Rejected: 1 low (spec-text claim), 6 false (see the rework-2 triage row). Follow-up review recommended: false (no high patched on a follow-up pass; patched counts high 0, medium 0, low 1).

**Verification.** After the final `npm run build` and redeploy to `ocupilot-ci`, one file per run: toast 3/3, definitions 8/8 (re-run at verify; includes the Story 10.5 test that failed in CI), users-editor 8/8, a11y-structural-invariants 10/10. `npm run test:tools` 1384/1384, `npm run test:components` 1097/1097, `lint-docs` clean, build (client-lint) clean. Mutations: `min-width` dropped → 7.9 x 24 red; `min-height` dropped → 24 x 14 red (DW-1412 also red in that run); both reverted, tree byte-identical, bundle hash `main-7GZCA6O2.js` identical to the verified build. Initial bundle 1,430,355 bytes (main 1,292,498 + styles 137,857). Earlier passes: first build `19849911`, review patches `ba6f2258`, rework 1 `41e795e9`.

**Residual risk.** The toast is about 4px taller (48px); the `toast` and `users-editor` geometry pins pass.
