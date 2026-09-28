# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Voting-week work: the second-tier screens and actions a judge compares entries on, six stories deferred from the contest build (16.11 to 16.16) and stories from the contest surveys (16.17 to 16.24). Done: 16.1, 16.8, 16.9 and 16.17 to 16.24. **Remaining run order:** 16.3 (spec ready), then 16.16. 16.4 waits for Story 18.1, and the rest stay in the backlog. **Nothing here may break a Release 1 screen or a Release 1 agent write**; anything that risks either waits for Stage 2.

## Stories

- Story 16.1: The try-it request console
- Story 16.2: Web sessions, listed and ended
- Story 16.3: Effective privileges and the permission-check tool
- Story 16.4: Task export and import
- Story 16.5: Background tasks
- Story 16.6: Broadcast a message to processes
- Story 16.7: License usage and the full dashboard
- Story 16.8: The six secondary log viewers
- Story 16.9: The unified log hub
- Story 16.10: External language servers
- Story 16.11: Start, suspend and resume the Task Manager
- Story 16.12: Remove locks - one, all of a process, all of a remote client
- Story 16.13: The service editor
- Story 16.14: The LDAP and Kerberos editor
- Story 16.15: The data-egress line
- Story 16.16: The agent audit viewer
- Story 16.17: The read-back line
- Story 16.18: Home's performance row
- Story 16.19: Impact lines on removals
- Story 16.20: Older messages.log files
- Story 16.21: Security findings, with a fix you confirm
- Story 16.22: The Guardrails page
- Story 16.23: Any table, downloaded as CSV
- Story 16.24: A try-it request, copied as curl

## Requirements & Constraints

- **Every story.** A screen is one descriptor with its derived read tool; an action ships with its confirmed write tool, its key joins `Kernel/Governance/Baseline.cls` in the same story (enabled unless the criteria say disabled), and every `Invoke` branch has a `Snippet` branch. A test fails on either gap.
- **Copy.** Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change; runners never invent copy. While slot B also edits it, EXPERIENCE.md is edited in place with its line count unchanged (new strings fold into existing rows), so no `EXPERIENCE.md:n` citation shifts.
- **Bundle.** 2,006,491 bytes after 16.24, against a 2107kB `maximumWarning`; a story that crosses it re-bases it under DW-1166 (5% above the measured total, with the `angular-json.test.mjs` literal). Stop and ask above 3800kB (hard stop 4000kB). No lazy routes, no `@defer`.
- **16.3.** A user's effective roles, resources, applications, databases and services render, composed from reads the area already makes. The permission-check tool (agent or user, for a user or a role) answers yes or no, naming the role whose own grant it is and the account's role it is reached through, and short-circuits on `%All`. Its routed DW-1018 is decided as Option A (AD-8 below); the routing line's "a rail item is allowed when any of its screens is" is not adopted, and that residual is DW-1768.
- **16.16.** Lists ledger rows with filters by user, screen and date, and opens a row's arguments and result. A user sees their own rows; an OcuPilot administrator's view of another user's rows is gated by the resources recorded on each row. Secrets are absent because they were excluded at write time by schema, never redacted afterwards.
- **Keep intact:** the done stories' surfaces. Download CSV (16.23) comes automatically on a new data table; the hub's members (16.9) are the listed Logs screens, pinned by a test.
- **Routed ledger entries** for backlog stories (16.5, 16.7, 16.10, 16.12 to 16.15) are addressed or declined with a reason when their story is built.

## Technical Decisions

- **Reads (AD-5, AD-24, AD-36).** A hand-written descriptor with at least three prompts; `Screen/Registry.cls` and `screen-mirror.mjs` refuse identically. Screen and tool share one bounded read that reports truncation. Its source is an instance endpoint through a port, OcuPilot's protected state through a kernel store's guarded list, or a composition of the area's screens' reads, each member through its own gate, never widening. A `state` store may release only the caller's own rows, or every row to an `OcuPilotAdmin:USE` holder, decided before any escalation, with no caller argument on the read (first used by 14.4's Transcripts). A `datetime` criterion may declare `defaultHoursAgo`.
- **Privilege (AD-8, AD-29).** Pair sets are checked at call time, with no elevation; what a caller cannot read is reported, never inferred. An area's set gates its rail item, Home tile and side bar, and covers its screens' pairs except pairs a screen declares its own (`ownPrivileges`, validated alike by `Screen.Registry` and `screen-mirror.mjs`), which are never pairs the area declares; a caller lacking an own pair loses that screen alone. The cases: Logs (event log `%Ens_EventLog:USE`, analytics log `%DeepSee_Portal:USE`) and, from 16.3, Security, whose set is `%Admin_Secure:USE` + `%DB_IRISSYS:READ`, the wallet screens owning `%Admin_Wallet:USE` and each OAuth 2.0 tab and form its OAuth resource.
- **Effective privilege.** `Kernel.Shell.Effective` is the one composition, and 16.3's Effective privileges view and permission check use it: the union over the user's roles and, transitively, every role they grant; `%All` anywhere in that closure holds everything; a resource's public permission is held by every user; an escalation role counts for nothing until used.
- **Ledger (AD-9, AD-41, AD-46).** OcuPilot's own protected state, per user, holding prompts and rationales. A row is finalized after the write and records what executed (resolved target, fields sent, privileges exercised); secret-typed fields are excluded at write time (AD-3). Bounded per turn, overflow recorded as a count. The per-row gate lives with the ledger, not the screen. The agent markers in the IRIS audit database are a separate thing, shown on the audit screen.
- **Navigation (AD-11).** `shell.screen.open` accepts registry routes only; `criteria` only on `list (server criteria)` screens, validated on the instance and carried on the directive, never in a URL. A person-initiated arrival is not announced.
- **Dates.** Emitted timestamps are ISO-8601 UTC (a log entry's instance-local `time` excepted); local-calendar comparisons use `+$Horolog`.
- **Writes (backlog stories).** One tool, two callers (AD-53, AD-55), port declared per tool (AD-52), read back (AD-58), governance checked at dispatch and at Confirm (AD-22).
- **Conventions.** Client: zoneless, `OnPush`, framework-free root stores in `core/` mirrored into signals, reset at sign-out; every API URL absolute (AD-19, AD-20). Server: one envelope `{error, reason, code, detail}`; ids encoded twice, decoded once; tools named `<area>.<screen>.<verb>`.
- **Tests.** CI runs each long suite as three shards on fresh throwaways, regrouped as timings change, so a test depends on nothing another left, on order, or on instance uptime; such a red is fixed in the test, never by pinning.

## UX & Interaction Patterns

- **Placement.** Effective privileges is a view in the User editor (Permissions area, detail); Permission check is a command-bar action (dialog); the Agent audit ledger is a polish-week entry in the Agent co-pilot area (list, server criteria), beside Guardrails, Governance policy and Transcripts.
- **Gated controls** use `aria-disabled`, never `disabled`, and name their reason ("Requires <resource>"). A screen's destructive dialog asks for the typed name; a destructive agent proposal takes the destructive bar without one.

## Cross-Story Dependencies

- **Slot A.** Profile `ocupilot-slot-a`, throwaway `ocupilot-ci` on 52776/1975. After an integrate forward, load the merged ObjectScript into the throwaway (Rule 22). Push a code commit alone and confirm its CI before a skip-tagged one (Rule 28). `main` and release branches move only at owner-planned releases; a cut release branch is never touched.
- **Slot B runs Epic 18 (18.1 to 18.4).** Both epics touch `ui/tools/**`, `scripts/ci-throwaway.sh` and EXPERIENCE.md; keep shared roster edits to added lines (inference).
- **Epic 14 is complete**: its governance baseline, sanitizer, per-user read-only and transcripts bind new work.
- **Within this epic.** 16.3 uses `Kernel.Shell.Effective` (16.19) and adds Security's `ownPrivileges`. 16.16 can follow the Transcripts caller-scoped store (inference).
- **Held and pending.** 16.4 needs Story 18.1's directory allow-list. 16.13 and 16.14 each remove a classic-link exemption (AD-44). DW-1768 (the any-screen rail) and DW-1769 (whether Copy as curl masks beyond the credential-name pattern) are owner decisions, not 16.3's or 16.16's to settle.
