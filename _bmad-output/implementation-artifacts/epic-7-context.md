# Epic 7 Context: Act on any row

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is build step 4. Completing it clears the last floor requirement below the create-and-edit line. A user does the small jobs that make up most daily administration (enable, disable, run, suspend, resume, terminate and delete) from the row menu or the command bar, and the row updates in place. The user can also ask the agent to do any of these through a confirmed proposal. Epic 5 built the write path and one write per area, and Epic 6 built the screens. This epic adds the remaining verbs to screens that already exist, so each action has two callers: the screen and the agent's write tool. Story 7.1 is done and built the shared seam that every later story here reuses.

## Stories

- Story 7.1: Enable, disable and delete a web application (done)
- Story 7.2: User enable, disable, delete, password and roles
- Story 7.3: Delete an OAuth 2.0 client configuration or server client description
- Story 7.4: Turn auditing on and off from the screen
- Story 7.5: Run an on-demand task
- Story 7.6: Run, suspend, resume and delete a task
- Story 7.8: Terminate, suspend and resume a process
- Story 7.10: The remaining application error delete scopes
- Story 7.11: System and user audit event configuration

Stories 7.7 (Task Manager control) and 7.9 (lock removal) moved to Epic 16 as 16.11 and 16.12.

## Requirements & Constraints

- **Two callers, one operation.** A story is not done when the button works. The agent's write tool follows the full model: a server-minted proposal built from a fresh read, a diff computed on the instance, and a confirmation sent as a separate authenticated request that executes the stored arguments. The prohibited set and both switches are evaluated at the write, inside the atomic transition, and the agent's write carries the agent marker. Both callers publish the change event.
- **Self-protection is enforced on the instance, never only in the UI.** The row menu only explains a refusal. The instance refuses the following whatever the caller:
  - removing an account or its administration when the account is the current user, `_SYSTEM`, the account the instance's own services run as, or the last `%All` holder. "Removing" means a delete, a disable, **and** a `Roles` delta that strips `%All`. Each of the four predicates is evaluated for all three effects (DW-1486);
  - deleting or disabling OcuPilot's own web applications or the web service it runs on;
  - control actions on the process serving this request or on any OcuPilot turn job (7.8's clause was narrowed to this so the screen and the agent evaluate the same rule), and terminating an IRIS system process.
- **Privilege grants are refused whatever the caller, at every confirmation level.** Adding `%All` or any `%Admin_*` role is refused on the instance from the screen **and** from the agent. The screen still manages every other role for a privileged user. These grants remain a classic-portal action in Release 1. This amends 7.2, which once let the screen make them.
- **Warnings before a non-delete write** use a primary button, not a destructive one: disabling auditing ("agent writes will no longer be marked") and disabling OcuPilot's own audit events. A proposal for either carries the warning in its card.
- **Secrets are write-only.** The set-password dialog never pre-fills, never echoes a stored value, accepts pasted text without trimming and carries a change-on-login flag. The password is sent once and no read returns it.
- **Application error deletes need all three scopes:** by namespace, by date and by individual error. `DeleteByDate` is either implemented or explicitly refused. The fingerprint is the set of ids enumerated at mint, and confirm deletes exactly those. The namespace comes from the drilled-to level, never from `?ns=`. The gate is per namespace: `%Admin_Operate` plus read and write on the database holding that namespace's `^ERRORS`.
- **Two write families need care with bodies.** `Security.Audit.Event` (7.11) has no body template: derive its field list from the class, pin it with a test, and test its upsert PUT. None of the four `Security.OAuth2.*` endpoints (7.3) merges, so every write sends the complete property set from a fresh read.
- **Task-list quirk (IRIS 2026.2).** After a suspend or resume the list's `Suspended` field is stale while the task's info read is correct. The in-place update and write verification read task info.

## Technical Decisions

- **AD-53 (in the spine) is this epic's seam, and 7.1 built it.** The executed write was lifted out of the confirm transition into one operation. A user-originated `POST /screens/:screen/action` sits beside `GET /screens/:screen/read`. Both callers share target resolution through the tool's declared port, the fresh read, the prohibited set evaluated at the write, the caller's own privilege pairs (checked **before** the fresh read, so a short account gets `AUTH.NOPRIVILEGE` naming the failed pair), the change event and the vendor's audit record.
- **The screen caller differs on purpose.** It mints no proposal, because the confirm dialog is its review. It emits no agent marker. The kill switch and enforced read-only do not gate it, because screens must keep working with the agent disabled.
- **Predicates are stated over the effect, never over the payload's shape or the verb (AD-10 as amended, AD-53).** A bodyless delete has no changed fields and must still hit the arm that protects its target. A predicate gated inside a disable arm, or read off the diff, lets deletes and role deltas through. 7.1 fixed this for the serving-path arm. 7.2 owns the account-predicate restructure (DW-1486, moved over from 7.8). Each arm carries a test that fails when its predicate is removed.
- **Refusal copy is written once.** Each self-protection sentence is a row in EXPERIENCE.md's Fixed strings. It serves as the kernel's envelope `reason` and as the reason the row action is drawn non-selectable, and a test pins the two equal. **A refusal reason that names "the agent" is a defect** once a screen caller can reach that arm. DW-1499 (7.2) covers every `Prohibited.ReasonFor` sentence except SERVINGPATH.
- **AD-56 covers the values a caller may put into a write** (7.2 first, then any row action that carries a value the person supplies):
  - *Secret-only body.* An action-style write may send a body made only of its declared secret arguments. A password change is `Security.User`'s own `CHANGEPWD` request, which takes exactly `{NewPassword}`. The secret is supplied at the write (the confirm for the agent, the dialog for the screen). It is never stored: not in proposal arguments, the diff, the ledger, screen context or a log. The fingerprint covers a declared subject of the fresh read and never includes the secret. The change-on-login flag cannot ride on `CHANGEPWD`, so it is a separate ordinary `update` sent **first**, which means a failure leaves nothing sent.
  - *Declared values only.* The screen-action route refuses (never ignores) any key that the action's tool does not declare. A list-valued field such as roles changes by a **server-side delta over a fresh read** (add this role, remove that one), never by a client-computed replacement list.
  - *One secret declaration.* Secrets travel under the descriptor's existing `secretArguments`. There is no parallel list for screen actions.
- **Action-style writes** (delete, run, suspend, resume, terminate) declare their request type, send no body except AD-56's secret-only case, and declare `CHANGEACTION`, `DESTRUCTIVE` where it applies, and a non-empty fingerprint subject. The subject is drawn from fields the target's read actually answers, read from the instance, with identity and fast-moving counters excluded. `ErrorDelete` and `WebAppDelete` are the precedents.
- **Merge writes** (enable and disable among them) reuse the area's shipped update tool. There is no second code path per field. Field lists are derived, never hand-typed.
- **Descriptors declare row actions with a `selfProtection` rule from a closed vocabulary.** An action is declared only in the same pass that registers its handler. Every surface (command bar, command box, row menu) hides an action that has no registered handler. Tool names follow `<area>.<screen>.<verb>`, and the verb matches the row action.
- **Identity** is `(entity type, scope, id)` in each type's canonical form, applied at mint, at confirm, at the row action and at the change event. Each type that gains a write here adds its own canonicalization rule if it needs one.
- **One change event per write** from the closed entity-type enum. Screens re-fetch in place and keep sort, filter, selection and scroll; they never patch rows from a write response.
- **Disabling auditing cannot be marked.** The ledger row reads "done · audit not marked" and the banner shows. The re-enable is marked.
- **Known limits carried from 7.1.** A screen action takes no per-target lock, so it and a confirm against the same target are ordered only by the vendor endpoint. The client mirrors only the install roster's protected paths, while the instance also protects the paths the install recorded.

## UX & Interaction Patterns

- **Row menu.** Actions appear in command-bar order, with destructive ones last. Refused and privilege-gated actions stay listed as non-selectable rows that the arrow keys still reach, with the reason inline, and they are never Material-disabled. Every row-menu item is also on the command bar.
- **Typed-name dialog (shipped by 7.1, in the shell).** The title names the action and the target, and the body states the consequence. "Type <name> to confirm" requires an exact, case-sensitive match and allows pasting. On blur, a mismatch shows "Does not match" and sets `aria-invalid`. The `button-destructive` button is labeled with the verb and target and stays `aria-disabled` until the name matches. Focus starts in the field. After a confirmed delete, focus goes to the grid. Terminate adds the optional error-to-job flag and names the pid.
- **Users list (7.2).** Row actions are "Set password", "Add role" and "Remove role". The set-password dialog carries "Require a password change at next sign-in". The role dialog is a permitted dialog whose field label is "Role". Delete user carries its own consequence body. The four account refusals (signed-in account, `_SYSTEM`, service account, last `%All` holder) each have one caller-neutral published sentence. The empty-list agent invitation reads "create a user", shared with Epic 8's Story 8.2.
- **Destructive proposal card.** It carries the same typed-name field. The removal-residue sentence appears only for `application-error`.
- **Banner.** "Agent writes are not being marked" appears the moment auditing goes off, clears the moment it returns, and links to Auditing configuration.
- **Auditing configuration** (7.4 and 7.11) is a form. The system-event and user-event lists sit beneath it, and the screen cross-links to the Audit database viewer.
- **Strings.** Every new user-facing string is added to EXPERIENCE.md's Fixed strings with its `strings.ts` key in the same pass. `strings.ts` holds nothing the table does not publish.

## Cross-Story Dependencies

- **Upstream, Epic 5:** 7.2 extends 5.9, 7.4 and 7.11 extend 5.10's auditing toggle, 7.6 extends 5.11's task resume, 7.8 extends 5.12's process suspend and resume, and 7.10 extends 5.13's delete by namespace. **Epic 6** provides the screens.
- **From 7.1:** later stories reuse the screen-action route, the kernel operation, the generic shell row-action handler, the typed-name dialog and the `selfProtection` vocabulary. They do not build their own.
- **Within this epic:** 7.6 owns the UJ-6 replay end to end: the agent navigates to Task details, the Status field highlights, and a toast offers "Open in Task schedule". 7.4 and 7.11 are the two halves of the Auditing screen.
- **Routed ledger items:**
  - 7.2 has DW-1486 (floor-blocking; one restructure together with 7.2's delete hole, and it returns to 7.8 only if 7.2 leaves a residual) and DW-1499.
  - 7.6 has DW-1463.
  - 7.8 has DW-1155 and DW-1189.
  - Still open under 7.1: DW-1001 and DW-1013 (for the first story that amends a derived read's criteria), DW-1136 and DW-1137 (inside `AdminPort`, which is shared-append), DW-1099 (descriptor read, filter and sort assertions) and DW-389 (Switches declares row actions that have no handler).
- **Epic 8 runs concurrently.** It owns `ui/src/app/areas/web-applications/**`. `AdminPort.cls` and `strings.ts` are shared-append. The Users list is contended: 7.2's row actions and 8.2's create both make it write-capable, and both declare the "create a user" invitation. 8.2 widens `secretArguments` to accept a top-level secret field of a screen's tools, which is the same declaration AD-56 reads. At merge, reconcile Epic 8's web-application verb test (which asserts no delete exists) with 7.1's three-verb roster.
- **Downstream:** Epics 9 and 12 become eligible once Epics 7 and 8 have both merged. Epic 8's create forms and Epic 9's editors reuse the screen-write seam for Save. Epic 12's OAuth editors build on 7.3's deletes.
