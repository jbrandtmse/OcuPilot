# Epic 7 Context: Act on any row

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is build step 4. Completing it clears the last floor requirement below the create-and-edit line. A user does the small jobs that make up most daily administration (enable, disable, run, suspend, resume, terminate and delete) from the row menu or the command bar, and the row updates in place. The user can also ask the agent to do any of these through a confirmed proposal. Epic 5 built the write path and one write per area, and Epic 6 built the screens. This epic adds the remaining verbs to screens that already exist, so each action has two callers: the screen and the agent's write tool.

## Stories

- Story 7.1: Enable, disable and delete a web application
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

- **Two callers, one operation.** A story is not done when the button works. The agent's write tool follows the full model: a server-minted proposal built from a fresh read, a diff computed on the instance, and a confirmation sent as a separate authenticated browser request. The confirmation executes the stored arguments. The prohibited set and both switches are evaluated at the write, inside the atomic transition, and the write carries the agent marker. Both callers publish the change event.
- **Self-protection is enforced on the instance, never only in the UI.** The row menu only explains a refusal. The instance refuses the following whatever the caller:
  - disabling or deleting the current user, the last `%All` holder or `_SYSTEM`;
  - deleting or disabling OcuPilot's own web applications or the web service it runs on;
  - terminating an IRIS system process.
- **Privilege grants are prohibited through the agent at every confirmation level.** This covers adding `%All` or any `%Admin_*` role, setting application roles, and adding a role to a resource. The screen's own role management stays available to a privileged user (7.2).
- **Process control uses one narrow predicate.** It refuses the process serving this request and any OcuPilot turn job. It does not refuse "the user's own process": 7.8's clause was amended so the screen and the agent evaluate the same rule.
- **Three warnings come before a non-delete write:**
  - disabling auditing: "agent writes will no longer be marked";
  - disabling OcuPilot's own web service;
  - suspending the Task Manager, which is now Epic 16's.

  Each warning uses a primary button, not a destructive one. A proposal to disable auditing or OcuPilot's own audit events carries the warning in its card.
- **Secrets are write-only.** The set-password dialog never pre-fills and never echoes a stored value, and it accepts pasted text without trimming. The password is sent once, and no read returns it. It carries a change-on-login flag.
- **Application error deletes need all three scopes:** by namespace, by date and by individual error. `DeleteByDate` is either implemented or explicitly refused. The fingerprint is the set of ids enumerated when the proposal is minted, never a count or a new query at confirm. Errors logged in between are left behind, and the card says so. The namespace comes from the level the user has drilled to, never from `?ns=`. The gate is resolved per namespace: `%Admin_Operate` plus read and write on the database that holds that namespace's `^ERRORS`.
- **Two write families need care with bodies.**
  - `Security.Audit.Event` (7.11) publishes no body template. Its field list is derived from the underlying class and pinned by a test. Its PUT is an upsert, and that path needs its own test.
  - None of the four `Security.OAuth2.*` endpoints (7.3) merges. Every write sends the complete property set from a fresh read.
- **Task-list quirk (IRIS 2026.2).** After a suspend or resume, the list's `Suspended` field is stale, while the task's `INFO` read is correct. The in-place update and write verification must read `INFO`.

## Technical Decisions

- **The screen caller and the agent caller share one operation.** The operation sits outside the confirm path. The screen reaches it through a user-originated route placed beside `GET /screens/:screen/read`. Both callers share:
  - target resolution through the tool's declared port (AdminPort by default; LogSourcePort for application errors);
  - the fresh read;
  - the prohibited-set predicates, evaluated against the resolved target inside the single atomic transition;
  - the caller's own privileges through that port's gate;
  - the change event and the vendor's own audit record.
- **The screen caller differs on purpose in three ways.** It mints no proposal: its review is the confirm dialog. It emits no OcuPilot agent marker. It is not gated by enforced read-only or the kill switch, because those switches govern the agent and "all screens continue to work with the agent disabled".
- **Refusal copy is written once.** Each self-protection sentence is published once in EXPERIENCE.md's Fixed strings. It serves both as the kernel's envelope `reason` and as the reason the row action is drawn disabled, and a test pins the two equal. A refusal reason must not mention "the agent", because the screen shares the predicate.
- **Predicates are stated over the effect, never over the payload's shape.** A bodyless delete has no changed fields and must still hit the arm that protects the serving path. Story 7.1 found exactly this gap. DW-1486 is the same kind of defect.
- **Action-style writes** (run, suspend, resume, terminate, and the error deletes) declare their request type, send no body and admit nothing on the confirm channel. Their fingerprint subject is declared by the tool: every field the action's precondition reads, for example `State` for suspend and resume. It excludes identity and fast-moving counters. The build refuses an empty or inadequate subject. The diff is computed over what the read can see.
- **Merge writes** read fresh, apply the diff and send the complete body. Field lists are derived at build time, never hand-typed. Every derived field is classified `ordinary`, `secret` or `opaque`, and an unclassified field is emitted as secret.
- **Identity** is the triple `(entity type, scope, id)`, with the canonical spelling set per entity type in the identity layer. Each type that gains a write here adds its own canonicalization rule. A type with no rule canonicalizes to itself.
- **One change event per write**, from the kernel's closed entity-type enum. Screens re-fetch in place, keep sort, filter, selection and scroll, and highlight the change; they never patch rows from a write response. Proposal open and close events pause auto-refresh.
- **Disabling auditing cannot be marked.** The audit channel is closed by the time the marker would fire, so the ledger row reads "done · audit not marked" and the banner shows. The re-enable is marked.
- **Descriptors carry row actions and their self-protection rules**, and tool names follow `<area>.<screen>.<verb>`, where the verb matches the row action. A descriptor that declares a row action must also register its handler; no inert control ships.

## UX & Interaction Patterns

- **Row menu.** Actions appear in command-bar order, with destructive actions last. Refused and privilege-gated actions stay listed and reachable with the arrow keys as non-selectable rows, with the reason inline after the label. They are never Material-disabled. Every row-menu item is also on the command bar.
- **Destructive dialog.** It is one level deep, the title names the action and the target, and the body states the consequence. The typed-name field "Type <name> to confirm" requires an exact, case-sensitive match, and pasting is allowed. A mismatch on blur shows "Does not match" and sets `aria-invalid`. Enter submits only once the name matches. The `button-destructive` button is labeled with the verb and target, and it stays `aria-disabled` until the name matches. Initial focus goes to the typed-name field. Escape or Cancel closes the dialog and returns focus to the opener. Terminate adds the optional error-to-job flag and names the pid.
- **Destructive proposal card.** It carries the same typed-name field and a destructive Confirm. After the write, a focused status line replaces the buttons, and the screen highlights the change within 2 s. When the affected screen is not open, a toast names the change and offers "Open in <screen>".
- **Banner.** "Agent writes are not being marked" appears the moment auditing goes off and clears the moment it comes back. It links to Auditing configuration, and OcuPilot administrators also get "Turn auditing on".
- **Auditing configuration** (7.4 and 7.11) is a form. The system-event and user-event lists are embedded beneath it, each behaving as a list, and the screen cross-links to the Audit database viewer.
- **Strings.** Every new user-facing string goes into EXPERIENCE.md's Fixed strings table, with its `strings.ts` key, in the same pass.

## Cross-Story Dependencies

- **Upstream, Epic 5:** the write path and each area's first write. 7.1 extends 5.8, 7.2 extends 5.9, 7.4 and 7.11 extend 5.10's auditing toggle, 7.6 extends 5.11's task resume, 7.8 extends 5.12's process suspend and resume, and 7.10 extends 5.13's delete by namespace.
- **Upstream, Epic 6:** the screens: the OAuth tabs (7.3), the on-demand list (7.5), Task details and the schedule (7.6), Processes and Process details (7.8), and the error drill-down (7.10).
- **Within this epic:** 7.6 owns the UJ-6 replay end to end. The agent navigates to Task details, the Status field highlights, and a toast reads the change with "Open in Task schedule". 7.4 and 7.11 are the two halves of the Auditing screen.
- **Routed ledger items:** DW-1486 is attached to 7.8 and is marked floor-blocking. Moving its arm out of `Disables()` needs an AD-10 amendment first.
- **Downstream:** Epics 9 and 12 become eligible once both Epic 7 and Epic 8 have merged. Epic 12's OAuth editors build on 7.3's deletes. Epic 16 takes Task Manager control (16.11) and lock removal (16.12).
