# Epic 7 Context: Act on any row

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is build step 4. Completing it clears the last floor requirement below the create-and-edit line. A user does the small jobs that make up most daily administration (enable, disable, run, suspend, resume, terminate and delete) from the row menu or the command bar, and the row updates in place. The user can also ask the agent to do any of these through a confirmed proposal. Epic 5 built the write path and one write per area, and Epic 6 built the screens. This epic adds the remaining verbs to screens that already exist, so each action has two callers: the screen and the agent's write tool. Stories 7.1 to 7.6, 7.8 and 7.10 are done. The one remaining story is 7.11. It completes the Auditing configuration screen that 7.4 built by adding row actions to its system-event and user-event lists, plus the selective SQL auditing wizard.

## Stories

- Story 7.1: Enable, disable and delete a web application (done)
- Story 7.2: User enable, disable, delete, password and roles (done)
- Story 7.3: Delete an OAuth 2.0 client configuration or server client description (done)
- Story 7.4: Turn auditing on and off from the screen (done)
- Story 7.5: Run an on-demand task (done)
- Story 7.6: Run, suspend, resume and delete a task (done)
- Story 7.8: Terminate, suspend and resume a process (done)
- Story 7.10: The remaining application error delete scopes (done)
- Story 7.11: System and user audit event configuration

Stories 7.7 (Task Manager control) and 7.9 (lock removal) moved to Epic 16 as 16.11 and 16.12.

## Requirements & Constraints

- **Two callers, one operation.** A story is not done when the button works. The agent's write tool follows the full model:
  - a server-minted proposal built from a fresh read;
  - a diff computed on the instance;
  - a confirmation sent as a separate authenticated request that executes the stored arguments;
  - the prohibited set and both switches, evaluated at the write inside the atomic transition;
  - the agent marker.

  Both callers publish the change event, and the row updates in place.
- **Audit event configuration (7.11).**
  - A system event can be enabled, disabled and have its counter reset.
  - A user event can be created, configured and deleted.
  - The selective SQL auditing wizard configures the SQL audit events it covers.
- **`Security.Audit.Event` publishes no body template, and its PUT is an upsert.** Derive the write's field list from the underlying class, pin it with a test, and test the upsert path explicitly.
- **Disabling OcuPilot's own audit events** must state the consequence: agent writes stop being marked. It is a non-delete write, so it takes the warning dialog with a primary button. The panel's "Agent writes are not being marked" banner must appear the moment the disable takes effect, and a proposal for it carries the warning in its card.
- **Self-protection is enforced on the instance, never only in the UI.** The row menu only explains a refusal, and the kernel refuses the prohibited set whatever the caller. Each predicate is stated over the effect, so a bodyless delete still reaches the arm that protects its target.
- **Privilege grants are permitted (owner reversal, 2026-09-23).** Epic 8 implements this. Until it merges, this branch's kernel still refuses grants with `PROHIBITED.PRIVILEGEGRANT`.
- **A no-op action is refused with 400 `TOOL.ARGUMENTS` and `detail.problem`, and nothing is sent.** Both callers answer in that shape.
- **A confirm is a user request outside any turn**, so no agent reply follows it.
- **Destructive or state-changing tests run only on a throwaway**, only against fixtures the test created itself, and one test class per call.

## Technical Decisions

- **AD-53 is the seam.**
  - The screen action is a user-originated `POST /screens/:screen/action`, beside `GET /screens/:screen/read`.
  - Both callers share:
    - target resolution through the tool's declared port;
    - the fresh read;
    - the prohibited set, evaluated at the write;
    - the caller's own privilege pairs, checked **before** the fresh read, so a short account gets `AUTH.NOPRIVILEGE` naming the failed pair;
    - the change event;
    - the vendor's audit record.
  - The screen caller mints no proposal, emits no agent marker, and is not gated by the kill switch or enforced read-only.
- **`MOVESMARKING` (AD-53, amended 2026-09-23).** A write that opens or closes the audit channel records the observed marking fact that the banner reads.
  - The agent's caller takes the fact from its marker's own answer.
  - The screen caller emits no marker, so after the write it re-reads through the tool's port, with the caller's own privileges. It reads the instance auditing flag and OcuPilot's marker event (marked = both enabled) and records that.
  - A failed observation records nothing and never fails the write.
  - A tool opts in with `Parameter MOVESMARKING = 1`. `AuditingUpdate` (7.4) is the first, and 7.11's disable of OcuPilot's own events is the second.
  - `Kernel/Audit/Event.cls` provides `ObserveMarking`, `MovesMarking` and `RecordMarking`. The install rule it mirrors: with auditing off, the answer is 0 without reading the event, and a 404 on the event means "not marked".
- **Closing the audit channel cannot be marked (AD-15).** Once the write closes the channel, the marker has nowhere to land. The ledger row reads "done · audit not marked" and the banner shows. The re-enable is marked. OcuPilot registers its events under its own Source at install (for example `OcuPilot/Security/AgentWrite`, `OcuPilot/Security/ConfigChange`), and they appear among the user events.
- **Audit event reads (measured in 7.4).**
  - `Security.Audit.Event` `LIST` takes `eventOwner`:
    - 1 answers the system events (75 rows);
    - 0 answers the user events (4 rows, OcuPilot's own among them);
    - 2 answers all of them.
  - A row is `{EventName, Enabled, Total, Written, Lost}`.
  - `GET` needs `source`, `type` and `name`, and answers `{Description, Enabled}`.
  - The vendor gate (`ResourcesOR`) is `%Admin_Secure`, so the pair is `%Admin_Secure:USE`.
  - The lists are 7.4's `AuditSystemEventList` and `AuditUserEventList`: entity type `audit-event`, id `EventName`.
- **Merge writes** (enable, disable) reuse the area's update tool, and nothing else writes those fields.
  - `SCREENACTIONS` maps an action to fixed values. Its grammar is `enable=Enabled:true,disable=Enabled:false`, as in `WebAppUpdate` and `AuditingUpdate`.
  - Field lists are derived, never hand-typed.
- **Action-style writes** (delete, reset) declare:
  - `WRITETYPE`;
  - `SENDSBODY = 0`;
  - `CHANGEACTION`;
  - `DESTRUCTIVE` where it applies;
  - a non-empty `FINGERPRINTSUBJECT` with a `PRECONDITIONFIELD` inside it, drawn from keys the target's read actually answers (measured). It excludes identity, fast-moving counters and secret-pattern keys.

  Every diff-row label must be the `STATEFIELD` or a subject name, or `Prohibited.ReviewedFewOnly` refuses it. A fixed vendor body that no caller supplies comes from `AdminPort.CONSTANTBODIES`, keyed by endpoint and type.
- **AD-56: values a caller puts into a write.**
  - The route refuses, and never ignores, a key the tool does not declare.
  - A non-secret value must land in a settable field, so a bodyless action cannot carry one. Use a second tool reached through an undrawn declared action instead; 7.8's `terminate-with-error` is the precedent.
  - A list field changes by a server-side delta over a fresh read (7.2's `SCREENVALUES`).
- **The prohibited set has one home, in `Prohibited.cls`.** Every new entity type a write touches is covered there, or its writes are refused as `PROHIBITED.UNCOVERED`. Each arm has a test that fails when the arm is removed.
- **Refusal copy is written once.** The same sentence appears in EXPERIENCE.md's Fixed strings, as the kernel's envelope `reason`, and as the row action's inline reason, and a test pins them equal. A reason that names "the agent" is a defect.
- **Ports (AD-52, AD-27).** A tool may declare its own port, and only `AdminPort` names an `%Api.Admin.*` class. Where the admin API cannot express a write, a port may call the documented `%SYS` method the vendor endpoint itself calls. It must first repeat that endpoint's gate, its not-found answer and its guard (7.8's `ProcessPort` is the precedent). A non-default port bypasses `ProposalFixture`'s canned-read seam.
- **Descriptors.**
  - A row action has a `selfProtection` rule from a closed vocabulary (`""` where none applies).
  - An action is declared only in the same pass that registers its handler.
  - A list that declares a row action names `emptyAgentKey` and leaves `emptyNextKey` empty.
  - Tool names follow `<area>.<screen>.<verb>`.
  - The row key and the typed name use the vendor's IdKey.
- **Identity** is `(entity type, scope, id)` in canonical form, at mint, confirm, row action and change event. Each write publishes one change event. Screens re-fetch and never patch.
- **Application errors (AD-48, amended 2026-09-23).** All three delete scopes (namespace; namespace and date; one error) are prefixes of the composite id. Each is enumerated at mint and deleted through `DeleteByError`. `DeleteByDate` and `DeleteByNamespace` are never called.

## UX & Interaction Patterns

- **Row menu.** Actions appear in command-bar order, with destructive actions last. A refused or privilege-gated action stays listed as a non-selectable row with its reason inline, and the arrow keys still reach it. Such rows are never Material-disabled. Every row-menu item is also on the command bar, which wraps rather than hiding an action.
- **Warning dialog** (`app-warning-dialog`, the shell's `warning` pending kind, keyed by `WARNING_CONSEQUENCES`). It comes before a non-delete write.
  - The title is the verb and the body is the consequence.
  - "Proceed" is `button-primary`, and initial focus is on Cancel.
  - Escape, Cancel and the scrim send nothing.
- **Typed-name dialog** (for deletes).
  - The name must match exactly, case-sensitive, and pasting is allowed.
  - A mismatch shows "Does not match" on blur.
  - The `button-destructive` button is labeled with the verb and target and stays `aria-disabled` until the name matches.
  - Each action has its own consequence body in `DESTRUCTIVE_CONSEQUENCES`.
  - The typed `name` can differ from the sent `target`.
  - An optional `advisory` paragraph carries a consequence that depends on the row.
- **Non-destructive, unwarned actions** (enable, reset a counter) are sent at once with no dialog. The row is marked changed in place, keeping its filter and selection.
- **Auditing configuration** is a form-page.
  - A status line and one toggle button; turning auditing off goes through the warning dialog.
  - Beneath it, the System events and User events lists (columns name, status, Total, Written, Lost), each also at its own route.
  - A cross-link to the Audit database viewer.
  - The page re-reads on an `auditing-configuration` change event.
  - 7.11 adds the lists' row actions and the SQL wizard on the same descriptors. The catalog lists enable/disable audit events and reset counters among the row-menu and command-bar actions that have no surface of their own.
- **Banner.** "Agent writes are not being marked" appears the moment marking stops, from either caller, and clears when marking returns.
- **Strings.** Every new user-facing string goes into EXPERIENCE.md's Fixed strings together with its `strings.ts` key, in the same pass. `strings.ts` is shared-append.

## Cross-Story Dependencies

- **7.11 consumes 7.4:**
  - the `AuditSystemEventList` and `AuditUserEventList` descriptors;
  - `AuditingUpdate` and `MOVESMARKING`;
  - the warning dialog and `ObserveMarking`.

  It also uses 7.1's route, `Operation`, generic row-action handler and typed-name dialog, and 5.10's recorded fact and banner. It builds no per-area handler of its own.
- **Routed to 7.11:**
  - **DW-1529.** Both event lists declare `audit-event`, so `screenForEntityType` resolves a user event's reference to the system-event list.
  - **DW-1530.** The screen caller's post-write `Security.Audit.Event` GET has never run as a principal holding exactly the declared pairs.
- **Still open from 7.1:**
  - DW-1001 and DW-1013, for the first story that amends a derived read's criteria;
  - DW-1136 and DW-1137, in `AdminPort`;
  - DW-1099, descriptor read, filter and sort assertions;
  - DW-389, Switches declares row actions with no handler.
- **Reopen at the Epic 7/8 merge:** DW-1557 and DW-1563, both stale `AdminPort` and `Prohibited` docs.
- **Epic 8 runs concurrently.**
  - It owns:
    - `areas/web-applications/**`;
    - `scripts/ci-*.sh` and `ci.yml`;
    - `Install/**` except `Smoke.cls`;
    - `Kernel/Secret/Ladder.cls`;
    - `ui/tools/field-lists.*`;
    - the arming roster, so do not add a new *armed* test class.
  - Shared-append: `AdminPort.cls`, `strings.ts` and `_components.scss`.
  - Contended: `Prohibited.cls`, `Write.cls`, `Confirm.cls`, `Registry.cls` and the test roster classes. Before editing one, run `git show origin/OCU-1-epic8:<path>` and stay off its hunks. A story that touches an Epic 8-modified file lists it under `footprint_extensions` with the line ranges of its own members.
- **Downstream:** Epics 9 and 12 become eligible once Epics 7 and 8 have both merged.
