# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Voting-week work: the second-tier screens and actions a judge compares entries on, six stories deferred from the contest build (16.11 to 16.16) and stories from the contest surveys (16.17 to 16.24). Done: 16.1, 16.8, 16.9 and 16.17 to 16.23. **This run's order:** 16.24, then 16.3 and 16.16. 16.4 waits for Story 18.1, and the rest stay in the backlog. **Nothing here may break a Release 1 screen or a Release 1 agent write**; anything that risks either waits for Stage 2.

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
- **Copy.** Every new string goes into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change; runners never invent copy. While two slots edit it, EXPERIENCE.md is edited in place with its line count unchanged (new strings fold into existing rows), so no `EXPERIENCE.md:n` citation shifts. The curl copy has no strings yet. Reusable: "Copied", the clipboard-unavailable sentence, the try-it console's refusal sentences.
- **Bundle.** 2,002,678 bytes after 16.9, against a 2004kB `maximumWarning`: little headroom. The hard stop is 4000kB; stop and ask above 3800kB. No lazy routes, no `@defer`.
- **16.24.** **Copy as curl** puts one command on the clipboard and sends nothing: the method, the absolute URL with its query, the headers and the body, as the console would send them. The access token and every header the console masks are never copied; the command carries a placeholder and the console says so beside the copy. Values are quoted so the command runs as shown in a POSIX shell. A request the console refuses to send is refused for copy with the same reason.
- **16.3.** A user's effective roles, resources, applications, databases and services render, composed from reads the area already makes. The permission-check tool (agent or user, for a user or a role) answers yes or no and names the granting role, short-circuiting on `%All`. Routed: DW-1018, decided that a rail item is allowed when any of its screens is, each screen keeping its own gate.
- **16.16.** Lists ledger rows with filters by user, screen and date, and opens a row's arguments and result. A user sees their own rows; an OcuPilot administrator's view of another user's rows is gated by the resources recorded on each row. Secrets are absent because they were excluded at write time.
- **Keep intact:** the done stories' surfaces. Download CSV (16.23) comes automatically on a new data table; the hub's members (16.9) are the listed Logs screens, pinned by a test.
- **Routed ledger entries** for backlog stories (16.5, 16.7, 16.10, 16.12 to 16.15) are addressed or declined with a reason when their story is built.

## Technical Decisions

- **Reads (AD-5, AD-24, AD-36).** A hand-written descriptor with at least three prompts; `Screen/Registry.cls` and `screen-mirror.mjs` refuse identically. Screen and tool share one bounded read that reports truncation. Its source is an instance endpoint through a port, OcuPilot's protected state through a kernel store's guarded list, or a composition of the area's screens' reads (the hub, Logs only). A `state` store may release only the caller's own rows, or every row to an `OcuPilotAdmin:USE` holder, decided before any escalation, with no caller argument on the read (first used by 14.4's Transcripts). A `datetime` criterion may declare `defaultHoursAgo`.
- **Try-it console (AD-57).** A same-origin browser request under the tab's Bearer token, never the refresh token or a cookie; not a tool and not the write path. Targets are resolved as the browser resolves them, then OcuPilot's own applications and `/api/admin` writes are refused; other writes are confirmed first. The record masks the Authorization header and any header, query parameter or body member matching the Conventions › Secrets pattern. The response reaches the screen only. AD-57 has no curl line: its masking and refusal rules bind the copy as a new surface on the same request (inference; may warrant an AD-57 line at the spec gate).
- **Privilege (AD-8, AD-29).** Pair sets checked at call time, no elevation; what a caller cannot read is reported, never inferred. An area's set covers its screens' pairs except declared `ownPrivileges` (event log `%Ens_EventLog:USE`, analytics `%DeepSee_Portal:USE`). DW-1018 must be reconciled with that coverage rule (inference). `Kernel.Shell.Effective` is the one effective-privilege composition: the union over roles, transitively; `%All` holds everything; public permissions are held by every user; escalation roles count for nothing until used.
- **Ledger (16.16).** Per user, bounded, secrets excluded by schema at write time (AD-41). An administrator's view of others' rows is gated by each row's recorded resources, and that gate lives with the ledger (AD-46).
- **Logs and dates.** `LogSourcePort` reads every log the admin API does not back; no endpoint accepts a path (AD-21). A log entry's `time` is instance-local `YYYY-MM-DDTHH:MM:SS.mmm`, no zone; other emitted timestamps are ISO-8601 UTC, and local-calendar comparisons use `+$Horolog`. Tool results pass one sanitizer (AD-60), never relied on as the defense.
- **Navigation (AD-11).** `shell.screen.open` accepts registry routes only; `criteria` only on `list (server criteria)` screens, validated on the instance and carried on the directive, never in a URL. A person-initiated arrival (`ScreenArrivals`) is not announced.
- **Writes (later stories).** One tool, two callers (AD-53, AD-55), its port declared per tool (AD-52), read back (AD-58); governance is stored setting, then preset, then baseline, checked at dispatch and at Confirm (AD-22). Screens re-fetch after a confirmed write (AD-14).
- **Conventions.** Client: zoneless, `OnPush`, framework-free root stores in `core/` mirrored into signals, reset at sign-out; every API URL absolute (AD-19, AD-20). Server: one envelope `{error, reason, code, detail}`; ids encoded twice, decoded once; tools named `<area>.<screen>.<verb>`.

## UX & Interaction Patterns

- **Try-it console.** Request and response sit under their headings on the code surface, as data. A copy control follows the code-block pattern: "Copied" announced politely; on clipboard failure, the fallback sentence with the text left selectable.
- **Placement.** Effective privileges is a view in the User editor (detail); Permission check is a command-bar action (dialog); Agent audit ledger is a polish-week entry in the Agent co-pilot area (list, server criteria), beside Guardrails, Governance policy and Transcripts.
- **Gated controls** use `aria-disabled`, never `disabled`, and name their reason ("Requires <resource>"). A screen's destructive dialog asks for the typed name; a destructive agent proposal takes the destructive bar without one.

## Cross-Story Dependencies

- **Slot A.** Profile `ocupilot-slot-a`, throwaway `ocupilot-ci` on 52776/1975. After an integrate forward, load the merged ObjectScript into the throwaway (Rule 22). Push a code commit alone and confirm its CI before a skip-tagged one (Rule 28). `main` and release branches move only at owner-planned releases; a cut release branch is never touched.
- **Story 13.5 runs on slot B.** Do not edit `.github/workflows/ci.yml`, `ui/tools/ci-runner.mjs` or `ui/browser.config.mjs`. `ui/tools/ci.test.mjs` and `scripts/ci-throwaway.sh` roster changes are add-only; new browser specs and test classes land unassigned in 13.5's timings file.
- **Epic 14 is complete**: its governance baseline, sanitizer, per-user read-only and transcripts bind new work.
- **Within this epic.** 16.24 depends only on 16.1. 16.3 uses `Kernel.Shell.Effective` (16.19). 16.16 can follow the Transcripts caller-scoped store (inference).
- **Held.** 16.4 needs Story 18.1's directory allow-list (Epic 18 follows 13.5 on slot B). 16.13 and 16.14 each remove a classic-link exemption (AD-44).
