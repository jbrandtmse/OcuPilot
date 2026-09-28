# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is voting-week work. It adds the second-tier screens and actions a judge sees when comparing entries: a try-it console, web sessions, effective privileges and a permission check, task export and import, background tasks, broadcast, license usage and the full dashboard, six secondary log viewers, and a log hub with a merged timeline. It also covers external language servers, six stories deferred from the contest build (16.11 to 16.16), and stories that came out of the contest surveys (16.17 to 16.24). Stories 16.1, 16.8 and 16.17 to 16.23 are done and shipped in release 1.0.2. **This run's order:** 16.9 (amended: merged timeline), then 16.24, then 16.3 and 16.16. 16.4 waits for Story 18.1, and the rest stay in the backlog. **Nothing here may break a Release 1 screen or a Release 1 agent write.** Anything that risks either waits for Stage 2.

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

- **Every story.**
  - Each screen is one descriptor with its derived read tool, and each action ships with its confirmed write tool.
  - A new write key joins `Kernel/Governance/Baseline.cls` in the same story, enabled unless the story's criteria say disabled (through 2026-10-04). A test fails naming any registered write key missing from it.
  - A new write tool also needs its script form: a `Snippet` branch in its port for every `Invoke` branch. Without it, a registry test fails.
- **Copy.** Every new user-facing string goes into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change. Runners never invent copy. The hub, the timeline and the curl copy have no strings yet. Existing strings that can be reused: "Explain this entry", the log viewer's words and truncation notices, "Copied", and the sentence shown when the clipboard is unavailable.
- **Bundle.** `maximumWarning` is 2004kB and the hard stop is 4000kB. Stop and ask above 3800kB. No lazy routes and no `@defer`. The bundle is about 1.98 MB now.
- **Hub (16.9).**
  - Lists every log source with a count and its last entry. Each row opens that source and carries an explain entry point.
  - **Timeline view:**
    - Merges the entries of every listed source the person may read, newest first, over a chosen window that defaults to the last hour. Each entry shows its time, source, severity (where the source records one) and text.
    - Times are compared and shown on the instance's clock, whatever form or time zone each source writes.
    - Each source is read through its own bounded read, with its own viewer's privilege and fixed source name, never a path. A source has a row cap, and hitting it is marked in the viewers' existing truncation words.
    - A source the person may not read is left out without an error. The timeline names each such source and the privilege it needs.
    - Filters by source, severity or text leave only matching entries, and each source's count in the list updates to match.
    - Choosing an entry opens its source at that entry. The entry's explain entry point sends that entry alone.
- **Curl copy (16.24).**
  - **Copy as curl** puts one command on the clipboard and sends nothing: the method, the absolute URL with its query, the headers and the body, as the console would send them.
  - The access token, and any header the console masks, is never copied. The command carries a placeholder instead, and the console says so beside the copy.
  - Values are quoted so the command runs exactly as shown in a POSIX shell.
  - A request the console refuses to send is refused for copy too, with the same reason.
- **16.3.** A user's effective roles, resources, applications, databases and services render, composed from reads the area already makes. The permission-check tool answers yes or no and names the granting role, short-circuiting on `%All`.
- **16.16.** Lists ledger rows with filters by user, screen and date, and opens a row's arguments and result. A user sees their own rows. An OcuPilot administrator's view of another user's rows is gated by the resources recorded on each row. Secrets are absent because they were excluded at write time.
- **Done work that later stories keep intact:**
  - 16.17: the read-back line on every confirmed write.
  - 16.18: Home's performance row, absent rather than zeros for a caller who may not read the metrics.
  - 16.19: impact lines on role delete, role removal from a user and resource delete.
  - 16.20: the messages.log file choice, with the file named in the address.
  - 16.21: Home's findings panel, both groups.
  - 16.22: the Guardrails page, generated from the enforced rules.
  - 16.23: Download CSV on every data table. A new table screen gets it automatically.
  - 16.8: the six secondary viewers.
- **Routed ledger entries for backlog stories.** Each is addressed, or declined with a reason, when its story is built:
  - DW-1018 (16.3)
  - DW-1080, DW-1101, DW-1137 (16.5)
  - DW-1116 (16.7)
  - DW-253 (16.10)
  - DW-1073, DW-1074 (16.12)
  - DW-1016 (16.13)
  - DW-1639 (16.14)
  - DW-1076, DW-1192 (16.15)

## Technical Decisions

- **Descriptors and reads (AD-5, AD-24, AD-36).**
  - A screen is a hand-written descriptor with at least three suggested prompts. `Screen/Registry.cls` and `screen-mirror.mjs` refuse identically.
  - The screen and its tool share one bounded read that reports truncation.
  - Context caps: rows 1 to 1,000 (default 200), 65,536 characters in total, 1,000 characters per field.
  - A `datetime` criterion may declare `defaultHoursAgo` or `atOrAfterField`, and the answer reports `criteria`.
- **Log sources.**
  - `LogSourcePort` reads every log the admin API does not back. Of the six secondary logs, four are read per namespace, over the set the caller can read, through the vendor's own readers. The event log and SQL diagnostics are read with `%ExecDirectNoPriv`, behind the source's own gate (AD-29).
  - AD-21: no endpoint accepts a path, and files are named from a fixed enum. AD-21 names exactly five pattern cases: the static handler, the WSGI directory, a task output file, rotated `messages.old_*` and `DeepSeeTasks_<NS>.log`. Any other pattern-named file needs an AD-21 amendment first.
  - The application error log goes through `SYS.ApplicationError`. Its detail is secret by default, and only summary fields reach the model (AD-48).
  - The audit record LIST is async (AD-26), and its `EventData` is masked per declared event (AD-35).
  - Log text and tool results reach the model through one sanitizer (AD-60). A new read tool needs no change, and nothing may rely on the sanitizer as the defense.
- **Privilege (AD-8, AD-29).**
  - Gates are pair sets checked at call time, with no elevation. What a caller cannot read is reported as such, never inferred.
  - An area's pair set covers its screens' pairs, except pairs a screen declares as `ownPrivileges`. Today those are the event log's `%Ens_EventLog:USE` and the analytics log's `%DeepSee_Portal:USE`. The hub and timeline must honor each source's own gate (inference).
  - DW-1018's decision (a rail item is allowed when any of its screens is) must be reconciled with this coverage rule when 16.3 takes it up (inference).
  - `Kernel.Shell.Effective` is the one effective-privilege composition, and 16.3 uses it: the union over roles, transitively; `%All` holds everything; public permissions are held by every user; escalation roles count for nothing until used.
- **Dates.** Emitted timestamps are ISO-8601 UTC, and instance-local calendar comparisons use `+$Horolog`. The timeline's "instance's clock" rule must be squared with this at the spec gate, and may need a spine note (inference).
- **Navigation (AD-11).**
  - `shell.screen.open` accepts only registry routes.
  - `criteria` works on `list (server criteria)` screens only, and is validated on the instance and carried on the directive, never in a URL.
  - An unstarted navigation is announced, and a citation chip is a reference.
  - Opening a source "at that entry" has no existing mechanism in the viewers (inference).
- **Try-it console (AD-57).**
  - It is a browser request under the tab's Bearer token. It is not a tool and not the write path.
  - Before any spelling is compared, the target is resolved the way the browser resolves it. OcuPilot's own applications are refused, and so are `/api/admin` writes.
  - Other writes are confirmed in a dialog first.
  - The record of a request masks secret-named headers, query parameters and body members.
  - The curl copy is a new surface for the same request, so these masking and refusal rules bind it (inference: may warrant an AD-57 line).
- **Ledger viewer (16.16).**
  - The ledger is per user. An administrator's view of another user's rows is gated by each row's recorded resources, and that gate lives with the ledger (AD-46).
  - A `state` store may release only the caller's rows, or every row to an `OcuPilotAdmin:USE` holder, decided before any escalation (AD-36, first used by 14.4's Transcripts).
  - Ledger rows record what was executed, with secrets excluded at write time (AD-41).
- **Writes, for later stories.**
  - A screen action and the agent are two callers of one tool (AD-53, AD-55).
  - Write kinds are merge (AD-4), action-style (AD-51), create (AD-54) and secret-only (AD-56). `Task.Manager`, `Lock` and `Process` are action-style and need no template (16.11, 16.12).
  - The port is declared per tool (AD-52).
  - Read-back follows AD-58. Per DW-1710, a create re-reads by `createdId`; that fix belongs to the range-end cleanup.
  - Copy-out follows AD-59. Governance as shipped: stored setting, then preset, then baseline, checked at dispatch and again at Confirm (AD-22).
  - AD-10 refuses disabling `%Service_WebGateway` from either caller (16.13).
  - LDAP test connection uses AdminPort's async path, and list, get and put stay synchronous (AD-26, 16.14).
  - Background tasks need an admin-API half and a custom-endpoint half (16.5).
  - The egress line is computed from the same configuration the request uses (AD-42, 16.15).
- **Refresh (AD-14, AD-43).**
  - A confirmed write publishes the scoped triple, and screens re-fetch rather than patch.
  - Auto-refresh has one framework over EXPERIENCE.md's roster of eight. A screen joins through its descriptor and the roster together.
- **Client and server conventions.**
  - Client (AD-19, AD-20): zoneless, `OnPush`, framework-free stores in `core/` mirrored into signals. Every root store resets at sign-out, and every API URL is absolute.
  - Server: one envelope `{error, reason, code, detail}`, ids encoded twice and decoded once, and tools named `<area>.<screen>.<verb>`.

## UX & Interaction Patterns

- **Log viewer.**
  - Rows show time, pid, a severity chip with its word, and text. A per-row explain entry point sends that entry alone.
  - The sticky search shows a polite "n of N", with "Next match" and "Previous match" beside it. Jump to top and bottom, "Load newer" and a Raw toggle on `code-surface` complete the bar.
  - Secondary logs show a bounded newest window, and per-namespace entries lead with `[<namespace>]`. It is a tail, not live.
- **Placement.**
  - "Unified log hub" is the last polish-week entry in the Logs side bar (log-viewer · list).
  - Effective privileges is a view in the User editor. Permission check is a command-bar action.
  - Agent audit ledger is a polish-week entry in the Agent co-pilot area (list, server criteria).
- **Try-it console.** The request and response appear under their headings on the code surface, as data. A copy control follows the code-block pattern: it announces "Copied" politely, and if the clipboard fails it shows the fallback sentence and leaves the text selectable.
- **Gated controls.** They use `aria-disabled`, never `disabled`, and name their reason ("Requires <resource>"). A screen's destructive dialog asks for the typed name, while a destructive agent proposal takes the destructive bar with no typed name.
- **Meters (16.7).** Each state is shown as a word as well as a colour.

## Cross-Story Dependencies

- **Slot and process.**
  - This run uses slot A: profile `ocupilot-slot-a`, throwaway `ocupilot-ci` on 52776/1975.
  - After an integrate forward, load the merged ObjectScript into the throwaway (Rule 22).
  - Push a code commit alone and confirm its CI before pushing a skip-tagged commit (Rule 28).
  - `main` and release branches move only at owner-planned releases, and a cut release branch is never touched.
- **Story 13.5 runs on slot B at the same time.**
  - Do not edit `.github/workflows/ci.yml`, `ui/tools/ci-runner.mjs` or `ui/browser.config.mjs` while it runs.
  - Changes to `ui/tools/ci.test.mjs` and `scripts/ci-throwaway.sh` roster lines are add-only.
  - New browser specs and test classes land unassigned in 13.5's timings file.
- **Epic 14 is complete on the feature branch.** Its governance baseline, copy-out drafts, sanitizer, per-user read-only, transcripts and turns-per-hour all bind new work.
- **Within this epic.**
  - 16.9 builds on 16.8's sources through `LogSourcePort`.
  - 16.24 depends only on 16.1 and runs right after 16.9.
  - 16.3 uses `Kernel.Shell.Effective` (from 16.19).
  - 16.16 can follow 14.4's caller-scoped store pattern (inference).
- **Held and backlog.**
  - 16.4 needs Story 18.1's directory allow-list. Epic 18 follows 13.5 on slot B, and its destructive keys default to disabled.
  - 16.11 ships the Task Manager resume, and Story 18.4 the database mount, that 16.21's Operations findings link out to until then. Adding Fix it is the shipping story's job (inference).
  - 16.13 and 16.14 each remove a classic-link exemption (AD-44) and replace Story 9.9's reduced forms.
  - 16.6 is the first screen needing multi-select.
